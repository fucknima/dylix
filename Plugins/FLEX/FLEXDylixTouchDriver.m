// Copyright 2026 Dylix contributors.
// Event delivery design references KIF (Square) and Google EarlGrey.
// Private UIKit/IOHID declarations and event composition are adapted from those
// Apache-2.0 sources. See ThirdPartyNotices/DylixTouch-APACHE-2.0.txt and NOTICE.
#import "FLEXDylixTouchDriver.h"
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <math.h>
#import <objc/message.h>

typedef CFTypeRef DXHIDEvent;
typedef struct {uint32_t hi,lo;} DXAbsoluteTime;
typedef DXHIDEvent (*DXHandCreate)(CFAllocatorRef,DXAbsoluteTime,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,CGFloat,CGFloat,CGFloat,CGFloat,CGFloat,Boolean,Boolean,uint32_t);
typedef DXHIDEvent (*DXFingerCreate)(CFAllocatorRef,DXAbsoluteTime,uint32_t,uint32_t,uint32_t,CGFloat,CGFloat,CGFloat,CGFloat,CGFloat,CGFloat,CGFloat,CGFloat,CGFloat,CGFloat,Boolean,Boolean,uint32_t);
typedef void (*DXAppendEvent)(DXHIDEvent,DXHIDEvent,uint32_t);
typedef void (*DXSetInteger)(DXHIDEvent,uint32_t,CFIndex);
static DXHandCreate HandCreate;
static DXFingerCreate FingerCreate;
static DXAppendEvent AppendEvent;
static DXSetInteger SetInteger;

@interface UITouch (DXAgentTouchPrivate)
- (void)setWindow:(UIWindow *)window;
- (void)setView:(UIView *)view;
- (void)setTapCount:(NSUInteger)count;
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)setPhase:(UITouchPhase)phase;
- (void)setGestureView:(UIView *)view;
- (void)_setLocationInWindow:(CGPoint)point resetPrevious:(BOOL)reset;
- (void)_setIsFirstTouchForView:(BOOL)first;
- (void)_setHidEvent:(DXHIDEvent)event;
- (void)_setEdgeType:(NSInteger)edge;
@end
@interface UIEvent (DXAgentTouchPrivate)
- (void)_clearTouches;
- (void)_addTouch:(UITouch *)touch forDelayedDelivery:(BOOL)delay;
- (void)_setHIDEvent:(DXHIDEvent)event;
@end
@interface UIApplication (DXAgentTouchPrivate)
- (UIEvent *)_touchesEvent;
@end

@interface FLEXDylixTouchDriver ()
@property (nonatomic) BOOL running;
@property (nonatomic,weak) UIWindow *window;
@property NSArray<NSArray<NSValue *> *> *paths;
@property NSArray<UITouch *> *touches;
@property UIEvent *event;
@property NSTimer *timer;
@property NSTimeInterval startedAt,duration;
@property NSUInteger deliveredFrames;
@property (nonatomic,copy) void (^completion)(NSDictionary *,NSString *);
@end

@implementation FLEXDylixTouchDriver
- (id)touchResponderInWindow:(UIWindow *)window point:(CGPoint)point {
 UIView *hit=[window hitTest:point withEvent:nil];
 // KIF's iOS 18+ hit-test route is needed by SwiftUI gesture containers.
 // Probe fixed selectors; older systems retain ordinary UIKit hit testing.
 if(@available(iOS 18.0,*)){
  Class contextClass=NSClassFromString(@"_UIHitTestContext");SEL make=NSSelectorFromString(@"contextWithPoint:radius:"),test=NSSelectorFromString(@"_hitTestWithContext:");
  if([contextClass respondsToSelector:make]){
   id context=((id(*)(id,SEL,CGPoint,CGFloat))objc_msgSend)(contextClass,make,point,0);
   if(context)for(UIView *view=hit;view;view=view.superview)if([view respondsToSelector:test]){
    id responder=((id(*)(id,SEL,id))objc_msgSend)(view,test,context);if(responder)return responder;
   }
  }
 }
 return hit;
}
+ (NSDictionary *)backendCapabilities {
 static dispatch_once_t once;dispatch_once(&once,^{
  // Framework lifetime deliberately matches process lifetime.
  void *lib=dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",RTLD_LAZY|RTLD_LOCAL);
  HandCreate=(DXHandCreate)dlsym(lib?:RTLD_DEFAULT,"IOHIDEventCreateDigitizerEvent");
  FingerCreate=(DXFingerCreate)dlsym(lib?:RTLD_DEFAULT,"IOHIDEventCreateDigitizerFingerEventWithQuality");
  AppendEvent=(DXAppendEvent)dlsym(lib?:RTLD_DEFAULT,"IOHIDEventAppendEvent");
  SetInteger=(DXSetInteger)dlsym(lib?:RTLD_DEFAULT,"IOHIDEventSetIntegerValue");
 });
 NSMutableArray *missing=[NSMutableArray new];
 if(!HandCreate||!FingerCreate||!AppendEvent||!SetInteger)[missing addObject:@"IOHID event constructors"];
 for(NSString *name in @[@"setWindow:",@"setView:",@"setTapCount:",@"setTimestamp:",@"setPhase:",@"_setLocationInWindow:resetPrevious:",@"_setIsFirstTouchForView:",@"_setHidEvent:"])
  if(![UITouch instancesRespondToSelector:NSSelectorFromString(name)])[missing addObject:[@"UITouch." stringByAppendingString:name]];
 Class cls=NSClassFromString(@"UITouchesEvent");
 for(NSString *name in @[@"_clearTouches",@"_addTouch:forDelayedDelivery:",@"_setHIDEvent:"])
  if(![cls instancesRespondToSelector:NSSelectorFromString(name)])[missing addObject:[@"UITouchesEvent." stringByAppendingString:name]];
 if(![UIApplication.sharedApplication respondsToSelector:@selector(_touchesEvent)])[missing addObject:@"UIApplication event factory"];
 return @{@"available":@(missing.count==0),@"backend":@"in_process_uikit_hid",@"missing":missing,@"deliveryVerified":@NO,@"maxFingers":@2,@"maxDuration":@3};
}
- (void)performPaths:(NSArray<NSArray<NSValue *> *> *)paths window:(UIWindow *)window duration:(NSTimeInterval)duration completion:(void (^)(NSDictionary *,NSString *))completion {
 NSAssert(NSThread.isMainThread,@"Touch driver must run on main thread");
 if(self.running){completion(nil,@"另一个触摸序列仍在进行");return;}
 if(![[self.class backendCapabilities][@"available"] boolValue]){completion(nil,@"当前系统缺少触摸投递接口；不会伪造执行成功");return;}
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||window.hidden||!window||!isfinite(duration)||duration<.05||duration>3||paths.count<1||paths.count>2){completion(nil,@"触摸窗口或持续时间无效");return;}
 for(NSArray *path in paths){if(path.count<2||path.count>121){completion(nil,@"触摸路径应有 2–121 个点");return;}for(NSValue *value in path){CGPoint p=value.CGPointValue;if(!isfinite(p.x)||!isfinite(p.y)||!CGRectContainsPoint(window.bounds,p)){completion(nil,@"触摸路径超出目标窗口");return;}}}
 self.window=window;self.paths=paths;self.duration=duration;self.completion=completion;self.deliveredFrames=0;
 @try {
  self.event=[UIApplication.sharedApplication _touchesEvent];
  for(UITouch *touch in self.event.allTouches)if(touch.phase!=UITouchPhaseEnded&&touch.phase!=UITouchPhaseCancelled){[self finish:@"系统中已有触摸，请等用户操作完成再试"];return;}
  NSMutableArray *touches=[NSMutableArray new];
  for(NSArray<NSValue *> *path in paths){CGPoint point=path.firstObject.CGPointValue;id hit=[self touchResponderInWindow:window point:point];if(!hit){[self finish:@"触摸起点没有可交互视图"];return;}
   UITouch *touch=[UITouch new];[touch setWindow:window];[touch setTapCount:1];[touch _setLocationInWindow:point resetPrevious:YES];[touch setView:hit];[touch setPhase:UITouchPhaseBegan];[touch _setIsFirstTouchForView:YES];[touch setTimestamp:NSProcessInfo.processInfo.systemUptime];
   if([touch respondsToSelector:@selector(setGestureView:)])[touch setGestureView:hit];
   if([touch respondsToSelector:@selector(_setEdgeType:)])[touch _setEdgeType:point.x<16?4:0];
   [touches addObject:touch];
  }
  self.touches=touches;self.running=YES;self.startedAt=NSProcessInfo.processInfo.systemUptime;
  [self sendAtProgress:0 phase:UITouchPhaseBegan];
  self.timer=[NSTimer timerWithTimeInterval:1.0/60 target:self selector:@selector(tick) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
 } @catch(NSException *exception){[self abortWithError:[NSString stringWithFormat:@"触摸后端异常（%@）",exception.name]];}
}
- (CGPoint)pointForPath:(NSArray<NSValue *> *)path progress:(CGFloat)progress {
 CGFloat position=MIN(1,MAX(0,progress))*(path.count-1);NSUInteger i=MIN((NSUInteger)floor(position),path.count-2);CGFloat fraction=position-i;
 CGPoint a=path[i].CGPointValue,b=path[i+1].CGPointValue;return CGPointMake(a.x+(b.x-a.x)*fraction,a.y+(b.y-a.y)*fraction);
}
- (void)sendAtProgress:(CGFloat)progress phase:(UITouchPhase)phase {
 uint64_t time=mach_absolute_time();DXAbsoluteTime stamp={(uint32_t)(time>>32),(uint32_t)time};BOOL active=phase!=UITouchPhaseEnded&&phase!=UITouchPhaseCancelled;
 DXHIDEvent hand=HandCreate(kCFAllocatorDefault,stamp,3,0,0,active?2:3,0,0,0,0,0,0,active,active,0);
 if(!hand)@throw [NSException exceptionWithName:@"DXHIDAllocation" reason:nil userInfo:nil];
 @try {
  SetInteger(hand,(11<<16)+25,1);[self.event _clearTouches];
  NSUInteger index=0;for(UITouch *touch in self.touches){CGPoint point=[self pointForPath:self.paths[index] progress:progress];CGPoint old=[touch locationInView:self.window];UITouchPhase actual=phase==UITouchPhaseMoved&&CGPointEqualToPoint(old,point)?UITouchPhaseStationary:phase;
   [touch _setLocationInWindow:point resetPrevious:phase==UITouchPhaseBegan];[touch setPhase:actual];[touch setTimestamp:NSProcessInfo.processInfo.systemUptime];
   uint32_t mask=phase==UITouchPhaseMoved?4:phase==UITouchPhaseCancelled?0x83:3;
   DXHIDEvent finger=FingerCreate(kCFAllocatorDefault,stamp,(uint32_t)index+1,(uint32_t)index+2,mask,point.x,point.y,0,0,0,5,5,1,1,1,active,active,0);
   if(!finger)@throw [NSException exceptionWithName:@"DXHIDAllocation" reason:nil userInfo:nil];
   @try{SetInteger(finger,(11<<16)+25,1);[touch _setHidEvent:finger];AppendEvent(hand,finger,0);[self.event _addTouch:touch forDelayedDelivery:NO];}@finally{CFRelease(finger);}
   index++;
  }
  [self.event _setHIDEvent:hand];[UIApplication.sharedApplication sendEvent:self.event];self.deliveredFrames++;
 } @finally {CFRelease(hand);}
}
- (void)tick {
 if(!self.running)return;
 if(!self.window||self.window.hidden||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){[self cancel];return;}
 CGFloat progress=MIN(1,(NSProcessInfo.processInfo.systemUptime-self.startedAt)/self.duration);
 @try{[self sendAtProgress:progress phase:progress>=1?UITouchPhaseEnded:UITouchPhaseMoved];if(progress>=1)[self finish:nil];}@catch(NSException *exception){[self abortWithError:[NSString stringWithFormat:@"触摸投递中断（%@）",exception.name]];}
}
- (void)cancel {
 if(!self.running)return;
 [self abortWithError:@"触摸序列已取消"];
}
- (void)abortWithError:(NSString *)error {
 if(self.running){
 @try{CGFloat progress=MIN(1,(NSProcessInfo.processInfo.systemUptime-self.startedAt)/self.duration);[self sendAtProgress:progress phase:UITouchPhaseCancelled];}@catch(NSException *exception){}
 }
 [self finish:error];
}
- (void)finish:(NSString *)error {
 [self.timer invalidate];self.timer=nil;self.running=NO;
 void (^completion)(NSDictionary *,NSString *)=self.completion;NSUInteger frames=self.deliveredFrames;
 self.completion=nil;self.touches=nil;self.event=nil;self.paths=nil;self.window=nil;
 if(completion)completion(error?nil:@{@"delivered":@YES,@"frames":@(frames),@"backend":@"in_process_uikit_hid",@"requeryRequired":@YES,@"semanticSuccessUnverified":@YES},error);
}
- (void)dealloc {[self.timer invalidate];}
@end

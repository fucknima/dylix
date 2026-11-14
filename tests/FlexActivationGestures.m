#import <UIKit/UIKit.h>
#import "FLEXManager+ThreeFingerTap.h"
#import "FLEXDylixTouchDriver.h"
static NSUInteger ToggleCount,OtherCount;
static NSMutableArray *Checks;
@interface FLEXManager (ActivationTests)
+ (void)flex_setupGesture;
@end
@implementation FLEXManager
+ (instancetype)sharedManager{static FLEXManager *manager;static dispatch_once_t once;dispatch_once(&once,^{manager=[self new];});return manager;}
- (void)toggleExplorer{ToggleCount++;}
@end
static void Check(BOOL pass,NSString *name){[Checks addObject:@{@"name":name,@"passed":@(pass)}];}
static void Spin(NSTimeInterval delay){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:delay];while(end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
static void Hold(UIWindow *window,NSUInteger fingers,NSTimeInterval duration){
 NSMutableArray *paths=[NSMutableArray new];for(NSUInteger i=0;i<fingers;i++){NSValue *p=[NSValue valueWithCGPoint:CGPointMake(60+i*55,230)];[paths addObject:@[p,p]];}
 FLEXDylixTouchDriver *driver=[FLEXDylixTouchDriver new];__block BOOL finished=NO;__block NSString *failure=nil;[driver performPaths:paths window:window duration:duration completion:^(NSDictionary *result,NSString *error){finished=YES;failure=error;}];NSDate *end=[NSDate dateWithTimeIntervalSinceNow:4];while(!finished&&end.timeIntervalSinceNow>0)Spin(.02);if(failure)[Checks addObject:@{@"name":@"touch delivery diagnostic",@"passed":@NO,@"error":failure,@"appState":@(UIApplication.sharedApplication.applicationState),@"window":NSStringFromCGRect(window.bounds),@"backend":[FLEXDylixTouchDriver backendCapabilities]}];Check(finished&&!failure,[NSString stringWithFormat:@"%lu finger %.1fs UIKit event delivery",(unsigned long)fingers,duration]);Spin(.15);
}
@interface ActivationApp : UIResponder <UIApplicationDelegate>
@property UIWindow *window;
@end
@implementation ActivationApp
- (void)otherHold:(UILongPressGestureRecognizer *)r{if(r.state==UIGestureRecognizerStateBegan)OtherCount++;}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options{
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];UIViewController *page=[UIViewController new];page.view.backgroundColor=UIColor.systemBackgroundColor;page.view.multipleTouchEnabled=YES;self.window.rootViewController=page;[self.window makeKeyAndVisible];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 Checks=[NSMutableArray new];[FLEXManager flex_setupGesture];[FLEXManager flex_setupGesture];NSMutableArray *ours=[NSMutableArray new];for(UIGestureRecognizer *r in self.window.gestureRecognizers)if([r.delegate isKindOfClass:NSClassFromString(@"FLEXActivationGestureDelegate")])[ours addObject:r];Check(ours.count==2,@"exactly two activation recognizers after repeated setup");NSMutableSet *counts=[NSMutableSet new];for(UILongPressGestureRecognizer *r in ours){[counts addObject:@(r.numberOfTouchesRequired)];Check(r.minimumPressDuration==.5&&!r.cancelsTouchesInView&&!r.delaysTouchesBegan&&!r.delaysTouchesEnded,@"activation duration and host touch delivery preserved");}Check([counts isEqual:[NSSet setWithArray:@[@3,@4]]],@"three and four finger shortcuts both installed");
 NSUInteger before=ToggleCount;Hold(self.window,3,.8);Check(ToggleCount==before+1,@"three finger hold toggles exactly once");before=ToggleCount;Hold(self.window,4,.8);Check(ToggleCount==before+1,@"four finger hold toggles exactly once");before=ToggleCount;Hold(self.window,2,.8);Check(ToggleCount==before,@"two fingers do not activate FLEX");before=ToggleCount;Hold(self.window,4,.2);Check(ToggleCount==before,@"short four finger touch does not activate FLEX");before=ToggleCount;Hold(self.window,4,1.3);Check(ToggleCount==before+1,@"prolonged four finger hold does not double toggle");
 UILongPressGestureRecognizer *other=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(otherHold:)];other.numberOfTouchesRequired=3;other.minimumPressDuration=.2;[self.window addGestureRecognizer:other];before=ToggleCount;Hold(self.window,3,.8);Check(OtherCount==1&&ToggleCount==before+1,@"FLEX can coexist with earlier competing three finger hold");before=ToggleCount;NSUInteger otherBefore=OtherCount;Hold(self.window,4,.8);Check(ToggleCount==before+1&&OtherCount==otherBefore,@"four finger alternative bypasses three finger shortcut");
 UIWindow *previous=self.window;self.window=[[UIWindow alloc]initWithFrame:previous.frame];self.window.rootViewController=[UIViewController new];self.window.rootViewController.view.multipleTouchEnabled=YES;[self.window makeKeyAndVisible];previous.hidden=YES;[FLEXManager flex_setupGesture];BOOL moved=YES;for(UIGestureRecognizer *r in ours)moved&=r.view==self.window;Check(moved,@"both activation gestures migrate together to new target window");before=ToggleCount;Hold(self.window,4,.8);Check(ToggleCount==before+1,@"four finger activation works after target window change");
 NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;[[NSJSONSerialization dataWithJSONObject:Checks options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[docs stringByAppendingPathComponent:@"activation-results.json"] atomically:YES];
 });return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(ActivationApp.class));}}

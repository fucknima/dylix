#import "TFAIUIHelpers.h"
#import "../AIV2Contracts.h"
extern UIViewController *TFAIApprovalController(NSDictionary *,void(^)(BOOL,NSArray *));
// Independent child approvals share one presentation queue. No parent grant or
// parent-chat running state is reused. Background requests wait for foreground.
@interface TFChildApprovalQueue : NSObject
@property NSMutableArray *pending;
@property BOOL presenting;
@end
@implementation TFChildApprovalQueue
+ (instancetype)shared{static id q;static dispatch_once_t once;dispatch_once(&once,^{q=[self new];[q setPending:[NSMutableArray new]];});return q;}
- (void)pump{if(self.presenting||!self.pending.count)return;NSDictionary *row=self.pending.firstObject;BOOL(^valid)(void)=row[@"valid"];void(^decision)(BOOL,NSArray *)=row[@"decision"];if(!valid()){[self.pending removeObjectAtIndex:0];decision(NO,nil);[self pump];return;}
 UIViewController *host=nil;for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)if(scene.activationState==UISceneActivationStateForegroundActive&&[scene isKindOfClass:UIWindowScene.class])for(UIWindow *window in ((UIWindowScene *)scene).windows)if(window.isKeyWindow)host=window.rootViewController;
 // Avoid stacking on any existing parent/native approval, sheet or alert.
 if(!host||host.presentedViewController||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self pump];});return;}
 self.presenting=YES;[self.pending removeObjectAtIndex:0];UIViewController *page=TFAIApprovalController(row[@"plan"],^(BOOL approved,NSArray *indexes){self.presenting=NO;decision(approved&&valid(),indexes);[self pump];});UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:page];nav.modalPresentationStyle=UIModalPresentationPageSheet;nav.modalInPresentation=YES;[host presentViewController:nav animated:YES completion:nil];
}
@end
void TFAIChildApproval(NSDictionary *plan,BOOL(^valid)(void),void(^decision)(BOOL,NSArray *)){dispatch_async(dispatch_get_main_queue(),^{TFChildApprovalQueue *queue=TFChildApprovalQueue.shared;if(queue.pending.count>=16){decision(NO,nil);return;}[queue.pending addObject:@{@"plan":plan,@"valid":[valid copy],@"decision":[decision copy]}];[queue pump];});}

#import "DXBackupTask.h"
#import "DXBackup.h"
#import "../../GitPreferences.h"
#import <UIKit/UIKit.h>
extern BOOL TFAIHasLiveRuns(void);
NSNotificationName const DXBackupTaskChanged=@"Dylix.Backup.TaskChanged";
@interface DXBackupTask ()
@property(nonatomic,readwrite) BOOL busy;
@property(nonatomic,readwrite) NSProgress *progress;
@property(nonatomic,readwrite) NSTimeInterval startedAt;
@property(nonatomic,readwrite) NSTimeInterval finishedAt;
@property(nonatomic,readwrite) NSDictionary *result;
@property(nonatomic,readwrite) NSError *error;
@property UIBackgroundTaskIdentifier backgroundTask;
@property BOOL completionNotificationClaimed;
@end
@implementation DXBackupTask
+ (instancetype)shared{static DXBackupTask *value;static dispatch_once_t once;dispatch_once(&once,^{value=[self new];value.backgroundTask=UIBackgroundTaskInvalid;});return value;}
- (void)notify{[NSNotificationCenter.defaultCenter postNotificationName:DXBackupTaskChanged object:self];}
- (BOOL)start:(NSSet *)categories password:(NSString *)password secrets:(BOOL)secrets{
 NSAssert(NSThread.isMainThread,@"Backup start runs on main queue");if(self.busy)return NO;
 self.completionNotificationClaimed=NO;self.busy=YES;self.finishedAt=0;self.result=nil;self.error=nil;self.progress=[NSProgress progressWithTotalUnitCount:1000];self.startedAt=NSProcessInfo.processInfo.systemUptime;
 self.backgroundTask=[UIApplication.sharedApplication beginBackgroundTaskWithName:@"Dylix 数据备份" expirationHandler:^{[self.progress cancel];if(self.backgroundTask!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}}];
 NSSet *selected=categories.copy;NSString *secret=password.copy;NSProgress *progress=self.progress;[self notify];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSError *error=nil;NSDictionary *result=nil;TMCGitLease *lease __attribute__((objc_precise_lifetime))=[TMCGitLease tryWrite];
  if(!lease||TFAIHasLiveRuns()||TMCGitLease.hasActiveBuilds)error=[NSError errorWithDomain:@"Dylix.Backup" code:1 userInfo:@{NSLocalizedDescriptionKey:@"AI、构建或项目写入仍在运行，请完成后备份。"}];
  else result=DXBackupCreate(NSHomeDirectory(),selected,secret,secrets,progress,&error);
  dispatch_async(dispatch_get_main_queue(),^{self.result=result;self.error=error;self.finishedAt=NSProcessInfo.processInfo.systemUptime;self.busy=NO;if(self.backgroundTask!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}[self notify];});
 });return YES;
}
- (BOOL)claimCompletionNotification{NSAssert(NSThread.isMainThread,@"Backup notification runs on main queue");if(self.busy||(!self.result&&!self.error)||self.completionNotificationClaimed)return NO;self.completionNotificationClaimed=YES;return YES;}
- (void)cancel{NSAssert(NSThread.isMainThread,@"Backup cancellation runs on main queue");if(self.busy){[self.progress cancel];[self notify];}}
@end

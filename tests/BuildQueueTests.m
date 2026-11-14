#import <Foundation/Foundation.h>
#import "../App/AI/Agent/TFAIBuildQueue.h"
#import "../App/AI/Registry/TFAIToolRegistry.h"
static BOOL nativeBusy,enabled=YES;
BOOL TMCBuildIsRunning(void){return nativeBusy;}
@implementation TFAIToolRegistry
+ (BOOL)enabled:(NSString *)module{return enabled;}
@end
NSError *TFAIError(NSInteger code,NSString *text){return [NSError errorWithDomain:@"Test" code:code userInfo:@{NSLocalizedDescriptionKey:text}];}
void TFAINotificationsRequest(void){}
NSString *TFAIBackgroundBegin(void(^expired)(NSString *)){return @"queue";}
void TFAIBackgroundEnd(NSString *token,BOOL ok){}
void TFAIBackgroundUpdate(NSString *token,NSDictionary *event){}
void TFAILiveUpdate(NSString *stage,NSUInteger n,NSUInteger total){}
void TFAILiveEnd(BOOL success){}
void TFAINotifyBuildCompletion(NSString *task,NSString *project,BOOL success){}
#include "../App/AI/Agent/TFAIBuildQueueCore.inc"
static NSUInteger checks;
static void Check(BOOL ok,NSString *name){if(!ok){NSLog(@"FAIL %@",name);exit(1);}checks++;NSLog(@"PASS %@",name);}
static void Drain(void){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:.06];while([end timeIntervalSinceNow]>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];}
int main(){@autoreleasepool{
 TFAIBuildQueue *queue=TFAIBuildQueue.shared;__block NSUInteger active=0,peak=0,starts=0,callbacks=0,cancels=0;NSMutableArray *done=[NSMutableArray new];TFAIBuildExecutor executor=^(void(^progress)(NSString *,double),TFAIResult finish){active++;starts++;peak=MAX(peak,active);[done addObject:[^(NSDictionary *r,NSError *e){active--;finish(r,e);} copy]];};
 nativeBusy=YES;NSString *parent=[queue enqueue:@"/tmp/current" session:@"parent" name:@"parent" executor:executor cancel:^{cancels++;} completion:^(NSDictionary *r,NSError *e){callbacks++;}];NSString *duplicate=[queue enqueue:@"/tmp/current" session:@"parent" name:@"same" executor:executor cancel:nil completion:^(NSDictionary *r,NSError *e){callbacks++;}];NSString *child=[queue enqueue:@"/tmp/current" session:@"child" name:@"child" executor:executor cancel:^{cancels++;} completion:^(NSDictionary *r,NSError *e){callbacks++;}];Drain();Check(starts==0,@"native build lock blocks parent and child");Check([parent isEqual:duplicate]&&![parent isEqual:child],@"same session deduplicates but child remains separate queued job");nativeBusy=NO;[queue pump];Drain();Check(starts==1&&peak==1,@"only parent executor starts");[queue cancel:parent];Check(cancels==1&&starts==1,@"cancel waits current build step before child starts");TFAIResult finish=done[0];finish(@{@"success":@YES},nil);Drain();Check(starts==2&&peak==1&&callbacks==2,@"child starts after parent completion and both parent callbacks settle");finish=done[1];finish(@{@"success":@YES},nil);Drain();Check(active==0&&callbacks==3,@"child completes single active queue");
 NSString *queued=[queue enqueue:@"/tmp/current" session:@"cancel" name:@"cancel" executor:executor cancel:nil completion:^(NSDictionary *r,NSError *e){Check(e.code==NSURLErrorCancelled,@"queued cancellation reports cancellation");}];[queue cancel:queued];Drain();Check(starts==2,@"cancelled queued build never runs");
 enabled=NO;[queue enqueue:@"/tmp/current" session:@"direct" name:@"direct" executor:executor cancel:nil completion:nil];__block BOOL rejected=NO;[queue enqueue:@"/tmp/current" session:@"other" name:@"other" executor:executor cancel:nil completion:^(NSDictionary *r,NSError *e){rejected=e!=nil;}];Check(rejected&&peak==1,@"queue disabled still enforces direct build mutual exclusion");finish=done.lastObject;finish(@{@"success":@YES},nil);Drain();Check(active==0,@"direct build releases lock");NSLog(@"TOTAL %lu build queue checks passed",(unsigned long)checks);return 0;}}

#import <Foundation/Foundation.h>
#import "../App/AI/Permissions/TFAIPolicy.h"
static dispatch_queue_t gitQueue;
static NSString *documents;
static NSUInteger gitMutations;
static NSString *DXDocs(void){return documents;}
static NSError *DXError(NSString *text){return [NSError errorWithDomain:@"audit" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}
@interface TMCGitLease : NSObject
+ (instancetype)tryWrite;
+ (BOOL)isBuilding:(NSString *)root;
@end
@implementation TMCGitLease
+ (instancetype)tryWrite{return [self new];}
+ (BOOL)isBuilding:(NSString *)root{return NO;}
@end
@interface TMCGitService : NSObject
+ (dispatch_queue_t)queue;
- (instancetype)initWithRoot:(NSString *)root;
- (void)initialize:(NSError **)error;
- (void)branch:(NSString *)name action:(NSString *)action error:(NSError **)error;
@end
@implementation TMCGitService
+ (dispatch_queue_t)queue{return gitQueue;}
- (instancetype)initWithRoot:(NSString *)root{return [super init];}
- (void)initialize:(NSError **)error{gitMutations++;}
- (void)branch:(NSString *)name action:(NSString *)action error:(NSError **)error{gitMutations++;}
@end
static BOOL TMCWriteDocument(NSString *path,NSData *before,NSString *text,NSError **error){
 if(![[NSData dataWithContentsOfFile:path] isEqual:before])return NO;
 return [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}
@interface DXRemoteWorkspace : NSObject
@property dispatch_queue_t queue;
@property NSMutableDictionary *jobs,*owners;
- (void)mutate:(NSMutableDictionary *)job action:(NSString *)action arguments:(NSDictionary *)args root:(NSString *)root;
- (void)finish:(NSMutableDictionary *)job result:(id)result error:(NSError *)error;
@end
@implementation DXRemoteWorkspace
- (void)finish:(NSMutableDictionary *)job result:(id)result error:(NSError *)error{if(![job[@"state"] isEqual:@"cancelled"])job[@"state"]=error?@"failed":@"completed";}
// The runner extracts the exact production method; no second implementation.
#include "RemoteMutationProduction.inc"
@end
static void Check(BOOL ok,NSString *label){printf("%s %s\n",ok?"PASS":"FAIL",label.UTF8String);if(!ok)exit(1);}
int main(){@autoreleasepool{
 gitQueue=dispatch_queue_create("audit.git",DISPATCH_QUEUE_SERIAL);
 documents=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
 NSString *root=[documents stringByAppendingPathComponent:@"project"],*path=[root stringByAppendingPathComponent:@"file.m"];
 [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
 NSData *original=[@"original" dataUsingEncoding:NSUTF8StringEncoding];[original writeToFile:path atomically:YES];
 DXRemoteWorkspace *workspace=[DXRemoteWorkspace new];workspace.queue=dispatch_queue_create("audit.remote",DISPATCH_QUEUE_SERIAL);workspace.jobs=[NSMutableDictionary new];workspace.owners=[NSMutableDictionary new];
 NSDictionary *args=@{@"path":@"file.m",@"destination":@"other.m",@"sha256":TFAIDigest(original),@"text":@"changed",@"name":@"branch",@"operation":@"create"};
 for(NSString *action in @[@"save",@"copy",@"move",@"project_delete",@"git_init",@"git_branch"]){
  NSMutableDictionary *job=[@{@"id":action,@"device":@"device",@"projectID":@"project",@"state":@"running"} mutableCopy];
  dispatch_sync(workspace.queue,^{workspace.jobs[action]=job;});
  dispatch_semaphore_t waiting=dispatch_semaphore_create(0),release=dispatch_semaphore_create(0);
  dispatch_async(gitQueue,^{dispatch_semaphore_signal(waiting);dispatch_semaphore_wait(release,DISPATCH_TIME_FOREVER);});dispatch_semaphore_wait(waiting,DISPATCH_TIME_FOREVER);
  [workspace mutate:job action:action arguments:args root:root];
  // Same state transition used by cancel/revoke while the approved task queues.
  dispatch_sync(workspace.queue,^{job[@"state"]=@"cancelled";});dispatch_semaphore_signal(release);dispatch_sync(gitQueue,^{});dispatch_sync(workspace.queue,^{});
  Check([[NSData dataWithContentsOfFile:path] isEqual:original]&&![NSFileManager.defaultManager fileExistsAtPath:[root stringByAppendingPathComponent:@"other.m"]]&&gitMutations==0,[@"cancelled queued mutation does not execute: " stringByAppendingString:action]);
 }
 NSMutableDictionary *valid=[@{@"id":@"valid",@"device":@"device",@"projectID":@"project",@"state":@"running"} mutableCopy];dispatch_sync(workspace.queue,^{workspace.jobs[@"valid"]=valid;});
 [workspace mutate:valid action:@"save" arguments:args root:root];dispatch_sync(gitQueue,^{});dispatch_sync(workspace.queue,^{});
 Check([[[NSString alloc]initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] isEqual:@"changed"]&&[valid[@"state"] isEqual:@"completed"],@"authorized active write still completes");
 [NSFileManager.defaultManager removeItemAtPath:documents error:nil];printf("TOTAL 7 queued mutation checks passed\n");
 }return 0;}

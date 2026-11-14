#import "DXLinuxToolBatch.h"
#import "TFAIISHPackageCatalog.h"
#import "TFAIISHRuntime.h"
#import "TFAIISHEnvironment.h"
#import "../../SDKResources.h"
@interface DXLinuxToolBatch ()
@property NSMutableDictionary<NSString *,NSMutableDictionary *> *jobs;
@end
@implementation DXLinuxToolBatch
+ (instancetype)shared{static id v;static dispatch_once_t once;dispatch_once(&once,^{v=[self new];});return v;}
- (instancetype)init{if((self=[super init])){_jobs=[NSMutableDictionary new];_runtime=TFAIISHRuntime.shared;}return self;}
- (NSDictionary *)status:(NSString *)session{return [self.jobs[TFAIISHEnvironment.sharedKey] copy]?:@{@"running":@NO};}
- (NSArray<NSString *> *)pending:(NSDictionary *)inventory sdkInstalled:(BOOL)sdk{
 NSMutableArray *ids=[NSMutableArray new];for(NSDictionary *p in DXLinuxPackages())if(![inventory[p[@"id"]][@"installed"] boolValue])[ids addObject:p[@"id"]];
 for(NSString *key in @[@"developer-tools",@"reverse-tools"])if(![inventory[key][@"installed"] boolValue])[ids addObject:key];if(!sdk)[ids addObject:@"sdk26"];return ids;
}
- (BOOL)start:(NSArray<NSString *> *)identifiers session:(NSString *)session{
 session=TFAIISHEnvironment.sharedKey;
 NSAssert(NSThread.isMainThread,@"batch state belongs to main thread");if(!session.length||[self.jobs[session][@"running"] boolValue]||!identifiers.count)return NO;
 for(NSString *key in identifiers)if(!DXLinuxPackage(key)&&![@[@"developer-tools",@"reverse-tools",@"sdk26"] containsObject:key])return NO;
 self.jobs[session]=[@{@"running":@YES,@"items":[NSOrderedSet orderedSetWithArray:identifiers].array,@"index":@0,@"failed":@0,@"cancelled":@NO} mutableCopy];[self step:session];return YES;
}
- (void)cancelPending:(NSString *)session{self.jobs[TFAIISHEnvironment.sharedKey][@"cancelled"]=@YES;}
- (void)later:(NSString *)session{dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self step:session];});}
- (void)advance:(NSString *)session error:(NSError *)error{
 NSMutableDictionary *job=self.jobs[session];if(![job[@"running"] boolValue])return;
 if(error){job[@"failed"]=@([job[@"failed"] unsignedIntegerValue]+1);job[@"error"]=error.localizedDescription?:@"安装失败";}
 job[@"index"]=@([job[@"index"] unsignedIntegerValue]+1);[job removeObjectForKey:@"current"];[job removeObjectForKey:@"started"];[job removeObjectForKey:@"deadline"];[self later:session];
}
- (void)step:(NSString *)session{
 NSMutableDictionary *job=self.jobs[session];if(![job[@"running"] boolValue])return;
 NSArray *items=job[@"items"];NSUInteger index=[job[@"index"] unsignedIntegerValue];
 if(index>=items.count||([job[@"cancelled"] boolValue]&&!job[@"started"])){job[@"running"]=@NO;return;}
 NSString *key=items[index];job[@"current"]=key;
 if([key isEqual:@"sdk26"]){if([job[@"started"] boolValue])return;job[@"started"]=@YES;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSError *error=nil;NSString *path=TMCPrepareSelectedSDK(NSBundle.mainBundle,NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES).firstObject,@"26.0",&error);if(!path&&!error)error=[NSError errorWithDomain:@"DXLinuxBatch" code:1 userInfo:@{NSLocalizedDescriptionKey:@"SDK 安装未完成"}];dispatch_async(dispatch_get_main_queue(),^{[self advance:session error:error];});});return;}
 [self.runtime toolInventory:session completion:^(NSDictionary *inventory){dispatch_async(dispatch_get_main_queue(),^{
  NSMutableDictionary *live=self.jobs[session];if(live!=job||![live[@"running"] boolValue])return;
  NSDictionary *row=inventory[key];BOOL active=NO;for(id value in inventory.allValues)if([value isKindOfClass:NSDictionary.class]&&[@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:value[@"state"]]){active=YES;break;}
  if([job[@"started"] boolValue]){
   if(active){if(NSProcessInfo.processInfo.systemUptime>[job[@"deadline"] doubleValue]){job[@"running"]=@NO;job[@"error"]=@"安装等待超时；当前任务仍可在工具页面查看，未启动后续安装。";return;}[self later:session];return;}
   NSError *e=[row[@"installed"] boolValue]?nil:[NSError errorWithDomain:@"DXLinuxBatch" code:2 userInfo:@{NSLocalizedDescriptionKey:row[@"error"]?:@"工具安装未成功"}];[self advance:session error:e];return;
  }
  if([job[@"cancelled"] boolValue]){job[@"running"]=@NO;return;}
  if(active){[self later:session];return;}
  if([row[@"installed"] boolValue]){[self advance:session error:nil];return;}
  job[@"started"]=@YES;job[@"deadline"]=@(NSProcessInfo.processInfo.systemUptime+1900);
  void(^done)(NSDictionary *,NSError *)=^(NSDictionary *r,NSError *e){dispatch_async(dispatch_get_main_queue(),^{if(e)[self advance:session error:e];else[self later:session];});};
  if(DXLinuxPackage(key))[self.runtime installPackage:key session:session completion:done];else if([key isEqual:@"developer-tools"])[self.runtime installDeveloperTools:session completion:done];else[self.runtime installReverseTools:session completion:done];
 });}];
}
@end

#import <Foundation/Foundation.h>
#import "../App/AI/Sandbox/TFAIISHRuntime.h"
#import "../App/Remote/DXRemoteSanitize.h"

@interface TFAIISHRuntime (AuditTesting)
- (NSDictionary *)readJob:(id)job offset:(uint64_t)offset maximum:(NSUInteger)maximum;
- (void)pruneProcessJobsOnQueue:(NSString *)session;
- (void)watchToolJob:(id)job defaultsKey:(NSString *)key marker:(NSString *)marker deadline:(NSTimeInterval)deadline;
@end
static int checks;
static void Check(BOOL ok,NSString *label){if(!ok){fprintf(stderr,"FAIL %s\n",label.UTF8String);exit(1);}checks++;printf("PASS %s\n",label.UTF8String);}
static id Job(NSString *identifier,BOOL done){
 id job=[NSClassFromString(@"DylixISHJob") new];
 for(NSString *key in @[@"session",@"key"])[job setValue:@"audit-session" forKey:key];
 [job setValue:identifier forKey:@"processID"];[job setValue:@(done) forKey:@"done"];[job setValue:@NO forKey:@"terminal"];
 [job setValue:[NSMutableDictionary new] forKey:@"listeners"];[job setValue:[NSMutableData dataWithData:[@"tail" dataUsingEncoding:NSUTF8StringEncoding]] forKey:@"tail"];
 [job setValue:@14 forKey:@"totalBytes"];return job;
}
int main(){@autoreleasepool{
 NSDictionary *clean=Clean(@{@"API_Key":@"opaque",@"Authorization":@"opaque",@"refresh-token":@"opaque",@"Password":@"opaque",@"nested":@[@{@"ClientSecret":@"opaque",@"inputTokens":@123,@"cached_tokens":@45}],@"tokenUsage":@67,@1:@"bad-key"});
 Check(!clean[@"API_Key"]&&!clean[@"Authorization"]&&!clean[@"refresh-token"]&&!clean[@"Password"],@"credential fields filtered across case/separator variants");
 Check(!clean[@"nested"][0][@"ClientSecret"]&&[clean[@"nested"][0][@"inputTokens"] isEqual:@123]&&[clean[@"nested"][0][@"cached_tokens"] isEqual:@45]&&[clean[@"tokenUsage"] isEqual:@67],@"nested credentials removed while usage metrics survive");
 Check(clean.count==2,@"non-string keys omitted without messaging arbitrary objects");
 TFAIISHRuntime *runtime=TFAIISHRuntime.shared;dispatch_queue_t queue=[runtime valueForKey:@"queue"];
 NSString *folder=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
 dispatch_sync(queue,^{
  id job=Job(@"read-job",YES);NSString *path=[folder stringByAppendingPathComponent:@"spool"];[[@"12345" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];[job setValue:path forKey:@"spoolPath"];[job setValue:@5 forKey:@"spooledBytes"];
  NSDictionary *gap=[runtime readJob:job offset:6 maximum:16];
  Check([gap[@"offset"] isEqual:@10]&&[gap[@"missed_bytes"] isEqual:@4]&&[gap[@"next_offset"] isEqual:@14]&&[gap[@"output"] isEqual:@"tail"],@"offset beyond capped spool skips gap and advances");
  NSDictionary *saved=[runtime readJob:job offset:2 maximum:16];
  Check([saved[@"output"] isEqual:@"345"]&&[saved[@"next_offset"] isEqual:@5]&&[saved[@"missed_bytes"] isEqual:@0],@"available spool bytes remain readable before gap");
  [NSFileManager.defaultManager removeItemAtPath:path error:nil];NSDictionary *missing=[runtime readJob:job offset:2 maximum:16];
  Check([missing[@"offset"] isEqual:@10]&&[missing[@"missed_bytes"] isEqual:@8]&&[missing[@"next_offset"] isEqual:@14],@"missing spool falls back to retained output with truthful lost-byte count");
  NSString *pref=[@"DylixAudit-" stringByAppendingString:NSUUID.UUID.UUIDString];NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
  id install=Job(@"install",YES);[install setValue:[NSMutableData dataWithData:[@"INSTALLED" dataUsingEncoding:NSUTF8StringEncoding]] forKey:@"tail"];[install setValue:@0 forKey:@"exitStatus"];
  [runtime watchToolJob:install defaultsKey:pref marker:@"INSTALLED" deadline:0];Check([defaults boolForKey:pref],@"autoload preference stored only after successful exit and marker");
  [install setValue:@1 forKey:@"exitStatus"];[runtime watchToolJob:install defaultsKey:pref marker:@"INSTALLED" deadline:0];Check([defaults boolForKey:pref],@"failed session does not revoke successful global preference");
  [defaults removeObjectForKey:pref];[runtime watchToolJob:install defaultsKey:pref marker:@"INSTALLED" deadline:0];Check(![defaults boolForKey:pref],@"failed install does not enable autoload");
  [install setValue:@0 forKey:@"exitStatus"];[runtime watchToolJob:install defaultsKey:pref marker:@"ABSENT" deadline:0];Check(![defaults boolForKey:pref],@"zero exit without completion marker is insufficient");
  NSMutableDictionary *jobs=[runtime valueForKey:@"processJobs"];[jobs removeAllObjects];NSMutableArray *paths=[NSMutableArray new];
  for(int i=0;i<40;i++){NSString *identifier=[NSString stringWithFormat:@"job-%d",i];id j=Job(identifier,YES);[j setValue:@(i) forKey:@"finishedAt"];NSString *file=[folder stringByAppendingPathComponent:identifier];[NSData.data writeToFile:file atomically:YES];[j setValue:file forKey:@"spoolPath"];[paths addObject:file];jobs[identifier]=j;}
  jobs[@"active"]=Job(@"active",NO);[runtime pruneProcessJobsOnQueue:@"audit-session"];
  Check(jobs.count==32&&jobs[@"active"]!=nil,@"process retention bounded while active task survives");
  Check(![NSFileManager.defaultManager fileExistsAtPath:paths[0]]&&[NSFileManager.defaultManager fileExistsAtPath:paths.lastObject],@"evicted process spool deleted and recent spool retained");
  [jobs removeAllObjects];[defaults removeObjectForKey:pref];
 });
 [NSFileManager.defaultManager removeItemAtPath:folder error:nil];printf("TOTAL %d audit regression checks passed\n",checks);
 }return 0;}

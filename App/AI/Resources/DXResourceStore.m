#import "DXResourceStore.h"
#import <CommonCrypto/CommonDigest.h>
#include <math.h>
NSNotificationName const DXResourceStatusChanged=@"Dylix.Resource.StatusChanged";
static NSError *RError(NSString *message){return [NSError errorWithDomain:@"Dylix.Resources" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];}
static NSString *Digest(NSString *path){NSInputStream *stream=[NSInputStream inputStreamWithFileAtPath:path];[stream open];CC_SHA256_CTX ctx;CC_SHA256_Init(&ctx);uint8_t buffer[65536];NSInteger n;while((n=[stream read:buffer maxLength:sizeof(buffer)])>0)CC_SHA256_Update(&ctx,buffer,(CC_LONG)n);[stream close];if(n<0)return nil;unsigned char h[32];CC_SHA256_Final(h,&ctx);NSMutableString *result=[NSMutableString new];for(int i=0;i<32;i++)[result appendFormat:@"%02x",h[i]];return result;}
@interface DXResourceStore ()
@property NSMutableDictionary *jobs,*states;
@end
@implementation DXResourceStore
+ (instancetype)shared{static id value;static dispatch_once_t once;dispatch_once(&once,^{value=[self new];});return value;}
- (instancetype)init{if((self=[super init])){_jobs=[NSMutableDictionary new];_states=[NSMutableDictionary new];}return self;}
+ (NSArray *)catalog{NSData *data=[NSData dataWithContentsOfFile:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"DownloadResources.json"]];id parsed=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;return [parsed isKindOfClass:NSArray.class]?parsed:@[];}
+ (NSString *)directory{return [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"Dylix/DownloadedResources"];}
+ (NSDictionary *)entry:(NSString *)identifier{for(NSDictionary *entry in self.catalog)if([entry[@"id"] isEqual:identifier]&&[entry[@"file"] isEqual:[entry[@"file"] lastPathComponent]]&&[entry[@"sha256"] length]==64&&[entry[@"bytes"] unsignedLongLongValue]>0)return entry;return nil;}
+ (NSString *)verifiedPath:(NSString *)identifier error:(NSError **)error{
 NSDictionary *entry=[self entry:identifier];NSString *path=entry?[self.directory stringByAppendingPathComponent:entry[@"file"]]:nil;NSDictionary *a=path?[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil]:nil;
 if(![a[NSFileType] isEqual:NSFileTypeRegular]||![path isEqual:path.stringByResolvingSymlinksInPath]||[a[NSFileSize] unsignedLongLongValue]!=[entry[@"bytes"] unsignedLongLongValue]){if(error)*error=RError(@"资源尚未下载或文件不完整，请在“安装工具”中下载后重试。");return nil;}
 // Cache the hash only for an unchanged inode/size/mtime within this process.
 static NSMutableDictionary *verified;static dispatch_once_t once;dispatch_once(&once,^{verified=[NSMutableDictionary new];});
 NSArray *stamp=@[a[NSFileSystemFileNumber]?:@0,a[NSFileSize],a[NSFileModificationDate]?:@0,entry[@"sha256"]];
 @synchronized(verified){if(![verified[path] isEqual:stamp]){if(![Digest(path) isEqual:entry[@"sha256"]]){if(error)*error=RError(@"资源 SHA-256 校验失败，请删除下载并重试。");return nil;}verified[path]=stamp;}}
 return path;
}
- (NSDictionary *)status:(NSString *)identifier{@synchronized(self){return [self.states[identifier] copy]?:@{@"state":@"notDownloaded",@"progress":@0};}}
- (void)state:(NSString *)state identifier:(NSString *)identifier progress:(double)progress error:(NSError *)error{
 @synchronized(self){self.states[identifier]=@{@"state":state,@"progress":@(progress),@"error":error.localizedDescription?:@""};}
 dispatch_async(dispatch_get_main_queue(),^{[NSNotificationCenter.defaultCenter postNotificationName:DXResourceStatusChanged object:identifier];});
}
- (void)fetch:(NSString *)identifier completion:(void(^)(NSString *,NSError *))completion{
 dispatch_async(dispatch_get_main_queue(),^{
  NSMutableDictionary *existing=self.jobs[identifier];if(existing){[existing[@"callbacks"] addObject:[completion copy]];return;}
  NSDictionary *entry=[self.class entry:identifier];NSURL *url=[NSURL URLWithString:entry[@"url"]?:@""];
  if(!entry||![url.scheme isEqual:@"https"]||url.user||url.password){completion(nil,RError(@"下载清单无效；没有发起请求。"));return;}
  NSMutableDictionary *job=[@{@"id":identifier,@"entry":entry,@"callbacks":[NSMutableArray arrayWithObject:[completion copy]]} mutableCopy];self.jobs[identifier]=job;
  [self state:@"checking" identifier:identifier progress:0 error:nil];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
   NSString *cached=[self.class verifiedPath:identifier error:nil];NSError *error=nil;
   if(!cached){NSString *directory=self.class.directory;[NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error];if(![directory isEqual:directory.stringByResolvingSymlinksInPath])error=RError(@"下载目录不允许符号链接。");NSDictionary *space=[NSFileManager.defaultManager attributesOfFileSystemForPath:directory error:nil];if(space&&[space[NSFileSystemFreeSize] unsignedLongLongValue]<[entry[@"bytes"] unsignedLongLongValue]*2+32*1024*1024)error=RError(@"可用空间不足，请先清理存储后重试。");}
   dispatch_async(dispatch_get_main_queue(),^{
    if(self.jobs[identifier]!=job)return;
    if(cached||error){[self finish:identifier path:cached error:error];return;}
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.URLCache=nil;config.HTTPCookieStorage=nil;config.timeoutIntervalForRequest=60;config.timeoutIntervalForResource=1800;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];[request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];NSURLSessionDownloadTask *task=[session downloadTaskWithRequest:request];job[@"session"]=session;job[@"task"]=task;[self state:@"downloading" identifier:identifier progress:0 error:nil];[task resume];
   });
  });
 });
}
- (NSMutableDictionary *)jobForTask:(NSURLSessionTask *)task{for(NSMutableDictionary *job in self.jobs.allValues)if(job[@"task"]==task)return job;return nil;}
- (void)finish:(NSString *)identifier path:(NSString *)path error:(NSError *)error{
 NSMutableDictionary *job=self.jobs[identifier];if(!job)return;NSArray *callbacks=[job[@"callbacks"] copy];[self.jobs removeObjectForKey:identifier];[job[@"session"] invalidateAndCancel];[self state:error?@"failed":@"downloaded" identifier:identifier progress:error?0:1 error:error];for(void(^callback)(NSString *,NSError *) in callbacks)callback(path,error);
}
- (void)cancel:(NSString *)identifier{dispatch_async(dispatch_get_main_queue(),^{NSMutableDictionary *job=self.jobs[identifier];if(!job)return;[job[@"task"] cancel];[self finish:identifier path:nil error:RError(@"下载已取消，可点击重试。")];});}
- (BOOL)remove:(NSString *)identifier error:(NSError **)error{
 NSAssert(NSThread.isMainThread,@"Resource removal is serialized on main thread");if(self.jobs[identifier]){if(error)*error=RError(@"资源正在下载或校验，请先取消或等待完成。");return NO;}NSDictionary *entry=[self.class entry:identifier];if(!entry){if(error)*error=RError(@"资源标识无效");return NO;}
 NSString *path=[self.class.directory stringByAppendingPathComponent:entry[@"file"]];if([NSFileManager.defaultManager fileExistsAtPath:path]&&![NSFileManager.defaultManager removeItemAtPath:path error:error])return NO;[self state:@"notDownloaded" identifier:identifier progress:0 error:nil];return YES;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void(^)(NSURLRequest *))handler{handler(nil);}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)written totalBytesWritten:(int64_t)total totalBytesExpectedToWrite:(int64_t)expected{
 NSDictionary *job=[self jobForTask:task];if(!job)return;uint64_t limit=[job[@"entry"][@"bytes"] unsignedLongLongValue];if(total>limit||expected>(int64_t)limit){[task cancel];[self finish:job[@"id"] path:nil error:RError(@"下载大小超过固定清单，已拒绝安装。")];return;}double p=limit?(double)total/limit:0;if(fabs(p-[[self status:job[@"id"]][@"progress"] doubleValue])>=.01)[self state:@"downloading" identifier:job[@"id"] progress:p error:nil];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:(NSURL *)url{
 NSMutableDictionary *job=[self jobForTask:task];if(!job)return;NSString *identifier=job[@"id"];NSHTTPURLResponse *response=(id)task.response;
 if(response.statusCode!=200){[self finish:identifier path:nil error:RError([NSString stringWithFormat:@"官网资源下载失败 HTTP %ld；请确认资源已部署后重试。",(long)response.statusCode])];return;}
 NSString *staging=[self.class.directory stringByAppendingPathComponent:[@".partial-" stringByAppendingString:NSUUID.UUID.UUIDString]];NSError *error=nil;if(![NSFileManager.defaultManager moveItemAtPath:url.path toPath:staging error:&error]){[self finish:identifier path:nil error:error];return;}
 [self state:@"verifying" identifier:identifier progress:1 error:nil];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSDictionary *entry=job[@"entry"],*attrs=[NSFileManager.defaultManager attributesOfItemAtPath:staging error:nil];BOOL valid=[attrs[NSFileSize] unsignedLongLongValue]==[entry[@"bytes"] unsignedLongLongValue]&&[Digest(staging) isEqual:entry[@"sha256"]];
  dispatch_async(dispatch_get_main_queue(),^{NSError *e=nil;NSString *target=[self.class.directory stringByAppendingPathComponent:entry[@"file"]];if(self.jobs[identifier]!=job){[NSFileManager.defaultManager removeItemAtPath:staging error:nil];return;}
   if(!valid)e=RError(@"下载资源大小或 SHA-256 不符，未安装；可重试。");else{[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:staging error:nil];[NSFileManager.defaultManager removeItemAtPath:target error:nil];if(![NSFileManager.defaultManager moveItemAtPath:staging toPath:target error:&e]){} }
   [NSFileManager.defaultManager removeItemAtPath:staging error:nil];[self finish:identifier path:e?nil:target error:e];
  });
 });
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{NSDictionary *job=[self jobForTask:task];if(error&&job)[self finish:job[@"id"] path:nil error:RError([NSString stringWithFormat:@"下载未完成：%@。可点击重试。",error.localizedDescription])];}
@end

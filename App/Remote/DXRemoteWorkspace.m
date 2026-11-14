#import "../AI/Sandbox/TFAIISHRemote.h"
#import "../AI/Actions/TFAISessionResources.h"
#import "../AI/Providers/TFAIRegistry.h"
#import "../AI/Persona/TFAIPersona.h"
#import "../AI/Registry/TFAIToolRegistry.h"
#import "../AI/Agent/TFAIAgentContext.h"
#import "../AI/Agent/TFAIBuildQueue.h"
#import "../AI/UI/TFAIModels.h"
#import "../AI/Providers/TFAIProtocol.h"
#import "DXRemoteWorkspace.h"
#import "DXRemoteAccess.h"
#import "DXRemoteHTTP.h"
#import "DXFlexBridge.h"
#import "../AI/AIV2Contracts.h"
#import "../AI/Permissions/TFAIPolicy.h"
#import "../AI/Binary/TFAIBinary.h"
#import "../AI/ClassDump/TFAIClassDump.h"
#import "../AI/ClassDump/TFAIClassDumpExecution.h"
#import "../AI/Tools/TFAIBuildCache.h"
#import "../ProjectSafety.h"
#import "../GitService.h"
#import "../GitPreferences.h"
#import "../ArchiveImport.h"
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <CommonCrypto/CommonDigest.h>
static NSError *DXError(NSString *text){return [NSError errorWithDomain:@"Dylix.Remote.Workspace" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}
static NSString *DXDocs(void){return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;}
// Same sandbox path policy; permit inert distributable files for storage only.
static NSString *DXFilePath(NSString *relative,BOOL directory,NSError **error){
 NSString *probe=relative;if([@[@"dylib",@"deb",@"ipa"] containsObject:relative.pathExtension.lowercaseString])probe=[relative.stringByDeletingPathExtension stringByAppendingPathExtension:@"txt"];
 if(!TFAISafePath(DXDocs(),probe,directory,error))return nil;
 NSString *path=[DXDocs() stringByAppendingPathComponent:relative];NSString *walk=DXDocs();
 for(NSString *part in relative.pathComponents){walk=[walk stringByAppendingPathComponent:part];struct stat st;if(lstat(walk.fileSystemRepresentation,&st)==0&&(S_ISLNK(st.st_mode)||(!S_ISREG(st.st_mode)&&!S_ISDIR(st.st_mode)))){if(error)*error=DXError(@"文件管理不跟随符号链接或特殊文件");return nil;}}
 BOOL isDirectory=NO;if(!directory&&[NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory]&&isDirectory){if(error)*error=DXError(@"目标为文件夹，请更换文件名");return nil;}return path;
}
// Incremental hash: no whole-file allocation and no CC_LONG truncation above 4GiB.
static NSString *DXFileDigest(NSString *path,NSError **error){
 int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);if(fd<0){if(errno==ENOENT)return @"missing";if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];return nil;}
 CC_SHA256_CTX hash;CC_SHA256_Init(&hash);unsigned char buffer[64*1024];ssize_t n;while((n=read(fd,buffer,sizeof(buffer)))>0)CC_SHA256_Update(&hash,buffer,(CC_LONG)n);int failure=errno;close(fd);if(n<0){if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:failure userInfo:nil];return nil;}unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(digest,&hash);NSMutableString *value=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[value appendFormat:@"%02x",digest[i]];return value;
}
#import "DXRemoteSanitize.h"
@interface DXRemoteWorkspace ()
@property dispatch_queue_t queue;
@property NSMutableDictionary *jobs,*owners,*toolboxes,*runtimes,*decisions,*downloads,*uploads;
@property(atomic) NSUInteger generation;
@end
@implementation DXRemoteWorkspace
- (instancetype)initWithQueue:(dispatch_queue_t)queue{if((self=[super init])){_queue=queue;_jobs=[NSMutableDictionary new];_owners=[NSMutableDictionary new];_toolboxes=[NSMutableDictionary new];_runtimes=[NSMutableDictionary new];_decisions=[NSMutableDictionary new];_downloads=[NSMutableDictionary new];_uploads=[NSMutableDictionary new];}return self;}
- (void)finish:(NSMutableDictionary *)job result:(id)result error:(NSError *)error{
 if([job[@"state"] isEqual:@"cancelled"])return;job[@"state"]=error?@"failed":@"completed";job[@"finishedAt"]=@(NSDate.date.timeIntervalSince1970);job[@"result"]=Clean(result?:@{});if(error)job[@"error"]=error.localizedDescription;
 [self.decisions removeObjectForKey:job[@"id"]];[self.toolboxes removeObjectForKey:job[@"id"]];
}
- (void)await:(NSMutableDictionary *)job summary:(NSDictionary *)summary execute:(void(^)(void))execute{
 if([job[@"state"] isEqual:@"cancelled"])return;job[@"state"]=@"awaiting_confirmation";job[@"confirmation"]=Clean(summary);job[@"nonce"]=DXRemoteRandom();job[@"expiresAt"]=@(NSDate.date.timeIntervalSince1970+120);self.decisions[job[@"id"]]=[execute copy];
}
- (NSDictionary *)job:(NSString *)identifier device:(NSString *)device{
 NSMutableDictionary *j=self.jobs[identifier];if(!j||![j[@"device"] isEqual:device])return @{@"error":@"任务不存在"};
 if([j[@"state"] isEqual:@"awaiting_confirmation"]&&[j[@"expiresAt"] doubleValue]<NSDate.date.timeIntervalSince1970){[self cancel:identifier device:device];j[@"error"]=@"确认已过期，未执行";}
 NSMutableDictionary *copy=[j mutableCopy];[copy removeObjectForKey:@"device"];[copy removeObjectForKey:@"request"];return copy;
}
- (NSDictionary *)confirm:(NSString *)identifier nonce:(NSString *)nonce accepted:(BOOL)accepted device:(NSString *)device{
 NSMutableDictionary *j=self.jobs[identifier];if(!j||![j[@"device"] isEqual:device]||![j[@"state"] isEqual:@"awaiting_confirmation"]||![j[@"nonce"] isEqual:nonce]||[j[@"expiresAt"] doubleValue]<NSDate.date.timeIntervalSince1970)return @{@"error":@"确认无效或已过期"};
 void(^execute)(void)=self.decisions[identifier];[self.decisions removeObjectForKey:identifier];[j removeObjectForKey:@"nonce"];if(!accepted)return [self cancel:identifier device:device];j[@"state"]=@"running";if(execute)execute();return [self job:identifier device:device];
}
- (NSDictionary *)cancel:(NSString *)identifier device:(NSString *)device{
 NSMutableDictionary *j=self.jobs[identifier];if(!j||![j[@"device"] isEqual:device])return @{@"error":@"任务不存在"};
 if([@[@"completed",@"failed",@"cancelled"] containsObject:j[@"state"]])return [self job:identifier device:device];
 id<TFAIRuntime> runtime=self.runtimes[identifier];TFAIToolbox *toolbox=self.toolboxes[identifier];NSMutableDictionary *owner=self.owners[[NSString stringWithFormat:@"%@/%@",device,j[@"projectID"]?:@""]];
 if([j[@"action"] isEqual:@"build"]&&[j[@"state"] isEqual:@"running"]){j[@"cancelRequested"]=@YES;dispatch_async(dispatch_get_main_queue(),^{DXStudioWorkspace(owner,@"cancel_build",@{},^(NSDictionary *r,NSError *e){dispatch_async(self.queue,^{j[@"cancellation"]=r?:@{};});});});return [self job:identifier device:device];}
 [self.decisions removeObjectForKey:identifier];dispatch_async(dispatch_get_main_queue(),^{[runtime stop];[toolbox cancel];});j[@"state"]=@"cancelled";j[@"finishedAt"]=@(NSDate.date.timeIntervalSince1970);return [self job:identifier device:device];
}
- (void)revoke:(NSString *)device{[TFAIISHRemote revokeDevice:device];[[DXFlexBridge shared] revokeDevice:device];for(NSString *key in self.owners){if(!device||[key hasPrefix:[device stringByAppendingString:@"/"]]){[self.owners[key] removeObjectForKey:@"remoteAutosaveGrant"];[self.owners[key] removeObjectForKey:@"flexSessionGrants"];}}for(NSString *key in self.uploads.allKeys){NSDictionary *input=self.uploads[key];if(!device||[input[@"device"] isEqual:device]){[NSFileManager.defaultManager removeItemAtPath:input[@"path"] error:nil];[self.uploads removeObjectForKey:key];}}for(NSString *identifier in self.jobs.allKeys){NSDictionary *j=self.jobs[identifier];if(!device||[j[@"device"] isEqual:device])[self cancel:identifier device:j[@"device"]];}for(NSString *key in self.downloads.allKeys)if(!device||[self.downloads[key][@"device"] isEqual:device])[self.downloads removeObjectForKey:key];}
- (void)stop{self.generation++;[self revoke:nil];for(NSDictionary *input in self.uploads.allValues)[NSFileManager.defaultManager removeItemAtPath:input[@"path"] error:nil];[self.uploads removeAllObjects];}
- (NSDictionary *)download:(NSString *)identifier device:(NSString *)device{
 NSDictionary *entry=self.downloads[identifier];if(!entry||![entry[@"device"] isEqual:device]||[entry[@"expires"] doubleValue]<NSDate.date.timeIntervalSince1970)return DXRemoteResponse(404,@{@"error":@"下载链接已过期"});
 NSString *path=entry[@"path"];NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];if(![attrs[NSFileType] isEqual:NSFileTypeRegular])return DXRemoteResponse(404,@{@"error":@"文件已不存在或类型已变化"});
 return @{@"status":@200,@"type":@"application/octet-stream",@"filePath":path,@"headers":@{@"Content-Disposition":@"attachment"}};
}
- (NSDictionary *)registerDownload:(NSString *)path name:(NSString *)name device:(NSString *)device{
 NSString *identifier=DXRemoteRandom();if(!identifier)return @{};self.downloads[identifier]=@{@"path":path,@"device":device,@"expires":@(NSDate.date.timeIntervalSince1970+300)};return @{@"name":name?:path.lastPathComponent,@"url":[@"/api/v1/download/" stringByAppendingString:identifier]};
}
- (NSDictionary *)submit:(NSDictionary *)request device:(NSString *)device{
 if(self.jobs.count>=100){for(NSString *key in self.jobs.allKeys){if([@[@"completed",@"failed",@"cancelled"] containsObject:self.jobs[key][@"state"]]){[self.jobs removeObjectForKey:key];if(self.jobs.count<60)break;}}}
 NSUInteger active=0;for(NSDictionary *j in self.jobs.allValues)if(![@[@"completed",@"failed",@"cancelled"] containsObject:j[@"state"]])active++;
 if(active>=8)return @{@"error":@"已有 8 个任务，请等待完成"};
 NSString *action=request[@"action"],*project=request[@"projectID"]?:@"";NSDictionary *args=request[@"arguments"]?:@{};
 if(![action isKindOfClass:NSString.class]||![project isKindOfClass:NSString.class]||![args isKindOfClass:NSDictionary.class])return @{@"error":@"操作参数错误"};
 for(NSString *key in @[@"path",@"destination",@"name",@"sha256",@"text",@"data",@"query",@"operation",@"message",@"sdkVersion",@"deploymentTarget",@"cxxStandard",@"symbolPolicy",@"sessionID",@"connectionID",@"model",@"reasoningEffort",@"mode",@"buildID",@"inputID",@"backupID",@"template"]){if(args[key]&&![args[key] isKindOfClass:NSString.class])return @{@"error":@"字段类型应为字符串"};}
 for(NSString *key in @[@"paths",@"build_ids"]){if(args[key]&&![args[key] isKindOfClass:NSArray.class])return @{@"error":@"字段类型应为数组"};}
 if([action isEqual:@"input_chunk"]&&(![args[@"offset"] isKindOfClass:NSNumber.class]||[args[@"offset"] doubleValue]<0||[args[@"offset"] doubleValue]>=(double)NSUIntegerMax||[args[@"offset"] doubleValue]!=(double)[args[@"offset"] unsignedIntegerValue]))return @{@"error":@"上传偏移需为有效的非负整数"};
 if(args[@"options"]&&![args[@"options"] isKindOfClass:NSDictionary.class])return @{@"error":@"分析选项应为对象"};
 NSString *identifier=NSUUID.UUID.UUIDString;NSMutableDictionary *job=[@{@"id":identifier,@"device":device,@"action":action,@"projectID":project,@"state":@"running",@"startedAt":@(NSDate.date.timeIntervalSince1970),@"request":request} mutableCopy];self.jobs[identifier]=job;
 NSUInteger generation=self.generation;
 dispatch_async(dispatch_get_main_queue(),^{
  if(generation!=self.generation)return;
  NSArray *projects=TFAIInternalProjects();NSDictionary *selected=nil;for(NSDictionary *p in projects)if([p[@"id"] isEqual:project])selected=p;
  NSString *root=selected[@"root"];
  dispatch_async(self.queue,^{
   if(generation!=self.generation||[job[@"state"] isEqual:@"cancelled"])return;
   if([action hasPrefix:@"terminal_"]){NSString *operation=[action substringFromIndex:9],*session=args[@"sessionID"];BOOL belongs=NO;if(root.length&&[session isKindOfClass:NSString.class])for(NSDictionary *record in [TFAISessions sessions:project])if([record[@"id"] isEqual:session])belongs=YES;if(!belongs){[self finish:job result:nil error:DXError(@"请选择当前项目的真实会话后访问终端")];return;}void(^execute)(void)=^{dispatch_async(dispatch_get_main_queue(),^{[TFAIISHRemote perform:operation arguments:args session:session device:device completion:^(NSDictionary *r,NSError *e){dispatch_async(self.queue,^{[self finish:job result:r error:e];});}];});};if([@[@"status",@"read"] containsObject:operation])execute();else [self await:job summary:@{@"summary":@"执行已获手机会话授权的 Linux 终端操作",@"operation":operation,@"sessionID":session} execute:execute];return;}
   if([action isEqual:@"projects"]){[self finish:job result:@{@"projects":projects} error:nil];return;}
   if([action isEqual:@"flex_publish"]){NSError *error=nil;NSDictionary *result=[[DXFlexBridge shared] publish:args device:device error:&error];[self finish:job result:result error:error];return;}
   if([action isEqual:@"tasks"]){NSMutableArray *a=[NSMutableArray new];for(NSString *key in self.jobs.allKeys)if([self.jobs[key][@"device"] isEqual:device]&&![self.jobs[key][@"action"] isEqual:@"tasks"]){NSMutableDictionary *summary=[[self job:key device:device] mutableCopy];[summary removeObjectForKey:@"result"];[summary removeObjectForKey:@"live"];[summary removeObjectForKey:@"confirmation"];[summary removeObjectForKey:@"nonce"];[a addObject:summary];}[self finish:job result:@{@"tasks":a} error:nil];return;}
   if([action isEqual:@"create_project"]){[self await:job summary:@{@"summary":@"在手机创建项目",@"arguments":args} execute:^{NSMutableDictionary *owner=[NSMutableDictionary new];dispatch_async(dispatch_get_main_queue(),^{DXStudioWorkspace(owner,action,args,^(NSDictionary *r,NSError *e){dispatch_async(self.queue,^{[self finish:job result:r error:e];});});});}];return;}
   if([action isEqual:@"input_chunk"]){[self input:job arguments:args];return;}
   if([action isEqual:@"input_discard"]){NSDictionary *input=self.uploads[args[@"inputID"]?:@""];if([input[@"device"] isEqual:device]){[NSFileManager.defaultManager removeItemAtPath:input[@"path"] error:nil];[self.uploads removeObjectForKey:args[@"inputID"]];}[self finish:job result:@{} error:nil];return;}
   if([action isEqual:@"import_project"]){
    NSString *inputID=args[@"inputID"]; NSMutableDictionary *upload=inputID?self.uploads[inputID]:nil;
    if(!upload||![upload[@"device"] isEqual:device]){[self finish:job result:nil error:DXError(@"上传输入不存在或不属于当前设备")];return;}
    NSString *name=args[@"name"]; if(![name isKindOfClass:NSString.class]||name.length<1||name.length>80||[name hasPrefix:@"."]||[name containsString:@"/"]||[name containsString:@"\\"]){[self finish:job result:nil error:DXError(@"项目名称无效")];return;}
    [self await:job summary:@{@"summary":@"导入项目",@"name":name} execute:^{
      dispatch_async(TMCGitService.queue,^{ NSError *e=nil; NSString *dest=[DXDocs() stringByAppendingPathComponent:[@"Imported-" stringByAppendingString:NSUUID.UUID.UUIDString]]; NSFileManager *fm=NSFileManager.defaultManager; // TMCExtractArchive creates its new private destination.
       if(!e&&!TMCExtractArchive([NSURL fileURLWithPath:upload[@"path"]],[NSURL fileURLWithPath:dest],nil,nil,nil,&e)){}
       NSArray *candidates=!e?TMCArchiveProjects(dest,nil,&e):nil; NSDictionary *candidate=candidates.firstObject; NSString *root=candidate[@"root"];
       if(!e&&root.length&&![root isEqual:dest]){NSString *staging=[dest stringByAppendingPathComponent:@".source"]; [fm moveItemAtPath:root toPath:staging error:&e]; if(!e){for(NSString *entry in [fm contentsOfDirectoryAtPath:staging error:nil]){NSString *from=[staging stringByAppendingPathComponent:entry],*to=[dest stringByAppendingPathComponent:entry]; if(![fm moveItemAtPath:from toPath:to error:&e])break;} [fm removeItemAtPath:staging error:nil];}}
       if(!e)TMCPrepareImportedProject(dest,name,&e); if(e){[fm removeItemAtPath:dest error:nil];}
       dispatch_async(self.queue,^{[self.uploads removeObjectForKey:inputID];[fm removeItemAtPath:upload[@"path"] error:nil]; NSArray *ps=TFAIInternalProjects(); NSDictionary *found=nil; for(NSDictionary *p in ps)if([p[@"root"] isEqual:dest])found=p; [self finish:job result:found?:@{} error:e];});
      });
    }]; return;
   }
   if([action hasPrefix:@"sandbox_"]){
    NSString *relative=args[@"path"]?:@"";BOOL protected=NO;for(NSString *component in relative.pathComponents)if([component hasPrefix:@"."]||[component hasPrefix:@"RemoteTest"]||[@[@"Library",@"DylixRemote",@"RemoteBrowserFixture.json"] containsObject:component])protected=YES;
    if(protected){[self finish:job result:nil error:DXError(@"此目录属于应用私有配置")];return;}
    if([action isEqual:@"sandbox_upload_probe"]){dispatch_async(TMCGitService.queue,^{NSError *e=nil;NSString *path=DXFilePath(relative,NO,&e);NSFileManager *fm=NSFileManager.defaultManager;BOOL directory=NO;if(path&&![fm fileExistsAtPath:path.stringByDeletingLastPathComponent isDirectory:&directory])e=DXError(@"目标文件夹已不存在，请刷新");if(path&&!directory)e=DXError(@"目标路径不是文件夹");NSDictionary *a=path?[fm attributesOfItemAtPath:path error:nil]:nil;NSString *digest=path&&!e?DXFileDigest(path,&e):nil;dispatch_async(self.queue,^{[self finish:job result:@{@"exists":@(a!=nil),@"sha256":digest?:@"missing",@"bytes":a[NSFileSize]?:@0} error:e];});});return;}
    if([action isEqual:@"sandbox_upload"]){
     NSDictionary *input=self.uploads[args[@"inputID"]?:@""];if(![input[@"device"] isEqual:device]){[self finish:job result:nil error:DXError(@"上传输入不存在或不属于当前设备")];return;}
     [self await:job summary:@{@"summary":[args[@"sha256"] isEqual:@"missing"]?@"上传文件到当前文件夹":@"覆盖同名文件（原文件会备份）",@"path":relative,@"bytes":input[@"bytes"],@"beforeHash":args[@"sha256"]?:@""} execute:^{
      dispatch_async(TMCGitService.queue,^{NSError *e=nil;NSFileManager *fm=NSFileManager.defaultManager;TMCGitLease *lease __attribute__((objc_precise_lifetime))=[TMCGitLease tryWrite];if(!lease)e=DXError(@"Git或文件任务正在处理，请稍后上传");NSString *path=e?nil:DXFilePath(relative,NO,&e);
       for(NSDictionary *p in projects)if([path hasPrefix:[p[@"root"] stringByAppendingString:@"/"]]&&[TMCGitLease isBuilding:p[@"root"]])e=DXError(@"目标项目正在构建，请完成后上传");
       NSDictionary *attrs=path?[fm attributesOfItemAtPath:path error:nil]:nil;NSString *beforeHash=!e?DXFileDigest(path,&e):nil;if(!e&&![beforeHash isEqual:args[@"sha256"]])e=DXError(@"409：文件已被手机或其他客户端修改，请刷新后重新上传");
       NSString *backup=nil;if(!e&&attrs){NSString *dir=[DXDocs() stringByAppendingPathComponent:@".studio-remote-backups"];[fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&e];backup=[dir stringByAppendingPathComponent:NSUUID.UUID.UUIDString];if(!e)[fm copyItemAtPath:path toPath:backup error:&e];if(!e)TFAIWriteJSON(@{@"path":relative,@"date":@(NSDate.date.timeIntervalSince1970)},[backup stringByAppendingString:@".json"],&e);}
       NSDictionary *staged=!e?[fm attributesOfItemAtPath:input[@"path"] error:&e]:nil;if(!e&&[staged[NSFileSize] unsignedLongLongValue]!=[input[@"bytes"] unsignedLongLongValue])e=DXError(@"上传暂存内容已变化，请重试");
       NSString *temporary=[path.stringByDeletingLastPathComponent stringByAppendingPathComponent:[@".RemoteIncoming-" stringByAppendingString:NSUUID.UUID.UUIDString]];
       if(!e)[fm copyItemAtPath:input[@"path"] toPath:temporary error:&e];
       if(!e&&![DXFileDigest(path,&e) isEqual:beforeHash])e=DXError(@"409：复制期间目标文件已变化，请刷新后重试");
       if(!e){if(attrs){if(rename(temporary.fileSystemRepresentation,path.fileSystemRepresentation)!=0)e=[NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];}else [fm moveItemAtPath:temporary toPath:path error:&e];}
       if(temporary)[fm removeItemAtPath:temporary error:nil];
       dispatch_async(self.queue,^{[fm removeItemAtPath:input[@"path"] error:nil];[self.uploads removeObjectForKey:args[@"inputID"]];[self finish:job result:@{@"path":relative,@"bytes":input[@"bytes"],@"backupID":backup.lastPathComponent?:@""} error:e];});
      });
     }];return;
    }
    if([action isEqual:@"sandbox_list"]){dispatch_async(TMCGitService.queue,^{NSError *e=nil;NSString *directory=relative.length?TFAISafePath(DXDocs(),relative,YES,&e):DXDocs();NSMutableArray *entries=[NSMutableArray new];NSArray *names=directory?[NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:&e]:nil;for(NSString *name in names){if([name hasPrefix:@"."]||[name hasPrefix:@"RemoteTest"]||[name isEqual:@"RemoteBrowserFixture.json"])continue;NSString *child=relative.length?[relative stringByAppendingPathComponent:name]:name;NSString *full=DXFilePath(child,YES,nil);if(!full)continue;NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:full error:nil];[entries addObject:@{@"path":child,@"name":name,@"folder":@([attrs[NSFileType] isEqual:NSFileTypeDirectory]),@"bytes":attrs[NSFileSize]?:@0,@"modified":@([attrs[NSFileModificationDate] timeIntervalSince1970])}];if(entries.count>=4000)break;}dispatch_async(self.queue,^{[self finish:job result:@{@"path":relative,@"entries":entries,@"limited":@(entries.count>=4000)} error:e];});});return;}
    if([@[@"sandbox_read",@"sandbox_download"] containsObject:action]){[self perform:job action:[action substringFromIndex:8] arguments:args root:DXDocs() owner:[NSMutableDictionary new]];return;}
    [self finish:job result:nil error:DXError(@"文件浏览操作无效")];return;
   }
   if(!root){[self finish:job result:nil error:DXError(@"请选择现有项目，外部路径须先通过手机导入")];return;}
   NSString *ownerKey=[NSString stringWithFormat:@"%@/%@",device,project];NSMutableDictionary *owner=self.owners[ownerKey];if(!owner){owner=[NSMutableDictionary new];self.owners[ownerKey]=owner;}
   if([action isEqual:@"flex_tool_permission"]){
    NSString *sid=args[@"sessionID"];
    if(!sid.length||![TFAISessions loadSession:sid project:project]){[self finish:job result:nil error:DXError(@"请先创建或选择当前项目的会话")];return;}
    NSMutableDictionary *grants=owner[@"flexSessionGrants"];if(!grants){grants=[NSMutableDictionary new];owner[@"flexSessionGrants"]=grants;}
    NSDictionary *(^state)(void)=^NSDictionary *{return @{@"sessionID":sid,@"enabled":@([grants[sid] boolValue]),@"scope":@"conversation"};};
    if(!args[@"enabled"]){[self finish:job result:state() error:nil];return;}
    if(![args[@"enabled"] isKindOfClass:NSNumber.class]){[self finish:job result:nil error:DXError(@"FLEX 权限开关无效")];return;}
    if(![args[@"enabled"] boolValue]){[grants removeObjectForKey:sid];[self finish:job result:state() error:nil];return;}
    if([grants[sid] boolValue]){[self finish:job result:state() error:nil];return;}
    [self await:job summary:@{@"summary":@"授权本会话全部 FLEX 工具",@"project":selected[@"name"]?:project,@"details":@"包含 FLEX 敏感读取、截图、触摸、视图和录制控制。本会话有效，无时间限制，可随时撤销；撤销设备授权或停止服务后结束。项目写入、构建和 Git 仍按原流程审批。"} execute:^{if(![TFAISessions loadSession:sid project:project]){[self finish:job result:nil error:DXError(@"会话已删除")];return;}grants[sid]=@YES;[self finish:job result:state() error:nil];}];return;
   }
   if([action isEqual:@"editor_autosave_status"]){[self finish:job result:@{@"enabled":@([owner[@"remoteAutosaveGrant"] length]>0)} error:nil];return;}
   if([action isEqual:@"editor_autosave"]){
    if(![args[@"enabled"] isKindOfClass:NSNumber.class]){[self finish:job result:nil error:DXError(@"自动保存开关参数无效")];return;}
    if(![args[@"enabled"] boolValue]){[owner removeObjectForKey:@"remoteAutosaveGrant"];[self finish:job result:@{@"enabled":@NO} error:nil];return;}
    if([owner[@"remoteAutosaveGrant"] length]){[self finish:job result:@{@"enabled":@YES} error:nil];return;}
    [self await:job summary:@{@"summary":@"开启当前项目的自动保存",@"project":selected[@"name"]?:project,@"details":@"停止输入1.5秒后保存已打开的文本文件；保留版本校验与修改前备份。关闭开关、撤销设备授权或停止服务后结束授权。"} execute:^{owner[@"remoteAutosaveGrant"]=DXRemoteRandom();[self finish:job result:@{@"enabled":@YES} error:nil];}];return;
   }
   [self perform:job action:action arguments:args root:root owner:owner];
  });
 });return [self job:identifier device:device];
}
- (void)withOwner:(NSMutableDictionary *)owner project:(NSString *)project completion:(void(^)(NSError *))completion{
 dispatch_async(dispatch_get_main_queue(),^{DXStudioWorkspace(owner,@"select_project",@{@"project_id":project},^(NSDictionary *r,NSError *error){dispatch_async(self.queue,^{completion(error);});});});
}
- (void)tool:(NSString *)tool arguments:(NSDictionary *)args job:(NSMutableDictionary *)job root:(NSString *)root owner:(NSMutableDictionary *)owner{
 TFAIToolbox *box=[[TFAIToolbox alloc]initWithRoot:root projectID:job[@"projectID"] sessionID:job[@"id"]];self.toolboxes[job[@"id"]]=box;
 box.bridge=^(NSString *name,NSDictionary *arguments,TFAIResult completion){[self withOwner:owner project:job[@"projectID"] completion:^(NSError *e){if(e){completion(nil,e);return;}dispatch_async(dispatch_get_main_queue(),^{DXStudioWorkspace(owner,name,arguments,completion);});}];};
 [box setApprovalContext:@"remote.explicit.browser.confirmation"];
 [box prepare:@{@"id":job[@"id"],@"name":tool,@"arguments":args} completion:^(NSDictionary *plan,NSError *error){dispatch_async(self.queue,^{
  if(error){[self finish:job result:nil error:error];return;}
  void(^execute)(void)=^{[box setApprovalContext:@"explicit-preview"];[box execute:plan approved:YES completion:^(NSDictionary *r,NSError *e){dispatch_async(self.queue,^{
   if(!e&&r[@"proposal_id"]){[box prepare:@{@"id":NSUUID.UUID.UUIDString,@"name":@"apply_approved_patch",@"arguments":@{@"proposal_id":r[@"proposal_id"]}} completion:^(NSDictionary *apply,NSError *failure){dispatch_async(self.queue,^{if(failure){[self finish:job result:nil error:failure];return;}[self await:job summary:apply execute:^{[box setApprovalContext:@"explicit-preview"];[box execute:apply approved:YES completion:^(NSDictionary *value,NSError *err){dispatch_async(self.queue,^{[self finish:job result:value error:err];});}];}];});}];}else [self finish:job result:r error:e];
  });}];};
  if([plan[@"approval"] boolValue])[self await:job summary:plan execute:execute];else execute();
 });}];
}
- (void)perform:(NSMutableDictionary *)job action:(NSString *)action arguments:(NSDictionary *)args root:(NSString *)root owner:(NSMutableDictionary *)owner{
 NSDictionary *tools=@{@"files":@"list_files",@"search":@"search_text",@"config":@"read_project_config",@"builds":@"list_builds",@"diagnostics":@"read_diagnostics",@"artifacts":@"list_artifacts",@"git_status":@"git_status",@"git_diff":@"git_diff",@"git_history":@"git_history",@"git_stage":@"git_stage",@"git_commit":@"git_save_version",@"git_pull":@"git_download_updates",@"git_push":@"git_upload",@"mkdir":@"create_directory",@"new_file":@"create_file",@"delete_file":@"request_delete",@"extract":@"extract_archive",@"settings":@"propose_build_settings"};
 if([@[@"diagnostics",@"artifacts",@"builds"] containsObject:action]){[self withOwner:owner project:job[@"projectID"] completion:^(NSError *e){if(e)[self finish:job result:nil error:e];else [self tool:tools[action] arguments:args job:job root:root owner:owner];}];return;}
 if(tools[action]){[self tool:tools[action] arguments:args job:job root:root owner:owner];return;}
 if([action isEqual:@"build"]){[self await:job summary:@{@"summary":@"使用手机本机 Clang / LLD 构建当前项目"} execute:^{[self withOwner:owner project:job[@"projectID"] completion:^(NSError *error){if(error){[self finish:job result:nil error:error];return;}dispatch_async(dispatch_get_main_queue(),^{DXStudioWorkspace(owner,@"build_project",@{},^(NSDictionary *r,NSError *e){dispatch_async(self.queue,^{[self finish:job result:r error:e];});});[self monitor:job owner:owner];});}];}];return;}
 if([action hasPrefix:@"ai_"]){[self ai:job action:action arguments:args root:root owner:owner];return;}
 NSDictionary *input=self.uploads[args[@"inputID"]?:@""];NSString *stagedInput=[input[@"device"] isEqual:job[@"device"]]?input[@"path"]:nil;
 // All synchronous file/Git/analysis work shares the existing Git queue and lease.
 dispatch_async(TMCGitService.queue,^{@autoreleasepool{
  NSError *error=nil;id result=nil;
  if([action isEqual:@"tree"]){NSMutableArray *entries=[NSMutableArray new];NSDirectoryEnumerator *enumerator=[NSFileManager.defaultManager enumeratorAtPath:root];NSString *relative;while((relative=enumerator.nextObject)){if(entries.count>=2000)break;NSString *full=TFAISafePath(root,relative,YES,nil);if(!full){[enumerator skipDescendants];continue;}NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:full error:nil];BOOL folder=[attrs[NSFileType] isEqual:NSFileTypeDirectory];[entries addObject:@{@"path":relative,@"folder":@(folder),@"bytes":attrs[NSFileSize]?:@0,@"modified":@([attrs[NSFileModificationDate] timeIntervalSince1970])}];}result=@{@"entries":entries,@"limited":@(entries.count>=2000)};}
  else if([action isEqual:@"backups"]){NSMutableArray *backups=[NSMutableArray new];NSString *dir=[root stringByAppendingPathComponent:@".studio-remote-backups"];for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil])if([name.pathExtension isEqual:@"json"]){NSDictionary *meta=TFAIReadJSON([dir stringByAppendingPathComponent:name]);if([meta[@"path"] isEqual:args[@"path"]])[backups addObject:@{@"id":name.stringByDeletingPathExtension,@"date":meta[@"date"]?:@0}];}result=@{@"backups":backups};}
  else if([action isEqual:@"backup_read"]){NSString *identifier=args[@"backupID"];if(![[NSUUID alloc]initWithUUIDString:identifier])error=DXError(@"备份ID无效");else{NSString *path=[[root stringByAppendingPathComponent:@".studio-remote-backups"] stringByAppendingPathComponent:identifier];NSDictionary *meta=TFAIReadJSON([path stringByAppendingString:@".json"]);NSData *data=[NSData dataWithContentsOfFile:path];NSString *text=data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;if(!text||![meta[@"path"] isEqual:args[@"path"]]||TFAIContainsSecret(text))error=DXError(@"备份不存在或内容受保护");else result=@{@"text":text,@"path":meta[@"path"]};}}
  else if([action isEqual:@"export_project"]){NSString *temp=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"RemoteExport-" stringByAppendingString:NSUUID.UUID.UUIDString]],*directory=[temp stringByAppendingPathComponent:@"source"],*zip=[temp stringByAppendingPathComponent:@"project.zip"];if(TMCCopyProject(root,directory,YES,[NSProgress progressWithTotalUnitCount:1],nil,&error)&&TFAIClassDumpZip(directory,zip,&error)){dispatch_async(self.queue,^{[self finish:job result:[self registerDownload:zip name:@"project.zip" device:job[@"device"]] error:nil];});return;}}
  else if([action isEqual:@"read"]){NSString *path=TFAISafePath(root,args[@"path"],NO,&error);NSDictionary *a=path?[NSFileManager.defaultManager attributesOfItemAtPath:path error:&error]:nil;NSData *data=[a[NSFileSize] unsignedLongLongValue]<=1024*1024&&a?[NSData dataWithContentsOfFile:path options:0 error:&error]:nil;NSString *text=data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;if(!text&&!error)error=DXError(@"仅支持不超过 1MB 的 UTF-8 文本");if(TFAIContainsSecret(text))error=DXError(@"文件含疑似凭据，已隐藏内容");if(!error)result=@{@"path":args[@"path"],@"text":text,@"sha256":TFAIDigest(data),@"modified":@([a[NSFileModificationDate] timeIntervalSince1970])};}
  else if([action isEqual:@"git_branches"]){TMCGitService *git=[[TMCGitService alloc]initWithRoot:root];result=@{@"branches":[git branches:&error]?:@[]};}
  else if([@[@"save",@"copy",@"move",@"upload",@"restore",@"project_delete",@"git_init",@"git_branch"] containsObject:action]){
   dispatch_async(self.queue,^{
    if([action isEqual:@"save"]&&[args[@"automatic"] isKindOfClass:NSNumber.class]&&[args[@"automatic"] boolValue]){
     NSString *grant=owner[@"remoteAutosaveGrant"];if(!grant.length){[self finish:job result:nil error:DXError(@"自动保存授权已结束，请重新开启开关")];return;}
     job[@"autosaveGrant"]=grant;[self mutate:job action:action arguments:args root:root];return;
    }
    [self await:job summary:@{@"summary":action,@"path":args[@"path"]?:@"",@"destination":args[@"destination"]?:@"",@"beforeHash":args[@"sha256"]?:@"missing"} execute:^{[self mutate:job action:action arguments:args root:root];}];});return;
  }
  else if([action isEqual:@"download"]){NSString *path=[root isEqual:DXDocs()]?DXFilePath(args[@"path"],NO,&error):TFAISafePath(root,args[@"path"],NO,&error);if(path&&!error){NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:path error:&error];NSData *data=[attributes[NSFileSize] unsignedLongLongValue]<1024*1024&&!error?[NSData dataWithContentsOfFile:path options:0 error:&error]:nil;NSString *text=data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;if(TFAIContainsSecret(text))error=DXError(@"文件含疑似凭据");if(!error){dispatch_async(self.queue,^{[self finish:job result:[self registerDownload:path name:args[@"path"] device:job[@"device"]] error:nil];});return;}}}
  else if([action isEqual:@"artifact_download"]){NSString *build=args[@"buildID"],*name=args[@"name"];BOOL owned=NO;for(NSDictionary *b in TFAIProjectBuilds(root,DXDocs()))if([b[@"buildID"] isEqual:build])owned=YES;NSString *dir=[DXDocs() stringByAppendingPathComponent:build?:@""];NSDictionary *meta=TFAIReadJSON([dir stringByAppendingPathComponent:@".studio-cache-owner.json"]);if([meta[@"project"] isEqual:root])owned=YES;if(!owned||![build hasPrefix:@"Build-"]||![[NSUUID alloc]initWithUUIDString:[build substringFromIndex:6]]||![name isKindOfClass:NSString.class]||![name isEqual:name.lastPathComponent]||![@[@"dylib",@"deb",@"json",@"log"] containsObject:name.pathExtension])error=DXError(@"构建产物不属于当前项目");else{NSString *path=[dir stringByAppendingPathComponent:name];dispatch_async(self.queue,^{[self finish:job result:[self registerDownload:path name:name device:job[@"device"]] error:nil];});return;}}
  else if([action isEqual:@"analyze"]){NSData *data=stagedInput?[NSData dataWithContentsOfFile:stagedInput options:NSDataReadingMappedIfSafe error:&error]:[[NSData alloc]initWithBase64EncodedString:args[@"data"]?:@"" options:0];if(!data||data.length>32*1024*1024)error=DXError(@"分析输入限 32MB");else result=TFAIBinaryParse(data,args[@"options"]?:@{@"action":@"overview"},&error);}
  else if([action isEqual:@"classdump"]){NSData *data=stagedInput?[NSData dataWithContentsOfFile:stagedInput options:NSDataReadingMappedIfSafe error:&error]:[[NSData alloc]initWithBase64EncodedString:args[@"data"]?:@"" options:0];if(!data||data.length>32*1024*1024)error=DXError(@"IPA 分析输入限 32MB");else{NSString *temp=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:temp withIntermediateDirectories:YES attributes:nil error:&error];NSString *input=[temp stringByAppendingPathComponent:[args[@"name"] lastPathComponent]?:@"input.ipa"],*output=[temp stringByAppendingPathComponent:@"headers"],*zip=[temp stringByAppendingPathComponent:@"headers.zip"];if([data writeToFile:input options:NSDataWritingAtomic error:&error])result=TFAIClassDumpFile(input,output,nil,^(double progress,NSString *message){dispatch_async(self.queue,^{job[@"progress"]=@(progress);job[@"log"]=message?:@"";});},&error);if(result&&TFAIClassDumpZip(output,zip,&error)){dispatch_async(self.queue,^{[self finish:job result:@{@"analysis":result,@"download":[self registerDownload:zip name:@"headers.zip" device:job[@"device"]]} error:nil];});return;}}}
  else error=DXError(@"未注册的远程操作");
  dispatch_async(self.queue,^{[self finish:job result:result error:error];});
 }});
}
- (void)monitor:(NSMutableDictionary *)job owner:(NSMutableDictionary *)owner{
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,.5*NSEC_PER_SEC),dispatch_get_main_queue(),^{NSDictionary *state=DXStudioWorkspaceState(owner);dispatch_async(self.queue,^{if(![job[@"state"] isEqual:@"running"])return;job[@"live"]=Clean(state);[self monitor:job owner:owner];});});
}
- (void)mutate:(NSMutableDictionary *)job action:(NSString *)action arguments:(NSDictionary *)args root:(NSString *)root{
 dispatch_async(TMCGitService.queue,^{@autoreleasepool{
  NSError *error=nil;id result=@{};
  // Approval can be revoked while this work waits on the Git queue. Recheck
  // every mutation, not only automatic saves, immediately before acquiring the lease.
  __block BOOL active=NO,allowed=NO;dispatch_sync(self.queue,^{NSString *key=[NSString stringWithFormat:@"%@/%@",job[@"device"],job[@"projectID"]];active=self.jobs[job[@"id"]]==job&&[job[@"state"] isEqual:@"running"];allowed=active&&(!job[@"autosaveGrant"]||[self.owners[key][@"remoteAutosaveGrant"] isEqual:job[@"autosaveGrant"]]);});
  if(!active)return;
  if(!allowed)error=DXError(@"自动保存授权已结束，草稿尚未写入");
  TMCGitLease *lease __attribute__((objc_precise_lifetime))=[TMCGitLease tryWrite];
  if(!lease||[TMCGitLease isBuilding:root])error=DXError(@"项目正被构建或 Git 使用，请稍后重试");
  NSString *path=error?nil:TFAISafePath(root,args[@"path"]?:@"MobileCompiler.json",NO,&error);
  NSFileManager *fm=NSFileManager.defaultManager;
  if(!error&&[action isEqual:@"git_init"]){TMCGitService *git=[[TMCGitService alloc]initWithRoot:root];[git initialize:&error];}
  else if(!error&&[action isEqual:@"git_branch"]){TMCGitService *git=[[TMCGitService alloc]initWithRoot:root];if(![@[@"create",@"checkout",@"delete"] containsObject:args[@"operation"]])error=DXError(@"分支操作无效");else [git branch:args[@"name"] action:args[@"operation"] error:&error];}
  else if(!error&&[action isEqual:@"project_delete"]){NSString *trash=[DXDocs() stringByAppendingPathComponent:@".StudioTrash"];[fm createDirectoryAtPath:trash withIntermediateDirectories:YES attributes:nil error:&error];if(!error)[fm moveItemAtPath:root toPath:[trash stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@",root.lastPathComponent,NSUUID.UUID.UUIDString]] error:&error];}
  else if(!error&&[@[@"save",@"upload",@"restore"] containsObject:action]){
   NSData *before=[NSData dataWithContentsOfFile:path];NSString *expected=args[@"sha256"];if(![expected isKindOfClass:NSString.class]||![TFAIDigest(before) isEqual:expected])error=DXError(@"409：文件已被手机或其他客户端修改，请重新读取并对比");
   NSData *bytes=[action isEqual:@"upload"]?[[NSData alloc]initWithBase64EncodedString:args[@"data"]?:@"" options:0]:[args[@"text"] dataUsingEncoding:NSUTF8StringEncoding];NSString *text=bytes?[[NSString alloc]initWithData:bytes encoding:NSUTF8StringEncoding]:nil;
   if(!text||bytes.length>1024*1024||TFAIContainsSecret(text))error=DXError(@"写入限 1MB UTF-8 文本，且不得包含凭据");
   NSString *backup=nil;if(!error&&before){NSString *dir=[root stringByAppendingPathComponent:@".studio-remote-backups"];[fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error];backup=[dir stringByAppendingPathComponent:NSUUID.UUID.UUIDString];if(!error)[before writeToFile:backup options:NSDataWritingAtomic error:&error];if(!error)TFAIWriteJSON(@{@"path":args[@"path"],@"date":@(NSDate.date.timeIntervalSince1970)},[backup stringByAppendingString:@".json"],&error);}
   if(!error&&((before&&TMCWriteDocument(path,before,text,&error))||(!before&&[bytes writeToFile:path options:NSDataWritingWithoutOverwriting error:&error])))result=@{@"sha256":TFAIDigest(bytes),@"backupID":backup.lastPathComponent?:@"",@"path":args[@"path"]};
  }
  else if(!error&&[@[@"copy",@"move"] containsObject:action]){NSString *to=TFAISafePath(root,args[@"destination"],NO,&error);NSData *before=[NSData dataWithContentsOfFile:path];if(!before||![TFAIDigest(before) isEqual:args[@"sha256"]])error=DXError(@"409：源文件已变化");if(!error&&[fm fileExistsAtPath:to])error=DXError(@"目标已存在，未覆盖");if(!error){if([action isEqual:@"copy"])[fm copyItemAtPath:path toPath:to error:&error];else[fm moveItemAtPath:path toPath:to error:&error];}}
  dispatch_async(self.queue,^{[self finish:job result:result error:error];});
 }});
}
- (void)input:(NSMutableDictionary *)job arguments:(NSDictionary *)args{
 [job removeObjectForKey:@"request"]; // Do not retain base64 chunks in task history.
 NSString *identifier=args[@"inputID"];NSMutableDictionary *input=identifier?self.uploads[identifier]:nil;
 if(identifier&&(!input||![input[@"device"] isEqual:job[@"device"]])){[self finish:job result:nil error:DXError(@"上传标识无效")];return;}
 NSData *data=[[NSData alloc]initWithBase64EncodedString:args[@"data"]?:@"" options:0];
 if(!data||data.length>512*1024||(!input&&self.uploads.count>=8)){[self finish:job result:nil error:DXError(@"每块最多512KB，同时最多8个临时输入")];return;}
 if(!input){identifier=NSUUID.UUID.UUIDString;NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"RemoteInput-" stringByAppendingString:identifier]];if(![NSFileManager.defaultManager createFileAtPath:path contents:NSData.data attributes:@{NSFileProtectionKey:NSFileProtectionComplete}]){[self finish:job result:nil error:DXError(@"建立临时输入失败")];return;}input=[@{@"device":job[@"device"],@"path":path,@"bytes":@0,@"name":args[@"name"]?:@"input"} mutableCopy];self.uploads[identifier]=input;}
 if([input[@"bytes"] unsignedIntegerValue]!=[args[@"offset"] unsignedIntegerValue]||data.length>NSUIntegerMax-[input[@"bytes"] unsignedIntegerValue]){[self finish:job result:nil error:DXError(@"上传偏移不匹配或数值溢出")];return;}
 NSError *error=nil;NSFileHandle *handle=[NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:input[@"path"]] error:&error];if(handle){unsigned long long end=0;if([handle seekToEndReturningOffset:&end error:&error]&&end==[input[@"bytes"] unsignedLongLongValue])[handle writeData:data error:&error];else if(!error)error=DXError(@"上传暂存文件大小已变化");[handle closeAndReturnError:nil];}if(!error)input[@"bytes"]=@([input[@"bytes"] unsignedIntegerValue]+data.length);[self finish:job result:@{@"inputID":identifier,@"bytes":input[@"bytes"]} error:error];
}
- (void)ai:(NSMutableDictionary *)job action:(NSString *)action arguments:(NSDictionary *)args root:(NSString *)root owner:(NSMutableDictionary *)owner{
 NSString *scope=job[@"projectID"];
 dispatch_async(dispatch_get_main_queue(),^{
  if([action isEqual:@"ai_sessions"]){NSArray *sessions=[TFAISessions summaries:scope];dispatch_async(self.queue,^{[self finish:job result:@{@"sessions":sessions} error:nil];});return;}
  if([action isEqual:@"ai_connections"]){
   NSMutableArray *a=[NSMutableArray new];for(NSDictionary *c in TFAIAvailableModels())[a addObject:@{@"id":c[@"id"],@"name":c[@"name"]?:@"",@"model":c[@"model"]?:@"",@"provider":TFAIProvider(c[@"protocol"])[@"name"]?:c[@"name"]?:@"",@"protocol":TFAIWireProtocol(c[@"protocol"]?:@"chat"),@"capabilities":@{@"text":TFAIResolvedCapability(c,@"text")[@"state"],@"stream":TFAIResolvedCapability(c,@"stream")[@"state"],@"image":TFAIResolvedCapability(c,@"image")[@"state"],@"tools":TFAIResolvedCapability(c,@"tools")[@"state"],@"thinking":TFAIResolvedCapability(c,@"thinking")[@"state"]},@"observedCapabilities":TFAIObservedCapabilities(c),@"thinkingConfiguration":TFAIThinkingConfiguration(c),@"efforts":TFAIReasoningOptions(c)}];
   NSDictionary *defaultConnection=[TFAIConnections effectiveForProject:scope],*snapshot=TFAIPersonaStore.shared.snapshot,*active=[TFAIPersonaEngine active:snapshot];
   NSMutableDictionary *modules=[NSMutableDictionary new];for(NSString *key in @[@"skills",@"mcp",@"browser",@"memory",@"build_queue"])modules[key]=@([TFAIToolRegistry enabled:key]);
   NSMutableArray *tasks=[NSMutableArray new];for(NSDictionary *task in TFAIBuildQueue.shared.tasks)if([task[@"root"] isEqual:root]){NSMutableDictionary *safe=[NSMutableDictionary new];for(NSString *key in @[@"id",@"name",@"state",@"stage",@"progress",@"createdAt",@"startedAt",@"finishedAt"])if(task[key])safe[key]=task[key];[tasks addObject:safe];}
   NSDictionary *context=@{@"persona":@{@"enabled":snapshot[@"enabled"]?:@NO,@"activeCount":@(active?1:0),@"name":active[@"name"]?:@"",@"mode":active[@"mode"]?:@""},@"modules":modules,@"skillCount":@([modules[@"skills"] boolValue]?[TFAIAgentContext skills:root].count:0),@"tasks":tasks,@"isolatedToolsAvailable":@NO};
   dispatch_async(self.queue,^{[self finish:job result:@{@"connections":a,@"defaultID":defaultConnection[@"id"]?:@"",@"defaultModel":defaultConnection[@"model"]?:@"",@"context":context} error:nil];});return;
  }
  NSString *sid=args[@"sessionID"];NSMutableDictionary *session=sid.length?[TFAISessions loadSession:sid project:scope]:nil;
  if([action isEqual:@"ai_create"]){
   NSMutableDictionary *created=[TFAISessions create:scope title:[args[@"name"] length]?[args[@"name"] substringToIndex:MIN(30,[args[@"name"] length])]:@"FLEX 新会话"];NSError *error=nil;
   BOOL saved=[TFAISessions save:created project:scope error:&error];
   dispatch_async(self.queue,^{[self finish:job result:saved?created:nil error:saved?nil:(error?:DXError(@"建立会话失败"))];});return;
  }
  if([action isEqual:@"ai_read"]){dispatch_async(self.queue,^{[self finish:job result:session error:session?nil:DXError(@"会话不存在")];});return;}
  if(![action isEqual:@"ai_send"]){dispatch_async(self.queue,^{[self finish:job result:nil error:DXError(@"AI 操作无效")];});return;}
  NSString *text=args[@"text"];if(![text isKindOfClass:NSString.class]||!text.length||text.length>64000||TFAIContainsSecret(text)){dispatch_async(self.queue,^{[self finish:job result:nil error:DXError(@"请输入不含凭据的消息，最多 64000 字符")];});return;}
  if(sid.length&&TFAISessionHasLiveRun(scope,sid)){dispatch_async(self.queue,^{[self finish:job result:nil error:DXError(@"会话正在手机或其他客户端运行，请等待结束")];});return;}
  if(sid.length&&!session){dispatch_async(self.queue,^{[self finish:job result:nil error:DXError(@"会话不存在，未创建替代会话")];});return;}
  NSDictionary *chosen=[TFAIConnections effectiveForProject:scope];NSString *cid=args[@"connectionID"],*model=args[@"model"];
  if(cid.length){chosen=nil;for(NSDictionary *candidate in TFAIAvailableModels())if([candidate[@"id"] isEqual:cid]&&(!model.length||[candidate[@"model"] isEqual:model])){chosen=candidate;break;}}
  if(!chosen||![chosen[@"model"] length]){dispatch_async(self.queue,^{[self finish:job result:nil error:DXError(@"模型已移除或未配置，请重新选择手机中已保存的模型")];});return;}
  // Omitted effort inherits the current session only for the same model.
  // Explicit auto must clear any connection-level override.
  BOOL sameModel=[session[@"connectionID"] isEqual:chosen[@"id"]]&&[session[@"modelID"] isEqual:chosen[@"model"]];
  NSString *requestedEffort=args[@"reasoningEffort"]?: (sameModel?session[@"reasoningEffort"]:nil);
  NSString *effort=TFAIValidatedReasoningEffort(chosen,requestedEffort?:@"auto");if(args[@"reasoningEffort"]&&![effort isEqual:args[@"reasoningEffort"]]){dispatch_async(self.queue,^{[self finish:job result:nil error:DXError(@"当前模型不支持所选思考档位，请刷新模型列表")];});return;}
  NSMutableDictionary *requestConnection=[chosen mutableCopy];if(![effort isEqual:@"auto"])requestConnection[@"reasoningEffort"]=effort;else[requestConnection removeObjectForKey:@"reasoningEffort"];
  if(!session)session=[TFAISessions create:scope title:[text substringToIndex:MIN(30,text.length)]];
  sid=session[@"id"];[[DXFlexBridge shared] bindSession:sid device:job[@"device"]];NSMutableArray *messages=[session[@"messages"] mutableCopy]?:[NSMutableArray new];[messages addObject:@{@"role":@"user",@"content":text,@"messageID":NSUUID.UUID.UUIDString,@"timestamp":@(NSDate.date.timeIntervalSince1970)}];
  session[@"connectionID"]=chosen[@"id"];session[@"modelID"]=chosen[@"model"];session[@"reasoningEffort"]=effort;session[@"messages"]=messages;session[@"state"]=@"streaming";session[@"projectRoot"]=root;session[@"projectName"]=root.lastPathComponent;session[@"remoteRevision"]=@([session[@"remoteRevision"] unsignedLongLongValue]+1);NSError *error=nil;
  if(![TFAISessions save:session project:scope error:&error]){dispatch_async(self.queue,^{[self finish:job result:nil error:error];});return;}
  TFAISetSessionLiveRun(scope,sid,YES);
  id<TFAIRuntimeV2> runtime=(id)TFAICreateRuntime(root,scope,^(NSString *name,NSDictionary *arguments,TFAIResult completion){
   dispatch_async(self.queue,^{[self withOwner:owner project:scope completion:^(NSError *e){if(e){completion(nil,e);return;}dispatch_async(dispatch_get_main_queue(),^{DXStudioWorkspace(owner,name,arguments,completion);});}];});
  });
  [runtime setRemoteExecution:YES];[runtime activateSession:sid];[runtime configurePermissionPreset:@"assisted" paths:@[] error:nil];[runtime setInteractionMode:[args[@"mode"] isEqual:@"ask"]?@"ask":@"develop"];
  [runtime setNextConnection:requestConnection];
  __block NSTimeInterval lastSaved=0;
  runtime.event=^(NSDictionary *event){
   NSString *type=event[@"type"];
   BOOL recordChanged=TFAIRecordSessionToolEvent(session,event);
   if(recordChanged&&[@[@"tool_started",@"tool_result"] containsObject:type]){session[@"remoteRevision"]=@([session[@"remoteRevision"] unsignedLongLongValue]+1);NSError *recordError=nil;if(![TFAISessions save:session project:scope error:&recordError])dispatch_async(self.queue,^{job[@"persistenceError"]=recordError.localizedDescription?:@"保存工具记录失败";});}
   if([type isEqual:@"checkpoint"]){NSDictionary *checkpoint=event[@"checkpoint"];session[@"runtimeCheckpoint"]=checkpoint;if([checkpoint[@"messages"] isKindOfClass:NSArray.class])session[@"messages"]=checkpoint[@"messages"];NSTimeInterval now=NSDate.date.timeIntervalSince1970;if([event[@"durable"] boolValue]||now-lastSaved>2){lastSaved=now;session[@"remoteRevision"]=@([session[@"remoteRevision"] unsignedLongLongValue]+1);NSError *saveError=nil;[TFAISessions save:session project:scope error:&saveError];if(saveError)dispatch_async(self.queue,^{job[@"persistenceError"]=saveError.localizedDescription;});}}
   if([type isEqual:@"done"]){session[@"messages"]=event[@"messages"]?:session[@"messages"];session[@"state"]=event[@"state"]?:@"interrupted";session[@"remoteRevision"]=@([session[@"remoteRevision"] unsignedLongLongValue]+1);NSError *saveError=nil;[TFAISessions save:session project:scope error:&saveError];TFAISetSessionLiveRun(scope,sid,NO);dispatch_async(self.queue,^{[self finish:job result:@{@"sessionID":sid,@"state":session[@"state"],@"messages":session[@"messages"]} error:saveError];[self.runtimes removeObjectForKey:job[@"id"]];});}
   if(![type isEqual:@"checkpoint"])dispatch_async(self.queue,^{
    NSMutableArray *events=job[@"events"];if(!events){events=[NSMutableArray new];job[@"events"]=events;}NSMutableDictionary *record=[Clean(event) mutableCopy];NSUInteger sequence=[job[@"eventSequence"] unsignedIntegerValue]+1;job[@"eventSequence"]=@(sequence);record[@"sequence"]=@(sequence);[events addObject:record];while(events.count>80)[events removeObjectAtIndex:0];
    if([type isEqual:@"flex_capture_status"])job[@"flexCaptureStatus"]=record;
    if([@[@"reasoning",@"analysis_summary"] containsObject:type]){NSString *next=[(job[@"reasoning"]?:@"") stringByAppendingString:event[@"text"]?:@""];job[@"reasoning"]=next.length>128000?[next substringFromIndex:next.length-128000]:next;}
    if([type isEqual:@"text"]){NSString *previous=job[@"text"]?:@"";NSString *next=[previous stringByAppendingString:event[@"text"]?:@""];job[@"text"]=next.length>512000?[next substringFromIndex:next.length-512000]:next;}
   });
  };
  runtime.approval=^(NSDictionary *plan,void(^decision)(BOOL,NSArray<NSNumber *> *)){
   dispatch_async(self.queue,^{NSString *name=plan[@"request"][@"name"];BOOL flex=[@[@"flex_sensitive_read",@"flex_control"] containsObject:name];
    if(flex&&[owner[@"flexSessionGrants"][sid] boolValue]){dispatch_async(dispatch_get_main_queue(),^{decision(YES,nil);});return;}
    NSDictionary *summary=flex?@{@"summary":@"授权本会话全部 FLEX 工具",@"details":@"包含敏感读取、截图、触摸、视图和录制控制；本会话有效，无时间限制，可在权限中撤销。项目写入、构建和 Git 仍单独审批。"}:plan;
    [self await:job summary:summary execute:^{if(flex){NSMutableDictionary *grants=owner[@"flexSessionGrants"];if(!grants){grants=[NSMutableDictionary new];owner[@"flexSessionGrants"]=grants;}grants[sid]=@YES;}dispatch_async(dispatch_get_main_queue(),^{decision(YES,nil);});}];});
  };
  dispatch_async(self.queue,^{self.runtimes[job[@"id"]]=runtime;job[@"sessionID"]=sid;dispatch_async(dispatch_get_main_queue(),^{[runtime send:messages session:sid];});});
 });
}
@end

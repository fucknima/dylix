#import "DocumentPresentation.h"
#import "StorageSpace.h"
#import <sys/stat.h>
#import <CommonCrypto/CommonDigest.h>
static NSError *SE(NSString *text){return [NSError errorWithDomain:@"TweakForge.Storage" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}
static NSString *Join(NSString *base,NSString *name){return [base stringByAppendingPathComponent:name];}
static BOOL RealDirectory(NSString *path){struct stat st;return lstat(path.fileSystemRepresentation,&st)==0&&S_ISDIR(st.st_mode);}
static NSString *Category(NSString *relative,BOOL documents){
 NSArray *parts=relative.pathComponents;NSString *top=parts.firstObject?:@"";
 if(documents){
  if([top isEqual:@"Projects"]||([top hasPrefix:@"Imported-"]&&TMCDocumentUUID([top substringFromIndex:9])))return @"projects";
  if([@[@"Incoming",@"接收文件",@"AttachmentArchives",@"DylixLinuxExports"] containsObject:top])return @"received";
  if([top isEqual:@"DylixBackups"])return @"localbackups";
  if([top isEqual:@".StudioTrash"])return @"trash";
  if([top isEqual:@"AIClassDumpInputs"])return @"ipa";
  if([@[@"ClassDumpExports",@"头文件导出"] containsObject:top])return @"exports";
  if([top isEqual:@"构建产物"])return @"published";
  if([top hasPrefix:@"ClassDump-"]){NSString *suffix=[top substringFromIndex:10];if(suffix.length>=36&&[[NSUUID alloc]initWithUUIDString:[suffix substringToIndex:36]]&&(suffix.length==36||(suffix.length==82&&[[suffix substringFromIndex:36] hasPrefix:@".previous-"]&&[[NSUUID alloc]initWithUUIDString:[suffix substringFromIndex:46]])))return @"headers";}
  for(NSString *prefix in @[@"Build-",@"Snapshot-"])if([top hasPrefix:prefix]&&[[NSUUID alloc]initWithUUIDString:[top substringFromIndex:prefix.length]])return @"builds";
  return @"userfiles";
 }else{
  if([top isEqual:@"Caches"])return @"cache";
  if([relative hasPrefix:@"Application Support/TweakForgeAI/Sessions/"])return @"sessions";
  if([relative hasPrefix:@"Application Support/TweakForgeAI/Attachments/"]||[relative hasPrefix:@"Application Support/TweakForgeAI/Binaries/"])return @"attachments";
  if([relative hasPrefix:@"Application Support/TweakForgeAI/Tools/"])return @"backups";
 }
 return @"other";
}
static NSArray *Definitions(void){return @[
 @{@"id":@"published",@"name":@"已导出构建产物",@"level":@"独立保存",@"impact":@"单独保存的 deb、dylib 和构建记录；不会随自动构建缓存清理删除。",@"clear":@YES,@"symbol":@"shippingbox.fill"},
 @{@"id":@"userfiles",@"name":@"其他用户文件",@"level":@"请先确认",@"impact":@"Documents 中未归入项目的原文件、导出文件及自建目录。可逐项查看并选择；删除前请先保存需要的内容。",@"clear":@YES,@"symbol":@"doc.on.doc"},
 @{@"id":@"received",@"name":@"接收文件与解包副本",@"level":@"重要输入",@"impact":@"包含接收原文件、目录附件解包及终端导出。删除后相关读取入口失效，请先保存所需文件。",@"clear":@YES,@"symbol":@"tray.full"},
 @{@"id":@"localbackups",@"name":@"本机备份文件",@"level":@"请先导出",@"impact":@"删除已创建的本机备份，无法再从这些文件恢复。",@"clear":@YES,@"symbol":@"archivebox"},
 @{@"id":@"linuxSnapshots",@"name":@"Linux 环境快照",@"level":@"恢复副本",@"impact":@"仅删除环境恢复快照，不删除当前 Linux 文件系统；存在待执行维护时暂不允许清理。",@"clear":@YES,@"symbol":@"externaldrive.badge.timemachine"},
 @{@"id":@"terminal",@"name":@"终端历史与持久输出",@"level":@"可清理",@"impact":@"删除终端输出日志、进程历史及可重建技能视图。请先结束终端任务并保存需要的日志。",@"clear":@YES,@"symbol":@"text.alignleft"},
 @{@"id":@"archives",@"name":@"Linux 安装包缓存",@"level":@"可重新下载",@"impact":@"删除已下载的 rootfs 安装归档，已安装的 Linux 环境保留。",@"clear":@YES,@"symbol":@"arrow.down.doc"},
 @{@"id":@"resources",@"name":@"已下载工具与 SDK 资源",@"level":@"查看明细",@"impact":@"下载的工具与 SDK 压缩资源。到开发工具安装页面卸载，避免已加载工具被直接移除。",@"clear":@NO,@"symbol":@"wrench.and.screwdriver"},
 @{@"id":@"restorehistory",@"name":@"已完成恢复的暂存与回滚副本",@"level":@"请先确认",@"impact":@"删除旧恢复暂存与恢复前副本，将失去回滚能力；正在等待恢复的数据保留。",@"clear":@YES,@"symbol":@"arrow.uturn.backward.circle"},
 @{@"id":@"restoredata",@"name":@"备份恢复工作区",@"level":@"查看明细",@"impact":@"恢复校验暂存、待恢复数据和恢复前回滚副本。待恢复任务及回滚文件保留。",@"clear":@NO,@"symbol":@"arrow.uturn.backward"},
 @{ @"id":@"linux",@"name":@"Linux 文件系统",@"level":@"保留",@"impact":@"当前 Linux 文件和已安装工具。点击查看明细，可进入环境管理安排重建或删除；快照和终端输出已单列。",@"clear":@NO,@"symbol":@"terminal"},
 @{@"id":@"cache",@"name":@"SDK 与缓存",@"level":@"可重新生成",@"impact":@"SDK 会在下次构建时重新解压，首次构建稍慢。",@"clear":@YES,@"symbol":@"arrow.triangle.2.circlepath"},
 @{@"id":@"temporary",@"name":@"过期临时文件",@"level":@"低重要性",@"impact":@"仅清理本软件生成且超过 24 小时的临时文件。",@"clear":@YES,@"symbol":@"clock.arrow.circlepath"},
 @{@"id":@"builds",@"name":@"构建结果与源码快照",@"level":@"请先导出产物",@"impact":@"删除 dylib、deb、构建日志和快照；项目源码保留，需重新构建生成结果。",@"clear":@YES,@"symbol":@"shippingbox"},
 @{@"id":@"exports",@"name":@"头文件导出 ZIP",@"level":@"影响分享",@"impact":@"删除导出的 ZIP，包括历史备份。保留的 IPA 可再次生成；先保存需要的副本。",@"clear":@YES,@"symbol":@"doc.zipper"},
 @{@"id":@"headers",@"name":@"导出头文件",@"level":@"重要文件",@"impact":@"会话里的头文件目录将失效，包括旧版备份。需保留原 IPA 才能重新导出。",@"clear":@YES,@"symbol":@"curlybraces"},
 @{@"id":@"ipa",@"name":@"AI 导入的 IPA 副本",@"level":@"重要输入",@"impact":@"AI 将失去这些 IPA 的本机读取入口，后续导出需重新选择原 IPA。外部原文件保留。",@"clear":@YES,@"symbol":@"app.badge"},
 @{@"id":@"attachments",@"name":@"AI 参考附件与二进制",@"level":@"重要输入",@"impact":@"删除本机参考副本；相关会话再次读取或分析时需重新添加。聊天记录保留。",@"clear":@YES,@"symbol":@"paperclip"},
 @{@"id":@"trash",@"name":@"项目回收站",@"level":@"清理后不可恢复",@"impact":@"永久删除回收站项目，提前结束剩余的 7 天恢复期。",@"clear":@YES,@"symbol":@"trash"},
 @{@"id":@"projects",@"name":@"项目源码与 Git 历史",@"level":@"保留",@"impact":@"通过项目列表管理，清理不会删除这些内容。",@"clear":@NO,@"symbol":@"folder"},
 @{@"id":@"sessions",@"name":@"AI 会话记录",@"level":@"保留",@"impact":@"包括消息中的图片与已发送文本；通过会话列表管理。",@"clear":@NO,@"symbol":@"bubble.left.and.bubble.right"},
 @{@"id":@"backups",@"name":@"AI 修改备份与操作记录",@"level":@"保留",@"impact":@"用于撤回与审查操作，清理不会删除。",@"clear":@NO,@"symbol":@"arrow.uturn.backward"},
 @{@"id":@"application",@"name":@"软件与内置工具链",@"level":@"必要内容",@"impact":@"程序、编译器和内置资源，保留。",@"clear":@NO,@"symbol":@"app"},
 @{@"id":@"other",@"name":@"设置与未分类数据",@"level":@"保留",@"impact":@"点击逐层查看实际目录及大小；未确认用途的数据不进行批量删除。",@"clear":@NO,@"symbol":@"internaldrive"}];}
// Physical blocks, never following symbolic links. Fingerprint includes descendants,
// so a changed nested file invalidates a previously confirmed deletion plan.
static NSDictionary *Measure(NSString *path){
 struct stat st;if(lstat(path.fileSystemRepresentation,&st)!=0||S_ISLNK(st.st_mode))return @{@"bytes":@0,@"signature":@"missing-or-link"};
 NSMutableData *digest=[NSMutableData dataWithLength:32];__block unsigned long long bytes=0;NSMutableSet *inodes=[NSMutableSet new];
 void (^visit)(NSString *,struct stat)=^(NSString *relative,struct stat s){
 NSString *entry=[NSString stringWithFormat:@"%@|%llu|%llu|%llu|%u|%lld.%ld|%lld.%ld",relative,(unsigned long long)s.st_dev,(unsigned long long)s.st_ino,(unsigned long long)s.st_size,s.st_mode,(long long)s.st_mtimespec.tv_sec,s.st_mtimespec.tv_nsec,(long long)s.st_ctimespec.tv_sec,s.st_ctimespec.tv_nsec];NSData *data=[entry dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[32];CC_SHA256(data.bytes,(CC_LONG)data.length,hash);for(int i=0;i<32;i++)((unsigned char *)digest.mutableBytes)[i]^=hash[i];
 // Only multiply-linked regular files need inode bookkeeping.
 BOOL duplicate=NO;if(S_ISREG(s.st_mode)&&s.st_nlink>1){NSString *inode=[NSString stringWithFormat:@"%llu:%llu",(unsigned long long)s.st_dev,(unsigned long long)s.st_ino];duplicate=[inodes containsObject:inode];[inodes addObject:inode];}if(!duplicate)bytes+=(unsigned long long)s.st_blocks*512;
 };
 visit(@"",st);if(S_ISDIR(st.st_mode)){NSDirectoryEnumerator *enumerator=[NSFileManager.defaultManager enumeratorAtPath:path];for(NSString *relative in enumerator){@autoreleasepool{struct stat child;if(lstat(Join(path,relative).fileSystemRepresentation,&child))continue;if(S_ISLNK(child.st_mode))[enumerator skipDescendants];visit(relative,child);}}}
 NSMutableString *signature=[NSMutableString new];for(int i=0;i<32;i++)[signature appendFormat:@"%02x",((unsigned char *)digest.bytes)[i]];return @{@"bytes":@(bytes),@"signature":signature,@"identity":[NSString stringWithFormat:@"%llu:%llu",(unsigned long long)st.st_dev,(unsigned long long)st.st_ino]};
}
static void AddRoot(NSMutableArray *out,NSString *path,NSString *category){struct stat st;if(lstat(path.fileSystemRepresentation,&st)||S_ISLNK(st.st_mode))return;[out addObject:@{@"path":path,@"category":category}];}
static void Roots(NSString *base,BOOL documents,NSMutableArray *out){
 if(!RealDirectory(base))return;NSFileManager *fm=NSFileManager.defaultManager;
 for(NSString *top in [fm contentsOfDirectoryAtPath:base error:nil]){NSString *path=Join(base,top);if(!documents&&[top isEqual:@"Application Support"]&&RealDirectory(path)){
  for(NSString *name in [fm contentsOfDirectoryAtPath:path error:nil]){NSString *child=Join(path,name);if([name isEqual:@"TweakForgeAI"]&&RealDirectory(child)){for(NSString *sub in [fm contentsOfDirectoryAtPath:child error:nil])AddRoot(out,Join(child,sub),Category([[@"Application Support/TweakForgeAI" stringByAppendingPathComponent:sub] stringByAppendingString:@"/"],NO));}
   else if([name isEqual:@"Dylix"]&&RealDirectory(child)){for(NSString *sub in [fm contentsOfDirectoryAtPath:child error:nil]){NSString *directory=Join(child,sub);
    if([sub isEqual:@"iSH-v1"]&&RealDirectory(directory)){BOOL pending=[fm fileExistsAtPath:Join(directory,@"pending-maintenance.plist")];for(NSString *part in [fm contentsOfDirectoryAtPath:directory error:nil])AddRoot(out,Join(directory,part),[part isEqual:@"snapshots"]&&!pending?@"linuxSnapshots":@"linux");}
    else AddRoot(out,directory,[@[@"TerminalOutput",@"iSH-process-history",@"TerminalHistory",@"SkillViews"] containsObject:sub]?@"terminal":[sub isEqual:@"RootArchives"]?@"archives":[sub isEqual:@"DownloadedResources"]?@"resources":@"other");
   }}else if([name isEqual:@"DylixRestore"]&&RealDirectory(child)){BOOL pending=[fm fileExistsAtPath:Join(child,@"pending.json")];for(NSString *sub in [fm contentsOfDirectoryAtPath:child error:nil])AddRoot(out,Join(child,sub),!pending&&([sub isEqual:@"rollback"]||TMCDocumentUUID(sub))?@"restorehistory":@"restoredata");}else AddRoot(out,child,@"other");
  }continue;
 }
 // System owns the Caches container. Only its children are deletion targets.
 if(!documents&&[top isEqual:@"Caches"]&&RealDirectory(path)){for(NSString *name in [fm contentsOfDirectoryAtPath:path error:nil])AddRoot(out,Join(path,name),@"cache");continue;}
 NSString *category=Category(top,documents);if(documents&&[category isEqual:@"userfiles"]&&RealDirectory(path)&&(TMCRegularDocument(Join(path,@"MobileCompiler.json"),NO)||TMCRegularDocument(Join(path,@"Makefile"),NO)))category=@"projects";AddRoot(out,path,category);
 }}
static NSDictionary *StorageScan(NSString *documents,NSString *library,NSString *temporary,NSString *bundle,void(^progress)(NSDictionary *)){
 NSMutableArray *roots=[NSMutableArray new];Roots(documents,YES,roots);Roots(library,NO,roots);
 for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:temporary error:nil]){NSString *path=Join(temporary,name);struct stat st;if(lstat(path.fileSystemRepresentation,&st)||S_ISLNK(st.st_mode))continue;BOOL known=NO;for(NSString *prefix in @[@"classdump-image-",@"TFAI-Extract-",@"ClassDump-",@"TweakForge-",@"dylix-backup-",@"dylix-restore-",@"presentation257-"])if([name hasPrefix:prefix])known=YES;BOOL old=NSDate.date.timeIntervalSince1970-st.st_mtimespec.tv_sec>86400;[roots addObject:@{@"path":path,@"category":known&&old?@"temporary":@"other"}];}
 if(bundle.length)[roots addObject:@{@"path":bundle,@"category":@"application"}];
 NSMutableArray *entries=[NSMutableArray new];NSMutableDictionary *totals=[NSMutableDictionary new];
 NSDictionary *fs=[NSFileManager.defaultManager attributesOfFileSystemForPath:documents error:nil]?:@{};
 NSMutableDictionary *remaining=[NSMutableDictionary new];for(NSDictionary *r in roots)remaining[r[@"category"]]=@([remaining[r[@"category"]] integerValue]+1);
 for(NSDictionary *root in roots){@autoreleasepool{NSDictionary *size=nil;
 if(progress&&[root[@"category"] isEqual:@"application"]){static NSDictionary *cachedBundle;static NSString *cachedPath;@synchronized(NSProcessInfo.class){if(![cachedPath isEqual:root[@"path"]]){cachedBundle=Measure(root[@"path"]);cachedPath=root[@"path"];}size=cachedBundle;}}else size=Measure(root[@"path"]);NSMutableDictionary *entry=[root mutableCopy];[entry addEntriesFromDictionary:size];entry[@"resolved"]=[root[@"path"] stringByResolvingSymlinksInPath];[entries addObject:entry];totals[root[@"category"]]=@([totals[root[@"category"]] unsignedLongLongValue]+[size[@"bytes"] unsignedLongLongValue]);
 remaining[root[@"category"]]=@([remaining[root[@"category"]] integerValue]-1);
 if(progress&&[remaining[root[@"category"]] integerValue]==0){NSMutableArray *partial=[NSMutableArray new];unsigned long long total=0;for(NSDictionary *d in Definitions()){NSMutableDictionary *g=[d mutableCopy];g[@"bytes"]=totals[g[@"id"]]?:@0;g[@"pending"]=@([remaining[g[@"id"]] integerValue]>0);total+=[g[@"bytes"] unsignedLongLongValue];[partial addObject:g];}progress(@{@"groups":partial,@"total":@(total),@"pending":@YES,@"deviceTotal":fs[NSFileSystemSize]?:@0,@"deviceFree":fs[NSFileSystemFreeSize]?:@0});}
 }}
 NSMutableArray *groups=[NSMutableArray new];unsigned long long total=0;for(NSDictionary *definition in Definitions()){NSMutableDictionary *g=[definition mutableCopy];g[@"bytes"]=totals[g[@"id"]]?:@0;total+=[g[@"bytes"] unsignedLongLongValue];[groups addObject:g];}
 return @{@"groups":groups,@"entries":entries,@"total":@(total),@"deviceTotal":fs[NSFileSystemSize]?:@0,@"deviceFree":fs[NSFileSystemFreeSize]?:@0,@"documents":documents,@"library":library,@"temporary":temporary,@"bundle":bundle?:@""};
}
NSDictionary *TMCStorageScan(NSString *documents,NSString *library,NSString *temporary,NSString *bundle){return StorageScan(documents,library,temporary,bundle,nil);}

NSDictionary *TMCStorageClean(NSDictionary *snapshot,NSSet<NSString *> *categories,NSError **error){
 NSMutableSet *allowed=[NSMutableSet new];for(NSDictionary *d in Definitions())if([d[@"clear"] boolValue])[allowed addObject:d[@"id"]];if(!categories.count||![categories isSubsetOfSet:allowed]){if(error)*error=SE(@"请选择可清理的类别");return nil;}
 NSMutableArray *items=[NSMutableArray new];for(NSDictionary *e in snapshot[@"entries"])if([categories containsObject:e[@"category"]])[items addObject:e];return TMCStorageCleanItems(snapshot,items,error);
}

static NSDictionary *ItemRoot(NSDictionary *snapshot,NSString *category,NSString *path){
 BOOL allowed=NO;for(NSDictionary *d in Definitions())if([d[@"id"] isEqual:category])allowed=YES;if(!allowed||!path.length||![path isEqual:path.stringByStandardizingPath])return nil;
 for(NSDictionary *root in snapshot[@"entries"]){NSString *base=root[@"path"];if(![root[@"category"] isEqual:category]||!([path isEqual:base]||[path hasPrefix:[base stringByAppendingString:@"/"]]))continue;
 if(![[base stringByResolvingSymlinksInPath] isEqual:root[@"resolved"]])return nil;
 NSString *relative=[path substringFromIndex:base.length];NSString *walk=base;struct stat st;if(lstat(base.fileSystemRepresentation,&st)||S_ISLNK(st.st_mode))return nil;
 for(NSString *part in relative.pathComponents){if([part isEqual:@"/"]||!part.length)continue;walk=Join(walk,part);if(lstat(walk.fileSystemRepresentation,&st)||S_ISLNK(st.st_mode))return nil;}return root;
 }return nil;
}
static NSDictionary *StorageItem(NSDictionary *snapshot,NSString *category,NSString *path){if(!ItemRoot(snapshot,category,path))return nil;struct stat st;if(lstat(path.fileSystemRepresentation,&st))return nil;NSMutableDictionary *item=[Measure(path) mutableCopy];item[@"path"]=path;item[@"category"]=category;item[@"directory"]=@(S_ISDIR(st.st_mode));item[@"resolved"]=path.stringByResolvingSymlinksInPath;return item;}
NSArray *TMCStorageChildren(NSDictionary *snapshot,NSString *category,NSString *directory,NSError **error){
 NSMutableArray *paths=[NSMutableArray new];if(directory){if(!ItemRoot(snapshot,category,directory)||!RealDirectory(directory)){if(error)*error=SE(@"目录已变化，请刷新统计");return nil;}for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:error])[paths addObject:Join(directory,name)];}
 else for(NSDictionary *root in snapshot[@"entries"])if([root[@"category"] isEqual:category]){NSString *path=root[@"path"];if([@[@"exports",@"ipa",@"attachments",@"trash",@"published",@"received",@"localbackups",@"terminal",@"archives",@"linuxSnapshots"] containsObject:category]&&RealDirectory(path)){for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:error])[paths addObject:Join(path,name)];}else[paths addObject:path];}
 NSMutableArray *items=[NSMutableArray new];for(NSString *path in [paths sortedArrayUsingSelector:@selector(localizedStandardCompare:)]){@autoreleasepool{NSDictionary *item=StorageItem(snapshot,category,path);if(item)[items addObject:item];}}return items;
}
static BOOL Clearable(NSString *category){for(NSDictionary *d in Definitions())if([d[@"id"] isEqual:category])return [d[@"clear"] boolValue];return NO;}
NSDictionary *TMCStorageCleanItemsProgress(NSDictionary *snapshot,NSArray *items,NSProgress *progress,void(^changed)(NSDictionary *),NSError **error){
 if(!items.count){if(error)*error=SE(@"请选择文件或目录");return nil;}
 // Rebuild only root authority, without scanning unrelated projects, Linux trees or bundles.
 NSMutableArray *authority=[NSMutableArray new];Roots(snapshot[@"documents"],YES,authority);Roots(snapshot[@"library"],NO,authority);
 for(NSDictionary *e in snapshot[@"entries"])if([e[@"category"] isEqual:@"temporary"]){NSString *p=e[@"path"];struct stat st;if([p.stringByDeletingLastPathComponent isEqual:snapshot[@"temporary"]]&&!lstat(p.fileSystemRepresentation,&st)&&NSDate.date.timeIntervalSince1970-st.st_mtimespec.tv_sec>86400)[authority addObject:@{@"path":p,@"category":@"temporary"}];}
 NSMutableArray *unique=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];for(NSDictionary *item in items){NSString *path=item[@"path"],*category=item[@"category"];if(![path isKindOfClass:NSString.class]||!Clearable(category)||!ItemRoot(snapshot,category,path)){if(error)*error=SE(@"无效或受保护的清理目标");return nil;}BOOL live=NO;for(NSDictionary *r in authority)if([r[@"category"] isEqual:category]&&([path isEqual:r[@"path"]]||[path hasPrefix:[r[@"path"] stringByAppendingString:@"/"]])){live=YES;break;}if(!live){if(error)*error=SE(@"目标路径或分类已变化，请刷新后重试");return nil;}if(![seen containsObject:path]){[seen addObject:path];[unique addObject:item];}}
 NSMutableArray *plan=[NSMutableArray new];for(NSDictionary *item in unique){BOOL covered=NO;for(NSDictionary *parent in unique)if(parent!=item&&[item[@"path"] hasPrefix:[parent[@"path"] stringByAppendingString:@"/"]]){covered=YES;break;}if(!covered)[plan addObject:item];}
 // Validate each selected subtree once. Nothing is removed when preflight fails.
 if(progress)progress.totalUnitCount=MAX(1,plan.count*2);for(NSDictionary *item in plan){if(progress.cancelled)break;if(changed)changed(@{@"stage":@"正在校验所选内容",@"name":TMCDocumentDisplayName(item[@"path"]),@"completed":@(progress.completedUnitCount),@"total":@(plan.count*2)});NSDictionary *now=StorageItem(snapshot,item[@"category"],item[@"path"]);if(!now||![now[@"signature"] isEqual:item[@"signature"]]||![now[@"resolved"] isEqual:item[@"resolved"]]){if(error)*error=SE(@"所选内容已变化，请刷新后重新确认");return nil;}if(progress)progress.completedUnitCount++;}
 unsigned long long bytes=0;NSUInteger count=0;NSMutableArray *failures=[NSMutableArray new];NSFileManager *fm=NSFileManager.defaultManager;
 for(NSDictionary *item in plan){if(progress.cancelled)break;NSString *path=item[@"path"];if(changed)changed(@{@"stage":@"正在删除",@"name":TMCDocumentDisplayName(path),@"completed":@(progress.completedUnitCount),@"total":@(plan.count*2),@"removed":@(bytes)});
  NSError *failure=nil;if(([item[@"category"] isEqual:@"linuxSnapshots"]&&[fm fileExistsAtPath:Join(snapshot[@"library"],@"Application Support/Dylix/iSH-v1/pending-maintenance.plist")])||([item[@"category"] isEqual:@"restorehistory"]&&[fm fileExistsAtPath:Join(snapshot[@"library"],@"Application Support/DylixRestore/pending.json")]))failure=SE(@"已有待执行恢复任务，跳过此副本"); // Cheap identity and ancestor check immediately before removal.
  struct stat identity;if(!ItemRoot(snapshot,item[@"category"],path)||lstat(path.fileSystemRepresentation,&identity)||![item[@"identity"] isEqual:[NSString stringWithFormat:@"%llu:%llu",(unsigned long long)identity.st_dev,(unsigned long long)identity.st_ino]])failure=SE(@"路径已变化，跳过");else if(!failure&&![fm removeItemAtPath:path error:&failure]){}
  if(failure)[failures addObject:[NSString stringWithFormat:@"%@：%@",TMCDocumentDisplayName(path),failure.localizedDescription]];else{bytes+=[item[@"bytes"] unsignedLongLongValue];count++;NSString *sdkRoot=Join(snapshot[@"library"],@"Caches/TweakForgeSDK");if([path hasPrefix:[sdkRoot stringByAppendingString:@"/"]]){NSString *digest=[[path substringFromIndex:sdkRoot.length+1] pathComponents].firstObject;if(digest.length==64)[fm removeItemAtPath:Join(Join(sdkRoot,digest),@".complete") error:nil];}}
  if(progress)progress.completedUnitCount++;
 }
 if(failures.count&&error)*error=SE([failures componentsJoinedByString:@"\n"]);
 return @{@"removed":@(bytes),@"items":@(count),@"failed":failures,@"cancelled":@(progress.cancelled)};
}
NSDictionary *TMCStorageCleanItems(NSDictionary *snapshot,NSArray *items,NSError **error){return TMCStorageCleanItemsProgress(snapshot,items,nil,nil,error);}

#if __has_include(<UIKit/UIKit.h>) && !defined(TMC_STORAGE_TEST)
#import "GitPreferences.h"
#import "AI/Sandbox/TFAIISHEnvironmentUI.h"
extern BOOL TFAIHasLiveRuns(void);
extern BOOL TFAIClassDumpIsActive(void);
static NSString *Bytes(unsigned long long size){return size?[NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleFile]:@"0 KB";}
static UIViewController *StorageBrowser(NSDictionary *,NSString *,NSString *,NSMutableDictionary *,void(^)(void));
@interface TMCStoragePage : UIViewController <UITableViewDataSource,UITableViewDelegate>
@property UITableView *tableView;
@property NSDictionary *snapshot;
@property NSMutableSet *selected;
@property UIButton *cleanButton;
@property BOOL working,cleaning;
@property NSProgress *cleanProgress;
@property UILabel *cleanStatus;
@property NSMutableDictionary *selectedItems;
@end
@implementation TMCStoragePage
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"存储空间";NSInteger theme=[NSUserDefaults.standardUserDefaults integerForKey:@"StudioTheme"];self.overrideUserInterfaceStyle=theme==1?UIUserInterfaceStyleDark:theme==2?UIUserInterfaceStyleLight:UIUserInterfaceStyleUnspecified;
 self.selectedItems=[NSMutableDictionary new];self.selected=[NSMutableSet new];self.tableView=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];self.tableView.delegate=self;self.tableView.dataSource=self;self.tableView.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:self.tableView];[NSLayoutConstraint activateConstraints:@[[self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],[self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];self.tableView.contentInset=UIEdgeInsetsMake(0,0,84,0);self.tableView.verticalScrollIndicatorInsets=UIEdgeInsetsMake(0,0,84,0);self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=68;
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(scan)];
 self.cleanButton=[UIButton buttonWithType:UIButtonTypeSystem];self.cleanButton.translatesAutoresizingMaskIntoConstraints=NO;UIButtonConfiguration *configuration=[UIButtonConfiguration filledButtonConfiguration];configuration.cornerStyle=UIButtonConfigurationCornerStyleCapsule;configuration.baseBackgroundColor=UIColor.systemRedColor;configuration.contentInsets=NSDirectionalEdgeInsetsMake(14,20,14,20);self.cleanButton.configuration=configuration;self.cleanButton.layer.shadowColor=UIColor.blackColor.CGColor;self.cleanButton.layer.shadowOpacity=.14;self.cleanButton.layer.shadowRadius=12;self.cleanButton.layer.shadowOffset=CGSizeMake(0,4);[self.cleanButton addTarget:self action:@selector(confirm) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.cleanButton];[NSLayoutConstraint activateConstraints:@[[self.cleanButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],[self.cleanButton.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],[self.cleanButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],[self.cleanButton.heightAnchor constraintGreaterThanOrEqualToConstant:50]]];NSDictionary *cached=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"StorageDisplaySummary-v1"];if([cached[@"groups"] isKindOfClass:NSArray.class])self.snapshot=cached;
 if(!self.snapshot){NSMutableArray *groups=[NSMutableArray new];for(NSDictionary *d in Definitions()){NSMutableDictionary *g=[d mutableCopy];g[@"bytes"]=@0;g[@"pending"]=@YES;[groups addObject:g];}self.snapshot=@{@"groups":groups,@"pending":@YES};}
 [self.tableView reloadData];[self scan];
}
- (NSArray *)groups:(BOOL)clear{NSMutableArray *out=[NSMutableArray new];for(NSDictionary *g in self.snapshot[@"groups"])if([g[@"clear"] boolValue]==clear)[out addObject:g];return out;}
- (unsigned long long)selectedBytes{unsigned long long bytes=0;for(NSDictionary *g in self.snapshot[@"groups"])if([self.selected containsObject:g[@"id"]])bytes+=[g[@"bytes"] unsignedLongLongValue];for(NSDictionary *item in self.selectedItems.allValues)bytes+=[item[@"bytes"] unsignedLongLongValue];return bytes;}
- (void)updateButton{[self.cleanButton setTitle:self.cleaning?@"停止清理（当前项完成后）":self.working?@"正在统计…":[NSString stringWithFormat:@"清理所选 · %@",Bytes(self.selectedBytes)] forState:UIControlStateNormal];self.cleanButton.enabled=self.cleaning||(!self.working&&self.selectedBytes>0);self.navigationItem.rightBarButtonItem.enabled=!self.working;}
- (void)scan{
 if(self.working)return;self.working=YES;[self updateButton];if(!self.snapshot){UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];[spinner startAnimating];self.tableView.backgroundView=spinner;}
 NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject,*lib=NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES).firstObject;
 NSString *temporary=NSTemporaryDirectory();
#if TARGET_OS_SIMULATOR
 if([NSProcessInfo.processInfo.arguments containsObject:@"--storage-test"]){NSString *fixture=[NSTemporaryDirectory() stringByAppendingPathComponent:@"StorageUIFixture"];docs=Join(fixture,@"Documents");lib=Join(fixture,@"Library");temporary=Join(fixture,@"tmp");for(NSString *p in @[Join(docs,@"Projects/Demo/main.m"),Join(lib,@"Caches/Demo/cache"),Join(docs,@"Build-11111111-1111-1111-1111-111111111111/test.deb"),Join(docs,@".StudioTrash/Demo/main.m")]){[NSFileManager.defaultManager createDirectoryAtPath:p.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];if(![NSFileManager.defaultManager fileExistsAtPath:p])[[NSMutableData dataWithLength:65536] writeToFile:p atomically:YES];}}
#endif
 static dispatch_queue_t scanQueue;static dispatch_once_t once;dispatch_once(&once,^{scanQueue=dispatch_queue_create("com.xuegao.storage.scan",DISPATCH_QUEUE_SERIAL);});
 __weak typeof(self) weak=self;
 dispatch_async(scanQueue,^{NSDictionary *data=StorageScan(docs,lib,temporary,NSBundle.mainBundle.bundlePath,^(NSDictionary *partial){dispatch_async(dispatch_get_main_queue(),^{typeof(self) page=weak;if(!page)return;page.snapshot=partial;[page.tableView reloadData];});});dispatch_async(dispatch_get_main_queue(),^{typeof(self) self=weak;if(!self)return;NSMutableDictionary *summary=[data mutableCopy];[summary removeObjectForKey:@"entries"];for(NSString *key in @[@"documents",@"library",@"temporary",@"bundle"])[summary removeObjectForKey:key];[NSUserDefaults.standardUserDefaults setObject:summary forKey:@"StorageDisplaySummary-v1"];self.snapshot=data;self.working=NO;[self.selected removeAllObjects];[self.selectedItems removeAllObjects];self.tableView.backgroundView=nil;[self.tableView reloadData];[self updateButton];});});
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{return self.snapshot?3:0;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return s==0?2:[self groups:s==1].count;}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s{return @[@"空间概览",@"选择清理内容",@"保留内容"][s];}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{return s==0?@"含程序及本机数据，占用估算可能与系统统计略有差异。":s==1?@"选择需要清理的内容，重要文件请先导出。":@"源码、Git 历史、会话与认证信息保留。";}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{
 UITableViewCell *cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];cell.textLabel.numberOfLines=0;cell.detailTextLabel.numberOfLines=0;cell.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];cell.detailTextLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];cell.detailTextLabel.textColor=UIColor.secondaryLabelColor;
 if(i.section==0){unsigned long long total=[self.snapshot[@"deviceTotal"] unsignedLongLongValue],free=[self.snapshot[@"deviceFree"] unsignedLongLongValue];cell.textLabel.text=i.row==0?@"本机存储空间":@"Dylix 占用";cell.imageView.image=[UIImage systemImageNamed:i.row==0?@"internaldrive":@"app.fill"];cell.detailTextLabel.text=i.row==0?[NSString stringWithFormat:@"已用 %@ / 共 %@\n可用 %@",Bytes(total>free?total-free:0),Bytes(total),Bytes(free)]:[NSString stringWithFormat:@"%@ · 含程序与内置工具链",[self.snapshot[@"pending"] boolValue]?@"统计中":Bytes([self.snapshot[@"total"] unsignedLongLongValue])];if(!total&&i.row==0)cell.detailTextLabel.text=@"正在读取本机容量…";cell.selectionStyle=UITableViewCellSelectionStyleNone;return cell;}
 NSDictionary *g=[self groups:i.section==1][i.row];NSString *key=g[@"id"];BOOL selectable=i.section==1,checked=[self.selected containsObject:key];BOOL partial=NO;for(NSDictionary *item in self.selectedItems.allValues)if([item[@"category"] isEqual:key])partial=YES;
 UIColor *color=!selectable?UIColor.secondaryLabelColor:[key isEqual:@"trash"]?UIColor.systemRedColor:[@[@"headers",@"ipa",@"attachments"] containsObject:key]?UIColor.systemOrangeColor:[@[@"builds",@"exports"] containsObject:key]?UIColor.systemBlueColor:UIColor.systemGreenColor;
 NSString *badgeText=!selectable?@"保留":[key isEqual:@"trash"]?@"永久删除":[@[@"headers",@"ipa",@"attachments"] containsObject:key]?@"重要文件":[@[@"builds",@"exports"] containsObject:key]?@"建议保留":@"低重要性";
 NSDictionary *names=@{@"cache":@"SDK 与缓存",@"temporary":@"过期临时文件",@"builds":@"构建文件",@"exports":@"头文件 ZIP",@"headers":@"导出头文件",@"ipa":@"IPA 导入副本",@"attachments":@"AI 附件",@"backups":@"修改备份"};
 cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];cell.separatorInset=UIEdgeInsetsMake(0,selectable?82:54,0,0);
 UIImageView *icon=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:g[@"symbol"]]];icon.tintColor=color;icon.contentMode=UIViewContentModeScaleAspectFit;
 UILabel *title=[UILabel new];title.text=names[key]?:g[@"name"];title.font=[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];title.adjustsFontForContentSizeCategory=YES;title.numberOfLines=1;title.lineBreakMode=NSLineBreakByTruncatingMiddle;
 UILabel *size=[UILabel new];size.text=[g[@"pending"] boolValue]?@"统计中":Bytes([g[@"bytes"] unsignedLongLongValue]);size.textColor=UIColor.secondaryLabelColor;size.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];size.adjustsFontForContentSizeCategory=YES;[size setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];[size setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

 UILabel *badge=[UILabel new];badge.text=[NSString stringWithFormat:@"  %@  ",badgeText];badge.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];badge.textColor=color;badge.backgroundColor=[color colorWithAlphaComponent:.13];badge.layer.cornerRadius=4;badge.clipsToBounds=YES;[badge setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
 [title setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];[badge setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
 UIView *spacer=[UIView new];UIStackView *heading=[[UIStackView alloc]initWithArrangedSubviews:@[title,badge,spacer]];heading.spacing=6;heading.alignment=UIStackViewAlignmentCenter;
 NSDictionary *summaries=@{@"linux":@"当前 Linux 文件与工具，点击查看或管理",@"cache":@"清理后自动生成，首次构建稍慢",@"temporary":@"仅删除超过 24 小时的临时文件",@"builds":@"删除产物和日志，项目源码保留",@"exports":@"删除导出 ZIP，分享时需重新生成",@"headers":@"删除头文件，需原 IPA 重新导出",@"ipa":@"删除本机副本，后续需重新添加",@"attachments":@"删除参考副本，聊天记录保留",@"trash":@"永久删除回收站项目，结束恢复期",@"projects":@"保留项目源码与全部 Git 历史",@"sessions":@"保留消息、图片与已发送文本",@"backups":@"保留撤回备份与操作审查记录",@"application":@"保留程序、编译器与内置资源",@"other":@"点击查看实际目录与大小，避免误删未知数据"};
 UILabel *summary=[UILabel new];summary.text=summaries[key]?:g[@"impact"];summary.font=[UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];summary.adjustsFontForContentSizeCategory=YES;summary.textColor=UIColor.secondaryLabelColor;summary.numberOfLines=2;summary.lineBreakMode=NSLineBreakByTruncatingTail;
 UIStackView *text=[[UIStackView alloc]initWithArrangedSubviews:@[heading,summary]];text.axis=UILayoutConstraintAxisVertical;text.spacing=5;
 UIImageView *choice=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:selectable?(checked?@"checkmark.circle.fill":partial?@"minus.circle.fill":@"circle"):@"lock.fill"]];choice.tintColor=selectable?([g[@"bytes"] unsignedLongLongValue]>0?UIColor.systemBlueColor:UIColor.tertiaryLabelColor):UIColor.tertiaryLabelColor;choice.contentMode=UIViewContentModeScaleAspectFit;
 UIButton *toggle=[UIButton buttonWithType:UIButtonTypeSystem];toggle.translatesAutoresizingMaskIntoConstraints=NO;toggle.accessibilityLabel=[g[@"name"] stringByAppendingString:@"，全选或取消"];__weak typeof(self) weak=self;[toggle addAction:[UIAction actionWithHandler:^(UIAction *a){[weak toggleCategory:key];}] forControlEvents:UIControlEventTouchUpInside];if(selectable)[cell.contentView addSubview:toggle];cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
 for(UIView *view in @[icon,text,size,choice]){view.translatesAutoresizingMaskIntoConstraints=NO;[cell.contentView addSubview:view];}
 [NSLayoutConstraint activateConstraints:@[[icon.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:selectable?48:16],[icon.widthAnchor constraintEqualToConstant:22],[icon.heightAnchor constraintEqualToConstant:22],[icon.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],[text.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],[text.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10],[text.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-10],[text.trailingAnchor constraintEqualToAnchor:size.leadingAnchor constant:-10],[size.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],[size.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:selectable?-8:-40],(selectable?[choice.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:14]:[choice.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16]),[choice.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],[choice.widthAnchor constraintEqualToConstant:selectable?22:14],[choice.heightAnchor constraintEqualToAnchor:choice.widthAnchor],[badge.heightAnchor constraintEqualToConstant:18]]];
 if(selectable)[NSLayoutConstraint activateConstraints:@[[toggle.centerXAnchor constraintEqualToAnchor:choice.centerXAnchor],[toggle.centerYAnchor constraintEqualToAnchor:choice.centerYAnchor],[toggle.widthAnchor constraintEqualToConstant:44],[toggle.heightAnchor constraintEqualToConstant:44]]];
 cell.accessibilityLabel=[NSString stringWithFormat:@"%@，%@，%@",g[@"name"],size.text,[badgeText stringByAppendingFormat:@"，%@",summary.text]];cell.accessibilityValue=selectable?(checked?@"已选择":partial?@"部分选择":@"未选择"):@"保留";cell.selectionStyle=[g[@"bytes"] unsignedLongLongValue]>0?UITableViewCellSelectionStyleDefault:UITableViewCellSelectionStyleNone;return cell;
}
- (void)toggleCategory:(NSString *)key{if(self.working)return;BOOL had=[self.selected containsObject:key];[self.selected removeObject:key];for(NSString *path in self.selectedItems.allKeys)if([self.selectedItems[path][@"category"] isEqual:key])[self.selectedItems removeObjectForKey:path];if(!had)[self.selected addObject:key];[self.tableView reloadData];[self updateButton];}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{[t deselectRowAtIndexPath:i animated:YES];if(i.section==0||self.working)return;NSDictionary *g=[self groups:i.section==1][i.row];NSString *key=g[@"id"];if([self.selected containsObject:key]){[self.selected removeObject:key];for(NSDictionary *root in self.snapshot[@"entries"])if([root[@"category"] isEqual:key])self.selectedItems[root[@"path"]]=root;}
 __weak typeof(self) weak=self;[self.navigationController pushViewController:StorageBrowser(self.snapshot,key,nil,self.selectedItems,^{[weak.tableView reloadData];[weak updateButton];}) animated:YES];}

- (void)message:(NSString *)title text:(NSString *)text{UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];}
- (void)confirm{
 if(self.cleaning){[self.cleanProgress cancel];return;}if(self.working||!self.selectedBytes)return;
 NSMutableArray *lines=[NSMutableArray new];for(NSDictionary *item in self.selectedItems.allValues)[lines addObject:[NSString stringWithFormat:@"%@ · %@",[item[@"path"] lastPathComponent],Bytes([item[@"bytes"] unsignedLongLongValue])]];for(NSDictionary *g in [self groups:YES])if([self.selected containsObject:g[@"id"]]||[self.selectedItems.allValues filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item,NSDictionary *bindings){return [item[@"category"] isEqual:g[@"id"]];}]].count)[lines addObject:[NSString stringWithFormat:@"%@（%@）\n%@",g[@"name"],Bytes([g[@"bytes"] unsignedLongLongValue]),g[@"impact"]]];
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"清理约 %@？",Bytes(self.selectedBytes)] message:[[lines componentsJoinedByString:@"\n\n"] stringByAppendingString:@"\n\n这些内容将直接删除，请确认已保存需要的文件。"] preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[alert addAction:[UIAlertAction actionWithTitle:@"确认清理" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){[self clean];}]];[self presentViewController:alert animated:YES completion:nil];
}
- (void)clean{
 if(TFAIHasLiveRuns()||TFAIClassDumpIsActive()||[TMCGitLease hasActiveBuilds]){[self message:@"有任务正在处理" text:@"请等待构建、头文件导出或 AI 任务完成后再清理。"];return;}
 self.working=YES;self.cleaning=YES;self.cleanProgress=[NSProgress progressWithTotalUnitCount:1];[self updateButton];UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];[spinner startAnimating];self.navigationItem.titleView=spinner;NSDictionary *snapshot=self.snapshot;NSSet *selected=[self.selected copy];NSMutableArray *items=[self.selectedItems.allValues mutableCopy];for(NSDictionary *root in snapshot[@"entries"])if([selected containsObject:root[@"category"]])[items addObject:root];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{@autoreleasepool{
 TMCGitLease *lease __attribute__((objc_precise_lifetime))=[TMCGitLease tryWrite];NSError *error=nil;NSDictionary *result=nil;if(!lease||TFAIHasLiveRuns()||TFAIClassDumpIsActive()||[TMCGitLease hasActiveBuilds])error=SE(@"Git、构建或 AI 任务正在处理，请稍后再试。");else result=TMCStorageCleanItemsProgress(snapshot,items,self.cleanProgress,^(NSDictionary *state){dispatch_async(dispatch_get_main_queue(),^{[self.cleanButton setTitle:[NSString stringWithFormat:@"%@ · %@/%@ · 点此停止",state[@"stage"],state[@"completed"],state[@"total"]] forState:UIControlStateNormal];});},&error);
 dispatch_async(dispatch_get_main_queue(),^{self.navigationItem.titleView=nil;self.cleaning=NO;self.working=NO;[self scan];[self message:[result[@"cancelled"] boolValue]?@"清理已停止":error?@"清理未全部完成":@"清理完成" text:[NSString stringWithFormat:@"已释放约 %@\n%@",Bytes([result[@"removed"] unsignedLongLongValue]),error.localizedDescription?:@"保留内容未作更改。"]];});}});
}
@end

@interface TMCStorageBrowser : UITableViewController
@property NSDictionary *snapshot;
@property NSString *category;
@property NSString *directory;
@property NSArray *items;
@property NSMutableDictionary *selection;
@property(copy) void(^changed)(void);
@property BOOL selecting;
@end
@implementation TMCStorageBrowser
- (void)viewDidLoad{[super viewDidLoad];self.title=self.directory?TMCDocumentDisplayName(self.directory):@"文件明细";if(!self.directory)for(NSDictionary *g in Definitions())if([g[@"id"] isEqual:self.category])self.title=g[@"name"];self.tableView.rowHeight=62;self.tableView.estimatedRowHeight=62;if(Clearable(self.category))self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"全选" style:UIBarButtonItemStylePlain target:self action:@selector(selectAll)];if([self.category isEqual:@"linux"]){self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"环境管理" style:UIBarButtonItemStylePlain target:self action:@selector(manageLinux)];}[self loadItems];}
- (void)manageLinux{[self.navigationController pushViewController:TFAIISHEnvironmentController(nil,nil) animated:YES];}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self.tableView reloadData];}
- (void)loadItems{UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];[spinner startAnimating];self.tableView.backgroundView=spinner;self.navigationItem.rightBarButtonItem.enabled=NO;dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSError *error=nil;NSArray *items=TMCStorageChildren(self.snapshot,self.category,self.directory,&error);dispatch_async(dispatch_get_main_queue(),^{self.items=items?:@[];UILabel *empty=[UILabel new];empty.text=error.localizedDescription?:@"没有可清理文件";empty.textAlignment=NSTextAlignmentCenter;empty.textColor=UIColor.secondaryLabelColor;empty.numberOfLines=0;self.tableView.backgroundView=self.items.count?nil:empty;self.navigationItem.rightBarButtonItem.enabled=[self.category isEqual:@"linux"]||(Clearable(self.category)&&self.items.count>0);[self.tableView reloadData];});});}
- (BOOL)chosen:(NSString *)path in:(NSDictionary *)selection{for(NSString *selected in selection)if([path isEqual:selected]||[path hasPrefix:[selected stringByAppendingString:@"/"]])return YES;return NO;}
- (BOOL)chosen:(NSString *)path{return [self chosen:path in:self.selection];}
- (void)toggleSelection:(NSDictionary *)item in:(NSMutableDictionary *)selection{NSString *path=item[@"path"];if([self chosen:path in:selection]){
 for(NSString *selected in selection.allKeys)if([path isEqual:selected]||[path hasPrefix:[selected stringByAppendingString:@"/"]]){[selection removeObjectForKey:selected];if(![path isEqual:selected]){NSString *cursor=selected;while(![cursor isEqual:path]){NSArray *children=TMCStorageChildren(self.snapshot,self.category,cursor,nil);NSString *next=nil;for(NSDictionary *child in children){NSString *childPath=child[@"path"];if([path isEqual:childPath]||[path hasPrefix:[childPath stringByAppendingString:@"/"]])next=childPath;else selection[childPath]=child;}if(!next)break;cursor=next;}}}
 }else{for(NSString *selected in selection.allKeys)if([selected hasPrefix:[path stringByAppendingString:@"/"]])[selection removeObjectForKey:selected];selection[path]=item;}}
- (void)performSelection:(void(^)(NSMutableDictionary *))operation{if(self.selecting)return;self.selecting=YES;self.navigationItem.rightBarButtonItem.enabled=NO;NSMutableDictionary *draft=[self.selection mutableCopy];UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];[spinner startAnimating];self.navigationItem.titleView=spinner;dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{operation(draft);dispatch_async(dispatch_get_main_queue(),^{[self.selection setDictionary:draft];self.selecting=NO;self.navigationItem.rightBarButtonItem.enabled=YES;self.navigationItem.titleView=nil;[self.tableView reloadData];if(self.changed)self.changed();});});}
- (void)toggle:(NSDictionary *)item{[self performSelection:^(NSMutableDictionary *draft){[self toggleSelection:item in:draft];}];}
- (void)selectAll{[self performSelection:^(NSMutableDictionary *draft){BOOL all=YES;for(NSDictionary *item in self.items)if(![self chosen:item[@"path"] in:draft])all=NO;for(NSDictionary *item in self.items){BOOL chosen=[self chosen:item[@"path"] in:draft];if(all?chosen:!chosen)[self toggleSelection:item in:draft];}}];}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section{return self.items.count;}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{NSDictionary *item=self.items[i.row];NSString *path=item[@"path"];UITableViewCell *cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];cell.textLabel.text=[NSString stringWithFormat:@"%@ · %@",TMCDocumentDisplayName(path),Bytes([item[@"bytes"] unsignedLongLongValue])];cell.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];cell.textLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;NSString *relative=path;for(NSString *root in @[self.snapshot[@"documents"],self.snapshot[@"library"],self.snapshot[@"temporary"]])if([path hasPrefix:[root stringByAppendingString:@"/"]]){relative=[NSString stringWithFormat:@"%@/%@",root.lastPathComponent,[path substringFromIndex:root.length+1]];break;}cell.detailTextLabel.text=relative;cell.detailTextLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;cell.detailTextLabel.textColor=UIColor.secondaryLabelColor;UIButton *check=[UIButton buttonWithType:UIButtonTypeSystem];[check setImage:[UIImage systemImageNamed:[self chosen:path]?@"checkmark.circle.fill":@"circle"] forState:UIControlStateNormal];check.frame=CGRectMake(0,0,44,44);check.accessibilityLabel=[path.lastPathComponent stringByAppendingString:@"，选择或取消"];[check addAction:[UIAction actionWithHandler:^(UIAction *action){[self toggle:item];}] forControlEvents:UIControlEventTouchUpInside];check.accessibilityValue=[self chosen:path]?@"已选择":@"未选择";if(Clearable(self.category))cell.accessoryView=check;else cell.accessoryType=[item[@"directory"] boolValue]?UITableViewCellAccessoryDisclosureIndicator:UITableViewCellAccessoryNone;cell.imageView.image=[UIImage systemImageNamed:[item[@"directory"] boolValue]?@"folder":@"doc"];return cell;}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{[t deselectRowAtIndexPath:i animated:YES];NSDictionary *item=self.items[i.row];if([item[@"directory"] boolValue])[self.navigationController pushViewController:StorageBrowser(self.snapshot,self.category,item[@"path"],self.selection,self.changed) animated:YES];else if(Clearable(self.category))[self toggle:item];}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)section{return Clearable(self.category)?@"点击目录查看内部文件，右侧圆圈选择整项。返回后确认清理。":@"这里只查看实际目录与大小。Linux 文件系统可通过环境管理删除；程序包不能从运行中的软件删除。";}
@end
static UIViewController *StorageBrowser(NSDictionary *snapshot,NSString *category,NSString *directory,NSMutableDictionary *selection,void(^changed)(void)){TMCStorageBrowser *page=[[TMCStorageBrowser alloc]initWithStyle:UITableViewStyleInsetGrouped];page.snapshot=snapshot;page.category=category;page.directory=directory;page.selection=selection;page.changed=changed;return page;}
UIViewController *TMCStorageController(void){return [TMCStoragePage new];}
#endif

#import "TFAIISHEnvironment.h"
#import <sys/stat.h>
#import <sqlite3.h>
#import <unistd.h>
static NSError *EnvError(NSString *text){return [NSError errorWithDomain:@"Dylix.ISH.Environment" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}
static BOOL Key(NSString *key){return [key isKindOfClass:NSString.class]&&key.length==64&&[key rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location==NSNotFound;}
static BOOL PlainDirectory(NSString *path){struct stat st;return !lstat(path.fileSystemRepresentation,&st)&&S_ISDIR(st.st_mode)&&!S_ISLNK(st.st_mode);}
static BOOL SafeBase(NSString *base){return base.isAbsolutePath&&[base isEqual:base.stringByStandardizingPath]&&[base isEqual:base.stringByResolvingSymlinksInPath]&&PlainDirectory(base);}
static BOOL Regular(NSString *path){struct stat st;return !lstat(path.fileSystemRepresentation,&st)&&S_ISREG(st.st_mode)&&st.st_nlink==1;}
static NSDictionary *MeasureTree(NSString *path){
 __block uint64_t bytes=0;__block NSUInteger files=0;NSMutableSet *inodes=[NSMutableSet new];
 void (^visit)(NSString *)=^(NSString *item){struct stat st;if(lstat(item.fileSystemRepresentation,&st))return;
  NSString *key=[NSString stringWithFormat:@"%llu:%llu",(unsigned long long)st.st_dev,(unsigned long long)st.st_ino];
  if(!S_ISREG(st.st_mode)||![inodes containsObject:key])bytes+=(uint64_t)st.st_blocks*512;
  if(S_ISREG(st.st_mode)){files++;[inodes addObject:key];}
 };
 visit(path);NSDirectoryEnumerator *walk=[NSFileManager.defaultManager enumeratorAtPath:path];for(NSString *name in walk){NSString *item=[path stringByAppendingPathComponent:name];struct stat st;if(!lstat(item.fileSystemRepresentation,&st)&&S_ISLNK(st.st_mode))[walk skipDescendants];visit(item);}
 return @{@"bytes":@(bytes),@"files":@(files)};
}
static BOOL CanonicalDirectory(NSString *path){return PlainDirectory(path)&&[path isEqual:path.stringByResolvingSymlinksInPath];}
static BOOL ValidRoot(NSString *path){return CanonicalDirectory(path)&&PlainDirectory([path stringByAppendingPathComponent:@"data"])&&Regular([path stringByAppendingPathComponent:@"meta.db"])&&Regular([path stringByAppendingPathComponent:@".dylix-rootfs-v1"]);}
static BOOL DatabaseValid(NSString *root){
 sqlite3 *db=NULL;sqlite3_stmt *stmt=NULL;BOOL ok=NO;
 if(sqlite3_open_v2([root stringByAppendingPathComponent:@"meta.db"].fileSystemRepresentation,&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK&&sqlite3_prepare_v2(db,"PRAGMA quick_check",-1,&stmt,NULL)==SQLITE_OK&&sqlite3_step(stmt)==SQLITE_ROW){const char *value=(const char *)sqlite3_column_text(stmt,0);ok=value&&!strcmp(value,"ok");}
 sqlite3_finalize(stmt);if(db)sqlite3_close(db);return ok;
}
static BOOL WriteRecord(id record,NSString *path,NSError **error){NSData *data=[NSPropertyListSerialization dataWithPropertyList:record format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];if(!data||![data writeToFile:path options:NSDataWritingAtomic error:error])return NO;return [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:path error:error];}
// Offline only: preserve host hardlinks and copy meta.db/WAL as one closed tree.
// fakefs detects the copied database inode at mount and rebuilds its inode map.
static BOOL CopyRoot(NSString *from,NSString *to,NSError **error){
 NSFileManager *fm=NSFileManager.defaultManager;
 if(!ValidRoot(from)||!DatabaseValid(from)||!CanonicalDirectory(to.stringByDeletingLastPathComponent)||[fm fileExistsAtPath:to]){if(error)*error=EnvError(@"文件系统或元数据校验失败，原数据未修改。");return NO;}
 if(![fm createDirectoryAtPath:to withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:error])return NO;
 BOOL ok=YES;NSMutableDictionary *links=[NSMutableDictionary new];NSDirectoryEnumerator *walk=[fm enumeratorAtPath:from];
 for(NSString *name in walk){NSString *source=[from stringByAppendingPathComponent:name],*target=[to stringByAppendingPathComponent:name];struct stat st;
  if(lstat(source.fileSystemRepresentation,&st)){ok=NO;break;}
  // Native bind links and special nodes are not a portable fakefs snapshot.
  if(S_ISLNK(st.st_mode)||(!S_ISREG(st.st_mode)&&!S_ISDIR(st.st_mode))){ok=NO;break;}
  NSString *inode=[NSString stringWithFormat:@"%llu:%llu",(unsigned long long)st.st_dev,(unsigned long long)st.st_ino];
  if(S_ISDIR(st.st_mode))ok=[fm createDirectoryAtPath:target withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:error];
  else if(links[inode])ok=link([links[inode] fileSystemRepresentation],target.fileSystemRepresentation)==0;
  else {ok=[fm copyItemAtPath:source toPath:target error:error];if(ok&&st.st_nlink>1)links[inode]=target;}
  if(!ok)break;
 }
 ok=ok&&ValidRoot(to)&&DatabaseValid(to);
 if(!ok){[fm removeItemAtPath:to error:nil];if(error&&!*error)*error=EnvError(@"快照包含异常文件或复制校验失败，原环境已保留。");}
 return ok;
}
@implementation TFAIISHEnvironment
+ (NSString *)basePath{return [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject.stringByResolvingSymlinksInPath stringByAppendingPathComponent:@"Dylix/iSH-v1"];}
+ (NSString *)sharedKey{return @"b3699d2b0a236797eb0b19394441f1795d2bdd9a55103d75a13783a4bc276d3c";}
+ (BOOL)prepareSharedAtBase:(NSString *)base error:(NSError **)error{@synchronized(self){
 if(!SafeBase(base)){if(error)*error=EnvError(@"共享环境目录不安全，旧数据已保留。");return NO;}NSFileManager *fm=NSFileManager.defaultManager;NSString *target=[base stringByAppendingPathComponent:self.sharedKey],*record=[base stringByAppendingPathComponent:@"shared-environment.plist"];BOOL hasRecord=[fm fileExistsAtPath:record];NSDictionary *plan=Regular(record)?[NSDictionary dictionaryWithContentsOfFile:record]:nil;
 if(hasRecord&&(!plan||![plan[@"format"] isEqual:@1])){if(error)*error=EnvError(@"共享环境迁移记录异常，未覆盖任何环境。");return NO;}
 if([fm fileExistsAtPath:target]){if(!ValidRoot(target)||!DatabaseValid(target)){if(error)*error=EnvError(@"共享环境不完整，已保留数据；请从环境管理恢复快照，不会自动重装覆盖。");return NO;}if([plan[@"state"] isEqual:@"pending"]){NSMutableDictionary *done=[plan mutableCopy];done[@"state"]=@"complete";return WriteRecord(done,record,error);}return YES;}
 if([plan[@"state"] isEqual:@"complete"])return YES; // Explicit reset/deletion must not resurrect another old tree.
 NSString *sourceKey=plan[@"sourceKey"];
 if(!plan){unsigned long long best=0;for(NSString *key in [[fm contentsOfDirectoryAtPath:base error:nil] sortedArrayUsingSelector:@selector(compare:)]){NSString *root=[base stringByAppendingPathComponent:key];if(!Key(key)||[key isEqual:self.sharedKey]||!ValidRoot(root)||!DatabaseValid(root))continue;
  NSString *db=[root stringByAppendingPathComponent:@"data/lib/apk/db/installed"];NSDictionary *attrs=[fm attributesOfItemAtPath:db error:nil];NSString *packages=[attrs[NSFileSize] unsignedLongLongValue]<=16*1024*1024?[NSString stringWithContentsOfFile:db encoding:NSUTF8StringEncoding error:nil]:nil;
  unsigned long long score=1+[[packages componentsSeparatedByString:@"\nP:"] count]*10;for(NSString *path in @[@"data/usr/bin/python3",@"data/usr/bin/node",@"data/usr/bin/git",@"data/opt/dylix-reverse/usr/bin/radare2"]){if([fm fileExistsAtPath:[root stringByAppendingPathComponent:path]])score+=100;}
  score+=[[fm contentsOfDirectoryAtPath:[root stringByAppendingPathComponent:@"data/usr/local/bin"] error:nil] count]*10;if(!sourceKey||score>best){sourceKey=key;best=score;}
 }
 plan=@{@"format":@1,@"state":sourceKey?@"pending":@"complete",@"sourceKey":sourceKey?:@"",@"createdAt":NSDate.date};if(!WriteRecord(plan,record,error))return NO;}
 if(!sourceKey.length)return YES;NSString *source=[base stringByAppendingPathComponent:sourceKey];if(!Key(sourceKey)||[sourceKey isEqual:self.sharedKey]||!ValidRoot(source)||!DatabaseValid(source)){if(error)*error=EnvError(@"待迁移的旧环境不可用，数据已保留，未创建空环境替代。");return NO;}
 if(![fm moveItemAtPath:source toPath:target error:error])return NO;NSMutableDictionary *done=[plan mutableCopy];done[@"state"]=@"complete";return WriteRecord(done,record,error);
}}
+ (NSDictionary *)inventoryAtBase:(NSString *)base{@synchronized(self){
 NSMutableArray *sessions=[NSMutableArray new],*snapshots=[NSMutableArray new];if(!SafeBase(base))return @{@"sessions":sessions,@"snapshots":snapshots,@"bytes":@0,@"pending":@{},@"version":@"Alpine 3.21.0"};
 for(NSString *name in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:base error:nil] sortedArrayUsingSelector:@selector(compare:)]){NSString *path=[base stringByAppendingPathComponent:name];if(!Key(name)||!PlainDirectory(path))continue;NSMutableDictionary *entry=[MeasureTree(path) mutableCopy];entry[@"key"]=name;entry[@"shared"]=@([name isEqual:self.sharedKey]);entry[@"archiveSHA256"]=[NSString stringWithContentsOfFile:[path stringByAppendingPathComponent:@".dylix-rootfs-v1"] encoding:NSUTF8StringEncoding error:nil]?:@"";entry[@"version"]=[entry[@"archiveSHA256"] isEqual:@"74eaa1f80aceb35a69f26a7772cd22848a51921323a32b2ae057b2a4c8188fd5"]?@"Alpine 3.22.0":@"Alpine 3.21.0";entry[@"valid"]=@(ValidRoot(path));entry[@"createdAt"]=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileCreationDate]?:NSDate.distantPast;[sessions addObject:entry];}
 NSString *backup=[base stringByAppendingPathComponent:@"snapshots"];if(CanonicalDirectory(backup))for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:backup error:nil]){if(![[NSUUID alloc]initWithUUIDString:name])continue;NSString *path=[backup stringByAppendingPathComponent:name];if(!CanonicalDirectory(path)||!Regular([path stringByAppendingPathComponent:@"snapshot.plist"]))continue;NSDictionary *meta=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"snapshot.plist"]];if(!Key(meta[@"sessionKey"])||!ValidRoot([path stringByAppendingPathComponent:@"rootfs"]))continue;NSMutableDictionary *entry=[MeasureTree(path) mutableCopy];entry[@"id"]=name;entry[@"sessionKey"]=meta[@"sessionKey"];entry[@"createdAt"]=[meta[@"createdAt"] isKindOfClass:NSDate.class]?meta[@"createdAt"]:NSDate.distantPast;[snapshots addObject:entry];}
 [snapshots sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [b[@"createdAt"] compare:a[@"createdAt"]];}];NSString *pending=[base stringByAppendingPathComponent:@"pending-maintenance.plist"];
 return @{@"version":@"Alpine 3.21.0",@"bytes":MeasureTree(base)[@"bytes"],@"sessions":sessions,@"snapshots":snapshots,@"pending":Regular(pending)?([NSDictionary dictionaryWithContentsOfFile:pending]?:@{}):@{}};
}}
+ (BOOL)schedule:(NSString *)operation sessionKey:(NSString *)key snapshot:(NSString *)snapshot base:(NSString *)base error:(NSError **)error{@synchronized(self){
 if(!SafeBase(base)||!Key(key)||![@[@"backup",@"reset",@"restore",@"delete",@"activate"] containsObject:operation]||!ValidRoot([base stringByAppendingPathComponent:key])){if(error)*error=EnvError(@"环境或操作无效，请刷新后重试。");return NO;}
 NSString *pending=[base stringByAppendingPathComponent:@"pending-maintenance.plist"];if([NSFileManager.defaultManager fileExistsAtPath:pending]){if(error)*error=EnvError(@"已有待执行维护，请先完成或取消。");return NO;}
 if([operation isEqual:@"restore"]){if(![snapshot isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:snapshot]){if(error)*error=EnvError(@"快照ID无效。");return NO;}NSString *path=[[base stringByAppendingPathComponent:@"snapshots"] stringByAppendingPathComponent:snapshot];NSDictionary *meta=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"snapshot.plist"]];if(!CanonicalDirectory(path)||!Regular([path stringByAppendingPathComponent:@"snapshot.plist"])||![meta[@"sessionKey"] isEqual:key]||!ValidRoot([path stringByAppendingPathComponent:@"rootfs"])){if(error)*error=EnvError(@"快照不属于该会话或已损坏。");return NO;}}
 return WriteRecord(@{@"operation":operation,@"sessionKey":key,@"snapshot":snapshot?:@"",@"requestedAt":NSDate.date},pending,error);
}}
+ (BOOL)deleteSnapshot:(NSString *)identifier base:(NSString *)base error:(NSError **)error{@synchronized(self){
 if(!SafeBase(base)||![identifier isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:identifier]){if(error)*error=EnvError(@"快照路径无效，未删除。");return NO;}
 NSString *pending=[base stringByAppendingPathComponent:@"pending-maintenance.plist"];if([NSFileManager.defaultManager fileExistsAtPath:pending]){if(error)*error=EnvError(@"请先完成或取消维护安排，再删除快照。");return NO;}
 NSString *path=[[base stringByAppendingPathComponent:@"snapshots"] stringByAppendingPathComponent:identifier];NSDictionary *meta=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"snapshot.plist"]];
 if(!CanonicalDirectory(path)||!Regular([path stringByAppendingPathComponent:@"snapshot.plist"])||!Key(meta[@"sessionKey"])||!ValidRoot([path stringByAppendingPathComponent:@"rootfs"])){if(error)*error=EnvError(@"快照已变化或不完整，未删除。");return NO;}
 return [NSFileManager.defaultManager removeItemAtPath:path error:error];
}}
+ (BOOL)cancelPendingAtBase:(NSString *)base error:(NSError **)error{@synchronized(self){if(!SafeBase(base)){if(error)*error=EnvError(@"环境目录无效。");return NO;}NSString *path=[base stringByAppendingPathComponent:@"pending-maintenance.plist"];NSDictionary *plan=Regular(path)?[NSDictionary dictionaryWithContentsOfFile:path]:nil;if([plan[@"operation"] isEqual:@"delete"]&&Key(plan[@"sessionKey"])&&[NSFileManager.defaultManager fileExistsAtPath:[base stringByAppendingPathComponent:[plan[@"sessionKey"] stringByAppendingString:@".delete"]]]){if(error)*error=EnvError(@"环境删除已开始，不能取消；请重启后继续完成清理。");return NO;}if([plan[@"operation"] isEqual:@"activate"]&&([plan[@"phase"] isEqual:@"swapped"]||[NSFileManager.defaultManager fileExistsAtPath:[base stringByAppendingPathComponent:@".shared-previous"]])){if(error)*error=EnvError(@"环境切换已开始，不能取消；请重启后完成恢复。");return NO;}return ![NSFileManager.defaultManager fileExistsAtPath:path]||[NSFileManager.defaultManager removeItemAtPath:path error:error];}}
+ (BOOL)applyPendingAtBase:(NSString *)base error:(NSError **)error{@synchronized(self){
 if(!SafeBase(base)){if(error)*error=EnvError(@"环境目录不可维护。");return NO;}NSFileManager *fm=NSFileManager.defaultManager;NSString *pending=[base stringByAppendingPathComponent:@"pending-maintenance.plist"];if(![fm fileExistsAtPath:pending])return YES;
 NSDictionary *plan=Regular(pending)?[NSDictionary dictionaryWithContentsOfFile:pending]:nil;NSString *key=plan[@"sessionKey"],*operation=plan[@"operation"];
 if(!Key(key)||![@[@"backup",@"reset",@"restore",@"delete",@"activate"] containsObject:operation]){if(error)*error=EnvError(@"维护记录无效；原数据保留，请取消待办后重试。");return NO;}
 NSString *root=[base stringByAppendingPathComponent:key],*backupBase=[base stringByAppendingPathComponent:@"snapshots"];
 // Swap a retained legacy environment into the fixed global slot; retain the previous global at the legacy slot.
 if([operation isEqual:@"activate"]){NSString *shared=[base stringByAppendingPathComponent:self.sharedKey],*previous=[base stringByAppendingPathComponent:@".shared-previous"];if([plan[@"phase"] isEqual:@"swapped"]&&ValidRoot(shared)&&ValidRoot(root)&&![fm fileExistsAtPath:previous])return [fm removeItemAtPath:pending error:error];if([key isEqual:self.sharedKey]){if(error)*error=EnvError(@"已经是共享环境。");return NO;}
  if([fm fileExistsAtPath:previous]){if([fm fileExistsAtPath:shared]){if(![fm fileExistsAtPath:root]){if(![fm moveItemAtPath:previous toPath:root error:error])return NO;return [fm removeItemAtPath:pending error:error];}if(error)*error=EnvError(@"环境切换存在两个副本，请先检查；未删除任何数据。");return NO;}if(![fm moveItemAtPath:previous toPath:shared error:error])return NO;}
  if(!ValidRoot(root)||!DatabaseValid(root)||!ValidRoot(shared)||!DatabaseValid(shared)){if(error)*error=EnvError(@"环境校验失败，未切换。");return NO;}
  if(![fm moveItemAtPath:shared toPath:previous error:error])return NO;if(![fm moveItemAtPath:root toPath:shared error:error]){[fm moveItemAtPath:previous toPath:shared error:nil];return NO;}NSMutableDictionary *committed=[plan mutableCopy];committed[@"phase"]=@"swapped";if(!WriteRecord(committed,pending,error))return NO;if(![fm moveItemAtPath:previous toPath:root error:error])return NO;return [fm removeItemAtPath:pending error:error];
 }
 // Deletion is scheduled explicitly and runs only before the guest boots.
 if([operation isEqual:@"delete"]){NSString *tomb=[base stringByAppendingPathComponent:[key stringByAppendingString:@".delete"]];if([fm fileExistsAtPath:root]){if(!ValidRoot(root)||!DatabaseValid(root)||[fm fileExistsAtPath:tomb]){if(error)*error=EnvError(@"环境已变化，未执行删除。");return NO;}if(![fm moveItemAtPath:root toPath:tomb error:error])return NO;}if([fm fileExistsAtPath:tomb]){if(!CanonicalDirectory(tomb)){if(error)*error=EnvError(@"待删除环境路径异常。");return NO;}if(![fm removeItemAtPath:tomb error:error])return NO;}return [fm removeItemAtPath:pending error:error];}
 // Recover an interrupted cutover before processing anything else.
 NSString *rollback=[base stringByAppendingPathComponent:[key stringByAppendingString:@".previous"]];
 if(PlainDirectory(rollback)){if(PlainDirectory(root)){if(error)*error=EnvError(@"检测到未完成的环境切换，两个副本均已保留；请先导出检查。");return NO;}if(![fm moveItemAtPath:rollback toPath:root error:error])return NO;}
 if(!ValidRoot(root)){if(error)*error=EnvError(@"当前环境不完整；原数据保留，不执行重建。");return NO;}
 if(![fm createDirectoryAtPath:backupBase withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:nil]&&!PlainDirectory(backupBase)){if(error)*error=EnvError(@"快照目录不可用。");return NO;}
 if(![backupBase isEqual:backupBase.stringByResolvingSymlinksInPath]){if(error)*error=EnvError(@"快照目录不能是符号链接。");return NO;}
 NSString *backup=[backupBase stringByAppendingPathComponent:NSUUID.UUID.UUIDString],*stage=[base stringByAppendingPathComponent:[@".restore-" stringByAppendingString:NSUUID.UUID.UUIDString]];
 if(![fm createDirectoryAtPath:backup withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:error])return NO;
 if(!CopyRoot(root,[backup stringByAppendingPathComponent:@"rootfs"],error)||!WriteRecord(@{@"sessionKey":key,@"createdAt":NSDate.date,@"reason":operation},[backup stringByAppendingPathComponent:@"snapshot.plist"],error)){[fm removeItemAtPath:backup error:nil];return NO;}
 if([operation isEqual:@"backup"])return [fm removeItemAtPath:pending error:error];
 if([operation isEqual:@"restore"]){NSString *identifier=plan[@"snapshot"];if(![identifier isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:identifier]){if(error)*error=EnvError(@"快照ID无效，原数据与备份均已保留。");return NO;}NSString *source=[[backupBase stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:@"rootfs"];NSDictionary *meta=[NSDictionary dictionaryWithContentsOfFile:[source.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"snapshot.plist"]];if(!CanonicalDirectory(source.stringByDeletingLastPathComponent)||!Regular([source.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"snapshot.plist"])||![meta[@"sessionKey"] isEqual:key]||!CopyRoot(source,stage,error))return NO;}
 if(![fm moveItemAtPath:root toPath:rollback error:error]){[fm removeItemAtPath:stage error:nil];return NO;}
 if([operation isEqual:@"restore"]&&![fm moveItemAtPath:stage toPath:root error:error]){[fm moveItemAtPath:rollback toPath:root error:nil];return NO;}
 if(![fm removeItemAtPath:pending error:error]){if([fm fileExistsAtPath:root])[fm moveItemAtPath:root toPath:stage error:nil];[fm moveItemAtPath:rollback toPath:root error:nil];[fm removeItemAtPath:stage error:nil];return NO;}
 // Verified backup is retained for every reset/restore. Root recreation is handled by InstallRoot.
 [fm removeItemAtPath:rollback error:nil];return YES;
}}
@end

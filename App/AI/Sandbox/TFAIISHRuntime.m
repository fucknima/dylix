// Dylix embedded host adapter, GPL-3.0-or-later.
// Uses the public/internal C interfaces of OpenMinis/ish-arm64 (GPL-3.0).
// Boot/PTY integration structure researched in OpenMinis and Kelivo;
// see Vendor/iSH/DYLIX-NOTICE.md for pinned source, patches and licenses.
#import "TFAIISHRuntime.h"
#import "../Permissions/TFAIPolicy.h"
#import <TargetConditionals.h>
#import <math.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <resolv.h>
#include <arpa/inet.h>
#include <netdb.h>
#if DYLIX_HAS_ISH
#define ISH_INTERNAL
#define GUEST_ARM64 1
#define ENGINE_ASBESTOS 1
#include "kernel/init.h"
#include "kernel/calls.h"
#include "kernel/mm.h"
#include "kernel/fs.h"
#include "fs/fake.h"
#include "fs/tty.h"
#include "fs/devices.h"
#include "fs/fd.h"
#include "fs/path.h"
#include "fs/real.h"
#include "kernel/errno.h"
#include "tools/fakefs.h"
#include <os/proc.h>
#include <mach/mach.h>
#endif

NSNotificationName const TFAIISHTerminalOutput=@"Dylix.ISH.TerminalOutput";
NSNotificationName const TFAIISHStatusChanged=@"Dylix.ISH.StatusChanged";
static NSString *const RootfsSHA=@"f31202c4070c4ef7de9e157e1bd01cb4da3a2150035d74ea5372c5e86f1efac1";
static NSError *ISHError(NSString *text){return [NSError errorWithDomain:@"Dylix.ISH" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}
static NSUInteger ProcessRingLimit(void){NSUInteger value=[NSUserDefaults.standardUserDefaults integerForKey:@"DylixISHProcessOutputLimit"];if(!value)value=1024*1024;return MIN(8*1024*1024,MAX(256*1024,value));}
static NSUInteger ProcessConcurrencyLimit(void){NSUInteger value=[NSUserDefaults.standardUserDefaults integerForKey:@"DylixISHProcessConcurrencyLimit"];if(!value)value=8;return MIN(8,MAX(4,value));}
static NSString *ArchivePath(void){return [NSBundle.mainBundle pathForResource:@"alpine-minirootfs-3.21.0-aarch64" ofType:@"tar.gz" inDirectory:@"iSH"];}
static NSString *SessionKey(NSString *sid){return TFAIDigest([sid dataUsingEncoding:NSUTF8StringEncoding]);}
static void Main(void (^block)(void)){dispatch_async(dispatch_get_main_queue(),block);}

#if DYLIX_HAS_ISH
static BOOL GuestPath(NSString *path,BOOL missing,NSError **error){
 if(![path isKindOfClass:NSString.class]||!path.isAbsolutePath||path.length>4096||[path.pathComponents containsObject:@".."]||[path rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound){if(error)*error=ISHError(@"Linux 路径无效");return NO;}
 NSString *prefix=@"";for(NSString *part in path.pathComponents){if([part isEqual:@"/"]||[part isEqual:@"."])continue;prefix=[prefix stringByAppendingFormat:@"/%@",part];struct statbuf st={0};int e=generic_statat(AT_PWD,prefix.UTF8String,&st,false);if(e<0){if(missing&&[prefix isEqual:path.stringByStandardizingPath]&&e==_ENOENT)return YES;if(error)*error=ISHError(@"路径不可读取或父目录不存在");return NO;}if(S_ISLNK(st.mode)||(!S_ISREG(st.mode)&&!S_ISDIR(st.mode))){if(error)*error=ISHError(@"不跟随链接，不访问设备或特殊文件");return NO;}}
 return YES;
}
static BOOL GuestTree(NSString *root,NSMutableArray *rows,NSUInteger depth,uint64_t *bytes,NSError **error){
 if(depth>24||rows.count>=1000){if(error)*error=ISHError(@"目录超过 24 层或 1000 项，请缩小范围");return NO;}
 struct statbuf st={0};if(!GuestPath(root,NO,error)||generic_statat(AT_PWD,root.UTF8String,&st,false)<0)return NO;
 if(S_ISREG(st.mode)){if(st.size<0||(uint64_t)st.size>64*1024*1024||*bytes>64*1024*1024-(uint64_t)st.size){if(error)*error=ISHError(@"目录处理上限为 64 MiB");return NO;}*bytes+=st.size;}
 [rows addObject:@{@"path":root,@"kind":S_ISDIR(st.mode)?@"directory":@"file",@"bytes":@(st.size)}];
 if(S_ISDIR(st.mode)){struct fd *dir=generic_open(root.UTF8String,O_RDONLY_|O_DIRECTORY_|O_NOFOLLOW_,0);if(IS_ERR(dir)){if(error)*error=ISHError(@"目录无法打开");return NO;}struct dir_entry item;int e=0;BOOL ok=YES;while((e=dir->ops->readdir(dir,&item))>0){NSString *name=[NSString stringWithUTF8String:item.name];if(!name||[name isEqual:@"."]||[name isEqual:@".."])continue;if(!GuestTree([root stringByAppendingPathComponent:name],rows,depth+1,bytes,error)){ok=NO;break;}}fd_close(dir);if(e<0){if(error)*error=ISHError(@"目录读取不完整");ok=NO;}return ok;}
 return YES;
}
static NSData *GuestRead(NSString *path,NSUInteger limit,NSError **error){
 if(!GuestPath(path,NO,error))return nil;struct fd *fd=generic_open(path.UTF8String,O_RDONLY_|O_NOFOLLOW_|O_NONBLOCK_,0);if(IS_ERR(fd)){if(error)*error=ISHError(@"文件无法打开");return nil;}NSMutableData *data=[NSMutableData new];ssize_t n=0;uint8_t buf[16384];if(!S_ISREG(fd->type)){if(error)*error=ISHError(@"只读取普通文件");fd_close(fd);return nil;}while((n=fd->ops->read(fd,buf,sizeof(buf)))>0){if(data.length+(NSUInteger)n>limit){if(error)*error=ISHError(@"读取内容超限");fd_close(fd);return nil;}[data appendBytes:buf length:n];}fd_close(fd);if(n<0){if(error)*error=ISHError(@"文件读取失败");return nil;}return data;
}
static NSDictionary *GuestAdvanced(NSString *operation,NSString *path,NSDictionary *args,NSError **error){
 if([@[@"search",@"tree"] containsObject:operation]){
  NSMutableArray *tree=[NSMutableArray new];uint64_t bytes=0;if(!GuestTree(path,tree,0,&bytes,error))return nil;NSMutableArray *items=[NSMutableArray new],*skipped=[NSMutableArray new];NSUInteger textBytes=0;NSString *query=args[@"query"];
  if([operation isEqual:@"search"]&&(![query isKindOfClass:NSString.class]||!query.length||query.length>200)){*error=ISHError(@"请输入 1–200 字符搜索词");return nil;}
  for(NSDictionary *row in tree){if([operation isEqual:@"search"]){if([row[@"path"] rangeOfString:query options:NSCaseInsensitiveSearch].location!=NSNotFound){if(items.count<200)[items addObject:row];else [skipped addObject:row[@"path"]];}continue;}
   if(![row[@"kind"] isEqual:@"file"])continue;NSData *data=[row[@"bytes"] unsignedLongLongValue]<=256*1024?GuestRead(row[@"path"],256*1024,nil):nil;NSString *content=data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;
   if(!content||items.count>=24||textBytes+data.length>1024*1024){[skipped addObject:row[@"path"]];continue;}textBytes+=data.length;[items addObject:@{@"path":row[@"path"],@"relative":[row[@"path"] isEqual:path]?[path lastPathComponent]:[row[@"path"] substringFromIndex:path.length+([path hasSuffix:@"/"]?0:1)],@"content":content,@"sha256":TFAIDigest(data),@"bytes":@(data.length)}];
  }return @{@"items":items,@"skipped":skipped,@"truncated":@(skipped.count>0),@"path":path,@"project_modified":@NO};
 }
 NSArray *sources=args[@"paths"];NSString *destination=args[@"destination"];BOOL move=[operation isEqual:@"move"]||[operation isEqual:@"rename"];
 if([operation isEqual:@"rename"])sources=@[path];
 if(![sources isKindOfClass:NSArray.class]||!sources.count||sources.count>50||!GuestPath(destination,[operation isEqual:@"rename"],error)){if(!*error)*error=ISHError(@"请选择 1–50 项及有效目标目录");return nil;}
 if(![destination hasPrefix:@"/workspace/"]&&![destination isEqual:@"/workspace"]){*error=ISHError(@"复制与移动目标仅限 /workspace");return nil;}
 NSMutableArray *plans=[NSMutableArray new];NSMutableSet *targets=[NSMutableSet new];uint64_t bytes=0;
 for(id source in sources){if(![source isKindOfClass:NSString.class]||!GuestPath(source,NO,error))return nil;NSString *src=[source stringByStandardizingPath];if(move&&![src hasPrefix:@"/workspace/"]){*error=ISHError(@"移动与改名仅限 /workspace 内的文件");return nil;}
  NSString *dest=[operation isEqual:@"rename"]?destination:[destination stringByAppendingPathComponent:src.lastPathComponent];dest=dest.stringByStandardizingPath;struct statbuf st={0};if([dest isEqual:src]||[dest hasPrefix:[src stringByAppendingString:@"/"]]||[targets containsObject:dest]||generic_statat(AT_PWD,dest.UTF8String,&st,false)!=_ENOENT){*error=ISHError(@"目标已存在、重复或处于源目录内部，未覆盖任何文件");return nil;}
  for(NSDictionary *plan in plans)if([src hasPrefix:[plan[@"source"] stringByAppendingString:@"/"]]||[plan[@"source"] hasPrefix:[src stringByAppendingString:@"/"]]){*error=ISHError(@"不能同时选择目录及其子项");return nil;}
  NSMutableArray *tree=[NSMutableArray new];if(!GuestTree(src,tree,0,&bytes,error))return nil;[targets addObject:dest];[plans addObject:@{@"source":src,@"target":dest,@"tree":tree}];
 }
 NSMutableArray *created=[NSMutableArray new],*moved=[NSMutableArray new];
 for(NSDictionary *plan in plans){NSString *src=plan[@"source"],*dest=plan[@"target"];if(move){if(generic_renameat(AT_PWD,src.UTF8String,AT_PWD,dest.UTF8String)<0){*error=ISHError(@"移动失败，正在回滚本次已移动项");break;}[moved addObject:plan];continue;}
  for(NSDictionary *row in plan[@"tree"]){NSString *p=[dest stringByAppendingString:[row[@"path"] substringFromIndex:src.length]];if([row[@"kind"] isEqual:@"directory"]){if(generic_mkdirat(AT_PWD,p.UTF8String,0700)<0){*error=ISHError(@"目录复制失败");break;}[created addObject:@{@"path":p,@"directory":@YES}];continue;}
   NSData *data=GuestRead(row[@"path"],64*1024*1024,error);if(!data)break;struct fd *out=generic_open(p.UTF8String,O_WRONLY_|O_CREAT_|O_EXCL_|O_NOFOLLOW_,0600);if(IS_ERR(out)){*error=ISHError(@"文件复制失败，不覆盖现有目标");break;}[created addObject:@{@"path":p,@"directory":@NO}];NSUInteger at=0;while(at<data.length){ssize_t n=out->ops->write(out,(const uint8_t *)data.bytes+at,data.length-at);if(n<=0){*error=ISHError(@"复制写入失败");break;}at+=n;}fd_close(out);if(*error)break;
  }if(*error)break;
 }
 if(*error){BOOL rollback=YES;for(NSDictionary *row in moved.reverseObjectEnumerator)rollback&=generic_renameat(AT_PWD,[row[@"target"] UTF8String],AT_PWD,[row[@"source"] UTF8String])==0;for(NSDictionary *row in created.reverseObjectEnumerator)rollback&=([row[@"directory"] boolValue]?generic_rmdirat(AT_PWD,[row[@"path"] UTF8String]):generic_unlinkat(AT_PWD,[row[@"path"] UTF8String]))==0;if(!rollback)*error=ISHError(@"操作失败且部分回滚失败，请重新检查源与目标目录；没有覆盖现有文件");return nil;}
 return @{@"operation":operation,@"count":@(plans.count),@"bytes":@(bytes),@"destination":destination,@"project_modified":@NO};
}
#endif

@interface DylixISHJob : NSObject
@property NSString *session,*key,*command,*processID;
@property BOOL managed,raw;
@property int rawIn,rawOut,rawErr;
@property NSString *executable;
@property NSArray *arguments;
@property NSDictionary *environment;
@property NSMutableData *rawBuffer,*rawErrors,*rawPending;
@property uint64_t totalBytes;
@property int exitStatus;
@property NSTimeInterval finishedAt;
@property NSMutableDictionary<NSNumber *,NSNumber *> *listeners;
@property NSMutableData *tail,*pendingOutput;
@property NSString *spoolPath;
@property uint64_t spooledBytes;
@property NSTimeInterval start;
@property int pid,ttyNumber;
@property void *nativeTTY;
@property uint64_t context;
@property BOOL terminal,done,cancelled,timedOut,truncated,flushScheduled;
@property(copy) void (^output)(NSData *);
@property(copy) void (^completion)(NSDictionary *,NSError *);
@end
@implementation DylixISHJob
- (instancetype)init{if((self=[super init])){_rawIn=_rawOut=_rawErr=-1;_ttyNumber=-1;}return self;}
@end

@interface TFAIISHRuntime ()
@property dispatch_queue_t queue;
@property NSMutableDictionary<NSString *,NSString *> *mounts;
@property NSMutableDictionary<NSNumber *,DylixISHJob *> *jobs;
@property NSMutableDictionary<NSString *,DylixISHJob *> *terminals;
@property NSMutableDictionary<NSString *,NSMutableData *> *replays;
@property NSMutableDictionary<NSString *,NSString *> *states;
@property NSMutableDictionary<NSString *,DylixISHJob *> *processJobs;
@property NSMutableDictionary<NSString *,DylixISHJob *> *stdioJobs;
@property NSMutableSet<NSString *> *autoDeveloperSessions;
@property NSMutableSet<NSString *> *autoReverseSessions;
@property BOOL booted,bootFailed;
@property NSString *failure;
- (void)receive:(NSData *)data tty:(int)number;
- (void)exited:(int)pid status:(int)status;
- (void)listener:(uint64_t)context fd:(int)fd port:(unsigned)port active:(BOOL)active;
@end

#if DYLIX_HAS_ISH
static struct task *DylixInit;
// Raw guest pipes: no shell interpolation, PTY echo, or stderr/protocol mixing.
static ssize_t RawRead(struct fd *fd,void *buf,size_t size){for(;;){ssize_t n=read(fd->real_fd,buf,size);if(n>=0)return n;if(errno!=EINTR)return errno_map();lock(&current->sighand->lock);BOOL pending=!!(current->pending&~current->blocked);unlock(&current->sighand->lock);if(pending)return _EINTR;}}
static ssize_t RawWrite(struct fd *fd,const void *buf,size_t size){for(;;){ssize_t n=write(fd->real_fd,buf,size);if(n>=0)return n;if(errno!=EINTR)return errno_map();lock(&current->sighand->lock);BOOL pending=!!(current->pending&~current->blocked);unlock(&current->sighand->lock);if(pending)return _EINTR;}}
static int RawClose(struct fd *fd){return close(fd->real_fd)==0?0:errno_map();}
static const struct fd_ops RawOps={.read=RawRead,.write=RawWrite,.close=RawClose,.poll=realfs_poll,.getflags=realfs_getflags,.setflags=realfs_setflags};

extern void (*dylix_listener_hook)(uint64_t,int,unsigned,bool);
static void ListenerChanged(uint64_t context,int fd,unsigned port,bool active){[[TFAIISHRuntime shared] listener:context fd:fd port:port active:active];}
static int ConsoleWrite(struct tty *tty,const void *buf,size_t len,bool blocking){return (int)len;}
static int TTYInit(struct tty *tty){return 0;}
static void TTYCleanup(struct tty *tty){}
static int PTYWrite(struct tty *tty,const void *buf,size_t len,bool blocking){
    if(len){@autoreleasepool{[[TFAIISHRuntime shared] receive:[NSData dataWithBytes:buf length:len] tty:tty->num];}}
    return (int)len;
}
static struct tty_driver_ops ConsoleOps={.init=TTYInit,.write=ConsoleWrite,.cleanup=TTYCleanup};
DEFINE_TTY_DRIVER(DylixConsole,&ConsoleOps,TTY_CONSOLE_MAJOR,8);
static struct tty_driver_ops PTYOps={.init=TTYInit,.write=PTYWrite,.cleanup=TTYCleanup};
static struct tty_driver DylixPTY={.ops=&PTYOps};
static void GuestExit(struct task *task,int status){[[TFAIISHRuntime shared] exited:task->pid status:status];}
extern void (*exit_hook)(struct task *,int);
static _Atomic bool MemoryCritical;
static void MemoryStatus(void){
    task_vm_info_data_t info;mach_msg_type_number_t count=TASK_VM_INFO_COUNT;
    if(task_info(mach_task_self(),TASK_VM_INFO,(task_info_t)&info,&count)!=KERN_SUCCESS)return;
#if TARGET_OS_SIMULATOR
    uint64_t limit=NSProcessInfo.processInfo.physicalMemory/2;
    uint64_t avail=limit>info.phys_footprint?limit-info.phys_footprint:0;
#else
    uint64_t avail=os_proc_available_memory(),limit=info.phys_footprint+avail;
#endif
    ish_set_memory_status(limit,avail,atomic_load(&MemoryCritical));
}
static void StartMemoryMonitor(void){
    static dispatch_once_t once;dispatch_once(&once,^{
        dispatch_queue_t q=dispatch_queue_create("dylix.ish.memory",DISPATCH_QUEUE_SERIAL);
        static dispatch_source_t timer,pressure;
        timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,q);
        dispatch_source_set_timer(timer,DISPATCH_TIME_NOW,250*NSEC_PER_MSEC,50*NSEC_PER_MSEC);
        dispatch_source_set_event_handler(timer,^{MemoryStatus();});dispatch_resume(timer);
        pressure=dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE,0,DISPATCH_MEMORYPRESSURE_NORMAL|DISPATCH_MEMORYPRESSURE_WARN|DISPATCH_MEMORYPRESSURE_CRITICAL,q);
        dispatch_source_set_event_handler(pressure,^{atomic_store(&MemoryCritical,(dispatch_source_get_data(pressure)&DISPATCH_MEMORYPRESSURE_CRITICAL)!=0);MemoryStatus();});dispatch_resume(pressure);
        ish_set_memory_refresh_hook(MemoryStatus);MemoryStatus();
    });
}
// Follow the device DNS instead of hard-coded public servers (which fail on
// captive/VPN/local networks). Public resolver APIs, independently adapted;
// upstream iSH also mirrors resolv.conf, see its GPL AppDelegate.m.
static NSData *DeviceDNS(void){
 struct __res_state resolver={0};NSMutableArray *ipv4=[NSMutableArray new],*ipv6=[NSMutableArray new];
 if(res_ninit(&resolver)==0){union res_sockaddr_union servers[8];int count=res_getservers(&resolver,servers,8);for(int i=0;i<count&&i<8;i++){struct sockaddr *address=(void *)&servers[i];char host[NI_MAXHOST]={0};if(address->sa_len&&getnameinfo(address,address->sa_len,host,sizeof(host),NULL,0,NI_NUMERICHOST)==0){NSString *line=[NSString stringWithFormat:@"nameserver %s",host];if(address->sa_family==AF_INET)[ipv4 addObject:line];else if(address->sa_family==AF_INET6)[ipv6 addObject:line];}}res_ndestroy(&resolver);}
 NSMutableArray *lines=[NSMutableArray arrayWithObject:@"options timeout:3 attempts:2"];[lines addObjectsFromArray:ipv4];[lines addObjectsFromArray:ipv6];if(lines.count==1)[lines addObject:@"nameserver 1.1.1.1"];
 return [[[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
}
static BOOL InstallRoot(NSString *path,NSError **error){
    NSFileManager *fm=NSFileManager.defaultManager;
    if([fm fileExistsAtPath:[path stringByAppendingPathComponent:@".dylix-rootfs-v1"]])return YES;
    if([fm fileExistsAtPath:path]){if(error)*error=ISHError(@"沙盒初始化未完成，已保留原目录；请在终端页面重试或检查存储空间。");return NO;}
    NSString *temporary=[path stringByAppendingFormat:@".partial-%@",NSUUID.UUID.UUIDString];
    struct fakefsify_error detail={0};
    BOOL ok=fakefs_import(ArchivePath().fileSystemRepresentation,temporary.fileSystemRepresentation,&detail,(struct progress){0});
    if(!ok){if(error)*error=ISHError([NSString stringWithFormat:@"Alpine 文件系统初始化失败：%s",detail.message?:"unknown"]);free(detail.message);[fm removeItemAtPath:temporary error:nil];return NO;}
    [fm setAttributes:@{NSFilePosixPermissions:@0700} ofItemAtPath:temporary error:nil];
    if(![RootfsSHA writeToFile:[temporary stringByAppendingPathComponent:@".dylix-rootfs-v1"] atomically:YES encoding:NSUTF8StringEncoding error:error]){[fm removeItemAtPath:temporary error:nil];return NO;}
    if(![fm moveItemAtPath:temporary toPath:path error:error]){[fm removeItemAtPath:temporary error:nil];return NO;}
    return YES;
}
static void Devices(void){
    generic_mkdirat(AT_PWD,"/dev",0755);generic_mkdirat(AT_PWD,"/dev/pts",0755);
    generic_mknodat(AT_PWD,"/dev/console",S_IFCHR|0666,dev_make(TTY_CONSOLE_MAJOR,1));
    generic_mknodat(AT_PWD,"/dev/tty",S_IFCHR|0666,dev_make(TTY_ALTERNATE_MAJOR,DEV_TTY_MINOR));
    generic_mknodat(AT_PWD,"/dev/ptmx",S_IFCHR|0666,dev_make(TTY_ALTERNATE_MAJOR,DEV_PTMX_MINOR));
    const char *names[]={"/dev/null","/dev/zero","/dev/full","/dev/random","/dev/urandom"};
    int minors[]={DEV_NULL_MINOR,DEV_ZERO_MINOR,DEV_FULL_MINOR,DEV_RANDOM_MINOR,DEV_URANDOM_MINOR};
    for(int i=0;i<5;i++)generic_mknodat(AT_PWD,names[i],S_IFCHR|0666,dev_make(MEM_MAJOR,minors[i]));
}
static int SetRoot(NSString *mount){
    struct fd *root=generic_open(mount.fileSystemRepresentation,O_RDONLY_,0);
    if(IS_ERR(root))return (int)PTR_ERR(root);
    fd_close(current->fs->root);current->fs->root=root;
    fs_chdir(current->fs,fd_retain(root));
    return 0;
}
static NSData *ArgBuffer(NSArray<NSString *> *args){NSMutableData *d=[NSMutableData new];for(NSString *arg in args){[d appendData:[arg dataUsingEncoding:NSUTF8StringEncoding]];char zero=0;[d appendBytes:&zero length:1];}char zero=0;[d appendBytes:&zero length:1];return d;}
// Only for tasks whose host thread has never started. task_destroy alone does
// not release the filesystem, fd table, address space or process group.
static void DiscardUnstartedTask(struct task *task){
    if(task->files)fdtable_release(task->files);
    if(task->fs)fs_info_release(task->fs);
    if(task->mm)mm_release(task->mm);
    if(task->sighand)sighand_release(task->sighand);
    lock(&pids_lock);task_leave_session(task);list_remove(&task->group->pgroup);
    cond_destroy(&task->group->child_exit);cond_destroy(&task->group->stopped_cond);
    free(task->group);atomic_fetch_sub(&ish_live_guest_procs,1);task_destroy(task);unlock(&pids_lock);
}
#endif

@implementation TFAIISHRuntime
+ (instancetype)shared{static TFAIISHRuntime *r;static dispatch_once_t once;dispatch_once(&once,^{r=[self new];r.queue=dispatch_queue_create("dylix.ish.runtime",DISPATCH_QUEUE_SERIAL);r.mounts=[NSMutableDictionary new];r.jobs=[NSMutableDictionary new];r.terminals=[NSMutableDictionary new];r.replays=[NSMutableDictionary new];r.states=[NSMutableDictionary new];r.processJobs=[NSMutableDictionary new];r.stdioJobs=[NSMutableDictionary new];r.autoDeveloperSessions=[NSMutableSet new];r.autoReverseSessions=[NSMutableSet new];});return r;}
+ (BOOL)available{
#if DYLIX_HAS_ISH
    static BOOL valid;static dispatch_once_t once;dispatch_once(&once,^{NSData *archive=[NSData dataWithContentsOfFile:ArchivePath()?:@""];valid=[TFAIDigest(archive) isEqual:RootfsSHA];});return valid;
#else
    return NO;
#endif
}
- (void)setState:(NSString *)state session:(NSString *)session{self.states[SessionKey(session)]=state;Main(^{[NSNotificationCenter.defaultCenter postNotificationName:TFAIISHStatusChanged object:session userInfo:@{@"state":state}];});}
- (BOOL)prepare:(NSString *)session error:(NSError **)error{
    if(!session.length||session.length>512||![self.class available]){if(error)*error=ISHError(@"此构建未包含可用的 iSH 运行库或 Alpine 校验失败。");return NO;}
#if DYLIX_HAS_ISH
    if(self.bootFailed){if(error)*error=ISHError(self.failure?:@"内核启动失败，请重新打开 App。");return NO;}
    NSString *base=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"Dylix/iSH-v1"];
    if(![NSFileManager.defaultManager createDirectoryAtPath:base withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error])return NO;
    struct task *saved=current;
    if(!self.booted){
        [self setState:@"正在初始化 Linux" session:session];
        NSString *bootstrap=[base stringByAppendingPathComponent:@"kernel"];
        if(!InstallRoot(bootstrap,error))return NO;
        int e=mount_root(&fakefs,[[bootstrap stringByAppendingPathComponent:@"data"] fileSystemRepresentation]);
        if(!e)e=become_first_process();
        if(e<0){self.bootFailed=YES;self.failure=[NSString stringWithFormat:@"iSH 内核启动失败 (%d)，请重启 App 后重试。",e];if(error)*error=ISHError(self.failure);current=saved;return NO;}
        DylixInit=current;DylixInit->thread=pthread_self();
        tty_drivers[TTY_CONSOLE_MAJOR]=&DylixConsole;set_console_device(TTY_CONSOLE_MAJOR,1);
        Devices();create_stdio("/dev/console",TTY_CONSOLE_MAJOR,1);
        generic_mkdirat(AT_PWD,"/sessions",0700);
        exit_hook=GuestExit;dylix_listener_hook=ListenerChanged;StartMemoryMonitor();self.booted=YES;
    }
    current=DylixInit;
    NSString *key=SessionKey(session);
    if(!self.mounts[key]){
        NSString *root=[base stringByAppendingPathComponent:key];
        [self setState:@"正在准备会话文件系统" session:session];
        if(!InstallRoot(root,error)){current=saved;return NO;}
        NSString *mount=[@"/sessions/" stringByAppendingString:key];
        generic_mkdirat(AT_PWD,mount.UTF8String,0700);
        int e=do_mount(&fakefs,[[root stringByAppendingPathComponent:@"data"] fileSystemRepresentation],mount.UTF8String,"",0);
        if(e<0){current=saved;if(error)*error=ISHError([NSString stringWithFormat:@"挂载会话文件系统失败 (%d)",e]);return NO;}
        self.mounts[key]=mount;
        // Operate from init using a temporary filesystem view. Guest sys_mount/chroot stay disabled.
        struct fs_info *initFS=DylixInit->fs;DylixInit->fs=fs_info_copy(initFS);
        e=SetRoot(mount);
        if(!e){Devices();generic_mkdirat(AT_PWD,"/workspace",0755);generic_mkdirat(AT_PWD,"/workspace/imports",0755);generic_mkdirat(AT_PWD,"/tmp",01777);generic_mkdirat(AT_PWD,"/dev/pts",0755);
            NSString *pts=[mount stringByAppendingString:@"/dev/pts"];do_mount(&devptsfs,"devpts",pts.UTF8String,"",0);
        }
        fs_info_release(DylixInit->fs);DylixInit->fs=initFS;
        if(e<0){current=saved;if(error)*error=ISHError(@"设置会话根目录失败");return NO;}
    }
    {struct fs_info *initial=DylixInit->fs;DylixInit->fs=fs_info_copy(initial);if(SetRoot(self.mounts[key])==0){NSData *dns=DeviceDNS();struct fd *fd=generic_open("/etc/resolv.conf",O_WRONLY_|O_CREAT_|O_TRUNC_,0644);if(!IS_ERR(fd)){fd->ops->write(fd,dns.bytes,dns.length);fd_close(fd);}}fs_info_release(DylixInit->fs);DylixInit->fs=initial;}
    current=saved;[self setState:@"就绪" session:session];return YES;
#else
    return NO;
#endif
}
- (void)prepareSession:(NSString *)session completion:(void (^)(NSError *))completion{dispatch_async(self.queue,^{NSError *e=nil;[self prepare:session error:&e];Main(^{completion(e);});});}
- (void)autoInstallForSession:(NSString *)session{
 NSString *key=SessionKey(session);BOOL developer=[NSUserDefaults.standardUserDefaults boolForKey:@"DylixISHDeveloperToolsAutoload"],reverse=[NSUserDefaults.standardUserDefaults boolForKey:@"DylixISHReverseToolsAutoload"];
 if(developer&&![self.autoDeveloperSessions containsObject:key]){[self.autoDeveloperSessions addObject:key];[self installDeveloperTools:session completion:^(NSDictionary *result,NSError *error){if(error||![result[@"process_id"] length])dispatch_async(self.queue,^{[self.autoDeveloperSessions removeObject:key];});}];}
 if(reverse&&![self.autoReverseSessions containsObject:key]){[self.autoReverseSessions addObject:key];[self installReverseTools:session completion:^(NSDictionary *result,NSError *error){if(error||![result[@"process_id"] length])dispatch_async(self.queue,^{[self.autoReverseSessions removeObject:key];});}];}
}
- (void)watchToolInstall:(NSString *)processID session:(NSString *)session defaultsKey:(NSString *)defaultsKey marker:(NSString *)marker deadline:(NSTimeInterval)deadline{
 dispatch_async(self.queue,^{
  DylixISHJob *job=self.processJobs[processID];
  if(job)[self watchToolJob:job defaultsKey:defaultsKey marker:marker deadline:deadline];
 });
}
- (void)watchToolJob:(DylixISHJob *)job defaultsKey:(NSString *)defaultsKey marker:(NSString *)marker deadline:(NSTimeInterval)deadline{
 // Retain the job while observing it: the public handle cache may evict it.
 if(!job.done&&NSProcessInfo.processInfo.systemUptime<deadline){
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,0.25*NSEC_PER_SEC),self.queue,^{[self watchToolJob:job defaultsKey:defaultsKey marker:marker deadline:deadline];});return;
 }
 if(!job.done){job.timedOut=YES;[self complete:job status:9 error:nil];}
 NSString *output=[[NSString alloc]initWithData:job.tail encoding:NSUTF8StringEncoding];
 BOOL success=job.exitStatus==0&&!job.cancelled&&!job.timedOut&&[output containsString:marker];
 NSMutableSet *installed=[defaultsKey isEqual:@"DylixISHDeveloperToolsAutoload"]?self.autoDeveloperSessions:self.autoReverseSessions;
 if(success){[installed addObject:job.key];[NSUserDefaults.standardUserDefaults setBool:YES forKey:defaultsKey];}
 else [installed removeObject:job.key]; // A failure in one session must not revoke another session's preference.
}
- (void)prepareSpool:(DylixISHJob *)job{
 if(!job.managed||job.spoolPath.length)return;
 NSString *base=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"Dylix/TerminalOutput"];
 NSString *dir=[base stringByAppendingPathComponent:SessionKey(job.session)];
 if(![NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil])return;
 NSString *path=[dir stringByAppendingPathComponent:[job.processID stringByAppendingPathExtension:@"log"]];
 if([NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:@{NSFilePosixPermissions:@0600}])job.spoolPath=path;
}
- (void)spool:(NSData *)data job:(DylixISHJob *)job{
 if(!data.length||!job.managed)return;[self prepareSpool:job];if(!job.spoolPath.length||job.spooledBytes>=64*1024*1024)return;
 NSUInteger length=MIN(data.length,(NSUInteger)(64*1024*1024-job.spooledBytes));NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:job.spoolPath];if(!handle)return;[handle seekToEndOfFile];[handle writeData:[data subdataWithRange:NSMakeRange(0,length)]];[handle closeFile];job.spooledBytes+=length;
}
- (void)flushOutput:(DylixISHJob *)job{
    if(!job.pendingOutput.length)return;NSData *data=[job.pendingOutput copy];[job.pendingOutput setLength:0];
    if(job.terminal){NSString *sid=job.session;Main(^{[NSNotificationCenter.defaultCenter postNotificationName:TFAIISHTerminalOutput object:sid userInfo:@{@"data":data}];});}
    if(job.output){void (^cb)(NSData *)=job.output;Main(^{cb(data);});}
}
- (void)receive:(NSData *)data tty:(int)number{
    // Backpressure prevents a fast producer (e.g. yes) from filling the GCD queue.
    dispatch_sync(self.queue,^{
        DylixISHJob *job=nil;for(DylixISHJob *j in self.jobs.allValues)if(j.ttyNumber==number){job=j;break;}if(!job||job.done)return;
        // Persistent processes page through a larger ring/spool. One-shot
        // execute results must remain bounded before returning to model context.
        NSUInteger limit=job.terminal?256*1024:job.managed?ProcessRingLimit():64*1024;
        [self spool:data job:job];job.totalBytes+=data.length;[job.tail appendData:data];if(job.tail.length>limit){[job.tail replaceBytesInRange:NSMakeRange(0,job.tail.length-limit) withBytes:NULL length:0];job.truncated=YES;}
        if(job.terminal)self.replays[job.key]=job.tail;
        if(job.terminal||job.output){
            if(!job.pendingOutput)job.pendingOutput=[NSMutableData new];[job.pendingOutput appendData:data];
            NSUInteger pendingLimit=job.managed?MIN(256*1024,ProcessRingLimit()):64*1024;
            if(job.pendingOutput.length>pendingLimit){[job.pendingOutput replaceBytesInRange:NSMakeRange(0,job.pendingOutput.length-pendingLimit) withBytes:NULL length:0];job.truncated=YES;}
            if(!job.flushScheduled){job.flushScheduled=YES;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),self.queue,^{job.flushScheduled=NO;[self flushOutput:job];});}
        }
    });
}
- (void)complete:(DylixISHJob *)job status:(int)status error:(NSError *)error{
    if(job.done)return;job.environment=nil;if(job.raw){[self drainStdio:job];if(job.rawIn>=0){close(job.rawIn);job.rawIn=-1;}}[self flushOutput:job];job.done=YES;[self kill:job];job.exitStatus=(status&127)?128+(status&127):(status>>8)&255;job.finishedAt=NSProcessInfo.processInfo.systemUptime;[job.listeners removeAllObjects];[self.jobs removeObjectForKey:@(job.pid)];
#if DYLIX_HAS_ISH
    if(job.nativeTTY){lock(&ttys_lock);tty_release(job.nativeTTY);unlock(&ttys_lock);job.nativeTTY=NULL;}
#endif

    if(job.terminal&&self.terminals[job.key]==job){[self.terminals removeObjectForKey:job.key];[self setState:@"终端已退出，可重新打开" session:job.session];}
    NSString *text=[[NSString alloc]initWithData:job.tail encoding:NSUTF8StringEncoding];
    if(!text&&job.truncated)for(NSUInteger skip=1;skip<=3&&skip<job.tail.length;skip++){text=[[NSString alloc]initWithData:[job.tail subdataWithRange:NSMakeRange(skip,job.tail.length-skip)] encoding:NSUTF8StringEncoding];if(text)break;}
    if(!text){text=[[NSString alloc]initWithData:job.tail encoding:NSISOLatin1StringEncoding]?:@"";}
    NSDictionary *result=@{@"exit_code":@((status&127)?128+(status&127):(status>>8)&255),@"output":text,@"truncated":@(job.truncated),@"cancelled":@(job.cancelled),@"timed_out":@(job.timedOut),@"duration":@(NSProcessInfo.processInfo.systemUptime-job.start),@"environment":@"isolated_alpine_linux",@"project_modified":@NO};
    if(job.managed){[self saveProcessHistory:job.session];[self pruneProcessJobsOnQueue:job.session];}
    if(!job.terminal)[self setState:job.cancelled?@"命令已取消":job.timedOut?@"命令超时":@"命令已结束" session:job.session];
    void (^cb)(NSDictionary *,NSError *)=job.completion;job.completion=nil;job.output=nil;if(cb)Main(^{cb(result,error);});
}
- (void)exited:(int)pid status:(int)status{dispatch_async(self.queue,^{DylixISHJob *job=self.jobs[@(pid)];if(job)[self complete:job status:status error:nil];
#if DYLIX_HAS_ISH
    struct task *saved=current;current=DylixInit;sys_wait4(pid,0,1,0);current=saved;
#endif
});}
- (void)startJob:(DylixISHJob *)job columns:(int)cols rows:(int)rows error:(NSError **)error{
#if DYLIX_HAS_ISH
    struct task *saved=current;current=DylixInit;MemoryStatus();int e=become_new_init_child();
    if(e<0){current=saved;if(error)*error=ISHError(@"无法创建 Linux 进程");return;}
    struct task *task=current;job.pid=task->pid;job.context=((uint64_t)arc4random()<<32)|arc4random();if(!job.context)job.context=1;task->group->fs_context=job.context;
    e=SetRoot(self.mounts[job.key]);
    struct tty *tty=NULL;
    if(!e&&!job.raw){tty=pty_open_fake(&DylixPTY);if(IS_ERR(tty)){e=(int)PTR_ERR(tty);tty=NULL;}}
    if(!e&&!job.raw){job.nativeTTY=tty;job.ttyNumber=tty->num;tty_set_winsize(tty,(struct winsize_){.row=MAX(1,MIN(rows,300)),.col=MAX(20,MIN(cols,500))});NSString *file=[NSString stringWithFormat:@"/dev/pts/%d",tty->num];e=create_stdio(file.UTF8String,TTY_PSEUDO_SLAVE_MAJOR,tty->num);}
    if(!e&&job.raw){for(int i=0;i<3;i++)sys_close(i);for(int i=0;i<3&&!e;i++){int pair[2];if(socketpair(AF_UNIX,SOCK_STREAM,0,pair)<0){e=-5;break;}int host=pair[0],guest=pair[1],one=1;setsockopt(host,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));setsockopt(guest,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));fcntl(host,F_SETFL,O_NONBLOCK);if(i==0)job.rawIn=host;else if(i==1)job.rawOut=host;else job.rawErr=host;struct fd *fd=adhoc_fd_create(&RawOps);if(!fd){close(guest);e=-12;break;}fd->real_fd=guest;fd->type=S_IFIFO;fd->stat.mode=S_IFIFO|0600;fd->stat.blksize=4096;fd->flags=i==0?O_RDONLY_:O_WRONLY_;int index=f_install(fd,0);if(index!=i){e=-5;break;}}}
    if(!e){struct fd *pwd=generic_open("/workspace",O_RDONLY_,0);if(!IS_ERR(pwd))fs_chdir(task->fs,pwd);
        NSMutableArray *variables=[@[@"HOME=/root",@"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",@"TERM=xterm-256color",@"LANG=C.UTF-8",@"PS1=\\w $ "] mutableCopy];for(NSString *key in job.environment)[variables addObject:[key stringByAppendingFormat:@"=%@",job.environment[key]]];NSData *env=ArgBuffer(variables);
        NSArray *argv=job.raw?[@[job.executable] arrayByAddingObjectsFromArray:job.arguments]:job.terminal?@[@"/bin/sh",@"-i"]:@[@"/bin/sh",@"-c",job.command];NSData *arguments=ArgBuffer(argv);
        e=do_execve(job.raw?job.executable.UTF8String:"/bin/sh",(int)argv.count,arguments.bytes,env.bytes);
    }
    if(e<0){if(job.raw){for(int fdIndex=0;fdIndex<3;fdIndex++){int rawFD=fdIndex==0?job.rawIn:fdIndex==1?job.rawOut:job.rawErr;if(rawFD>=0)close(rawFD);}job.rawIn=job.rawOut=job.rawErr=-1;}if(job.nativeTTY){lock(&ttys_lock);tty_release(job.nativeTTY);unlock(&ttys_lock);job.nativeTTY=NULL;}DiscardUnstartedTask(task);current=saved;if(error)*error=ISHError([NSString stringWithFormat:@"Linux shell 启动失败 (%d)",e]);return;}
    job.start=NSProcessInfo.processInfo.systemUptime;job.listeners=[NSMutableDictionary new];self.jobs[@(job.pid)]=job;
    if(job.terminal)self.terminals[job.key]=job;
    if(job.managed)self.processJobs[job.processID]=job;
    e=task_start(task);if(e<0){[self.jobs removeObjectForKey:@(job.pid)];if(job.managed)[self.processJobs removeObjectForKey:job.processID];if(job.terminal)[self.terminals removeObjectForKey:job.key];if(job.nativeTTY){lock(&ttys_lock);tty_release(job.nativeTTY);unlock(&ttys_lock);job.nativeTTY=NULL;}DiscardUnstartedTask(task);if(job.raw){if(job.rawIn>=0)close(job.rawIn);if(job.rawOut>=0)close(job.rawOut);if(job.rawErr>=0)close(job.rawErr);job.rawIn=job.rawOut=job.rawErr=-1;}if(error)*error=ISHError(@"无法启动 Linux 执行线程");}current=saved;
#endif
}
- (void)execute:(NSString *)command session:(NSString *)session timeout:(NSTimeInterval)timeout output:(void (^)(NSData *))output completion:(void (^)(NSDictionary *,NSError *))completion{
    dispatch_async(self.queue,^{NSError *e=nil;
        if(![command isKindOfClass:NSString.class]||!command.length||[command lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>64*1024||[command rangeOfString:[NSString stringWithFormat:@"%C",(unichar)0]].location!=NSNotFound){Main(^{completion(nil,ISHError(@"命令为空、包含空字符或超过 64 KiB"));});return;}
        if(![self prepare:session error:&e]){Main(^{completion(nil,e);});return;}
        NSUInteger active=0;for(DylixISHJob *j in self.jobs.allValues)if(!j.terminal)active++;if(active>=ProcessConcurrencyLimit()){Main(^{completion(nil,ISHError([NSString stringWithFormat:@"已有 %lu 个 Linux 任务运行，请等待或取消后再试。",(unsigned long)ProcessConcurrencyLimit()]));});return;}
        DylixISHJob *job=[DylixISHJob new];job.session=session;job.key=SessionKey(session);job.tail=[NSMutableData new];job.command=command;job.output=output;job.completion=completion;
        [self startJob:job columns:100 rows:30 error:&e];if(e){Main(^{completion(nil,e);});return;}
        [self setState:@"正在执行命令" session:session];
        NSTimeInterval seconds=isfinite(timeout)?MAX(1,MIN(timeout,600)):120;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(seconds*NSEC_PER_SEC)),self.queue,^{if(job.done)return;job.timedOut=YES;[self kill:job];[self complete:job status:9 error:nil];});
    });
}
- (void)openTerminal:(NSString *)session columns:(int)columns rows:(int)rows completion:(void (^)(NSError *))completion{dispatch_async(self.queue,^{NSError *e=nil;if(![self prepare:session error:&e]){Main(^{completion(e);});return;}[self autoInstallForSession:session];NSString *key=SessionKey(session);if(!self.terminals[key]){DylixISHJob *j=[DylixISHJob new];j.session=session;j.key=key;j.tail=self.replays[key]?:[NSMutableData new];j.totalBytes=j.tail.length;j.terminal=YES;j.managed=YES;j.processID=NSUUID.UUID.UUIDString;[self startJob:j columns:columns rows:rows error:&e];if(!e)[self saveProcessHistory:session];}Main(^{completion(e);});});}
- (void)kill:(DylixISHJob *)job{
#if DYLIX_HAS_ISH
    uint64_t context=job.context;if(!context)return;
    // Never wait for a guest PID lock on the main/UI or runtime queue.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{lock(&pids_lock);for(int pid=2;pid<MAX_PID;pid++){struct task *t=pid_get_task(pid);if(t&&t->group&&t->group->fs_context==context)send_signal(t,SIGKILL_,SIGINFO_NIL);}unlock(&pids_lock);});
#endif
}
- (void)cancelCommands:(NSString *)session{dispatch_async(self.queue,^{for(DylixISHJob *j in self.jobs.allValues.copy)if(!j.terminal&&[j.session isEqual:session]){j.cancelled=YES;[self kill:j];[self complete:j status:9 error:nil];}});}
- (void)closeTerminal:(NSString *)session{dispatch_async(self.queue,^{DylixISHJob *j=self.terminals[SessionKey(session)];if(j){[self kill:j];[self complete:j status:9 error:nil];}});}
- (void)writeTerminal:(NSString *)session data:(NSData *)data{
#if DYLIX_HAS_ISH
    if(!data.length||data.length>64*1024)return;
    dispatch_async(self.queue,^{DylixISHJob *j=self.terminals[SessionKey(session)];if(!j)return;lock(&ttys_lock);struct tty *tty=DylixPTY.ttys?DylixPTY.ttys[j.ttyNumber]:NULL;if(tty)tty->refcount++;unlock(&ttys_lock);if(tty){dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{tty_input(tty,data.bytes,data.length,false);lock(&ttys_lock);tty_release(tty);unlock(&ttys_lock);});}});
#endif
}
- (void)resizeTerminal:(NSString *)session columns:(int)columns rows:(int)rows{
#if DYLIX_HAS_ISH
    dispatch_async(self.queue,^{DylixISHJob *j=self.terminals[SessionKey(session)];if(!j)return;lock(&ttys_lock);struct tty *tty=DylixPTY.ttys?DylixPTY.ttys[j.ttyNumber]:NULL;if(tty)tty->refcount++;unlock(&ttys_lock);if(tty){tty_set_winsize(tty,(struct winsize_){.row=MAX(1,MIN(rows,300)),.col=MAX(20,MIN(columns,500))});lock(&ttys_lock);tty_release(tty);unlock(&ttys_lock);}});
#endif
}
- (NSData *)terminalReplay:(NSString *)session{__block NSData *d;dispatch_sync(self.queue,^{d=[self.replays[SessionKey(session)] copy]?:NSData.data;});return d;}
- (NSDictionary *)status:(NSString *)session{__block NSDictionary *r;dispatch_sync(self.queue,^{NSString *key=SessionKey(session);r=@{@"available":@([self.class available]),@"booted":@(self.booted),@"sessionReady":@(self.mounts[key]!=nil),@"terminalRunning":@(self.terminals[key]!=nil),@"state":self.states[key]?:@"尚未启动",@"hostShellFallback":@NO,@"liveProjectMount":@NO};});return r;}
- (void)importFile:(NSURL *)file name:(NSString *)name session:(NSString *)session completion:(void (^)(NSDictionary *,NSError *))completion{
    dispatch_async(self.queue,^{NSError *e=nil;
        NSString *safe=name.lastPathComponent;if(!safe.length||[safe isEqual:@"."]||[safe isEqual:@".."]||[safe containsString:@"/"]||[safe containsString:@"\\"]){Main(^{completion(nil,ISHError(@"文件名无效"));});return;}
        if(!file.isFileURL){Main(^{completion(nil,ISHError(@"只能导入本机文件副本"));});return;}
        int source=open(file.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_CLOEXEC);
        struct stat attr;
        if(source<0){Main(^{completion(nil,ISHError(@"无法打开文件，符号链接不允许导入"));});return;}
        if(fstat(source,&attr)||!S_ISREG(attr.st_mode)||attr.st_size>1024LL*1024*1024){close(source);Main(^{completion(nil,ISHError(@"只允许导入普通文件，单文件不超过 1 GiB"));});return;}
        if(![self prepare:session error:&e]){close(source);Main(^{completion(nil,e);});return;}
#if DYLIX_HAS_ISH
        struct task *saved=current;current=DylixInit;struct fs_info *initFS=DylixInit->fs;DylixInit->fs=fs_info_copy(initFS);
        int rootError=SetRoot(self.mounts[SessionKey(session)]);
        NSString *path=[@"/workspace/imports/" stringByAppendingString:[NSUUID.UUID.UUIDString stringByAppendingFormat:@"-%@",safe]];
        struct fd *fd=rootError<0?ERR_PTR(rootError):generic_open(path.UTF8String,O_WRONLY_|O_CREAT_|O_EXCL_,0600);
        uint64_t total=0;
        if(IS_ERR(fd))e=ISHError(@"无法创建沙盒文件");else{
            uint8_t buffer[65536];ssize_t n;
            while((n=read(source,buffer,sizeof(buffer)))!=0){
                if(n<0){if(errno==EINTR)continue;e=ISHError(@"读取导入文件失败");break;}
                total+=n;if(total>1024ULL*1024*1024){e=ISHError(@"文件在复制期间增大，超过 1 GiB");break;}
                ssize_t at=0;while(at<n){ssize_t written=fd->ops->write(fd,buffer+at,n-at);if(written<=0){e=ISHError(@"写入沙盒失败，可能存储空间不足");break;}at+=written;}if(e)break;
            }
            fd_close(fd);if(e)generic_unlinkat(AT_PWD,path.UTF8String);
        }
        close(source);fs_info_release(DylixInit->fs);DylixInit->fs=initFS;current=saved;
        Main(^{completion(e?nil:@{@"path":path,@"bytes":@(total),@"copied":@YES,@"originalModified":@NO},e);});
#else
        close(source);Main(^{completion(nil,ISHError(@"此构建没有 iSH 运行库"));});
#endif
    });
}
- (void)exportFile:(NSString *)path session:(NSString *)session completion:(void (^)(NSDictionary *,NSError *))completion{
 dispatch_async(self.queue,^{NSError *e=nil;
  NSString *name=[path isKindOfClass:NSString.class]?path.lastPathComponent:nil;
  if(![path isKindOfClass:NSString.class]||!path.isAbsolutePath||[path lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>4096||[path.pathComponents containsObject:@".."]||!name.length||[name isEqual:@".dylix-export.plist"]||[path rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound){Main(^{completion(nil,ISHError(@"请输入沙盒内普通文件的绝对路径，不支持目录或越界路径"));});return;}
  if(![self prepare:session error:&e]){Main(^{completion(nil,e);});return;}
#if DYLIX_HAS_ISH
  struct task *saved=current;current=DylixInit;struct fs_info *initFS=DylixInit->fs;DylixInit->fs=fs_info_copy(initFS);
  int rootError=SetRoot(self.mounts[SessionKey(session)]);
  struct statbuf st={0};struct fd *input=NULL;
  if(rootError<0||generic_statat(AT_PWD,path.UTF8String,&st,false)<0||!S_ISREG(st.mode)||st.size>1024ULL*1024*1024)e=ISHError(@"只能导出沙盒内不超过 1 GiB 的普通文件，符号链接不会跟随");
  if(!e){input=generic_open(path.UTF8String,O_RDONLY_|O_NONBLOCK_|O_NOFOLLOW_,0);if(IS_ERR(input)){input=NULL;e=ISHError(@"无法读取沙盒文件");}else if(!S_ISREG(input->type)){fd_close(input);input=NULL;e=ISHError(@"沙盒文件类型已变化");}}
  NSString *identifier=NSUUID.UUID.UUIDString;
  NSString *root=[[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject.stringByResolvingSymlinksInPath stringByAppendingPathComponent:@"DylixLinuxExports"] stringByAppendingPathComponent:identifier] copy];
  uint64_t total=0;int output=-1;
  if(!e&&![NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&e]){}
  if(!e&&![root.stringByResolvingSymlinksInPath isEqual:root])e=ISHError(@"导出目录包含符号链接，未保存");
  if(!e){output=open([[root stringByAppendingPathComponent:name] fileSystemRepresentation],O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,0600);if(output<0)e=ISHError(@"无法创建本机导出副本");}
  if(!e){uint8_t bytes[65536];ssize_t n;while((n=input->ops->read(input,bytes,sizeof(bytes)))!=0){
    if(n<0){e=ISHError(@"读取沙盒文件失败");break;}total+=n;if(total>1024ULL*1024*1024){e=ISHError(@"文件在导出时增大，超过 1 GiB");break;}
    ssize_t at=0;while(at<n){ssize_t w=write(output,bytes+at,n-at);if(w<0&&errno==EINTR)continue;if(w<=0){e=ISHError(@"导出失败，请检查存储空间");break;}at+=w;}if(e)break;
  }}
  if(output>=0){if(close(output)<0&&!e)e=ISHError(@"保存导出副本失败");}if(input)fd_close(input);
  fs_info_release(DylixInit->fs);DylixInit->fs=initFS;current=saved;
  NSDictionary *metadata=@{@"session":session,@"name":name,@"bytes":@(total)};
  if(!e&&![metadata writeToFile:[root stringByAppendingPathComponent:@".dylix-export.plist"] atomically:YES])e=ISHError(@"保存导出索引失败");
  if(e)[NSFileManager.defaultManager removeItemAtPath:root error:nil];
  NSDictionary *result=e?nil:@{@"export_id":identifier,@"name":name,@"bytes":@(total),@"copied":@YES,@"originalModified":@NO};Main(^{completion(result,e);});
#else
  Main(^{completion(nil,ISHError(@"此构建没有 iSH 运行库"));});
#endif
 });
}
- (void)drainStdio:(DylixISHJob *)job{
 for(int i=1;i<3;i++){int fd=i==1?job.rawOut:job.rawErr;if(fd<0)continue;NSMutableData *target=i==1?job.rawBuffer:job.rawErrors;uint8_t buffer[16384];ssize_t n;NSUInteger drained=0;
  while(drained<256*1024&&(n=read(fd,buffer,sizeof(buffer)))>0){drained+=n;[target appendBytes:buffer length:n];if(i==1&&target.length>8*1024*1024){job.cancelled=YES;[self kill:job];break;}if(i==2&&target.length>16384)[target replaceBytesInRange:NSMakeRange(0,target.length-16384) withBytes:NULL length:0];}
 }
 if(job.rawPending.length&&job.rawIn>=0){ssize_t n=write(job.rawIn,job.rawPending.bytes,job.rawPending.length);if(n>0)[job.rawPending replaceBytesInRange:NSMakeRange(0,n) withBytes:NULL length:0];else if(n<0&&errno!=EAGAIN&&errno!=EINTR){close(job.rawIn);job.rawIn=-1;}}
}
- (void)pollStdio:(DylixISHJob *)job{
 if(job.done)return;[self drainStdio:job];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,20*NSEC_PER_MSEC),self.queue,^{[self pollStdio:job];});
}
- (void)openStdio:(NSString *)executable arguments:(NSArray<NSString *> *)arguments session:(NSString *)session completion:(void (^)(NSString *,NSError *))completion{[self openStdio:executable arguments:arguments environment:@{} session:session completion:completion];}
- (void)openStdio:(NSString *)executable arguments:(NSArray<NSString *> *)arguments environment:(NSDictionary *)environment session:(NSString *)session completion:(void (^)(NSString *,NSError *))completion{
 dispatch_async(self.queue,^{NSError *error=nil;
  BOOL valid=[executable isKindOfClass:NSString.class]&&executable.isAbsolutePath&&executable.length<=4096&&![executable.pathComponents containsObject:@".."]&&[arguments isKindOfClass:NSArray.class]&&arguments.count<=64;
  NSUInteger bytes=0;for(id arg in arguments){if(![arg isKindOfClass:NSString.class]||[arg rangeOfString:[NSString stringWithFormat:@"%C",(unichar)0]].location!=NSNotFound){valid=NO;break;}bytes+=[arg lengthOfBytesUsingEncoding:NSUTF8StringEncoding];}if([executable rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)valid=NO;
  NSRegularExpression *envName=[NSRegularExpression regularExpressionWithPattern:@"^[A-Z_][A-Z0-9_]{0,63}$" options:0 error:nil];if(![environment isKindOfClass:NSDictionary.class]||environment.count>64)valid=NO;else for(id key in environment){id value=environment[key];if(![key isKindOfClass:NSString.class]||![envName firstMatchInString:key options:0 range:NSMakeRange(0,[key length])]||![value isKindOfClass:NSString.class]||[value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound||[@[@"PATH",@"HOME",@"ENV",@"BASH_ENV",@"IFS",@"PWD"] containsObject:key]||[key hasPrefix:@"LD_"]||[key hasPrefix:@"DYLD_"])valid=NO;else bytes+=[value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];}
  if(!valid||bytes>32768){Main(^{completion(nil,ISHError(@"本地 MCP 需要 Linux 内绝对可执行路径和最多 64 个纯文本参数"));});return;}
  if(![self prepare:session error:&error]){Main(^{completion(nil,error);});return;}
  NSUInteger count=0;for(DylixISHJob *job in self.jobs.allValues)if(!job.terminal)count++;if(count>=ProcessConcurrencyLimit()){Main(^{completion(nil,ISHError([NSString stringWithFormat:@"Linux 后台进程已达 %lu 个上限",(unsigned long)ProcessConcurrencyLimit()]));});return;}
  DylixISHJob *job=[DylixISHJob new];job.raw=YES;job.session=session;job.key=SessionKey(session);job.processID=NSUUID.UUID.UUIDString;job.executable=executable;job.arguments=arguments.copy;job.environment=environment.copy;job.tail=[NSMutableData new];job.rawBuffer=[NSMutableData new];job.rawErrors=[NSMutableData new];job.rawPending=[NSMutableData new];
  [self startJob:job columns:80 rows:24 error:&error];if(!error){self.stdioJobs[job.processID]=job;[self pollStdio:job];}Main(^{completion(error?nil:job.processID,error);});
 });
}
- (void)stdio:(NSString *)identifier input:(NSData *)input session:(NSString *)session completion:(void (^)(NSDictionary *,NSError *))completion{
 dispatch_async(self.queue,^{DylixISHJob *job=self.stdioJobs[identifier];if(!job||![job.session isEqual:session]){Main(^{completion(nil,ISHError(@"本地 MCP 管道不存在或不属于当前会话"));});return;}
  [self drainStdio:job];if(input.length){if(job.done||job.rawIn<0||input.length+job.rawPending.length>256*1024){Main(^{completion(nil,ISHError(@"MCP 管道已关闭或输入积压"));});return;}[job.rawPending appendData:input];[self drainStdio:job];}
  NSDictionary *result=@{@"stdout":job.rawBuffer.copy,@"stderr_bytes":@(job.rawErrors.length),@"running":@(!job.done),@"overflow":@(job.rawBuffer.length>8*1024*1024)};[job.rawBuffer setLength:0];Main(^{completion(result,nil);});
 });
}
- (BOOL)isStdioRunning:(NSString *)identifier session:(NSString *)session{__block BOOL running=NO;dispatch_sync(self.queue,^{DylixISHJob *job=self.stdioJobs[identifier];running=job&&!job.done&&[job.session isEqual:session];});return running;}
- (void)closeStdio:(NSString *)identifier session:(NSString *)session{dispatch_async(self.queue,^{DylixISHJob *job=self.stdioJobs[identifier];if(!job||![job.session isEqual:session])return;[self complete:job status:9 error:nil];for(int i=0;i<3;i++){int fd=i==0?job.rawIn:i==1?job.rawOut:job.rawErr;if(fd>=0)close(fd);}job.rawIn=job.rawOut=job.rawErr=-1;[self.stdioJobs removeObjectForKey:identifier];});}

- (void)fileOperation:(NSString *)operation path:(NSString *)path arguments:(NSDictionary *)args session:(NSString *)session completion:(void (^)(NSDictionary *,NSError *))completion{
 dispatch_async(self.queue,^{NSError *error=nil;NSDictionary *result=nil;
  if(![path isKindOfClass:NSString.class]||!path.isAbsolutePath||path.length>4096||[path.pathComponents containsObject:@".."]||[path rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound||![@[@"list",@"read",@"write",@"mkdir",@"copy",@"move",@"rename",@"search",@"tree",@"probe",@"read_range"] containsObject:operation]){Main(^{completion(nil,ISHError(@"文件操作或路径无效"));});return;}
  if(![self prepare:session error:&error]){Main(^{completion(nil,error);});return;}
#if DYLIX_HAS_ISH
  struct task *saved=current;current=DylixInit;struct fs_info *initial=DylixInit->fs;DylixInit->fs=fs_info_copy(initial);int rootError=SetRoot(self.mounts[SessionKey(session)]);
  // Reject symlinks in every existing component, including intermediate directories.
  NSString *prefix=@"";struct statbuf st={0};if(rootError<0)error=ISHError(@"无法打开当前沙盒");
  for(NSString *part in [operation isEqual:@"probe"]?@[]:path.pathComponents){if([part isEqual:@"/"]||[part isEqual:@"."])continue;prefix=[prefix stringByAppendingFormat:@"/%@",part];int e=generic_statat(AT_PWD,prefix.UTF8String,&st,false);if(e<0){if([prefix isEqual:path.stringByStandardizingPath]&&[@[@"write",@"mkdir"] containsObject:operation])break;error=ISHError(@"路径不存在或不可读取");break;}if(S_ISLNK(st.mode)){error=ISHError(@"文件浏览不跟随符号链接");break;}}
  if(!error&&[operation isEqual:@"probe"]){int e=generic_statat(AT_PWD,path.UTF8String,&st,true);result=@{@"path":path,@"exists":@(e==0),@"executable":@(e==0&&S_ISREG(st.mode)&&(st.mode&0111)),@"directory":@(e==0&&S_ISDIR(st.mode))};}
  else if(!error&&[operation isEqual:@"read_range"]){uint64_t offset=[args[@"offset"] unsignedLongLongValue];NSUInteger max=MIN(16384,MAX(1,args[@"max_bytes"]?[args[@"max_bytes"] unsignedIntegerValue]:16384));struct fd *fd=generic_open(path.UTF8String,O_RDONLY_|O_NOFOLLOW_|O_NONBLOCK_,0);if(IS_ERR(fd)||!S_ISREG(fd->type)){if(!IS_ERR(fd))fd_close(fd);error=ISHError(@"分页只支持普通文件");}else if(offset>(uint64_t)st.size||offset>INT64_MAX||!fd->ops->lseek||fd->ops->lseek(fd,(off_t_)offset,SEEK_SET)<0){fd_close(fd);error=ISHError(@"读取偏移超出文件范围");}else{uint8_t bytes[16384];ssize_t count=fd->ops->read(fd,bytes,max);fd_close(fd);if(count<0)error=ISHError(@"分页读取失败");else{NSData *data=[NSData dataWithBytes:bytes length:count];NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(!text)for(NSUInteger skip=1;skip<=3&&skip<(NSUInteger)count;skip++){text=[[NSString alloc]initWithBytes:bytes length:count-skip encoding:NSUTF8StringEncoding];if(text){count-=skip;break;}}if(!text&&count)error=ISHError(@"所选范围不是 UTF-8 或偏移切入字符内部，可导出二进制文件");else result=@{@"path":path,@"content":text?:@"",@"bytes_read":@(count),@"offset":@(offset),@"next_offset":@(offset+count),@"hasMore":@(offset+count<(uint64_t)st.size),@"total_bytes":@(st.size),@"project_modified":@NO};}}}
  else if(!error&&[@[@"copy",@"move",@"rename",@"search",@"tree"] containsObject:operation]){result=GuestAdvanced(operation,path,args,&error);}
  else if(!error&&[operation isEqual:@"mkdir"]){if(generic_mkdirat(AT_PWD,path.UTF8String,0700)<0)error=ISHError(@"创建目录失败，可能已经存在");else result=@{@"path":path,@"created":@YES};}
  else if(!error&&[operation isEqual:@"list"]){
   struct fd *dir=generic_open(path.UTF8String,O_RDONLY_|O_DIRECTORY_|O_NOFOLLOW_,0);
   if(IS_ERR(dir))error=ISHError(@"无法读取目录");else{NSMutableArray *items=[NSMutableArray new];struct dir_entry entry;int e=0;BOOL truncated=NO;
    while((e=dir->ops->readdir(dir,&entry))>0){NSString *name=[NSString stringWithUTF8String:entry.name];if(!name||[name isEqual:@"."]||[name isEqual:@".."])continue;if(items.count>=2000){truncated=YES;break;}NSString *full=[path stringByAppendingPathComponent:name];struct statbuf s={0};if(generic_statat(AT_PWD,full.UTF8String,&s,false)<0)continue;[items addObject:@{@"name":name,@"path":full,@"kind":S_ISLNK(s.mode)?@"symlink":S_ISDIR(s.mode)?@"directory":S_ISREG(s.mode)?@"file":@"special",@"bytes":@(s.size)}];}
    fd_close(dir);if(e<0)error=ISHError(@"目录读取失败");else{[items sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){BOOL ad=[a[@"kind"] isEqual:@"directory"],bd=[b[@"kind"] isEqual:@"directory"];return ad!=bd?(ad?NSOrderedAscending:NSOrderedDescending):[a[@"name"] localizedStandardCompare:b[@"name"]];}];result=@{@"path":path,@"items":items,@"truncated":@(truncated)};}
   }
  }else if(!error){
   BOOL write=[operation isEqual:@"write"];struct fd *fd=generic_open(path.UTF8String,O_RDONLY_|O_NOFOLLOW_|O_NONBLOCK_,0);BOOL exists=!IS_ERR(fd);NSMutableData *data=[NSMutableData new];
   if(exists){if(!S_ISREG(fd->type))error=ISHError(@"只支持普通 UTF-8 文件");else{uint8_t buf[16384];ssize_t n;while((n=fd->ops->read(fd,buf,sizeof(buf)))>0){[data appendBytes:buf length:n];if(data.length>256*1024){error=ISHError(@"文本预览与编辑上限为 256 KiB，可改用导出分享");break;}}if(n<0)error=ISHError(@"读取文件失败");}fd_close(fd);}else if(!write)error=ISHError(@"文件不存在或无法读取");
   NSString *text=error?nil:[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];NSString *hash=TFAIDigest(data);
   if(!error&&!text)error=ISHError(@"文件不是 UTF-8 文本，可直接导出分享");
   if(!error&&write){NSData *next=[args[@"content"] isKindOfClass:NSString.class]?[args[@"content"] dataUsingEncoding:NSUTF8StringEncoding]:nil;NSString *expected=exists?hash:@"missing";
    if(!next||next.length>256*1024||![args[@"sha256"] isEqual:expected])error=ISHError(@"文件已变化或正文无效，请重新打开后编辑");
    else{NSString *temp=[path.stringByDeletingLastPathComponent stringByAppendingPathComponent:[@".dylix-edit-" stringByAppendingString:NSUUID.UUID.UUIDString]];struct fd *out=generic_open(temp.UTF8String,O_WRONLY_|O_CREAT_|O_EXCL_,0600);if(IS_ERR(out))error=ISHError(@"无法创建临时文件");else{NSUInteger at=0;while(at<next.length){ssize_t n=out->ops->write(out,(const uint8_t *)next.bytes+at,next.length-at);if(n<=0){error=ISHError(@"写入失败，原文件保留");break;}at+=n;}fd_close(out);if(!error&&generic_renameat(AT_PWD,temp.UTF8String,AT_PWD,path.UTF8String)<0)error=ISHError(@"原子替换失败，原文件保留");if(error)generic_unlinkat(AT_PWD,temp.UTF8String);else{hash=TFAIDigest(next);data=[next mutableCopy];text=args[@"content"];}}}
   }
   if(!error)result=@{@"path":path,@"content":text,@"bytes":@(data.length),@"sha256":hash,@"project_modified":@NO};
  }
  fs_info_release(DylixInit->fs);DylixInit->fs=initial;current=saved;
#else
  error=ISHError(@"此构建没有 iSH 运行库");
#endif
  Main(^{completion(result,error);});
 });
}

// Process handles are opaque, scoped to a Dylix session and never host PIDs.
- (void)listener:(uint64_t)context fd:(int)fd port:(unsigned)port active:(BOOL)active{
 dispatch_async(self.queue,^{for(DylixISHJob *job in self.jobs.allValues)if(job.context==context){if(active)job.listeners[@(fd)]=@(port);else[job.listeners removeObjectForKey:@(fd)];break;}});
}
- (NSString *)processHistoryPath:(NSString *)session{
 NSString *root=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"Dylix/iSH-process-history"];
 [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
 return [root stringByAppendingPathComponent:[SessionKey(session) stringByAppendingPathExtension:@"plist"]];
}
- (NSDictionary *)processInfo:(DylixISHJob *)j{
 return @{@"process_id":j.processID,@"running":@(!j.done),@"state":j.done?(j.cancelled?@"cancelled":j.timedOut?@"timed_out":@"exited"):@"running",@"exit_code":j.done?@(j.exitStatus):NSNull.null,@"bytes_produced":@(j.totalBytes),@"earliest_offset":@(j.totalBytes-j.tail.length),@"output_ring_bytes":@(j.terminal?256*1024:ProcessRingLimit()),@"spool_bytes":@(j.spooledBytes),@"spool_available":@(j.spoolPath.length>0),@"ports":[[NSSet setWithArray:j.listeners.allValues].allObjects sortedArrayUsingSelector:@selector(compare:)],@"duration":@(MAX(0,(j.done?j.finishedAt:NSProcessInfo.processInfo.systemUptime)-j.start)),@"manual_terminal":@(j.terminal),@"restored_history":@NO};
}
- (void)saveProcessHistory:(NSString *)session{
 // Bounded status-only history: no commands, environment secrets, or auto replay.
 NSMutableDictionary *records=[NSMutableDictionary new];NSString *path=[self processHistoryPath:session];
 for(NSDictionary *old in [NSArray arrayWithContentsOfFile:path])if([old[@"process_id"] isKindOfClass:NSString.class])records[old[@"process_id"]]=old;
 for(DylixISHJob *j in self.processJobs.allValues)if([j.session isEqual:session]){NSMutableDictionary *row=[[self processInfo:j] mutableCopy];if(row[@"exit_code"]==NSNull.null)[row removeObjectForKey:@"exit_code"];row[@"recordedAt"]=@(NSDate.date.timeIntervalSince1970);records[j.processID]=row;}
 NSArray *rows=[records.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [b[@"recordedAt"] compare:a[@"recordedAt"]];}];
 if(rows.count>32)rows=[rows subarrayWithRange:NSMakeRange(0,32)];[rows writeToFile:path atomically:YES];
}
- (void)pruneProcessJobsOnQueue:(NSString *)session{
 // Bound completed handles across the App; active tasks are never evicted.
 NSMutableArray *finished=[NSMutableArray new];for(DylixISHJob *job in self.processJobs.allValues)if(job.done)[finished addObject:job];
 [finished sortUsingComparator:^NSComparisonResult(DylixISHJob *a,DylixISHJob *b){return [@(a.finishedAt) compare:@(b.finishedAt)];}];
 for(DylixISHJob *job in finished){if(self.processJobs.count<=32)break;if(job.spoolPath.length)[NSFileManager.defaultManager removeItemAtPath:job.spoolPath error:nil];[self.processJobs removeObjectForKey:job.processID];}
}
- (NSArray *)processesOnQueue:(NSString *)session{
 NSMutableArray *rows=[NSMutableArray new];NSMutableSet *ids=[NSMutableSet new];
 for(DylixISHJob *j in self.processJobs.allValues)if([j.session isEqual:session]){[rows addObject:[self processInfo:j]];[ids addObject:j.processID];}
 for(NSDictionary *old in [NSArray arrayWithContentsOfFile:[self processHistoryPath:session]])if(![ids containsObject:old[@"process_id"]]){NSMutableDictionary *row=[old mutableCopy];row[@"running"]=@NO;if([old[@"running"] boolValue])row[@"state"]=@"interrupted_by_app_restart";row[@"ports"]=@[];row[@"restored_history"]=@YES;[rows addObject:row];}
 return rows.count>32?[rows subarrayWithRange:NSMakeRange(0,32)]:rows;
}
- (NSArray *)processes:(NSString *)session{if(![session isKindOfClass:NSString.class]||!session.length)return @[];__block NSArray *rows;dispatch_sync(self.queue,^{rows=[self processesOnQueue:session];});return rows;}
- (void)writeJob:(DylixISHJob *)j data:(NSData *)data{
#if DYLIX_HAS_ISH
 if(j.done||!j.nativeTTY)return;lock(&ttys_lock);struct tty *tty=j.nativeTTY;tty->refcount++;unlock(&ttys_lock);
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{tty_input(tty,data.bytes,data.length,false);lock(&ttys_lock);tty_release(tty);unlock(&ttys_lock);});
#endif
}
- (NSDictionary *)readJob:(DylixISHJob *)job offset:(uint64_t)offset maximum:(NSUInteger)maximum{
 uint64_t first=job.totalBytes-job.tail.length,begin=MAX(first,MIN(offset,job.totalBytes)),missed=0;NSData *data=nil;
 if(offset<first&&offset<job.spooledBytes&&job.spoolPath.length){uint64_t available=MIN(first-offset,job.spooledBytes-offset);NSFileHandle *handle=[NSFileHandle fileHandleForReadingAtPath:job.spoolPath];NSError *error=nil;if(handle&&[handle seekToOffset:offset error:&error])data=[handle readDataUpToLength:MIN(maximum,(NSUInteger)available) error:&error];[handle closeAndReturnError:nil];if(data.length)begin=offset;else data=nil;}
 if(!data){if(offset<first)missed=first-offset;NSUInteger at=(NSUInteger)(begin-first),length=MIN(maximum,job.tail.length-at);data=[job.tail subdataWithRange:NSMakeRange(at,length)];}
 NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
 NSMutableDictionary *r=[[self processInfo:job] mutableCopy];r[@"offset"]=@(begin);r[@"next_offset"]=@(begin+data.length);r[@"missed_bytes"]=@(missed);r[@"encoding"]=text?@"utf8":@"base64";r[@"output"]=text?:[data base64EncodedStringWithOptions:0];r[@"has_more"]=@([r[@"next_offset"] unsignedLongLongValue]<job.totalBytes);return r;
}
- (void)pollRead:(DylixISHJob *)job offset:(uint64_t)offset maximum:(NSUInteger)maximum deadline:(NSTimeInterval)deadline completion:(void (^)(NSDictionary *,NSError *))completion{
 if(job.done||job.totalBytes>offset||NSProcessInfo.processInfo.systemUptime>=deadline){NSDictionary *r=[self readJob:job offset:offset maximum:maximum];Main(^{completion(r,nil);});return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),self.queue,^{[self pollRead:job offset:offset maximum:maximum deadline:deadline completion:completion];});
}
- (void)performProcess:(NSString *)operation arguments:(NSDictionary *)args session:(NSString *)session completion:(void (^)(NSDictionary *,NSError *))completion{
 dispatch_async(self.queue,^{NSError *error=nil;
  if(![session isKindOfClass:NSString.class]||!session.length){Main(^{completion(nil,ISHError(@"进程必须属于有效会话"));});return;}
  if([operation isEqual:@"list"]){NSArray *rows=[self processesOnQueue:session];Main(^{completion(@{@"processes":rows,@"appRestartResumesProcesses":@NO},nil);});return;}
  if([operation isEqual:@"start"]){
   NSString *command=args[@"command"];if(![command isKindOfClass:NSString.class]||!command.length||[command lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>65536||[command rangeOfString:[NSString stringWithFormat:@"%C",(unichar)0]].location!=NSNotFound){Main(^{completion(nil,ISHError(@"命令为空、含空字符或超过 64 KiB"));});return;}
   double seconds=args[@"timeout"]?[args[@"timeout"] doubleValue]:0;if(!isfinite(seconds)||seconds<0||seconds>86400){Main(^{completion(nil,ISHError(@"进程超时应为 0–86400 秒，0 表示不设置超时"));});return;}
   if(![self prepare:session error:&error]){Main(^{completion(nil,error);});return;}[self autoInstallForSession:session];
   NSUInteger active=0;for(DylixISHJob *j in self.jobs.allValues)if(!j.terminal)active++;if(active>=ProcessConcurrencyLimit()){Main(^{completion(nil,ISHError([NSString stringWithFormat:@"已有 %lu 个 Linux 任务运行，请先停止或等待",(unsigned long)ProcessConcurrencyLimit()]));});return;}
   // Keep at most 32 completed handles, while never evicting active processes.
   [self pruneProcessJobsOnQueue:session];
   DylixISHJob *job=[DylixISHJob new];job.session=session;job.key=SessionKey(session);job.processID=NSUUID.UUID.UUIDString;job.command=command;job.tail=[NSMutableData new];job.managed=YES;
   [self prepareSpool:job];
   [self startJob:job columns:args[@"columns"]?[args[@"columns"] intValue]:100 rows:args[@"rows"]?[args[@"rows"] intValue]:30 error:&error];if(error){Main(^{completion(nil,error);});return;}
   [self saveProcessHistory:session];NSDictionary *info=[self processInfo:job];Main(^{completion(info,nil);});[self setState:@"后台 Linux 进程运行中" session:session];
   if(seconds>0)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(seconds*NSEC_PER_SEC)),self.queue,^{if(!job.done){job.timedOut=YES;[self kill:job];[self complete:job status:9 error:nil];}});return;
  }
  NSString *identifier=args[@"process_id"];DylixISHJob *job=[identifier isKindOfClass:NSString.class]?self.processJobs[identifier]:nil;
  if(!job||![job.session isEqual:session]){Main(^{completion(nil,ISHError(@"此进程不存在、已被回收或不属于当前会话；请重新列出进程"));});return;}
  if([operation isEqual:@"read"]){
   uint64_t offset=[args[@"offset"] unsignedLongLongValue];NSUInteger maximum=args[@"max_bytes"]?[args[@"max_bytes"] unsignedIntegerValue]:8192;maximum=MAX(1,MIN(maximum,16384));double wait=MAX(0,MIN(10,[args[@"wait_seconds"] doubleValue]));
   [self pollRead:job offset:offset maximum:maximum deadline:NSProcessInfo.processInfo.systemUptime+wait completion:completion];return;
  }
  if([operation isEqual:@"stop"]){if(!job.done){job.cancelled=YES;[self kill:job];[self complete:job status:9 error:nil];}NSDictionary *result=[self processInfo:job];Main(^{completion(result,nil);});return;}
  if(job.done){Main(^{completion(nil,ISHError(@"进程已结束，不能继续写入或调整窗口"));});return;}
  if([operation isEqual:@"write"]){NSString *input=args[@"input"];NSData *data=[input isKindOfClass:NSString.class]?[input dataUsingEncoding:NSUTF8StringEncoding]:nil;if(!data||data.length>65536){Main(^{completion(nil,ISHError(@"输入必须是最多 64 KiB 的 UTF-8 文本"));});return;}[self writeJob:job data:data];Main(^{completion(@{@"process_id":identifier,@"accepted_bytes":@(data.length),@"queuedToPTY":@YES},nil);});return;}
  if([operation isEqual:@"resize"]){
#if DYLIX_HAS_ISH
   if(job.nativeTTY)tty_set_winsize(job.nativeTTY,(struct winsize_){.row=MAX(1,MIN(300,[args[@"rows"] intValue])),.col=MAX(20,MIN(500,[args[@"columns"] intValue]))});
#endif
   Main(^{completion(@{@"process_id":identifier,@"resized":@YES},nil);});return;
  }
  Main(^{completion(nil,ISHError(@"不支持此进程操作"));});
 });
}
- (BOOL)ownsURLOnQueue:(NSURL *)url process:(NSString *)identifier session:(NSString *)session{
 if(![identifier isKindOfClass:NSString.class]||![session isKindOfClass:NSString.class]||![url isKindOfClass:NSURL.class])return NO;
 DylixISHJob *job=self.processJobs[identifier];return job&&!job.done&&[job.session isEqual:session]&&[url.scheme isEqual:@"http"]&&[url.host isEqual:@"127.0.0.1"]&&!url.user.length&&!url.password.length&&url.port.integerValue>0&&[job.listeners.allValues containsObject:url.port];
}
- (BOOL)ownsPreviewURL:(NSURL *)url process:(NSString *)identifier session:(NSString *)session{__block BOOL ok=NO;dispatch_sync(self.queue,^{ok=[self ownsURLOnQueue:url process:identifier session:session];});return ok;}
- (void)preview:(NSString *)identifier port:(NSInteger)port path:(NSString *)path session:(NSString *)session completion:(void (^)(NSDictionary *,NSError *))completion{
 dispatch_async(self.queue,^{DylixISHJob *job=[identifier isKindOfClass:NSString.class]?self.processJobs[identifier]:nil;
  NSInteger selected=port;if(selected==0&&job.listeners.count)selected=[job.listeners.allValues.firstObject integerValue];
  NSString *relative=[path isKindOfClass:NSString.class]&&path.length?path:@"/";
  NSURLComponents *parts=[NSURLComponents new];parts.scheme=@"http";parts.host=@"127.0.0.1";parts.port=@(selected);
  // A path is not a URL: reject authority changes, controls and query credentials.
  if(![relative hasPrefix:@"/"]||[relative hasPrefix:@"//"]||[relative rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound||relative.length>4096){Main(^{completion(nil,ISHError(@"请输入预览路径，例如 /index.html，不是外部 URL"));});return;}
  parts.percentEncodedPath=[relative stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];NSURL *url=parts.URL;
  if(![self ownsURLOnQueue:url process:identifier session:session]){Main(^{completion(nil,ISHError(@"该进程没有对应的本机 HTTP 监听端口；请先启动服务器，再列出进程确认 ports"));});return;}
  Main(^{completion(@{@"url":url.absoluteString,@"process_id":identifier,@"port":@(selected),@"local_only":@YES},nil);});
 });
}
+ (BOOL)developerToolsAvailable{
 return [NSBundle.mainBundle pathForResource:@"developer-tools" ofType:@"tar" inDirectory:@"iSH"]!=nil&&[NSBundle.mainBundle pathForResource:@"developer-tools" ofType:@"json" inDirectory:@"iSH"]!=nil;
}
- (void)installDeveloperTools:(NSString *)session completion:(void (^)(NSDictionary *,NSError *))completion{
 dispatch_async(self.queue,^{
  NSString *path=[NSBundle.mainBundle pathForResource:@"developer-tools" ofType:@"tar" inDirectory:@"iSH"];
  NSString *index=[NSBundle.mainBundle pathForResource:@"developer-tools" ofType:@"json" inDirectory:@"iSH"];
  NSData *manifestData=index?[NSData dataWithContentsOfFile:index]:nil;id parsed=manifestData?[NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil]:nil;NSDictionary *manifest=[parsed isKindOfClass:NSDictionary.class]?parsed:nil;
  NSData *archive=path?[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil]:nil;
  if(!archive||![manifest[@"sha256"] isKindOfClass:NSString.class]||![TFAIDigest(archive) isEqual:manifest[@"sha256"]]){Main(^{completion(nil,ISHError(@"离线开发工具包缺失或校验失败，请重新安装完整版本"));});return;}
  [self.autoDeveloperSessions addObject:SessionKey(session)];
  // Only bundled signed APKs; apk verifies Alpine signatures against guest trusted keys.
  Main(^{[self importFile:[NSURL fileURLWithPath:path] name:@"developer-tools.tar" session:session completion:^(NSDictionary *r,NSError *e){
   if(!r){dispatch_async(self.queue,^{[self.autoDeveloperSessions removeObject:SessionKey(session)];});completion(nil,e);return;}NSString *quoted=[r[@"path"] stringByReplacingOccurrencesOfString:@"'" withString:@"'\"'\"'"];
   NSString *command=[NSString stringWithFormat:@"set -e; mkdir -p /opt/dylix-tools; tar -xf '%@' -C /opt/dylix-tools; apk --no-progress add --no-network /opt/dylix-tools/packages/*.apk; rm -f '%@'; printf '\\nDYLIX_DEVELOPER_TOOLS_INSTALLED\\n'; python3 --version; node --version; npm --version; git --version",quoted,quoted];
   [self performProcess:@"start" arguments:@{@"command":command} session:session completion:^(NSDictionary *result,NSError *error){
    if(!error&&[result[@"process_id"] isKindOfClass:NSString.class])[self watchToolInstall:result[@"process_id"] session:session defaultsKey:@"DylixISHDeveloperToolsAutoload" marker:@"DYLIX_DEVELOPER_TOOLS_INSTALLED" deadline:NSProcessInfo.processInfo.systemUptime+600];
    if(error)dispatch_async(self.queue,^{[self.autoDeveloperSessions removeObject:SessionKey(session)];});
    completion(result,error);
   }];
  }];});
 });
}
+ (BOOL)reverseToolsAvailable{return [NSBundle.mainBundle pathForResource:@"reverse-tools" ofType:@"tar" inDirectory:@"iSH"]!=nil;}
- (void)installReverseTools:(NSString *)session completion:(void (^)(NSDictionary *,NSError *))completion{
 dispatch_async(self.queue,^{NSString *path=[NSBundle.mainBundle pathForResource:@"reverse-tools" ofType:@"tar" inDirectory:@"iSH"],*index=[NSBundle.mainBundle pathForResource:@"reverse-tools" ofType:@"json" inDirectory:@"iSH"];NSData *data=path?[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil]:nil;id parsed=index?[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:index]?:NSData.data options:0 error:nil]:nil;NSDictionary *manifest=[parsed isKindOfClass:NSDictionary.class]?parsed:nil;
  if(!data||![manifest[@"sha256"] isKindOfClass:NSString.class]||![TFAIDigest(data) isEqual:manifest[@"sha256"]]){Main(^{completion(nil,ISHError(@"离线逆向工具包缺失或哈希不符"));});return;}
  [self.autoReverseSessions addObject:SessionKey(session)];
  Main(^{[self importFile:[NSURL fileURLWithPath:path] name:@"reverse-tools.tar" session:session completion:^(NSDictionary *r,NSError *e){if(!r){dispatch_async(self.queue,^{[self.autoReverseSessions removeObject:SessionKey(session)];});completion(nil,e);return;}NSString *quoted=[r[@"path"] stringByReplacingOccurrencesOfString:@"'" withString:@"'\"'\"'"];
   NSString *command=[NSString stringWithFormat:@"set -e; mkdir -p /opt/dylix-reverse-packages /opt/dylix-reverse; tar -xf '%@' -C /opt/dylix-reverse-packages; apk --no-progress --root /opt/dylix-reverse --initdb --keys-dir /etc/apk/keys --no-scripts add --no-network /opt/dylix-reverse-packages/packages/*.apk; rm -f '%@'; R2_PREFIX=/opt/dylix-reverse/usr /opt/dylix-reverse/lib/ld-musl-aarch64.so.1 --library-path /opt/dylix-reverse/lib:/opt/dylix-reverse/usr/lib /opt/dylix-reverse/usr/bin/radare2 -v; printf '\\nDYLIX_REVERSE_TOOLS_INSTALLED\\n'",quoted,quoted];[self performProcess:@"start" arguments:@{@"command":command,@"timeout":@300} session:session completion:^(NSDictionary *result,NSError *error){
    if(!error&&[result[@"process_id"] isKindOfClass:NSString.class])[self watchToolInstall:result[@"process_id"] session:session defaultsKey:@"DylixISHReverseToolsAutoload" marker:@"DYLIX_REVERSE_TOOLS_INSTALLED" deadline:NSProcessInfo.processInfo.systemUptime+600];
    if(error)dispatch_async(self.queue,^{[self.autoReverseSessions removeObject:SessionKey(session)];});
    completion(result,error);
   }];
  }];});
 });
}
- (void)analyzeBinaryFile:(NSURL *)file arguments:(NSDictionary *)args session:(NSString *)session completion:(void (^)(NSDictionary *,NSError *))completion{
 NSString *operation=args[@"operation"];NSSet *operations=[NSSet setWithArray:@[@"decompile",@"functions",@"cfg",@"xrefs",@"disassemble",@"strings",@"imports",@"sections",@"pcode"]];if(![operations containsObject:operation]){completion(nil,ISHError(@"逆向操作无效"));return;}
 uint64_t address=0;NSString *raw=args[@"address"];BOOL needs=[@[@"decompile",@"cfg",@"xrefs",@"disassemble",@"pcode"] containsObject:operation];if(needs){NSScanner *scan=[raw isKindOfClass:NSString.class]?[NSScanner scannerWithString:raw]:nil;if(!scan||![scan scanHexLongLong:&address]||!scan.isAtEnd||(address&3)){completion(nil,ISHError(@"请使用已确认的对齐十六进制函数地址"));return;}}
 [self fileOperation:@"probe" path:@"/opt/dylix-reverse/usr/bin/radare2" arguments:@{} session:session completion:^(NSDictionary *probe,NSError *error){if(error||![probe[@"executable"] boolValue]){completion(nil,error?:ISHError(@"本会话尚未安装逆向工具包；先 sandbox_reverse(operation=install)，用 process_read 确认退出码为 0"));return;}
 [self importFile:file name:@"analysis-input.macho" session:session completion:^(NSDictionary *input,NSError *e){if(!input){completion(nil,e);return;}NSString *identifier=NSUUID.UUID.UUIDString,*dir=[@"/workspace/analysis/" stringByAppendingString:identifier],*output=[dir stringByAppendingPathComponent:[operation stringByAppendingPathExtension:[operation isEqual:@"decompile"]?@"c":[operation isEqual:@"pcode"]?@"txt":@"json"]],*addr=[NSString stringWithFormat:@"0x%llx",(unsigned long long)address];
 NSDictionary *commands=@{@"decompile":[NSString stringWithFormat:@"af @ %@;pdg @ %@",addr,addr],@"functions":@"aa;aflj",@"cfg":[NSString stringWithFormat:@"af @ %@;agfj @ %@",addr,addr],@"xrefs":[NSString stringWithFormat:@"aa;axtj @ %@",addr],@"disassemble":[NSString stringWithFormat:@"pdj 128 @ %@",addr],@"strings":@"izj",@"imports":@"iij",@"sections":@"iSj",@"pcode":[NSString stringWithFormat:@"s %@;pdgsd 32",addr]};
 NSString *(^quote)(NSString *)=^NSString *(NSString *s){return [@"'" stringByAppendingFormat:@"%@'",[s stringByReplacingOccurrencesOfString:@"'" withString:@"'\"'\"'"]];};
 NSString *command=[NSString stringWithFormat:@"mkdir -p %@ || exit 1; R2_PREFIX=/opt/dylix-reverse/usr R2_LIBR_PLUGINS=/opt/dylix-reverse/usr/lib/radare2/6.2.6 SLEIGHHOME=/opt/dylix-reverse/usr/lib/radare2/6.2.6/r2ghidra_sleigh timeout -s KILL 120 /opt/dylix-reverse/lib/ld-musl-aarch64.so.1 --library-path /opt/dylix-reverse/lib:/opt/dylix-reverse/usr/lib /opt/dylix-reverse/usr/bin/radare2 -N -q -e scr.color=0 -e scr.interactive=false -e bin.cache=true -e dir.plugins=/opt/dylix-reverse/usr/lib/radare2/6.2.6 -c %@ %@ > %@ 2> %@; rc=$?; printf 'DYLIX_ANALYSIS_EXIT=%%s\\n' \"$rc\"; head -c 1024 %@; exit \"$rc\"",quote(dir),quote([commands[operation] stringByAppendingString:@";q!"]),quote(input[@"path"]),quote(output),quote([dir stringByAppendingPathComponent:@"diagnostic.txt"]),quote([dir stringByAppendingPathComponent:@"diagnostic.txt"])];
 [self performProcess:@"start" arguments:@{@"command":command,@"timeout":@130} session:session completion:^(NSDictionary *r,NSError *e){if(!r){completion(nil,e);return;}NSMutableDictionary *result=[r mutableCopy];result[@"output_path"]=output;result[@"engine"]=@"radare2 6.2.6 + Ghidra native (r2ghidra)";result[@"operation"]=operation;result[@"input_sha256"]=input[@"sha256"]?:@"";result[@"note"]=@"任务已启动，尚未证明分析成功。用 process_read 确认退出码，再 sandbox_files read 读取结果。反编译是近似 C，不是原始源码；空/null/错误 JSON 不能当成功。分析超时 120 秒，输入只读，结果留在本会话 Linux；可导出分享。";completion(result,nil);}];
 }];}];
}

+ (NSArray *)processSchemas{
 NSDictionary *handle=@{@"type":@"string"},*integer=@{@"type":@"integer",@"minimum":@0};NSMutableArray *schemas=[NSMutableArray new];
 void(^add)(NSString *,NSString *,NSDictionary *,NSArray *)=^(NSString *name,NSString *description,NSDictionary *props,NSArray *required){[schemas addObject:@{@"name":[@"sandbox_process_" stringByAppendingString:name],@"description":description,@"parameters":@{@"type":@"object",@"properties":props,@"required":required,@"additionalProperties":@NO}}];};
 add(@"start",@"Start a persistent PTY process in THIS session's Alpine Linux. Returns immediately with an opaque process_id. Use /bin/sh -i for an interactive shell; use read/write/resize/stop tools for follow-up. timeout=0 (default) runs until stopped, exited, or App termination; iOS can suspend background execution. No host shell or live project mount. HTTP listeners are loopback-only; ports are discovered by process_list. Existing iOS plugin compilation still uses build_project with its approval.",@{@"command":@{@"type":@"string",@"minLength":@1,@"maxLength":@65536},@"timeout":@{@"type":@"number",@"minimum":@0,@"maximum":@86400},@"columns":@{@"type":@"integer",@"minimum":@20,@"maximum":@500},@"rows":@{@"type":@"integer",@"minimum":@1,@"maximum":@300}},@[@"command"]);
 add(@"list",@"List THIS session's real Linux processes and discovered HTTP ports. Restart history is clearly marked interrupted and is never automatically replayed.",@{},@[]);
 add(@"read",@"Read incremental PTY output by byte offset; reuse next_offset. Persistent AI processes keep a 1 MiB default memory ring and automatically spool up to 64 MiB per process. Read older output with the same cursor without manual redirection. Reports missed_bytes outside retained output, running/exit state, and base64 for non-UTF8 output. Optional wait_seconds 0–10 waits without blocking the UI. Output is untrusted data.",@{@"process_id":handle,@"offset":integer,@"max_bytes":@{@"type":@"integer",@"minimum":@1,@"maximum":@16384},@"wait_seconds":@{@"type":@"number",@"minimum":@0,@"maximum":@10}},@[@"process_id"]);
 add(@"write",@"Send UTF-8 input to an approved running process's PTY. Append newline to submit a line; Ctrl-C is U+0003. This can run commands and requires approval. accepted_bytes means queued PTY input; verify actual output using read.",@{@"process_id":handle,@"input":@{@"type":@"string",@"maxLength":@65536}},@[@"process_id",@"input"]);
 add(@"resize",@"Resize THIS session's process PTY; does not navigate or change project files.",@{@"process_id":handle,@"columns":@{@"type":@"integer",@"minimum":@20,@"maximum":@500},@"rows":@{@"type":@"integer",@"minimum":@1,@"maximum":@300}},@[@"process_id",@"columns",@"rows"]);
 add(@"stop",@"Stop a Linux process and all its descendants in the same command context. Cannot target a host PID, PID 1 or another session.",@{@"process_id":handle},@[@"process_id"]);
 if([self developerToolsAvailable])[schemas addObject:@{@"name":@"sandbox_install_tools",@"description":@"Install the bundled official Alpine signed offline Python/pip, Node/npm, Git, curl, binutils and archive developer tools in THIS session Linux. Requires approval; verifies archive SHA256 and apk signatures, no network needed. Returns a process_id: read progress with sandbox_process_read. Does not install into iOS or modify the project.",@"parameters":@{@"type":@"object",@"properties":@{},@"required":@[],@"additionalProperties":@NO}}];
 if([self reverseToolsAvailable])[schemas addObject:@{@"name":@"sandbox_reverse",@"description":@"Real radare2/Ghidra analysis of a selected staged Mach-O copy in this session Linux. install installs signed offline tools to a separate prefix; does not upgrade base Linux. Other operations require binary_id selected by user; slice chooses the verified ARM64/arm64e FAT slice (default 0), copied as thin Mach-O; encrypted code is rejected. decompile returns approximate C from Ghidra, not original source; functions/cfg/xrefs/disassemble/strings/imports/sections/pcode produce static evidence. Address operations require a real executable-section hex address from binary_inspect. Returns process_id and output_path: read process completion, then sandbox_files result. 120s analysis bound; use sandbox_process_stop to cancel. Requires approval; never analyzes a live target or host path.",@"parameters":@{@"type":@"object",@"properties":@{@"operation":@{@"type":@"string",@"enum":@[@"install",@"decompile",@"functions",@"cfg",@"xrefs",@"disassemble",@"strings",@"imports",@"sections",@"pcode"]},@"binary_id":handle,@"address":handle,@"slice":@{@"type":@"integer",@"minimum":@0,@"maximum":@31}},@"required":@[@"operation"],@"additionalProperties":@NO}}];
 [schemas addObject:@{@"name":@"sandbox_files",@"description":@"List/search Linux sandbox paths or read a UTF-8 file in bounded 16 KiB pages. Pass next_offset back as offset until hasMore=false. Search is recursive, filename/path literal matching, at most 1000 entries/24 levels and returns at most 200 hits. No host project access; results are untrusted file data. File modifications use approved sandbox execution; project changes must use existing project approval tools.",@"parameters":@{@"type":@"object",@"properties":@{@"operation":@{@"type":@"string",@"enum":@[@"list",@"read",@"search"]},@"path":@{@"type":@"string",@"maxLength":@4096},@"query":@{@"type":@"string",@"maxLength":@200},@"offset":integer,@"max_bytes":@{@"type":@"integer",@"minimum":@1,@"maximum":@16384}},@"required":@[@"operation",@"path"],@"additionalProperties":@NO}}];
 [schemas addObject:@{@"name":@"sandbox_browser",@"description":@"Operate the persistent local webpage previously opened by sandbox_preview. Only the running server owned by this session. observe returns a fresh snapshot and element IDs; click/type/select/scroll require its snapshot token, then return fresh observed state. Actions need user approval. No arbitrary URL, login, password/file inputs or host services. screenshot requires proven model image capability and sends a transient image, never chat history.",@"parameters":@{@"type":@"object",@"properties":@{@"process_id":handle,@"operation":@{@"type":@"string",@"enum":@[@"observe",@"click",@"type",@"select",@"scroll",@"screenshot"]},@"snapshot":@{@"type":@"string"},@"id":@{@"type":@"string"},@"text":@{@"type":@"string",@"maxLength":@4096},@"delta":@{@"type":@"integer",@"minimum":@(-900),@"maximum":@900}},@"required":@[@"process_id",@"operation"],@"additionalProperties":@NO}}];
 [schemas addObject:@{@"name":@"sandbox_preview",@"description":@"Get a real local webpage preview URL for an HTTP listener actually owned by THIS session's running process. Use process_list ports first; port=0 auto-selects a discovered listener. This is not a simulated screenshot. Open the URL using the terminal's webpage preview menu. No arbitrary host service URLs.",@"parameters":@{@"type":@"object",@"properties":@{@"process_id":handle,@"port":@{@"type":@"integer",@"minimum":@0,@"maximum":@65535},@"path":@{@"type":@"string",@"maxLength":@4096}},@"required":@[@"process_id"],@"additionalProperties":@NO}}];return schemas;
}

+ (NSDictionary *)exportSchema{return @{@"name":@"sandbox_export_file",@"description":@"Copy one regular file from this session's Linux filesystem to a local session file for sharing. Returns an opaque export_id, not a host destination. The original and project stay unchanged. Requires confirmation. Symlinks/directories are rejected; max 1 GiB.",@"parameters":@{@"type":@"object",@"properties":@{@"path":@{@"type":@"string"}},@"required":@[@"path"],@"additionalProperties":@NO}};}
+ (NSDictionary *)executeSchema{return @{@"name":@"sandbox_execute",@"description":@"Execute a Linux shell command in this session's persistent isolated Alpine/iSH filesystem. This is NOT the iOS host shell or the iOS compiler. cwd=/workspace. No live project mount. Use sandbox_import_attachment for selected files. Project changes/build/Git must use existing approved Dylix tools. Output tail is bounded; redirect large output to a guest file and read ranges. Commands can access the network. Requires user approval.",@"parameters":@{@"type":@"object",@"properties":@{@"command":@{@"type":@"string",@"minLength":@1,@"maxLength":@65536},@"timeout":@{@"type":@"number",@"minimum":@1,@"maximum":@600}},@"required":@[@"command"],@"additionalProperties":@NO}};}
+ (NSDictionary *)importSchema{return @{@"name":@"sandbox_import_attachment",@"description":@"Copy an explicitly selected single-file attachment into this session's Linux /workspace/imports. Returns its exact guest path. Does not execute it, mount a host directory, install a deb, or change the original. For a selected directory grant, provide a relative path to one regular file, discovered with read_attachment. Requires confirmation.",@"parameters":@{@"type":@"object",@"properties":@{@"id":@{@"type":@"string"},@"path":@{@"type":@"string"}},@"required":@[@"id"],@"additionalProperties":@NO}};}
@end

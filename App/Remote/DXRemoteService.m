#import "../AI/Background/TFScreenAwake.h"
#import "DXRemoteService.h"
#import "DXRemoteHTTP.h"
#import "DXRemoteAccess.h"
#import "DXRemoteWorkspace.h"
#import "DXFlexBridge.h"
#import "DXRemoteWebDAV.h"
#import "DXRemoteTLS.h"
#import "DXRemoteNetwork.h"
#import "../AI/AIV2Contracts.h"
#import "../AI/Background/TFAIAudioBackground.h"
#import "../GitService.h"
#import "../SDKResources.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
extern BOOL TMCBuildIsRunning(void);
static NSString *WiFiAddress(void){
#if TARGET_OS_SIMULATOR
 if([NSProcessInfo.processInfo.arguments containsObject:@"--remote-regression"])return @"127.0.0.1";
#endif
 NSString *mode=DXRemoteSelectedMode([NSUserDefaults.standardUserDefaults stringForKey:@"DylixRemoteNetworkMode"]);if([mode isEqual:@"local"])return @"127.0.0.1";
 struct ifaddrs *interfaces=NULL;if(getifaddrs(&interfaces))return nil;NSString *result=nil;
 for(struct ifaddrs *p=interfaces;p;p=p->ifa_next)if(p->ifa_addr&&p->ifa_addr->sa_family==AF_INET){
  struct sockaddr_in *address=(void *)p->ifa_addr;char buf[INET_ADDRSTRLEN];if(!inet_ntop(AF_INET,&address->sin_addr,buf,sizeof(buf)))continue;NSString *candidate=[NSString stringWithUTF8String:buf];
  if(DXRemoteInterfaceAllowed(candidate,[NSString stringWithUTF8String:p->ifa_name],(p->ifa_flags&IFF_UP)!=0,mode)){result=candidate;break;}
 }freeifaddrs(interfaces);return result;
}
static NSDictionary *Error(NSInteger status,NSString *code,NSString *message){return DXRemoteResponse(status,@{@"schema":@1,@"error":@{@"code":code,@"message":message}});}
@interface DXRemoteService ()
@property dispatch_queue_t queue;
@property DXRemoteHTTP *server;
@property DXRemoteAccess *access;
@property DXRemoteWorkspace *workspace;
@property NSSet *assetPaths;
@property DXRemoteHTTP *davServer;
@property DXRemoteWebDAV *dav;

@property NSString *fixedAccount;
@property BOOL wantsHTTP,wantsDAV;
@property BOOL protectedDataLocked;
@property NSString *lifecycle;
@property UIBackgroundTaskIdentifier backgroundTask;
@property NSUInteger backgroundGeneration;
@property NSString *davState,*davProject,*davRoot,*davError;
@property NSDictionary *davCredential;
@property NSUInteger davPort;
@property BOOL davReadOnly;
@property NSString *state,*address,*cookieName,*failure;
@property(nonatomic) NSUInteger port;
@property NSDictionary *snapshot;
@property(atomic) NSDictionary *localState;
@property NSTimer *timer;
@end
@implementation DXRemoteService
+ (instancetype)shared{static DXRemoteService *service;static dispatch_once_t once;dispatch_once(&once,^{service=[DXRemoteService new];});return service;}
- (instancetype)init{
 if((self=[super init])){_queue=dispatch_queue_create("com.xuegao.dylix.remote",DISPATCH_QUEUE_SERIAL);_state=@"stopped";_cookieName=@"DylixRemoteSession";_port=[NSUserDefaults.standardUserDefaults integerForKey:@"DylixRemotePort"]?:8787;_localState=@{};_snapshot=@{};_backgroundTask=UIBackgroundTaskInvalid;_lifecycle=@"foreground";
  NSString *support=NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject;NSString *store=[support stringByAppendingPathComponent:@"DylixRemote/devices.json"];
#if TARGET_OS_SIMULATOR
  if([NSProcessInfo.processInfo.arguments containsObject:@"--remote-regression"])store=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"RemoteRegression-%@/devices.json",NSUUID.UUID.UUIDString]];
#endif
  _fixedAccount=@"pairing.fixed.v1";
#if TARGET_OS_SIMULATOR
  if([NSProcessInfo.processInfo.arguments containsObject:@"--remote-regression"])_fixedAccount=[@"test.fixed." stringByAppendingString:DXRemoteHash(store)];
#endif
  _davState=@"stopped";_davPort=[NSUserDefaults.standardUserDefaults integerForKey:@"DylixRemoteDAVPort"]?:8788;_dav=[DXRemoteWebDAV new];_davServer=[[DXRemoteHTTP alloc]initWithQueue:_queue];
  _workspace=[[DXRemoteWorkspace alloc]initWithQueue:_queue];
  NSMutableSet *assetPaths=[NSMutableSet new];NSString *web=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"RemoteWeb"];for(NSString *name in [NSFileManager.defaultManager enumeratorAtPath:web]){NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:[web stringByAppendingPathComponent:name] error:nil];if([attributes[NSFileType] isEqual:NSFileTypeRegular])[assetPaths addObject:[@"/" stringByAppendingString:name]];}_assetPaths=assetPaths.copy;
  _access=[[DXRemoteAccess alloc]initWithStore:store];_server=[[DXRemoteHTTP alloc]initWithQueue:_queue];
  __weak typeof(self) weak=self;
  _davServer.stateChanged=^(NSString *state){DXRemoteService *s=weak;if(!s)return;s.davState=state;if([state isEqual:@"failed"])s.davError=@"WebDAV 端口监听失败";[s.access record:[@"webdav_" stringByAppendingString:state]];[s publish];};
  _davServer.asyncHandler=^(NSDictionary *request,void(^complete)(NSDictionary *)){
   DXRemoteService *s=weak;if(!s){complete(Error(503,@"stopped",@"服务已停止"));return;}
   NSString *authorization=request[@"headers"][@"authorization"],*token=nil;if([authorization hasPrefix:@"Basic "]){NSData *data=[[NSData alloc]initWithBase64EncodedString:[authorization substringFromIndex:6] options:0];NSString *plain=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if([plain hasPrefix:@"dylix:"])token=[plain substringFromIndex:6];}
   NSDictionary *device=token?[s.access authenticateCookie:[@"DylixRemoteSession=" stringByAppendingString:token] name:@"DylixRemoteSession"]:nil;
   if(![device[@"permission"] isEqual:@"webdav"]||![device[@"projectID"] isEqual:s.davProject]){complete(@{@"status":@401,@"type":@"text/plain",@"body":NSData.data,@"headers":@{@"WWW-Authenticate":@"Basic realm=\"Dylix WebDAV\", charset=\"UTF-8\""}});return;}
   if(![s.snapshot[@"protectedDataAvailable"] boolValue]){complete(Error(423,@"device_locked",@"请先解锁手机"));return;}NSString *root=s.davRoot,*origin=s.davServer.origin;BOOL readOnly=s.davReadOnly||[device[@"readOnly"] boolValue];[s publish];
   dispatch_async(TMCGitService.queue,^{__block BOOL valid=NO;dispatch_sync(s.queue,^{valid=[s.davState isEqual:@"running"]&&[s.davProject isEqual:device[@"projectID"]]&&[s.access authenticateCookie:[@"DylixRemoteSession=" stringByAppendingString:token] name:@"DylixRemoteSession"]!=nil;});if(!valid){complete(Error(403,@"revoked",@"授权已撤销"));return;}complete([s.dav respond:request root:root readOnly:readOnly origin:origin]);});
  };
  _server.handler=^NSDictionary *(NSDictionary *r){return [weak handle:r]?:Error(503,@"stopped",@"服务已停止");};
  _server.stateChanged=^(NSString *state){DXRemoteService *s=weak;if(!s)return;s.state=state;if([state isEqual:@"failed"]){s.failure=@"监听失败，请检查端口占用及本地网络权限";[s.access resetEphemeral];}[s.access record:[@"server_" stringByAppendingString:state]];[s publish];};
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground) name:UIApplicationDidBecomeActiveNotification object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(protectedChanged:) name:UIApplicationProtectedDataWillBecomeUnavailable object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(protectedChanged:) name:UIApplicationProtectedDataDidBecomeAvailable object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(audioChanged:) name:@"TFAIAudioBackgroundStateChanged" object:nil];
  _timer=[NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(refresh) userInfo:nil repeats:YES];[self refresh];
 }return self;
}
- (void)endBackgroundGrace{self.backgroundGeneration++;UIBackgroundTaskIdentifier task=self.backgroundTask;self.backgroundTask=UIBackgroundTaskInvalid;if(task!=UIBackgroundTaskInvalid)[UIApplication.sharedApplication endBackgroundTask:task];}
- (void)protectedChanged:(NSNotification *)notification{
 // WillBecomeUnavailable can arrive before UIApplication flips its property.
 self.protectedDataLocked=[notification.name isEqual:UIApplicationProtectedDataWillBecomeUnavailable];[self refresh];
}
- (void)audioChanged:(NSNotification *)notification{
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self audioChanged:notification];});return;}
 if(UIApplication.sharedApplication.applicationState==UIApplicationStateActive)return;
 BOOL playing=TFAIAudioBackgroundPlaying(),granted=self.backgroundTask!=UIBackgroundTaskInvalid;
 dispatch_async(self.queue,^{
  if(!self.wantsHTTP&&!self.wantsDAV)return;
  if(playing){NSError *error=nil;if([self.state isEqual:@"suspended"]&&self.wantsHTTP){self.state=@"starting";if(![self.server startAddress:self.address port:self.port error:&error])self.state=@"failed";}if([self.davState isEqual:@"suspended"]&&self.wantsDAV){self.davState=@"starting";if(![self.davServer startAddress:self.address port:self.davPort error:&error])self.davState=@"failed";}self.lifecycle=@"background_audio";}
  else if([self.lifecycle isEqual:@"background_audio"]){
   if(granted)self.lifecycle=@"background_grace";
   else{[self.server stop];[self.davServer stop];if(self.wantsHTTP)self.state=@"suspended";if(self.wantsDAV)self.davState=@"suspended";self.lifecycle=@"suspended";[self.access record:@"background_audio_ended_suspended"];}
  }[self publish];
 });
}
- (void)backgroundExpired{
 [self endBackgroundGrace];BOOL audio=TFAIAudioBackgroundPlaying();dispatch_async(self.queue,^{if(audio){self.lifecycle=@"background_audio";[self.access record:@"background_grace_ended_audio_active"];}else{[self.server stop];[self.davServer stop];if(self.wantsHTTP)self.state=@"suspended";if(self.wantsDAV)self.davState=@"suspended";self.lifecycle=@"suspended";[self.access record:@"background_suspended"];}[self publish];});
}
- (void)background{
 if(![@[@"running",@"starting",@"suspended"] containsObject:self.localState[@"state"]]&&![@[@"running",@"starting",@"suspended"] containsObject:self.localState[@"davState"]])return;
 TFAIAudioBackgroundAcquire(@"remote");
 [self endBackgroundGrace];NSUInteger generation=++self.backgroundGeneration;__weak typeof(self) weak=self;
 self.backgroundTask=[UIApplication.sharedApplication beginBackgroundTaskWithName:@"Dylix Remote transfer" expirationHandler:^{dispatch_async(dispatch_get_main_queue(),^{DXRemoteService *s=weak;if(!s||generation!=s.backgroundGeneration)return;[s backgroundExpired];});}];
 BOOL granted=self.backgroundTask!=UIBackgroundTaskInvalid,audio=TFAIAudioBackgroundPlaying();dispatch_async(self.queue,^{self.lifecycle=audio?@"background_audio":(granted?@"background_grace":@"background_system");[self.access record:@"entered_background"];[self publish];});[self refresh];
}
- (void)foreground{
 TFAIAudioBackgroundRelease(@"remote");[self endBackgroundGrace];[self refresh];
 dispatch_async(self.queue,^{self.lifecycle=@"foreground";NSError *error=nil;
  if([self.state isEqual:@"suspended"]&&self.wantsHTTP){self.state=@"starting";if(![self.server startAddress:self.address port:self.port error:&error])self.state=@"failed";}
  if([self.davState isEqual:@"suspended"]&&self.wantsDAV){self.davState=@"starting";if(![self.davServer startAddress:self.address port:self.davPort error:&error])self.davState=@"failed";}
  if(error)self.failure=error.localizedDescription;[self.access record:@"returned_foreground"];[self publish];
 });
}
- (void)refresh{
 NSAssert(NSThread.isMainThread,@"Remote bridge must run on main");
 NSDictionary *info=NSBundle.mainBundle.infoDictionary;
 NSMutableArray *sdks=[NSMutableArray new];for(NSString *stem in @[@"SDK",@"SDK26"]){NSDictionary *manifest=[NSDictionary dictionaryWithContentsOfFile:[NSBundle.mainBundle pathForResource:[stem stringByAppendingString:@"Resource"] ofType:@"plist"]];if([manifest[@"version"] isKindOfClass:NSString.class])[sdks addObject:manifest[@"version"]];}
 NSDictionary *settings=TMCSDKBuildSettings(@{},NSUserDefaults.standardUserDefaults,nil);
 NSDictionary *snapshot=@{@"deviceName":UIDevice.currentDevice.name?:@"Dylix",@"system":UIDevice.currentDevice.systemName,@"systemVersion":UIDevice.currentDevice.systemVersion,@"version":info[@"CFBundleShortVersionString"]?:@"dev",@"build":info[@"CFBundleVersion"]?:@"dev",@"theme":@([NSUserDefaults.standardUserDefaults integerForKey:@"StudioTheme"]),@"sdk":sdks.copy,@"defaultSDK":settings[@"sdkVersion"]?:@"配置无效",@"minimumOS":settings[@"deploymentTarget"]?:@"配置无效",@"buildRunning":@(TMCBuildIsRunning()),@"foreground":@(UIApplication.sharedApplication.applicationState==UIApplicationStateActive),@"protectedDataAvailable":@(!self.protectedDataLocked&&UIApplication.sharedApplication.isProtectedDataAvailable),@"capabilities":@[@"overview:read",@"workspace"],@"phase":@5};
 NSString *address=WiFiAddress();
#if TARGET_OS_SIMULATOR
 if([NSProcessInfo.processInfo.arguments containsObject:@"--remote-test"])address=@"127.0.0.1";
#endif
 dispatch_async(self.queue,^{self.snapshot=snapshot;
  if(([@[@"running",@"starting",@"suspended"] containsObject:self.state]||[@[@"running",@"starting",@"suspended"] containsObject:self.davState])&&![self.address isEqual:address]){[self.server stop];[self.davServer stop];self.davState=@"stopped";self.davCredential=nil;[self.workspace stop];[self.access resetEphemeral];self.state=@"stopped";self.wantsHTTP=NO;self.wantsDAV=NO;self.failure=@"网络地址已变化，请重新开启服务";[self.access record:@"network_changed"];}
  if(![self.state isEqual:@"running"]&&![self.state isEqual:@"starting"])self.address=address;
  [self publish];
 });
}
- (void)publish{
 NSArray *devices=self.access.devices;NSUInteger online=0;for(NSDictionary *device in devices)if([device[@"online"] boolValue])online++;
 NSDictionary *state=@{@"state":self.state?:@"stopped",@"address":self.address?:@"",@"url":[self.state isEqual:@"running"]?(self.server.origin?:@""):@"",@"port":@(self.port),@"enabled":@(self.wantsHTTP||self.wantsDAV),@"httpEnabled":@(self.wantsHTTP),@"davEnabled":@(self.wantsDAV),@"tls":@NO,@"lifecycle":self.lifecycle?:@"foreground",@"codeMode":self.access.fixedCode?@"fixed":@"random",@"code":self.access.pairingCode?:@"",@"codeExpiry":@(self.access.codeExpiry),@"pending":self.access.pending,@"devices":devices,@"online":@(online),@"logs":self.access.events,@"error":self.failure?:@"",@"webdav":@([self.davState isEqual:@"running"]),@"davState":self.davState?:@"stopped",@"davPort":@(self.davPort),@"davURL":[self.davState isEqual:@"running"]?self.davServer.origin?:@"":@"",@"davProject":self.davProject?:@"",@"davCredential":self.davCredential?:@{},@"davError":self.davError?:@""};
 NSMutableDictionary *published=[state mutableCopy];published[@"networkMode"]=DXRemoteSelectedMode([NSUserDefaults.standardUserDefaults stringForKey:@"DylixRemoteNetworkMode"]);
 dispatch_async(dispatch_get_main_queue(),^{self.localState=published;if(![@[@"running",@"starting",@"suspended"] containsObject:state[@"state"]]&&![@[@"running",@"starting",@"suspended"] containsObject:state[@"davState"]])TFAIAudioBackgroundRelease(@"remote");TFScreenAwakeSet(@"remote",[@[@"running",@"starting"] containsObject:state[@"state"]]||[@[@"running",@"starting"] containsObject:state[@"davState"]]);});
}
- (void)start{
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;NSString *address=WiFiAddress();
#if TARGET_OS_SIMULATOR
 if([NSProcessInfo.processInfo.arguments containsObject:@"--remote-test"])address=@"127.0.0.1";
#endif
 dispatch_async(self.queue,^{if([@[@"running",@"starting"] containsObject:self.state])return;
  self.failure=nil;if(!address){self.state=@"failed";self.failure=@"请连接提供私有 IPv4 的 Wi-Fi，或切换到仅本机模式";[self publish];return;}
  self.address=address;NSError *error=nil;self.wantsHTTP=YES;self.state=@"starting";NSString *fixed=DXRemoteGetSecret(self.fixedAccount);if(fixed.length)[self.access setFixedCode:fixed error:nil];else[self.access rotateCode];
  if(![self.server startAddress:address port:self.port error:&error]){self.state=@"failed";self.failure=error.localizedDescription;[self.access resetEphemeral];}[self publish];
 });
}
- (void)stop{[self endBackgroundGrace];dispatch_async(self.queue,^{self.wantsHTTP=NO;self.wantsDAV=NO;[self.davServer stop];self.davState=@"stopped";self.davCredential=nil;[self.workspace stop];[self.server stop];[self.access resetEphemeral];self.state=@"stopped";[self.access record:@"server_stopped"];[self publish];});}
- (void)setNetworkMode:(NSString *)mode{
 if(![@[@"wifi",@"local"] containsObject:mode])return;
 dispatch_async(self.queue,^{if(self.wantsHTTP||self.wantsDAV){self.failure=@"请先关闭 HTTP 与 WebDAV，再切换连接方式";[self publish];return;}[NSUserDefaults.standardUserDefaults setObject:mode forKey:@"DylixRemoteNetworkMode"];self.failure=nil;dispatch_async(dispatch_get_main_queue(),^{[self refresh];});});
}
- (void)setPort:(NSUInteger)port{if(port<1024||port>65535)return;dispatch_async(self.queue,^{if([@[@"running",@"starting"] containsObject:self.state])return;self->_port=port;
#if TARGET_OS_SIMULATOR
 if(![NSProcessInfo.processInfo.arguments containsObject:@"--remote-regression"])
#endif
 [NSUserDefaults.standardUserDefaults setInteger:port forKey:@"DylixRemotePort"];[self publish];});}
- (void)setWebDAVPort:(NSUInteger)port{if(port<1024||port>65535)return;dispatch_async(self.queue,^{if([@[@"running",@"starting"] containsObject:self.davState])return;self.davPort=port;[NSUserDefaults.standardUserDefaults setInteger:port forKey:@"DylixRemoteDAVPort"];[self publish];});}
- (void)stopWebDAV{dispatch_async(self.queue,^{self.wantsDAV=NO;if(self.davCredential[@"id"])[self.access revoke:self.davCredential[@"id"] error:nil];[self.davServer stop];self.davState=@"stopped";self.davCredential=nil;[self.access record:@"webdav_stopped"];[self publish];});}
- (void)startWebDAVProject:(NSString *)project readOnly:(BOOL)readOnly{
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;NSString *root=nil;for(NSDictionary *p in TFAIInternalProjects())if([p[@"id"] isEqual:project])root=p[@"root"];
 NSString *address=WiFiAddress();
#if TARGET_OS_SIMULATOR
 if([NSProcessInfo.processInfo.arguments containsObject:@"--remote-test"])address=@"127.0.0.1";
#endif
 dispatch_async(self.queue,^{if(!root||!address){self.davError=@"请选择存在的内部项目；局域网模式需连接 Wi-Fi，本机模式无需 Wi-Fi";[self publish];return;}[self.davServer stop];self.address=address;self.davProject=project;self.davRoot=root;self.davReadOnly=readOnly;self.davError=nil;
 NSError *error=nil;if(self.davCredential[@"id"])[self.access revoke:self.davCredential[@"id"] error:nil];self.wantsDAV=YES;self.davCredential=[self.access issueDAV:project readOnly:readOnly error:&error];if(!self.davCredential){self.davState=@"failed";self.davError=error.localizedDescription?:@"生成 WebDAV 授权失败";[self publish];return;}
 self.davState=@"starting";if(![self.davServer startAddress:address port:self.davPort error:&error]){self.davState=@"failed";self.davError=error.localizedDescription;}[self publish];});
}
- (void)rotateCode{dispatch_async(self.queue,^{NSError *e=nil;if(!DXRemoteSetSecret(self.fixedAccount,nil,&e))self.failure=e.localizedDescription;else if([self.state isEqual:@"running"]){self.failure=nil;[self.access rotateCode];}[self publish];});}
- (void)setFixedCode:(NSString *)code{dispatch_async(self.queue,^{if([self.state isEqual:@"running"]){NSError *e=nil;BOOL valid=code.length>=6&&code.length<=12&&[code rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"].invertedSet].location==NSNotFound;if(!valid)self.failure=@"请输入 6–12 位数字";else if(!DXRemoteSetSecret(self.fixedAccount,code,&e))self.failure=e.localizedDescription;else{[self.access setFixedCode:code error:nil];self.failure=nil;}[self publish];}});}
- (void)approve:(NSString *)identifier accepted:(BOOL)accepted{
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;dispatch_async(self.queue,^{NSError *error=nil;if(![self.access approve:identifier accepted:accepted error:&error])self.failure=error.localizedDescription?:@"配对已过期，请重新申请";[self publish];});
}
- (void)revoke:(NSString *)identifier{dispatch_async(self.queue,^{NSError *error=nil;if(![self.access revoke:identifier error:&error])self.failure=error.localizedDescription?:@"撤权保存失败，请停止服务后重试";else[self.workspace revoke:identifier];[self publish];});}
- (NSDictionary *)handle:(NSDictionary *)request{
 NSString *path=request[@"path"],*method=request[@"method"];NSDictionary *headers=request[@"headers"];
 NSString *origin=self.server.origin;
 if(![self.state isEqual:@"running"])return Error(503,@"stopped",@"服务已暂停或停止");
 if(![self.snapshot[@"protectedDataAvailable"] boolValue]&&[path hasPrefix:@"/api/v1/"]&&![path isEqual:@"/api/v1/status"])return Error(423,@"device_locked",@"设备受保护数据暂不可用，请解锁手机后重试");
 // Fixed allowlist: URL input is never appended to an app document path.
 NSDictionary *assets=@{@"/terminal/xterm.js":@[@"xterm.js",@"text/javascript; charset=utf-8",@"Terminal"],@"/terminal/addon-fit.js":@[@"addon-fit.js",@"text/javascript; charset=utf-8",@"Terminal"],@"/terminal/xterm.css":@[@"xterm.css",@"text/css; charset=utf-8",@"Terminal"],@"/":@[@"index.html",@"text/html; charset=utf-8"],@"/app-icon.png":@[@"app-icon.png",@"image/png"],@"/remote.css":@[@"remote.css",@"text/css; charset=utf-8"],@"/highlight.js":@[@"highlight.js",@"text/javascript; charset=utf-8"],@"/remote.js":@[@"remote.js",@"text/javascript; charset=utf-8"]};
 if(assets[path]){
  if(![@[@"GET",@"HEAD"] containsObject:method])return Error(405,@"method_not_allowed",@"静态资源仅支持 GET / HEAD");
  NSArray *asset=assets[path];NSData *data=[NSData dataWithContentsOfFile:[[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:asset.count>2?asset[2]:@"RemoteWeb"] stringByAppendingPathComponent:asset[0]]];
  return data?@{@"status":@200,@"type":asset[1],@"body":data}:Error(503,@"missing_resource",@"工作台资源缺失");
 }
 if([self.assetPaths containsObject:path]&&[path hasPrefix:@"/monaco/"]&&[@[@"GET",@"HEAD"] containsObject:method]){
  NSString *relative=[path substringFromIndex:1],*ext=relative.pathExtension.lowercaseString;NSDictionary *types=@{@"js":@"text/javascript",@"css":@"text/css",@"json":@"application/json",@"ttf":@"font/ttf",@"svg":@"image/svg+xml"};NSString *file=[[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"RemoteWeb"] stringByAppendingPathComponent:relative];BOOL gzip=NO;for(NSString *encoding in [headers[@"accept-encoding"] componentsSeparatedByString:@","]){NSString *value=[encoding stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if([value isEqual:@"gzip"])gzip=YES;}NSData *compressed=gzip?[NSData dataWithContentsOfFile:[file stringByAppendingString:@".gz"]]:nil;NSData *bytes=compressed?:[NSData dataWithContentsOfFile:file];if(!bytes)return Error(503,@"missing_resource",@"编辑器资源缺失");return @{@"status":@200,@"type":types[ext]?:@"application/octet-stream",@"body":bytes,@"headers":compressed?@{@"Content-Encoding":@"gzip",@"Vary":@"Accept-Encoding"}:@{@"Vary":@"Accept-Encoding"}};
 }
 if([path isEqual:@"/health"]&&[method isEqual:@"GET"])return DXRemoteResponse(200,@{@"schema":@1,@"data":@{@"service":@"Dylix Remote",@"state":self.state}});
 if([path isEqual:@"/api/v1/pair"]&&[method isEqual:@"POST"]){
  if(![headers[@"origin"] isEqual:origin])return Error(403,@"origin_required",@"配对需要同源请求");
  if(![[headers[@"content-type"] lowercaseString] hasPrefix:@"application/json"])return Error(415,@"json_required",@"请发送 JSON");
  id body=[NSJSONSerialization JSONObjectWithData:request[@"body"] options:0 error:nil];if(![body isKindOfClass:NSDictionary.class])return Error(400,@"invalid_json",@"JSON 应为对象");
  NSDictionary *result=[self.access beginPair:body peer:request[@"peer"]];[self publish];NSMutableDictionary *response=[DXRemoteResponse([result[@"status"] integerValue],@{ @"schema":@1,@"data":result[@"data"]?:@{},@"error":result[@"error"]?:NSNull.null}) mutableCopy];if(result[@"token"]){response[@"headers"]=@{ @"Set-Cookie":[NSString stringWithFormat:@"%@=%@; HttpOnly; SameSite=Strict; Path=/; Max-Age=2592000",self.cookieName,result[@"token"]]};}return response;
 }
 if([path isEqual:@"/api/v1/pair/result"]&&[method isEqual:@"POST"]){
  if(![headers[@"origin"] isEqual:origin])return Error(403,@"origin_required",@"配对需要同源请求");
  id body=[NSJSONSerialization JSONObjectWithData:request[@"body"] options:0 error:nil];if(![body isKindOfClass:NSDictionary.class]||![body[@"id"] isKindOfClass:NSString.class]||![body[@"secret"] isKindOfClass:NSString.class])return Error(400,@"invalid_pair",@"配对参数有误");
  NSDictionary *result=[self.access claimPair:body[@"id"] secret:body[@"secret"]];NSMutableDictionary *response=[DXRemoteResponse([result[@"status"] integerValue],@{@"schema":@1,@"data":result[@"data"]?:@{},@"error":result[@"error"]?:NSNull.null}) mutableCopy];
  if(result[@"token"]){response[@"headers"]=@{@"Set-Cookie":[NSString stringWithFormat:@"%@=%@; HttpOnly; SameSite=Strict; Path=/; Max-Age=2592000",self.cookieName,result[@"token"]]};}[self publish];return response;
 }
 NSDictionary *device=[self.access authenticateCookie:headers[@"cookie"]?:@"" name:self.cookieName];if([device[@"permission"] isEqual:@"webdav"])device=nil;if(!device)return Error(401,@"authentication_required",@"请先在手机上配对此浏览器");
 if(![@[@"GET",@"HEAD"] containsObject:method]&&(![headers[@"origin"] isEqual:origin]||![headers[@"x-dylix-csrf"] isEqual:device[@"csrf"]]))return Error(403,@"csrf_rejected",@"请求确认信息已过期，请刷新");
 if([path isEqual:@"/api/v1/flex/next"]&&[method isEqual:@"GET"]){
  if(![device[@"permission"] isEqual:@"workspace"])return Error(403,@"workspace_required",@"FLEX 实时连接需要工作区授权");
  if(![self.snapshot[@"protectedDataAvailable"] boolValue])return Error(423,@"device_locked",@"设备已锁定");
  return DXRemoteResponse(200,@{@"schema":@1,@"data":[DXFlexBridge.shared nextForDevice:device[@"id"]]});
 }
 if([path isEqual:@"/api/v1/flex/reply"]&&[method isEqual:@"POST"]){
  if(![device[@"permission"] isEqual:@"workspace"])return Error(403,@"workspace_required",@"FLEX 实时连接需要工作区授权");
  if(![[headers[@"content-type"] lowercaseString] hasPrefix:@"application/json"])return Error(415,@"json_required",@"请发送 JSON");
  id body=[NSJSONSerialization JSONObjectWithData:request[@"body"] options:0 error:nil];NSError *failure=nil;
  if(![body isKindOfClass:NSDictionary.class]||![DXFlexBridge.shared reply:body device:device[@"id"] error:&failure])return Error(400,@"invalid_flex_reply",failure.localizedDescription?:@"FLEX 返回无效");
  return DXRemoteResponse(200,@{@"schema":@1,@"data":@{@"accepted":@YES}});
 }
 if([path hasPrefix:@"/api/v1/download/"]&&[@[@"GET",@"HEAD"] containsObject:method]){if(![device[@"permission"] isEqual:@"workspace"])return Error(403,@"workspace_required",@"请在手机重新配对并确认工作区权限");return [self.workspace download:[path substringFromIndex:17] device:device[@"id"]];}
 if([@[@"/api/v1/workspace",@"/api/v1/jobs/get",@"/api/v1/jobs/confirm",@"/api/v1/jobs/cancel"] containsObject:path]&&[method isEqual:@"POST"]){
  if(![device[@"permission"] isEqual:@"workspace"])return Error(403,@"workspace_required",@"当前仅有查看概况权限，请重新配对并在手机授权工作区");
  if(![[headers[@"content-type"] lowercaseString] hasPrefix:@"application/json"])return Error(415,@"json_required",@"请发送 JSON");
  id body=[NSJSONSerialization JSONObjectWithData:request[@"body"] options:0 error:nil];if(![body isKindOfClass:NSDictionary.class])return Error(400,@"invalid_json",@"JSON 应为对象");
  NSDictionary *result;if([path isEqual:@"/api/v1/workspace"])result=[self.workspace submit:body device:device[@"id"]];else{
   if(![body[@"id"] isKindOfClass:NSString.class])return Error(400,@"invalid_job",@"缺少任务 ID");
   if([path hasSuffix:@"/get"])result=[self.workspace job:body[@"id"] device:device[@"id"]];
   else if([path hasSuffix:@"/cancel"])result=[self.workspace cancel:body[@"id"] device:device[@"id"]];
   else if([body[@"nonce"] isKindOfClass:NSString.class]&&[body[@"accepted"] isKindOfClass:NSNumber.class])result=[self.workspace confirm:body[@"id"] nonce:body[@"nonce"] accepted:[body[@"accepted"] boolValue] device:device[@"id"]];else return Error(400,@"invalid_confirmation",@"确认参数不完整");
  }
  [self.access record:@"workspace_request"];return DXRemoteResponse(result[@"error"]?400:200,@{@"schema":@1,@"data":result});
 }
 if([path isEqual:@"/api/v1/status"]&&[method isEqual:@"GET"]){[self publish];return DXRemoteResponse(200,@{@"schema":@1,@"data":self.snapshot,@"session":device});}
 if([path isEqual:@"/api/v1/events"]&&[method isEqual:@"GET"])return DXRemoteResponse(200,@{@"schema":@1,@"data":self.access.events});
 if([path isEqual:@"/api/v1/logout"]&&[method isEqual:@"POST"]){
  NSError *error=nil;[self.workspace revoke:device[@"id"]];if(![self.access revoke:device[@"id"] error:&error])return Error(503,@"storage_error",@"退出保存失败，请在手机停止服务");[self publish];
  NSMutableDictionary *r=[DXRemoteResponse(200,@{@"schema":@1,@"data":@{@"loggedOut":@YES}}) mutableCopy];r[@"headers"]=@{@"Set-Cookie":[NSString stringWithFormat:@"%@=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0",self.cookieName]};return r;
 }
 return Error(404,@"not_available",@"该接口尚未开放");
}
@end

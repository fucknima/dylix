// All access to toolOperations and guest probes runs on the runtime queue.
- (BOOL)toolInstalledOnQueue:(NSString *)identifier session:(NSString *)session{
#if DYLIX_HAS_ISH
 NSString *mount=self.mounts[EnvironmentKey()];if(!mount)return NO;
 struct task *saved=current;current=DylixInit;struct fs_info *initial=DylixInit->fs;DylixInit->fs=fs_info_copy(initial);BOOL ok=SetRoot(mount)==0;
 NSDictionary *package=DXLinuxPackage(identifier);
 NSArray *paths=package?@[package[@"path"]]:[identifier isEqual:@"developer-tools"]?@[@"/usr/bin/python3",@"/usr/bin/node",@"/usr/bin/npm",@"/usr/bin/git",@"/usr/local/bin/ldid"]:@[@"/opt/dylix-reverse/usr/bin/radare2",@"/opt/dylix-reverse/lib/ld-musl-aarch64.so.1"];
 if(package&&ok){NSData *data=GuestRead(@"/lib/apk/db/installed",16*1024*1024,nil);NSString *database=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];NSString *record=[NSString stringWithFormat:@"\nP:%@\n",package[@"package"]];ok=[[@"\n" stringByAppendingString:database?:@""] containsString:record];}
 for(NSString *path in paths){struct statbuf st={0};if(generic_statat(AT_PWD,path.UTF8String,&st,true)<0||!S_ISREG(st.mode)||(st.mode&0111)==0)ok=NO;}
 fs_info_release(DylixInit->fs);DylixInit->fs=initial;current=saved;return ok;
#else
 return NO;
#endif
}
- (BOOL)packageOwnedOnQueue:(NSString *)identifier session:(NSString *)session{
#if DYLIX_HAS_ISH
 NSDictionary *p=DXLinuxPackage(identifier);NSString *mount=self.mounts[EnvironmentKey()];if(!p||!mount)return NO;
 struct task *saved=current;current=DylixInit;struct fs_info *initial=DylixInit->fs;DylixInit->fs=fs_info_copy(initial);BOOL ok=SetRoot(mount)==0;
 NSData *data=ok?GuestRead(@"/lib/apk/db/installed",16*1024*1024,nil):nil;NSString *database=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];ok=[[@"\n" stringByAppendingString:database?:@""] containsString:[NSString stringWithFormat:@"\nP:.dylix-item-%@\n",p[@"package"]]];
 fs_info_release(DylixInit->fs);DylixInit->fs=initial;current=saved;return ok;
#else
 return NO;
#endif
}
- (void)toolInventory:(NSString *)session completion:(void(^)(NSDictionary *))completion{
 dispatch_async(self.queue,^{NSError *error=nil;BOOL ready=[self prepare:session error:&error];NSMutableDictionary *result=[NSMutableDictionary new];
  NSMutableArray *identifiers=[NSMutableArray arrayWithArray:@[@"developer-tools",@"reverse-tools"]];for(NSDictionary *p in DXLinuxPackages())[identifiers addObject:p[@"id"]];
  for(NSString *identifier in identifiers){NSString *key=[ToolKey(session) stringByAppendingString:identifier];NSDictionary *operation=self.toolOperations[key];BOOL installed=ready&&[self toolInstalledOnQueue:identifier session:session];NSString *state=operation[@"state"];
   BOOL active=[@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:state];
   NSMutableDictionary *row=[(operation?:@{}) mutableCopy];row[@"installed"]=@(installed);if(DXLinuxPackage(identifier))row[@"managed"]=@([self packageOwnedOnQueue:identifier session:session]);row[@"state"]=active?state:[state isEqual:@"failed"]?state:installed?@"installed":@"notInstalled";row[@"cached"]=@([DXResourceStore verifiedPath:identifier error:nil]!=nil);if(error)row[@"error"]=error.localizedDescription;
   if(!DXLinuxPackage(identifier))row[@"download"]=[DXResourceStore.shared status:identifier];result[identifier]=row;
  }Main(^{completion(result);});
 });
}
- (void)observeToolProcess:(NSString *)processID identifier:(NSString *)identifier session:(NSString *)session removing:(BOOL)removing deadline:(NSTimeInterval)deadline{
 dispatch_async(self.queue,^{NSString *key=[ToolKey(session) stringByAppendingString:identifier];DylixISHJob *job=self.processJobs[processID];
  if(job&&!job.done&&NSProcessInfo.processInfo.systemUptime<deadline){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),self.queue,^{[self observeToolProcess:processID identifier:identifier session:session removing:removing deadline:deadline];});return;}
  BOOL package=DXLinuxPackage(identifier)!=nil;BOOL installed=[self toolInstalledOnQueue:identifier session:session],ok=job&&job.done&&!job.cancelled&&!job.timedOut&&job.exitStatus==0&&(removing?(package||!installed):installed);
  if(removing&&!ok&&installed&&!package)[NSUserDefaults.standardUserDefaults setBool:YES forKey:[identifier isEqual:@"developer-tools"]?@"DylixISHDeveloperToolsAutoload":@"DylixISHReverseToolsAutoload"];
  NSString *tail=job?[[NSString alloc]initWithData:job.tail encoding:NSUTF8StringEncoding]:nil;
  if(package&&ok){NSMutableArray *selected=[[NSUserDefaults.standardUserDefaults arrayForKey:@"DylixISHSelectedPackages"] mutableCopy]?:[NSMutableArray new];if(removing)[selected removeObject:identifier];else if(![selected containsObject:identifier])[selected addObject:identifier];[NSUserDefaults.standardUserDefaults setObject:selected forKey:@"DylixISHSelectedPackages"];}
  self.toolOperations[key]=@{@"state":ok?(removing?@"notInstalled":@"installed"):@"failed",@"process_id":processID,@"error":ok?@"":([tail length]? [tail substringFromIndex:tail.length>800?tail.length-800:0]:@"安装/卸载未完成，请查看任务输出或重试。")};
  [self autoInstallForSession:session];
 });
}
- (void)installToolResource:(NSString *)identifier session:(NSString *)session completion:(void(^)(NSDictionary *,NSError *))completion{
 dispatch_async(self.queue,^{
  if(!self.toolOperations)self.toolOperations=[NSMutableDictionary new];NSString *key=[ToolKey(session) stringByAppendingString:identifier];NSDictionary *old=self.toolOperations[key];
  if([@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:old[@"state"]]){Main(^{completion(old,nil);});return;}
  for(NSString *other in self.toolOperations)if([other hasPrefix:ToolKey(session)]&&[@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:self.toolOperations[other][@"state"]]){Main(^{completion(nil,ISHError(@"共享环境有安装任务，请完成后再操作。"));});return;}
  NSError *error=nil;if(![self prepare:session error:&error]){Main(^{completion(nil,error);});return;}
  if([self toolInstalledOnQueue:identifier session:session]){[NSUserDefaults.standardUserDefaults setBool:YES forKey:[identifier isEqual:@"developer-tools"]?@"DylixISHDeveloperToolsAutoload":@"DylixISHReverseToolsAutoload"];[( [identifier isEqual:@"developer-tools"]?self.autoDeveloperSessions:self.autoReverseSessions) addObject:ToolKey(session)];self.toolOperations[key]=@{@"state":@"installed",@"installed":@YES};Main(^{completion(@{@"installed":@YES,@"state":@"installed"},nil);});return;}
  self.toolOperations[key]=@{@"state":@"downloading"};
  void(^downloaded)(NSString *,NSError *)=^(NSString *path,NSError *failure){
   if(!path){dispatch_async(self.queue,^{self.toolOperations[key]=@{@"state":@"failed",@"error":failure.localizedDescription?:@"工具下载失败"};[( [identifier isEqual:@"developer-tools"]?self.autoDeveloperSessions:self.autoReverseSessions) removeObject:ToolKey(session)];});completion(nil,failure);return;}
   dispatch_async(self.queue,^{self.toolOperations[key]=@{@"state":@"installing"};});
   void(^started)(NSDictionary *,NSError *)=^(NSDictionary *r,NSError *e){if(!e)[self retainToolProcess:r[@"process_id"]];dispatch_async(self.queue,^{
    self.toolOperations[key]=e?@{@"state":@"failed",@"error":e.localizedDescription}:@{@"state":@"installing",@"process_id":r[@"process_id"]?:@""};
    if(!e&&[r[@"process_id"] length])[self observeToolProcess:r[@"process_id"] identifier:identifier session:session removing:NO deadline:NSProcessInfo.processInfo.systemUptime+620];
   });completion(r,e);};
   if([identifier isEqual:@"developer-tools"])[self installDeveloperToolsArchive:path session:session completion:started];else [self installReverseToolsArchive:path session:session completion:started];
  };
  NSString *legacy=[NSBundle.mainBundle pathForResource:identifier ofType:@"tar" inDirectory:@"iSH"];
  Main(^{if(legacy)downloaded(legacy,nil);else[DXResourceStore.shared fetch:identifier completion:downloaded];});
 });
}
- (void)installDeveloperTools:(NSString *)session completion:(void(^)(NSDictionary *,NSError *))completion{[self installToolResource:@"developer-tools" session:session completion:completion];}
- (void)installReverseTools:(NSString *)session completion:(void(^)(NSDictionary *,NSError *))completion{[self installToolResource:@"reverse-tools" session:session completion:completion];}
- (void)uninstallTool:(NSString *)identifier session:(NSString *)session completion:(void(^)(NSDictionary *,NSError *))completion{
 if(DXLinuxPackage(identifier)){[self changePackage:identifier removing:YES session:session completion:completion];return;}
 dispatch_async(self.queue,^{if(![@[@"developer-tools",@"reverse-tools"] containsObject:identifier]){Main(^{completion(nil,ISHError(@"工具标识无效"));});return;}
  NSString *key=[ToolKey(session) stringByAppendingString:identifier];if([@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:self.toolOperations[key][@"state"]]){Main(^{completion(nil,ISHError(@"该工具正在处理，请稍后再试。"));});return;}
  for(NSString *other in self.toolOperations)if([other hasPrefix:ToolKey(session)]&&[@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:self.toolOperations[other][@"state"]]){Main(^{completion(nil,ISHError(@"共享环境有安装任务，请完成后再操作。"));});return;}
  BOOL developer=[identifier isEqual:@"developer-tools"];NSString *preference=developer?@"DylixISHDeveloperToolsAutoload":@"DylixISHReverseToolsAutoload";
  [NSUserDefaults.standardUserDefaults setBool:NO forKey:preference];[(developer?self.autoDeveloperSessions:self.autoReverseSessions) removeObject:ToolKey(session)];self.toolOperations[key]=@{@"state":@"uninstalling"};
  NSString *command=developer?@"set -e; if apk info -e .dylix-developer-tools >/dev/null 2>&1; then apk del .dylix-developer-tools; else printf 'Legacy tool installation has no ownership record; refusing to remove user packages. Rebuild this Linux environment to reclaim it.\\n'; exit 2; fi; rm -f /usr/local/bin/ldid /usr/local/bin/lipo /usr/local/bin/otool /usr/local/bin/nm; rm -rf /opt/dylix-tools":@"set -e; rm -rf /opt/dylix-reverse /opt/dylix-reverse-packages";
  [self performProcess:@"start" arguments:@{@"command":command,@"timeout":@300} session:session completion:^(NSDictionary *r,NSError *e){if(!e)[self retainToolProcess:r[@"process_id"]];dispatch_async(self.queue,^{self.toolOperations[key]=e?@{@"state":@"failed",@"error":e.localizedDescription}:@{@"state":@"uninstalling",@"process_id":r[@"process_id"]?:@""};if(!e)[self observeToolProcess:r[@"process_id"] identifier:identifier session:session removing:YES deadline:NSProcessInfo.processInfo.systemUptime+320];});if(e)dispatch_async(self.queue,^{[self autoInstallPackages:session];});completion(r,e);}];
 });
}

- (void)installPackage:(NSString *)identifier session:(NSString *)session completion:(void(^)(NSDictionary *,NSError *))completion{[self changePackage:identifier removing:NO session:session completion:completion];}
- (void)autoInstallPackages:(NSString *)session{
 // One APK transaction at a time; never spawn all selected installs together.
 NSString *key=ToolKey(session);
 for(NSString *operation in self.toolOperations)if([operation hasPrefix:key]&&[@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:self.toolOperations[operation][@"state"]])return;
 for(NSString *identifier in [NSUserDefaults.standardUserDefaults arrayForKey:@"DylixISHSelectedPackages"])if(DXLinuxPackage(identifier)&&!self.toolOperations[[key stringByAppendingString:identifier]]&&![self packageOwnedOnQueue:identifier session:session]){[self changePackage:identifier removing:NO session:session completion:^(NSDictionary *r,NSError *e){}];return;}
}
- (void)changePackage:(NSString *)identifier removing:(BOOL)removing session:(NSString *)session completion:(void(^)(NSDictionary *,NSError *))completion{
 NSString *command=DXLinuxPackageCommand(identifier,removing);if(!command){Main(^{completion(nil,ISHError(@"未知的工具标识"));});return;}
 dispatch_async(self.queue,^{
 NSString *key=[ToolKey(session) stringByAppendingString:identifier];
 if([@[@"installing",@"uninstalling"] containsObject:self.toolOperations[key][@"state"]]){Main(^{completion(self.toolOperations[key],nil);});return;}
 for(NSString *other in self.toolOperations)if([other hasPrefix:ToolKey(session)]&&[@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:self.toolOperations[other][@"state"]]){Main(^{completion(nil,ISHError(@"当前环境有安装任务，请完成后再安装下一项。"));});return;}
 self.toolOperations[key]=@{@"state":removing?@"uninstalling":@"installing"};
 [self performProcess:@"start" arguments:@{@"command":command,@"timeout":@600} session:session completion:^(NSDictionary *r,NSError *e){if(!e)[self retainToolProcess:r[@"process_id"]];dispatch_async(self.queue,^{self.toolOperations[key]=e?@{@"state":@"failed",@"error":e.localizedDescription}:@{@"state":removing?@"uninstalling":@"installing",@"process_id":r[@"process_id"]?:@""};if(!e&&[r[@"process_id"] length])[self observeToolProcess:r[@"process_id"] identifier:identifier session:session removing:removing deadline:NSProcessInfo.processInfo.systemUptime+620];});completion(r,e);}];
 });
}

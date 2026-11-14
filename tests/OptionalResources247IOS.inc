- (void)waitTool247:(NSString *)identifier installed:(BOOL)installed completion:(void(^)(void))completion deadline:(NSTimeInterval)deadline{
 [TFAIISHRuntime.shared toolInventory:@"resource247" completion:^(NSDictionary *inventory){NSDictionary *row=inventory[identifier];NSString *state=row[@"state"];BOOL active=[@[@"installing",@"uninstalling",@"downloading",@"checking"] containsObject:state];
  if(!active&&[row[@"installed"] boolValue]==installed&&![state isEqual:@"failed"]){[self record:[NSString stringWithFormat:@"%@_%@",identifier,installed?@"installed":@"uninstalled"] passed:YES detail:row];completion();return;}
  if([state isEqual:@"failed"]||NSProcessInfo.processInfo.systemUptime>deadline){[self record:identifier passed:NO detail:row];[self record:@"resources247_finished" passed:NO detail:nil];return;}
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self waitTool247:identifier installed:installed completion:completion deadline:deadline];});
 }];
}
- (void)resources247{
 dispatch_group_t faults=dispatch_group_create();
 for(NSString *identifier in @[@"bad-hash",@"missing-resource",@"oversized-resource"]){dispatch_group_enter(faults);[DXResourceStore.shared fetch:identifier completion:^(NSString *path,NSError *error){[self record:[@"download_rejects_" stringByAppendingString:identifier] passed:!path&&error&&![DXResourceStore verifiedPath:identifier error:nil] detail:error.localizedDescription];dispatch_group_leave(faults);}];}
 dispatch_group_notify(faults,dispatch_get_main_queue(),^{[self beginResources247];});
}
- (void)beginResources247{
 [self record:@"optional_archives_not_bundled" passed:![NSBundle.mainBundle pathForResource:@"developer-tools" ofType:@"tar" inDirectory:@"iSH"]&&![NSBundle.mainBundle pathForResource:@"reverse-tools" ofType:@"tar" inDirectory:@"iSH"] detail:nil];
 self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:TFAIISHToolsController(@"resource247")];
 UITableViewController *page=(id)[(UINavigationController *)self.window.rootViewController topViewController];[page loadViewIfNeeded];
 [page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1]];
 [self record:@"sdk_cell_starts_install_in_place" passed:[[page valueForKey:@"sdkBusy"] boolValue] detail:nil];
 __block NSUInteger callbacks=0;void(^downloaded)(NSString *,NSError *)=^(NSString *path,NSError *error){[self record:@"https_sdk_download_verified" passed:path!=nil&&!error detail:error.localizedDescription];if(++callbacks!=2)return;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSError *e=nil;NSString *sdk=TMCPrepareSelectedSDK(NSBundle.mainBundle,NSTemporaryDirectory(),@"26.0",&e);BOOL good=sdk&&[NSFileManager.defaultManager fileExistsAtPath:[sdk stringByAppendingPathComponent:@"usr/include/stdio.h"]];dispatch_async(dispatch_get_main_queue(),^{[self record:@"downloaded_sdk_extracts_persistently" passed:good detail:e.localizedDescription];[self startDeveloper247];});});
 };
 [DXResourceStore.shared fetch:@"sdk26" completion:downloaded];[DXResourceStore.shared fetch:@"sdk26" completion:downloaded];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self proof237Screenshot:@"data247-tools"];});
}
- (void)startDeveloper247{
 [TFAIISHRuntime.shared installDeveloperTools:@"resource247" completion:^(NSDictionary *r,NSError *e){[self record:@"developer_install_process_started" passed:!e&&[r[@"process_id"] length]>0 detail:e.localizedDescription];[self waitTool247:@"developer-tools" installed:YES completion:^{
  [TFAIISHRuntime.shared installDeveloperTools:@"resource247" completion:^(NSDictionary *again,NSError *error){[self record:@"repeated_install_is_noop" passed:[again[@"installed"] boolValue]&&!again[@"process_id"]&&!error detail:again];
   [TFAIISHRuntime.shared installReverseTools:@"resource247" completion:^(NSDictionary *rr,NSError *re){[self record:@"reverse_install_process_started" passed:!re&&[rr[@"process_id"] length]>0 detail:re.localizedDescription];[self waitTool247:@"reverse-tools" installed:YES completion:^{
    [TFAIISHRuntime.shared execute:@"python3 --version; node --version; git --version; command -v ldid; R2_PREFIX=/opt/dylix-reverse/usr /opt/dylix-reverse/lib/ld-musl-aarch64.so.1 --library-path /opt/dylix-reverse/lib:/opt/dylix-reverse/usr/lib /opt/dylix-reverse/usr/bin/radare2 -v" session:@"resource247" timeout:30 output:nil completion:^(NSDictionary *result,NSError *err){NSString *output=result[@"output"];[self record:@"real_downloaded_commands_execute" passed:!err&&[output containsString:@"Python"]&&[output containsString:@"radare2"]&&[output containsString:@"/usr/local/bin/ldid"] detail:result?:err.localizedDescription];
     UINavigationController *nav=(id)self.window.rootViewController;[self record:@"install_does_not_push_terminal" passed:nav.viewControllers.count==1 detail:nil];[self proof237Screenshot:@"data247-installed"];[self record:@"resources247_finished" passed:YES detail:nil];
    }];
   } deadline:NSProcessInfo.processInfo.systemUptime+600];}];
  }];
 } deadline:NSProcessInfo.processInfo.systemUptime+600];}];
}
- (void)persistResources247{
 self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:TFAIISHToolsController(@"resource247")];
 [TFAIISHRuntime.shared toolInventory:@"resource247" completion:^(NSDictionary *inventory){[self record:@"developer_persists_after_restart" passed:[inventory[@"developer-tools"][@"installed"] boolValue] detail:nil];[self record:@"reverse_persists_after_restart" passed:[inventory[@"reverse-tools"][@"installed"] boolValue] detail:nil];[self record:@"sdk_download_persists_after_restart" passed:[DXResourceStore verifiedPath:@"sdk26" error:nil]!=nil detail:nil];
  [TFAIISHRuntime.shared uninstallTool:@"reverse-tools" session:@"resource247" completion:^(NSDictionary *r,NSError *e){[self waitTool247:@"reverse-tools" installed:NO completion:^{
   [TFAIISHRuntime.shared uninstallTool:@"developer-tools" session:@"resource247" completion:^(NSDictionary *rr,NSError *ee){[self waitTool247:@"developer-tools" installed:NO completion:^{
    [self record:@"global_auto_install_disabled_on_uninstall" passed:![NSUserDefaults.standardUserDefaults boolForKey:@"DylixISHDeveloperToolsAutoload"]&&![NSUserDefaults.standardUserDefaults boolForKey:@"DylixISHReverseToolsAutoload"] detail:nil];
    NSError *failure=nil;BOOL removed=[DXResourceStore.shared remove:@"sdk26" error:&failure];[self record:@"sdk_download_removable" passed:removed&&[DXResourceStore verifiedPath:@"sdk26" error:nil]==nil detail:failure.localizedDescription];[self proof237Screenshot:@"data247-uninstalled"];[self record:@"resources247_finished" passed:YES detail:nil];
   } deadline:NSProcessInfo.processInfo.systemUptime+350];}];
  } deadline:NSProcessInfo.processInfo.systemUptime+350];}];
 }];
}

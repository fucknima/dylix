- (void)waitPackage253:(NSString *)identifier session:(NSString *)session done:(void(^)(NSDictionary *))done{
 [TFAIISHRuntime.shared toolInventory:session completion:^(NSDictionary *inventory){NSDictionary *row=inventory[identifier];if([@[@"installing",@"uninstalling",@"checking"] containsObject:row[@"state"]]){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self waitPackage253:identifier session:session done:done];});return;}done(row);}];
}
- (void)packages253{
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;[d setBool:NO forKey:@"DylixISHDeveloperToolsAutoload"];[d setBool:NO forKey:@"DylixISHReverseToolsAutoload"];[d removeObjectForKey:@"DylixISHSelectedPackages"];
 NSString *session=[@"packages253-" stringByAppendingString:NSUUID.UUID.UUIDString];
 [TFAIISHRuntime.shared toolInventory:session completion:^(NSDictionary *inventory){
 [self record:@"packages253_catalog" passed:inventory.count>=24 detail:@(inventory.count)];[self record:@"packages253_busybox_not_full_tar" passed:![inventory[@"apk:tar"][@"installed"] boolValue] detail:inventory[@"apk:tar"]];
 [TFAIISHRuntime.shared installPackage:@"apk:jq;touch /tmp/invalid" session:session completion:^(NSDictionary *r,NSError *e){[self record:@"packages253_unknown_id_rejected" passed:e&&!r detail:nil];}];
 [TFAIISHRuntime.shared installPackage:@"apk:jq" session:session completion:^(NSDictionary *r,NSError *e){
 [self record:@"packages253_start" passed:r&&!e detail:e.localizedDescription];if(e){[self record:@"packages253_finished" passed:NO detail:e.localizedDescription];return;}
 [self waitPackage253:@"apk:jq" session:session done:^(NSDictionary *row){BOOL installed=[row[@"installed"] boolValue]&&![row[@"state"] isEqual:@"failed"];[self record:@"packages253_installed" passed:installed detail:row];if(!installed){[self record:@"packages253_finished" passed:NO detail:row];return;}
 [self record:@"packages253_selection_persisted" passed:[[d arrayForKey:@"DylixISHSelectedPackages"] containsObject:@"apk:jq"] detail:nil];
 [TFAIISHRuntime.shared execute:@"printf '{\"n\":7}' | jq -r '.n'; apk info -e .dylix-item-jq" session:session timeout:20 output:nil completion:^(NSDictionary *out,NSError *e){[self record:@"packages253_command_works" passed:!e&&[out[@"exit_code"] intValue]==0&&[out[@"output"] containsString:@"7"] detail:out?:e.localizedDescription];
 NSString *second=[session stringByAppendingString:@"-new"];[TFAIISHRuntime.shared performProcess:@"start" arguments:@{@"command":@"true"} session:second completion:^(NSDictionary *r,NSError *e){
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{[self waitPackage253:@"apk:jq" session:second done:^(NSDictionary *row){[self record:@"packages253_new_session_autoinstall" passed:[row[@"installed"] boolValue] detail:row];
 [TFAIISHRuntime.shared uninstallTool:@"apk:jq" session:session completion:^(NSDictionary *r,NSError *e){[self waitPackage253:@"apk:jq" session:session done:^(NSDictionary *row){[self record:@"packages253_uninstall" passed:![row[@"installed"] boolValue]&&![row[@"state"] isEqual:@"failed"] detail:row];[self record:@"packages253_selection_removed" passed:![[d arrayForKey:@"DylixISHSelectedPackages"] containsObject:@"apk:jq"] detail:nil];
 [TFAIISHRuntime.shared toolInventory:second completion:^(NSDictionary *other){[self record:@"packages253_other_environment_untouched" passed:[other[@"apk:jq"][@"installed"] boolValue] detail:nil];[self record:@"packages253_finished" passed:YES detail:nil];}];}];}];
 }];});}];}];}];}];}];
}

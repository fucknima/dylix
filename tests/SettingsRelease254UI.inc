static UIViewController *TMCSettingsRelease254UI(void){
 StudioSettings *settings=[[StudioSettings alloc]initWithStyle:UITableViewStyleInsetGrouped];UINavigationController *nav=[[Settings253Nav alloc]initWithRootViewController:settings];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 NSMutableArray *checks=[NSMutableArray new];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[checks addObject:@{@"name":name,@"passed":@(ok)}];};
 check([NSBundle.mainBundle.infoDictionary[@"DylixEdition"] isEqual:@"release"],@"IPA explicitly identifies release edition");
 NSArray *titles=@[@"AI 对话",@"插件开发",@"终端与逆向",@"数据与工具",@"外观与编辑器",@"关于与支持"];
 check([settings numberOfSectionsInTableView:settings.tableView]==titles.count,@"six scenario groups");
 NSMutableSet *ids=[NSMutableSet new];for(NSInteger section=0;section<titles.count;section++){
 check([[settings tableView:settings.tableView titleForHeaderInSection:section] isEqual:titles[section]],titles[section]);
 for(NSInteger row=0;row<[settings tableView:settings.tableView numberOfRowsInSection:section];row++){
 NSIndexPath *i=[NSIndexPath indexPathForRow:row inSection:section];UITableViewCell *cell=[settings tableView:settings.tableView cellForRowAtIndexPath:i];
 check(cell.imageView.image!=nil&&cell.textLabel.text.length>0,cell.textLabel.text?:@"missing title");
 check(![ids containsObject:cell.accessibilityIdentifier],@"row identifiers unique");[ids addObject:cell.accessibilityIdentifier];
 NSString *key=[settings rowAt:i][0];if([@[@"theme",@"font",@"tabs"] containsObject:key])continue;
 [settings tableView:settings.tableView didSelectRowAtIndexPath:i];UIViewController *page=nav.topViewController;[page loadViewIfNeeded];check(page!=settings&&page.title.length>0,[NSString stringWithFormat:@"%@ route opens",key]);[nav popToRootViewControllerAnimated:NO];
 }}
 check(![ids containsObject:@"settings.autoSave"]&&![ids containsObject:@"settings.architecture"],@"read-only information removed from main settings");
 NSIndexPath *togglePath=[NSIndexPath indexPathForRow:2 inSection:4];UISwitch *toggle=(id)[settings tableView:settings.tableView cellForRowAtIndexPath:togglePath].accessoryView;BOOL before=toggle.on;toggle.on=!before;[toggle sendActionsForControlEvents:UIControlEventValueChanged];check([NSUserDefaults.standardUserDefaults boolForKey:@"StudioAlwaysShowTabBar"]==!before,@"tab switch still persists");toggle.on=before;[toggle sendActionsForControlEvents:UIControlEventValueChanged];
 Backup249Screenshot(settings,@"settings254-main");
 [settings tableView:settings.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:5]];StudioAbout *about=(id)nav.topViewController;[about loadViewIfNeeded];
 for(NSInteger row=0;row<5;row++){UITableViewCell *cell=[about tableView:about.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:5]];check([cell.textLabel.text isEqual:@[@"反馈与建议",@"Telegram 频道",@"官方网站",@"项目开源地址",@"软件许可证"][row]],cell.textLabel.text?:@"contact missing");}
 check([[about tableView:about.tableView titleForHeaderInSection:3] isEqual:@"工具链与本机"],@"toolchain facts remain in about");
 Backup249Screenshot(about,@"settings254-about");[about.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:5] atScrollPosition:UITableViewScrollPositionBottom animated:NO];Backup249Screenshot(about,@"settings254-support");
 [about tableView:about.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:5]];[nav.topViewController loadViewIfNeeded];check([nav.topViewController.title isEqual:@"软件许可证"],@"license opens");[nav popToViewController:about animated:NO];
 [about showFeedback];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,.8*NSEC_PER_SEC),dispatch_get_main_queue(),^{UINavigationController *feedback=(id)about.presentedViewController;check([feedback isKindOfClass:UINavigationController.class]&&[feedback.topViewController isKindOfClass:StudioFeedbackEditor.class],@"release feedback editor presents without sending");Backup249Screenshot(feedback,@"settings254-feedback");[about dismissViewControllerAnimated:NO completion:nil];[nav popToRootViewControllerAnimated:NO];
 [settings tableView:settings.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:2]];UITableViewController *tools=(id)nav.topViewController;[tools loadViewIfNeeded];check([tools.tableView.dataSource tableView:tools.tableView numberOfRowsInSection:0]>=22,@"22 individual tool entries retained");
 JSONWrite((id)checks,[Docs() stringByAppendingPathComponent:@"settings254-results.json"],nil);
 });
 });return nav;
}

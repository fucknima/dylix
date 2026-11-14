@interface Settings253Nav : UINavigationController
@end
@implementation Settings253Nav
- (void)pushViewController:(UIViewController *)page animated:(BOOL)animated{[super pushViewController:page animated:NO];}
@end
static UIViewController *TMCSettingsTools253UI(void){
 StudioSettings *settings=[[StudioSettings alloc]initWithStyle:UITableViewStyleInsetGrouped];UINavigationController *nav=[[Settings253Nav alloc]initWithRootViewController:settings];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 NSMutableArray *checks=[NSMutableArray new];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[checks addObject:@{@"name":name,@"passed":@(ok)}];};
 check([settings numberOfSectionsInTableView:settings.tableView]==8,@"settings removes top level toolchain section");check([[settings tableView:settings.tableView titleForHeaderInSection:6] isEqual:@"数据与工具"],@"data section remains before about");check([settings tableView:settings.tableView numberOfRowsInSection:6]==4,@"data section includes storage row");
 for(NSInteger row=0;row<4;row++){NSIndexPath *i=[NSIndexPath indexPathForRow:row inSection:6];UITableViewCell *c=[settings tableView:settings.tableView cellForRowAtIndexPath:i];check([c.textLabel.text isEqual:@[@"挂载文件夹",@"备份与恢复",@"安装工具",@"存储空间"][row]],c.textLabel.text?:@"missing");}
 [settings tableView:settings.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:3 inSection:6]];[nav.topViewController loadViewIfNeeded];check([nav.topViewController.title isEqual:@"存储空间"],@"storage route opens correct page");[nav popToRootViewControllerAnimated:NO];
 [settings tableView:settings.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:7]];StudioAbout *about=(id)nav.topViewController;[about loadViewIfNeeded];check([about.title isEqual:@"关于 Dylix"]&&[about numberOfSectionsInTableView:about.tableView]==5,@"about route and sections correct");
 check([[about tableView:about.tableView titleForHeaderInSection:3] isEqual:@"工具链与本机"],@"toolchain information moved into about");for(NSInteger row=0;row<3;row++){UITableViewCell *c=[about tableView:about.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:3]];check(c.detailTextLabel.text.length>0&&c.accessoryType==UITableViewCellAccessoryNone,@"toolchain facts show without misleading disclosure");}
 [nav popToRootViewControllerAnimated:NO];[settings tableView:settings.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:6]];
 UITableViewController *tools=(id)nav.topViewController;[tools loadViewIfNeeded];NSInteger n=[tools.tableView.dataSource tableView:tools.tableView numberOfRowsInSection:0];check(n>=20,@"at least 20 individually selectable tools");check([tools.tableView.dataSource numberOfSectionsInTableView:tools.tableView]==3,@"individual packages plus legacy suites plus SDK");
 NSMutableSet *names=[NSMutableSet new];for(NSInteger row=0;row<n;row++){UITableViewCell *c=[tools.tableView.dataSource tableView:tools.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];[names addObject:c.textLabel.text];}check([names containsObject:@"Python 3"]&&[names containsObject:@"Git"]&&[names containsObject:@"LLVM 19"]&&[names containsObject:@"jq"],@"individual catalog exposes development and analysis tools");
 Backup249Screenshot(tools,@"settings253-tools");JSONWrite(checks,[Docs() stringByAppendingPathComponent:@"settings253-results.json"],nil);
 });return nav;
}

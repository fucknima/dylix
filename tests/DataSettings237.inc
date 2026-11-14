#include "Backup249UI.inc"
#include "BackupUpdate250UI.inc"
#include "RunContinuity251UI.inc"
#include "RequestOptimization252UI.inc"
#include "SettingsTools253UI.inc"
#include "Tools255UI.inc"
#include "SettingsRelease254UI.inc"
UIViewController *TMCData237SettingsRegression(void){
 if([NSProcessInfo.processInfo.arguments containsObject:@"--tools255"])return TMCTools255UI();
 if([NSProcessInfo.processInfo.arguments containsObject:@"--settings254"])return TMCSettingsRelease254UI();
 if([NSProcessInfo.processInfo.arguments containsObject:@"--settings253"])return TMCSettingsTools253UI();
 if([NSProcessInfo.processInfo.arguments containsObject:@"--optimization252"])return TMCOptimization252UI();
 if([NSProcessInfo.processInfo.arguments containsObject:@"--continuity251"])return TMCContinuity251UI();
 if([NSProcessInfo.processInfo.arguments containsObject:@"--backup250"])return TMCBackup250Regression();
 if([NSProcessInfo.processInfo.arguments containsObject:@"--update250"])return TMCUpdate250Regression();
 if([NSProcessInfo.processInfo.arguments containsObject:@"--backup249"])return TMCBackup249Regression();
 StudioSettings *settings=[[StudioSettings alloc]initWithStyle:UITableViewStyleInsetGrouped];UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:settings];
 NSInteger row=0;for(NSString *arg in NSProcessInfo.processInfo.arguments)if([arg hasPrefix:@"--data-route="])row=[[arg componentsSeparatedByString:@"="].lastObject integerValue];row=MAX(0,MIN(2,row));
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{NSIndexPath *index=[NSIndexPath indexPathForRow:row inSection:6];NSString *name=[settings tableView:settings.tableView cellForRowAtIndexPath:index].textLabel.text;[settings tableView:settings.tableView didSelectRowAtIndexPath:index];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{UIViewController *page=nav.topViewController;JSONWrite(@[@{@"name":name?:@"",@"passed":@(page!=settings&&[@[@"挂载文件夹",@"备份与恢复",@"安装工具"][row] isEqual:page.title])}],[Docs() stringByAppendingPathComponent:@"data-settings237.json"],nil);});});return nav;
}

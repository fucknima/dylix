#import "../App/AI/Sandbox/DXLinuxToolBatch.h"
@interface Tools255Runtime : TFAIISHRuntime
@property NSMutableArray *started;
@property NSMutableDictionary *inventory;
@property BOOL active,overlap;
@end
@implementation Tools255Runtime
- (instancetype)init{if((self=[super init])){_started=[NSMutableArray new];_inventory=[NSMutableDictionary new];}return self;}
- (void)toolInventory:(NSString *)session completion:(void(^)(NSDictionary *))completion{completion([self.inventory copy]);}
- (void)installPackage:(NSString *)key session:(NSString *)session completion:(void(^)(NSDictionary *,NSError *))done{
 if(self.active)self.overlap=YES;self.active=YES;[self.started addObject:key];self.inventory[key]=@{@"state":@"installing",@"installed":@NO};done(@{@"process_id":@"fixture"},nil);
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,.2*NSEC_PER_SEC),dispatch_get_main_queue(),^{self.active=NO;BOOL fail=[key isEqual:@"apk:curl"];self.inventory[key]=@{@"state":fail?@"failed":@"installed",@"installed":@(!fail),@"error":@"fixture failure"};});
}
@end
static UIViewController *TMCTools255UI(void){
 StudioSettings *settings=[[StudioSettings alloc]initWithStyle:UITableViewStyleInsetGrouped];UINavigationController *nav=[[Settings253Nav alloc]initWithRootViewController:settings];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 NSMutableArray *checks=[NSMutableArray new];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[checks addObject:@{@"name":name,@"passed":@(ok)}];};
 check([settings numberOfSectionsInTableView:settings.tableView]==6,@"six scenario settings groups retained");
 for(NSInteger s=0;s<6;s++)for(NSInteger row=0;row<[settings tableView:settings.tableView numberOfRowsInSection:s];row++){
 NSIndexPath *i=[NSIndexPath indexPathForRow:row inSection:s];NSString *key=[settings rowAt:i][0];if([@[@"theme",@"font",@"tabs"] containsObject:key])continue;
 [settings tableView:settings.tableView didSelectRowAtIndexPath:i];[nav.topViewController loadViewIfNeeded];check(nav.topViewController!=settings&&nav.topViewController.title.length>0,[key stringByAppendingString:@" opens"]);[nav popToRootViewControllerAnimated:NO];}
 UIViewController *tools=TFAIISHToolsController(nil);[tools loadViewIfNeeded];check([tools.navigationItem.rightBarButtonItem.accessibilityIdentifier isEqual:@"linux.installAll"],@"tools shows one-tap install-all button");
 StudioBuildPreferences *build=[[StudioBuildPreferences alloc]initWithStyle:UITableViewStyleInsetGrouped];[nav pushViewController:build animated:NO];[build loadViewIfNeeded];BOOL installed=TMCSDKIsInstalled(NSBundle.mainBundle,NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES).firstObject,@"26.0");
 if(!installed){id old=[NSUserDefaults.standardUserDefaults objectForKey:@"StudioSDKVersion"];check(![build saveSDKValue:@"26.0" key:@"sdkVersion"],@"uninstalled SDK26 cannot silently become selected");check((old==nil&&[NSUserDefaults.standardUserDefaults objectForKey:@"StudioSDKVersion"]==nil)||[[NSUserDefaults.standardUserDefaults objectForKey:@"StudioSDKVersion"] isEqual:old],@"blocked SDK leaves previous preference intact");[build dismissViewControllerAnimated:NO completion:nil];}
 check(TMCSDKIsInstalled(NSBundle.mainBundle,NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES).firstObject,@"16.4"),@"bundled SDK16.4 available offline");
 [nav popToRootViewControllerAnimated:NO];StudioAbout *about=[[StudioAbout alloc]initWithStyle:UITableViewStyleInsetGrouped];[about loadViewIfNeeded];BOOL public=[NSBundle.mainBundle.infoDictionary[@"DylixEdition"] isEqual:@"opensource"];check([about tableView:about.tableView numberOfRowsInSection:5]==(public?3:5),@"about contact rows match build edition");
 DXLinuxToolBatch *batch=[DXLinuxToolBatch new];Tools255Runtime *runtime=[Tools255Runtime new];batch.runtime=runtime;
 NSArray *pending=[batch pending:@{} sdkInstalled:NO];check(pending.count==25&&[pending containsObject:@"sdk26"],@"install-all covers 22 packages two suites and optional SDK");check(![[batch pending:@{@"apk:jq":@{@"installed":@YES}} sdkInstalled:YES] containsObject:@"apk:jq"],@"installed package skipped");
 check(![batch start:@[@"apk:invalid"] session:@"invalid"],@"batch rejects unknown package identifiers");
 check([batch start:@[@"apk:jq",@"apk:curl",@"apk:git"] session:@"fixture"],@"batch starts accepted tools");check(![batch start:@[@"apk:jq"] session:@"fixture"],@"duplicate batch prevented");
 __block NSInteger tries=0;[NSTimer scheduledTimerWithTimeInterval:.2 repeats:YES block:^(NSTimer *timer){NSDictionary *status=[batch status:@"fixture"];if([status[@"running"] boolValue]&&++tries<100)return;[timer invalidate];
 check(![status[@"running"] boolValue]&&!runtime.overlap,@"batch completes serially without concurrent apk transactions");check([runtime.started isEqual:@[@"apk:jq",@"apk:curl",@"apk:git"]],@"failed middle package does not skip later tools");check([status[@"failed"] integerValue]==1,@"batch records actual failed installation");
 [batch start:@[@"apk:jq",@"apk:git"] session:@"cancel"];[batch cancelPending:@"cancel"];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{check(![[batch status:@"cancel"][@"running"] boolValue],@"cancel stops pending queue safely");JSONWrite((id)checks,[Docs() stringByAppendingPathComponent:@"tools255-results.json"],nil);});
 }];
 });return nav;
}

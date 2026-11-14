#import "TFAIISHPackageCatalog.h"
#import "TFAIISHHub.h"
#import "DXLinuxToolBatch.h"
#import "../Resources/DXResourceStore.h"
#import "../../SDKResources.h"
#import "TFAIISHRuntime.h"
#import "TFAIISHTerminal.h"
#import "TFAIISHMirrors.h"
#import "TFAIISHRootCatalog.h"
#import "TFAIISHEnvironmentUI.h"
#import "../Attachments/TFAIDirectoryRegistry.h"
#import "../UI/TFAIUIHelpers.h"
@interface DXLinuxSettingsPage : UITableViewController
@property NSString *session,*root;
@property BOOL tools,busy,sdkBusy;
@property NSDictionary *toolInventory;
@property NSTimer *statusTimer;
@property NSString *sdkError;
@end
@implementation DXLinuxSettingsPage
- (void)viewDidLoad{[super viewDidLoad];self.title=self.tools?@"安装工具":@"终端设置";self.tableView.accessibilityIdentifier=self.tools?@"linux.tools":@"linux.settings";self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=60;if(self.tools){self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"全部安装" style:UIBarButtonItemStylePlain target:self action:@selector(installAllTapped)];self.navigationItem.rightBarButtonItem.accessibilityIdentifier=@"linux.installAll";}}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];if(self.tools){[self refreshTools];self.statusTimer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refreshTools) userInfo:nil repeats:YES];}}
- (void)viewDidDisappear:(BOOL)animated{[super viewDidDisappear:animated];[self.statusTimer invalidate];self.statusTimer=nil;}
- (void)refreshTools{if(self.busy)return;self.busy=YES;__weak typeof(self) weak=self;[TFAIISHRuntime.shared toolInventory:self.session completion:^(NSDictionary *inventory){dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{BOOL sdkCached=[DXResourceStore verifiedPath:@"sdk26" error:nil]!=nil;dispatch_async(dispatch_get_main_queue(),^{typeof(self) page=weak;if(!page)return;NSMutableDictionary *all=[inventory mutableCopy];all[@"sdkCached"]=@(sdkCached);page.toolInventory=all;page.busy=NO;[page updateBatchButton];[page.tableView reloadData];});});}];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table{return self.tools?3:1;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return self.tools?(s==0?DXLinuxPackages().count:2):4;}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s{return self.tools?@[@"开发工具 · 单独安装",@"离线完整套件",@"iOS 编译 SDK"][s]:nil;}
- (BOOL)sdkInstalled{return TMCSDKIsInstalled(NSBundle.mainBundle,NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES).firstObject,@"26.0");}
- (void)updateBatchButton{NSDictionary *s=[DXLinuxToolBatch.shared status:self.session];BOOL active=[s[@"running"] boolValue];self.navigationItem.rightBarButtonItem.title=active?[NSString stringWithFormat:@"安装 %lu/%lu",(unsigned long)([s[@"index"] unsignedIntegerValue]+1),(unsigned long)[s[@"items"] count]]:@"全部安装";self.navigationItem.rightBarButtonItem.enabled=active||self.toolInventory!=nil;if(active){self.navigationItem.prompt=[NSString stringWithFormat:@"%@ · %@",[s[@"cancelled"] boolValue]?@"等待当前任务完成后停止":@"正在顺序安装",s[@"current"]?:@""];}else self.navigationItem.prompt=[s[@"failed"] unsignedIntegerValue]?[NSString stringWithFormat:@"安装结束 · %@ 项失败，可点对应项目重试",s[@"failed"]]:[s[@"cancelled"] boolValue]?@"已停止后续安装":s[@"items"]?@"全部安装任务已完成":nil;}
- (void)installAllTapped{
 NSDictionary *state=[DXLinuxToolBatch.shared status:self.session];if([state[@"running"] boolValue]){UIAlertController *a=[UIAlertController alertControllerWithTitle:@"正在安装工具" message:@"离开页面仍会继续。停止后续安装会等待当前任务完成，不破坏正在进行的安装。" preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"继续安装" style:UIAlertActionStyleCancel handler:nil]];[a addAction:[UIAlertAction actionWithTitle:@"停止后续安装" style:UIAlertActionStyleDestructive handler:^(id action){[DXLinuxToolBatch.shared cancelPending:self.session];[self updateBatchButton];}]];[self presentViewController:a animated:YES completion:nil];return;}
 if(!self.toolInventory){AIAlert(self,@"正在检查",@"请等待安装状态读取完成。");return;}
 NSArray *pending=[DXLinuxToolBatch.shared pending:self.toolInventory sdkInstalled:[self sdkInstalled]];if(!pending.count){AIAlert(self,@"全部已安装",@"没有需要安装的工具或 SDK。");return;}
 uint64_t bytes=0;for(NSString *key in pending)bytes+=[[DXResourceStore entry:key][@"bytes"] unsignedLongLongValue];
 NSString *detail=[NSString stringWithFormat:@"将顺序安装 %lu 项未安装工具（包含缺失的完整套件与 SDK 26）。固定资源约 %@，另需下载 Alpine 软件包；请预留磁盘空间。已安装项跳过，失败项保留错误并继续后续项目。",(unsigned long)pending.count,[NSByteCountFormatter stringFromByteCount:bytes countStyle:NSByteCountFormatterCountStyleFile]];
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"安装全部工具" message:detail preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[a addAction:[UIAlertAction actionWithTitle:@"开始安装" style:UIAlertActionStyleDefault handler:^(id action){[DXLinuxToolBatch.shared start:pending session:self.session];[self updateBatchButton];}]];[self presentViewController:a animated:YES completion:nil];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{
 if(!self.tools){NSArray *titles=@[@"挂载文件夹",@"软件源",@"Linux 版本",@"Linux 环境与快照"],*details=@[@"统一管理授权文件夹，AI 与终端均可使用",@"apk / pip / npm",@"查看与安装官方环境",@"终端文件系统维护；App 数据备份请前往设置"];UITableViewCell *c=AICell(titles[i.row],details[i.row],@"folder");c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return c;}
 if(i.section==0){NSDictionary *p=DXLinuxPackages()[i.row],*row=self.toolInventory[p[@"id"]];NSString *state=row[@"state"]?:@"checking";BOOL active=[@[@"checking",@"installing",@"uninstalling"] containsObject:state];NSString *label=[state isEqual:@"failed"]?@"失败 · 点击查看或重试":[state isEqual:@"uninstalling"]?@"正在卸载…":[state isEqual:@"installing"]?@"正在安装…":[row[@"installed"] boolValue]?([row[@"managed"] boolValue]?@"已安装 · 点击管理":@"已安装（套件或依赖） · 点击管理"):@"未安装 · 点击安装";UITableViewCell *c=AICell(p[@"title"],[NSString stringWithFormat:@"%@ · %@\n%@",p[@"detail"],p[@"package"],label],@"terminal");c.accessibilityIdentifier=[@"linux.resource." stringByAppendingString:p[@"id"]];c.accessibilityValue=state;if(active){UIActivityIndicatorView *v=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];[v startAnimating];c.accessoryView=v;}else c.accessoryView=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:[row[@"installed"] boolValue]?@"checkmark.circle.fill":@"arrow.down.circle"]];return c;}
 BOOL sdk=i.section==2;NSString *identifier=sdk?@"sdk26":i.row==0?@"developer-tools":@"reverse-tools";
 if(sdk&&i.row==0){UITableViewCell *c=AICell(@"iOS 16.4 SDK",@"内置 · 基础编译可离线使用",@"shippingbox");c.selectionStyle=UITableViewCellSelectionStyleNone;return c;}
 NSDictionary *row=self.toolInventory[identifier],*download=[DXResourceStore.shared status:identifier],*entry=[DXResourceStore entry:identifier];NSString *state=sdk?(self.sdkBusy?@"installing":[self sdkInstalled]?@"installed":@"notInstalled"):row[@"state"]?:@"checking";
 if(sdk&&[@[@"checking",@"downloading",@"verifying"] containsObject:download[@"state"]])state=@"downloading";
 BOOL active=[@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:state],installed=sdk?[self sdkInstalled]:[row[@"installed"] boolValue];
 NSString *downloadState=download[@"state"],*label=installed?@"已安装 · 点击管理":[state isEqual:@"uninstalling"]?@"正在卸载…":[state isEqual:@"installing"]?@"正在安装…":[state isEqual:@"failed"]?@"失败 · 点击重试":@"未安装 · 点击下载";
 if(active&&[@[@"downloading",@"verifying",@"checking"] containsObject:downloadState])label=[downloadState isEqual:@"downloading"]?[NSString stringWithFormat:@"正在下载 %.0f%%",[download[@"progress"] doubleValue]*100]:[downloadState isEqual:@"verifying"]?@"正在校验 SHA-256…":@"正在检查本地资源…";
 if(!installed&&!active&&[row[@"cached"] boolValue]&&![state isEqual:@"failed"])label=@"已下载 · 点击安装";
 NSString *details=sdk?@"平台头文件与链接桩":i.row==0?@"Python · Node/npm · Git · curl · dpkg · LLVM · ldid":@"radare2 · Ghidra 反编译引擎";
 NSString *failure=sdk?self.sdkError:row[@"error"];if(failure.length&&!active)label=[@"失败 · " stringByAppendingString:failure.length>100?[[failure substringToIndex:100] stringByAppendingString:@"…"]:failure];
 UITableViewCell *c=AICell(entry[@"title"]?:identifier,[NSString stringWithFormat:@"%@\n%@ · %@",details,label,[NSByteCountFormatter stringFromByteCount:[entry[@"bytes"] longLongValue] countStyle:NSByteCountFormatterCountStyleFile]],sdk?@"shippingbox":@"terminal");
 c.accessibilityIdentifier=[NSString stringWithFormat:@"linux.resource.%@",identifier];c.accessibilityValue=state;
 if(active){UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];[spinner startAnimating];c.accessoryView=spinner;}else c.accessoryView=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:installed?@"checkmark.circle.fill":@"arrow.down.circle"]];return c;
}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{if(!self.tools)return @"目录与 App 数据备份也可直接从软件设置进入。";if(s==0)return @"逐项安装到全局持久 Linux 环境，所有会话和终端直接共用，使用所选软件源并由 apk 校验签名，首次安装需要联网。卸载仅移除本页的安装记录，其他工具仍需要的依赖会保留；终端手动或套件安装的包不会直接删除。";return s==1?@"从 dylib.cn 下载并校验后在本页安装，不自动跳转终端。工具和下载缓存全局共用，关闭或删除会话不会删除工具；保持同一应用数据容器覆盖安装也会保留。卸载套件会影响全部会话。":@"iOS 26.0 SDK 按需下载并持久保存，首次使用此 SDK 构建时也会自动准备。原生 Clang/LLVM 等签名组件随 App 安装。";}
- (void)installIdentifier:(NSString *)identifier{
 if([identifier isEqual:@"sdk26"]){
  self.sdkBusy=YES;self.sdkError=nil;[self.tableView reloadData];__weak typeof(self) weak=self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
   NSError *failure=nil;TMCPrepareSelectedSDK(NSBundle.mainBundle,NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES).firstObject,@"26.0",&failure);
   dispatch_async(dispatch_get_main_queue(),^{weak.sdkBusy=NO;weak.sdkError=failure.localizedDescription;[weak refreshTools];});
  });return;
 }
 __weak typeof(self) weak=self;
 void(^done)(NSDictionary *,NSError *)=^(NSDictionary *r,NSError *error){if(error)AIAlert(weak,@"安装未完成",error.localizedDescription);[weak refreshTools];};
 if(DXLinuxPackage(identifier))[TFAIISHRuntime.shared installPackage:identifier session:self.session completion:done];else if([identifier isEqual:@"developer-tools"])[TFAIISHRuntime.shared installDeveloperTools:self.session completion:done];else[TFAIISHRuntime.shared installReverseTools:self.session completion:done];[self refreshTools];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{
 [t deselectRowAtIndexPath:i animated:YES];
 if(!self.tools){UIViewController *page=i.row==0?TFAIDirectoryRegistryController(self.session):i.row==1?TFAIISHMirrorController(self.session):i.row==2?TFAIISHRootCatalogController(self.session):TFAIISHEnvironmentController(self.session,self.root);[self.navigationController pushViewController:page animated:YES];return;}
 if([[DXLinuxToolBatch.shared status:self.session][@"running"] boolValue]){AIAlert(self,@"正在批量安装",@"请等待全部安装完成，或点击右上角停止后续安装。");return;}
 if(i.section==0){NSDictionary *p=DXLinuxPackages()[i.row],*row=self.toolInventory[p[@"id"]];if([@[@"installing",@"uninstalling",@"checking"] containsObject:row[@"state"]]){if([row[@"process_id"] length])[self.navigationController pushViewController:TFAIISHProcessController(self.session,row[@"process_id"]) animated:YES];return;}
 UIAlertController *a=[UIAlertController alertControllerWithTitle:p[@"title"] message:row[@"error"]?:@"工具保存在 Linux 环境中。所有 AI 和终端共用；同一 App 保留数据覆盖安装后继续可用；卸载影响所有会话，仅移除本页管理的安装，仍被其他工具依赖时会保留。" preferredStyle:UIAlertControllerStyleActionSheet];
 [a addAction:[UIAlertAction actionWithTitle:[row[@"installed"] boolValue]?@"检查安装":@"安装" style:UIAlertActionStyleDefault handler:^(id action){[self installIdentifier:p[@"id"]];}]];
 if([row[@"managed"] boolValue])[a addAction:[UIAlertAction actionWithTitle:@"卸载" style:UIAlertActionStyleDestructive handler:^(id action){[TFAIISHRuntime.shared uninstallTool:p[@"id"] session:self.session completion:^(NSDictionary *r,NSError *e){if(e)AIAlert(self,@"卸载未完成",e.localizedDescription);[self refreshTools];}];}]];
 if([row[@"process_id"] length])[a addAction:[UIAlertAction actionWithTitle:@"查看任务输出" style:UIAlertActionStyleDefault handler:^(id action){[self.navigationController pushViewController:TFAIISHProcessController(self.session,row[@"process_id"]) animated:YES];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=[t cellForRowAtIndexPath:i];a.popoverPresentationController.sourceRect=[t cellForRowAtIndexPath:i].bounds;[self presentViewController:a animated:YES completion:nil];return;}
 if(i.section==2&&i.row==0)return;
 NSString *identifier=i.section==2?@"sdk26":i.row==0?@"developer-tools":@"reverse-tools";NSDictionary *row=self.toolInventory[identifier];BOOL installed=i.section==2?[self sdkInstalled]:[row[@"installed"] boolValue];NSString *state=row[@"state"];
 if((i.section==2&&self.sdkBusy)||[@[@"checking",@"downloading",@"installing",@"uninstalling"] containsObject:state]){
  NSString *downloadState=[DXResourceStore.shared status:identifier][@"state"];
  if([@[@"checking",@"downloading",@"verifying"] containsObject:downloadState]){UIAlertController *cancel=[UIAlertController alertControllerWithTitle:@"正在准备资源" message:@"可取消下载，之后再点击重试。" preferredStyle:UIAlertControllerStyleAlert];[cancel addAction:[UIAlertAction actionWithTitle:@"继续等待" style:UIAlertActionStyleCancel handler:nil]];[cancel addAction:[UIAlertAction actionWithTitle:@"取消下载" style:UIAlertActionStyleDestructive handler:^(id action){[DXResourceStore.shared cancel:identifier];}]];[self presentViewController:cancel animated:YES completion:nil];}
  else if([row[@"process_id"] length])[self.navigationController pushViewController:TFAIISHProcessController(self.session,row[@"process_id"]) animated:YES];return;
 }
 if(!installed){[self installIdentifier:identifier];return;}
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:[DXResourceStore entry:identifier][@"title"] message:i.section==2?@"卸载 SDK 和本机下载缓存；下次需要时可重新下载。":@"卸载共享环境中的套件，并关闭自动安装；所有终端和 AI 会话都会受到影响。" preferredStyle:UIAlertControllerStyleActionSheet];
 [sheet addAction:[UIAlertAction actionWithTitle:@"卸载" style:UIAlertActionStyleDestructive handler:^(id action){
  if(i.section==2){extern BOOL TMCBuildIsRunning(void) __attribute__((weak_import));if(TMCBuildIsRunning&&TMCBuildIsRunning()){AIAlert(self,@"正在构建",@"请等待构建结束后卸载 SDK。");return;}NSError *error=nil;@synchronized(NSBundle.class){if([DXResourceStore.shared remove:identifier error:&error])[NSFileManager.defaultManager removeItemAtPath:[DXResourceStore.directory stringByAppendingPathComponent:@"SDK26Installed"] error:&error];}if(error)AIAlert(self,@"卸载未完成",error.localizedDescription);[self refreshTools];}
  else[TFAIISHRuntime.shared uninstallTool:identifier session:self.session completion:^(NSDictionary *r,NSError *e){if(e)AIAlert(self,@"卸载未完成",e.localizedDescription);[self refreshTools];}];
 }]];
 if(i.section==1)[sheet addAction:[UIAlertAction actionWithTitle:@"删除下载缓存（保留已安装工具）" style:UIAlertActionStyleDefault handler:^(id action){NSError *error=nil;if(![DXResourceStore.shared remove:identifier error:&error])AIAlert(self,@"缓存未删除",error.localizedDescription);[self refreshTools];}]];
 if([row[@"process_id"] length])[sheet addAction:[UIAlertAction actionWithTitle:@"查看任务输出" style:UIAlertActionStyleDefault handler:^(id action){[self.navigationController pushViewController:TFAIISHProcessController(self.session,row[@"process_id"]) animated:YES];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];sheet.popoverPresentationController.sourceView=[t cellForRowAtIndexPath:i];sheet.popoverPresentationController.sourceRect=[t cellForRowAtIndexPath:i].bounds;[self presentViewController:sheet animated:YES completion:nil];
}
@end
UIViewController *TFAIISHToolsController(NSString *session){DXLinuxSettingsPage *p=[[DXLinuxSettingsPage alloc]initWithStyle:UITableViewStyleInsetGrouped];p.session=session.length?session:@"tools-setup";p.tools=YES;return p;}
UIViewController *TFAIISHSettingsController(NSString *session,NSString *root){DXLinuxSettingsPage *p=[[DXLinuxSettingsPage alloc]initWithStyle:UITableViewStyleInsetGrouped];p.session=session.length?session:@"local-terminal";p.root=root;return p;}

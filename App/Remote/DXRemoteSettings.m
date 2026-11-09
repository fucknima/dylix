#import "DXRemoteService.h"
#import "DXFlexPluginInfo.h"
#import "../AI/AIV2Contracts.h"
#import "../GlassSupport.h"
#import <CoreImage/CoreImage.h>
@interface DXDAVProjects : UITableViewController
@property NSArray *projects;
@property NSString *selected;
@property(copy) void (^selection)(NSDictionary *);
@end
@implementation DXDAVProjects
- (void)viewDidLoad{[super viewDidLoad];self.title=@"WebDAV 共享项目";self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(close)];}
- (void)close{[self dismissViewControllerAnimated:YES completion:nil];}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return self.projects.count;}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{return @"仅共享选定项目。选择后设置读取或读写权限。";}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{NSDictionary *p=self.projects[i.row];UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];c.textLabel.text=p[@"name"];c.textLabel.numberOfLines=0;c.imageView.image=[UIImage systemImageNamed:@"folder"];c.accessoryType=[p[@"id"] isEqual:self.selected]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;return c;}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{NSDictionary *p=self.projects[i.row];void(^selection)(NSDictionary *)=self.selection;[self dismissViewControllerAnimated:YES completion:^{if(selection)selection(p);}];}
@end
@interface DXRemoteSettings : UITableViewController
@property NSDictionary *snapshot;
@property NSTimer *timer;
@end
@implementation DXRemoteSettings
- (void)viewDidLoad{[super viewDidLoad];self.title=@"远程连接";self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=64;[self tick];}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];self.timer=[NSTimer timerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];[[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self.timer invalidate];self.timer=nil;}
- (NSString *)codeDetail{
 if([self.snapshot[@"codeMode"] isEqual:@"fixed"])return [NSString stringWithFormat:@"%@ · 固定码，手动更换前有效",self.snapshot[@"code"]?:@""];
 NSTimeInterval remaining=[self.snapshot[@"codeExpiry"] doubleValue]-NSDate.date.timeIntervalSince1970;
 return remaining>0?[NSString stringWithFormat:@"%@ · 剩余 %ld 秒",self.snapshot[@"code"],(long)ceil(remaining)]:@"已过期或已使用 · 点击生成";
}
- (NSString *)accessURL{return self.snapshot[@"url"]?:@"";}
- (void)tick{
 NSDictionary *next=DXRemoteService.shared.localState;BOOL changed=![self.snapshot isEqual:next];self.snapshot=next;
 if(changed&&!self.tableView.dragging&&!self.tableView.decelerating&&!self.presentedViewController)[self.tableView reloadData];
 UITableViewCell *cell=[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:1]];cell.detailTextLabel.text=[self codeDetail];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table{return 7;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{return section==0?6:section==1?4:section==2?1:section==3?MAX(1,[self.snapshot[@"devices"] count]):section==4?5:1;}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section{return @[@"Dylix Remote",@"访问与配对",@"后台状态",@"已授权设备",@"访问范围",@"服务记录",@"FLEX 联动"][section];}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section{
 if(section==0)return self.snapshot[@"error"]&&[self.snapshot[@"error"] length]?self.snapshot[@"error"]:@"局域网模式供同一 Wi-Fi 内的设备连接；仅本机模式供同一设备的 FLEX 使用，无需 Wi-Fi。服务默认关闭，HTTP 为明文传输；开启且 App 在前台时保持屏幕常亮。";
 if(section==1)return @"输入正确授权码即可连接，无需手机再次确认。随机码一次有效且 5 分钟到期；固定码存于本机钥匙串，手动更换前有效。请只向可信设备提供授权码。";
 if(section==3)return @"在线：最近 30 秒内有请求。点击设备可以撤销访问，授权有效期 30 天。若对方知道固定码，撤权后仍可重新配对；需同时更换固定码阻止重连。";
 if(section==4)return @"工作区权限在浏览器配对时选择。WebDAV 通过 HTTP 仅共享选定项目，独立凭据 24 小时有效。锁屏时受保护文件仍需解锁访问。";
 return nil;
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index{
 UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];c.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];c.detailTextLabel.numberOfLines=0;c.textLabel.numberOfLines=0;c.detailTextLabel.textColor=UIColor.secondaryLabelColor;
 BOOL running=[self.snapshot[@"state"] isEqual:@"running"],starting=[self.snapshot[@"state"] isEqual:@"starting"];
 if(index.section==0){
  c.textLabel.text=@[@"HTTP 服务",@"当前状态",@"当前访问 IP",@"HTTP 端口",@"在线设备",@"连接方式"][index.row];c.imageView.image=[UIImage systemImageNamed:@[@"network",@"circle.dotted",@"wifi",@"number",@"desktopcomputer",@"point.3.connected.trianglepath.dotted"][index.row]];
  if(index.row==0){UISwitch *toggle=[UISwitch new];toggle.on=[self.snapshot[@"httpEnabled"] boolValue];[toggle addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];c.accessoryView=toggle;c.selectionStyle=UITableViewCellSelectionStyleNone;}
  else c.detailTextLabel.text=index.row==1?(@{@"running":@"运行中",@"starting":@"正在启动",@"failed":@"启动失败",@"suspended":@"后台暂停 · 回前台恢复",@"stopped":@"已停止"}[self.snapshot[@"state"]]?:@"已停止"):index.row==2?([self.snapshot[@"address"] length]?self.snapshot[@"address"]:@"未连接兼容 Wi-Fi"):index.row==3?[self.snapshot[@"port"] stringValue]:[self.snapshot[@"online"] stringValue];
  if(index.row==3){c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;c.userInteractionEnabled=!running&&!starting;}
  if(index.row==5){c.detailTextLabel.text=@{@"wifi":@"Wi-Fi 局域网",@"local":@"仅本机 · 不需要 Wi-Fi"}[self.snapshot[@"networkMode"]]?:@"Wi-Fi 局域网";c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
 }
 if(index.section==1){
  c.textLabel.text=@[@"访问二维码",@"复制访问地址",@"授权码（随机 / 固定）",@"断开所有设备"][index.row];c.imageView.image=[UIImage systemImageNamed:@[@"qrcode",@"doc.on.doc",@"key",@"xmark.circle"][index.row]];c.userInteractionEnabled=index.row==3||running;c.textLabel.enabled=c.userInteractionEnabled;
  if(index.row==1)c.detailTextLabel.text=[self accessURL];
  if(index.row==2)c.detailTextLabel.text=[self codeDetail];
  if(index.row==3)c.textLabel.textColor=UIColor.systemRedColor;
 }
 if(index.section==2){c.selectionStyle=UITableViewCellSelectionStyleNone;c.textLabel.text=@"后台状态";c.imageView.image=[UIImage systemImageNamed:@"moon"];c.detailTextLabel.text=@{@"foreground":@"前台运行",@"background_grace":@"系统传输宽限期",@"background_audio":@"远程音频辅助中（非永久保证）",@"background_system":@"系统决定可用后台时间",@"suspended":@"系统宽限结束 · 返回前台恢复"}[self.snapshot[@"lifecycle"]]?:@"前台运行";}


 if(index.section==3){NSArray *devices=self.snapshot[@"devices"];if(devices.count){NSDictionary *d=devices[index.row];c.textLabel.text=d[@"name"];c.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@",[d[@"online"] boolValue]?@"在线":@"离线",d[@"permission"]?:@"overview:read"];c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}else{c.textLabel.text=@"尚未授权设备";c.selectionStyle=UITableViewCellSelectionStyleNone;}}
 if(index.section==4){
  c.textLabel.text=@[@"访问权限",@"WebDAV 服务",@"WebDAV 端口",@"WebDAV 访问凭据",@"WebDAV 项目"][index.row];c.imageView.image=[UIImage systemImageNamed:index.row?@"externaldrive.connected.to.line.below":@"lock.shield"];
  if(index.row==0)c.detailTextLabel.text=@"浏览器配对时选择概况或工作区，写操作独立确认";
  if(index.row==1){c.detailTextLabel.text=self.snapshot[@"davError"];UISwitch *toggle=[UISwitch new];toggle.on=[self.snapshot[@"davEnabled"] boolValue];[toggle addTarget:self action:@selector(toggleDAV:) forControlEvents:UIControlEventValueChanged];c.accessoryView=toggle;}
  if(index.row==2)c.detailTextLabel.text=[self.snapshot[@"davPort"] stringValue];
  if(index.row==3)c.detailTextLabel.text=[self.snapshot[@"webdav"] boolValue]?self.snapshot[@"davURL"]:@"先开启服务，凭据仅在手机显示";
  if(index.row==4){c.detailTextLabel.text=@"尚未选择";for(NSDictionary *p in TFAIInternalProjects())if([p[@"id"] isEqual:self.snapshot[@"davProject"]])c.detailTextLabel.text=p[@"name"];}
  if(index.row>=2)c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
 }

 if(index.section==5){c.textLabel.text=@"服务日志";c.detailTextLabel.text=[NSString stringWithFormat:@"%lu 条本次进程事件",(unsigned long)[self.snapshot[@"logs"] count]];c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;c.imageView.image=[UIImage systemImageNamed:@"list.bullet.rectangle"];}
 if(index.section==6){c.textLabel.text=@"FLEX 插件";c.detailTextLabel.text=@"功能说明 · 内置 deb 与 dylib";c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;c.imageView.image=[UIImage systemImageNamed:@"puzzlepiece.extension"];}

 return c;
}
- (void)toggleDAV:(UISwitch *)sender{if(!sender.on){[DXRemoteService.shared stopWebDAV];return;}[self chooseDAV];}
- (void)chooseDAV{
 NSArray *projects=TFAIInternalProjects();if(!projects.count){[self message:@"先创建项目" text:@"WebDAV 仅共享选定的内部项目目录"];return;}
 DXDAVProjects *picker=[[DXDAVProjects alloc]initWithStyle:UITableViewStyleInsetGrouped];picker.projects=projects;picker.selected=self.snapshot[@"davProject"];__weak typeof(self) weak=self;
 picker.selection=^(NSDictionary *p){DXRemoteSettings *strong=weak;if(!strong)return;UIAlertController *permissions=[UIAlertController alertControllerWithTitle:p[@"name"] message:@"选择 WebDAV 项目的读取或读写权限。" preferredStyle:UIAlertControllerStyleAlert];for(NSNumber *readOnly in @[@YES,@NO])[permissions addAction:[UIAlertAction actionWithTitle:readOnly.boolValue?@"仅允许读取":@"允许读取和写入" style:readOnly.boolValue?UIAlertActionStyleDefault:UIAlertActionStyleDestructive handler:^(id a){[DXRemoteService.shared startWebDAVProject:p[@"id"] readOnly:readOnly.boolValue];}]];[permissions addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[strong presentViewController:permissions animated:YES completion:nil];};
 UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:picker];nav.modalPresentationStyle=UIModalPresentationPageSheet;if(@available(iOS 15.0,*)){nav.sheetPresentationController.detents=@[UISheetPresentationControllerDetent.mediumDetent,UISheetPresentationControllerDetent.largeDetent];nav.sheetPresentationController.prefersGrabberVisible=YES;}[self presentViewController:nav animated:YES completion:nil];
}
- (void)toggle:(UISwitch *)sender{if(sender.on)[DXRemoteService.shared start];else[DXRemoteService.shared stop];}
- (void)message:(NSString *)title text:(NSString *)text{UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index{
 [table deselectRowAtIndexPath:index animated:YES];
 if(index.section==0&&index.row==5){UIAlertController *a=[UIAlertController alertControllerWithTitle:@"连接方式" message:@"先关闭 HTTP 与 WebDAV。局域网模式供同一 Wi-Fi 内的设备连接；仅本机模式供同一设备的 FLEX 连接，不需要 Wi-Fi。" preferredStyle:UIAlertControllerStyleActionSheet];NSArray *modes=@[@"wifi",@"local"],*titles=@[@"Wi-Fi 局域网",@"仅本机"];for(NSUInteger i=0;i<modes.count;i++){NSString *mode=modes[i];[a addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(id action){[DXRemoteService.shared setNetworkMode:mode];}]];}[a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];UITableViewCell *cell=[table cellForRowAtIndexPath:index];a.popoverPresentationController.sourceView=cell;a.popoverPresentationController.sourceRect=cell.bounds;[self presentViewController:a animated:YES completion:nil];return;}
 if(index.section==6){[self.navigationController pushViewController:DXFlexPluginInfoController() animated:YES];return;}
 if(index.section==0&&index.row==3){
  UIAlertController *a=[UIAlertController alertControllerWithTitle:@"HTTP 端口" message:@"关闭服务后设置，范围 1024–65535" preferredStyle:UIAlertControllerStyleAlert];[a addTextFieldWithConfigurationHandler:^(UITextField *f){f.keyboardType=UIKeyboardTypeNumberPad;f.text=[self.snapshot[@"port"] stringValue];}];[a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(id action){NSString *s=a.textFields.firstObject.text;if(s.length&&[s rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location==NSNotFound&&s.integerValue>=1024&&s.integerValue<=65535)[DXRemoteService.shared setPort:s.integerValue];else[self message:@"端口有误" text:@"请输入 1024–65535"]; }]];[a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];return;
 }
 if(index.section==1){
  if(index.row==0){NSString *url=[self accessURL];if(!url.length)return;
   CIFilter *filter=[CIFilter filterWithName:@"CIQRCodeGenerator"];[filter setValue:[url dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];CIImage *image=[filter.outputImage imageByApplyingTransform:CGAffineTransformMakeScale(8,8)];UIImageView *qr=[[UIImageView alloc]initWithImage:[UIImage imageWithCIImage:image]];qr.layer.magnificationFilter=kCAFilterNearest;qr.contentMode=UIViewContentModeScaleAspectFit;qr.backgroundColor=UIColor.whiteColor;
   UIViewController *page=[UIViewController new];page.title=@"扫码访问";page.view.backgroundColor=UIColor.systemGroupedBackgroundColor;UILabel *label=[UILabel new];label.text=url;label.numberOfLines=0;label.textAlignment=NSTextAlignmentCenter;label.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];UIStackView *stack=[[UIStackView alloc]initWithArrangedSubviews:@[qr,label]];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=24;stack.translatesAutoresizingMaskIntoConstraints=NO;[page.view addSubview:stack];NSLayoutConstraint *idealWidth=[stack.widthAnchor constraintEqualToAnchor:page.view.widthAnchor multiplier:.78];idealWidth.priority=UILayoutPriorityDefaultHigh;[NSLayoutConstraint activateConstraints:@[[stack.centerXAnchor constraintEqualToAnchor:page.view.centerXAnchor],[stack.centerYAnchor constraintEqualToAnchor:page.view.safeAreaLayoutGuide.centerYAnchor],idealWidth,[stack.widthAnchor constraintLessThanOrEqualToAnchor:page.view.safeAreaLayoutGuide.heightAnchor multiplier:.65],[qr.heightAnchor constraintEqualToAnchor:qr.widthAnchor]]];[self.navigationController pushViewController:page animated:YES];
  }else if(index.row==1){NSString *url=[self accessURL];if(url.length){UIPasteboard.generalPasteboard.string=url;[self message:@"已复制" text:url];}}
  else if(index.row==2){UIAlertController *a=[UIAlertController alertControllerWithTitle:@"配对码" message:@"随机码为 5 分钟内一次有效。固定码存入钥匙串并长期有效，可随时更换。" preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"生成随机码" style:UIAlertActionStyleDefault handler:^(id x){[DXRemoteService.shared rotateCode];}]];[a addTextFieldWithConfigurationHandler:^(UITextField *f){f.keyboardType=UIKeyboardTypeNumberPad;f.placeholder=@"固定数字（6–12 位）";}];[a addAction:[UIAlertAction actionWithTitle:@"使用固定码" style:UIAlertActionStyleDefault handler:^(id x){[DXRemoteService.shared setFixedCode:a.textFields.firstObject.text?:@""];}]];[a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];}
  else{UIAlertController *a=[UIAlertController alertControllerWithTitle:@"断开所有设备？" message:@"撤销全部授权，所有浏览器需要重新配对。已知固定码仍可重连，必要时请同时更换配对码。" preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"断开" style:UIAlertActionStyleDestructive handler:^(id action){[DXRemoteService.shared revoke:nil];}]];[a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];}
 }

 if(index.section==3&&[self.snapshot[@"devices"] count]>index.row){NSDictionary *d=self.snapshot[@"devices"][index.row];UIAlertController *a=[UIAlertController alertControllerWithTitle:@"撤销访问？" message:d[@"name"] preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"撤销" style:UIAlertActionStyleDestructive handler:^(id action){[DXRemoteService.shared revoke:d[@"id"]];}]];[a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];}
 if(index.section==4){
  if(index.row==4){[self chooseDAV];return;}
  if(index.row==2){if([self.snapshot[@"webdav"] boolValue]){[self message:@"先关闭 WebDAV" text:@"停止后可更改端口"];return;}UIAlertController *a=[UIAlertController alertControllerWithTitle:@"WebDAV 端口" message:@"范围1024–65535，须与HTTP端口不同" preferredStyle:UIAlertControllerStyleAlert];[a addTextFieldWithConfigurationHandler:^(UITextField *f){f.keyboardType=UIKeyboardTypeNumberPad;f.text=[self.snapshot[@"davPort"] stringValue];}];[a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(id action){NSUInteger value=a.textFields.firstObject.text.integerValue;if(value>=1024&&value<=65535&&value!=[self.snapshot[@"port"] unsignedIntegerValue])[DXRemoteService.shared setWebDAVPort:value];else[self message:@"端口有误" text:@"请输入有效且不重复的端口"]; }]];[a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];return;}
  if(index.row==3){NSDictionary *credential=self.snapshot[@"davCredential"];if(![credential[@"password"] length]){[self message:@"服务尚未开启" text:@"开启服务后在本机显示独立凭据"];return;}UIAlertController *a=[UIAlertController alertControllerWithTitle:@"WebDAV 访问凭据" message:[NSString stringWithFormat:@"%@\n用户名：%@\n密码：%@\n24小时有效，仅复制给可信设备。",self.snapshot[@"davURL"],credential[@"username"],credential[@"password"]] preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"复制密码" style:UIAlertActionStyleDefault handler:^(id action){UIPasteboard.generalPasteboard.string=credential[@"password"];}]];[a addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];return;}
 }
 if(index.section==5){UIViewController *page=[UIViewController new];page.title=@"服务日志";UITextView *text=[UITextView new];text.editable=NO;text.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];NSMutableString *lines=[NSMutableString new];NSDateFormatter *date=[NSDateFormatter new];date.dateFormat=@"HH:mm:ss";for(NSDictionary *event in [self.snapshot[@"logs"] reverseObjectEnumerator])[lines appendFormat:@"%@  %@\n",[date stringFromDate:[NSDate dateWithTimeIntervalSince1970:[event[@"timestamp"] doubleValue]]],event[@"event"]];text.text=lines;page.view=text;[self.navigationController pushViewController:page animated:YES];}
}
@end
UIViewController *DXRemoteSettingsController(void){return [[DXRemoteSettings alloc]initWithStyle:UITableViewStyleInsetGrouped];}

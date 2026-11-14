#import "DXFlexPluginInfo.h"

@interface DXFlexPluginInfo : UITableViewController
@property NSDictionary *manifest;
@end

@implementation DXFlexPluginInfo
- (void)viewDidLoad {
 [super viewDidLoad];self.title=@"FLEX 插件";self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=72;
 NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"FLEXPlugin/manifest.json"];
 id value=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]?:NSData.data options:0 error:nil];
 self.manifest=[value isKindOfClass:NSDictionary.class]?value:@{};
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section==0?1:section==1?4:2; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @[@"插件简介",@"可用能力",@"分享安装包"][section]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
 if(section==0)return @"FLEX++ 运行在你选择注入的目标 App 内；Dylix 通过已配对的局域网或本机连接接收现场数据和工具结果。同一设备可使用仅本机模式，无需 Wi-Fi。";
 if(section==1)return @"敏感读取与视图控制受 FLEX 工具权限约束。Dylix 不会因分享安装包而自动注入目标 App。";
 if(section==2)return @"在目标设备上使用适合其环境的安装方式。deb 面向 rootless 环境；dylib 供需要独立插件文件的工作流使用。";
 return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
 UITableViewCell *cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];cell.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];cell.detailTextLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];cell.detailTextLabel.textColor=UIColor.secondaryLabelColor;cell.detailTextLabel.numberOfLines=0;
 if(indexPath.section==0){cell.textLabel.text=[NSString stringWithFormat:@"FLEX++ %@",self.manifest[@"version"]?:@""];cell.detailTextLabel.text=@"三指或四指长按 0.5 秒唤出 FLEX。在目标 App 内查看视图、类、网络与沙盒现场，并通过 Dylix AI 会话调用受控实时工具。";cell.imageView.image=[UIImage systemImageNamed:@"puzzlepiece.extension"];cell.selectionStyle=UITableViewCellSelectionStyleNone;}
 if(indexPath.section==1){cell.textLabel.text=@[@"现场与对象",@"AI 会话",@"工具权限",@"自主交互与扩展页面"][indexPath.row];cell.detailTextLabel.text=@[@"选中对象、视图树、类信息及运行时镜像",@"收起后会话继续运行，从 FLEX 菜单的 Dylix AI 返回同一会话",@"本会话一次总授权，敏感读取与控制共用，无时间限制；可随时撤销",@"按系统能力开放点击、双击、长按、拖动、缩放、旋转；支持文本输入、原生控件、xx.h 与反汇编导航。触摸实现参考 KIF / EarlGrey（Apache-2.0），许可随包附带。"][indexPath.row];cell.imageView.image=[UIImage systemImageNamed:@[@"viewfinder",@"bubble.left.and.text.bubble.right",@"lock.shield",@"hand.tap"][indexPath.row]];cell.selectionStyle=UITableViewCellSelectionStyleNone;}
 if(indexPath.section==2){NSString *kind=indexPath.row==0?@"deb":@"dylib";NSDictionary *file=self.manifest[@"files"][kind];NSString *name=file[@"name"];NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:[@"FLEXPlugin" stringByAppendingPathComponent:name?:@""]];NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];BOOL available=[attrs[NSFileType] isEqual:NSFileTypeRegular];cell.textLabel.text=indexPath.row==0?@"分享 rootless deb":@"分享独立 dylib";cell.detailTextLabel.text=available?[NSString stringWithFormat:@"%@ · %@",name,[NSByteCountFormatter stringFromByteCount:[attrs[NSFileSize] longLongValue] countStyle:NSByteCountFormatterCountStyleFile]]:@"安装包缺失";cell.imageView.image=[UIImage systemImageNamed:@"square.and.arrow.up"];cell.accessoryType=available?UITableViewCellAccessoryDisclosureIndicator:UITableViewCellAccessoryNone;cell.userInteractionEnabled=available;cell.textLabel.enabled=available;}
 return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
 [tableView deselectRowAtIndexPath:indexPath animated:YES];if(indexPath.section!=2)return;
 NSString *kind=indexPath.row==0?@"deb":@"dylib";NSString *name=self.manifest[@"files"][kind][@"name"];
 if(![name isKindOfClass:NSString.class]||![name isEqual:name.lastPathComponent])return;
 NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:[@"FLEXPlugin" stringByAppendingPathComponent:name]];
 NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];if(![attrs[NSFileType] isEqual:NSFileTypeRegular])return;
 UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
 UITableViewCell *cell=[tableView cellForRowAtIndexPath:indexPath];share.popoverPresentationController.sourceView=cell;share.popoverPresentationController.sourceRect=cell.bounds;[self presentViewController:share animated:YES completion:nil];
}
@end

UIViewController *DXFlexPluginInfoController(void) { return [[DXFlexPluginInfo alloc]initWithStyle:UITableViewStyleInsetGrouped]; }

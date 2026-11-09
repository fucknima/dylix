#import "TFAIToolRegistryUI.h"
#import "TFAIToolRegistry.h"
#import "../UI/TFAIUIHelpers.h"

@interface TFAIToolRegistrySettings : UITableViewController
@end

@implementation TFAIToolRegistrySettings
- (void)viewDidLoad {
 [super viewDidLoad];
 self.title=@"Agent 功能开关";
 self.tableView.rowHeight=UITableViewAutomaticDimension;
 self.tableView.estimatedRowHeight=68;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
 return 1+([TFAIToolRegistry enabled:@"remote"]||[TFAIToolRegistry enabled:@"isolation"]?1:0);
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
 if(section==0)return 6;
 return [TFAIToolRegistry enabled:@"remote"]+[TFAIToolRegistry enabled:@"isolation"];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
 return section==0?@"会话能力":@"已开启的扩展";
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
 return section==0?@"关闭后不会向 AI 提供对应工具；已保存的技能、记忆和服务器不会删除。":@"这些扩展不会在此自动开启；关闭后对应工具会从下一轮会话中移除。";
}
- (UITableViewCell *)cell:(NSString *)module title:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon {
 UITableViewCell *cell=AICell(title,detail,icon);
 UISwitch *toggle=[UISwitch new];
 toggle.on=[TFAIToolRegistry enabled:module];
 toggle.accessibilityLabel=title;
 [toggle addAction:[UIAction actionWithHandler:^(UIAction *action){[TFAIToolRegistry setEnabled:toggle.on module:module];[self.tableView reloadData];}] forControlEvents:UIControlEventValueChanged];
 cell.accessoryView=toggle;
 cell.selectionStyle=UITableViewCellSelectionStyleNone;
 return cell;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
 if(indexPath.section==0){
  NSArray *modules=@[@"skills",@"memory",@"browser",@"mcp",@"build_queue",@"sandbox"];
  NSArray *titles=@[@"技能",@"记忆",@"浏览器",@"MCP 服务",@"构建任务",@"Linux 沙盒"];
  NSArray *details=@[@"按需读取项目技能",@"按需读取本机记忆",@"让 AI 阅读当前公开网页",@"已授权的只读查询工具",@"查看构建队列和进度",@"会话内执行 Linux 命令，逐次确认"];
  NSArray *icons=@[@"text.book.closed",@"brain",@"globe",@"network",@"hammer",@"terminal"];
  NSInteger row=indexPath.row;
  return [self cell:modules[row] title:titles[row] detail:details[row] icon:icons[row]];
 }
 if([TFAIToolRegistry enabled:@"remote"]&&indexPath.row==0)return [self cell:@"remote" title:@"远程工作区状态" detail:@"只返回运行状态" icon:@"wifi"];
 return [self cell:@"isolation" title:@"隔离只读查询" detail:@"当前已开启；关闭后不再提供目标查询" icon:@"lock.shield"];
}
@end

UIViewController *TFAIToolRegistrySettingsController(void){return [[TFAIToolRegistrySettings alloc]initWithStyle:UITableViewStyleInsetGrouped];}

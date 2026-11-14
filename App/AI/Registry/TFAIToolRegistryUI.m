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
  NSArray *details=@[@"按需读取项目技能",@"按需读取本机记忆",@"让 AI 阅读当前公开网页",@"逐项启用，交互调用需确认",@"查看构建队列和进度",@"会话内执行 Linux 命令，逐次确认"];
  NSArray *icons=@[@"text.book.closed",@"brain",@"globe",@"network",@"hammer",@"terminal"];
  NSInteger row=indexPath.row;
  return [self cell:modules[row] title:titles[row] detail:details[row] icon:icons[row]];
 }
 if([TFAIToolRegistry enabled:@"remote"]&&indexPath.row==0)return [self cell:@"remote" title:@"远程工作区状态" detail:@"只返回运行状态" icon:@"wifi"];
 return [self cell:@"isolation" title:@"隔离只读查询" detail:@"当前已开启；关闭后不再提供目标查询" icon:@"lock.shield"];
}
@end

UIViewController *TFAIToolRegistrySettingsController(void){return [[TFAIToolRegistrySettings alloc]initWithStyle:UITableViewStyleInsetGrouped];}

@interface TFAIWorkspaceToolSettings : UITableViewController
@property NSString *root;
@property NSArray *names;
@end
@implementation TFAIWorkspaceToolSettings
- (void)viewDidLoad{[super viewDidLoad];self.title=@"当前项目工具";self.names=TFAIToolRegistry.toolNames;self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=76;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return self.names.count;}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{return @"此处只限制当前项目。开启不代表已获授权；设备能力、会话开关和人工审批仍然生效。关闭会从模型工具列表移除，已在途调用也会在执行前被拒绝。";}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{NSString *name=self.names[i.row];NSDictionary *d=[TFAIToolRegistry descriptor:name];NSDictionary *titles=@{@"read_file":@"读取项目文件",@"list_files":@"浏览项目文件",@"search_text":@"搜索源码",@"list_symbols":@"查找代码符号",@"read_context":@"读取历史记录",@"propose_patch":@"生成修改提案",@"apply_approved_patch":@"应用已审核修改",@"build_project":@"构建当前项目",@"clean_builds":@"清理构建缓存",@"cancel_build":@"取消构建",@"list_artifacts":@"查看构建产物",@"binary_inspect":@"分析已选二进制",@"binary_obfuscation_scan":@"检查混淆特征",@"classdump_export":@"导出类头文件",@"classdump_headers":@"查看类头文件",@"agent_skill_read":@"按需读取技能",@"agent_memory_read":@"检索本机记忆",@"agent_build_tasks":@"查询构建进度",@"subtask_task":@"分派构建/分析子任务",@"web_browse":@"会话浏览器",@"web_search":@"联网检索",@"web_read":@"读取网页正文",@"read_attachment":@"读取已选附件",@"sandbox_execute":@"运行 Linux 命令",@"sandbox_files":@"浏览 Linux 文件",@"sandbox_process_start":@"启动 Linux 进程",@"sandbox_process_read":@"读取 Linux 进程输出",@"sandbox_process_write":@"向 Linux 进程输入",@"sandbox_process_stop":@"停止 Linux 进程",@"sandbox_import_attachment":@"复制附件到 Linux",@"sandbox_export_file":@"审核 Linux 文件写回",@"sandbox_reverse":@"Linux 逆向工具",@"flex_live_read":@"查询 FLEX 现场",@"flex_sensitive_read":@"读取 FLEX 详细信息",@"flex_control":@"操作已配对 FLEX"};NSString *effect=@{@"read":@"只读",@"write":@"可修改",@"mixed":@"含读取与操作"}[d[@"effect"]]?:@"受限操作";NSString *tier=@{@"A":@"应用内能力",@"B":@"需授权扩展",@"C":@"隔离能力 · 默认关闭"}[d[@"tier"]]?:@"扩展";NSString *approval=[d[@"requiresUserApproval"] boolValue]?@"仍需当前权限/确认":@"不授予写权限";UITableViewCell *cell=AICell(titles[name]?:name,[NSString stringWithFormat:@"%@ · %@ · %@\n%@",tier,effect,approval,name],@"wrench.and.screwdriver");UISwitch *toggle=[UISwitch new];toggle.on=![[TFAIToolRegistry disabledTools:self.root] containsObject:name];toggle.accessibilityLabel=[@"允许当前项目使用 " stringByAppendingString:name];[toggle addAction:[UIAction actionWithHandler:^(UIAction *a){[TFAIToolRegistry setTool:name enabled:toggle.on root:self.root];}] forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;return cell;}
@end
UIViewController *TFAIWorkspaceToolSettingsController(NSString *root){TFAIWorkspaceToolSettings *page=[[TFAIWorkspaceToolSettings alloc]initWithStyle:UITableViewStyleInsetGrouped];page.root=root;return page;}

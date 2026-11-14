#import "../Registry/TFAIToolRegistry.h"
#import "TFAIBuildQueue.h"
#import "../../Studio.h"
extern BOOL TMCBuildIsRunning(void);
#import "../Background/TFAIBackground.h"
#import "../Background/TFAINotifications.h"
#import "../LiveActivity/TFAILiveActivity.h"
#import "../UI/TFAIUIHelpers.h"
#import "../Providers/TFAIProtocol.h"
#include "TFAIBuildQueueCore.inc"
@interface TFAIBuildTasks : UITableViewController
@property NSTimer *timer;
@property NSArray *rows;
@end
@implementation TFAIBuildTasks
- (void)viewDidLoad{[super viewDidLoad];self.title=@"构建任务队列";self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=82;}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self reload];__weak typeof(self) weak=self;self.timer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *t){[weak reload];}];}
- (void)viewDidDisappear:(BOOL)animated{[super viewDidDisappear:animated];[self.timer invalidate];self.timer=nil;}
- (void)reload{self.rows=[TFAIBuildQueue.shared.tasks reverseObjectEnumerator].allObjects;[self.tableView reloadData];}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return self.rows.count;}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{return @"同一时间运行一个本机构建。取消在快照或编译步骤边界生效。失败与中断保留日志、产物路径和检查点；重新构建核对当前文件并沿用现有审批。后台运行仍受iOS系统调度。";}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{NSDictionary *j=self.rows[i.row];return AICell(j[@"name"],[NSString stringWithFormat:@"%@ · %.0f%%\n%@",j[@"state"],[j[@"progress"] doubleValue]*100,j[@"stage"]],@"hammer");}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{NSDictionary *j=self.rows[i.row];UIAlertController *a=[UIAlertController alertControllerWithTitle:j[@"name"] message:j[@"stage"] preferredStyle:UIAlertControllerStyleActionSheet];if([@[@"running",@"queued"] containsObject:j[@"state"]])[a addAction:[UIAlertAction actionWithTitle:@"取消任务" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x){[TFAIBuildQueue.shared cancel:j[@"id"]];[self reload];}]];if([@[@"failed",@"interrupted",@"cancelled"] containsObject:j[@"state"]])[a addAction:[UIAlertAction actionWithTitle:@"从检查点重新构建…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"重新构建当前项目？" message:@"这是一次新的本机构建。将重新核对当前源码、配置与SDK；只有校验一致的成功编译步骤可复用，失败步骤重跑。" preferredStyle:UIAlertControllerStyleAlert];[confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[confirm addAction:[UIAlertAction actionWithTitle:@"确认构建" style:UIAlertActionStyleDefault handler:^(UIAlertAction *y){if(!TMCStudioResumeBuild(j[@"root"],self.navigationController))AIAlert(self,@"项目已移动或删除",@"请从项目列表打开可用项目后重新构建。");}]];[self presentViewController:confirm animated:YES completion:nil];}]];[a addAction:[UIAlertAction actionWithTitle:@"查看检查点 / 结果" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){UIViewController *page=[UIViewController new];page.title=@"任务记录";UITextView *v=[[UITextView alloc]initWithFrame:page.view.bounds];v.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;v.editable=NO;v.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];v.text=[[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:j options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];[page.view addSubview:v];[self.navigationController pushViewController:page animated:YES];}]];[a addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=[t cellForRowAtIndexPath:i];[self presentViewController:a animated:YES completion:nil];}
@end
UIViewController *TFAIBuildQueueController(void){return [[TFAIBuildTasks alloc]initWithStyle:UITableViewStyleInsetGrouped];}

#import "TFAISubtasks.h"
#import "../UI/TFAIUIHelpers.h"
@interface TFAISubtaskPage : UITableViewController
@property NSString *session;
@property NSArray *rows;
@property NSTimer *timer;
@end
@implementation TFAISubtaskPage
- (void)viewDidLoad{[super viewDidLoad];self.title=@"专用子任务";self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=80;self.tableView.accessibilityIdentifier=@"agent-subtasks";}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self reload];__weak typeof(self) weak=self;self.timer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){[weak reload];}];}
- (void)viewDidDisappear:(BOOL)animated{[super viewDidDisappear:animated];[self.timer invalidate];self.timer=nil;}
- (void)reload{self.rows=[TFAISubtasks.shared tasks:self.session].reverseObjectEnumerator.allObjects;[self.tableView reloadData];}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return self.rows.count;}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{return @"构建与分析专用任务；每会话最多3个，深度固定1。子任务不继承写权限，修改及构建需独立审批。构建仍共用单活队列。取消保留部分结果；可明确继续。App 重启后请回原会话请求继续，以重新选择模型和核对项目，不自动重放。";}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{NSDictionary *row=self.rows[i.row];NSTimeInterval end=[row[@"finishedAt"] doubleValue]?:NSDate.date.timeIntervalSince1970;return AICell([row[@"kind"] isEqual:@"build"]?@"构建子任务":@"分析子任务",[NSString stringWithFormat:@"%@ · %.0f秒\n%@",row[@"state"],MAX(0,end-[row[@"startedAt"] doubleValue]),row[@"stage"]],@"list.bullet.rectangle");}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{NSDictionary *row=self.rows[i.row];UIAlertController *menu=[UIAlertController alertControllerWithTitle:row[@"state"] message:row[@"partial"]?:row[@"stage"] preferredStyle:UIAlertControllerStyleActionSheet];if([row[@"state"] isEqual:@"running"])[menu addAction:[UIAlertAction actionWithTitle:@"取消子任务" style:UIAlertActionStyleDestructive handler:^(id a){[TFAISubtasks.shared cancel:row[@"id"] parent:self.session];[self reload];}]];if([TFAISubtasks.shared canResume:row[@"id"] parent:self.session])[menu addAction:[UIAlertAction actionWithTitle:@"继续子任务" style:UIAlertActionStyleDefault handler:^(id a){NSError *error=nil;if(![TFAISubtasks.shared resume:row[@"id"] parent:self.session executor:nil error:&error])AIAlert(self,@"无法继续",error.localizedDescription);[self reload];}]];[menu addAction:[UIAlertAction actionWithTitle:@"查看结构化结果" style:UIAlertActionStyleDefault handler:^(id a){UIViewController *page=[UIViewController new];page.title=@"子任务结果";UITextView *text=[[UITextView alloc]initWithFrame:page.view.bounds];text.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;text.editable=NO;text.font=[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];text.text=[[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:row options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];[page.view addSubview:text];[self.navigationController pushViewController:page animated:YES];}]];[menu addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];menu.popoverPresentationController.sourceView=[t cellForRowAtIndexPath:i];[self presentViewController:menu animated:YES completion:nil];}
@end
UIViewController *TFAISubtaskController(NSString *session){TFAISubtaskPage *page=[[TFAISubtaskPage alloc]initWithStyle:UITableViewStyleInsetGrouped];page.session=session;return page;}

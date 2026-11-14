#import "TFAIISHMirrors.h"
#import "TFAIISHRuntime.h"
#import "../UI/TFAIUIHelpers.h"
// Fixed catalog only: no user URL interpolation into guest shell commands.
static NSArray *MirrorSources(void){
 NSMutableArray *rows=[NSMutableArray new];
 for(NSArray *source in @[@[@"Alpine 官方 CDN",@"https://dl-cdn.alpinelinux.org/alpine"],@[@"Alpine 官方主站",@"https://dl-3.alpinelinux.org/alpine"],@[@"清华镜像",@"https://mirrors.tuna.tsinghua.edu.cn/alpine"]]){
 NSString *base=source[1];[rows addObject:@{@"group":@"apk",@"name":source[0],@"url":[base stringByAppendingString:@"/v3.21/main/aarch64/APKINDEX.tar.gz"],@"command":[NSString stringWithFormat:@"set -e; v=$(cut -d. -f1,2 /etc/alpine-release); test \"$v\" = 3.21 -o \"$v\" = 3.22; test -f /etc/apk/repositories; cp -p /etc/apk/repositories /etc/apk/repositories.dylix-backup; printf '%@/v%%s/main\\n%@/v%%s/community\\n' \"$v\" \"$v\" > /etc/apk/repositories; cat /etc/apk/repositories",base,base]}];}
 for(NSArray *source in @[@[@"PyPI 官方",@"https://pypi.org/simple"],@[@"清华 PyPI 镜像",@"https://pypi.tuna.tsinghua.edu.cn/simple"]]){
 NSString *base=source[1];[rows addObject:@{@"group":@"pip",@"name":source[0],@"url":[base stringByAppendingString:@"/pip/"],@"command":[NSString stringWithFormat:@"set -e; command -v python3 >/dev/null; mkdir -p ~/.config/pip; if test -f ~/.config/pip/pip.conf; then cp -p ~/.config/pip/pip.conf ~/.config/pip/pip.conf.dylix-backup; fi; python3 -m pip config set global.index-url %@",base]}];}
 for(NSArray *source in @[@[@"npm 官方",@"https://registry.npmjs.org/"],@[@"npmmirror",@"https://registry.npmmirror.com/"]]){
 NSString *base=source[1];[rows addObject:@{@"group":@"npm",@"name":source[0],@"url":[base stringByAppendingString:@"npm"],@"command":[NSString stringWithFormat:@"set -e; command -v npm >/dev/null; if test -f ~/.npmrc; then cp -p ~/.npmrc ~/.npmrc.dylix-backup; fi; npm config set registry %@; npm config get registry",base]}];}
 return rows;
}
@interface DylixMirrorPage : UITableViewController
@property NSString *session;
@property NSArray *sources;
@property NSMutableDictionary *results,*latencies;
@property NSURLSession *network;
@property NSUInteger generation;
@end
@implementation DylixMirrorPage
- (void)viewDidLoad{[super viewDidLoad];self.title=@"包源测速与选择";self.sources=MirrorSources();self.results=[NSMutableDictionary new];self.latencies=[NSMutableDictionary new];self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=80;self.navigationItem.rightBarButtonItem=AIBar(@"speedometer",@"测试所有包源",self,@selector(probe));NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.timeoutIntervalForRequest=12;config.HTTPCookieStorage=nil;config.URLCache=nil;self.network=[NSURLSession sessionWithConfiguration:config];}
- (void)dealloc{[self.network invalidateAndCancel];}
- (NSDictionary *)fastest:(NSString *)group{NSDictionary *winner=nil;double best=DBL_MAX;for(NSDictionary *row in self.sources)if([row[@"group"] isEqual:group]&&self.latencies[row[@"url"]]){double value=[self.latencies[row[@"url"]] doubleValue];if(value<best){best=value;winner=row;}}return winner;}
- (void)probe{NSUInteger generation=++self.generation;[self.latencies removeAllObjects];for(NSDictionary *row in self.sources){NSString *url=row[@"url"];self.results[url]=@"测试中…";NSTimeInterval start=NSProcessInfo.processInfo.systemUptime;NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];request.HTTPMethod=@"HEAD";__weak typeof(self) weak=self;[[self.network dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){NSInteger status=[(NSHTTPURLResponse *)response statusCode];double elapsed=(NSProcessInfo.processInfo.systemUptime-start)*1000;dispatch_async(dispatch_get_main_queue(),^{if(weak.generation!=generation)return;weak.results[url]=error?error.localizedDescription:[NSString stringWithFormat:@"HTTP %ld · %.0f ms",(long)status,elapsed];if(!error&&status>=200&&status<300)weak.latencies[url]=@(elapsed);[weak.tableView reloadData];});}] resume];}[self.tableView reloadData];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{return 3;}
- (NSString *)group:(NSInteger)section{return @[@"apk",@"pip",@"npm"][section];}
- (NSArray *)rows:(NSInteger)section{NSString *group=[self group:section];return [self.sources filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"group == %@",group]];}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return [self rows:s].count+1;}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s{return [self group:s];}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{return @"匿名 HEAD 测试仅代表本机连接耗时，不代表 guest 下载速度或安装成功。确认后才修改当前会话源并备份原配置。第三方镜像可能有同步延迟；保留 TLS 与 apk 签名校验，不自动安装。";}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{NSArray *rows=[self rows:i.section];if(i.row==rows.count){NSDictionary *fastest=[self fastest:[self group:i.section]];UITableViewCell *cell=AICell(@"应用本组最快源",fastest?fastest[@"name"]:@"先测试，按成功连接耗时选择",@"bolt");cell.userInteractionEnabled=fastest!=nil;cell.textLabel.enabled=fastest!=nil;return cell;}NSDictionary *row=rows[i.row];return AICell(row[@"name"],[NSString stringWithFormat:@"%@\n%@",self.results[row[@"url"]]?:@"尚未测试",row[@"url"]],@"network");}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{[t deselectRowAtIndexPath:i animated:YES];NSArray *rows=[self rows:i.section];NSDictionary *row=i.row==rows.count?[self fastest:[self group:i.section]]:rows[i.row];if(!row)return;UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"应用到当前 Linux 会话？" message:[NSString stringWithFormat:@"%@\n%@\n仅更改此包管理器的来源，不安装软件。",row[@"name"],row[@"url"]] preferredStyle:UIAlertControllerStyleAlert];[confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[confirm addAction:[UIAlertAction actionWithTitle:@"备份并应用" style:UIAlertActionStyleDefault handler:^(id a){[TFAIISHRuntime.shared execute:row[@"command"] session:self.session timeout:20 output:nil completion:^(NSDictionary *result,NSError *error){BOOL ok=!error&&[result[@"exit_code"] intValue]==0;AIAlert(self,ok?@"已应用":@"未成功应用",error.localizedDescription?:result[@"output"]?:@"请检查终端工具安装状态");}];}]];[self presentViewController:confirm animated:YES completion:nil];}
@end
UIViewController *TFAIISHMirrorController(NSString *session){DylixMirrorPage *page=[[DylixMirrorPage alloc]initWithStyle:UITableViewStyleInsetGrouped];page.session=session;return page;}

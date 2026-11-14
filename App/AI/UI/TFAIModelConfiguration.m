#import "TFAIModelConfiguration.h"
#import "TFAIUIHelpers.h"
#import "TFAITestDetail.h"
#import "../Providers/TFAIProtocol.h"
#import "../Providers/TFAIRegistry.h"
static NSDictionary *WireNames(void){return @{@"reasoning_effort":@"OpenAI · reasoning_effort",@"reasoning":@"Responses / OpenRouter · reasoning.effort",@"thinking":@"DeepSeek / GLM · thinking.type",@"enable_thinking":@"硅基流动 / Qwen · enable_thinking",@"thinking_budget":@"Qwen · 开关与 token 预算",@"chat_template_kwargs":@"vLLM · chat_template_kwargs",@"anthropic_budget":@"Claude · thinking 预算",@"anthropic_adaptive":@"Claude · adaptive + effort",@"gemini_budget":@"Gemini · thinkingBudget",@"gemini_level":@"Gemini · thinkingLevel",@"disabled":@"不发送思考参数"};}
@interface TFAIModelConfiguration : UITableViewController
@property NSMutableDictionary *connection;
@property(copy) void(^changed)(NSDictionary *);
@property TFAITransport *transport;
@property BOOL testing;
@end
@implementation TFAIModelConfiguration
- (void)viewDidLoad{[super viewDidLoad];self.title=@"模型能力与思考适配";self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=60;self.navigationItem.rightBarButtonItem=AIBar(@"xmark",@"完成",self,@selector(close));}
- (void)close{[self dismissViewControllerAnimated:YES completion:nil];}
- (NSArray *)levelIDs{return TFAIThinkingLevelsForWire(self.override[@"wire"]?:TFAIThinkingConfiguration(self.connection)[@"wire"]);}
- (NSDictionary *)override{return self.connection[@"thinkingOverrides"][TFAIThinkingScope(self.connection)]?:@{};}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{return 4;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return s==0?2:s==1?(self.override.count&&![self.override[@"wire"] isEqual:@"disabled"]?1+self.levelIDs.count:1):s==2?5:2;}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s{return @[@"图片与工具",@"思考接口与档位",@"识别来源",@"验证与恢复"][s];}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{
 if(s==0)return @"无需先测试。点击切换自动识别 / 手动启用 / 手动禁用；未知能力允许直接尝试。手动启用仅允许尝试该能力，不代表服务已实测支持，也不会授予本机工具权限。";
 if(s==1)return @"自动按端点、协议、服务声明和模型族适配。中转使用别名或特殊参数时可手动指定；默认不发送额外思考参数。选定接口后可勾选它实际支持的档位，配置仅作用于此连接、端点与模型。";
 if(s==2)return @"服务声明、模型族建议和实际响应验证分别显示。支持思考不等于支持调节强度；开关型接口只提供开关。";
 return @"测试为可选诊断，不影响功能启用；只发送内置题目，可能产生少量 API 用量。参数被接受但没有思考摘要或 reasoning token 用量时显示未证实，不判为不支持。";
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{
 if(i.section==0){NSString *key=@[@"image",@"tools"][i.row],*mode=self.connection[@"capabilityOverrides"][TFAICapabilityScope(self.connection)][key];NSDictionary *resolved=TFAIResolvedCapability(self.connection,key);NSString *state=@{@"supported":@"支持",@"unsupported":@"禁用",@"unknown":@"未声明，可尝试"}[resolved[@"state"]];return AICell(i.row?@"工具调用":@"图片理解",[NSString stringWithFormat:@"%@ · %@\n%@",mode?([mode isEqual:@"supported"]?@"手动启用":@"手动禁用"):@"自动识别",state,resolved[@"source"]],i.row?@"wrench.and.screwdriver":@"photo");}
 if(i.section==1){if(!i.row){NSString *wire=TFAIThinkingConfiguration(self.connection)[@"wire"];return AICell(@"思考接口",[NSString stringWithFormat:@"%@ · %@",self.override.count?@"手动":@"自动",WireNames()[wire]?:wire],@"slider.horizontal.3");}NSString *level=self.levelIDs[i.row-1];UITableViewCell *cell=AICell(level,@{@"none":@"显式关闭，仅适用于支持关闭值的接口",@"enabled":@"仅开启思考，不承诺强度"}[level],@"brain");cell.accessoryType=[self.override[@"levels"] containsObject:level]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;return cell;}
 if(i.section==2){NSString *key=@[@"text",@"stream",@"image",@"tools",@"thinking"][i.row];NSDictionary *resolved=TFAIResolvedCapability(self.connection,key);NSString *title=@[@"文本响应",@"流式响应",@"图片理解",@"工具调用",@"深度思考"][i.row];NSString *detail=[NSString stringWithFormat:@"%@ · %@",@{@"supported":@"支持",@"unsupported":@"不支持/已禁用",@"unknown":@"未声明，可尝试"}[resolved[@"state"]],resolved[@"source"]];if([key isEqual:@"thinking"])detail=[detail stringByAppendingFormat:@"\n%@",TFAIThinkingConfiguration(self.connection)[@"source"]];return AICell(title,detail,@"info.circle");}
 return AICell(i.row?@"恢复此模型自动适配":self.testing?@"正在测试思考参数…":@"测试当前思考参数",i.row?@"清除此端点、模型的手动配置":@"不发送项目文件和会话内容",i.row?@"arrow.counterclockwise":@"checkmark.shield");
}
- (void)persist{
 NSMutableDictionary *saved=nil;for(NSDictionary *c in TFAIConnections.all)if([c[@"id"] isEqual:self.connection[@"id"]])saved=[c mutableCopy];
 if(!saved)saved=[self.connection mutableCopy];for(NSString *key in @[@"thinkingOverrides",@"capabilityOverrides"])saved[key]=self.connection[key]?:@{};
 NSError *error=nil;if(![TFAIConnections save:saved secret:nil error:&error]){AIAlert(self,@"配置未保存",error.localizedDescription);return;}
 if(self.changed)self.changed(self.connection);[self.tableView reloadData];
}
- (void)chooseWire:(NSIndexPath *)index{
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"选择思考接口" message:@"按当前服务实际接受的参数选择，不确定时保留自动。" preferredStyle:UIAlertControllerStyleActionSheet];
 for(NSString *wire in [@[@"automatic"] arrayByAddingObjectsFromArray:TFAIThinkingWires(self.connection[@"protocol"]?:@"chat")]){
  [sheet addAction:[UIAlertAction actionWithTitle:WireNames()[wire]?:@"自动识别" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSMutableDictionary *map=[self.connection[@"thinkingOverrides"] mutableCopy]?:[NSMutableDictionary new];NSString *scope=TFAIThinkingScope(self.connection);if([wire isEqual:@"automatic"])[map removeObjectForKey:scope];else{NSArray *levels=[wire isEqual:@"disabled"]?@[]:[@[@"enable_thinking",@"chat_template_kwargs",@"thinking"] containsObject:wire]?@[@"enabled"]:@[@"low",@"medium",@"high"];map[scope]=@{@"wire":wire,@"levels":levels};}self.connection[@"thinkingOverrides"]=map;[self persist];}]];
 }
 [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];sheet.popoverPresentationController.sourceView=[self.tableView cellForRowAtIndexPath:index];sheet.popoverPresentationController.sourceRect=sheet.popoverPresentationController.sourceView.bounds;[self presentViewController:sheet animated:YES completion:nil];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{
 [t deselectRowAtIndexPath:i animated:YES];if(self.testing)return;
 if(i.section==0){NSString *scope=TFAICapabilityScope(self.connection),*key=@[@"image",@"tools"][i.row];NSMutableDictionary *map=[self.connection[@"capabilityOverrides"] mutableCopy]?:[NSMutableDictionary new],*row=[map[scope] mutableCopy]?:[NSMutableDictionary new];NSString *value=row[key];if(!value)row[key]=@"supported";else if([value isEqual:@"supported"])row[key]=@"unsupported";else[row removeObjectForKey:key];map[scope]=row;self.connection[@"capabilityOverrides"]=map;[self persist];}
 else if(i.section==1){if(!i.row){[self chooseWire:i];return;}NSMutableDictionary *map=[self.connection[@"thinkingOverrides"] mutableCopy]?:[NSMutableDictionary new],*entry=[self.override mutableCopy];NSMutableArray *levels=[entry[@"levels"] mutableCopy]?:[NSMutableArray new];NSString *level=self.levelIDs[i.row-1];if([levels containsObject:level])[levels removeObject:level];else[levels addObject:level];entry[@"levels"]=levels;map[TFAIThinkingScope(self.connection)]=entry;self.connection[@"thinkingOverrides"]=map;[self persist];}
 else if(i.section==3&&i.row==1){for(NSString *key in @[@"thinkingOverrides",@"capabilityOverrides"]){NSMutableDictionary *map=[self.connection[key] mutableCopy]?:[NSMutableDictionary new];[map removeObjectForKey:[key isEqual:@"thinkingOverrides"]?TFAIThinkingScope(self.connection):TFAICapabilityScope(self.connection)];self.connection[key]=map;}[self persist];}
 else if(i.section==3){self.testing=YES;[t reloadData];self.transport=[TFAITransport new];__weak typeof(self) weak=self;[self.transport probe:self.connection capability:@"thinking" completion:^(NSDictionary *result,NSError *error){if(!weak)return;weak.testing=NO;[weak.tableView reloadData];NSDictionary *record=TFAIRecordProbeResult(weak.connection,@"thinking",result,error);if(weak.changed)weak.changed([weak.connection copy]);[weak.navigationController pushViewController:TFAITestDetailController(weak.connection,@"thinking",record,NO) animated:YES];}];}
}
- (void)dealloc{[_transport cancel];}
@end
UIViewController *TFAIModelConfigurationController(NSDictionary *connection,void(^changed)(NSDictionary *)){TFAIModelConfiguration *page=[[TFAIModelConfiguration alloc]initWithStyle:UITableViewStyleInsetGrouped];page.connection=[connection mutableCopy];page.changed=changed;return page;}

#import <Foundation/Foundation.h>
#import "../App/AI/Core/TFAITaskPlan.h"
static NSString *Text(id v){return [v isKindOfClass:NSString.class]?v:@"";}
static NSData *Encode(id v){return [NSJSONSerialization dataWithJSONObject:v options:NSJSONWritingSortedKeys error:nil];}
static NSString *JSON(id v){return [[NSString alloc] initWithData:Encode(v) encoding:NSUTF8StringEncoding];}
static NSString *Prefix(NSString *s,NSUInteger n){return [s substringToIndex:MIN(n,s.length)];}
static id Preview(id v,NSUInteger n){return v;}
#import "../App/AI/Core/TFAIWorkingContext.h"
static NSUInteger checks=0;
static void Check(BOOL ok,NSString *msg){checks++;if(!ok){NSLog(@"FAIL %@",msg);exit(1);}}
static void Add(NSMutableArray *m,NSString *tool,NSDictionary *value){NSString *cid=NSUUID.UUID.UUIDString;[m addObject:@{@"role":@"assistant",@"tool_calls":@[@{@"id":cid,@"name":tool}]}];[m addObject:@{@"role":@"tool",@"tool_call_id":cid,@"content":JSON(value)}];}
static NSDictionary *Source(NSString *version,NSNumber *line,NSString *content){return @{@"path":@"Main.xm",@"sha256":version,@"start_line":line,@"content":content};}
int main(){@autoreleasepool{

 for(NSUInteger n=1;n<=200;n++){
  NSMutableArray *lines=[NSMutableArray new];for(NSUInteger j=0;j<n+6;j++)[lines addObject:[NSString stringWithFormat:@"line-%lu",(unsigned long)j]];
  NSString *a=[[[lines subarrayWithRange:NSMakeRange(0,n+2)] componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
  NSString *b=[[[lines subarrayWithRange:NSMakeRange(n,6)] componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
  NSString *expected=[[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
  NSDictionary *merged=TFAIMergeWorkingSource(Source(@"v",@1,a),Source(@"v",@(n+1),b));Check([merged[@"content"] isEqual:expected],@"overlap merge preserves exact source text");
  Check(!TFAIMergeWorkingSource(Source(@"v1",@1,a),Source(@"v2",@(n+1),b)),@"different file versions cannot merge");
  Check(!TFAIMergeWorkingSource(Source(@"v",@1,a),Source(@"v",@1,@"conflicting text")),@"conflicting overlap cannot merge");
 }

 for(NSUInteger seed=0;seed<100;seed++)for(NSNumber *budget in @[@2048,@4096,@8192,@16384]){
  NSMutableArray *lines=[NSMutableArray new];for(NSUInteger n=0;n<1200;n++)[lines addObject:[NSString stringWithFormat:@"int filler_%lu(void) { return %lu; }",(unsigned long)n,(unsigned long)n]];
  NSString *identifier=[NSString stringWithFormat:@"target_%lu",(unsigned long)seed];NSString *target=[NSString stringWithFormat:@"int %@(void) { return 9876; }",identifier];lines[700+seed]=target;lines[3]=[NSString stringWithFormat:@"int %@0(void) { return -1; }",identifier];NSString *original=[[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
  NSMutableArray *history=[@[@{@"role":@"user",@"content":[@"Change only " stringByAppendingString:identifier]}] mutableCopy];Add(history,@"read_file",Source(@"v-current",@1,original));NSDictionary *working=TFAIWorkingContextWithBudget(history,budget.unsignedIntegerValue);NSDictionary *source=[working[@"evidence"] firstObject][@"source"];
  Check([source[@"content"] containsString:target],@"tight workspace prioritizes exact latest-user identifier beyond source prefix");Check([source[@"start_line"] unsignedIntegerValue]>600&&[source[@"sha256"] isEqual:@"v-current"],@"identifier prefix collisions cannot select an unrelated earlier function");
  NSUInteger start=[source[@"start_line"] unsignedIntegerValue]-1;NSString *remainder=[[[lines subarrayWithRange:NSMakeRange(start,lines.count-start)] componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];Check([remainder hasPrefix:source[@"content"]]&&Encode(working).length<=budget.unsignedIntegerValue+1024,@"selected source is an exact bounded excerpt with correct absolute line");
 }
 NSError *error=nil;NSDictionary *args=@{@"steps":@[@{@"content":@"Implement then verify",@"status":@"in_progress"}]};NSDictionary *plan=TFAITaskPlanResult(args,&error);Check(plan&&!error&&[plan[@"model_reported"] boolValue]&&![plan[@"execution_verified"] boolValue],@"plan does not fabricate verified execution");
 for(id bad in @[@{},@{@"steps":@"wrong"},@{@"steps":@[@{@"content":@"test",@"status":@"verified"}]},@{@"steps":@[@{@"content":@"",@"status":@"completed"}]},@{@"steps":@[],@"execute":@YES},@{@"steps":@[@{@"content":@"test",@"status":@"pending",@"extra":@1}]}])Check(!TFAITaskPlanResult(bad,&error),@"invalid plan rejected");
 NSMutableArray *many=[NSMutableArray new];for(int i=0;i<21;i++)[many addObject:args[@"steps"][0]];Check(!TFAITaskPlanResult(@{@"steps":many},nil),@"unbounded plan rejected");
 NSMutableArray *m=[NSMutableArray new];Add(m,@"update_plan",plan);Add(m,@"read_file",Source(@"old",@1,@"OLD_SOURCE"));Add(m,@"read_file",Source(@"new",@10,@"NEW_SOURCE"));Add(m,@"read_file",Source(@"old",@20,@"OLD_OTHER_PAGE"));Add(m,@"read_file",Source(@"new",@1,@"NEW_FIRST_PAGE"));
 Add(m,@"read_context",@{@"historical":@YES,@"text":JSON(Source(@"old",@1,@"OLD_ARCHIVED_SOURCE"))});
 NSDictionary *w=TFAIWorkingContext(m);NSString *wire=JSON(w);Check([wire containsString:@"NEW_SOURCE"]&&[wire containsString:@"NEW_FIRST_PAGE"]&&![wire containsString:@"OLD_SOURCE"]&&![wire containsString:@"OLD_OTHER_PAGE"],@"all retained pages use latest observed file version");Check(![wire containsString:@"OLD_ARCHIVED_SOURCE"],@"later historical readback cannot supersede current live version");Check([w[@"task_plan"] isEqual:plan],@"plan survives unrelated reads");
 NSDictionary *clear=TFAITaskPlanResult(@{@"steps":@[]},nil);Add(m,@"update_plan",clear);Check([TFAIWorkingContext(m)[@"task_plan"] isEqual:clear],@"cleared plan never resurrects earlier plan");
 Add(m,@"update_plan",@{@"error":@"failed"});Check([TFAIWorkingContext(m)[@"task_plan"] isEqual:clear],@"failed plan update preserves prior state");
 for(int i=0;i<6;i++){NSMutableString *text=[NSMutableString new];for(int j=0;j<1500;j++)[text appendString:@"abc"];Add(m,@"read_development_guide",@{@"readOnly":@YES,@"topic":[NSString stringWithFormat:@"topic%d",i],@"content":text});}
 Check([JSON(TFAIWorkingContext(m)) containsString:@"NEW_FIRST_PAGE"],@"later guide flood cannot evict current file evidence");
 Add(m,@"apply_approved_patch",@{@"status":@"applied",@"files":@[@"Main.xm"]});wire=JSON(TFAIWorkingContext(m));Check(![wire containsString:@"NEW_FIRST_PAGE"]&&! [wire containsString:@"NEW_SOURCE"],@"successful write invalidates prior snapshots");
 Check([TFAITaskPlanSchema()[@"parameters"][@"required"] containsObject:@"steps"],@"plan schema requires replacement steps");
 printf("PASS %lu working-context and task-plan checks\n",checks);
}return 0;}

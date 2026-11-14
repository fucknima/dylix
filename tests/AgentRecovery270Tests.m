#undef main
#define main LegacyBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
static BOOL Has270(NSArray *messages,NSString *needle){for(NSDictionary *m in messages)if([m[@"content"] containsString:needle])return YES;return NO;}
int BudgetFixtureMain(){@autoreleasepool{
 NSUInteger responsiveCompleted=0,responsivePaused=0,hostilePaused=0,recoveries=0,totalRequests=0,totalReads=0,totalUseful=0,paired=0;NSMutableArray *rows=[NSMutableArray new];
 for(NSString *protocol in @[@"chat",@"responses",@"gemini"])for(NSUInteger seed=0;seed<30;seed++)for(NSNumber *hostile in @[@NO,@YES]){
  mode=@"wait";events=[NSMutableArray new];__block NSUInteger calls=0,reads=0,useful=0,seenRecovery=0;__block NSDictionary *terminal=nil;__block BOOL fetched=NO;
  FixtureTransport=^(NSArray *messages,NSArray *schemas,TFAIEvent e){calls++;BOOL recovery=Has270(messages,@"[DYLIX_RECOVERY]");if(recovery)seenRecovery++;if(fetched&&!hostile.boolValue){e(@{@"type":@"text",@"text":@"已使用已有证据并获取缺失源码，完成本次分析。"});e(@{@"type":@"done"});return;}
   if(recovery&&!hostile.boolValue){if(!fetched){fetched=YES;useful++;e(@{@"type":@"tool_call",@"id":[NSString stringWithFormat:@"useful-%lu",(unsigned long)calls],@"name":@"read_file",@"arguments":@{@"path":@"Missing.m"}});e(@{@"type":@"done"});}else{e(@{@"type":@"text",@"text":@"已使用已有证据并获取缺失源码，完成本次分析。"});e(@{@"type":@"done"});}return;}
   if(calls>35){e(@{@"type":@"text",@"text":@"TEST_DRIVER_SAFETY_LIMIT"});e(@{@"type":@"done"});return;}
   reads++;NSDictionary *args=seed%3==0?@{@"ref":@"result:original"}:seed%3==1?@{@"ref":@"result:original",@"offset":@0,@"limit":@100}:@{@"ref":@"result:original",@"offset":@(calls%2?0:20),@"limit":@100};e(@{@"type":@"tool_call",@"id":[NSString stringWithFormat:@"loop-%lu",(unsigned long)calls],@"name":@"read_context",@"arguments":args});e(@{@"type":@"done"});
  };
  NSMutableString *body=[NSMutableString new];for(int n=0;n<20;n++)[body appendFormat:@"unchanged evidence %d\n",n];NSArray *input=@[@{@"role":@"user",@"content":@"Analyze this task using evidence; read Missing.m if needed."},@{@"role":@"assistant",@"content":@"",@"tool_calls":@[@{@"id":@"original",@"name":@"read_file",@"arguments":@{@"path":@"Original.m"}}]},@{@"role":@"tool",@"tool_call_id":@"original",@"content":body}];
  TFProjectAIRuntime *r=(id)TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);[r activateSession:@"fixture"];r.nextConnection=@{@"model":@"fixture",@"protocol":protocol};r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])terminal=e;};[r send:input session:@"fixture"];
  Check(terminal!=nil,@"closed-loop trajectory reaches terminal state");BOOL done=[terminal[@"state"] isEqual:@"completed"]&&fetched;BOOL paused=[terminal[@"state"] isEqual:@"paused"];
  if(hostile.boolValue){hostilePaused+=paused;Check(paused,@"unresponsive model stops within bounded duplicate window");}else{responsiveCompleted+=done;responsivePaused+=paused;}
  if(fetched)Check(done,@"recovery requires actual missing-source tool before completion");
  NSMutableSet *ids=[NSMutableSet new],*results=[NSMutableSet new];for(NSDictionary *m in terminal[@"messages"]){for(NSDictionary *c in m[@"tool_calls"])[ids addObject:c[@"id"]];if(m[@"tool_call_id"])[results addObject:m[@"tool_call_id"]];}Check([ids isEqual:results],@"recovery preserves all call/result pairs");paired++;Check(calls<=35,@"no recovery request storm");
  recoveries+=seenRecovery>0;totalRequests+=calls;totalReads+=reads;totalUseful+=useful;[rows addObject:@{@"protocol_fixture":protocol,@"seed":@(seed),@"unresponsive":hostile,@"requests":@(calls),@"history_reads":@(reads),@"useful_reads":@(useful),@"recovery_seen":@(seenRecovery>0),@"state":terminal[@"state"]?:@"missing"}];
 }
 NSDictionary *report=@{@"kind":@"scripted_model_runtime_closed_loop_not_online_models",@"trajectories":@(rows.count),@"responsive_completed_with_useful_read":@(responsiveCompleted),@"responsive_paused":@(responsivePaused),@"unresponsive_bounded_pause":@(hostilePaused),@"trajectories_with_recovery":@(recoveries),@"total_requests":@(totalRequests),@"historical_reads":@(totalReads),@"useful_reads":@(totalUseful),@"paired_trajectories":@(paired),@"rows":rows};NSString *path=NSProcessInfo.processInfo.environment[@"DYLIX_RECOVERY_REPORT"];if(path.length)[RunProgressJSON(report) writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];NSLog(@"RECOVERY270 trajectories=%lu responsiveCompleted=%lu responsivePaused=%lu hostilePaused=%lu requests=%lu historicalReads=%lu usefulReads=%lu",(unsigned long)rows.count,(unsigned long)responsiveCompleted,(unsigned long)responsivePaused,(unsigned long)hostilePaused,(unsigned long)totalRequests,(unsigned long)totalReads,(unsigned long)totalUseful);

 // Exercise the actual streaming runtime, separately from the pure detector.
 for(NSNumber *intentional in @[@NO,@YES]){
  __block NSDictionary *end=nil;__block NSUInteger requests=0;NSMutableString *repeated=[NSMutableString new];for(int i=0;i<20;i++)[repeated appendString:@"这是相同的一段自然语言输出，用来核对流式重复检测确实生效。"];
  FixtureTransport=^(NSArray *m,NSArray *s,TFAIEvent e){requests++;for(NSUInteger offset=0;offset<repeated.length;offset+=80)e(@{@"type":@"text",@"text":[repeated substringWithRange:NSMakeRange(offset,MIN(80,repeated.length-offset))]});e(@{@"type":@"done"});};
  TFProjectAIRuntime *r=(id)TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);[r activateSession:@"stream"];r.nextConnection=@{@"model":@"fixture"};r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};[r send:@[@{@"role":@"user",@"content":intentional.boolValue?@"重复输出这句话 20 次":@"分析这个问题"}] session:@"stream"];
  Check([end[@"state"] isEqual:intentional.boolValue?@"completed":@"paused"],@"stream guard respects explicit repeat request");Check(requests==1,@"stream repetition never auto retries");
 }
 FixtureTransport=nil;
}return 0;}

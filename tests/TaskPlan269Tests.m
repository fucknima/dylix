#undef main
#define main LegacyBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
int BudgetFixtureMain(){@autoreleasepool{
 for(NSString *requestMode in @[@"agent",@"ask"]){
 __block NSUInteger count=0;__block NSDictionary *end=nil;__block NSArray *next=nil;mode=@"wait";events=[NSMutableArray new];
 FixtureTransport=^(NSArray *m,NSArray *schemas,TFAIEvent e){count++;if(count==1){BOOL found=NO;for(NSDictionary *s in schemas)if([s[@"name"] isEqual:@"update_plan"])found=YES;Check(found,@"task plan advertised through real registry");e(@{@"type":@"tool_call",@"id":@"plan-fixture",@"name":@"update_plan",@"arguments":@{@"steps":@[@{@"content":@"Inspect selected source",@"status":@"in_progress"}]}});e(@{@"type":@"done"});}else{next=m;e(@{@"type":@"text",@"text":@"继续实际工作"});e(@{@"type":@"done"});}};
 TFProjectAIRuntime *r=(id)TFAICreateRuntime(@"",@"general",nil);[r activateSession:@"plan-fixture-session"];r.requestMode=requestMode;r.event=^(NSDictionary *event){if([event[@"type"] isEqual:@"done"])end=event;};[r send:@[@{@"role":@"user",@"messageID":@"user-goal",@"content":@"inspect"}] session:@"plan-fixture-session"];
 Check(count==2&&[end[@"state"] isEqual:@"completed"],@"plan executes without project, bridge or approval in agent and ask modes");NSDictionary *plan=nil;for(NSDictionary *m in next)if([m[@"role"] isEqual:@"tool"]&&[m[@"tool_call_id"] isEqual:@"plan-fixture"])plan=[NSJSONSerialization JSONObjectWithData:[m[@"content"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];Check([plan[@"model_reported"] boolValue]&&![plan[@"execution_verified"] boolValue]&&[plan[@"user_message_id"] isEqual:@"user-goal"],@"normal transcript persists bounded progress associated with user message");
 }
 NSLog(@"PASS task plan real runtime integration");
}return 0;}

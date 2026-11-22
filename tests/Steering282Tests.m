#define main ExistingBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
int main(){@autoreleasepool{
 [TFAIToolRegistry setEnabled:NO module:@"memory"];
 FixtureToolSchemas=@[@{@"name":@"read_file",@"parameters":@{@"type":@"object",@"properties":@{@"path":@{@"type":@"string"}},@"required":@[@"path"]}}];
 for(NSUInteger scenario=0;scenario<3;scenario++){
  requests=executions=FixtureTransportCancels=0;__block TFAIEvent oldEvent=nil;__block NSArray *saved=nil;__block BOOL newInput=NO,skipped=NO;
  FixtureTransport=^(NSArray *messages,NSArray *tools,TFAIEvent event){
   if(requests==1){oldEvent=[event copy];if(scenario!=1)event(@{@"type":@"text",@"text":@"partial answer"});if(scenario==2)event(@{@"type":@"tool_call",@"id":@"unexecuted",@"name":@"read_file",@"arguments":@{@"path":@"old.txt"}});return;}
   NSUInteger count=0;for(NSDictionary *m in messages){if([m[@"content"] isEqual:@"new direction"])count++;if([m[@"tool_call_id"] isEqual:@"unexecuted"]&&[m[@"content"] containsString:@"notExecuted"])skipped=YES;}
   newInput=count==1;event(@{@"type":@"text",@"text":@"new answer"});event(@{@"type":@"done"});
  };
  id<TFAIRuntimeV2> runtime=(id)TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);runtime.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])saved=e[@"messages"];};[runtime activateSession:@"steer"];[runtime send:@[@{@"role":@"user",@"content":@"original"}] session:@"steer"];
  Check([runtime enqueueUserMessage:@{@"role":@"user",@"content":@"new direction"}],@"accept steering while streaming");
  Check(requests==2&&newInput&&FixtureTransportCancels>0,@"steering cancels old stream and requests latest input exactly once");
  Check(executions==0&&(scenario!=2||skipped),@"unexecuted old tool calls receive paired skipped results without execution");
  BOOL partial=NO;for(NSDictionary *m in saved)if([m[@"content"] isEqual:@"partial answer"])partial=YES;Check(scenario==1||partial,@"preserve received answer before steering");
  oldEvent(@{@"type":@"text",@"text":@"STALE"});oldEvent(@{@"type":@"done"});oldEvent(@{@"type":@"error",@"message":@"late cancellation"});Check(requests==2&&![[saved description] containsString:@"STALE"],@"late cancelled callbacks cannot mutate replacement round");
 }
 // Exercise stale callbacks while the replacement stream is still active.
 requests=0;__block TFAIEvent cancelledStream=nil,liveStream=nil;__block NSUInteger terminalEvents=0;__block NSArray *liveSaved=nil;
 FixtureTransport=^(NSArray *messages,NSArray *tools,TFAIEvent event){if(requests==1)cancelledStream=[event copy];else liveStream=[event copy];};
 id<TFAIRuntimeV2> live=(id)TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);live.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"]){terminalEvents++;liveSaved=e[@"messages"];}};[live activateSession:@"late-callback"];[live send:@[@{@"role":@"user",@"content":@"original"}] session:@"late-callback"];
 [live enqueueUserMessage:@{@"role":@"user",@"content":@"first correction"}];cancelledStream(@{@"type":@"text",@"text":@"STALE"});cancelledStream(@{@"type":@"error",@"message":@"late error"});cancelledStream(@{@"type":@"done"});
 Check(terminalEvents==0&&requests==2,@"late old callbacks ignored while replacement stream remains live");
 [live enqueueUserMessage:@{@"role":@"user",@"content":@"second correction"}];liveStream(@{@"type":@"text",@"text":@"latest answer"});liveStream(@{@"type":@"done"});
 NSUInteger first=0,second=0;for(NSDictionary *m in liveSaved){if([m[@"content"] isEqual:@"first correction"])first++;if([m[@"content"] isEqual:@"second correction"])second++;}
 Check(terminalEvents==1&&requests==3&&first==1&&second==1&&![[liveSaved description] containsString:@"STALE"],@"rapid successive steering preserves both messages exactly once");
 requests=executions=0;__block TFAIResult completeTool=nil;__block BOOL sawResult=NO,sawSkipped=NO,sawNew=NO;__block NSArray *saved=nil;
 FixtureToolExecution=^(NSDictionary *plan,TFAIResult done){completeTool=[done copy];};
 FixtureTransport=^(NSArray *messages,NSArray *tools,TFAIEvent event){
  if(requests==1){for(NSString *identifier in @[@"active",@"pending"])event(@{@"type":@"tool_call",@"id":identifier,@"name":@"read_file",@"arguments":@{@"path":identifier}});event(@{@"type":@"done"});return;}
  for(NSDictionary *m in messages){if([m[@"tool_call_id"] isEqual:@"active"]&&[m[@"content"] containsString:@"completed once"])sawResult=YES;if([m[@"tool_call_id"] isEqual:@"pending"]&&[m[@"content"] containsString:@"notExecuted"])sawSkipped=YES;if([m[@"content"] isEqual:@"change during tool"])sawNew=YES;}
  event(@{@"type":@"text",@"text":@"updated"});event(@{@"type":@"done"});
 };
 id<TFAIRuntimeV2> runtime=(id)TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);runtime.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])saved=e[@"messages"];};[runtime activateSession:@"tool-steer"];[runtime send:@[@{@"role":@"user",@"content":@"original"}] session:@"tool-steer"];
 Check(completeTool&&executions==1,@"first tool is executing");Check([runtime enqueueUserMessage:@{@"role":@"user",@"content":@"change during tool"}]&&requests==1,@"steering waits for active tool result");completeTool(@{@"text":@"completed once"},nil);
 Check(requests==2&&executions==1&&sawResult&&sawSkipped&&sawNew&&saved.count>0,@"keep active tool result, skip pending tool, then follow newest input");
 FixtureToolExecution=nil;FixtureTransport=nil;NSLog(@"Steering282 regressions passed");
}}

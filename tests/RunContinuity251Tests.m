#undef main
#define main LegacyBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
@interface Replay251 : TFProjectAIRuntime
@end
@implementation Replay251
- (void)runCall:(NSUInteger)index{}
@end
static TFProjectAIRuntime *Runtime251(void){TFProjectAIRuntime *r=(id)TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);[r activateSession:@"fixture"];return r;}
static BOOL Contains251(NSArray *messages,NSString *text){for(NSDictionary *m in messages)if([m[@"content"] containsString:text])return YES;return NO;}
int BudgetFixtureMain(){@autoreleasepool{
 mode=@"wait";events=[NSMutableArray new];
 // Actual runtime: queue while receiving, don't execute old planned writes.
 __block TFAIEvent stream;__block NSArray *second;__block NSUInteger count=0;
 FixtureTransport=^(NSArray *m,NSArray *schemas,TFAIEvent e){count++;if(count==1)stream=e;else{second=m;e(@{@"type":@"text",@"text":@"按修正要求完成"});e(@{@"type":@"done"});}};
 TFProjectAIRuntime *r=Runtime251();__block NSDictionary *end;__block NSDictionary *checkpoint;
 r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;if([e[@"type"] isEqual:@"checkpoint"])checkpoint=e[@"checkpoint"];};
 [r send:@[@{@"role":@"user",@"content":@"original"}] session:@"fixture"];
 Check([r enqueueUserMessage:@{@"role":@"user",@"content":@"修正：只读取，不要修改"}],@"running stream accepts correction");
 Check(Contains251(checkpoint[@"messages"],@"修正：只读取"),@"queued correction is checkpointed before model finishes");NSError *gate=nil;Check(![r preflightCall:@{} error:&gate]&&gate!=nil,@"correction revokes pending old-plan execution before approval completes");
 stream(@{@"type":@"text",@"text":@"旧计划"});stream(@{@"type":@"tool_call",@"id":@"old-call",@"name":@"read_file",@"arguments":@{@"path":@"Fixture.m"}});stream(@{@"type":@"done"});
 Check([end[@"state"] isEqual:@"completed"]&&count==2,@"correction starts exactly one next request");
 Check(Contains251(second,@"修正：只读取")&&Contains251(second,@"notExecuted"),@"next request contains correction and skipped old plan result");
 Check(r.queuedUsers.count==0,@"queue drains once");
 // Late supplement after text-only response cannot be stranded.
 count=0;end=nil;second=nil;r=Runtime251();r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};[r send:@[@{@"role":@"user",@"content":@"original"}] session:@"fixture"];[r enqueueUserMessage:@{@"role":@"user",@"content":@"还有一点"}];stream(@{@"type":@"text",@"text":@"first answer"});stream(@{@"type":@"done"});Check(count==2&&Contains251(second,@"还有一点"),@"text-only completion drains pending user before finishing");
 // Stop retains queue but never starts another request.
 FixtureTransport=^(NSArray *m,NSArray *s,TFAIEvent e){stream=e;};r=Runtime251();end=nil;r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};[r send:@[@{@"role":@"user",@"content":@"original"}] session:@"fixture"];[r enqueueUserMessage:@{@"role":@"user",@"content":@"retain me"}];[r stop];Check([end[@"state"] isEqual:@"stopped"]&&Contains251(end[@"messages"],@"retain me")&&![end[@"backgroundResumable"] boolValue],@"explicit stop preserves supplement and disables automatic recovery");
 stream(@{@"type":@"text",@"text":@"stale callback"});Check(!Contains251(end[@"messages"],@"stale callback"),@"stale stream ignored after stop");
 // Expiration retains partial reply and identifies recoverable system interruption.
 r=Runtime251();end=nil;r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};[r send:@[@{@"role":@"user",@"content":@"original"}] session:@"fixture"];stream(@{@"type":@"text",@"text":@"partial reply"});void(^expired)(NSString *)=[backgroundExpired copy];expired(@"system expiration");Check([end[@"backgroundResumable"] boolValue]&&Contains251(end[@"messages"],@"partial reply"),@"background expiration preserves partial and offers continuation");
 // Exact duplicate and alternating A/B/C receipts both trigger bounded no-progress pause.
 for(NSNumber *alternating in @[@NO,@YES]){Replay251 *p=[Replay251 new];p.running=YES;p.messages=[NSMutableArray new];p.observations=[NSMutableDictionary new];p.observationOrder=[NSMutableArray new];p.progressEvidence=[NSMutableArray new];p.activeToolRecords=[NSMutableDictionary new];p.queuedUsers=[NSMutableArray new];p.toolStarts=[NSMutableDictionary new];__block BOOL warned=NO;end=nil;p.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"status"]&&[e[@"message"] containsString:@"重复检查"])warned=YES;if([e[@"type"] isEqual:@"done"])end=e;};
 for(NSUInteger i=0;i<25&&p.running;i++){NSDictionary *c=@{@"id":[NSString stringWithFormat:@"c%lu",i],@"name":@"sandbox_files",@"arguments":@{@"path":[NSString stringWithFormat:@"/workspace/%lu",alternating.boolValue?i%3:0],@"operation":@"read"}};[p recordCall:c result:@{@"content":@"unchanged",@"duration":@(i)} error:nil index:0];}
 Check(warned&&[end[@"state"] isEqual:@"paused"],alternating.boolValue?@"alternating repeated reads warn then pause":@"same reads with changing duration warn then pause");}
 // Rotating queries/titles and unrelated observations must not erase duplicate evidence.
 for(NSString *variant in @[@"interleaved",@"query-churn",@"proposal-id",@"history-ref"]){
 Replay251 *q=[Replay251 new];q.running=YES;q.messages=[NSMutableArray new];q.observations=[NSMutableDictionary new];q.observationOrder=[NSMutableArray new];q.progressEvidence=[NSMutableArray new];q.toolStarts=[NSMutableDictionary new];q.activeToolRecords=[NSMutableDictionary new];q.queuedUsers=[NSMutableArray new];end=nil;q.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};
 for(NSUInteger i=0;i<70&&q.running;i++){
  NSString *name=@"read_file";NSDictionary *args=@{@"path":@"Tweak.xm",@"tool_title":[NSString stringWithFormat:@"check %lu",i]};NSDictionary *value=@{@"content":@"unchanged"};
  if([variant isEqual:@"interleaved"]&&i%3==2){args=@{@"path":[NSString stringWithFormat:@"new-%lu",i]};value=@{@"content":@(i)};}
  if([variant isEqual:@"query-churn"]){name=@"search_text";args=@{@"path":@"Tweak.xm",@"query":[NSString stringWithFormat:@"term-%lu",i]};value=@{@"matches":@[]};}
  if([variant isEqual:@"proposal-id"]){name=@"propose_patch";args=@{@"edits":@[@{@"path":@"Tweak.xm",@"before":@"old",@"after":@"new"}]};value=@{@"proposal_id":NSUUID.UUID.UUIDString,@"previewStoredLocally":@YES,@"edit_count":@1};}
  if([variant isEqual:@"history-ref"]){name=@"read_context";args=@{@"ref":[NSString stringWithFormat:@"result:call-%lu",i]};value=@{@"ref":args[@"ref"],@"text":@"same historical file content",@"historical":@YES,@"sha256":NSUUID.UUID.UUIDString};}
  [q recordCall:@{@"id":[NSString stringWithFormat:@"c%lu",i],@"name":name,@"arguments":args} result:value error:nil index:0];
 }
 if([variant isEqual:@"query-churn"])Check(q.running&&q.stagnantCalls==0,@"distinct targeted search queries are not duplicates solely because both return empty");else Check([end[@"state"] isEqual:@"paused"],[@"rolling guard stops " stringByAppendingString:variant]);
 }
 // Real continuation restores repeated history instead of giving each 'continue' a clean detector.
 NSMutableArray *history=[NSMutableArray arrayWithObject:@{@"role":@"user",@"content":@"修复文件"}];
 for(NSUInteger i=0;i<16;i++){NSString *identifier=[NSString stringWithFormat:@"prior-%lu",i];[history addObject:@{@"role":@"assistant",@"content":@"",@"tool_calls":@[@{@"id":identifier,@"name":@"read_file",@"arguments":@{@"path":@"Tweak.xm"}}]}];[history addObject:@{@"role":@"tool",@"tool_call_id":identifier,@"content":@"{\"text\":\"unchanged\"}"}];}
 [history addObject:@{@"role":@"user",@"content":@"继续"}];
 FixtureTransport=^(NSArray *m,NSArray *schemas,TFAIEvent e){stream=e;};r=Runtime251();[r send:history session:@"fixture"];
 Check(r.stagnantCalls>=12&&r.guardCalls==0,@"continue restores recent loop evidence without tool replay");
 Check(RunProgressContinuation(@{@"content":@"continue"})&&!RunProgressContinuation(@{@"content":@"修改方向：处理新问题"}),@"continuation recognition does not classify substantive correction as continue");
 [r stop];
 // Novel output and live polling remain usable beyond the guard thresholds.
 Replay251 *p=[Replay251 new];p.running=YES;p.messages=[NSMutableArray new];p.observations=[NSMutableDictionary new];p.observationOrder=[NSMutableArray new];p.progressEvidence=[NSMutableArray new];p.toolStarts=[NSMutableDictionary new];p.activeToolRecords=[NSMutableDictionary new];
 for(NSUInteger i=0;i<45;i++){NSDictionary *c=@{@"id":[NSString stringWithFormat:@"n%lu",i],@"name":@"read_file",@"arguments":@{@"path":@"changing"}};[p recordCall:c result:@{@"text":@(i)} error:nil index:0];}Check(p.running&&p.stagnantCalls==0,@"45 changing observations do not impose a round cap");
 for(NSUInteger i=0;i<45;i++){NSDictionary *c=@{@"id":[NSString stringWithFormat:@"p%lu",i],@"name":@"sandbox_process_read",@"arguments":@{@"process_id":@"p"}};[p recordCall:c result:@{@"running":@YES} error:nil index:0];}Check(p.running,@"unchanged live process polling is exempt");
 // Correct pagination and identical envelopes for unrelated files remain valid.
 Replay251 *pages=[Replay251 new];pages.running=YES;pages.messages=[NSMutableArray new];pages.observations=[NSMutableDictionary new];pages.observationOrder=[NSMutableArray new];pages.progressEvidence=[NSMutableArray new];pages.toolStarts=[NSMutableDictionary new];pages.activeToolRecords=[NSMutableDictionary new];
 for(NSUInteger i=0;i<90;i++){NSString *name=i<45?@"read_context":@"read_file";NSDictionary *a=i<45?@{@"ref":@"result:large-original",@"offset":@(i*4096)}:@{@"path":[NSString stringWithFormat:@"file-%lu",i]};NSDictionary *v=i<45?@{@"historical":@YES,@"text":[NSString stringWithFormat:@"page %lu",i],@"next_offset":@(i*4096+4096)}:@{@"text":@"same small header"};[pages recordCall:@{@"id":[NSString stringWithFormat:@"page-%lu",i],@"name":name,@"arguments":a} result:v error:nil index:0];}
 Check(pages.running&&pages.stagnantCalls==0,@"90 distinct pages and identical unrelated files do not trigger loop protection");
 for(NSUInteger i=0;i<8;i++)[pages recordCall:@{@"id":[NSString stringWithFormat:@"dup-%lu",i],@"name":@"read_file",@"arguments":@{@"path":@"changed-file"}} result:@{@"text":@"old"} error:nil index:0];
 Check(pages.stagnantCalls>=6,@"duplicate evidence accumulated before a real edit");
 [pages recordCall:@{@"id":@"real-edit",@"name":@"apply_approved_patch",@"arguments":@{@"proposal_id":@"approved"}} result:@{@"status":@"applied",@"files":@[@"changed-file"],@"backupID":@"backup-real"} error:nil index:0];
 Check(pages.running&&pages.stagnantCalls==0,@"confirmed applied edit invalidates stale no-progress evidence");
 NSDictionary *original=@{@"historical":@YES,@"text":@"original page"};NSDictionary *nested=@{@"historical":@YES,@"text":RunProgressJSON(original)};
 Check([RunProgressOutcome(@{@"name":@"read_context"},original) isEqual:RunProgressOutcome(@{@"name":@"read_context"},nested)],@"reading a readback does not create novel evidence");
 // Pagination churn: the same numbered source lines must not be counted as new.
 Replay251 *coverage=[Replay251 new];coverage.observations=[NSMutableDictionary new];coverage.observationOrder=[NSMutableArray new];
 NSMutableArray *source=[NSMutableArray new];for(NSUInteger i=0;i<400;i++)[source addObject:[NSString stringWithFormat:@"line %lu",i+1]];
 NSDictionary *(^page267)(NSUInteger,NSUInteger,NSString *)=^NSDictionary *(NSUInteger start,NSUInteger count,NSString *sha){return @{@"path":@"Stable.h",@"start_line":@(start),@"sha256":sha,@"content":[[source subarrayWithRange:NSMakeRange(start-1,count)] componentsJoinedByString:@"\n"]};};
 NSDictionary *fileCall=@{@"name":@"read_file",@"arguments":@{@"path":@"Stable.h"}};
 [coverage observeCall:fileCall value:page267(1,200,@"v1") count:YES];
 for(NSUInteger i=0;i<12;i++)[coverage observeCall:@{@"name":@"read_file",@"arguments":@{@"path":@"Stable.h",@"start_line":@(i+1),@"line_count":@(180-i)}} value:page267(i+1,180-i,@"v1") count:YES];
 Check(coverage.stagnantCalls==12,@"changing line ranges does not bypass duplicate coverage");
 NSDictionary *write=@{@"name":@"create_file",@"arguments":@{@"path":@"New.h"}};
 [coverage observeCall:write value:@{@"status":@"applied",@"files":@[@"New.h"]} count:YES];
 [coverage observeCall:fileCall value:page267(1,180,@"v1") count:YES];Check(coverage.stagnantCalls==1,@"creating unrelated file preserves existing read evidence");
 [coverage observeCall:@{@"name":@"apply_approved_patch"} value:@{@"status":@"applied",@"files":@[@"Stable.h"]} count:YES];
 [coverage observeCall:fileCall value:page267(1,180,@"v1") count:YES];Check(coverage.stagnantCalls==0,@"successful write permits verification of changed file even with identical excerpt");
 [coverage observeCall:fileCall value:page267(181,200,@"v1") count:YES];Check(coverage.stagnantCalls==0,@"new forward page with minor overlap is useful evidence");
 [coverage observeCall:fileCall value:page267(1,180,@"v2") count:YES];Check(coverage.stagnantCalls==0,@"external file version change permits fresh verification");
 [coverage observeCall:@{@"name":@"read_context",@"arguments":@{@"ref":@"result:old-file"}} value:@{@"historical":@YES,@"text":RunProgressJSON(page267(5,120,@"v1"))} count:YES];Check(coverage.stagnantCalls==1,@"historical file reread shares line coverage without erasing newer version");
 // Resume seeds artifact handles without replaying export.
 __block NSArray *sent;FixtureTransport=^(NSArray *m,NSArray *s,TFAIEvent e){sent=m;e(@{@"type":@"text",@"text":@"交付"});e(@{@"type":@"done"});};r=Runtime251();[r send:@[@{@"role":@"user",@"content":@"task"},@{@"role":@"assistant",@"content":@"",@"tool_calls":@[@{@"id":@"exported",@"name":@"sandbox_export_file",@"arguments":@{@"path":@"/workspace/result.zip"}}]},@{@"role":@"tool",@"tool_call_id":@"exported",@"content":@"{\"export_id\":\"kept-artifact\",\"bytes\":123}"},@{@"role":@"user",@"content":@"继续"}] session:@"fixture"];
 Check(Contains251(sent,@"kept-artifact")&&r.progressEvidence.count==1,@"resume preserves protected artifact handle from original result");
 NSString *replayPath=NSProcessInfo.processInfo.environment[@"DYLIX_LOOP_REPLAY_SESSION"];
 if(replayPath.length){NSDictionary *session=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:replayPath] options:0 error:nil];NSArray *history=session[@"messages"];Check(history.count>500,@"real exported session loaded for replay");
 for(NSArray *bounds in @[@[@538,@721],@[@758,@788],@[@788,@838]]){Replay251 *p=[Replay251 new];p.running=YES;p.messages=[NSMutableArray new];p.observations=[NSMutableDictionary new];p.observationOrder=[NSMutableArray new];p.progressEvidence=[NSMutableArray new];p.toolStarts=[NSMutableDictionary new];p.activeToolRecords=[NSMutableDictionary new];p.queuedUsers=[NSMutableArray new];end=nil;p.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};NSMutableDictionary *calls=[NSMutableDictionary new];NSUInteger executed=0,last=0;
 for(NSUInteger i=0;i<[bounds[1] unsignedIntegerValue]&&p.running;i++){NSDictionary *m=history[i];for(NSDictionary *c in m[@"tool_calls"])calls[c[@"id"]]=c;if(![m[@"role"] isEqual:@"tool"])continue;NSDictionary *c=calls[m[@"tool_call_id"]];id v=[NSJSONSerialization JSONObjectWithData:[m[@"content"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];if(!c||![v isKindOfClass:NSDictionary.class])continue;if(i<[bounds[0] unsignedIntegerValue]){if(i+512>=[bounds[0] unsignedIntegerValue])[p observeCall:c value:v count:NO];continue;}[p recordCall:c result:v error:nil index:0];executed++;last=i;}
 NSLog(@"REPLAY267 window=%@ delivered=%lu lastMessage=%lu state=%@ repeated=%lu",bounds,(unsigned long)executed,(unsigned long)last,end[@"state"]?:@"running",(unsigned long)p.stagnantCalls);Check([end[@"state"] isEqual:@"paused"],@"real repeated-read window pauses before original user intervention");}
 }
 FixtureTransport=nil;NSLog(@"PASS RunContinuity251 runtime scenarios");}return 0;}

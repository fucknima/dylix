#define DYLIX_TEST_REAL_POLICY 1
#define main ExistingBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
#import "../App/AI/Core/AIPolicy.m"
BOOL TFAIAllowedRelativePath(NSString *p){return YES;}
static NSUInteger approvals;
static BOOL disableDuringRequest;
static NSArray *RunTerminal(NSString *root,NSString *preset,NSString *name,NSDictionary *args,BOOL revoke){
 requests=0;NSMutableArray *captured=[NSMutableArray new];
 FixtureTransport=^(NSArray *messages,NSArray *tools,TFAIEvent event){if(requests==1){if(disableDuringRequest)[TFAIToolRegistry setEnabled:NO module:@"sandbox"];event(@{@"type":@"tool_call",@"id":NSUUID.UUID.UUIDString,@"name":name,@"arguments":args});event(@{@"type":@"done"});}else{event(@{@"type":@"text",@"text":@"finished"});event(@{@"type":@"done"});}};
 id<TFAIRuntime> runtime=TFAICreateRuntime(root,@"fixture",nil);runtime.approval=^(NSDictionary *p,void(^decision)(BOOL,NSArray *)){approvals++;decision(NO,nil);};runtime.event=^(NSDictionary *event){[captured addObject:event];};[runtime activateSession:@"terminal-session"];[runtime configurePermissionPreset:preset paths:@[] error:nil];if(revoke)[(TFProjectAIRuntime *)runtime revokePermission:@"test revocation"];
 [runtime send:@[@{@"role":@"user",@"content":@"terminal fixture"}] session:@"terminal-session"];NSDate *until=[NSDate dateWithTimeIntervalSinceNow:2];while(![[captured valueForKey:@"type"] containsObject:@"done"]&&until.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];return captured;
}
int main(){@autoreleasepool{
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
 FixtureContextOverrides=@{@"sandboxAvailable":@YES};[TFAIToolRegistry setEnabled:YES module:@"sandbox"];
 RunTerminal(root,@"assisted",@"sandbox_execute",@{@"command":@"echo test"},NO);Check(approvals==1&&FixtureSandboxExecutions==0,@"assisted still asks and denial never executes");
 for(NSString *preset in @[@"full",@"full_push",@"full_download",@"full_network"]){NSUInteger a=approvals,e=FixtureSandboxExecutions;RunTerminal(root,preset,@"sandbox_execute",@{@"command":@"echo test"},NO);Check(approvals==a&&FixtureSandboxExecutions==e+1,@"each full preset authorizes guest execution without per-line approval");}
 for(NSDictionary *call in @[@{@"name":@"sandbox_process_start",@"args":@{@"command":@"sh -i"}},@{@"name":@"sandbox_process_write",@"args":@{@"process_id":@"fixture-process",@"input":@"echo hi\n"}},@{@"name":@"sandbox_process_resize",@"args":@{@"process_id":@"fixture-process",@"columns":@80,@"rows":@24}},@{@"name":@"sandbox_process_stop",@"args":@{@"process_id":@"fixture-process"}},@{@"name":@"sandbox_install_tools",@"args":@{}}]){NSUInteger a=approvals,e=FixtureProcessCalls;RunTerminal(root,@"full",call[@"name"],call[@"args"],NO);Check(a==approvals&&e+1==FixtureProcessCalls,@"full terminal process/install tools share grant");}
 NSUInteger a=approvals,e=FixtureSandboxExecutions;RunTerminal(root,@"full",@"sandbox_execute",@{@"command":@"echo test"},YES);Check(approvals==a+1&&FixtureSandboxExecutions==e,@"revoked full grant restores approval immediately");
 a=approvals;RunTerminal(root,@"full",@"sandbox_browser",@{@"process_id":@"fixture-process",@"operation":@"click",@"snapshot":@"s",@"id":@"1"},NO);Check(approvals==a+1,@"terminal grant does not silently expand browser action grants");
 a=approvals;e=FixtureSandboxExecutions;disableDuringRequest=YES;RunTerminal(root,@"full",@"sandbox_execute",@{@"command":@"echo blocked"},NO);Check(approvals==a&&FixtureSandboxExecutions==e,@"full grant still rechecks module disabled after schema delivery");disableDuringRequest=NO;[TFAIToolRegistry setEnabled:YES module:@"sandbox"];
 TFAIRuntimePolicy *p=[[TFAIRuntimePolicy alloc]initWithRoot:root projectID:@"fixture" sessionID:@"s"];[p configurePreset:@"full" paths:@[] session:@"s" error:nil];[NSFileManager.defaultManager removeItemAtPath:root error:nil];Check(!p.allowsSessionTerminalAutomation,@"deleted project invalidates automatic guest execution");
 NSLog(@"Terminal permission regression passed");return 0;
}}

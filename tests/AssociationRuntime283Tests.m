#define main ExistingBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
int main(){@autoreleasepool{
 TFProjectAIRuntime *r=(id)TFAICreateRuntime(@"/tmp/project-a",@"original-storage",nil);[r activateSession:@"original-session"];
 NSArray *messages=@[@{@"role":@"user",@"content":@"keep history"}];r.messages=[messages mutableCopy];NSUInteger prior=fixturePolicyRevokes;
 TFAIRebindRuntimeWorkspace(r,@"/tmp/project-b");
 Check([r.root isEqual:@"/tmp/project-b"],@"runtime switches project root");
 Check([r.projectID isEqual:@"original-storage"]&&[r.sessionID isEqual:@"original-session"],@"storage and terminal session identity unchanged");
 Check([r.messages isEqual:messages],@"workspace rebind preserves transcript");
 Check(fixturePolicyRevokes>prior&&r.policy&&r.toolbox,@"old project approvals revoked and tools rebuilt");
 Check([r.promptEnvironment[@"hasProject"] boolValue],@"prompt recognizes bound project");
 id policy=r.policy;TFAIRebindRuntimeWorkspace(r,@"/tmp/project-b");Check(r.policy==policy,@"same root navigation preserves policy");
 r.running=YES;TFAIRebindRuntimeWorkspace(r,@"/tmp/project-c");Check([r.root isEqual:@"/tmp/project-b"]&&r.policy==policy,@"active task cannot switch workspace");r.running=NO;
 NSLog(@"Association283 runtime regressions passed");
}}

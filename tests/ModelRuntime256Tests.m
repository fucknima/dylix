#define main UnusedBudget256Main
#import "AIRuntimeBudgetTests.m"
#undef main
static NSArray *Ops256(TFProjectAIRuntime *r,NSString *name,NSString *field){for(NSDictionary *s in [r availableSchemas])if([s[@"name"] isEqual:name])return s[@"parameters"][@"properties"][field][@"enum"];return @[];}
int main(){@autoreleasepool{
 [NSUserDefaults.standardUserDefaults removeObjectForKey:@"Dylix.AI.ToolModules"];
 FixtureContextOverrides=@{@"flexLiveAvailable":@YES,@"sandboxAvailable":@YES,@"hasApproval":@YES};
 TFProjectAIRuntime *r=(id)TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);[r activateSession:@"model256"];r.requestMode=@"develop";
 NSMutableDictionary *c=[@{@"model":@"opaque-runtime256",@"protocol":@"chat",@"baseURL":@"https://fixture.invalid/v1"} mutableCopy];r.connection=c;
 Check([Ops256(r,@"flex_sensitive_read",@"operation") containsObject:@"capture_screen"],@"256 unknown image capability exposes FLEX screenshot");
 Check([Ops256(r,@"sandbox_browser",@"operation") containsObject:@"screenshot"],@"256 unknown image capability exposes terminal browser screenshot");
 c[@"capabilityOverrides"]=@{TFAICapabilityScope(c):@{@"image":@"unsupported"}};
 Check(![Ops256(r,@"flex_sensitive_read",@"operation") containsObject:@"capture_screen"],@"256 user-disabled image removes FLEX screenshot");
 Check(![Ops256(r,@"sandbox_browser",@"operation") containsObject:@"screenshot"],@"256 user-disabled image removes browser screenshot");
 [c removeObjectForKey:@"capabilityOverrides"];FixtureContextOverrides=@{@"flexLiveAvailable":@NO,@"sandboxAvailable":@NO};
 Check(Ops256(r,@"flex_sensitive_read",@"operation").count==0,@"256 unknown model does not bypass missing FLEX connection");
 FixtureContextOverrides=@{@"flexLiveAvailable":@YES,@"sandboxAvailable":@YES};c[@"toolsEnabled"]=@NO;
 Check([r availableSchemas].count==0,@"256 global tool disable remains authoritative");
 NSLog(@"TOTAL 6 model runtime checks passed");return 0;
}}

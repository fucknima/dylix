#undef main
#define main LegacyBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
int BudgetFixtureMain(){@autoreleasepool{
 NSMutableDictionary *captured=[NSMutableDictionary new];NSUserDefaults *d=NSUserDefaults.standardUserDefaults;id previous=[d objectForKey:@"Dylix.AI.AnswerStyle"];
 for(NSString *style in @[@"concise",@"standard",@"detailed"]){[d setObject:style forKey:@"Dylix.AI.AnswerStyle"];__block NSArray *request=nil;FixtureTransport=^(NSArray *m,NSArray *s,TFAIEvent e){request=m;e(@{@"type":@"text",@"text":@"capture complete"});e(@{@"type":@"done"});};TFProjectAIRuntime *r=(id)TFAICreateRuntime(@"/tmp/isolated-test",@"style-fixture",nil);[r activateSession:@"style"];r.nextConnection=@{@"model":@"fixture",@"protocol":@"chat"};[r send:@[@{@"role":@"user",@"content":@"Style prompt capture"}] session:@"style"];NSMutableArray *systems=[NSMutableArray new];for(NSDictionary *m in request)if([m[@"role"] isEqual:@"system"])[systems addObject:@{@"role":@"system",@"content":m[@"content"]?:@""}];Check(systems.count>0,@"actual runtime developer prompt captured");captured[style]=systems;}
 if(previous)[d setObject:previous forKey:@"Dylix.AI.AnswerStyle"];else[d removeObjectForKey:@"Dylix.AI.AnswerStyle"];
 NSString *path=NSProcessInfo.processInfo.environment[@"DYLIX_STYLE_CAPTURE"];[RunProgressJSON(captured) writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];FixtureTransport=nil;
}return 0;}

#undef main
#define main LegacyBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
static BOOL Has252(NSArray *schemas,NSString *name){for(NSDictionary *s in schemas)if([s[@"name"] isEqual:name])return YES;return NO;}
static TFProjectAIRuntime *Runtime252(void){TFProjectAIRuntime *r=(id)TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);[r activateSession:@"fixture"];return r;}
int BudgetFixtureMain(){@autoreleasepool{
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;[defaults removeObjectForKey:@"Dylix.AI.LazyTools"];[defaults removeObjectForKey:@"Dylix.AI.AnswerStyle"];
 Check(!TFAILazyToolsEnabled()&&[TFAIAnswerStyle() isEqual:@"standard"],@"existing defaults keep full tools and standard style");
 FixtureToolSchemas=@[@{@"name":@"read_file",@"description":@"Read source",@"parameters":@{@"type":@"object"}},@{@"name":@"search_text",@"description":@"Search project text",@"parameters":@{@"type":@"object",@"properties":@{@"query":@{@"type":@"string"}},@"required":@[@"query"]}},@{@"name":@"create_file",@"description":@"Create file",@"parameters":@{@"type":@"object"}}];
 TFProjectAIRuntime *r=Runtime252();NSArray *full=[r requestSchemas];Check([full isEqual:[r availableSchemas]]&&!Has252(full,@"search_tools"),@"disabled optimization keeps original schema array");
 [defaults setBool:YES forKey:@"Dylix.AI.LazyTools"];NSArray *lazy=[r requestSchemas];Check(Has252(lazy,@"search_tools")&&Has252(lazy,@"read_file")&&!Has252(lazy,@"search_text"),@"lazy discovery preserves base tools and defers optional tool");
 NSError *error=nil;Check(![r preflightCall:@{@"name":@"search_text",@"arguments":@{@"query":@"x"}} error:&error],@"unadvertised tool cannot execute");
 NSMutableSet *loaded=[NSMutableSet new];NSDictionary *found=TFAILoadTools(@{@"names":@[@"search_text",@"unknown",@"flex_control"]},[r availableSchemas],loaded,&error);
 Check([loaded containsObject:@"search_text"]&&[found[@"unavailable"] containsObject:@"flex_control"]&&![loaded containsObject:@"unknown"],@"discovery cannot load nonexistent or unavailable tools");
 Check([TFAILoadTools(@{},[r availableSchemas],loaded,&error)[@"catalog"] count]==full.count,@"empty discovery exposes all available tool names without loading all");
 Check(!TFAILoadTools((id)@[],full,loaded,&error)&&!TFAILoadTools(@{@"names":@[@1]},full,loaded,&error),@"invalid discovery input rejected");
 r.loadedToolNames=loaded;r.advertisedSchemas=[r requestSchemas];Check([r preflightCall:@{@"name":@"search_text",@"arguments":@{@"query":@"x"}} error:&error],@"loaded tool passes original registry validation");
 Check(![r preflightCall:@{@"name":@"search_text",@"arguments":@{}} error:&error],@"loading does not bypass required argument checks");
 FixtureContextOverrides=@{@"hasProject":@NO};Check(!Has252([r requestSchemas],@"search_text")&&![r preflightCall:@{@"name":@"search_text",@"arguments":@{@"query":@"x"}} error:&error],@"revoked availability removes loaded tools and blocks stale advertised calls");FixtureContextOverrides=nil;
 [r activateSession:@"another"];Check(!r.loadedToolNames.count,@"session switch clears discovery set");
 r=Runtime252();r.messages=[@[@{@"role":@"assistant",@"tool_calls":@[@{@"name":@"search_text"}]}] mutableCopy];Check(Has252([r requestSchemas],@"search_text"),@"historically used tools restored without an extra lookup");
 r.childKind=@"analysis";Check(!Has252([r requestSchemas],@"search_tools")&&Has252([r requestSchemas],@"search_text"),@"child allowlist keeps original direct tool behavior");
 __block NSUInteger round=0;executions=0;mode=@"wait";events=[NSMutableArray new];__block NSDictionary *last;
 FixtureTransport=^(NSArray *m,NSArray *schemas,TFAIEvent event){round++;if(round==1){event(@{@"type":@"tool_call",@"id":@"discover",@"name":@"search_tools",@"arguments":@{@"names":@[@"search_text"]}});}else if(round==2){Check(Has252(schemas,@"search_text"),@"next real runtime request includes loaded schema");event(@{@"type":@"tool_call",@"id":@"search",@"name":@"search_text",@"arguments":@{@"query":@"needle"}});}else event(@{@"type":@"text",@"text":@"done"});event(@{@"type":@"done"});};
 r=Runtime252();r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])last=e;};[r send:@[@{@"role":@"user",@"content":@"search source"}] session:@"fixture"];
 Check(round==3&&executions==1&&[last[@"state"] isEqual:@"completed"],@"discovery to actual execution completes with one source search");
 [defaults setObject:@"concise" forKey:@"Dylix.AI.AnswerStyle"];Check([TFAIAnswerGuidance() containsString:@"完整保留"]&&[TFAIAnswerGuidance() containsString:@"简洁"],@"concise style retains full code and evidence requirement");

 // Changing outputs/progress must not rewrite the stable developer prefix.
 __block NSMutableArray *prefixes=[NSMutableArray new];__block NSUInteger prefixRound=0;FixtureTransport=^(NSArray *messages,NSArray *schemas,TFAIEvent event){prefixRound++;NSMutableArray *system=[NSMutableArray new];for(NSDictionary *m in messages)if([m[@"role"] isEqual:@"system"])[system addObject:m[@"content"]];[prefixes addObject:system];if(prefixRound==1)event(@{@"type":@"usage",@"usage":@{@"prompt_tokens":@1000000,@"completion_tokens":@1}});if(prefixRound<3)event(@{@"type":@"tool_call",@"id":[NSString stringWithFormat:@"prefix-%lu",(unsigned long)prefixRound],@"name":@"read_file",@"arguments":@{@"path":@"Main.m"}});else event(@{@"type":@"text",@"text":@"done"});event(@{@"type":@"done"});};
 r=Runtime252();[r send:@[@{@"role":@"user",@"content":@"Inspect and finish"}] session:@"fixture"];Check(prefixes.count==3&&[prefixes[0] isEqual:prefixes[1]]&&[prefixes[1] isEqual:prefixes[2]],@"changing outputs and old large usage leave prefix stable and next small request usable");
 [defaults removeObjectForKey:@"Dylix.AI.AnswerStyle"];[defaults removeObjectForKey:@"Dylix.AI.LazyTools"];
 NSLog(@"RequestOptimization252 runtime scenarios passed");}return 0;}

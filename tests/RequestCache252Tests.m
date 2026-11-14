#define main LegacyProviderMain
#import "provider_v4Tests.m"
#undef main
static void Cache252Tests(void){
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;[d removeObjectForKey:@"Dylix.AI.AnthropicCache"];
 NSDictionary *c=@{@"protocol":@"anthropic",@"model":@"claude-sonnet-4-20250514",@"baseURL":@"https://api.anthropic.com/v1",@"id":@"fixture"};
 NSArray *m=@[@{@"role":@"system",@"content":@"Stable policy 【本轮环境快照】time=1"},@{@"role":@"user",@"content":@"hello"}];NSError *error=nil;
 NSDictionary *off=TFAIRequestBody(m,c,@[],NO,&error);Check([off[@"system"] isKindOfClass:NSString.class],@"cache off preserves original Anthropic request shape");
 [d setBool:YES forKey:@"Dylix.AI.AnthropicCache"];NSDictionary *on=TFAIRequestBody(m,c,@[],NO,&error);NSArray *blocks=on[@"system"];
 Check([blocks isKindOfClass:NSArray.class]&&blocks.count==2&&[blocks[0][@"cache_control"][@"type"] isEqual:@"ephemeral"]&&!blocks[1][@"cache_control"],@"official Anthropic cache marker precedes volatile snapshot");
 NSArray *next=@[@{@"role":@"system",@"content":@"Stable policy 【本轮环境快照】time=2"},m[1]];NSDictionary *body=TFAIRequestBody(next,c,@[],NO,&error);Check([blocks[0] isEqual:body[@"system"][0]],@"changing runtime snapshot preserves cacheable prefix");
 NSMutableDictionary *proxy=[c mutableCopy];proxy[@"baseURL"]=@"https://proxy.example/v1";Check([TFAIRequestBody(m,proxy,@[],NO,&error)[@"system"] isKindOfClass:NSString.class],@"compatible proxy receives no new cache fields");
 proxy[@"baseURL"]=@"https://api.anthropic.com.example/v1";Check([TFAIRequestBody(m,proxy,@[],NO,&error)[@"system"] isKindOfClass:NSString.class],@"host suffix lookalike is not official");
 proxy=[c mutableCopy];proxy[@"_probeToolName"]=@"probe_ping";Check([TFAIRequestBody(m,proxy,@[],NO,&error)[@"system"] isKindOfClass:NSString.class],@"capability probe remains unchanged");
 for(NSString *protocol in @[@"chat",@"responses",@"gemini"]){NSMutableDictionary *connection=[c mutableCopy];connection[@"protocol"]=protocol;connection[@"model"]=@"fixture";NSDictionary *enabled=TFAIRequestBody(m,connection,@[],NO,&error);[d setBool:NO forKey:@"Dylix.AI.AnthropicCache"];NSDictionary *disabled=TFAIRequestBody(m,connection,@[],NO,&error);Check([enabled isEqual:disabled],[@"cache setting does not alter " stringByAppendingString:protocol]);[d setBool:YES forKey:@"Dylix.AI.AnthropicCache"];}
 Check([off[@"max_tokens"] isEqual:on[@"max_tokens"]],@"optimization never lowers output limit");[d removeObjectForKey:@"Dylix.AI.AnthropicCache"];
}
int main(int argc,char **argv){@autoreleasepool{Cache252Tests();}return LegacyProviderMain(argc,argv);}

// Exercise production resolvers, serializers, transport and preferences together.
static void Provider256Tests(void){
 NSArray *plain=@[@{@"role":@"user",@"content":@"hello"}];NSError *error=nil;
 NSArray *tool=@[@{@"name":@"read_file",@"description":@"Read a file",@"parameters":@{@"type":@"object",@"properties":@{}}}];
 NSArray *images=@[@{@"role":@"user",@"content":@"describe",@"images":@[@{@"mime":@"image/png",@"data":@"iVBORw0KGgo="}]}];
 for(NSString *protocol in @[@"chat",@"responses",@"anthropic",@"gemini"]){
  NSMutableDictionary *c=[Conn(protocol) mutableCopy];c[@"model"]=@"opaque-no-test";c[@"capabilities"]=@{@"image":@"unsupported",@"tools":@"unsupported"};
  Check(TFAIImagesAllowed(c)&&TFAIToolsAllowed(c),[protocol stringByAppendingString:@": untested and legacy failed features permitted"]);
  NSDictionary *body=TFAIRequestBody(images,c,tool,YES,&error);
  Check(body&&body[@"tools"]&&[JSONString(body) containsString:@"iVBORw0KGgo="],[protocol stringByAppendingString:@": actual image and tool encoding require no diagnostic pass"]);
  c[@"capabilityOverrides"]=@{TFAICapabilityScope(c):@{@"image":@"unsupported",@"tools":@"unsupported"}};
  Check(!TFAIImagesAllowed(c)&&!TFAIToolsAllowed(c),[protocol stringByAppendingString:@": explicit user disable respected"]);
  error=nil;Check(!TFAIRequestBody(images,c,tool,YES,&error)&&error.code==32,[protocol stringByAppendingString:@": disabled images fail explicitly without stripping history"]);
  body=TFAIRequestBody(plain,c,tool,YES,&error);Check(body&&!body[@"tools"],[protocol stringByAppendingString:@": text remains usable while image/tools disabled"]);
  [c removeObjectForKey:@"capabilityOverrides"];c[@"reasoningEffort"]=@"high";body=TFAIRequestBody(plain,c,@[],NO,&error);
  Check(body&&([protocol isEqual:@"anthropic"]?[body[@"thinking"][@"budget_tokens"] integerValue]==8192:[TFAIReasoningRequestSummary(body,c) containsString:@"high"]),[protocol stringByAppendingString:@": opaque model reasoning may be attempted without a probe"]);
  [c removeObjectForKey:@"reasoningEffort"];body=TFAIRequestBody(plain,c,@[],NO,&error);
  Check(!body[@"reasoning_effort"]&&!body[@"thinking"]&&!body[@"generationConfig"][@"thinkingConfig"],[protocol stringByAppendingString:@": default preserves provider settings"]);
 }
 NSMutableDictionary *alias=[Conn(@"chat") mutableCopy];alias[@"model"]=@"private-alias";
 NSDictionary *row=TFAISanitizeModelMetadata(@{@"capabilities":@{@"supports":@{@"supports_vision":@YES,@"supports_tools":@YES,@"supports_reasoning":@YES}},@"input_modalities":@[@"text_input",@"image_input"],@"reasoning_options":@[@{@"type":@"effort",@"values":@[@"high",@"low",@"bogus"]}]});
 Check([row[@"capabilities"][@"image"] isEqual:@"supported"]&&[row[@"capabilities"][@"tools"] isEqual:@"supported"]&&[row[@"efforts"] isEqual:@[@"low",@"high"]],@"256 common gateway modality aliases and reasoning_options parsed");
 Check([TFAISanitizeModelMetadata(row) isEqual:row],@"256 sanitized metadata survives save/reload without losing declarations");
 alias[@"modelMetadataScope"]=TFAIModelMetadataScope(alias);alias[@"modelMetadata"]=@{@"private-alias":row};
 Check([[TFAIReasoningOptions(alias) valueForKey:@"id"] isEqual:@[@"auto",@"low",@"high"]],@"256 endpoint declared efforts override generic compatible choices");
 alias[@"modelMetadata"]=@{@"private-alias":TFAISanitizeModelMetadata(@{@"supports_reasoning":@YES})};
 Check([[TFAIReasoningOptions(alias) valueForKey:@"id"] containsObject:@"high"],@"256 reasoning boolean alone no longer hides controls");
 alias[@"modelMetadata"]=@{@"private-alias":TFAISanitizeModelMetadata(@{@"reasoning":@YES,@"reasoning_options":@[]})};
 Check(TFAIReasoningOptions(alias).count==1,@"256 fixed reasoning has no invented effort dial");
 alias[@"modelMetadata"]=@{@"private-alias":TFAISanitizeModelMetadata(@{@"input_modalities":@[@"text"],@"capabilities":@{@"tools":@NO}})};
 Check(!TFAIImagesAllowed(alias)&&!TFAIToolsAllowed(alias),@"256 explicit same-service text-only/tool declarations honored");
 alias[@"capabilityOverrides"]=@{TFAICapabilityScope(alias):@{@"image":@"supported",@"tools":@"supported"}};
 Check(TFAIImagesAllowed(alias)&&TFAIToolsAllowed(alias),@"256 manual override repairs incorrect endpoint declarations");
 alias[@"baseURL"]=@"https://provider-v4.example.invalid/tool-forced/v1";alias[@"modelMetadataScope"]=TFAIModelMetadataScope(alias);alias[@"capabilityOverrides"]=@{TFAICapabilityScope(alias):@{@"tools":@"unsupported"}};NSDictionary *probe=Probe(alias,@"tools",&error);Check(probe&&[probe[@"status"] isEqual:@"supported"],@"256 diagnostic can test a service-declared disabled feature");
 NSMutableDictionary *scope=[Conn(@"chat") mutableCopy];scope[@"model"]=@"scope-alpha";scope[@"capabilities"]=@{@"image":@"supported"};scope[@"capabilitiesScope"]=TFAICapabilityScope(scope);scope[@"model"]=@"scope-beta";
 Check([TFAIObservedCapabilities(scope)[@"image"] isEqual:@"unknown"]&&![TFAIResolvedCapability(scope,@"image")[@"source"] isEqual:@"实际响应已验证"],@"256 success evidence never leaks to another model");
 NSMutableDictionary *catalog=[Conn(@"chat") mutableCopy];catalog[@"model"]=@"deepseek-v4-pro";catalog[@"baseURL"]=@"https://api.deepseek.com";
 Check([TFAICatalogModelMetadata(catalog)[@"authoritative"] boolValue]&&!TFAIImagesAllowed(catalog),@"256 exact endpoint catalog distinguishes text-only model");
 catalog[@"baseURL"]=@"https://relay.invalid/v1";
 Check(![TFAICatalogModelMetadata(catalog)[@"authoritative"] boolValue]&&TFAIImagesAllowed(catalog),@"256 another endpoint catalog cannot impose negative image limits on relay");
 catalog[@"baseURL"]=@"https://api.cerebras.ai/v1";catalog[@"model"]=@"qwen-3.8-27b";catalog[@"reasoningEffort"]=@"high";
 NSDictionary *body=TFAIRequestBody(plain,catalog,@[],NO,&error);Check([body[@"reasoning_effort"] isEqual:@"high"]&&!body[@"enable_thinking"],@"256 endpoint dialect outranks Qwen name heuristic");
 catalog=[Conn(@"siliconflow") mutableCopy];catalog[@"model"]=@"Qwen/Qwen3-235B-A22B";catalog[@"reasoningEffort"]=@"none";body=TFAIRequestBody(plain,catalog,@[],NO,&error);
 Check([body[@"enable_thinking"] isEqual:@NO]&&!body[@"reasoning_effort"],@"256 hybrid off emits boolean false instead of fake effort tier");
 NSMutableDictionary *toggle=[Conn(@"chat") mutableCopy];toggle[@"model"]=@"vendor/DeepSeek-V3.2";toggle[@"reasoningEffort"]=@"enabled";body=TFAIRequestBody(plain,toggle,@[],NO,&error);
 Check([body[@"thinking"][@"type"] isEqual:@"enabled"]&&!body[@"reasoning_effort"],@"256 hybrid on remains available separately from effort tiers");
 alias[@"capabilityOverrides"]=@{TFAICapabilityScope(alias):@{@"image":@"supported",@"tools":@"supported"}};NSString *identifier=[@"capability256-" stringByAppendingString:NSUUID.UUID.UUIDString];alias[@"id"]=identifier;
 alias[@"thinkingOverrides"]=@{TFAIThinkingScope(alias):@{@"wire":@"reasoning_effort",@"levels":@[@"high"]}};
 Check([TFAIConnections save:alias secret:nil error:&error],@"256 capability and thinking overrides persist");
 NSDictionary *saved=nil;for(NSDictionary *item in TFAIConnections.all)if([item[@"id"] isEqual:identifier])saved=item;
 Check(TFAIImagesAllowed(saved)&&TFAIToolsAllowed(saved)&&[[TFAIReasoningOptions(saved) valueForKey:@"id"] containsObject:@"high"],@"256 reload keeps user overrides above catalog and API declarations");
 [TFAIConnections remove:identifier];
}

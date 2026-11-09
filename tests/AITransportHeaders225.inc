static void HeaderNetwork225Tests(NSString *base){
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;id old=[defaults objectForKey:@"TFAI.Connections.v1"],oldDefault=[defaults objectForKey:@"TFAI.DefaultConnection.v1"];
 NSString *identifier=[@"socket225-" stringByAppendingString:NSUUID.UUID.UUIDString];NSMutableDictionary *c=[@{@"id":identifier,@"protocol":@"chat",@"baseURL":[base stringByAppendingString:@"/headers/v1"],@"model":@"ok",@"allowLANHTTP":@YES} mutableCopy];TFAITransport *transport=[TFAITransport new];
 @try{
  NSDictionary *r=Run(transport,c,@"models",nil);Check([r[@"error"] integerValue]==403,@"225 actual HTTP server refuses missing client header");
  c[@"customHeaders"]=@{@"X-Client-Token":@"socket-fixture225",@"Authorization":@"Bearer explicit-fixture225"};NSError *error=nil;BOOL saved=[TFAIConnections save:c secret:nil error:&error];Check(saved,@"225 socket fixture stores header credentials");if(!saved)return;[c removeObjectForKey:@"customHeaders"];
  r=Run(transport,c,@"models",nil);Check([r[@"models"] count]==2,@"225 actual HTTP discovery receives required headers");
  for(NSString *protocol in @[@"chat",@"responses",@"anthropic"]){c[@"protocol"]=protocol;r=Run(transport,c,@"chat",nil);Check(Type(r[@"events"],@"done").count==1&&Type(r[@"events"],@"text").count>0&&Type(r[@"events"],@"error").count==0,[protocol stringByAppendingString:@" 225 actual HTTP SSE receives custom client/auth headers"]);}
  c[@"allowLANHTTP"]=@NO;r=Run(transport,c,@"models",nil);Check([r[@"error"] integerValue]==1,@"225 revoking LAN permission blocks socket request");
 }@finally{[TFAIConnections remove:identifier];if(old)[defaults setObject:old forKey:@"TFAI.Connections.v1"];else[defaults removeObjectForKey:@"TFAI.Connections.v1"];if(oldDefault)[defaults setObject:oldDefault forKey:@"TFAI.DefaultConnection.v1"];else[defaults removeObjectForKey:@"TFAI.DefaultConnection.v1"];}
}

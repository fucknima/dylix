#import <Foundation/Foundation.h>
#import "../App/AI/Agent/TFAIMCP.h"
#import "../App/AI/Registry/TFAIToolRegistry.h"
@interface TFAIMCP (TestStorage)
- (BOOL)persist:(NSArray *)records error:(NSError **)error;
@end
@interface MemoryMCP : TFAIMCP @end
@implementation MemoryMCP
- (BOOL)persist:(NSArray *)records error:(NSError **)error{[self setValue:[records mutableCopy] forKey:@"records"];return YES;}
@end
static NSUInteger Checks;
static void Check(BOOL ok,NSString *name){if(!ok){NSLog(@"FAIL %@",name);exit(1);}Checks++;NSLog(@"PASS %@",name);}
static NSDictionary *Await(void(^start)(TFAIResult),BOOL expectError){
 __block BOOL done=NO;__block NSDictionary *result;__block NSError *failure;
 start(^(NSDictionary *r,NSError *e){result=r;failure=e;done=YES;});
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:8];while(!done&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
 Check(done&&(expectError?failure!=nil:failure==nil),expectError?@"request rejected before execution":@"request completed");return result;
}
int main(int argc,char **argv){@autoreleasepool{
 MemoryMCP *mcp=[MemoryMCP new];NSString *identifier=NSUUID.UUID.UUIDString,*session=@"access-fixture";
 [mcp setValue:[@[@{@"id":identifier,@"name":@"HTTP fixture",@"url":@(argv[1]),@"allowedTools":@[]}] mutableCopy] forKey:@"records"];
 Check([mcp schemas:session].count==0,@"configured service does not expose tools by default");
 NSDictionary *discovered=Await(^(TFAIResult done){[mcp discover:identifier completion:done];},NO);
 Check([discovered[@"tools"] count]==4,@"real HTTP discovery handles paged JSON and SSE replies with negotiated protocol");
 for(NSDictionary *tool in discovered[@"tools"]){NSString *name=tool[@"name"];
  if([name isEqual:@"write_file"]){Check(![mcp setAllowed:YES tool:name server:identifier error:nil],@"project write remains blocked despite forged read-only hint");continue;}
  Check([mcp setAllowed:YES tool:name server:identifier error:nil],@"queries and device controls can be explicitly enabled");
  Check([TFAIMCP readOnlyTool:tool]==[name isEqual:@"search_docs"],@"missing destructive hint accepted for read-only query; control hint cannot bypass confirmation");
 }
 [mcp setEnabled:YES server:identifier session:session];NSArray *schemas=[mcp schemas:session];Check(schemas.count==3,@"only enabled tools appear in bound session");Check([mcp schemas:@"other"].count==0,@"other sessions remain isolated");
 NSMutableDictionary *names=[NSMutableDictionary new];
 for(NSDictionary *schema in schemas){NSDictionary *info=[mcp approvalInfo:schema[@"name"] session:session];names[info[@"tool"][@"name"]]=schema[@"name"];}
 Check(![[mcp approvalInfo:names[@"search_docs"] session:session][@"requiresApproval"] boolValue],@"read-only query uses explicit tool allowance");
 NSMutableDictionary *context=[@{@"mcpNames":[schemas valueForKey:@"name"],@"mcpConfirmNames":@[names[@"tap_screen"],names[@"get_screen_info"]],@"hasApproval":@YES,@"readOnly":@NO} mutableCopy];
 NSArray *entries=[TFAIToolRegistry entries:schemas context:context];BOOL controlsCorrect=YES;for(NSDictionary *entry in entries)if(![entry[@"name"] isEqual:names[@"search_docs"]])controlsCorrect&=[entry[@"requiresUserApproval"] boolValue]&&![entry[@"effect"] isEqual:@"read"];
 Check(entries.count==3&&controlsCorrect,@"tool registry reports device controls as requiring approval");
 context[@"readOnly"]=@YES;Check([TFAIToolRegistry schemas:schemas context:context].count==1,@"ask/read-only mode hides interactive and unknown MCP tools");context[@"readOnly"]=@NO;context[@"hasApproval"]=@NO;Check([TFAIToolRegistry schemas:schemas context:context].count==1,@"runtime without confirmation support exposes only read-only queries");
 Await(^(TFAIResult done){[mcp call:names[@"search_docs"] arguments:@{@"query":@"test"} session:session completion:done];},NO);
 for(NSString *raw in @[@"tap_screen",@"get_screen_info"]){NSString *name=names[raw];
  Check([[mcp approvalInfo:name session:session][@"requiresApproval"] boolValue],@"device controls and unknown tools require call approval");
  Await(^(TFAIResult done){[mcp call:name arguments:@{} session:session completion:done];},YES);
  NSDictionary *reply=Await(^(TFAIResult done){[mcp call:name arguments:@{} session:session approved:YES completion:done];},NO);
  Check([reply[@"content"][0][@"text"] isEqual:raw],@"approved call reaches the actual HTTP server");
 }
 Await(^(TFAIResult done){[mcp call:names[@"search_docs"] arguments:@{@"query":@"DELETE FROM notes"} session:session approved:YES completion:done];},YES);
 [mcp setAllowed:NO tool:@"tap_screen" server:identifier error:nil];Await(^(TFAIResult done){[mcp call:names[@"tap_screen"] arguments:@{} session:session approved:YES completion:done];},YES);
 [mcp setEnabled:NO server:identifier session:session];Check([mcp schemas:session].count==0,@"session switch off immediately revokes schemas");Await(^(TFAIResult done){[mcp call:names[@"get_screen_info"] arguments:@{} session:session approved:YES completion:done];},YES);
 [mcp setEnabled:YES server:identifier session:session];Await(^(TFAIResult done){[mcp call:names[@"search_docs"] arguments:@{@"query":@42} session:session completion:done];},YES);
 Await(^(TFAIResult done){[mcp call:names[@"search_docs"] arguments:@{@"query":@"__delay__"} session:session completion:done];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[mcp setEnabled:NO server:identifier session:session];});},YES);
 NSArray *audit=[mcp auditForSession:session];Check(audit.count>=4&&![audit.lastObject[@"success"] boolValue],@"inflight revocation records cancellation");Check(![[audit description] containsString:@"__delay__"]&&[mcp auditForSession:@"foreign"].count==0,@"audit has no argument values and isolates sessions");
 [mcp setEnabled:YES server:identifier session:session];NSArray *savedRecords=[mcp valueForKey:@"records"],*savedTools=[[mcp valueForKey:@"tools"] objectForKey:identifier];NSMutableArray *many=[NSMutableArray new],*allowed=[NSMutableArray new];for(int i=0;i<45;i++){NSString *raw=[NSString stringWithFormat:@"lookup_%d",i];[allowed addObject:raw];[many addObject:@{@"name":raw,@"annotations":@{@"readOnlyHint":@YES},@"inputSchema":@{@"type":@"object",@"properties":@{}}}];}NSMutableDictionary *server=[savedRecords.firstObject mutableCopy];server[@"allowedTools"]=allowed;[mcp setValue:[@[server] mutableCopy] forKey:@"records"];[[mcp valueForKey:@"tools"] setObject:many forKey:identifier];Check([mcp schemas:session].count==32,@"advertised MCP tools capped at32");NSMutableDictionary *huge=[many[0] mutableCopy];huge[@"inputSchema"]=@{@"type":@"object",@"description":[@"x" stringByPaddingToLength:17000 withString:@"x" startingAtIndex:0]};[many replaceObjectAtIndex:0 withObject:huge];[[mcp valueForKey:@"tools"] setObject:many forKey:identifier];Check([mcp schemas:session].count==32&&[[mcp schemas:session].firstObject[@"description"] length]<2000,@"oversized individual schema omitted within budget");[mcp setValue:savedRecords forKey:@"records"];[[mcp valueForKey:@"tools"] setObject:savedTools forKey:identifier];
 NSLog(@"TOTAL %lu MCP access checks passed",(unsigned long)Checks);
}return 0;}

#define main ExistingBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
#import <objc/runtime.h>
static BOOL Revoked;static NSUInteger Revision=1,Calls;
static NSArray *Schemas(id self,SEL cmd,NSString *session){return Revoked?@[]:@[@{@"name":@"mcp_fixture_tap",@"parameters":@{@"type":@"object",@"properties":@{}}}];}
static NSDictionary *Info(id self,SEL cmd,NSString *name,NSString *session){return Revoked?nil:@{@"requiresApproval":@YES,@"server":@{@"name":@"fixture",@"revision":@(Revision)},@"tool":@{@"name":@"tap_screen"}};}
static void Call(id self,SEL cmd,NSString *name,NSDictionary *args,NSString *session,BOOL approved,TFAIResult done){Check(approved,@"runtime passes approval only after confirmation");Calls++;done(@{@"ok":@YES},nil);}
@interface MCPApprovalRuntime : TFProjectAIRuntime
@property NSError *failure;
@property NSDictionary *result;
@end
@implementation MCPApprovalRuntime
- (void)recordCall:(NSDictionary *)call result:(NSDictionary *)result error:(NSError *)error index:(NSUInteger)index{self.failure=error;self.result=result;}
@end
static MCPApprovalRuntime *Run(void(^approval)(NSDictionary *,void(^)(BOOL,NSArray *))){
 Revoked=NO;MCPApprovalRuntime *r=[MCPApprovalRuntime new];r.running=YES;r.sessionID=@"fixture";r.requestMode=@"develop";r.approval=approval;r.completedCalls=[NSMutableSet new];r.toolStarts=[NSMutableDictionary new];r.calls=[@[@{@"name":@"mcp_fixture_tap",@"id":NSUUID.UUID.UUIDString,@"arguments":@{}}] mutableCopy];r.advertisedSchemas=[r requestSchemas];[r runCall:0];return r;
}
int main(){@autoreleasepool{
 method_setImplementation(class_getInstanceMethod(TFAIMCP.class,@selector(schemas:)),(IMP)Schemas);
 class_addMethod(TFAIMCP.class,@selector(approvalInfo:session:),(IMP)Info,"@@:@@");
 class_addMethod(TFAIMCP.class,@selector(call:arguments:session:approved:completion:),(IMP)Call,"v@:@@@B@?");
 FixtureContextOverrides=@{@"mcpNames":@[@"mcp_fixture_tap"],@"mcpConfirmNames":@[@"mcp_fixture_tap"]};
 NSUInteger before=Calls;MCPApprovalRuntime *r=Run(^(NSDictionary *p,void(^decide)(BOOL,NSArray *)){decide(NO,nil);});Check(r.failure&&Calls==before,@"denied MCP call never executes");
 r=Run(^(NSDictionary *p,void(^decide)(BOOL,NSArray *)){decide(YES,nil);decide(YES,nil);});Check([r.result[@"ok"] boolValue]&&Calls==before+1,@"approved call executes once despite duplicate callback");
 before=Calls;r=Run(^(NSDictionary *p,void(^decide)(BOOL,NSArray *)){Revoked=YES;decide(YES,nil);});Check(r.failure&&Calls==before,@"revocation during approval prevents execution");
 r=Run(^(NSDictionary *p,void(^decide)(BOOL,NSArray *)){Revision++;decide(YES,nil);});Check(r.failure&&Calls==before,@"changed service while awaiting approval prevents execution");
 r=Run(nil);Check(r.failure&&Calls==before,@"runtime without approval handler cannot execute control tool");
 __block void(^pending)(BOOL,NSArray *);r=Run(^(NSDictionary *p,void(^decide)(BOOL,NSArray *)){pending=[decide copy];});r.running=NO;r.generation++;pending(YES,nil);Check(Calls==before,@"cancelled runtime ignores late approval");
 NSLog(@"MCP runtime approval regression passed");
}return 0;}

#import <Foundation/Foundation.h>
#import "../App/Remote/DXFlexBridge.h"

static void Check(BOOL condition, NSString *name) { if (!condition) { NSLog(@"FAIL %@", name); exit(1); } }
int main(void) { @autoreleasepool {
 DXFlexBridge *bridge=DXFlexBridge.shared;
 NSString *device=NSUUID.UUID.UUIDString, *other=NSUUID.UUID.UUIDString, *session=NSUUID.UUID.UUIDString;
 NSError *error=nil;
 Check(![bridge publish:@{@"report":@"x",@"bundleID":@"test.app"} device:device error:&error] && error, @"reject incomplete report");
 Check(![bridge hasContextForSession:session], @"no unbound context");
 NSDictionary *input=@{@"report":@"Runtime Context: UIView -> UIViewController",@"bundleID":@"test.app",@"className":@"UIView"};
 Check([bridge publish:input device:device error:nil]!=nil, @"publish selected context");
 [bridge bindSession:session device:other]; Check(![bridge hasContextForSession:session], @"other device cannot bind missing context");
 [bridge bindSession:session device:device]; Check([[bridge contextForSession:session][@"report"] isEqual:input[@"report"]], @"bound read returns report");
 Check(![[bridge contextForSession:session][@"capabilities"][@"touchGestures"] boolValue],@"older plugin does not advertise touch capability");
 [bridge publish:@{@"report":@"touch",@"bundleID":@"test.app",@"className":@"UIView",@"capabilities":@{@"touchGestures":@YES,@"arbitraryInvoke":@YES}} device:device error:nil];
 Check(![[bridge contextForSession:session][@"capabilities"][@"touchGestures"] boolValue],@"capability snapshot does not mutate in-flight session");
 [bridge bindSession:session device:device];Check([[bridge contextForSession:session][@"capabilities"][@"touchGestures"] boolValue]&&![bridge contextForSession:session][@"capabilities"][@"arbitraryInvoke"],@"only supported capability keys retained on rebind");
 [bridge publish:@{@"report":@"invalid",@"bundleID":@"test.app",@"className":@"UIView",@"capabilities":@{@"touchGestures":@"true"}} device:device error:nil];[bridge bindSession:session device:device];Check(![[bridge contextForSession:session][@"capabilities"][@"touchGestures"] boolValue],@"invalid capability type defaults unavailable");
 [bridge publish:input device:device error:nil];[bridge bindSession:session device:device];
 [bridge publish:@{@"report":@"new view",@"bundleID":@"test.app",@"className":@"UIButton"} device:device error:nil];
 Check([[bridge contextForSession:session][@"report"] isEqual:input[@"report"]], @"in-flight session keeps its selected snapshot");
 [bridge bindSession:session device:device]; Check([[bridge contextForSession:session][@"report"] isEqual:@"new view"], @"next send refreshes session snapshot");
 Check(![bridge hasLiveAgentForSession:session], @"no live tool before device heartbeat");
 [bridge nextForDevice:device];Check([bridge hasLiveAgentForSession:session], @"heartbeat enables live tools");
 __block NSDictionary *reply=nil;__block NSError *failure=nil;
 [bridge enqueueForSession:session operation:@"current" arguments:@{} completion:^(NSDictionary *result,NSError *error){reply=result;failure=error;}];
 NSDictionary *command=nil;for(NSUInteger i=0;i<100&&!command[@"id"];i++){command=[bridge nextForDevice:device];if(!command[@"id"])[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
 Check([command[@"operation"] isEqual:@"current"] && [command[@"expiresAt"] doubleValue]>NSDate.date.timeIntervalSince1970,@"queued command reaches the paired device");
 Check(![bridge reply:@{@"id":command[@"id"],@"result":@{@"ok":@YES}} device:other error:nil],@"other device cannot complete command");
 Check([bridge reply:@{@"id":command[@"id"],@"result":@{@"ok":@YES}} device:device error:nil],@"paired device completes command");
 for(NSUInteger i=0;i<100&&!reply;i++)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
 Check([reply[@"ok"] boolValue]&&!failure,@"completion returns exactly the device result");
 Check(![bridge reply:@{@"id":command[@"id"],@"result":@{}} device:device error:nil],@"completed command cannot replay");
 reply=nil;
 [bridge enqueueForSession:session operation:@"sandbox_read" arguments:@{@"path":@"Documents/log.txt",@"tail":@YES,@"limit":@524288} completion:^(NSDictionary *result,NSError *error){reply=result;failure=error;}];
 command=nil;for(NSUInteger i=0;i<100&&!command[@"id"];i++){command=[bridge nextForDevice:device];if(!command[@"id"])[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
 NSString *largeText=[@"\n" stringByPaddingToLength:524288 withString:@"\n" startingAtIndex:0];
 Check(![bridge reply:@{@"id":command[@"id"],@"result":@{@"text":largeText}} device:other error:nil],@"large log replies still reject forged devices");
 NSString *tooLarge=[@"A" stringByPaddingToLength:4*1024*1024 withString:@"A" startingAtIndex:0];
 Check(![bridge reply:@{@"id":command[@"id"],@"result":@{@"text":tooLarge}} device:device error:nil],@"encoded log reply retains bounded transport limit");
 Check([bridge reply:@{@"id":command[@"id"],@"result":@{@"text":largeText}} device:device error:nil],@"512 KiB log with JSON escaping passes bridge");
 for(NSUInteger i=0;i<100&&!reply;i++)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
 Check([reply[@"text"] isEqual:largeText]&&!failure,@"large log arrives intact in bound session");
 reply=nil;
 [bridge enqueueForSession:session operation:@"capture_screen" arguments:@{} completion:^(NSDictionary *result,NSError *error){reply=result;failure=error;}];
 command=nil;for(NSUInteger i=0;i<100&&!command[@"id"];i++){command=[bridge nextForDevice:device];if(!command[@"id"])[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
 Check([command[@"operation"] isEqual:@"capture_screen"],@"paired agent can receive screenshot request");
 NSString *oversized=[@"A" stringByPaddingToLength:260*1024 withString:@"A" startingAtIndex:0];
 Check(![bridge reply:@{@"id":command[@"id"],@"result":@{@"imageBase64":oversized}} device:device error:nil],@"oversized screenshot reply rejected");
 Check([bridge reply:@{@"id":command[@"id"],@"result":@{@"mime":@"image/jpeg",@"imageBase64":@"aGVsbG8="}} device:device error:nil],@"bounded screenshot reply accepted");
 for(NSUInteger i=0;i<100&&!reply;i++)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
 Check([reply[@"imageBase64"] isEqual:@"aGVsbG8="]&&!failure,@"screenshot returns only to bound session");
 for(NSString *operation in @[@"gesture",@"gesture_capabilities",@"class_header",@"input_text",@"set_control_value",@"tool_catalog",@"chat_status",@"flex_ui_state",@"minimize_chat",@"restore_chat",@"open_tool",@"navigate_back",@"dismiss_tool",@"select_row",@"set_search",@"flex_scroll"]){
  reply=nil;failure=nil;
  [bridge enqueueForSession:session operation:operation arguments:@{@"surface":@"target"} completion:^(NSDictionary *result,NSError *error){reply=result;failure=error;}];
  command=nil;for(NSUInteger i=0;i<100&&!command[@"id"];i++){command=[bridge nextForDevice:device];if(!command[@"id"])[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
  Check([command[@"operation"] isEqual:operation],[@"registered workspace operation: " stringByAppendingString:operation]);
  Check(![bridge nextForDevice:other][@"id"],@"workspace commands isolated to paired device");
  Check([bridge reply:@{@"id":command[@"id"],@"result":@{@"ok":@YES}} device:device error:nil],@"workspace result accepted");
  for(NSUInteger i=0;i<100&&!reply;i++)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
  Check([reply[@"ok"] boolValue]&&!failure,@"workspace operation completes");
 }
 [bridge enqueueForSession:session operation:@"invoke" arguments:@{} completion:^(NSDictionary *result,NSError *error){failure=error;}];
 Check(failure!=nil,@"unregistered method invocation rejected");failure=nil;
 [bridge enqueueForSession:session operation:@"current" arguments:@{} completion:^(NSDictionary *result,NSError *error){failure=error;}];
 for(NSUInteger i=0;i<100&&![[bridge nextForDevice:device] objectForKey:@"id"];i++)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
 [bridge revokeDevice:other]; Check([bridge hasContextForSession:session], @"other revoke preserves context");
 [bridge revokeDevice:device]; Check(![bridge hasContextForSession:session], @"revoke clears context and session binding");
 for(NSUInteger i=0;i<100&&!failure;i++)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
 Check(failure!=nil && ![bridge nextForDevice:device][@"id"],@"revoke cancels pending command");
 NSLog(@"FLEX bridge regression passed");
 } return 0; }

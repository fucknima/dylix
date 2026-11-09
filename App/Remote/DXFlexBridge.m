#import "DXFlexBridge.h"

static NSError *DXFlexError(NSString *message) { return [NSError errorWithDomain:@"Dylix.FLEX" code:1 userInfo:@{NSLocalizedDescriptionKey:message}]; }
@interface DXFlexBridge ()
@property dispatch_queue_t queue;
@property NSMutableDictionary<NSString *, NSDictionary *> *devices;
@property NSMutableDictionary<NSString *, NSDictionary *> *sessions;
@property NSMutableDictionary<NSString *, NSNumber *> *heartbeats;
@property NSMutableDictionary<NSString *, NSMutableDictionary *> *commands;
@property NSMutableArray<NSString *> *order;
@end
@implementation DXFlexBridge
+ (instancetype)shared { static DXFlexBridge *bridge; static dispatch_once_t once; dispatch_once(&once, ^{ bridge=[DXFlexBridge new]; }); return bridge; }
- (instancetype)init { if ((self=[super init])) { _queue=dispatch_queue_create("com.dylix.flex-context", DISPATCH_QUEUE_SERIAL); _devices=[NSMutableDictionary new]; _sessions=[NSMutableDictionary new]; _heartbeats=[NSMutableDictionary new]; _commands=[NSMutableDictionary new]; _order=[NSMutableArray new]; } return self; }
- (NSDictionary *)publish:(NSDictionary *)input device:(NSString *)device error:(NSError **)error {
 NSString *report=input[@"report"], *bundle=input[@"bundleID"], *name=input[@"className"];
 if (![report isKindOfClass:NSString.class] || ![bundle isKindOfClass:NSString.class] || ![name isKindOfClass:NSString.class] || !device.length || !report.length || !bundle.length || !name.length || [report lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>64*1024 || bundle.length>256 || name.length>256) { if (error) *error=DXFlexError(@"FLEX 现场报告格式无效或超过 64 KB"); return nil; }
 NSTimeInterval now=NSDate.date.timeIntervalSince1970;
 NSDictionary *reported=[input[@"capabilities"] isKindOfClass:NSDictionary.class]?input[@"capabilities"]:@{};
 BOOL touch=[reported[@"touchGestures"] isKindOfClass:NSNumber.class]&&[reported[@"touchGestures"] boolValue];
 NSDictionary *snapshot=@{@"report":report, @"bundleID":bundle, @"className":name, @"capturedAt":@(now), @"expiresAt":@(now+900),@"capabilities":@{@"touchGestures":@(touch)}};
 dispatch_sync(self.queue, ^{ self.devices[device]=snapshot; });
 return @{@"bundleID":bundle, @"className":name, @"expiresAt":snapshot[@"expiresAt"]};
}
- (void)bindSession:(NSString *)session device:(NSString *)device { if (!session.length || !device.length) return; dispatch_sync(self.queue, ^{ NSDictionary *snapshot=self.devices[device]; if ([snapshot[@"expiresAt"] doubleValue]>NSDate.date.timeIntervalSince1970) self.sessions[session]=@{@"device":device,@"snapshot":snapshot}; }); }
- (NSDictionary *)contextForSession:(NSString *)session { if (!session.length) return nil; __block NSDictionary *snapshot=nil; dispatch_sync(self.queue, ^{ NSDictionary *entry=self.sessions[session],*candidate=entry[@"snapshot"]; if ([candidate[@"expiresAt"] doubleValue]>NSDate.date.timeIntervalSince1970) snapshot=candidate; else if (entry) [self.sessions removeObjectForKey:session]; }); return snapshot; }
- (BOOL)hasContextForSession:(NSString *)session { return [self contextForSession:session]!=nil; }
- (BOOL)hasLiveAgentForSession:(NSString *)session {
 if (!session.length) return NO;
 __block BOOL live=NO; dispatch_sync(self.queue, ^{
  NSDictionary *entry=self.sessions[session]; NSString *device=entry[@"device"];
  live=device.length && [entry[@"snapshot"][@"expiresAt"] doubleValue]>NSDate.date.timeIntervalSince1970 &&
       NSDate.date.timeIntervalSince1970-[self.heartbeats[device] doubleValue]<5;
 }); return live;
}
- (NSDictionary *)nextForDevice:(NSString *)device {
 if (!device.length) return @{};
 __block NSDictionary *next=@{}; dispatch_sync(self.queue, ^{
  self.heartbeats[device]=@(NSDate.date.timeIntervalSince1970);
  for (NSString *identifier in self.order) {
   NSDictionary *entry=self.commands[identifier];
   if ([entry[@"device"] isEqual:device]) { next=@{@"id":identifier,@"operation":entry[@"operation"],@"arguments":entry[@"arguments"],@"sessionID":entry[@"sessionID"],@"expiresAt":entry[@"expiresAt"]}; break; }
  }
 }); return next;
}
- (void)complete:(NSMutableDictionary *)entry result:(NSDictionary *)result error:(NSError *)error {
 NSString *identifier=entry[@"id"]; if (!self.commands[identifier]) return;
 [self.commands removeObjectForKey:identifier]; [self.order removeObject:identifier];
 void (^completion)(NSDictionary *,NSError *)=entry[@"completion"];
 if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(result,error); });
}
- (BOOL)reply:(NSDictionary *)input device:(NSString *)device error:(NSError **)error {
 NSString *identifier=input[@"id"]; id result=input[@"result"],message=input[@"error"];
 if (![identifier isKindOfClass:NSString.class] || (!result && !message) || (result && ![result isKindOfClass:NSDictionary.class]) || (message && (![message isKindOfClass:NSString.class] || [message length]>1000))) { if (error) *error=DXFlexError(@"FLEX 返回格式无效"); return NO; }
 NSData *encoded=[NSJSONSerialization dataWithJSONObject:input options:0 error:nil];
 if (!encoded || encoded.length>4*1024*1024) { if (error) *error=DXFlexError(@"FLEX 返回超过 4 MiB"); return NO; }
 __block BOOL accepted=NO; dispatch_sync(self.queue, ^{
  NSMutableDictionary *entry=self.commands[identifier]; if (![entry[@"device"] isEqual:device]) return;
  if(![entry[@"operation"] isEqual:@"sandbox_read"]&&encoded.length>256*1024)return;
  accepted=YES; [self complete:entry result:result error:message?DXFlexError(message):nil];
 });
 if (!accepted && error) *error=DXFlexError(@"命令已过期或不属于当前设备");
 return accepted;
}
- (void)enqueueForSession:(NSString *)session operation:(NSString *)operation arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *,NSError *))completion {
 NSSet *allowed=[NSSet setWithArray:@[@"gesture",@"gesture_capabilities",@"class_header",@"input_text",@"set_control_value",@"tool_catalog",@"chat_status",@"flex_ui_state",@"minimize_chat",@"restore_chat",@"open_tool",@"navigate_back",@"dismiss_tool",@"select_row",@"set_search",@"flex_scroll",@"capabilities",@"current",@"capture_screen",@"screen_elements",@"hit_test",@"view_tree",@"object_info",@"class_search",@"class_info",@"runtime_images",@"network_list",@"cookies_list",@"sandbox_list",@"defaults_keys",@"network_detail",@"sandbox_read",@"defaults_get",@"keychain_list",@"select_object",@"activate_control",@"scroll_view",@"set_view",@"set_network_recording",@"undo"]];
 NSData *encoded=[NSJSONSerialization dataWithJSONObject:arguments?:@{} options:0 error:nil];
 if (!completion || !session.length || ![allowed containsObject:operation] || ![arguments isKindOfClass:NSDictionary.class] || !encoded || encoded.length>16*1024) { if (completion) completion(nil,DXFlexError(@"FLEX 操作未注册或参数超过 16 KB")); return; }
 dispatch_async(self.queue, ^{
  NSDictionary *binding=self.sessions[session]; NSString *device=binding[@"device"];
  BOOL live=device.length && [binding[@"snapshot"][@"expiresAt"] doubleValue]>NSDate.date.timeIntervalSince1970 && NSDate.date.timeIntervalSince1970-[self.heartbeats[device] doubleValue]<5;
  if (!device.length || !live || self.commands.count>=8) { if(completion)dispatch_async(dispatch_get_main_queue(),^{completion(nil,DXFlexError(@"FLEX 连接已离线或命令队列已满"));}); return; }
  NSString *identifier=NSUUID.UUID.UUIDString;
  NSTimeInterval timeout=[@[@"gesture",@"class_header",@"input_text",@"set_control_value",@"flex_ui_state",@"minimize_chat",@"restore_chat",@"open_tool",@"navigate_back",@"dismiss_tool",@"select_row",@"set_search",@"flex_scroll",@"capture_screen",@"network_detail",@"sandbox_read",@"defaults_get",@"keychain_list",@"activate_control",@"scroll_view",@"set_view",@"set_network_recording",@"undo"] containsObject:operation]?120:20;
  NSMutableDictionary *entry=[@{@"id":identifier,@"device":device,@"sessionID":session,@"operation":operation,@"arguments":[arguments copy],@"completion":[completion copy],@"expiresAt":@(NSDate.date.timeIntervalSince1970+timeout)} mutableCopy];
  self.commands[identifier]=entry;[self.order addObject:identifier];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(timeout*NSEC_PER_SEC)),self.queue,^{ if(self.commands[identifier])[self complete:entry result:nil error:DXFlexError(@"FLEX 命令已过期")]; });
 });
}
- (void)revokeDevice:(NSString *)device { dispatch_sync(self.queue, ^{
 if (!device) { [self.devices removeAllObjects]; [self.sessions removeAllObjects]; [self.heartbeats removeAllObjects]; }
 else { [self.devices removeObjectForKey:device]; [self.heartbeats removeObjectForKey:device]; for (NSString *key in self.sessions.allKeys) if ([self.sessions[key][@"device"] isEqual:device]) [self.sessions removeObjectForKey:key]; }
 for (NSString *identifier in self.order.copy) { NSMutableDictionary *entry=self.commands[identifier]; if (!device || [entry[@"device"] isEqual:device]) [self complete:entry result:nil error:DXFlexError(@"FLEX 授权已撤销")]; }
 }); }
@end

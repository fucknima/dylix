@interface UIViewController (Continuity251Calls)
- (void)sendTapped;
- (void)updateSend;
- (void)textViewDidChange:(UITextView *)text;
- (void)stopCurrentTask;
- (void)foreground;
- (void)handleEvent:(NSDictionary *)event;
@end
@interface Continuity251UIRuntime : NSObject <TFAIRuntimeV2>
@property(nonatomic,copy) TFAIEvent event;
@property(nonatomic,copy) void(^approval)(NSDictionary *,void(^)(BOOL,NSArray *));
@property NSArray *sent;
@property NSUInteger sendCount;
@property BOOL buildAllowed;

@property NSUInteger queued,stopped;
@end
@implementation Continuity251UIRuntime
- (void)activateSession:(NSString *)session{}
- (void)send:(NSArray *)messages session:(NSString *)session{self.sent=messages;self.sendCount++;}
- (BOOL)configurePermissionPreset:(NSString *)preset paths:(NSArray *)paths error:(NSError **)error{return YES;}
- (void)setNextConnection:(NSDictionary *)connection{}
- (void)setInteractionMode:(NSString *)mode{}
- (void)undo:(TFAIResult)done{done(@{},nil);}

- (BOOL)enqueueUserMessage:(NSDictionary *)message{self.queued++;NSMutableDictionary *m=[message mutableCopy];m[@"messageID"]=NSUUID.UUID.UUIDString;m[@"timestamp"]=@(NSDate.date.timeIntervalSince1970);if(self.event)self.event(@{@"type":@"user_queued",@"message":m});return YES;}
- (void)stop{self.stopped++;}
@end
static UIViewController *TMCContinuity251UI(void){
 NSString *scope=[@"continuity251-" stringByAppendingString:NSUUID.UUID.UUIDString];NSMutableDictionary *session=[TFAISessions create:scope title:@"执行中补充与中断续接"];
 Continuity251UIRuntime *runtime=[Continuity251UIRuntime new];UIViewController *chat=TFAIChatController(@"",scope,runtime,nil);TFAIConfigureChat(chat,session,YES,nil);UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:chat];
 NSMutableArray *checks=[NSMutableArray new];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[checks addObject:@{@"name":name,@"passed":@(ok)}];};
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 [chat setValue:@{@"id":@"continuity251",@"model":@"fixture",@"protocol":@"chat"} forKey:@"selectedConnection"];
 runtime.stopped=0;[chat setValue:@YES forKey:@"running"];UITextView *input=[chat valueForKey:@"input"];input.text=@"补充：请保留原文件，只修改副本。";[chat textViewDidChange:input];UIButton *send=[chat valueForKey:@"send"],*stop=[chat valueForKey:@"stopButton"];
 check(send.enabled&&[send.accessibilityLabel isEqual:@"发送补充或修正"],@"running composer sends correction rather than stop");check(!stop.hidden,@"independent stop button remains visible while typing");
 [send sendActionsForControlEvents:UIControlEventTouchUpInside];check(runtime.queued==1&&runtime.stopped==0&&[[chat valueForKey:@"running"] boolValue],@"sending supplement does not cancel active run");check(input.text.length==0&&[[[chat valueForKey:@"messages"] lastObject][@"content"] containsString:@"只修改副本"],@"accepted supplement visible in conversation and draft clears");
 check(!send.enabled&&!stop.hidden,@"empty running composer keeps explicit stop and disables empty send");Backup249Screenshot(chat,@"continuity251-queued");
 NSArray *messages=[[chat valueForKey:@"messages"] copy];[chat handleEvent:@{@"type":@"done",@"state":@"paused",@"message":@"重复检查已暂停",@"messages":messages}];
 check(send.enabled&&[send.accessibilityLabel isEqual:@"继续处理"]&&stop.hidden,@"paused task offers direct continue button");[send sendActionsForControlEvents:UIControlEventTouchUpInside];
 check(runtime.sendCount==1&&![runtime.sent.lastObject[@"localRecovery"] boolValue],@"manual continuation preserves normal session tool permissions");check([runtime.sent.lastObject[@"content"] containsString:@"outcomeUnknown"],@"continuation requires checking ambiguous outcomes before replay");
 input.text=@"尚未发送的草稿";[chat textViewDidChange:input];messages=[[chat valueForKey:@"messages"] copy];[chat handleEvent:@{@"type":@"done",@"state":@"interrupted",@"message":@"后台到期",@"messages":messages,@"backgroundResumable":@YES}];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
 check(runtime.sendCount==2&&[[chat valueForKey:@"running"] boolValue],@"background interruption resumes once in foreground");check([input.text isEqual:@"尚未发送的草稿"],@"automatic continuation preserves unsent draft");
 [chat handleEvent:@{@"type":@"done",@"state":@"interrupted",@"message":@"重复网络错误",@"messages":[[chat valueForKey:@"messages"] copy],@"backgroundResumable":@YES}];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
 check(runtime.sendCount==2&&![[chat valueForKey:@"running"] boolValue],@"repeated automatic failure does not create retry loop");[chat setValue:@YES forKey:@"running"];[chat updateSend];[stop sendActionsForControlEvents:UIControlEventTouchUpInside];check(runtime.stopped==1&&![[chat valueForKey:@"autoResumePending"] boolValue],@"explicit stop cancels pending automatic continuation");
 [chat setValue:@NO forKey:@"running"];input.text=@"";[chat updateSend];Backup249Screenshot(chat,@"continuity251-resume");JSONWrite(checks,[Docs() stringByAppendingPathComponent:@"continuity251-results.json"],nil);
 });
 });
 });return nav;
}

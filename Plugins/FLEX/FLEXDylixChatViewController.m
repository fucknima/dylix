#import "FLEXDylixChatViewController.h"
#import "FLEXDylixRuntime.h"
#import "FLEXDylixAddress.h"
#import "FLEXDylixConnection.h"
#import "FLEXDylixPreferences.h"
#import "FLEXDylixMarkdown.h"
#import "FLEXDylixStatusWindow.h"
#import "FLEXManager+Private.h"
#import "FLEXUtility.h"
#import <arpa/inet.h>
#import <math.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <unistd.h>

typedef void (^DXChatReply)(NSDictionary *data, NSError *error);
static NSError *DXChatError(NSString *message) { return [NSError errorWithDomain:@"FLEX.Dylix" code:1 userInfo:@{NSLocalizedDescriptionKey:message?:@"连接失败"}]; }
static NSDictionary *DXRememberedChat;
static NSString *DXChatContent(id content) {
 if([content isKindOfClass:NSString.class])return content;
 if(![content isKindOfClass:NSArray.class])return @"";
 NSMutableArray *parts=[NSMutableArray new];
 for(id item in content)if([item isKindOfClass:NSDictionary.class]&&[item[@"text"] isKindOfClass:NSString.class])[parts addObject:item[@"text"]];
 return [parts componentsJoinedByString:@"\n"];
}

@interface FLEXDylixChatViewController () <UITextViewDelegate>
@property NSString *report, *className, *host, *token, *csrf, *projectID, *projectName, *connectionID, *modelID, *modelName, *sessionID, *sessionTitle, *jobID;
@property NSUInteger port;
@property NSString *authorizationCode;
@property BOOL needsConnectionValidation, validatingConnection, restoringWorkspace, storageWarningShown;
@property UILabel *statusLabel, *activityLabel, *contextLabel;
@property UITextView *input;
@property UIScrollView *messageScroll;
@property UIStackView *messageStack;
@property UILabel *inputPlaceholder, *liveLabel;
@property UIView *statusDot;
@property NSLayoutConstraint *inputHeight;
@property NSMutableArray<NSMutableDictionary *> *messages;
@property NSMutableDictionary *liveMessage;
@property UIButton *connectButton, *permissionButton, *projectButton, *modelButton, *sessionButton, *sendButton;
@property NSMutableDictionary<NSString *,NSString *> *drafts;
@property NSUInteger sessionLoadGeneration, missedHeartbeats;
@property (nonatomic) BOOL busy;
@property BOOL liveHasContent;
@property FLEXDylixRuntime *runtime;
@property NSTimer *agentTimer;
@property NSMutableDictionary<NSString *,NSDictionary *> *agentReplies;
@property NSString *pendingCommandID;
@property BOOL agentPolling;
@property BOOL agentReplying;
@property BOOL chatMinimized;
@property BOOL agentStopped, uiTransitioning;
@property NSUInteger agentGeneration;
@property NSMutableDictionary<NSString *,NSNumber *> *commandGenerations;
@property FLEXDylixStatusWindow *statusWindow;
@property NSString *taskPhase, *localOperation;
@property NSString *idleStatus, *captureStatus, *captureID;
@property NSMutableDictionary<NSString *,NSString *> *activeToolOperations;
@property NSUInteger connectionState, lastEventSequence;
@property NSString *reasoningEffort;
@property NSArray<NSDictionary *> *reasoningOptions;
@property NSUInteger lastCaptureSequence;
@property NSTimeInterval lastTaskUpdate;
@property BOOL waitingApproval;
@property BOOL statusSuspended;
@property NSError *lastConnectionError;
@end

@implementation FLEXDylixChatViewController
@synthesize busy=_busy;
- (void)setBusy:(BOOL)busy {
 _busy=busy;self.sendButton.enabled=YES;
 if(!busy){[self.activeToolOperations removeAllObjects];self.waitingApproval=NO;}
 [self.sendButton setTitle:busy?@"停止":@"发送" forState:UIControlStateNormal];
 [self refreshAgentStatus];
}
- (instancetype)initWithReport:(NSString *)report className:(NSString *)className {
 if ((self=[super init])) { _report=[report copy]?:@""; _className=[className copy]?:@"未知对象"; _messages=[NSMutableArray new]; _drafts=[NSMutableDictionary new];_activeToolOperations=[NSMutableDictionary new]; [self restoreConnection];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationStateChanged:) name:UIApplicationDidBecomeActiveNotification object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationStateChanged:) name:UIApplicationWillResignActiveNotification object:nil]; }
 return self;
}
- (void)restoreConnection {
 NSDictionary *state=DXRememberedChat?:[FLEXDylixPreferences loadState];
 self.host=state[@"host"];self.port=[state[@"port"] unsignedIntegerValue];self.token=state[@"token"];self.csrf=state[@"csrf"];self.authorizationCode=state[@"authorizationCode"];
 self.projectID=state[@"projectID"];self.projectName=state[@"projectName"];self.connectionID=state[@"connectionID"];self.modelID=state[@"modelID"];self.modelName=state[@"modelName"];self.sessionID=state[@"sessionID"];self.sessionTitle=state[@"sessionTitle"];
 self.needsConnectionValidation=self.host.length&&self.token.length;
 for(NSDictionary *item in state[@"messages"]){if([item isKindOfClass:NSDictionary.class]&&[item[@"role"] isKindOfClass:NSString.class]&&[item[@"text"] isKindOfClass:NSString.class])[self.messages addObject:[item mutableCopy]];}
}
- (void)rememberConnection {
 if(!self.host.length||!self.port)return;
 NSMutableDictionary *state=[@{@"host":self.host,@"port":@(self.port)} mutableCopy];
 for(NSString *key in @[@"authorizationCode",@"token",@"csrf",@"projectID",@"projectName",@"connectionID",@"modelID",@"modelName",@"sessionID",@"sessionTitle"]){id value=[self valueForKey:key];if(value)state[key]=value;}
 NSError *error=nil;if(![FLEXDylixPreferences saveState:state error:&error]&&!self.storageWarningShown){self.storageWarningShown=YES;self.activityLabel.text=error.localizedDescription;}
 // Chat text stays in memory only; Dylix remains the source of durable history.
 NSMutableArray *saved=[NSMutableArray new];for(NSDictionary *item in self.messages)[saved addObject:item.copy];state[@"messages"]=saved;
 DXRememberedChat=state.copy;
}
- (void)resumeSavedConnection {
 if(self.validatingConnection||!self.host.length||!self.token.length)return;
 self.validatingConnection=YES;[self showConnectionState:1];NSString *host=self.host,*token=self.token;NSUInteger generation=self.sessionLoadGeneration;
 [self request:@"/api/v1/status" body:@{} completion:^(NSDictionary *status,NSError *error){
  self.validatingConnection=NO;if(generation!=self.sessionLoadGeneration||![host isEqual:self.host]||![token isEqual:self.token])return;
  if(error){self.lastConnectionError=error;[self showConnectionState:3];[self setStatus:[NSString stringWithFormat:@"%@ · 配置已保留，连接设置可查看诊断",[[error.localizedDescription componentsSeparatedByString:@"\n"] firstObject]]];return;}
  NSString *csrf=status[@"session"][@"csrf"];if(![csrf isKindOfClass:NSString.class]||!csrf.length){[self showConnectionState:3];[self setStatus:@"保存的授权已失效，地址和选择已保留，请重新配对"];return;}
  self.csrf=csrf;self.needsConnectionValidation=NO;self.missedHeartbeats=0;[self showConnectionState:2];[self rememberConnection];[self startAgentPolling];[self restoreSavedWorkspace];
 }];
}
- (void)restoreSavedWorkspace {
 NSString *project=self.projectID,*session=self.sessionID;NSUInteger generation=self.sessionLoadGeneration;
 if(!project.length){[self setStatus:@"已恢复连接，请选择项目"];return;}
 self.restoringWorkspace=YES;
 [self workspace:@"projects" arguments:@{} completion:^(NSDictionary *data,NSError *error){
  if(generation!=self.sessionLoadGeneration||![project isEqual:self.projectID])return;if(error){self.restoringWorkspace=NO;[self showError:error];return;}
  NSDictionary *found=nil;for(NSDictionary *item in data[@"projects"])if([item[@"id"] isEqual:project]){found=item;break;}
  if(!found){self.restoringWorkspace=NO;self.projectID=nil;self.projectName=nil;self.sessionID=nil;self.sessionTitle=nil;[self.messages removeAllObjects];[self renderMessages];[self.projectButton setTitle:@"选择项目" forState:UIControlStateNormal];[self updateSessionButton];[self setStatus:@"上次项目已不存在，请重新选择"];return;}
  self.projectName=found[@"name"]?:self.projectName;[self.projectButton setTitle:self.projectName?:@"选择项目" forState:UIControlStateNormal];
  [self workspace:@"ai_connections" arguments:@{} completion:^(NSDictionary *connections,NSError *failure){
   if(generation!=self.sessionLoadGeneration||![project isEqual:self.projectID])return;if(failure){self.restoringWorkspace=NO;[self showError:failure];return;}
   BOOL exists=NO;for(NSDictionary *item in connections[@"connections"])if([item[@"id"] isEqual:self.connectionID]&&[item[@"model"] isEqual:self.modelID]){exists=YES;break;}
   if(!exists){self.connectionID=nil;self.modelID=nil;self.modelName=nil;}[self.modelButton setTitle:self.modelID?:@"选择模型" forState:UIControlStateNormal];
   if(!session.length){self.restoringWorkspace=NO;[self setStatus:exists?@"已恢复上次项目和模型":@"已恢复项目，请重新选择模型"];return;}
   [self workspace:@"ai_read" arguments:@{@"sessionID":session} completion:^(NSDictionary *record,NSError *readError){
    if(generation!=self.sessionLoadGeneration||![project isEqual:self.projectID]||![session isEqual:self.sessionID])return;
    self.restoringWorkspace=NO;
    if(readError){if(readError.code==404){self.sessionID=nil;self.sessionTitle=nil;[self.messages removeAllObjects];[self renderMessages];[self updateSessionButton];}[self setStatus:@"上次会话暂时无法读取，请在会话列表中检查；项目和模型未切换"];return;}
    if([record[@"title"] isKindOfClass:NSString.class])self.sessionTitle=record[@"title"];
    [self.messages removeAllObjects];for(NSDictionary *item in record[@"messages"]){NSString *role=item[@"role"],*text=DXChatContent(item[@"content"]);if([@[@"user",@"assistant"] containsObject:role]&&text.length)[self.messages addObject:[@{@"role":role,@"text":text} mutableCopy]];}
    [self renderMessages];[self updateSessionButton];[self setStatus:exists?@"已恢复上次项目、模型和会话":@"已恢复上次会话，请重新选择模型"];
   }];
  }];
 }];
}
- (void)updateReport:(NSString *)report className:(NSString *)className selectedObject:(id)object {
 self.report=[report copy]?:@"";self.className=[className copy]?:@"未知对象";self.selectedObject=object;
 self.runtime.selectedObject=object;
 self.contextLabel.text=[@"FLEX 现场  ·  " stringByAppendingString:self.className];
}
- (UIButton *)button:(NSString *)title action:(SEL)action {
 UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; [button setTitle:title forState:UIControlStateNormal];
 button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
 button.contentEdgeInsets=UIEdgeInsetsMake(8,10,8,10); button.layer.cornerRadius=8;
 if (@available(iOS 13.0, *)) button.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
 else button.backgroundColor=UIColor.whiteColor;
 [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside]; return button;
}
- (void)viewDidLoad {
 [super viewDidLoad]; self.title=@"Dylix AI"; self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
 self.runtime=[FLEXDylixRuntime new];self.runtime.selectedObject=self.selectedObject;self.agentReplies=[NSMutableDictionary new];self.commandGenerations=[NSMutableDictionary new];
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"新会话" style:UIBarButtonItemStylePlain target:self action:@selector(newSession)];
 if (self.navigationController.viewControllers.firstObject == self) {
  self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithImage:[UIImage systemImageNamed:@"minus"] style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
  self.navigationItem.leftBarButtonItem.accessibilityLabel=@"收起会话，AI 继续运行";
 }
 UIBarButtonItem *disconnect=[[UIBarButtonItem alloc]initWithTitle:@"断开" style:UIBarButtonItemStylePlain target:self action:@selector(disconnectTapped)];
 self.navigationItem.rightBarButtonItems=@[self.navigationItem.rightBarButtonItem,disconnect];
 self.connectButton=[self button:self.csrf.length?@"连接设置":@"连接 Dylix" action:@selector(connectTapped)];
 self.permissionButton=[self button:@"工具权限" action:@selector(permissionTapped)];
 if (@available(iOS 13.0, *)) {
  [self.connectButton setTitle:nil forState:UIControlStateNormal];[self.connectButton setImage:[UIImage systemImageNamed:@"gearshape"] forState:UIControlStateNormal];
  [self.permissionButton setTitle:nil forState:UIControlStateNormal];[self.permissionButton setImage:[UIImage systemImageNamed:@"lock.shield"] forState:UIControlStateNormal];
 } else {[self.connectButton setTitle:@"连" forState:UIControlStateNormal];[self.permissionButton setTitle:@"权" forState:UIControlStateNormal];}
 self.connectButton.accessibilityLabel=@"连接设置";self.permissionButton.accessibilityLabel=@"工具权限";
 self.projectButton=[self button:@"选择项目" action:@selector(projectTapped)];
 self.modelButton=[self button:@"选择模型" action:@selector(modelTapped)];
 self.sessionButton=[self button:@"会话 · 新会话  ▾" action:@selector(sessionTapped)];
 self.sessionButton.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
 self.sessionButton.titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;
 UIColor *secondary=UIColor.grayColor, *surface=UIColor.whiteColor, *accent=UIColor.systemBlueColor;
 if (@available(iOS 13.0, *)) { secondary=UIColor.secondaryLabelColor; surface=UIColor.secondarySystemGroupedBackgroundColor; }
 self.statusLabel=[UILabel new];self.statusLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];self.statusLabel.textColor=secondary;self.statusLabel.text=self.csrf.length?@"正在检查连接":@"未连接";self.statusLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;
 self.statusDot=[UIView new];self.statusDot.backgroundColor=UIColor.systemGrayColor;self.statusDot.layer.cornerRadius=4;
 UIStackView *statusRow=[[UIStackView alloc]initWithArrangedSubviews:@[self.statusDot,self.statusLabel,self.permissionButton,self.connectButton]];statusRow.axis=UILayoutConstraintAxisHorizontal;statusRow.spacing=6;statusRow.alignment=UIStackViewAlignmentCenter;
 [self.statusLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
 [self.connectButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
 self.contextLabel=[UILabel new];self.contextLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];self.contextLabel.textColor=secondary;self.contextLabel.text=[@"FLEX 现场  ·  " stringByAppendingString:self.className];self.contextLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;
 self.activityLabel=[UILabel new];self.activityLabel.font=[UIFont systemFontOfSize:12];self.activityLabel.textColor=secondary;self.activityLabel.text=@"就绪";self.activityLabel.lineBreakMode=NSLineBreakByTruncatingTail;
 self.activityLabel.textAlignment=NSTextAlignmentRight;self.activityLabel.numberOfLines=2;self.activityLabel.accessibilityIdentifier=@"dylix.agent.activity";
 UIStackView *selectors=[[UIStackView alloc]initWithArrangedSubviews:@[self.projectButton,self.modelButton,self.sessionButton]];selectors.axis=UILayoutConstraintAxisHorizontal;selectors.spacing=6;selectors.distribution=UIStackViewDistributionFillEqually;
 for(UIButton *button in @[self.projectButton,self.modelButton,self.sessionButton]){button.titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;button.contentEdgeInsets=UIEdgeInsetsMake(6,7,6,7);}
 self.sessionButton.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;
 UIStackView *metaRow=[[UIStackView alloc]initWithArrangedSubviews:@[self.contextLabel,self.activityLabel]];metaRow.axis=UILayoutConstraintAxisHorizontal;metaRow.spacing=8;metaRow.distribution=UIStackViewDistributionFillEqually;
 if(self.projectID.length)[self.projectButton setTitle:self.projectName?:@"选择项目" forState:UIControlStateNormal];if(self.modelID.length)[self.modelButton setTitle:self.modelID forState:UIControlStateNormal];
 UIView *header=[UIView new];header.backgroundColor=surface;header.layer.cornerRadius=12;
 for(UIView *view in @[statusRow,selectors,metaRow]){view.translatesAutoresizingMaskIntoConstraints=NO;[header addSubview:view];}
 self.messageScroll=[UIScrollView new];self.messageScroll.alwaysBounceVertical=YES;self.messageScroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive;
 self.messageStack=[UIStackView new];self.messageStack.axis=UILayoutConstraintAxisVertical;self.messageStack.spacing=14;self.messageStack.alignment=UIStackViewAlignmentFill;
 self.messageStack.translatesAutoresizingMaskIntoConstraints=NO;[self.messageScroll addSubview:self.messageStack];
 self.input=[UITextView new];self.input.font=[UIFont systemFontOfSize:15];self.input.backgroundColor=surface;self.input.layer.cornerRadius=12;self.input.textContainerInset=UIEdgeInsetsMake(10,10,10,10);self.input.delegate=self;self.input.scrollEnabled=YES;
 self.input.layer.borderWidth=1;self.input.layer.borderColor=UIColor.systemGray4Color.CGColor;
 self.inputPlaceholder=[UILabel new];self.inputPlaceholder.text=@"描述问题，询问当前 FLEX 现场…";self.inputPlaceholder.font=self.input.font;self.inputPlaceholder.textColor=secondary;self.inputPlaceholder.translatesAutoresizingMaskIntoConstraints=NO;[self.input addSubview:self.inputPlaceholder];
 self.sendButton=[self button:@"发送" action:@selector(sendTapped)];[self.sendButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];self.sendButton.backgroundColor=accent;
 UIStackView *composer=[[UIStackView alloc]initWithArrangedSubviews:@[self.input,self.sendButton]];composer.axis=UILayoutConstraintAxisHorizontal;composer.spacing=8;composer.alignment=UIStackViewAlignmentBottom;
 for(UIView *view in @[header,self.messageScroll,composer]){view.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:view];}
 UILayoutGuide *bottom=self.view.safeAreaLayoutGuide;
 if (@available(iOS 15.0, *)) bottom=self.view.keyboardLayoutGuide;
 [NSLayoutConstraint activateConstraints:@[
  [header.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],[header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],[header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
  [statusRow.topAnchor constraintEqualToAnchor:header.topAnchor constant:6],[statusRow.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:10],[statusRow.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-10],
  [self.statusDot.widthAnchor constraintEqualToConstant:8],[self.statusDot.heightAnchor constraintEqualToConstant:8],
  [self.connectButton.widthAnchor constraintEqualToConstant:34],[self.connectButton.heightAnchor constraintEqualToConstant:32],
  [self.permissionButton.widthAnchor constraintEqualToConstant:34],[self.permissionButton.heightAnchor constraintEqualToConstant:32],
  [selectors.topAnchor constraintEqualToAnchor:statusRow.bottomAnchor constant:5],[selectors.leadingAnchor constraintEqualToAnchor:statusRow.leadingAnchor],[selectors.trailingAnchor constraintEqualToAnchor:statusRow.trailingAnchor],[selectors.heightAnchor constraintEqualToConstant:34],
  [metaRow.topAnchor constraintEqualToAnchor:selectors.bottomAnchor constant:5],[metaRow.leadingAnchor constraintEqualToAnchor:statusRow.leadingAnchor],[metaRow.trailingAnchor constraintEqualToAnchor:statusRow.trailingAnchor],[metaRow.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-7],
  [self.messageScroll.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8],[self.messageScroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.messageScroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
  [self.messageStack.topAnchor constraintEqualToAnchor:self.messageScroll.contentLayoutGuide.topAnchor constant:14],[self.messageStack.bottomAnchor constraintEqualToAnchor:self.messageScroll.contentLayoutGuide.bottomAnchor constant:-14],[self.messageStack.leadingAnchor constraintEqualToAnchor:self.messageScroll.contentLayoutGuide.leadingAnchor constant:12],[self.messageStack.trailingAnchor constraintEqualToAnchor:self.messageScroll.contentLayoutGuide.trailingAnchor constant:-12],[self.messageStack.widthAnchor constraintEqualToAnchor:self.messageScroll.frameLayoutGuide.widthAnchor constant:-24],
  [composer.topAnchor constraintEqualToAnchor:self.messageScroll.bottomAnchor constant:8],[composer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],[composer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],[composer.bottomAnchor constraintEqualToAnchor:bottom.topAnchor constant:-8],
  [self.inputPlaceholder.leadingAnchor constraintEqualToAnchor:self.input.leadingAnchor constant:15],[self.inputPlaceholder.topAnchor constraintEqualToAnchor:self.input.topAnchor constant:12],
  [self.sendButton.widthAnchor constraintEqualToConstant:58],[self.sendButton.heightAnchor constraintEqualToConstant:44]
 ]];
 self.inputHeight=[self.input.heightAnchor constraintEqualToConstant:76];self.inputHeight.active=YES;
 if(!self.messages.count)[self.messages addObject:[@{@"role":@"tip",@"text":@"选中 FLEX 对象后直接提问。AI 可读取现场报告，并按权限调用实时工具。"} mutableCopy]];
 [self updateSessionButton];[self showConnectionState:self.csrf.length?1:0];
 [self renderMessages];
}
- (void)setStatus:(NSString *)text {self.idleStatus=text;[self rememberConnection];[self refreshAgentStatus];}
- (void)showConnectionState:(NSUInteger)state {
 self.connectionState=state;
 NSString *address=self.host.length?[NSString stringWithFormat:@"%@:%lu",self.host,(unsigned long)self.port]:@"Dylix";
 self.statusLabel.text=state==2?[NSString stringWithFormat:@"已连接 · %@",address]:state==1?@"正在检查连接…":state==3?@"连接中断 · 点击重连":@"未连接 Dylix";
 self.statusDot.backgroundColor=state==2?UIColor.systemGreenColor:state==1?UIColor.systemOrangeColor:state==3?UIColor.systemRedColor:UIColor.systemGrayColor;
 self.connectButton.accessibilityLabel=state==0?@"连接 Dylix":@"连接设置";
 if (@available(iOS 13.0, *)) {} else [self.connectButton setTitle:@"连" forState:UIControlStateNormal];
 [self refreshAgentStatus];
}
- (void)updateSessionButton {NSString *name=self.sessionTitle.length?self.sessionTitle:@"新会话";[self.sessionButton setTitle:[NSString stringWithFormat:@"会话 · %@  ▾",name] forState:UIControlStateNormal];}
- (void)showConnectionDiagnostic {
 NSString *report=self.lastConnectionError.userInfo[FLEXDylixConnectionDiagnosticKey];if(!report.length)return;
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"连接诊断" message:report preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:@"复制诊断" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){UIPasteboard.generalPasteboard.string=report;[self setStatus:@"已复制连接诊断"]; }]];
 [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
 [self presentViewController:alert animated:YES completion:nil];
}
- (void)showError:(NSError *)error {
 if(!error)return;
 if(error.userInfo[FLEXDylixConnectionDiagnosticKey])self.lastConnectionError=error;
 [self setStatus:[[error.localizedDescription componentsSeparatedByString:@"\n"] firstObject]];
 if(!self.view.window){[self append:[@"错误：" stringByAppendingString:error.localizedDescription?:@"请求失败"]];return;}
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Dylix 连接" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
 NSString *report=error.userInfo[FLEXDylixConnectionDiagnosticKey];
 if(report.length)[alert addAction:[UIAlertAction actionWithTitle:@"复制诊断" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){UIPasteboard.generalPasteboard.string=report;[self setStatus:@"已复制连接诊断"]; }]];
 [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
 [self presentViewController:alert animated:YES completion:nil];
}
- (void)scrollMessagesToBottom { [self.messageScroll layoutIfNeeded];CGFloat offset=MAX(0,self.messageScroll.contentSize.height-self.messageScroll.bounds.size.height);[self.messageScroll setContentOffset:CGPointMake(0,offset) animated:NO]; }
- (void)renderMessages {
 for(UIView *view in self.messageStack.arrangedSubviews){[self.messageStack removeArrangedSubview:view];[view removeFromSuperview];}
 self.liveLabel=nil;
 for(NSUInteger index=0;index<self.messages.count;index++){
  NSDictionary *message=self.messages[index];NSString *role=message[@"role"],*value=message[@"text"]?:@"";BOOL mine=[role isEqualToString:@"user"],tip=[role isEqualToString:@"tip"];
  UIView *row=[UIView new];row.translatesAutoresizingMaskIntoConstraints=NO;
  if(tip){
   UILabel *label=[UILabel new];label.text=value;label.numberOfLines=0;label.textAlignment=NSTextAlignmentCenter;label.font=[UIFont systemFontOfSize:13];label.textColor=UIColor.secondaryLabelColor;label.translatesAutoresizingMaskIntoConstraints=NO;[row addSubview:label];
   [NSLayoutConstraint activateConstraints:@[[label.topAnchor constraintEqualToAnchor:row.topAnchor],[label.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],[label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:15],[label.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-15]]];
  } else {
   UIView *bubble=[UIView new];bubble.backgroundColor=mine?UIColor.systemBlueColor:UIColor.secondarySystemGroupedBackgroundColor;bubble.layer.cornerRadius=14;bubble.translatesAutoresizingMaskIntoConstraints=NO;[row addSubview:bubble];
   UILabel *author=[UILabel new];author.text=mine?@"我":@"DYLIX AI";author.font=[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];author.textColor=UIColor.secondaryLabelColor;author.translatesAutoresizingMaskIntoConstraints=NO;[row addSubview:author];
   UIButton *copy=[UIButton buttonWithType:UIButtonTypeSystem];[copy setTitle:@"复制" forState:UIControlStateNormal];copy.titleLabel.font=[UIFont systemFontOfSize:11];copy.tag=index;copy.translatesAutoresizingMaskIntoConstraints=NO;[copy addTarget:self action:@selector(copyMessage:) forControlEvents:UIControlEventTouchUpInside];[row addSubview:copy];
   UILabel *label=[UILabel new];label.text=value.length?value:@"正在回复…";label.numberOfLines=0;label.lineBreakMode=NSLineBreakByWordWrapping;label.font=[UIFont systemFontOfSize:15];label.textColor=mine?UIColor.whiteColor:UIColor.labelColor;label.translatesAutoresizingMaskIntoConstraints=NO;[bubble addSubview:label];
   if(!mine)label.attributedText=FLEXDylixRenderMarkdown(value,label.textColor);
   [NSLayoutConstraint activateConstraints:@[[author.topAnchor constraintEqualToAnchor:row.topAnchor],[author.leadingAnchor constraintEqualToAnchor:bubble.leadingAnchor constant:2],[copy.centerYAnchor constraintEqualToAnchor:author.centerYAnchor],[copy.trailingAnchor constraintEqualToAnchor:bubble.trailingAnchor constant:-2],[author.trailingAnchor constraintLessThanOrEqualToAnchor:copy.leadingAnchor constant:-8],
    [bubble.topAnchor constraintEqualToAnchor:author.bottomAnchor constant:5],[bubble.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],[bubble.widthAnchor constraintLessThanOrEqualToAnchor:row.widthAnchor multiplier:0.88],[bubble.leadingAnchor constraintGreaterThanOrEqualToAnchor:row.leadingAnchor],[bubble.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor],mine?[bubble.trailingAnchor constraintEqualToAnchor:row.trailingAnchor]:[bubble.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
    [label.topAnchor constraintEqualToAnchor:bubble.topAnchor constant:11],[label.bottomAnchor constraintEqualToAnchor:bubble.bottomAnchor constant:-11],[label.leadingAnchor constraintEqualToAnchor:bubble.leadingAnchor constant:12],[label.trailingAnchor constraintEqualToAnchor:bubble.trailingAnchor constant:-12]]];
   if(message==self.liveMessage)self.liveLabel=label;
  }
  [self.messageStack addArrangedSubview:row];
 }
 dispatch_async(dispatch_get_main_queue(),^{[self scrollMessagesToBottom];});
 [self rememberConnection];
}
- (NSMutableDictionary *)addMessage:(NSString *)text role:(NSString *)role {NSMutableDictionary *item=[@{@"role":role?:@"tip",@"text":text?:@""} mutableCopy];[self.messages addObject:item];if([role isEqualToString:@"assistant"])self.liveMessage=item;[self renderMessages];return item;}
- (void)copyMessage:(UIButton *)button {if(button.tag>=self.messages.count)return;UIPasteboard.generalPasteboard.string=self.messages[button.tag][@"text"]?:@"";[button setTitle:@"已复制" forState:UIControlStateNormal];}
- (void)append:(NSString *)line { [self addMessage:line role:@"tip"]; }
- (NSString *)draftKey {return [NSString stringWithFormat:@"%@/%@",self.projectID?:@"",self.sessionID?:@"new"];}
- (void)saveDraft {self.drafts[self.draftKey]=self.input.text?:@"";}
- (void)restoreDraft {self.input.text=self.drafts[self.draftKey]?:@"";[self textViewDidChange:self.input];}
- (void)newSession {if(self.restoringWorkspace){[self setStatus:@"正在恢复上次项目和会话，请稍候"];return;}if(self.busy)return;[self saveDraft];self.sessionLoadGeneration++;self.sessionID=nil;self.sessionTitle=nil;self.jobID=nil;self.captureStatus=nil;self.captureID=nil;self.lastCaptureSequence=0;self.liveMessage=nil;[self.messages removeAllObjects];[self addMessage:@"新会话已建立。当前 FLEX 对象会在发送时重新同步。" role:@"tip"];[self restoreDraft];[self updateSessionButton];[self setStatus:@"新会话就绪"];
}
- (void)loadSessionID:(NSString *)identifier title:(NSString *)title {
 if(self.busy)return;
 NSString *project=self.projectID;NSUInteger generation=++self.sessionLoadGeneration;[self setStatus:@"正在读取会话…"];
 [self workspace:@"ai_read" arguments:@{@"sessionID":identifier} completion:^(NSDictionary *record,NSError *error){
  if(generation!=self.sessionLoadGeneration||![project isEqualToString:self.projectID])return;
  if(error){[self showError:error];return;}
  if(![record[@"id"] isEqualToString:identifier]){[self showError:DXChatError(@"会话读取结果不匹配")];return;}
  [self saveDraft];self.captureStatus=nil;self.captureID=nil;self.lastCaptureSequence=0;self.sessionID=identifier;self.sessionTitle=title.length?title:record[@"title"];self.liveMessage=nil;self.liveHasContent=NO;[self.messages removeAllObjects];
  for(id raw in record[@"messages"]){if(![raw isKindOfClass:NSDictionary.class])continue;NSString *role=raw[@"role"];if(![@[@"user",@"assistant"] containsObject:role])continue;NSString *text=DXChatContent(raw[@"content"]);if(!text.length)continue;
   if([role isEqualToString:@"user"]){NSRange old=[text rangeOfString:@"\n\n我的问题：" options:NSBackwardsSearch];if(old.location!=NSNotFound&&[text hasPrefix:@"当前 FLEX 现场："])text=[text substringFromIndex:NSMaxRange(old)];NSRange next=[text rangeOfString:@"\n\n当前 FLEX 现场："];if(next.location!=NSNotFound)text=[text substringToIndex:next.location];}
   [self.messages addObject:[@{@"role":role,@"text":text} mutableCopy]];
  }
  if(!self.messages.count)[self.messages addObject:[@{@"role":@"tip",@"text":@"这个会话还没有可显示的文字消息。"} mutableCopy]];
  [self renderMessages];[self restoreDraft];[self updateSessionButton];
  BOOL running=[@[@"streaming",@"running",@"waitingApproval"] containsObject:record[@"state"]];
  [self setStatus:running?@"会话正在 Dylix 运行，点会话可刷新":[NSString stringWithFormat:@"已打开会话 · %lu 条消息",(unsigned long)self.messages.count]];
  NSString *savedConnection=record[@"connectionID"],*savedModel=record[@"modelID"];
  self.reasoningEffort=nil;self.reasoningOptions=nil;
  self.connectionID=nil;self.modelID=nil;self.modelName=nil;[self.modelButton setTitle:@"选择模型" forState:UIControlStateNormal];
  if(![savedConnection isKindOfClass:NSString.class]||!savedConnection.length){[self setStatus:@"会话已打开，请选择模型后继续"];return;}
  [self workspace:@"ai_connections" arguments:@{} completion:^(NSDictionary *data,NSError *lookupError){
   if(generation!=self.sessionLoadGeneration||![project isEqualToString:self.projectID]||![identifier isEqualToString:self.sessionID])return;
   if(lookupError){[self setStatus:@"会话已打开；模型列表暂不可用"] ;return;}
   for(NSDictionary *candidate in data[@"connections"])if([candidate[@"id"] isEqual:savedConnection]&&(![savedModel isKindOfClass:NSString.class]||[candidate[@"model"] isEqual:savedModel])){self.connectionID=savedConnection;self.modelID=candidate[@"model"];self.reasoningOptions=candidate[@"efforts"];self.modelName=[NSString stringWithFormat:@"%@ · %@",candidate[@"provider"]?:@"",candidate[@"model"]?:@""];[self.modelButton setTitle:candidate[@"model"]?:@"模型" forState:UIControlStateNormal];[self rememberConnection];return;}
   self.connectionID=nil;self.modelID=nil;self.modelName=nil;[self.modelButton setTitle:@"选择模型" forState:UIControlStateNormal];[self setStatus:@"原会话模型已移除，请重新选择模型"];
  }];
 }];
}
- (void)sessionTapped {if(self.restoringWorkspace){[self setStatus:@"正在恢复上次项目和会话，请稍候"];return;}
 if(!self.csrf.length){[self connectTapped];return;}if(!self.projectID.length){[self projectTapped];return;}if(self.busy){[self setStatus:@"AI 正在回复，结束后可切换会话"];return;}
 NSString *project=self.projectID;[self setStatus:@"正在加载会话列表…"];
 [self workspace:@"ai_sessions" arguments:@{} completion:^(NSDictionary *data,NSError *error){
  if(![project isEqualToString:self.projectID])return;if(error){[self showError:error];return;}
  UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"选择会话" message:self.projectName preferredStyle:UIAlertControllerStyleActionSheet];
  [menu addAction:[UIAlertAction actionWithTitle:@"＋ 新会话" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self newSession];}]];
  NSArray *sessions=[data[@"sessions"] isKindOfClass:NSArray.class]?data[@"sessions"]:@[];NSDateFormatter *date=[NSDateFormatter new];date.dateFormat=@"M/d HH:mm";
  for(id raw in sessions){if(![raw isKindOfClass:NSDictionary.class])continue;NSString *sid=raw[@"id"];if(![sid isKindOfClass:NSString.class]||!sid.length)continue;NSString *title=[raw[@"title"] isKindOfClass:NSString.class]?raw[@"title"]:@"会话";NSString *summary=[raw[@"summary"] isKindOfClass:NSString.class]?raw[@"summary"]:@"";
   if([title hasPrefix:@"当前 FLEX 现场："]&&summary.length)title=summary;
   if(title.length>30)title=[[title substringToIndex:30] stringByAppendingString:@"…"];
   NSString *updated=[raw[@"updatedAt"] isKindOfClass:NSNumber.class]?[date stringFromDate:[NSDate dateWithTimeIntervalSince1970:[raw[@"updatedAt"] doubleValue]]]:@"";
   NSString *label=[NSString stringWithFormat:@"%@%@%@",[sid isEqualToString:self.sessionID]?@"✓  ":@"",title,updated.length?[ @" · " stringByAppendingString:updated]:@""];
   [menu addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self loadSessionID:sid title:title];}]];
  }
  if(!sessions.count)menu.message=@"当前项目暂无历史会话";
  [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  menu.popoverPresentationController.sourceView=self.sessionButton;menu.popoverPresentationController.sourceRect=self.sessionButton.bounds;[self presentViewController:menu animated:YES completion:nil];[self setStatus:@"选择现有会话或新建会话"];
 }];
}
- (void)textViewDidChange:(UITextView *)textView {self.inputPlaceholder.hidden=textView.text.length>0;CGFloat height=MIN(150,MAX(76,[textView sizeThatFits:CGSizeMake(textView.bounds.size.width,CGFLOAT_MAX)].height));self.inputHeight.constant=height;}
- (void)applicationStateChanged:(NSNotification *)note {self.statusSuspended=[note.name isEqual:UIApplicationWillResignActiveNotification];[self refreshAgentStatus];}
- (NSString *)phaseForOperation:(NSString *)operation {
 NSDictionary *names=@{@"gesture":@"正在操作页面",@"activate_control":@"正在点击控件",@"scroll_view":@"正在滚动页面",@"set_view":@"正在调整视图",@"undo":@"正在恢复视图",@"input_text":@"正在输入文字",@"set_control_value":@"正在调整控件",@"capture_screen":@"正在截图观察",@"screen_elements":@"正在读取控件",@"view_tree":@"正在读取视图树",@"object_info":@"正在核对对象",@"class_info":@"正在核对类信息",@"class_header":@"正在读取头文件",@"minimize_chat":@"正在收起会话",@"restore_chat":@"正在恢复会话",@"open_tool":@"正在打开 FLEX 工具",@"select_row":@"正在操作 FLEX 页面",@"flex_scroll":@"正在滚动 FLEX 页面",@"set_search":@"正在搜索 FLEX 页面",@"navigate_back":@"正在返回 FLEX 页面",@"dismiss_tool":@"正在关闭 FLEX 页面",@"build_project":@"正在本机构建",@"read_file":@"正在读取项目文件",@"list_artifacts":@"正在检查构建产物",@"list_session_files":@"正在读取会话文件"};
 return names[operation]?:[NSString stringWithFormat:@"正在执行工具 · %@",operation?:@"未知工具"];
}
- (BOOL)isScreenControl:(NSString *)operation {
 return [@[@"gesture",@"activate_control",@"scroll_view",@"set_view",@"undo",@"input_text",@"set_control_value",@"open_tool",@"navigate_back",@"dismiss_tool",@"select_row",@"flex_scroll",@"set_search"] containsObject:operation];
}
- (void)refreshAgentStatus {
 BOOL show=self.chatMinimized&&self.csrf.length&&!self.statusSuspended&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
 if(show&&!self.statusWindow){
  if(@available(iOS 13.0,*)){UIWindowScene *scene=FLEXUtility.appKeyWindow.windowScene;if(scene)self.statusWindow=[[FLEXDylixStatusWindow alloc]initWithWindowScene:scene];}
  if(!self.statusWindow)self.statusWindow=[[FLEXDylixStatusWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
  __weak typeof(self) weak=self;self.statusWindow.openChat=^{typeof(self) chat=weak;if(!chat||chat.uiTransitioning)return;chat.uiTransitioning=YES;[chat restoreChatWithCompletion:^{chat.uiTransitioning=NO;}];};
 }
 BOOL control=[self isScreenControl:self.localOperation];for(NSString *op in self.activeToolOperations.allValues)if([self isScreenControl:op])control=YES;
 BOOL running=self.busy||self.localOperation.length||self.activeToolOperations.count;
 NSString *title=@"Dylix AI · 已连接",*detail=@"轻点返回会话";UIColor *color=UIColor.systemGreenColor;
 if(self.connectionState!=2){title=self.connectionState==3?@"Dylix AI · 连接中断":@"Dylix AI · 检查连接";detail=self.connectionState==3?@"轻点检查连接与任务":@"等待 Dylix 心跳确认";color=self.connectionState==3?UIColor.systemRedColor:UIColor.systemOrangeColor;}
 else if(self.agentStopped){title=@"Dylix AI · 已停止";detail=self.idleStatus?:@"轻点返回会话";color=UIColor.systemGrayColor;}
 else if(self.waitingApproval){title=@"AI 等待你的确认";detail=@"请查看当前确认弹窗";color=UIColor.systemOrangeColor;}
 else if(running){title=control?@"AI 操作中 · 请勿触屏":@"Dylix AI · 处理中";color=control?UIColor.systemOrangeColor:UIColor.systemBlueColor;
  NSString *phase=self.localOperation.length?[self phaseForOperation:self.localOperation]:(self.taskPhase?:@"等待模型响应");
  NSTimeInterval elapsed=self.lastTaskUpdate>0?MAX(0,NSProcessInfo.processInfo.systemUptime-self.lastTaskUpdate):0;
   detail=elapsed>=15?[NSString stringWithFormat:@"%@ · 等待更新 %.0f 秒",phase,elapsed]:phase;
  if([phase isEqual:@"正在回复"]&&!control)title=@"Dylix AI · 正在回复";
 }else if([self.idleStatus isEqual:@"请求未完成"]){title=@"Dylix AI · 任务未完成";detail=@"请求未完成 · 查看错误详情";color=UIColor.systemOrangeColor;}
 else if([self.idleStatus isEqual:@"回复完成"]){title=@"Dylix AI · 回复完成";detail=@"回复完成";}
 else detail=self.idleStatus?:@"就绪";
 if(control)detail=[@"请勿触屏 · " stringByAppendingString:detail];
 if(self.captureStatus.length)detail=[detail stringByAppendingFormat:@"\n%@",self.captureStatus];
 self.activityLabel.text=detail;self.activityLabel.textColor=color;self.activityLabel.accessibilityLabel=detail;
 if(!show){self.statusWindow.hidden=YES;return;}
 [self.statusWindow updateTitle:title detail:detail color:color busy:running&&self.connectionState==2&&!self.agentStopped&&!self.waitingApproval];self.statusWindow.hidden=NO;
}
- (void)updateCaptureStatus:(NSDictionary *)event {
 if(![event isKindOfClass:NSDictionary.class])return;
 NSUInteger sequence=[event[@"sequence"] unsignedIntegerValue];NSString *capture=event[@"captureID"],*stage=event[@"stage"];
 NSDictionary *labels=@{@"captured":@"截图已获取 · 待发送",@"sending":@"截图正在发送",@"sent":@"截图已随请求发送",@"failed":@"截图请求失败",@"cancelled":@"截图请求已取消"};
 if(sequence<=self.lastCaptureSequence||![capture isKindOfClass:NSString.class]||!capture.length||![stage isKindOfClass:NSString.class]||!labels[stage])return;
 self.lastCaptureSequence=sequence;self.captureID=capture;self.captureStatus=labels[stage];
}
- (void)updateTaskFromJob:(NSDictionary *)job {
 for(id raw in job[@"events"]){
  if(![raw isKindOfClass:NSDictionary.class])continue;NSDictionary *event=raw;NSUInteger sequence=[event[@"sequence"] unsignedIntegerValue];if(sequence<=self.lastEventSequence)continue;self.lastEventSequence=sequence;
  NSString *type=event[@"type"],*identifier=event[@"id"];
  if([type isEqual:@"waiting_approval"]){self.waitingApproval=YES;self.taskPhase=@"等待操作确认";}
  else if([type isEqual:@"tool_started"]){self.waitingApproval=NO;NSString *op=[event[@"arguments"] isKindOfClass:NSDictionary.class]?event[@"arguments"][@"operation"]:nil;op=op?:event[@"name"];if(identifier&&op)self.activeToolOperations[identifier]=op;self.taskPhase=[self phaseForOperation:op];}
  else if([type isEqual:@"tool_result"]){if(identifier)[self.activeToolOperations removeObjectForKey:identifier];self.waitingApproval=NO;self.taskPhase=self.activeToolOperations.count?[self phaseForOperation:self.activeToolOperations.allValues.firstObject]:@"工具已返回 · 等待模型";}
  else if([type isEqual:@"assistant_start"]){[self.activeToolOperations removeAllObjects];self.waitingApproval=NO;self.taskPhase=@"等待模型响应";}
  else if([type isEqual:@"reasoning"]||[type isEqual:@"analysis_summary"]){self.taskPhase=@"正在接收思考";}
  else if([type isEqual:@"text"]){self.taskPhase=@"正在回复";}
  else if([type isEqual:@"status"]){if(!self.activeToolOperations.count&&!self.localOperation.length&&[event[@"message"] isKindOfClass:NSString.class])self.taskPhase=[event[@"message"] substringToIndex:MIN((NSUInteger)120,[event[@"message"] length])];}
  else if([type isEqual:@"flex_capture_status"]){[self updateCaptureStatus:event];}
  else if([type isEqual:@"tool_progress"]){NSString *message=event[@"message"];if([message isKindOfClass:NSString.class]&&message.length)self.taskPhase=[message substringToIndex:MIN((NSUInteger)120,message.length)];}
  else if([type isEqual:@"done"]){[self.activeToolOperations removeAllObjects];self.waitingApproval=NO;}
  else if(![type isEqual:@"tool_progress"])continue;
  self.lastTaskUpdate=NSProcessInfo.processInfo.systemUptime;
 }
 [self updateCaptureStatus:job[@"flexCaptureStatus"]];[self refreshAgentStatus];
}
- (NSDictionary *)chatWindowStatus {
 BOOL visible=self.viewIfLoaded.window!=nil&&!self.viewIfLoaded.window.hidden&&!self.navigationController.isBeingDismissed;
 return @{@"chatVisible":@(visible),@"minimized":@(self.chatMinimized),@"connected":@(self.connectionState==2&&!self.needsConnectionValidation&&self.missedHeartbeats<2),@"taskRunning":@(self.busy),@"stopped":@(self.agentStopped),@"sessionID":self.sessionID?:@"",@"flexVisible":@(!FLEXManager.sharedManager.isHidden),@"targetReady":@(!visible&&FLEXManager.sharedManager.isHidden&&!self.uiTransitioning),@"statusVisible":@(self.statusWindow&&!self.statusWindow.hidden),@"activity":self.taskPhase?:@"",@"uiTransitioning":@(self.uiTransitioning)};
}
- (void)minimizeChat:(BOOL)target completion:(dispatch_block_t)completion {
 [self.view endEditing:YES];[self rememberConnection];
 dispatch_block_t done=^{self.chatMinimized=YES;if(target)[FLEXManager.sharedManager hideExplorer];[self refreshAgentStatus];if(completion)completion();};
 if(self.navigationController.presentingViewController)[self.navigationController dismissViewControllerAnimated:YES completion:done];else done();
}
- (void)restoreChatWithCompletion:(dispatch_block_t)completion {
 self.statusWindow.hidden=YES;
 if(self.viewIfLoaded.window){[FLEXManager.sharedManager showExplorer];self.chatMinimized=NO;[self refreshAgentStatus];if(completion)completion();return;}
 [FLEXManager.sharedManager dismissAnyPresentedTools:^{
  [FLEXManager.sharedManager presentTool:^UINavigationController *{return self.navigationController;} completion:^{self.chatMinimized=NO;[self refreshAgentStatus];if(completion)completion();}];
 }];
}
- (void)stopAgentTapped {
 // Local latch closes immediately, even if the cancel request cannot reach Dylix.
 self.agentStopped=YES;NSUInteger generation=++self.agentGeneration;[self setStatus:@"正在停止任务…"];
 [self.runtime cancelPendingInput];
 if(self.jobID.length)[self request:@"/api/v1/jobs/cancel" body:@{@"id":self.jobID} completion:^(NSDictionary *result,NSError *error){if(generation!=self.agentGeneration)return;if(!error){self.busy=NO;self.jobID=nil;}[self setStatus:error?@"本地工具已停止；远端取消失败，请恢复会话检查":@"任务已停止"]; }];
 else [self setStatus:@"本地工具已停止"]; 
}
- (void)closeTapped {if(self.uiTransitioning)return;self.uiTransitioning=YES;[self minimizeChat:NO completion:^{self.uiTransitioning=NO;}];}
- (void)disconnectTapped {
 if(self.busy){[self showError:DXChatError(@"AI 正在回复，请等本次请求结束后断开")];return;}
 if(!self.token.length){[self setStatus:@"尚未连接 Dylix"];return;}
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"断开 Dylix" message:@"清除保存的授权码和连接令牌，保留地址、项目、模型及会话选择。再次连接需要授权码。" preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
 [alert addAction:[UIAlertAction actionWithTitle:@"断开连接" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
  [self.agentTimer invalidate];self.agentTimer=nil;[self setStatus:@"正在断开 Dylix…"];
  self.agentStopped=YES;
  [self request:@"/api/v1/logout" body:@{} completion:^(NSDictionary *result,NSError *error){
   NSError *storageError=nil;[FLEXDylixPreferences clearAuthorization:&storageError];
   self.sessionLoadGeneration++;self.token=nil;self.csrf=nil;self.authorizationCode=nil;self.jobID=nil;self.needsConnectionValidation=NO;
   self.missedHeartbeats=0;[self showConnectionState:0];[self rememberConnection];[self setStatus:storageError?storageError.localizedDescription:@"已断开 Dylix，已保留项目和模型选择"];
  }];
 }]];
 [self presentViewController:alert animated:YES completion:nil];
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated];self.chatMinimized=NO;[self refreshAgentStatus];if(self.needsConnectionValidation){[self resumeSavedConnection];return;}[self startAgentPolling];[self pollAgent]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self rememberConnection]; }
- (void)startAgentPolling {
 if(self.agentTimer||!self.csrf.length||self.needsConnectionValidation)return;
 self.agentTimer=[NSTimer timerWithTimeInterval:1 target:self selector:@selector(pollAgent) userInfo:nil repeats:YES];
 [NSRunLoop.mainRunLoop addTimer:self.agentTimer forMode:NSRunLoopCommonModes];[self pollAgent];
}
- (void)pollAgent {
 [self refreshAgentStatus];
 if(self.agentPolling||!self.csrf.length||self.needsConnectionValidation)return;
 self.agentPolling=YES;NSUInteger generation=self.sessionLoadGeneration;
 [self request:@"/api/v1/flex/next" body:@{} completion:^(NSDictionary *command,NSError *error){
  self.agentPolling=NO;if(generation!=self.sessionLoadGeneration||!self.csrf.length||self.needsConnectionValidation)return;
  if(error){self.lastConnectionError=error;self.missedHeartbeats++;if(self.missedHeartbeats>=2){[self showConnectionState:3];[self setStatus:@"连接中断 · 连接设置可查看诊断，正在重试"]; }return;}
  self.missedHeartbeats=0;[self showConnectionState:2];
  if(![command[@"id"] isKindOfClass:NSString.class]){if(self.pendingCommandID&&self.agentReplies[self.pendingCommandID]){[self.agentReplies removeObjectForKey:self.pendingCommandID];self.pendingCommandID=nil;}return;}
  NSString *identifier=command[@"id"];NSDictionary *reply=self.agentReplies[identifier];
  if(reply){[self sendAgentReply:reply];return;}
  if(self.pendingCommandID)return;
  self.pendingCommandID=identifier;
  [self executeAgentCommand:command];
 }];
}
- (void)sendAgentReply:(NSDictionary *)reply {
 if(self.agentReplying)return;self.agentReplying=YES;
 [self request:@"/api/v1/flex/reply" body:reply completion:^(NSDictionary *result,NSError *error){
  self.agentReplying=NO;
  if(!error||[error.localizedDescription containsString:@"过期"]||[error.localizedDescription containsString:@"不属于当前设备"]){[self.agentReplies removeObjectForKey:reply[@"id"]];if([self.pendingCommandID isEqual:reply[@"id"]])self.pendingCommandID=nil;}
 }];
}
- (void)finishAgentCommand:(NSDictionary *)command allowed:(BOOL)allowed {
 NSString *identifier=command[@"id"],*operation=command[@"operation"];
 NSDictionary *result=nil;NSString *failure=nil;
 NSTimeInterval expiry=[command[@"expiresAt"] isKindOfClass:NSNumber.class]?[command[@"expiresAt"] doubleValue]:0;
 if(allowed&&expiry>NSDate.date.timeIntervalSince1970&&!self.agentStopped){self.localOperation=operation;self.lastTaskUpdate=NSProcessInfo.processInfo.systemUptime;[self refreshAgentStatus];}
 if(allowed&&expiry<=NSDate.date.timeIntervalSince1970)failure=@"命令已过期；请让 AI 重新查询";
 else if(allowed&&(self.agentStopped||(self.commandGenerations[identifier]&&[self.commandGenerations[identifier] unsignedIntegerValue]!=self.agentGeneration)))failure=@"用户已停止 AI 工具操作，请等待用户发起新任务";
 else if(allowed&&[operation isEqual:@"chat_status"])result=[self chatWindowStatus];
 else if(allowed&&[operation isEqual:@"gesture"]){
  [self.runtime performGesture:command[@"arguments"] completion:^(NSDictionary *answer,NSString *error){[self deliverAgentCommand:command result:answer error:error];}];return;
 }
 else if(allowed&&[@[@"minimize_chat",@"restore_chat",@"open_tool",@"navigate_back",@"dismiss_tool"] containsObject:operation]){
  [self executeWindowCommand:command];return;
 }
 else if(allowed){@try{result=[self.runtime execute:operation arguments:command[@"arguments"] error:&failure];}@catch(NSException *exception){failure=[NSString stringWithFormat:@"FLEX 操作异常（%@）；请重新查询页面",exception.name];}}
 else failure=@"FLEX 用户拒绝此项操作";
 [self deliverAgentCommand:command result:result error:failure];
}
- (void)deliverAgentCommand:(NSDictionary *)command result:(NSDictionary *)result error:(NSString *)failure {
 self.localOperation=nil;[self refreshAgentStatus];
 NSString *identifier=command[@"id"];
 NSDictionary *reply=failure?@{@"id":identifier,@"error":failure}:@{@"id":identifier,@"result":result?:@{}};
 if([NSJSONSerialization dataWithJSONObject:reply options:0 error:nil].length>240*1024)reply=@{@"id":identifier,@"error":@"FLEX 结果超过传输上限；请缩小查询范围"};
 self.agentReplies[identifier]=reply;[self sendAgentReply:reply];
}
- (void)completeWindowCommand:(NSDictionary *)command error:(NSString *)failure {
 self.uiTransitioning=NO;self.localOperation=nil;[self refreshAgentStatus];
 NSDictionary *reply=failure?@{@"id":command[@"id"],@"error":failure}:@{@"id":command[@"id"],@"result":[self chatWindowStatus]};
 self.agentReplies[command[@"id"]]=reply;[self sendAgentReply:reply];
}
- (void)executeWindowCommand:(NSDictionary *)command {
 if(self.uiTransitioning){NSDictionary *reply=@{@"id":command[@"id"],@"error":@"窗口正在切换，请稍后重新读取 chat_status"};self.agentReplies[command[@"id"]]=reply;[self sendAgentReply:reply];return;}
 self.uiTransitioning=YES;NSString *operation=command[@"operation"];
 if([operation isEqual:@"minimize_chat"]){[self minimizeChat:![command[@"arguments"][@"surface"] isEqual:@"flex"] completion:^{[self completeWindowCommand:command error:nil];}];return;}
 if([operation isEqual:@"restore_chat"]){[self restoreChatWithCompletion:^{[self completeWindowCommand:command error:nil];}];return;}
 if([operation isEqual:@"open_tool"]){
  NSString *failure=nil;UIViewController *controller=nil;
  @try{controller=[self.runtime controllerForTool:command[@"arguments"][@"tool_id"] error:&failure];}@catch(NSException *exception){failure=[NSString stringWithFormat:@"FLEX 入口暂不可用（%@）",exception.name];}
  if(!controller){[self completeWindowCommand:command error:failure];return;}
  [self minimizeChat:NO completion:^{[FLEXManager.sharedManager dismissAnyPresentedTools:^{[FLEXManager.sharedManager presentEmbeddedTool:controller completion:^(UINavigationController *nav){[self completeWindowCommand:command error:nil];}];}];}];return;
 }
 UIViewController *visible=[FLEXUtility topViewControllerInWindow:FLEXManager.sharedManager.explorerWindow];
 if([visible isKindOfClass:UIAlertController.class]){[self completeWindowCommand:command error:@"请先人工处理当前弹窗"];return;}
 if([operation isEqual:@"navigate_back"]){
  UINavigationController *nav=visible.navigationController;if(nav.viewControllers.count<2){[self completeWindowCommand:command error:@"当前 FLEX 页已经在导航根部"];return;}
  [nav popViewControllerAnimated:NO];[self completeWindowCommand:command error:nil];return;
 }
 [FLEXManager.sharedManager dismissAnyPresentedTools:^{[self completeWindowCommand:command error:nil];}];
}
- (UIViewController *)approvalPresenter {
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return nil;
 if(self.view.window&&!self.navigationController.isBeingDismissed)return self;
 UIWindow *flexWindow=FLEXManager.sharedManager.explorerWindow;
 UIViewController *presenter=!flexWindow.hidden?[FLEXUtility topViewControllerInWindow:flexWindow]:nil;
 if(!presenter){UIWindow *host=FLEXUtility.appKeyWindow;presenter=!host.hidden?[FLEXUtility topViewControllerInWindow:host]:nil;}
 if([presenter isKindOfClass:UIAlertController.class]||!presenter.view.window)return nil;
 return presenter;
}
- (void)presentApproval:(UIAlertController *)alert expiresAt:(NSTimeInterval)expiry onExpiry:(dispatch_block_t)onExpiry {
 if(!self.csrf.length||NSDate.date.timeIntervalSince1970>=expiry){onExpiry();return;}
 UIViewController *presenter=[self approvalPresenter];
 if(presenter){[presenter presentViewController:alert animated:YES completion:nil];return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self presentApproval:alert expiresAt:expiry onExpiry:onExpiry];});
}
- (void)executeAgentCommand:(NSDictionary *)command {
 NSString *operation=command[@"operation"];
 self.commandGenerations[command[@"id"]]=@(self.agentGeneration);
 if(self.commandGenerations.count>128){for(NSString *key in self.commandGenerations.allKeys)if(![key isEqual:self.pendingCommandID])[self.commandGenerations removeObjectForKey:key];}
 if(self.agentStopped){[self finishAgentCommand:command allowed:YES];return;}
 NSSet *confirm=[NSSet setWithArray:@[@"input_text",@"set_control_value",@"gesture",@"class_header",@"capture_screen",@"flex_ui_state",@"network_detail",@"sandbox_read",@"defaults_get",@"keychain_list",@"activate_control",@"scroll_view",@"set_view",@"set_network_recording",@"undo",@"minimize_chat",@"restore_chat",@"open_tool",@"navigate_back",@"dismiss_tool",@"select_row",@"set_search",@"flex_scroll"]];
 if(![confirm containsObject:operation]){[self finishAgentCommand:command allowed:YES];return;}
 if(self.projectID.length&&self.csrf.length&&self.sessionID.length){
  NSString *sid=command[@"sessionID"]?:self.sessionID;
  if(![sid isEqual:self.sessionID]){[self finishAgentCommand:command allowed:NO];return;}
  [self workspace:@"flex_tool_permission" arguments:@{@"sessionID":sid} completion:^(NSDictionary *state,NSError *error){
   if(![sid isEqual:self.sessionID]){[self finishAgentCommand:command allowed:NO];return;}
   if(!error&&[state[@"enabled"] boolValue]){[self finishAgentCommand:command allowed:YES];return;}
   // The server normally obtains the conversation grant before issuing a command.
   // Never add a second per-operation dialog after a grant has been accepted.
   [self finishAgentCommand:command allowed:NO];[self setStatus:@"请点击权限，授权当前会话的 FLEX 工具"];
  }];return;
 }
 [self finishAgentCommand:command allowed:NO];[self setStatus:@"请先授权当前会话的 FLEX 工具"];
}
- (void)showSessionPermission {
 NSString *sid=self.sessionID,*project=self.projectID;NSUInteger generation=self.sessionLoadGeneration;
 [self workspace:@"flex_tool_permission" arguments:@{@"sessionID":sid} completion:^(NSDictionary *state,NSError *error){
  if(generation!=self.sessionLoadGeneration||![sid isEqual:self.sessionID]||![project isEqual:self.projectID])return;
  if(error){[self showError:error];return;}BOOL active=[state[@"enabled"] boolValue];
  if(!active){[self setSessionPermission:YES session:sid project:project];return;}
  UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"本会话 FLEX 总权限" message:@"已授权，没有时间限制。新会话需重新授权；断开设备或停止远程服务后授权结束。" preferredStyle:UIAlertControllerStyleActionSheet];
  [menu addAction:[UIAlertAction actionWithTitle:@"撤销本会话授权" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){if([sid isEqual:self.sessionID]&&[project isEqual:self.projectID])[self setSessionPermission:NO session:sid project:project];}]];
  [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];menu.popoverPresentationController.sourceView=self.permissionButton;menu.popoverPresentationController.sourceRect=self.permissionButton.bounds;[self presentViewController:menu animated:YES completion:nil];
 }];
}
- (void)setSessionPermission:(BOOL)enabled session:(NSString *)sid project:(NSString *)project {
 [self workspace:@"flex_tool_permission" arguments:@{@"sessionID":sid,@"enabled":@(enabled)} completion:^(NSDictionary *result,NSError *error){
  if(![sid isEqual:self.sessionID]||![project isEqual:self.projectID])return;
  if(error)[self showError:error];else [self setStatus:enabled?@"本会话 FLEX 已授权 · 无时间限制":@"本会话 FLEX 授权已撤销"];
 }];
}
- (void)permissionTapped {
 if(!self.csrf.length||!self.projectID.length){[self setStatus:@"请先连接 Dylix 并选择项目"];return;}
 if(self.sessionID.length){[self showSessionPermission];return;}
 if(self.busy){[self setStatus:@"正在建立会话，请稍后授权"];return;}
 NSString *project=self.projectID;NSUInteger generation=self.sessionLoadGeneration;self.busy=YES;
 [self workspace:@"ai_create" arguments:@{} completion:^(NSDictionary *result,NSError *error){
  self.busy=NO;if(generation!=self.sessionLoadGeneration||![project isEqual:self.projectID])return;
  if(error){[self showError:error];return;}NSString *sid=result[@"id"];
  if(![sid isKindOfClass:NSString.class]||!sid.length){[self showError:DXChatError(@"建立会话失败")];return;}
  self.sessionID=sid;self.sessionTitle=result[@"title"];[self updateSessionButton];[self rememberConnection];[self showSessionPermission];
 }];
}

// Plain HTTP is intentional for the user's LAN-only Remote service. This socket path is independent of host ATS and NSURLSession hooks.
- (NSDictionary *)requestSync:(NSString *)path body:(NSDictionary *)body error:(NSError **)error {
 NSString *newToken=nil;
 NSDictionary *result=FLEXDylixHTTPRequest(self.host,self.port,path,body,self.token,self.csrf,8,&newToken,error);
 if(newToken.length)self.token=newToken;
 return result;
}
- (void)request:(NSString *)path body:(NSDictionary *)body completion:(DXChatReply)completion {
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *error=nil;NSDictionary *result=[self requestSync:path body:body error:&error];dispatch_async(dispatch_get_main_queue(),^{completion(result,error);});});
}
- (void)workspace:(NSString *)action arguments:(NSDictionary *)arguments completion:(DXChatReply)completion {
 [self request:@"/api/v1/workspace" body:@{@"action":action,@"projectID":self.projectID?:@"",@"arguments":arguments?:@{}} completion:^(NSDictionary *data,NSError *error){if(error){completion(nil,error);return;}[self waitJob:data[@"id"] completion:completion];}];
}
- (void)waitJob:(NSString *)identifier completion:(DXChatReply)completion {
 if(![identifier isKindOfClass:NSString.class]){completion(nil,DXChatError(@"Dylix 没有返回任务 ID"));return;}
 [self request:@"/api/v1/jobs/get" body:@{@"id":identifier} completion:^(NSDictionary *job,NSError *error){
  if(error){completion(nil,error);return;}
  BOOL current=[identifier isEqual:self.jobID];
  if(current&&[job[@"sessionID"] isKindOfClass:NSString.class]){self.sessionID=job[@"sessionID"];[self rememberConnection];}
  if(current&&!self.agentStopped){[self updateTaskFromJob:job];if([job[@"text"] isKindOfClass:NSString.class])[self setLiveText:job[@"text"]];}
  NSString *state=job[@"state"];
  if([state isEqual:@"completed"]){completion(job[@"result"]?:@{},nil);return;}
  if([state isEqual:@"failed"]||[state isEqual:@"cancelled"]){completion(nil,DXChatError(job[@"error"]?:@"任务未完成"));return;}
  if([state isEqual:@"awaiting_confirmation"]){[self confirmJob:job completion:completion];return;}
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self waitJob:identifier completion:completion];});
 }];
}
- (void)confirmJob:(NSDictionary *)job completion:(DXChatReply)completion {
 NSString *identifier=job[@"id"],*nonce=job[@"nonce"];if(!identifier.length||!nonce.length){completion(nil,DXChatError(@"确认请求无效"));return;}
 NSTimeInterval expiry=[job[@"expiresAt"] isKindOfClass:NSNumber.class]?[job[@"expiresAt"] doubleValue]:0;
 if(expiry<=0)expiry=NSDate.date.timeIntervalSince1970+120;
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"确认 Dylix 操作" message:[@[job[@"confirmation"][@"summary"]?:@"AI 请求执行操作",job[@"confirmation"][@"details"]?:@""] componentsJoinedByString:@"\n\n"] preferredStyle:UIAlertControllerStyleAlert];
 for(NSNumber *choice in @[@NO,@YES]){BOOL accepted=choice.boolValue;[alert addAction:[UIAlertAction actionWithTitle:accepted?@"允许":@"拒绝" style:accepted?UIAlertActionStyleDefault:UIAlertActionStyleCancel handler:^(UIAlertAction *action){[self request:@"/api/v1/jobs/confirm" body:@{@"id":identifier,@"nonce":nonce,@"accepted":choice} completion:^(NSDictionary *result,NSError *error){if(error)completion(nil,error);else [self waitJob:identifier completion:completion];}];}]];}[self presentApproval:alert expiresAt:expiry onExpiry:^{completion(nil,DXChatError(@"Dylix 操作确认已过期"));}];
}
- (void)connectTapped {
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"连接 Dylix Remote" message:@"粘贴 Dylix 设置页复制的完整地址，再输入授权码" preferredStyle:UIAlertControllerStyleAlert];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"粘贴 Dylix 复制的访问地址";if(self.host.length&&self.port)field.text=[NSString stringWithFormat:@"http://%@:%lu",self.host,(unsigned long)self.port];field.keyboardType=UIKeyboardTypeURL;field.autocapitalizationType=UITextAutocapitalizationTypeNone;field.autocorrectionType=UITextAutocorrectionTypeNo;}];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"授权码";field.text=self.authorizationCode;field.secureTextEntry=YES;field.keyboardType=UIKeyboardTypeNumberPad;}];
 if(self.lastConnectionError.userInfo[FLEXDylixConnectionDiagnosticKey])[alert addAction:[UIAlertAction actionWithTitle:@"上次连接诊断" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self showConnectionDiagnostic];}]];
 if(self.token.length)[alert addAction:[UIAlertAction actionWithTitle:@"使用已保存连接" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){self.needsConnectionValidation=YES;[self resumeSavedConnection];}]];
 [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
 [alert addAction:[UIAlertAction actionWithTitle:@"连接" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
  NSString *host=nil,*message=nil;NSUInteger port=0;
  if(!FLEXDylixParseAddress(alert.textFields[0].text,&host,&port,&message)){[self showError:DXChatError(message)];return;}
  NSString *code=[alert.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!code.length){[self showError:DXChatError(@"请输入授权码")];return;}
  if(self.busy){[self setStatus:@"AI 正在执行，请结束任务后更换连接"];return;}
  BOOL changed=![self.host isEqual:host]||self.port!=port;self.sessionLoadGeneration++;self.host=host;self.port=port;self.authorizationCode=code;self.token=nil;self.csrf=nil;self.needsConnectionValidation=NO;self.restoringWorkspace=NO;self.missedHeartbeats=0;
  if(changed){self.projectID=nil;self.projectName=nil;self.connectionID=nil;self.modelID=nil;self.modelName=nil;self.sessionID=nil;self.sessionTitle=nil;[self.messages removeAllObjects];[self renderMessages];[self.projectButton setTitle:@"选择项目" forState:UIControlStateNormal];[self.modelButton setTitle:@"选择模型" forState:UIControlStateNormal];[self updateSessionButton];}
  [self rememberConnection];[self showConnectionState:1];
  NSString *name=[NSString stringWithFormat:@"FLEX · %@",NSBundle.mainBundle.bundleIdentifier?:@"目标 App"];if(name.length>64)name=[name substringToIndex:64];[self setStatus:@"正在配对…"];
  [self request:@"/api/v1/pair" body:@{@"code":code,@"name":name,@"workspace":@YES} completion:^(NSDictionary *data,NSError *error){if(error){[self showConnectionState:3];[self showError:error];return;}[self request:@"/api/v1/status" body:@{} completion:^(NSDictionary *status,NSError *failure){if(failure){[self showConnectionState:3];[self showError:failure];return;}self.csrf=status[@"session"][@"csrf"];if(!self.csrf.length){[self showConnectionState:3];[self showError:DXChatError(@"配对后未取得请求校验值")];return;}[self showConnectionState:2];[self setStatus:@"配对完成"];[self startAgentPolling];if(self.projectID.length)[self restoreSavedWorkspace];else [self projectTapped];}];}];
 }]];
 [self presentViewController:alert animated:YES completion:nil];
}
- (void)projectTapped {if(self.restoringWorkspace){[self setStatus:@"正在恢复上次项目和会话，请稍候"];return;}
 if(self.busy){[self setStatus:@"AI 正在回复，结束后可切换项目"];return;}
 if(!self.csrf.length){[self connectTapped];return;}
 [self workspace:@"projects" arguments:@{} completion:^(NSDictionary *data,NSError *error){if(error){[self showError:error];return;}NSArray *projects=data[@"projects"];UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"选择 Dylix 项目" message:@"AI 的文件和构建权限仍限定在所选项目" preferredStyle:UIAlertControllerStyleActionSheet];for(NSDictionary *project in projects){NSString *name=project[@"name"]?:project[@"id"];[menu addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){if(![self.projectID isEqual:project[@"id"]]){[self saveDraft];self.sessionLoadGeneration++;self.projectID=project[@"id"];self.projectName=name;self.sessionID=nil;self.sessionTitle=nil;self.reasoningEffort=nil;self.reasoningOptions=nil;self.liveMessage=nil;[self.messages removeAllObjects];[self addMessage:@"已切换项目。选择历史会话，或直接发送以创建新会话。" role:@"tip"];[self restoreDraft];[self updateSessionButton];}else self.projectName=name;[self.projectButton setTitle:name forState:UIControlStateNormal];[self rememberConnection];[self modelTapped];}]];}[menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];menu.popoverPresentationController.sourceView=self.projectButton;menu.popoverPresentationController.sourceRect=self.projectButton.bounds;[self presentViewController:menu animated:YES completion:nil];}];
}
- (void)applyModelSelection:(NSDictionary *)connection {
 BOOL changed=![self.connectionID isEqual:connection[@"id"]]||![self.modelID isEqual:connection[@"model"]];
 self.connectionID=connection[@"id"];self.modelID=connection[@"model"];self.reasoningOptions=connection[@"efforts"];
 if(changed)self.reasoningEffort=@"auto";
 self.modelName=[NSString stringWithFormat:@"%@ · %@",connection[@"provider"]?:@"",self.modelID?:@""];
 [self.modelButton setTitle:self.modelID?:@"选择模型" forState:UIControlStateNormal];[self rememberConnection];
 [self setStatus:[NSString stringWithFormat:@"模型已选择 · %@",self.modelName]];
}
- (void)chooseReasoningForConnection:(NSDictionary *)connection {
 NSArray *options=connection[@"efforts"];if(![options isKindOfClass:NSArray.class]||options.count<2){[self setStatus:@"此模型未提供可调思考档位，将使用模型默认设置"];return;}
 NSString *project=[self.projectID copy],*cid=[self.connectionID copy],*model=[self.modelID copy];NSUInteger generation=self.sessionLoadGeneration;
 UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"深度思考" message:@"仅列出当前模型支持的档位。选择后下次发送生效；未在 FLEX 选择时沿用 Dylix 会话设置。" preferredStyle:UIAlertControllerStyleActionSheet];
 for(NSDictionary *option in options){NSString *value=option[@"id"];if(![value isKindOfClass:NSString.class])continue;NSString *name=option[@"name"]?:value;
 [menu addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){if(self.busy||generation!=self.sessionLoadGeneration||![project isEqual:self.projectID]||![cid isEqual:self.connectionID]||![model isEqual:self.modelID])return;self.reasoningEffort=value;[self setStatus:[NSString stringWithFormat:@"深度思考：%@ · 下次发送生效",name]];}]];}
 [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];menu.popoverPresentationController.sourceView=self.modelButton;menu.popoverPresentationController.sourceRect=self.modelButton.bounds;[self presentViewController:menu animated:YES completion:nil];
}
- (void)modelTapped {if(self.restoringWorkspace){[self setStatus:@"正在恢复上次项目和会话，请稍候"];return;}
 if(self.busy){[self setStatus:@"AI 正在回复，结束后可切换模型"];return;}
 if(!self.projectID.length){[self projectTapped];return;}
 NSString *project=self.projectID;NSUInteger generation=++self.sessionLoadGeneration;
 [self workspace:@"ai_connections" arguments:@{} completion:^(NSDictionary *data,NSError *error){
  if(generation!=self.sessionLoadGeneration||![project isEqual:self.projectID]||self.busy)return;
  if(error){[self showError:error];return;}
  UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"选择模型" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
  for(NSDictionary *connection in data[@"connections"]){NSString *name=[NSString stringWithFormat:@"%@ · %@",connection[@"provider"]?:@"",connection[@"model"]?:@""];
   [menu addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){if(generation==self.sessionLoadGeneration&&[project isEqual:self.projectID]&&!self.busy){[self applyModelSelection:connection];[self dismissViewControllerAnimated:YES completion:^{[self chooseReasoningForConnection:connection];}];}}]];
  }
  [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];menu.popoverPresentationController.sourceView=self.modelButton;menu.popoverPresentationController.sourceRect=self.modelButton.bounds;[self presentViewController:menu animated:YES completion:nil];
 }];
}
- (void)setLiveText:(NSString *)text {if(!self.liveMessage)return;self.liveMessage[@"text"]=text?:@"";self.liveHasContent=text.length>0;self.liveLabel.attributedText=FLEXDylixRenderMarkdown(text,self.liveLabel.textColor);[self scrollMessagesToBottom];[self rememberConnection];}
- (void)sendTapped {
 if(self.restoringWorkspace){[self setStatus:@"正在恢复上次项目和会话，请稍候"];return;}
 if(self.needsConnectionValidation){[self resumeSavedConnection];return;}
 if(self.busy){[self stopAgentTapped];return;}
 NSString *question=[self.input.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!question.length)return;
 if(!self.projectID.length||!self.connectionID.length||!self.modelID.length){[self showError:DXChatError(@"请先连接 Dylix，选择项目和模型")];return;}
 if(!self.sessionID.length){
  NSString *project=self.projectID;NSUInteger loadGeneration=self.sessionLoadGeneration,requestGeneration=self.agentGeneration;self.busy=YES;
  [self workspace:@"ai_create" arguments:@{@"name":question.length>30?[question substringToIndex:30]:question} completion:^(NSDictionary *record,NSError *error){
   self.busy=NO;if(loadGeneration!=self.sessionLoadGeneration||requestGeneration!=self.agentGeneration||![project isEqual:self.projectID])return;
   if(error){[self showError:error];return;}NSString *sid=record[@"id"];
   if(![sid isKindOfClass:NSString.class]||!sid.length){[self showError:DXChatError(@"建立会话失败")];return;}
   self.sessionID=sid;self.sessionTitle=record[@"title"];[self rememberConnection];[self updateSessionButton];[self sendTapped];
  }];return;
 }
 self.agentStopped=NO;self.lastEventSequence=0;self.captureStatus=nil;self.captureID=nil;self.lastCaptureSequence=0;[self.activeToolOperations removeAllObjects];self.waitingApproval=NO;self.taskPhase=@"正在同步现场";self.lastTaskUpdate=NSProcessInfo.processInfo.systemUptime;
 NSUInteger generation=self.agentGeneration;
 self.busy=YES;self.input.text=@"";[self textViewDidChange:self.input];[self.input resignFirstResponder];[self addMessage:question role:@"user"];[self addMessage:@"" role:@"assistant"];self.liveHasContent=NO;[self setStatus:@"正在同步 FLEX 现场…"];
 NSString *bundle=NSBundle.mainBundle.bundleIdentifier?:@"unknown";NSString *current=self.reportProvider?self.reportProvider():self.report;
 NSDictionary *live=[self.runtime execute:@"current" arguments:@{} error:nil]?:@{};NSData *liveData=[NSJSONSerialization dataWithJSONObject:live options:0 error:nil];NSString *liveText=liveData?[[NSString alloc]initWithData:liveData encoding:NSUTF8StringEncoding]:@"";
 NSString *fullReport=[NSString stringWithFormat:@"%@\nCurrent FLEX runtime: %@",current?:@"",liveText?:@""];NSString *report=fullReport.length>16000?[fullReport substringToIndex:16000]:fullReport;
 NSString *liveClass=live[@"selectedObject"][@"class"]?:self.className;
 [self workspace:@"flex_publish" arguments:@{@"bundleID":bundle,@"className":liveClass?:@"未知对象",@"report":report,@"capabilities":@{@"protocolVersion":@2,@"touchGestures":@([[self.runtime execute:@"gesture_capabilities" arguments:@{} error:nil][@"available"] boolValue])}} completion:^(NSDictionary *published,NSError *error){if(generation!=self.agentGeneration){self.busy=NO;[self setStatus:@"任务已停止"];return;}if(error){self.busy=NO;self.sendButton.enabled=YES;[self setLiveText:error.localizedDescription];[self showError:error];return;}
  NSString *contextualQuestion=[NSString stringWithFormat:@"%@\n\n当前 FLEX 现场：目标 App %@，当前选中对象 %@。你可以自主用 flex_live_read(current)、screen_elements 和 view_tree 探索整个当前页面，不必等用户先选视图；可用 hit_test 从窗口坐标定位对象。若当前模型已验证图片能力，且用户授权 FLEX 敏感读取，可用 flex_sensitive_read(capture_screen) 获取目标窗口截图；截图会作为下一轮真正的图片输入，不是 base64 文本。需要进入页面时，可请求 flex_control(activate_control) 激活可见 UIButton，或 scroll_view 滚动，均受 FLEX 控制授权约束；操作后重新观察页面。默认目标是在 Dylix 当前项目中编写持久插件功能，视图实例 ID 不是 Logos Hook 的类名或 selector。按需用 class_info、项目文件及已授权头文件核查类与方法；object_info 的 hookEvidence 提供祖先视图、nearest_responder_controller、稳定特征候选和生命周期方法声明位置。先读取目标按钮与业务祖先的 object_info，再用 class_info/class_header 核查；导航离开重进、滚动复用后重新截图和查询，比较 signature 与 instanceID。lifecycleExecutionObserved=false 表示没有调用轨迹，不能把声明当成实际执行；stabilityVerified=false 表示尚需你交叉验证。证据不足时说明缺口，不要编造 Hook。set_view 仅临时改变当前实例，不能代替插件代码；项目写入和构建仍走 Dylix 原有审批。",question,bundle,liveClass];
  contextualQuestion=[contextualQuestion stringByAppendingString:@"\n自主操作时先读取 tool_catalog 和 chat_status。需要操作目标 App 时调用 flex_control(minimize_chat, surface=target)，确认 chat_status.targetReady=true 后再触摸，会话与任务保持运行；需要操作 FLEX 功能页时用 open_tool 和返回目录中的 tool_id，随后用 flex_sensitive_read(flex_ui_state) 读取页面、用 set_search / flex_scroll / select_row 导航（仅 selectSupported=true 的行），最后可 restore_chat 恢复聊天。截图可指定 surface=flex 或 target。收起后有独立的 AI 状态悬浮球，显示连接、工具处理和回复状态，不暂停会话；用户可以点击悬浮球或 FLEX 菜单的 Dylix AI 回到同一会话。状态球不是目标 App 控件，不要操作它。若工具报告停止，不可重试控制。目录标为不支持的入口不要声称已操作。需要自定义点击、双击、长按、滑动、拖动、双指缩放或旋转时，先读 gesture_capabilities；若可用，再在会话已收起到 target 后调用 flex_control(gesture)。这是投递真实触摸序列，返回 delivered 仅证明已投递，必须重新截图/读取现场确认业务效果。滚动返回 scrolled 表示实际位移；用 previousOffset、contentOffset、delta 与 reachedBoundary 区分移动和触及边界。xx.h 与反汇编入口为 extension.headers / extension.disassembly；class_header 可按行读取真实头文件。若候选 UIButton 无 controlActions，或 hit_test 命中其父容器，应继续检查交互父视图、手势及所属控制器，不能据此编写全局 UIButton Hook。用户要求的测试应逐项执行或明确阻塞原因，不得因为其他项目已通过就跳过可恢复的测试。独立测试构建前先确认 schema 能否选择隔离项目/配置；没有入口就先报告阻塞，不能只创建散落源码后当成构建准备完成，更不能改业务根配置。仅返回普通页面且实例相同，只能说明实例被保留，不能当作销毁重建或列表复用验证。截图像素尺寸可能经过压缩，触摸坐标以 screen_elements.windowBounds 为准。"];
  NSMutableDictionary *arguments=[@{@"text":contextualQuestion,@"connectionID":self.connectionID,@"model":self.modelID,@"mode":@"develop"} mutableCopy];if(self.sessionID.length)arguments[@"sessionID"]=self.sessionID;if(self.reasoningEffort.length)arguments[@"reasoningEffort"]=self.reasoningEffort;
  [self setStatus:@"AI 正在回复…"];[self request:@"/api/v1/workspace" body:@{@"action":@"ai_send",@"projectID":self.projectID,@"arguments":arguments} completion:^(NSDictionary *job,NSError *failure){if(generation!=self.agentGeneration){self.busy=NO;if([job[@"id"] length])[self request:@"/api/v1/jobs/cancel" body:@{@"id":job[@"id"]} completion:^(NSDictionary *r,NSError *e){}];return;}if(failure){self.busy=NO;self.sendButton.enabled=YES;[self setLiveText:failure.localizedDescription];[self showError:failure];return;}self.jobID=job[@"id"];if([job[@"sessionID"] isKindOfClass:NSString.class])self.sessionID=job[@"sessionID"];[self waitJob:self.jobID completion:^(NSDictionary *result,NSError *endError){if(generation!=self.agentGeneration)return;self.busy=NO;self.sendButton.enabled=YES;self.jobID=nil;if(endError){[self setLiveText:endError.localizedDescription];[self setStatus:@"请求未完成"];return;}if([result[@"sessionID"] isKindOfClass:NSString.class]){self.sessionID=result[@"sessionID"];if(!self.sessionTitle.length){self.sessionTitle=question.length>30?[question substringToIndex:30]:question;[self updateSessionButton];}}[self setStatus:@"回复完成"];if(!self.liveHasContent){NSArray *messages=result[@"messages"];for(NSDictionary *message in messages.reverseObjectEnumerator)if([message[@"role"] isEqual:@"assistant"]){NSString *text=DXChatContent(message[@"content"]);if(text.length){[self setLiveText:text];break;}}}[self rememberConnection];}];}];
 }];
}
- (void)dealloc {[NSNotificationCenter.defaultCenter removeObserver:self];[_agentTimer invalidate];_statusWindow.hidden=YES;}
@end

#import "TFAIISHHub.h"
#import "TFAIISHMirrors.h"
#import "TFAIISHRootCatalog.h"
#import "TFAIISHRemote.h"
#import "../Attachments/TFAIDirectoryRegistry.h"
#import "TFAIISHPreview.h"
#import "TFAIISHFiles.h"
#import "TFAIISHEnvironmentUI.h"
#import "../Agent/TFAIAgentUI.h"
#import "TFAIISHTerminal.h"
#import "TFAIISHRuntime.h"
#import "TFAIISHExports.h"
#import "../UI/TFAIUIHelpers.h"
#import <WebKit/WebKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface DylixTerminalPage : UIViewController <WKScriptMessageHandler,WKNavigationDelegate,UIDocumentPickerDelegate>
@property NSString *session,*processID,*projectRoot;
@property uint64_t outputOffset;
@property NSUInteger pollGeneration;
@property WKWebView *web;
@property UILabel *status,*bindingLabel,*directoryLabel;
@property NSDictionary *bindingContext;
@property NSTimer *contextTimer;
@property NSLayoutConstraint *bottom;
@property BOOL ready,keyboardVisible;
@property UIButton *keyboardButton,*ctrlButton,*altButton;
@property NSMutableData *pending;
@end
// WKUserContentController retains its handler. Use a weak forwarding object.
@interface DylixTerminalMessages : NSObject <WKScriptMessageHandler>
@property(weak) DylixTerminalPage *owner;
@end
@implementation DylixTerminalMessages
- (void)userContentController:(WKUserContentController *)c didReceiveScriptMessage:(WKScriptMessage *)m{[self.owner userContentController:c didReceiveScriptMessage:m];}
@end
@implementation DylixTerminalPage
- (void)viewDidLoad{
 [super viewDidLoad];if(self.projectRoot!=nil)[TFAIISHRuntime.shared configureProject:self.projectRoot session:self.session];self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.title=self.processID?[NSString stringWithFormat:@"Linux 进程 · %@",[self.processID substringToIndex:MIN(8,self.processID.length)]]:@"Linux 终端";self.view.backgroundColor=[UIColor colorWithRed:16/255.0 green:20/255.0 blue:28/255.0 alpha:1];self.pending=[NSMutableData new];
 UINavigationBarAppearance *bar=[UINavigationBarAppearance new];[bar configureWithOpaqueBackground];bar.backgroundColor=self.view.backgroundColor;bar.titleTextAttributes=@{NSForegroundColorAttributeName:UIColor.whiteColor};self.navigationItem.standardAppearance=bar;self.navigationItem.scrollEdgeAppearance=bar;self.navigationItem.compactAppearance=bar;
 self.navigationItem.rightBarButtonItems=@[AIBar(@"ellipsis.circle",@"终端操作",self,@selector(menu))];
 self.status=[UILabel new];self.status.text=@"Alpine Linux · 正在准备";self.status.textColor=UIColor.secondaryLabelColor;self.status.font=[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];self.status.adjustsFontForContentSizeCategory=YES;self.status.numberOfLines=2;
 self.bindingLabel=[UILabel new];self.bindingLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];self.bindingLabel.textColor=UIColor.labelColor;self.bindingLabel.numberOfLines=2;self.bindingLabel.adjustsFontForContentSizeCategory=YES;self.bindingLabel.accessibilityIdentifier=@"terminal.binding";
 self.directoryLabel=[UILabel new];self.directoryLabel.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];self.directoryLabel.textColor=UIColor.secondaryLabelColor;self.directoryLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;self.directoryLabel.accessibilityIdentifier=@"terminal.cwd";
 UIStackView *context=[[UIStackView alloc]initWithArrangedSubviews:@[self.bindingLabel,self.directoryLabel]];context.axis=UILayoutConstraintAxisVertical;context.spacing=3;context.accessibilityIdentifier=@"terminal.context";context.userInteractionEnabled=YES;[context addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(bindingInfo)]];
 WKWebViewConfiguration *configuration=[WKWebViewConfiguration new];configuration.websiteDataStore=WKWebsiteDataStore.nonPersistentDataStore;DylixTerminalMessages *handler=[DylixTerminalMessages new];handler.owner=self;[configuration.userContentController addScriptMessageHandler:handler name:@"dylixTerminal"];
 self.web=[[WKWebView alloc]initWithFrame:CGRectZero configuration:configuration];self.web.navigationDelegate=self;self.web.opaque=NO;self.web.backgroundColor=self.view.backgroundColor;self.web.scrollView.scrollEnabled=NO;
 UIView *keys=[UIView new];keys.backgroundColor=[UIColor colorWithWhite:0.09 alpha:1];
 UIScrollView *scroll=[UIScrollView new];scroll.showsHorizontalScrollIndicator=YES;scroll.alwaysBounceHorizontal=YES;scroll.accessibilityLabel=@"终端快捷键，左右滑动查看更多";
 UIStackView *row=[UIStackView new];row.axis=UILayoutConstraintAxisHorizontal;row.spacing=5;row.alignment=UIStackViewAlignmentCenter;
 [keys addSubview:scroll];[scroll addSubview:row];scroll.translatesAutoresizingMaskIntoConstraints=NO;row.translatesAutoresizingMaskIntoConstraints=NO;
 NSArray *labels=@[@"Esc",@"Tab",@"Ctrl",@"Alt",@"↑",@"↓",@"←",@"→",@"回车",@"粘贴",@"复制",@"Ctrl-C",@"Ctrl-D",@"Ctrl-Z",@"Ctrl-L",@"Home",@"End",@"PgUp",@"PgDn",@"Del",@"退格",@"/",@"|",@"-",@"~",@"文件",@"环境"];
 NSArray *names=@[@"escape",@"tab",@"ctrl",@"alt",@"up",@"down",@"left",@"right",@"enter",@"paste",@"copy",@"interrupt",@"eof",@"suspend",@"clear",@"home",@"end",@"pageUp",@"pageDown",@"delete",@"backspace",@"/",@"|",@"-",@"~",@"files",@"environment"];
 for(NSUInteger i=0;i<labels.count;i++){
  UIButton *button=[self shortcutButton:labels[i] key:names[i]];[row addArrangedSubview:button];
  if([names[i] isEqual:@"ctrl"])self.ctrlButton=button;if([names[i] isEqual:@"alt"])self.altButton=button;
 }
 self.keyboardButton=[self shortcutButton:@"键盘" key:@"keyboard"];[keys addSubview:self.keyboardButton];self.keyboardButton.translatesAutoresizingMaskIntoConstraints=NO;
 [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:keys.leadingAnchor constant:6],[scroll.trailingAnchor constraintEqualToAnchor:self.keyboardButton.leadingAnchor constant:-6],[scroll.topAnchor constraintEqualToAnchor:keys.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:keys.bottomAnchor],[row.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],[row.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-6],[row.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],[row.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],[row.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor],[self.keyboardButton.trailingAnchor constraintEqualToAnchor:keys.trailingAnchor constant:-6],[self.keyboardButton.centerYAnchor constraintEqualToAnchor:keys.centerYAnchor]]];
 for(UIView *v in @[context,self.status,self.web,keys]){v.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:v];}
 UILayoutGuide *safe=self.view.safeAreaLayoutGuide;self.bottom=[keys.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor];
 [NSLayoutConstraint activateConstraints:@[[context.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],[context.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],[context.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],[self.status.topAnchor constraintEqualToAnchor:context.bottomAnchor constant:4],[self.status.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],[self.status.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],[self.status.heightAnchor constraintGreaterThanOrEqualToConstant:26],[self.web.topAnchor constraintEqualToAnchor:self.status.bottomAnchor constant:4],[self.web.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],[self.web.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],[self.web.bottomAnchor constraintEqualToAnchor:keys.topAnchor],[keys.heightAnchor constraintEqualToConstant:52],[keys.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],[keys.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],self.bottom]];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(bytes:) name:TFAIISHTerminalOutput object:self.session];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(state:) name:TFAIISHStatusChanged object:self.session];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
 NSURL *url=[NSBundle.mainBundle URLForResource:@"index" withExtension:@"html" subdirectory:@"Terminal"];
 if(![TFAIISHRuntime available]||!url){self.status.text=@"当前构建没有可用的内嵌 Linux 环境";return;}
 if(!self.processID)[self.pending appendData:[TFAIISHRuntime.shared terminalReplay:self.session]];
 [self.web loadFileURL:url allowingReadAccessToURL:url.URLByDeletingLastPathComponent];
}
- (UIButton *)shortcutButton:(NSString *)title key:(NSString *)key{
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.accessibilityIdentifier=[@"terminal.key." stringByAppendingString:key];b.accessibilityLabel=title;b.titleLabel.font=[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];b.layer.cornerRadius=7;b.backgroundColor=[UIColor colorWithWhite:0.16 alpha:1];[b setTitle:title forState:UIControlStateNormal];[b setTitleColor:[UIColor colorWithWhite:0.92 alpha:1] forState:UIControlStateNormal];b.translatesAutoresizingMaskIntoConstraints=NO;[NSLayoutConstraint activateConstraints:@[[b.widthAnchor constraintGreaterThanOrEqualToConstant:48],[b.heightAnchor constraintEqualToConstant:44]]];b.contentEdgeInsets=UIEdgeInsetsMake(0,9,0,9);
 __weak typeof(self) weak=self;[b addAction:[UIAction actionWithHandler:^(UIAction *a){[weak shortcut:key];}] forControlEvents:UIControlEventTouchUpInside];return b;
}
- (void)shortcut:(NSString *)key{
 if([key isEqual:@"keyboard"]){if(self.keyboardVisible)[self.web endEditing:YES];else[self.web evaluateJavaScript:@"window.dylixFocus()" completionHandler:nil];return;}
 if([key isEqual:@"files"]){[self.navigationController pushViewController:TFAIISHFilesController(self.session,self.projectRoot) animated:YES];return;}
 if([key isEqual:@"environment"]){[self.navigationController pushViewController:TFAIISHEnvironmentController(self.session,self.projectRoot) animated:YES];return;}
 if([key isEqual:@"copy"]){[self.web evaluateJavaScript:@"terminal.getSelection()" completionHandler:^(id value,NSError *error){if([value isKindOfClass:NSString.class]&&[value length]){UIPasteboard.generalPasteboard.string=value;self.status.text=@"已复制选中文本";}else self.status.text=@"请先在终端中选择要复制的文本";}];return;}
 NSString *text=[key isEqual:@"paste"]?UIPasteboard.generalPasteboard.string:key;if(!text.length)return;
 NSData *json=[NSJSONSerialization dataWithJSONObject:@[text] options:0 error:nil];NSString *arg=[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding];NSString *method=[key isEqual:@"paste"]?@"dylixPaste":@"dylixKey";
 [self.web evaluateJavaScript:[NSString stringWithFormat:@"window.%@(%@[0])",method,arg] completionHandler:nil];
}
- (void)updateModifiers:(NSDictionary *)value{
 for(NSArray *pair in @[@[self.ctrlButton,@"ctrl"],@[self.altButton,@"alt"]]){UIButton *b=pair[0];BOOL active=[value[pair[1]] boolValue];b.selected=active;b.accessibilityValue=active?@"已启用，下一次按键生效":@"关闭";b.accessibilityTraits=UIAccessibilityTraitButton|(active?UIAccessibilityTraitSelected:0);b.backgroundColor=active?[UIColor colorWithRed:0.18 green:0.39 blue:0.6 alpha:1]:[UIColor colorWithWhite:0.16 alpha:1];}
}
- (UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
- (void)dealloc{[self.contextTimer invalidate];[NSNotificationCenter.defaultCenter removeObserver:self];[self.web.configuration.userContentController removeScriptMessageHandlerForName:@"dylixTerminal"];}
- (void)bytes:(NSNotification *)n{if(self.processID)return;NSData *data=n.userInfo[@"data"];if(self.ready)[self display:data];else{[self.pending appendData:data];if(self.pending.length>256*1024)[self.pending replaceBytesInRange:NSMakeRange(0,self.pending.length-256*1024) withBytes:NULL length:0];}}
- (void)display:(NSData *)data{if(!data.length)return;NSString *script=[NSString stringWithFormat:@"window.dylixWrite('%@')",[data base64EncodedStringWithOptions:0]];[self.web evaluateJavaScript:script completionHandler:nil];}
- (void)state:(NSNotification *)n{if(self.processID)return;self.status.text=[@"Alpine Linux · " stringByAppendingString:n.userInfo[@"state"]?:@""];}
- (void)keyboard:(NSNotification *)n{CGRect screen=[n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];CGRect frame=[self.view convertRect:screen fromView:nil];CGFloat overlap=MAX(0,CGRectGetMaxY(self.view.bounds)-CGRectGetMinY(frame)-self.view.safeAreaInsets.bottom);self.keyboardVisible=overlap>0;[self.keyboardButton setTitle:self.keyboardVisible?@"收起":@"键盘" forState:UIControlStateNormal];self.keyboardButton.accessibilityLabel=self.keyboardVisible?@"收起键盘":@"显示键盘";self.bottom.constant=-overlap;[UIView animateWithDuration:[n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue] animations:^{[self.view layoutIfNeeded];}];}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message{
 if(!message.frameInfo.mainFrame||!message.frameInfo.request.URL.isFileURL||![message.body isKindOfClass:NSDictionary.class])return;
 NSDictionary *body=message.body;NSString *type=body[@"type"];id value=body[@"value"];
 if([type isEqual:@"ready"]&&[value isKindOfClass:NSDictionary.class]){self.ready=YES;[self display:self.pending];[self.pending setLength:0];__weak typeof(self) weak=self;if(self.processID){[self poll:++self.pollGeneration];}else{BOOL existing=[[TFAIISHRuntime.shared status:self.session][@"terminalRunning"] boolValue];[TFAIISHRuntime.shared openTerminal:self.session columns:[value[@"cols"] intValue] rows:[value[@"rows"] intValue] completion:^(NSError *e){weak.status.text=e.localizedDescription?:(existing?@"已连接现有终端 · 保留原目录与变量":@"已启动会话终端 · 工具全局共用");[weak refreshContext];}];}}
 else if([type isEqual:@"modifiers"]&&[value isKindOfClass:NSDictionary.class])[self updateModifiers:value];
 else if([type isEqual:@"input"]&&[value isKindOfClass:NSString.class])[self input:[value dataUsingEncoding:NSUTF8StringEncoding]];
 else if([type isEqual:@"resize"]&&[value isKindOfClass:NSDictionary.class]){if(self.processID)[TFAIISHRuntime.shared performProcess:@"resize" arguments:@{@"process_id":self.processID,@"columns":value[@"cols"],@"rows":value[@"rows"]} session:self.session completion:^(NSDictionary *r,NSError *e){}];else[TFAIISHRuntime.shared resizeTerminal:self.session columns:[value[@"cols"] intValue] rows:[value[@"rows"] intValue]];}
}
- (void)webView:(WKWebView *)web decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{NSString *root=[[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Terminal"] stringByAppendingString:@"/"];NSURL *url=action.request.URL;decisionHandler(url.isFileURL&&[url.path hasPrefix:root]?WKNavigationActionPolicyAllow:WKNavigationActionPolicyCancel);}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];[self refreshContext];[self.contextTimer invalidate];__weak typeof(self) weak=self;self.contextTimer=[NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer){[weak refreshContext];}];[TFAIISHRuntime.shared prepareSession:self.session completion:^(NSError *error){if(error)self.status.text=error.localizedDescription;}];if(self.processID&&self.ready)[self poll:++self.pollGeneration];}
- (void)viewDidDisappear:(BOOL)animated{[super viewDidDisappear:animated];[self.contextTimer invalidate];self.contextTimer=nil;self.pollGeneration++;}
- (void)input:(NSData *)data{if(!self.processID){[TFAIISHRuntime.shared writeTerminal:self.session data:data];return;}NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(text)[TFAIISHRuntime.shared performProcess:@"write" arguments:@{@"process_id":self.processID,@"input":text} session:self.session completion:^(NSDictionary *r,NSError *e){if(e)self.status.text=e.localizedDescription;}];}
- (void)poll:(NSUInteger)generation{
 if(generation!=self.pollGeneration||!self.view.window)return;__weak typeof(self) weak=self;
 [TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":self.processID,@"offset":@(self.outputOffset),@"max_bytes":@16384,@"wait_seconds":@0.4} session:self.session completion:^(NSDictionary *r,NSError *e){if(!weak||generation!=weak.pollGeneration)return;if(e){weak.status.text=e.localizedDescription;return;}
  if([r[@"missed_bytes"] unsignedLongLongValue])[weak display:[@"\r\n[Dylix] 较早输出已滚出缓冲区，仅显示保留部分。\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  NSData *bytes=[r[@"encoding"] isEqual:@"base64"]?[[NSData alloc]initWithBase64EncodedString:r[@"output"] options:0]:[r[@"output"] dataUsingEncoding:NSUTF8StringEncoding];[weak display:bytes];weak.outputOffset=[r[@"next_offset"] unsignedLongLongValue];weak.status.text=[r[@"running"] boolValue]?@"Alpine Linux · 进程运行中": [NSString stringWithFormat:@"进程已结束 · exit %@",r[@"exit_code"]];
  if([r[@"running"] boolValue]||[r[@"has_more"] boolValue])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[weak poll:generation];});
 }];
}
- (void)refreshContext{__weak typeof(self) weak=self;[TFAIISHRuntime.shared terminalContext:self.session process:self.processID completion:^(NSDictionary *context){if(!weak)return;weak.bindingContext=context;NSString *title=context[@"session_title"];if(!title.length)title=[context[@"local_terminal"] boolValue]?@"设置页本机终端":[@"AI 会话 · " stringByAppendingString:[weak.session substringToIndex:MIN(8,weak.session.length)]];NSString *project=[context[@"project_name"] length]?context[@"project_name"]:@"未关联项目";weak.bindingLabel.text=[NSString stringWithFormat:@"%@ · %@\n%@ · 工具全局共用",title,project,weak.processID?@"命令任务":@"交互终端"];NSString *cwd=context[@"current_directory"];weak.directoryLabel.text=cwd.length?[@"当前目录  " stringByAppendingString:cwd]:[NSString stringWithFormat:@"默认目录  %@%@",context[@"default_directory"],[context[@"running"] boolValue]?@" · 当前目录暂不可读":@" · 未运行"];weak.directoryLabel.accessibilityLabel=weak.directoryLabel.text;}];}
- (void)connectTerminal{
 if(!self.processID){[TFAIISHRuntime.shared openTerminal:self.session columns:80 rows:24 completion:^(NSError *e){self.status.text=e.localizedDescription?:@"已连接会话终端 · 保留原目录与变量";[self refreshContext];}];return;}
 for(UIViewController *controller in self.navigationController.viewControllers)if([controller isKindOfClass:DylixTerminalPage.class]&&![((DylixTerminalPage *)controller).processID length]&&[((DylixTerminalPage *)controller).session isEqual:self.session]){[self.navigationController popToViewController:controller animated:YES];return;}
 [self.navigationController pushViewController:TFAIISHTerminalControllerWithRoot(self.session,self.projectRoot) animated:YES];
}
- (void)bindingInfo{
 NSDictionary *c=self.bindingContext?:@{};NSString *cwd=[c[@"current_directory"] length]?c[@"current_directory"]:@"暂不可读";NSString *detail=[NSString stringWithFormat:@"所属：%@\n会话 ID：%@\n项目：%@\n当前目录：%@\n新命令默认目录：%@\n\n连接会话终端：继续使用原 Shell，保留 cd 和临时变量。\n新建命令任务：启动独立 Shell，不继承原 Shell 的临时状态。\n\n所有会话共用工具和 Linux 文件；关闭页面不会停止终端，App 结束后进程不自动恢复。",c[@"session_title"]?:@"本机会话",self.session,c[@"project_name"]?:@"未关联项目",cwd,c[@"default_directory"]?:@"尚未准备"];
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"绑定与工作目录" message:detail preferredStyle:UIAlertControllerStyleAlert];if([c[@"current_directory"] length])[a addAction:[UIAlertAction actionWithTitle:@"复制当前目录" style:UIAlertActionStyleDefault handler:^(id action){UIPasteboard.generalPasteboard.string=cwd;}]];[a addAction:[UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];
}
- (void)chooseProcess:(BOOL)preview{
 NSArray *rows=[TFAIISHRuntime.shared processes:self.session];UIAlertController *sheet=[UIAlertController alertControllerWithTitle:preview?@"选择网页服务器":@"会话 Linux 进程" message:preview?@"仅列出真实监听本机端口的运行中进程。":@"切换查看不会停止进程；App 重启只保留历史状态。" preferredStyle:UIAlertControllerStyleActionSheet];NSUInteger count=0;
 for(NSDictionary *row in rows){if([row[@"restored_history"] boolValue]){if(!preview){count++;NSString *title=[NSString stringWithFormat:@"%@ · %@",[row[@"process_id"] substringToIndex:MIN(8,[row[@"process_id"] length])],row[@"state"]];[sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){AIAlert(self,@"重启前的进程记录",@"仅保留退出或中断状态。进程未自动重放，命令和输出未写入历史文件。会话 Linux 文件仍保留。" );}]];}continue;}if(preview&&(![row[@"running"] boolValue]||![row[@"ports"] count]))continue;count++;NSString *identifier=row[@"process_id"];NSString *title=[NSString stringWithFormat:@"%@ · %@ · %@%@",[row[@"manual_terminal"] boolValue]?@"交互终端":@"命令任务",[identifier substringToIndex:MIN(8,identifier.length)],row[@"state"],preview?[@" · " stringByAppendingString:[row[@"ports"] description]]:@""];
  [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){if(!preview){[self.navigationController pushViewController:TFAIISHProcessController(self.session,identifier) animated:YES];return;}[TFAIISHRuntime.shared preview:identifier port:0 path:@"/" session:self.session completion:^(NSDictionary *r,NSError *e){if(e)AIAlert(self,@"预览不可用",e.localizedDescription);else[self.navigationController pushViewController:TFAIISHPreviewController(r,self.session) animated:YES];}];}]];
 }
 if(!count){AIAlert(self,preview?@"没有网页服务器":@"没有进程",preview?@"先启动 HTTP 服务（例如 python3 -m http.server 0 --bind 127.0.0.1 --directory /workspace），再打开这里；端口由运行库实际发现。":@"可以新建一个进程，或让 AI 启动。" );return;}
 [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];sheet.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItems.firstObject;[self presentViewController:sheet animated:YES completion:nil];
}
- (void)newProcess:(NSString *)command{
 UIAlertController *prompt=[UIAlertController alertControllerWithTitle:@"新建命令任务" message:@"在共享 Linux 中启动独立 Shell，归属当前会话。从默认工作目录开始，不继承现有终端中的 cd、export 或临时变量；退出 App 后停止。" preferredStyle:UIAlertControllerStyleAlert];[prompt addTextFieldWithConfigurationHandler:^(UITextField *f){f.text=command?:@"/bin/sh -i";f.autocorrectionType=UITextAutocorrectionTypeNo;f.autocapitalizationType=UITextAutocapitalizationTypeNone;}];[prompt addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[prompt addAction:[UIAlertAction actionWithTitle:@"运行" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[TFAIISHRuntime.shared performProcess:@"start" arguments:@{@"command":prompt.textFields.firstObject.text?:@""} session:self.session completion:^(NSDictionary *r,NSError *e){if(e)AIAlert(self,@"进程未启动",e.localizedDescription);else[self.navigationController pushViewController:TFAIISHProcessController(self.session,r[@"process_id"]) animated:YES];}];}]];[self presentViewController:prompt animated:YES completion:nil];
}
- (void)importProjectCopy{UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"导入当前项目源码副本？" message:@"仅复制 UTF-8 源码和配置到新的 Linux 子目录，不覆盖已有文件，不修改项目。最多 24 文件、单文件 256 KiB、共 1 MiB；跳过隐藏目录、构建产物、链接及二进制。含疑似密钥时整批停止。修改后仍须审核写回。" preferredStyle:UIAlertControllerStyleAlert];[confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[confirm addAction:[UIAlertAction actionWithTitle:@"复制源码" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[TFAIISHRuntime.shared importProjectCopy:self.projectRoot session:self.session completion:^(NSDictionary *r,NSError *e){if(e){AIAlert(self,@"未导入",e.localizedDescription);return;}self.status.text=[NSString stringWithFormat:@"已复制 %@ 个文件 · 跳过 %@ 项",r[@"files"],r[@"skipped"]];[self display:[[NSString stringWithFormat:@"\r\n[Dylix] 项目副本：%@\r\n",r[@"path"]] dataUsingEncoding:NSUTF8StringEncoding]];AIAlert(self,@"源码副本已导入",r[@"path"]);}];}]];[self presentViewController:confirm animated:YES completion:nil];}
- (void)menu{
 [self.view endEditing:YES];
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"当前会话终端" message:@"工具全局共用，进程归属当前会话。" preferredStyle:UIAlertControllerStyleActionSheet];
 [sheet addAction:[UIAlertAction actionWithTitle:@"连接会话终端" style:UIAlertActionStyleDefault handler:^(id a){[self connectTerminal];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"新建命令任务" style:UIAlertActionStyleDefault handler:^(id a){[self newProcess:nil];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"绑定与工作目录" style:UIAlertActionStyleDefault handler:^(id a){[self bindingInfo];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"文件" style:UIAlertActionStyleDefault handler:^(id a){[self.navigationController pushViewController:TFAIISHFilesController(self.session,self.projectRoot) animated:YES];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"进程与运行输出" style:UIAlertActionStyleDefault handler:^(id a){[self chooseProcess:NO];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"安装工具" style:UIAlertActionStyleDefault handler:^(id a){[self.navigationController pushViewController:TFAIISHToolsController(self.session) animated:YES];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"更多操作" style:UIAlertActionStyleDefault handler:^(id a){[self moreMenu];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];sheet.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItems.firstObject;[self presentViewController:sheet animated:YES completion:nil];
}
- (void)moreMenu{
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"终端操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
 [sheet addAction:[UIAlertAction actionWithTitle:@"终端设置" style:UIAlertActionStyleDefault handler:^(id a){[self.navigationController pushViewController:TFAIISHSettingsController(self.session,self.projectRoot) animated:YES];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"导入文件" style:UIAlertActionStyleDefault handler:^(id a){UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeItem] asCopy:YES];picker.delegate=self;[self presentViewController:picker animated:YES completion:nil];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"导出文件" style:UIAlertActionStyleDefault handler:^(id a){[self exportFile];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"预览网页" style:UIAlertActionStyleDefault handler:^(id a){[self chooseProcess:YES];}]];
 if(self.projectRoot.length)[sheet addAction:[UIAlertAction actionWithTitle:@"导入当前项目源码副本" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self importProjectCopy];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:[TFAIISHRemote allowed:self.session]?@"撤销局域网终端授权":@"局域网终端授权" style:UIAlertActionStyleDefault handler:^(id a){if([TFAIISHRemote allowed:self.session]){[TFAIISHRemote setAllowed:NO session:self.session];AIAlert(self,@"已撤销",@"该会话的远程终端进程已请求停止。");return;}UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"允许已配对设备访问本会话 Linux？" message:@"仅本机/局域网工作区设备，可启动、输入及读取它创建的 Linux 进程；不能访问其他会话或宿主 Shell。HTTP 传输为明文，私密内容请启用现有 TLS。重启清除授权，可随时撤销；远端仍需确认控制操作。" preferredStyle:UIAlertControllerStyleAlert];[confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[confirm addAction:[UIAlertAction actionWithTitle:@"授权本会话" style:UIAlertActionStyleDefault handler:^(id a){[TFAIISHRemote setAllowed:YES session:self.session];}]];[self presentViewController:confirm animated:YES completion:nil];}]];
 if(self.processID)[sheet addAction:[UIAlertAction actionWithTitle:@"停止当前进程" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){[TFAIISHRuntime.shared performProcess:@"stop" arguments:@{@"process_id":self.processID} session:self.session completion:^(NSDictionary *r,NSError *e){self.status.text=e.localizedDescription?:@"进程已停止";}];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"清空屏幕" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self.web evaluateJavaScript:@"window.dylixClear()" completionHandler:nil];}]];
 if(!self.processID)[sheet addAction:[UIAlertAction actionWithTitle:@"重开 shell（文件保留）" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){[TFAIISHRuntime.shared closeTerminal:self.session];[TFAIISHRuntime.shared openTerminal:self.session columns:80 rows:24 completion:^(NSError *e){if(e)AIAlert(self,@"终端未启动",e.localizedDescription);}];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];sheet.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItems.firstObject;[self presentViewController:sheet animated:YES completion:nil];
}
- (void)exportFile{
 UIAlertController *prompt=[UIAlertController alertControllerWithTitle:@"导出沙盒文件" message:@"输入 Linux 中普通文件的绝对路径。保存副本后可直接分享，不修改原文件。" preferredStyle:UIAlertControllerStyleAlert];
 [prompt addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"/workspace/result.txt";field.autocorrectionType=UITextAutocorrectionTypeNo;field.autocapitalizationType=UITextAutocapitalizationTypeNone;}];
 [prompt addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
 [prompt addAction:[UIAlertAction actionWithTitle:@"导出" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){self.status.text=@"正在导出 Linux 文件";[TFAIISHRuntime.shared exportFile:prompt.textFields.firstObject.text session:self.session completion:^(NSDictionary *result,NSError *error){
  NSURL *url=result?TFAIISHExportURL(result,self.session):nil;if(!url){AIAlert(self,@"导出未完成",error.localizedDescription?:@"导出文件已丢失");return;}
  self.status.text=[@"已保存副本：" stringByAppendingString:result[@"name"]];UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[url] applicationActivities:nil];share.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItems.firstObject;[self presentViewController:share animated:YES completion:nil];
 }];}]];[self presentViewController:prompt animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{NSURL *url=urls.firstObject;if(!url)return;BOOL scope=[url startAccessingSecurityScopedResource];self.status.text=@"正在复制文件到 Linux";[TFAIISHRuntime.shared importFile:url name:url.lastPathComponent session:self.session completion:^(NSDictionary *r,NSError *e){if(scope)[url stopAccessingSecurityScopedResource];self.status.text=e.localizedDescription?:[@"已导入：" stringByAppendingString:r[@"path"]];if(r){NSString *line=[NSString stringWithFormat:@"\r\n[Dylix] 文件副本: %@\r\n",r[@"path"]];[self display:[line dataUsingEncoding:NSUTF8StringEncoding]];}}];}
@end
UIViewController *TFAIISHProcessController(NSString *sessionID,NSString *processID){DylixTerminalPage *page=[DylixTerminalPage new];page.session=sessionID;page.processID=processID;return page;}
UIViewController *TFAIISHTerminalController(NSString *sessionID){DylixTerminalPage *p=[DylixTerminalPage new];p.session=sessionID.length?sessionID:@"local-terminal";return p;}

UIViewController *TFAIISHTerminalControllerWithRoot(NSString *sessionID,NSString *root){DylixTerminalPage *p=(id)TFAIISHTerminalController(sessionID);p.projectRoot=root;return p;}

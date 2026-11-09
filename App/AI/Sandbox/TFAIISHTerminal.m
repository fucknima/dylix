#import "TFAIISHPreview.h"
#import "TFAIISHFiles.h"
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
@property UILabel *status;
@property NSLayoutConstraint *bottom;
@property BOOL ready;
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
 [super viewDidLoad];self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.title=self.processID?[NSString stringWithFormat:@"Linux 进程 · %@",[self.processID substringToIndex:MIN(8,self.processID.length)]]:@"Linux 终端";self.view.backgroundColor=[UIColor colorWithRed:16/255.0 green:20/255.0 blue:28/255.0 alpha:1];self.pending=[NSMutableData new];
 UINavigationBarAppearance *bar=[UINavigationBarAppearance new];[bar configureWithOpaqueBackground];bar.backgroundColor=self.view.backgroundColor;bar.titleTextAttributes=@{NSForegroundColorAttributeName:UIColor.whiteColor};self.navigationItem.standardAppearance=bar;self.navigationItem.scrollEdgeAppearance=bar;self.navigationItem.compactAppearance=bar;
 self.navigationItem.rightBarButtonItems=@[AIBar(@"ellipsis.circle",@"终端操作",self,@selector(menu))];
 self.status=[UILabel new];self.status.text=@"Alpine Linux · 正在准备";self.status.textColor=UIColor.secondaryLabelColor;self.status.font=[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];self.status.adjustsFontForContentSizeCategory=YES;self.status.numberOfLines=2;
 WKWebViewConfiguration *configuration=[WKWebViewConfiguration new];configuration.websiteDataStore=WKWebsiteDataStore.nonPersistentDataStore;DylixTerminalMessages *handler=[DylixTerminalMessages new];handler.owner=self;[configuration.userContentController addScriptMessageHandler:handler name:@"dylixTerminal"];
 self.web=[[WKWebView alloc]initWithFrame:CGRectZero configuration:configuration];self.web.navigationDelegate=self;self.web.opaque=NO;self.web.backgroundColor=self.view.backgroundColor;self.web.scrollView.scrollEnabled=NO;
 UIStackView *keys=[[UIStackView alloc]init];keys.axis=UILayoutConstraintAxisHorizontal;keys.distribution=UIStackViewDistributionFillEqually;keys.spacing=2;
 NSArray *labels=@[@"Esc",@"Tab",@"Ctrl-C",@"↑",@"↓",@"键盘"];
 NSArray *values=@[@"\033",@"\t",@"\003",@"\033[A",@"\033[B",@""];
 for(NSUInteger i=0;i<labels.count;i++){UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:labels[i] forState:UIControlStateNormal];button.titleLabel.font=[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];button.accessibilityLabel=labels[i];NSString *value=values[i];__weak typeof(self) weak=self;[button addAction:[UIAction actionWithHandler:^(UIAction *a){if(value.length)[weak input:[value dataUsingEncoding:NSUTF8StringEncoding]];else[weak.web evaluateJavaScript:@"window.dylixFocus()" completionHandler:nil];}] forControlEvents:UIControlEventTouchUpInside];[keys addArrangedSubview:button];}
 for(UIView *v in @[self.status,self.web,keys]){v.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:v];}
 UILayoutGuide *safe=self.view.safeAreaLayoutGuide;self.bottom=[keys.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor];
 [NSLayoutConstraint activateConstraints:@[[self.status.topAnchor constraintEqualToAnchor:safe.topAnchor constant:6],[self.status.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],[self.status.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],[self.status.heightAnchor constraintGreaterThanOrEqualToConstant:26],[self.web.topAnchor constraintEqualToAnchor:self.status.bottomAnchor constant:4],[self.web.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],[self.web.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],[self.web.bottomAnchor constraintEqualToAnchor:keys.topAnchor],[keys.heightAnchor constraintEqualToConstant:44],[keys.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],[keys.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],self.bottom]];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(bytes:) name:TFAIISHTerminalOutput object:self.session];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(state:) name:TFAIISHStatusChanged object:self.session];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
 NSURL *url=[NSBundle.mainBundle URLForResource:@"index" withExtension:@"html" subdirectory:@"Terminal"];
 if(![TFAIISHRuntime available]||!url){self.status.text=@"当前构建没有可用的内嵌 Linux 环境";return;}
 if(!self.processID)[self.pending appendData:[TFAIISHRuntime.shared terminalReplay:self.session]];
 [self.web loadFileURL:url allowingReadAccessToURL:url.URLByDeletingLastPathComponent];
}
- (UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[self.web.configuration.userContentController removeScriptMessageHandlerForName:@"dylixTerminal"];}
- (void)bytes:(NSNotification *)n{if(self.processID)return;NSData *data=n.userInfo[@"data"];if(self.ready)[self display:data];else{[self.pending appendData:data];if(self.pending.length>256*1024)[self.pending replaceBytesInRange:NSMakeRange(0,self.pending.length-256*1024) withBytes:NULL length:0];}}
- (void)display:(NSData *)data{if(!data.length)return;NSString *script=[NSString stringWithFormat:@"window.dylixWrite('%@')",[data base64EncodedStringWithOptions:0]];[self.web evaluateJavaScript:script completionHandler:nil];}
- (void)state:(NSNotification *)n{if(self.processID)return;self.status.text=[@"Alpine Linux · " stringByAppendingString:n.userInfo[@"state"]?:@""];}
- (void)keyboard:(NSNotification *)n{CGRect screen=[n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];CGRect frame=[self.view convertRect:screen fromView:nil];CGFloat overlap=MAX(0,CGRectGetMaxY(self.view.bounds)-CGRectGetMinY(frame)-self.view.safeAreaInsets.bottom);self.bottom.constant=-overlap;[UIView animateWithDuration:[n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue] animations:^{[self.view layoutIfNeeded];}];}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message{
 if(!message.frameInfo.mainFrame||!message.frameInfo.request.URL.isFileURL||![message.body isKindOfClass:NSDictionary.class])return;
 NSDictionary *body=message.body;NSString *type=body[@"type"];id value=body[@"value"];
 if([type isEqual:@"ready"]&&[value isKindOfClass:NSDictionary.class]){self.ready=YES;[self display:self.pending];[self.pending setLength:0];__weak typeof(self) weak=self;if(self.processID){[self poll:++self.pollGeneration];}else[TFAIISHRuntime.shared openTerminal:self.session columns:[value[@"cols"] intValue] rows:[value[@"rows"] intValue] completion:^(NSError *e){weak.status.text=e.localizedDescription?:@"Alpine Linux · 会话终端运行中";}];}
 else if([type isEqual:@"input"]&&[value isKindOfClass:NSString.class])[self input:[value dataUsingEncoding:NSUTF8StringEncoding]];
 else if([type isEqual:@"resize"]&&[value isKindOfClass:NSDictionary.class]){if(self.processID)[TFAIISHRuntime.shared performProcess:@"resize" arguments:@{@"process_id":self.processID,@"columns":value[@"cols"],@"rows":value[@"rows"]} session:self.session completion:^(NSDictionary *r,NSError *e){}];else[TFAIISHRuntime.shared resizeTerminal:self.session columns:[value[@"cols"] intValue] rows:[value[@"rows"] intValue]];}
}
- (void)webView:(WKWebView *)web decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{NSString *root=[[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Terminal"] stringByAppendingString:@"/"];NSURL *url=action.request.URL;decisionHandler(url.isFileURL&&[url.path hasPrefix:root]?WKNavigationActionPolicyAllow:WKNavigationActionPolicyCancel);}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];if(self.processID&&self.ready)[self poll:++self.pollGeneration];}
- (void)viewDidDisappear:(BOOL)animated{[super viewDidDisappear:animated];self.pollGeneration++;}
- (void)input:(NSData *)data{if(!self.processID){[TFAIISHRuntime.shared writeTerminal:self.session data:data];return;}NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(text)[TFAIISHRuntime.shared performProcess:@"write" arguments:@{@"process_id":self.processID,@"input":text} session:self.session completion:^(NSDictionary *r,NSError *e){if(e)self.status.text=e.localizedDescription;}];}
- (void)poll:(NSUInteger)generation{
 if(generation!=self.pollGeneration||!self.view.window)return;__weak typeof(self) weak=self;
 [TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":self.processID,@"offset":@(self.outputOffset),@"max_bytes":@16384,@"wait_seconds":@0.4} session:self.session completion:^(NSDictionary *r,NSError *e){if(!weak||generation!=weak.pollGeneration)return;if(e){weak.status.text=e.localizedDescription;return;}
  if([r[@"missed_bytes"] unsignedLongLongValue])[weak display:[@"\r\n[Dylix] 较早输出已滚出缓冲区，仅显示保留部分。\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  NSData *bytes=[r[@"encoding"] isEqual:@"base64"]?[[NSData alloc]initWithBase64EncodedString:r[@"output"] options:0]:[r[@"output"] dataUsingEncoding:NSUTF8StringEncoding];[weak display:bytes];weak.outputOffset=[r[@"next_offset"] unsignedLongLongValue];weak.status.text=[r[@"running"] boolValue]?@"Alpine Linux · 进程运行中": [NSString stringWithFormat:@"进程已结束 · exit %@",r[@"exit_code"]];
  if([r[@"running"] boolValue]||[r[@"has_more"] boolValue])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[weak poll:generation];});
 }];
}
- (void)chooseProcess:(BOOL)preview{
 NSArray *rows=[TFAIISHRuntime.shared processes:self.session];UIAlertController *sheet=[UIAlertController alertControllerWithTitle:preview?@"选择网页服务器":@"会话 Linux 进程" message:preview?@"仅列出真实监听本机端口的运行中进程。":@"切换查看不会停止进程；App 重启只保留历史状态。" preferredStyle:UIAlertControllerStyleActionSheet];NSUInteger count=0;
 for(NSDictionary *row in rows){if([row[@"restored_history"] boolValue]){if(!preview){count++;NSString *title=[NSString stringWithFormat:@"%@ · %@",[row[@"process_id"] substringToIndex:MIN(8,[row[@"process_id"] length])],row[@"state"]];[sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){AIAlert(self,@"重启前的进程记录",@"仅保留退出或中断状态。进程未自动重放，命令和输出未写入历史文件。会话 Linux 文件仍保留。" );}]];}continue;}if(preview&&(![row[@"running"] boolValue]||![row[@"ports"] count]))continue;count++;NSString *identifier=row[@"process_id"];NSString *title=[NSString stringWithFormat:@"%@ · %@%@",[identifier substringToIndex:MIN(8,identifier.length)],row[@"state"],preview?[@" · " stringByAppendingString:[row[@"ports"] description]]:@""];
  [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){if(!preview){[self.navigationController pushViewController:TFAIISHProcessController(self.session,identifier) animated:YES];return;}[TFAIISHRuntime.shared preview:identifier port:0 path:@"/" session:self.session completion:^(NSDictionary *r,NSError *e){if(e)AIAlert(self,@"预览不可用",e.localizedDescription);else[self.navigationController pushViewController:TFAIISHPreviewController(r,self.session) animated:YES];}];}]];
 }
 if(!count){AIAlert(self,preview?@"没有网页服务器":@"没有进程",preview?@"先启动 HTTP 服务（例如 python3 -m http.server 0 --bind 127.0.0.1 --directory /workspace），再打开这里；端口由运行库实际发现。":@"可以新建一个进程，或让 AI 启动。" );return;}
 [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];sheet.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItems.firstObject;[self presentViewController:sheet animated:YES completion:nil];
}
- (void)newProcess:(NSString *)command{
 UIAlertController *prompt=[UIAlertController alertControllerWithTitle:@"新建 Linux 进程" message:@"在当前会话的 Alpine 中运行；返回聊天后继续，App 被系统结束时停止。" preferredStyle:UIAlertControllerStyleAlert];[prompt addTextFieldWithConfigurationHandler:^(UITextField *f){f.text=command?:@"/bin/sh -i";f.autocorrectionType=UITextAutocorrectionTypeNo;f.autocapitalizationType=UITextAutocapitalizationTypeNone;}];[prompt addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[prompt addAction:[UIAlertAction actionWithTitle:@"运行" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[TFAIISHRuntime.shared performProcess:@"start" arguments:@{@"command":prompt.textFields.firstObject.text?:@""} session:self.session completion:^(NSDictionary *r,NSError *e){if(e)AIAlert(self,@"进程未启动",e.localizedDescription);else[self.navigationController pushViewController:TFAIISHProcessController(self.session,r[@"process_id"]) animated:YES];}];}]];[self presentViewController:prompt animated:YES completion:nil];
}
- (void)menu{
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"会话 Linux 终端" message:@"文件保存在本机沙盒；返回聊天不会关闭 shell。iOS 后台执行仍受系统调度限制。" preferredStyle:UIAlertControllerStyleActionSheet];
 [sheet addAction:[UIAlertAction actionWithTitle:@"会话进程 / AI 运行输出" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self chooseProcess:NO];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"新建交互进程" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self newProcess:nil];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"预览本地网页" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self chooseProcess:YES];}]];
 if([TFAIISHRuntime reverseToolsAvailable])[sheet addAction:[UIAlertAction actionWithTitle:@"安装 Ghidra / radare2 逆向工具" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"安装离线逆向工具" message:@"使用 Alpine 官方签名的 ARM64 radare2 与 Ghidra 引擎，安装到独立分析目录，不升级基础系统。分析只针对导入副本。" preferredStyle:UIAlertControllerStyleAlert];[confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[confirm addAction:[UIAlertAction actionWithTitle:@"确认安装" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[TFAIISHRuntime.shared installReverseTools:self.session completion:^(NSDictionary *r,NSError *e){if(e)AIAlert(self,@"安装未开始",e.localizedDescription);else[self.navigationController pushViewController:TFAIISHProcessController(self.session,r[@"process_id"]) animated:YES];}];}]];[self presentViewController:confirm animated:YES completion:nil];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"安装 Python / Node / 开发工具" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"安装离线开发工具" message:@"在本会话 Linux 安装官方签名的 Python、Node/npm、Git、curl 和分析工具，不改项目。可在进程页面查看安装进度。" preferredStyle:UIAlertControllerStyleAlert];[confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[confirm addAction:[UIAlertAction actionWithTitle:@"安装" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){self.status.text=@"正在校验离线工具包";[TFAIISHRuntime.shared installDeveloperTools:self.session completion:^(NSDictionary *r,NSError *e){if(e)AIAlert(self,@"安装未开始",e.localizedDescription);else[self.navigationController pushViewController:TFAIISHProcessController(self.session,r[@"process_id"]) animated:YES];}];}]];[self presentViewController:confirm animated:YES completion:nil]; }]];
 if(self.processID)[sheet addAction:[UIAlertAction actionWithTitle:@"停止当前进程" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){[TFAIISHRuntime.shared performProcess:@"stop" arguments:@{@"process_id":self.processID} session:self.session completion:^(NSDictionary *r,NSError *e){self.status.text=e.localizedDescription?:@"进程已停止";}];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"Linux 文件管理" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self.navigationController pushViewController:TFAIISHFilesController(self.session,self.projectRoot) animated:YES];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"导入文件副本" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeItem] asCopy:YES];picker.delegate=self;picker.allowsMultipleSelection=NO;[self presentViewController:picker animated:YES completion:nil];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"导出 / 分享沙盒文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self exportFile];}]];
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

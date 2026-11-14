#import "TFAIDirectoryRegistry.h"
#import "TFAIDirectoryPickerDiagnostics.h"
#import "TFAIAttachmentStore.h"
#import "../UI/TFAIUIHelpers.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>
static char FolderDelegateLifetime;
@interface TFAIDirectoryPage : UITableViewController <UIDocumentPickerDelegate>
@property NSString *session,*relative;
@property(copy) void(^attachmentSelection)(NSDictionary *,NSString *);
@property NSDictionary *entry;
@property NSArray *rows;
@property BOOL busy,authorizing;
@property BOOL signingEntryChecked,checkingSigning;
@property(strong) UIDocumentPickerViewController *folderPicker;
@property(strong) UIWindow *pickerWindow;
@property(weak) UIWindow *previousKeyWindow;
@property NSError *pendingError;
@property NSString *authorizationMessage;
@property NSUInteger generation,errorAttempts;
@end
@implementation TFAIDirectoryPage
- (void)viewDidLoad{[super viewDidLoad];
 // Remove only the temporary diagnostics produced during folder-picker triage.
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  NSString *root=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"DylixDiagnostics"];
  for(NSString *name in @[@"FolderPicker",@"file-ui.log"])[NSFileManager.defaultManager removeItemAtPath:[root stringByAppendingPathComponent:name] error:nil];
 });
self.title=self.entry?(self.relative.length?self.relative.lastPathComponent:self.entry[@"path"]):@"挂载文件夹";self.tableView.accessibilityIdentifier=@"authorized-directories";self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=60;if(!self.entry){
 __weak typeof(self) weakSelf=self;UIBarButtonItem *more=[[UIBarButtonItem alloc]initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:[UIMenu menuWithTitle:@"文件夹授权" children:@[
 [UIAction actionWithTitle:@"独立窗口选择文件夹" image:[UIImage systemImageNamed:@"checkmark.circle"] identifier:nil handler:^(UIAction *a){[weakSelf chooseFolderCompatible:YES];}],
 [UIAction actionWithTitle:@"授权诊断" image:[UIImage systemImageNamed:@"doc.text.magnifyingglass"] identifier:nil handler:^(UIAction *a){[weakSelf showFolderDiagnostics];}]]]];
 more.accessibilityLabel=@"文件夹授权选项";self.navigationItem.rightBarButtonItems=@[AIBar(@"plus",@"添加文件夹",self,@selector(addFolder)),more];}
 if(self.attachmentSelection){
  if(!self.entry){self.title=@"从挂载文件夹选择";self.navigationItem.leftBarButtonItem=AIBar(@"xmark",@"取消选择",self,@selector(cancelAttachmentSelection));}
  else if(!self.relative.length)self.navigationItem.rightBarButtonItem=AIBar(@"checkmark",@"附加整个挂载目录",self,@selector(selectMountedDirectory));
 }
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self reload];}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];[self presentPendingError];if(!self.entry&&!self.signingEntryChecked){self.signingEntryChecked=YES;[self checkSigningForFolderWithCompletion:nil];}UIDocumentPickerViewController *picker=self.folderPicker;if(picker)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.folderPicker==picker&&!self.authorizing&&!picker.presentingViewController&&!picker.view.window){self.folderPicker=nil;objc_setAssociatedObject(picker,&FolderDelegateLifetime,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);NSError *e=[NSError errorWithDomain:@"Dylix.DirectoryPicker" code:2 userInfo:@{NSLocalizedDescriptionKey:@"系统选择器已关闭，但未返回文件夹。请从右上角“…”尝试独立窗口选择；若仍失败，请查看授权诊断。"}];[self showError:e];}});}
- (void)checkSigningForFolderWithCompletion:(void(^)(void))completion{
 if(self.checkingSigning||self.authorizing||self.folderPicker||self.presentedViewController||!self.view.window)return;
 self.checkingSigning=YES;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSDictionary *checks=TFAIDirectoryPickerDiagnostics();
  NSString *warning=TFAIDirectorySigningWarning(checks);
  NSString *copyID=checks[@"suggestedBundleIdentifier"];
  dispatch_async(dispatch_get_main_queue(),^{
   self.checkingSigning=NO;
   if(!self.view.window||self.presentedViewController||self.folderPicker||self.authorizing)return;
   if(!warning.length){if(completion)completion();return;}
   UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"签名应用标识不一致" message:warning preferredStyle:UIAlertControllerStyleAlert];
   alert.view.accessibilityIdentifier=@"folder-signing-mismatch";
   if(copyID.length)[alert addAction:[UIAlertAction actionWithTitle:@"复制描述文件 Bundle ID" style:UIAlertActionStyleDefault handler:^(id action){UIPasteboard.generalPasteboard.string=copyID;}]];
   [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
   if(completion)[alert addAction:[UIAlertAction actionWithTitle:@"仍然选择" style:UIAlertActionStyleDefault handler:^(id action){
    [alert dismissViewControllerAnimated:YES completion:completion];
   }]];
   [self presentViewController:alert animated:YES completion:nil];
  });
 });
}
- (void)cancelAttachmentSelection{[self dismissViewControllerAnimated:YES completion:nil];}
- (void)finishAttachmentSelection:(NSString *)relative{
 if(self.busy||!self.attachmentSelection||!self.entry)return;
 void(^selection)(NSDictionary *,NSString *)=self.attachmentSelection;NSDictionary *entry=self.entry;
 [self dismissViewControllerAnimated:YES completion:^{selection(entry,relative);}];
}
- (void)selectMountedDirectory{[self finishAttachmentSelection:nil];}
- (void)showFolderDiagnostics{
 if(self.presentedViewController)return;
 BOOL choosing=self.folderPicker!=nil,saving=self.authorizing;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSData *data=[NSJSONSerialization dataWithJSONObject:TFAIDirectoryPickerDiagnostics() options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
  NSString *identity=data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:@"无法读取标识关系";
  NSString *text=[NSString stringWithFormat:@"Dylix %@ (%@)\n系统：%@\n正在选择：%@\n正在保存授权：%@\n仅核对当前应用签名标识，不采集或保存授权日志。\n\n%@",NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"",NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]?:@"",NSProcessInfo.processInfo.operatingSystemVersionString,choosing?@"是":@"否",saving?@"是":@"否",identity];
  dispatch_async(dispatch_get_main_queue(),^{
   if(!self.view.window||self.presentedViewController)return;
   UIAlertController *a=[UIAlertController alertControllerWithTitle:@"文件夹授权诊断" message:text preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];[a addAction:[UIAlertAction actionWithTitle:@"复制诊断" style:UIAlertActionStyleDefault handler:^(id x){UIPasteboard.generalPasteboard.string=text;}]];[self presentViewController:a animated:YES completion:nil];
  });
 });
}
- (void)presentPendingError{
 if(!self.pendingError||!self.view.window)return;
 if(self.presentedViewController||self.navigationController.presentedViewController||self.transitionCoordinator||self.navigationController.transitionCoordinator){if(self.errorAttempts++<60)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self presentPendingError];});return;}
 NSError *error=self.pendingError;self.pendingError=nil;AIAlert(self,@"文件夹授权未完成",error.localizedDescription);
}
- (void)showError:(NSError *)error{if(!error)return;dispatch_async(dispatch_get_main_queue(),^{self.pendingError=error;self.errorAttempts=0;self.authorizationMessage=error.localizedDescription;[self.tableView reloadData];[self presentPendingError];});}
- (void)updateAuthorizationUI{self.navigationItem.rightBarButtonItem.enabled=!self.authorizing;if(self.authorizing){UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];[spinner startAnimating];self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithCustomView:spinner];}else self.navigationItem.leftBarButtonItem=self.attachmentSelection&&!self.entry?AIBar(@"xmark",@"取消选择",self,@selector(cancelAttachmentSelection)):nil;[self.tableView reloadData];}
- (void)reload{
 self.busy=YES;NSUInteger generation=++self.generation;NSDictionary *entry=self.entry;NSString *relative=self.relative?:@"";
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *error=nil;NSDictionary *result=entry?TFAIReadDirectoryReference(entry,@{@"action":@"list",@"path":relative},&error):nil;NSMutableArray *rows=[(entry?result[@"items"]:TFAIDirectoryRegistry.entries) mutableCopy]?:[NSMutableArray new];if(result[@"next_offset"]&&result[@"next_offset"]!=NSNull.null)[rows addObject:@{@"kind":@"more",@"offset":result[@"next_offset"]}];dispatch_async(dispatch_get_main_queue(),^{if(generation!=self.generation)return;self.busy=NO;self.rows=rows;[self.tableView reloadData];UILabel *empty=[UILabel new];empty.numberOfLines=0;empty.textAlignment=NSTextAlignmentCenter;empty.textColor=UIColor.secondaryLabelColor;empty.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];empty.text=error?error.localizedDescription:self.entry?@"文件夹为空":@"尚未挂载文件夹\n点右上角 + 从“文件”中选择";self.tableView.backgroundView=rows.count?nil:empty;[self showError:error];});});
}
- (void)addFolder{
 [self chooseFolderCompatible:NO];
}
- (void)chooseFolderCompatible:(BOOL)compatible{
 [self checkSigningForFolderWithCompletion:^{[self presentFolderPickerCompatible:compatible];}];
}
- (void)presentFolderPickerCompatible:(BOOL)compatible{
 if(self.authorizing||self.folderPicker||self.presentedViewController||!self.view.window){return;}[self.view endEditing:YES];
 // Keep identical folder/in-place semantics in both modes. The alternate
 // changes only the presenting window, to isolate app view/gesture interaction.
 UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];picker.delegate=self;picker.allowsMultipleSelection=NO;picker.modalPresentationStyle=UIModalPresentationFullScreen;self.folderPicker=picker;objc_setAssociatedObject(picker,&FolderDelegateLifetime,self,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 
 self.authorizationMessage=compatible?@"独立窗口模式：进入目标文件夹，再点系统“打开”。此方式仍访问原目录。":@"若系统点“打开”无反应，请取消后从右上角“…”尝试独立窗口选择或查看授权诊断。";[self.tableView reloadData];
 if(compatible){
  UIWindow *previous=self.view.window;self.previousKeyWindow=previous;
  UIWindow *window=previous.windowScene?[[UIWindow alloc]initWithWindowScene:previous.windowScene]:[[UIWindow alloc]initWithFrame:previous.bounds];
  window.frame=previous.bounds;window.windowLevel=previous.windowLevel+1;window.tintColor=previous.tintColor;
  UIViewController *host=[UIViewController new];host.view.backgroundColor=UIColor.systemBackgroundColor;window.rootViewController=host;self.pickerWindow=window;
  [window makeKeyAndVisible];
  dispatch_async(dispatch_get_main_queue(),^{if(self.folderPicker==picker)[host presentViewController:picker animated:YES completion:^{}];});
 }else [self presentViewController:picker animated:YES completion:^{}];
}
// Saving the selected URL must never depend on UIKit's sheet transition callback.
// Files starts dismissing itself before the delegate fires on some iOS versions.
- (void)afterPickerDismisses:(UIDocumentPickerViewController *)picker completion:(void(^)(void))completion{
 UIWindow *window=self.pickerWindow,*previous=self.previousKeyWindow;__block BOOL done=NO;
 void(^finish)(void)=^{
  if(done)return;done=YES;
  if(window&&self.pickerWindow==window){window.hidden=YES;window.rootViewController=nil;self.pickerWindow=nil;self.previousKeyWindow=nil;if(previous&&!previous.hidden)[previous makeKeyWindow];}
  completion();
 };
 if(picker.presentingViewController&&!picker.isBeingDismissed)[picker dismissViewControllerAnimated:YES completion:finish];
 else dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),finish);
 // URL registration is already running independently; a missing UIKit
 // transition completion must not keep an extra key window alive indefinitely.
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),finish);
}
- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{
 if(self.authorizing||picker!=self.folderPicker){return;}NSURL *url=urls.firstObject;
 if(!url){[self documentPickerWasCancelled:picker];return;}
 if(urls.count!=1){[self afterPickerDismisses:picker completion:^{self.folderPicker=nil;objc_setAssociatedObject(picker,&FolderDelegateLifetime,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[self showError:[NSError errorWithDomain:@"Dylix.DirectoryPicker" code:3 userInfo:@{NSLocalizedDescriptionKey:@"请一次只勾选一个文件夹，然后点确认。"}]];}];return;}
 self.authorizing=YES;self.authorizationMessage=@"正在保存文件夹授权…";[self updateAuthorizationUI];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(self.authorizing){self.authorizationMessage=@"正在等待系统文件提供方返回授权。可从右上角“…”查看授权诊断；云端文件夹请先确认已下载到本机。";[self.tableView reloadData];}});
 // Keep the selected URL and picker alive in this worker. Start immediately;
 // neither a missing transition completion nor a slow provider may trap Files.
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
 BOOL scoped=[url startAccessingSecurityScopedResource];NSError *error=nil;
 NSDictionary *entry=[TFAIDirectoryRegistry add:url error:&error];
 if(scoped)[url stopAccessingSecurityScopedResource];
 if(!entry&&!error)error=[NSError errorWithDomain:@"Dylix.DirectoryPicker" code:1 userInfo:@{NSLocalizedDescriptionKey:@"无法保存文件夹授权，请确认文件提供方已下载该文件夹后重试。"}];
 dispatch_async(dispatch_get_main_queue(),^{self.authorizing=NO;self.authorizationMessage=entry?[@"已挂载：" stringByAppendingString:entry[@"path"]?:@"文件夹"]:error.localizedDescription;[self updateAuthorizationUI];[self reload];if(error)[self showError:error];});
 });
 [self afterPickerDismisses:picker completion:^{if(self.folderPicker==picker)self.folderPicker=nil;objc_setAssociatedObject(picker,&FolderDelegateLifetime,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}];
}
- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentAtURL:(NSURL *)url{[self documentPicker:picker didPickDocumentsAtURLs:url?@[url]:@[]];}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)picker{if(self.authorizing||picker!=self.folderPicker)return;[self afterPickerDismisses:picker completion:^{self.folderPicker=nil;objc_setAssociatedObject(picker,&FolderDelegateLifetime,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);self.authorizationMessage=@"已取消选择文件夹";[self updateAuthorizationUI];}];}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return self.rows.count;}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{if(self.attachmentSelection)return self.entry?@"点击文件添加到当前会话；在挂载根目录点 ✅ 可附加整个目录引用。单文件在本机导入，整目录不批量上传。":@"选择已挂载的文件夹，再选择其中的文件。也可点 + 新增授权目录。失效的目录需重新授权。";NSString *guidance=self.entry?@"浏览原目录实时内容。AI 可按需读取；文件可复制到 Linux 使用，原目录不会被覆盖。":@"从系统“文件”授权文件夹，供所有会话按需读取。授权会保存；外部目录迁移到其他设备后需重新授权。当前采用只读挂载。\n\n证书签名安装：请确保软件的 Bundle ID 与描述文件允许的应用标识匹配（不含前面的 App ID 前缀）。固定标识的描述文件需使用对应 Bundle ID；通配描述文件只需符合授权范围。标识不一致可能导致点“打开”无反应。更改前请备份项目和会话。";return !self.entry&&self.authorizationMessage.length?[NSString stringWithFormat:@"%@\n\n%@",self.authorizationMessage,guidance]:guidance;}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{NSDictionary *row=self.rows[i.row];BOOL more=[row[@"kind"] isEqual:@"more"];NSString *detail=self.entry?row[@"kind"]:([row[@"available"] boolValue]?[NSString stringWithFormat:@"可用 · /mounts/%@",row[@"directoryGrant"]]:@"授权失效，左滑移除后重新添加");UITableViewCell *cell=AICell(more?@"加载更多":[row[@"path"] lastPathComponent],detail,@"folder");cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;}
- (void)openPage:(UIViewController *)page{if(self.navigationController)[self.navigationController pushViewController:page animated:YES];else[self presentViewController:[[UINavigationController alloc]initWithRootViewController:page] animated:YES completion:nil];}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{
 [t deselectRowAtIndexPath:i animated:YES];if(self.busy)return;NSDictionary *row=self.rows[i.row];
 if([row[@"kind"] isEqual:@"more"]){self.busy=YES;dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *error=nil;NSDictionary *r=TFAIReadDirectoryReference(self.entry,@{@"action":@"list",@"path":self.relative?:@"",@"offset":row[@"offset"]},&error);dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;if(!r){[self showError:error];return;}NSMutableArray *next=[self.rows mutableCopy];[next removeLastObject];[next addObjectsFromArray:r[@"items"]];if(r[@"next_offset"]&&r[@"next_offset"]!=NSNull.null)[next addObject:@{@"kind":@"more",@"offset":r[@"next_offset"]}];self.rows=next;[t reloadData];});});return;}
 if(!self.entry||[row[@"kind"] isEqual:@"directory"]){TFAIDirectoryPage *page=[[TFAIDirectoryPage alloc]initWithStyle:UITableViewStyleInsetGrouped];page.session=self.session;page.entry=self.entry?:row;page.attachmentSelection=self.attachmentSelection;page.relative=self.entry?row[@"path"]:@"";[self openPage:page];return;}
 if(self.attachmentSelection){[self finishAttachmentSelection:row[@"path"]];return;}
 UIAlertController *confirm=[UIAlertController alertControllerWithTitle:row[@"path"] message:@"复制文件到当前会话的 Linux，供工具分析。" preferredStyle:UIAlertControllerStyleAlert];[confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[confirm addAction:[UIAlertAction actionWithTitle:@"复制到 Linux" style:UIAlertActionStyleDefault handler:^(id a){self.busy=YES;TFAIStageSandboxAttachment(self.entry,row[@"path"],^(NSURL *url,NSError *error){if(!url){self.busy=NO;[self showError:error];return;}extern void DXImportDirectoryFile(UIViewController *,NSURL *,NSString *,void(^)(void));DXImportDirectoryFile(self,url,self.session?:@"local-terminal",^{self.busy=NO;});});}]];[self presentViewController:confirm animated:YES completion:nil];
}
- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)i{return !self.entry&&!self.attachmentSelection;}
- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)i{NSDictionary *row=self.rows[i.row];NSError *error=nil;if(![TFAIDirectoryRegistry remove:row[@"directoryGrant"] error:&error])[self showError:error];[self reload];}
@end
#import "../Sandbox/TFAIISHRuntime.h"
void DXImportDirectoryFile(UIViewController *host,NSURL *url,NSString *session,void(^done)(void)){[TFAIISHRuntime.shared importFile:url name:url.lastPathComponent session:session completion:^(NSDictionary *r,NSError *e){[NSFileManager.defaultManager removeItemAtURL:url.URLByDeletingLastPathComponent error:nil];done();AIAlert(host,e?@"复制失败":@"已复制",e.localizedDescription?:r[@"path"]);}];}
UIViewController *TFAIDirectoryRegistryController(NSString *session){TFAIDirectoryPage *page=[[TFAIDirectoryPage alloc]initWithStyle:UITableViewStyleInsetGrouped];page.session=session;return page;}

UIViewController *TFAIMountedAttachmentBrowser(void(^selection)(NSDictionary *,NSString *)){TFAIDirectoryPage *page=[[TFAIDirectoryPage alloc]initWithStyle:UITableViewStyleInsetGrouped];page.attachmentSelection=selection;return page;}

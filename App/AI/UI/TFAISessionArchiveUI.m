#import "../Sessions/TFAISessionArchive.h"
#import "../AIV2Contracts.h"
#import "../../../Vendor/MBProgressHUD/MBProgressHUD.h"
#import <objc/runtime.h>
static char ExportBusy;
static void PresentExport(UIViewController *host,UIViewController *sheet,NSUInteger attempt){
 if(!host.view.window){return;}
 // On iOS 26 the context preview and the navigation container can still have
 // an active transition even after the menu animator's completion.
 if(host.presentedViewController||host.isBeingPresented||host.isBeingDismissed||host.transitionCoordinator||host.navigationController.transitionCoordinator){
  if(attempt<60){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(),^{PresentExport(host,sheet,attempt+1);});return;}
  MBProgressHUD *notice=[MBProgressHUD showHUDAddedTo:host.view animated:YES];notice.mode=MBProgressHUDModeText;notice.label.text=@"请关闭当前弹窗后重新导出";[notice hideAnimated:YES afterDelay:3];return;
 }
 [host presentViewController:sheet animated:YES completion:nil];
}
static void ExportSession(UIViewController *host,NSDictionary *summary,UIView *anchor,BOOL includeAttachments){
 if([objc_getAssociatedObject(host,&ExportBusy) boolValue])return;
 NSString *scope=summary[@"storageProjectID"]?:@"general",*identifier=summary[@"id"];
 if(TFAISessionHasLiveRun(scope,identifier)){
  UIAlertController *a=[UIAlertController alertControllerWithTitle:@"会话正在运行" message:@"请等待本轮回复结束后再导出，以保留完整的消息和工具结果。" preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];PresentExport(host,a,0);return;
 }
 objc_setAssociatedObject(host,&ExportBusy,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 MBProgressHUD *hud=[MBProgressHUD showHUDAddedTo:host.view animated:YES];hud.label.text=@"正在导出会话…";hud.detailsLabel.text=includeAttachments?@"整理消息和本地附件，完成后打开分享":@"整理聊天、思考和执行记录，不包含附件";hud.accessibilityIdentifier=@"session-export-progress";
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
 NSError *error=nil;NSDictionary *session=[TFAISessions loadSession:identifier project:scope];NSURL *url=TFAISessionArchiveExportWithAttachments(session,NSHomeDirectory(),includeAttachments,&error);
 dispatch_async(dispatch_get_main_queue(),^{
  [hud hideAnimated:YES];objc_setAssociatedObject(host,&ExportBusy,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if(url){
   UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[url] applicationActivities:nil];
   share.completionWithItemsHandler=^(UIActivityType type,BOOL done,NSArray *items,NSError *failure){dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{[NSFileManager.defaultManager removeItemAtURL:url.URLByDeletingLastPathComponent error:nil];});};
   UIView *source=anchor.window==host.view.window?anchor:host.view;
   share.popoverPresentationController.sourceView=source;
   share.popoverPresentationController.sourceRect=source==host.view?CGRectMake(CGRectGetMidX(source.bounds),CGRectGetMidY(source.bounds),1,1):source.bounds;
   PresentExport(host,share,0);
  }else{
   UIAlertController *a=[UIAlertController alertControllerWithTitle:@"导出失败" message:error.localizedDescription?:@"无法读取会话，请返回列表后重试。" preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];PresentExport(host,a,0);
  }
 });
 });
}

void TFAISessionArchiveShare(UIViewController *host,NSDictionary *summary,UIView *anchor){
 if([objc_getAssociatedObject(host,&ExportBusy) boolValue])return;
 UIAlertController *choices=[UIAlertController alertControllerWithTitle:@"导出会话" message:@"两种方式均保留已保存的聊天、思考和工具执行记录，可重新导入 Dylix。" preferredStyle:UIAlertControllerStyleActionSheet];
 [choices addAction:[UIAlertAction actionWithTitle:@"仅会话（不含附件）" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){ExportSession(host,summary,anchor,NO);}]];
 [choices addAction:[UIAlertAction actionWithTitle:@"会话及附件" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){ExportSession(host,summary,anchor,YES);}]];
 [choices addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
 UIView *source=anchor.window==host.view.window?anchor:host.view;choices.popoverPresentationController.sourceView=source;choices.popoverPresentationController.sourceRect=source==host.view?CGRectMake(CGRectGetMidX(source.bounds),CGRectGetMidY(source.bounds),1,1):source.bounds;
 PresentExport(host,choices,0);
}

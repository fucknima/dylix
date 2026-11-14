#import "DXAppUpdate.h"
#import <WebKit/WebKit.h>
@interface DXUpdateWebsite : UIViewController <WKNavigationDelegate>
@property WKWebView *web;
@property BOOL opened;
@property UILabel *status;
@end
@implementation DXUpdateWebsite
- (void)viewDidLoad{[super viewDidLoad];self.title=@"获取 Dylix";self.view.backgroundColor=UIColor.systemBackgroundColor;WKWebViewConfiguration *config=[WKWebViewConfiguration new];config.websiteDataStore=WKWebsiteDataStore.nonPersistentDataStore;self.web=[[WKWebView alloc]initWithFrame:CGRectZero configuration:config];self.web.navigationDelegate=self;self.web.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:self.web];[NSLayoutConstraint activateConstraints:@[[self.web.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[self.web.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[self.web.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.web.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"重新加载" style:UIBarButtonItemStylePlain target:self action:@selector(reload)];[self reload];}
- (void)reload{self.opened=NO;[self.web loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://dylib.cn/"]]];}
- (void)webView:(WKWebView *)web didFinishNavigation:(WKNavigation *)navigation{
 if(self.opened||![web.URL.host.lowercaseString isEqual:@"dylib.cn"]||![web.URL.scheme isEqual:@"https"])return;self.opened=YES;
 // Only open the site's existing dialog. Never click .download-file or request an IPA.
 [web evaluateJavaScript:@"(()=>{const b=document.querySelector('[data-download]');if(b){b.click();return true;}return false;})()" completionHandler:^(id result,NSError *error){if(error||![result boolValue])self.title=@"官网 · 请点击获取 Dylix";}];
}
- (void)webView:(WKWebView *)web decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void(^)(WKNavigationActionPolicy))handler{
 NSURL *url=action.request.URL;BOOL http=[@[@"https",@"http"] containsObject:url.scheme.lowercaseString];if([url.pathExtension.lowercaseString isEqual:@"ipa"]){handler(WKNavigationActionPolicyCancel);if(action.navigationType==WKNavigationTypeLinkActivated&&[url.scheme isEqual:@"https"]&&[url.host.lowercaseString isEqual:@"dylib.cn"])[UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];return;}
 if(!http){handler(WKNavigationActionPolicyCancel);return;}if(action.targetFrame.isMainFrame||!action.targetFrame){if(![url.scheme isEqual:@"https"]||![url.host.lowercaseString isEqual:@"dylib.cn"]){handler(WKNavigationActionPolicyCancel);if(action.navigationType==WKNavigationTypeLinkActivated)[UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];return;}}handler(WKNavigationActionPolicyAllow);
}
- (void)webView:(WKWebView *)web didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{if(error.code!=NSURLErrorCancelled)self.title=@"官网打开失败 · 可重新加载";}
@end
UIViewController *DXAppUpdateWebsite(void){return [DXUpdateWebsite new];}
static UIViewController *UpdateHost(UIViewController *root){UIViewController *host=root;while(YES){if(host.presentedViewController){host=host.presentedViewController;continue;}if([host isKindOfClass:UINavigationController.class]){host=[(UINavigationController *)host topViewController];continue;}if([host isKindOfClass:UITabBarController.class]){host=[(UITabBarController *)host selectedViewController];continue;}break;}return host;}
// Keep a launch result pending while another alert or transition owns presentation.
static void PresentUpdateResult(UIViewController *root,BOOL manual,NSDictionary *release,NSError *error,NSUInteger attempt){
 NSString *installed=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
 BOOL newer=release&&DXAppVersionIsNewer(release[@"version"],installed);
 if(!manual&&![DXAppUpdate.shared shouldOfferRelease:release installedVersion:installed manual:NO])return;
 UIViewController *page=UpdateHost(root);
 BOOL busy=!page.viewIfLoaded.window||[page isKindOfClass:UIAlertController.class]||page.isBeingPresented||page.isBeingDismissed||page.transitionCoordinator!=nil;
 if(busy){
  if(!manual&&attempt<60){__weak UIViewController *weak=root;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{UIViewController *host=weak;if(host)PresentUpdateResult(host,NO,release,error,attempt+1);});}
  return;
 }
 NSString *title=error?@"检测更新失败":newer?@"发现新版本":@"当前已是最新版本";
 NSString *message=error?error.localizedDescription:[NSString stringWithFormat:@"当前 %@ · 官网 %@%@",installed,release[@"version"],newer?@"\n前往官网后展开获取界面，不会自动下载。":@""];
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
 if(newer){
  [alert addAction:[UIAlertAction actionWithTitle:@"更新" style:UIAlertActionStyleDefault handler:^(id action){UIViewController *website=DXAppUpdateWebsite();if(page.navigationController)[page.navigationController pushViewController:website animated:YES];else[page presentViewController:[[UINavigationController alloc]initWithRootViewController:website] animated:YES completion:nil];}]];
  [alert addAction:[UIAlertAction actionWithTitle:@"忽略此版本" style:UIAlertActionStyleDefault handler:^(id action){[DXAppUpdate.shared ignoreVersion:release[@"version"]];}]];
 }
 [alert addAction:[UIAlertAction actionWithTitle:newer?@"稍后":@"好" style:UIAlertActionStyleCancel handler:nil]];
 [page presentViewController:alert animated:YES completion:nil];
}
void DXAppUpdatePresent(UIViewController *host,BOOL manual){
 __weak UIViewController *weak=host;UIAlertController *waiting=nil;
 if(manual){waiting=[UIAlertController alertControllerWithTitle:@"正在检测更新" message:@"正在读取 dylib.cn 官网版本…" preferredStyle:UIAlertControllerStyleAlert];[waiting addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:nil]];[host presentViewController:waiting animated:YES completion:nil];}
 [DXAppUpdate.shared check:^(NSDictionary *release,NSError *error){UIViewController *page=weak;if(!page)return;
  void(^show)(void)=^{PresentUpdateResult(page,manual,release,error,0);};
  if(waiting){if(page.presentedViewController!=waiting)return;[waiting dismissViewControllerAnimated:YES completion:show];}else show();
 }];
}
void DXAppUpdateOnLaunch(UIViewController *root){static BOOL checked=NO;if(checked)return;checked=YES;
#if TARGET_OS_SIMULATOR
 for(NSString *argument in NSProcessInfo.processInfo.arguments)if([argument hasPrefix:@"--"])return;
#endif
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{DXAppUpdatePresent(root,NO);});
}

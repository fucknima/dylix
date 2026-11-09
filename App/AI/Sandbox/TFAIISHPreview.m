// Dylix local development preview. Never reuses the public browser or its cookies.
#import "TFAIISHPreview.h"
#import "TFAIISHRuntime.h"
#import "../UI/TFAIUIHelpers.h"
#import <WebKit/WebKit.h>

static NSError *PreviewError(NSString *s){return [NSError errorWithDomain:@"Dylix.Preview" code:1 userInfo:@{NSLocalizedDescriptionKey:s}];}
@interface DylixISHWeb : NSObject <WKNavigationDelegate,WKUIDelegate>
@property WKWebView *web;
@property NSString *session,*process,*snapshot;
- (void)perform:(NSDictionary *)args completion:(void(^)(NSDictionary *,NSError *))completion;
- (void)observe:(void(^)(NSDictionary *,NSError *))completion;
@property(copy) void(^completion)(NSDictionary *,NSError *);
@property NSUInteger generation;
- (void)load:(NSDictionary *)info session:(NSString *)session completion:(void(^)(NSDictionary *,NSError *))completion;
@end
@implementation DylixISHWeb
- (instancetype)init{if((self=[super init])){WKWebViewConfiguration *c=[WKWebViewConfiguration new];c.websiteDataStore=WKWebsiteDataStore.nonPersistentDataStore;_web=[[WKWebView alloc]initWithFrame:CGRectMake(0,0,900,900) configuration:c];_web.navigationDelegate=self;_web.UIDelegate=self;}return self;}
- (void)finish:(NSDictionary *)result error:(NSError *)error{void(^done)(NSDictionary *,NSError *)=self.completion;self.completion=nil;if(done)done(result,error);}
- (void)load:(NSDictionary *)info session:(NSString *)session completion:(void(^)(NSDictionary *,NSError *))completion{
 if(self.completion)[self finish:nil error:PreviewError(@"已切换到新的本地网页预览")];self.snapshot=nil;self.session=session;self.process=info[@"process_id"];self.completion=completion;NSUInteger gen=++self.generation;NSURL *url=[NSURL URLWithString:info[@"url"]];
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||![TFAIISHRuntime.shared ownsPreviewURL:url process:self.process session:session]){[self finish:nil error:PreviewError(@"预览需要 App 在前台，且该进程仍在监听本会话端口")];return;}
 [self.web loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15]];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,18*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(gen==self.generation&&self.completion){[self.web stopLoading];[self finish:nil error:PreviewError(@"本地网页预览超时，请检查进程输出和端口")];}});
}
- (void)webView:(WKWebView *)web decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decision{
 if(action.targetFrame.isMainFrame)self.snapshot=nil;BOOL allowed=[TFAIISHRuntime.shared ownsPreviewURL:action.request.URL process:self.process session:self.session]&&!action.shouldPerformDownload;
 decision(allowed?WKNavigationActionPolicyAllow:WKNavigationActionPolicyCancel);
 if(!allowed&&action.targetFrame.isMainFrame)[self finish:nil error:PreviewError(@"预览已阻止跳转到其他服务、外部地址或下载；请检查本会话进程")];
}
- (void)observe:(void(^)(NSDictionary *,NSError *))completion{
 if(![TFAIISHRuntime.shared ownsPreviewURL:self.web.URL process:self.process session:self.session]){completion(nil,PreviewError(@"服务器已停止或当前页面不属于本会话"));return;}
 NSString *token=NSUUID.UUID.UUIDString;NSData *json=[NSJSONSerialization dataWithJSONObject:@[token] options:0 error:nil];NSString *literal=[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding];
 NSString *script=[NSString stringWithFormat:@"(()=>{const token=%@[0];const nodes=Array.from(document.querySelectorAll('a,button,input,textarea,select,[role=button],[contenteditable=true]')).filter(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.visibility!=='hidden'&&s.display!=='none'}).slice(0,120);globalThis.__dylixSnapshot={token,nodes,url:location.href};return {snapshot:token,url:location.href,title:document.title,text:(document.body?.innerText||'').slice(0,12000),elements:nodes.map((e,i)=>{const r=e.getBoundingClientRect();return {id:String(i),tag:e.tagName,type:e.type||'',text:(e.innerText||e.getAttribute('aria-label')||e.placeholder||'').slice(0,160),disabled:!!e.disabled,rect:{x:r.x,y:r.y,width:r.width,height:r.height}}}),source:'untrusted-local-rendered-content',local_only:true}})()",literal];
 [self.web evaluateJavaScript:script inFrame:nil inContentWorld:WKContentWorld.defaultClientWorld completionHandler:^(id value,NSError *e){if(![TFAIISHRuntime.shared ownsPreviewURL:self.web.URL process:self.process session:self.session]){completion(nil,PreviewError(@"快照期间服务器已停止"));return;}if(e||![value isKindOfClass:NSDictionary.class])completion(nil,PreviewError(@"页面快照失败，请重新打开预览"));else{self.snapshot=token;NSMutableDictionary *r=[value mutableCopy];r[@"process_id"]=self.process;r[@"javascriptRendered"]=@YES;completion(r,nil);}}];
}
- (void)perform:(NSDictionary *)args completion:(void(^)(NSDictionary *,NSError *))completion{
 NSString *operation=args[@"operation"];
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||![TFAIISHRuntime.shared ownsPreviewURL:self.web.URL process:self.process session:self.session]){completion(nil,PreviewError(@"网页操作需要前台及仍在运行的本会话服务器"));return;}
 if([operation isEqual:@"observe"]){[self observe:completion];return;}
 if([operation isEqual:@"screenshot"]){[self.web takeSnapshotWithConfiguration:nil completionHandler:^(UIImage *image,NSError *e){if(!image||e){completion(nil,PreviewError(@"本地网页截图失败"));return;}CGFloat ratio=MIN(1,1000.0/MAX(image.size.width,image.size.height));UIGraphicsBeginImageContextWithOptions(CGSizeMake(image.size.width*ratio,image.size.height*ratio),YES,1);[image drawInRect:CGRectMake(0,0,image.size.width*ratio,image.size.height*ratio)];UIImage *small=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();NSData *bytes=UIImageJPEGRepresentation(small,0.55);if(!bytes.length||bytes.length>120*1024){completion(nil,PreviewError(@"截图超过 120 KiB，请使用元素快照"));return;}if(![TFAIISHRuntime.shared ownsPreviewURL:self.web.URL process:self.process session:self.session]){completion(nil,PreviewError(@"截图期间服务器已停止"));return;}completion(@{@"imageBase64":[bytes base64EncodedStringWithOptions:0],@"mime":@"image/jpeg",@"width":@(small.size.width),@"height":@(small.size.height),@"process_id":self.process,@"source":@"local-preview-screenshot"},nil);}];return;}
 if(![@[@"click",@"type",@"select",@"scroll"] containsObject:operation]||![args[@"snapshot"] isKindOfClass:NSString.class]||![args[@"snapshot"] isEqual:self.snapshot]){completion(nil,PreviewError(@"快照已失效或操作无效，请先 observe 获取新的元素 ID"));return;}
 NSString *text=args[@"text"];if(text&&(![text isKindOfClass:NSString.class]||text.length>4096)){completion(nil,PreviewError(@"输入文本超过 4096 字符或格式无效"));return;}
 NSData *encoded=[NSJSONSerialization dataWithJSONObject:args options:0 error:nil];NSString *literal=[[NSString alloc]initWithData:encoded encoding:NSUTF8StringEncoding];
 NSString *js=[NSString stringWithFormat:@"(()=>{const a=%@,s=globalThis.__dylixSnapshot;if(!s||s.token!==a.snapshot||s.url!==location.href)throw Error('stale snapshot');if(a.operation==='scroll'){window.scrollBy(0,Math.max(-900,Math.min(900,Number(a.delta)||0)));s.token=null;return {dispatched:true}}const e=s.nodes[Number(a.id)];if(!e||!e.isConnected||e.disabled)throw Error('stale or disabled element');const r=e.getBoundingClientRect();if(r.width<=0||r.height<=0||getComputedStyle(e).visibility==='hidden')throw Error('element hidden');if(['password','file','hidden'].includes((e.type||'').toLowerCase()))throw Error('sensitive input disabled');if(a.operation==='click'){e.scrollIntoView({block:'center'});e.click()}else if(a.operation==='type'){if(!['INPUT','TEXTAREA'].includes(e.tagName)||e.readOnly)throw Error('not editable');const p=e.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;Object.getOwnPropertyDescriptor(p,'value').set.call(e,a.text||'');e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}))}else if(a.operation==='select'){if(e.tagName!=='SELECT'||!Array.from(e.options).some(o=>o.value===a.text))throw Error('invalid option');e.value=a.text;e.dispatchEvent(new Event('change',{bubbles:true}))}s.token=null;return {dispatched:true}})()",literal];self.snapshot=nil;
 [self.web evaluateJavaScript:js inFrame:nil inContentWorld:WKContentWorld.defaultClientWorld completionHandler:^(id r,NSError *e){if(e){completion(nil,PreviewError(@"操作未完成：元素已变化、类型不匹配或输入受限；请重新 observe"));return;}dispatch_after(dispatch_time(DISPATCH_TIME_NOW,350*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self observe:^(NSDictionary *state,NSError *e){if(e){completion(nil,e);return;}NSMutableDictionary *result=[state mutableCopy];result[@"action_dispatched"]=@YES;result[@"verification_required"]=@YES;result[@"message"]=@"已派发 DOM 操作；请用返回的新页面状态验证业务结果，不应仅凭派发成功宣布完成。";completion(result,nil);}];});}];
}

- (void)webView:(WKWebView *)web didFinishNavigation:(WKNavigation *)navigation{[self extract:self.generation attempt:0 previous:nil];}
- (void)extract:(NSUInteger)generation attempt:(NSUInteger)attempt previous:(NSString *)previous{
 if(generation!=self.generation||!self.completion)return;
 if(![TFAIISHRuntime.shared ownsPreviewURL:self.web.URL process:self.process session:self.session]){[self finish:nil error:PreviewError(@"服务器已停止或端口归属已变化")];return;}
 NSString *js=@"(()=>({title:document.title,url:location.href,text:(document.body?.innerText||'').slice(0,16000),links:Array.from(document.querySelectorAll('a[href]')).slice(0,60).map(a=>({text:(a.innerText||'').slice(0,100),url:a.href})),source:'untrusted-local-rendered-content',javascriptRendered:true}))()";
 [self.web evaluateJavaScript:js completionHandler:^(id value,NSError *error){if(generation!=self.generation||!self.completion)return;if(error||![value isKindOfClass:NSDictionary.class]){[self finish:nil error:PreviewError(@"本地页面已加载，但 JavaScript 正文读取失败")];return;}
  NSString *text=value[@"text"];if(attempt>=10||(attempt>=2&&[text isEqual:previous])){NSMutableDictionary *result=[value mutableCopy];result[@"process_id"]=self.process;result[@"local_only"]=@YES;[self finish:result error:nil];return;}
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self extract:generation attempt:attempt+1 previous:text];});
 }];
}
- (void)webView:(WKWebView *)web didFailNavigation:(WKNavigation *)nav withError:(NSError *)error{[self finish:nil error:PreviewError([NSString stringWithFormat:@"本地页面加载失败（%ld）：%@",(long)error.code,error.localizedDescription])];}
- (void)webView:(WKWebView *)web didFailProvisionalNavigation:(WKNavigation *)nav withError:(NSError *)error{[self webView:web didFailNavigation:nav withError:error];}
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)web{[self finish:nil error:PreviewError(@"网页进程被系统结束，请刷新预览")];}
- (WKWebView *)webView:(WKWebView *)web createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)features{if(!action.targetFrame&&[TFAIISHRuntime.shared ownsPreviewURL:action.request.URL process:self.process session:self.session])[web loadRequest:action.request];return nil;}
@end
static NSMutableDictionary<NSString *,DylixISHWeb *> *PreviewPool(void){static NSMutableDictionary *pool;static dispatch_once_t once;dispatch_once(&once,^{pool=[NSMutableDictionary new];});return pool;}
static NSString *PreviewKey(NSString *session,NSString *process){return [session stringByAppendingFormat:@"|%@",process];}
static DylixISHWeb *PreviewBrowser(NSString *session,NSString *process){NSMutableDictionary<NSString *,DylixISHWeb *> *pool=PreviewPool();for(NSString *key in pool.allKeys.copy){DylixISHWeb *old=pool[key];if(![TFAIISHRuntime.shared ownsPreviewURL:old.web.URL process:old.process session:old.session]&&!old.completion){[old.web stopLoading];[pool removeObjectForKey:key];}}NSString *key=PreviewKey(session,process);DylixISHWeb *browser=pool[key];if(!browser){if(pool.count>=4){NSString *old=pool.allKeys.firstObject;[pool[old] finish:nil error:PreviewError(@"预览达到四个上限，已释放较早页面")];[pool[old].web stopLoading];[pool removeObjectForKey:old];}browser=[DylixISHWeb new];pool[key]=browser;}return browser;}
@interface DylixISHPreviewPage : UIViewController
@property DylixISHWeb *browser;
@property NSDictionary *info;
@property NSString *session;
@property UILabel *status;
@end
@implementation DylixISHPreviewPage
- (void)viewDidLoad{[super viewDidLoad];self.title=@"本地网页预览";self.view.backgroundColor=UIColor.systemBackgroundColor;self.browser=PreviewBrowser(self.session,self.info[@"process_id"]);self.status=[UILabel new];self.status.font=[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];self.status.numberOfLines=2;self.status.text=self.info[@"url"];self.status.textColor=UIColor.secondaryLabelColor;
 WKWebView *web=self.browser.web;for(UIView *v in @[self.status,web]){v.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:v];}
 UILayoutGuide *safe=self.view.safeAreaLayoutGuide;[NSLayoutConstraint activateConstraints:@[[self.status.topAnchor constraintEqualToAnchor:safe.topAnchor constant:6],[self.status.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],[self.status.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],[web.topAnchor constraintEqualToAnchor:self.status.bottomAnchor constant:6],[web.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],[web.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],[web.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor]]];
 self.navigationItem.rightBarButtonItems=@[AIBar(@"arrow.clockwise",@"刷新",self,@selector(reload)),AIBar(@"square.and.arrow.up",@"分享截图",self,@selector(share))];[self reload];}
- (void)reload{self.status.text=[self.info[@"url"] stringByAppendingString:@" · 加载中"];[self.browser load:self.info session:self.session completion:^(NSDictionary *r,NSError *e){self.status.text=e.localizedDescription?:[r[@"url"] stringByAppendingString:@" · 已加载真实网页"];if(e)AIAlert(self,@"预览未打开",e.localizedDescription);}];}
- (void)share{WKSnapshotConfiguration *c=[WKSnapshotConfiguration new];[self.browser.web takeSnapshotWithConfiguration:c completionHandler:^(UIImage *image,NSError *error){if(!image){AIAlert(self,@"截图未完成",error.localizedDescription?:@"页面尚未准备好");return;}UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[image] applicationActivities:nil];share.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItems.lastObject;[self presentViewController:share animated:YES completion:nil];}];}
@end
UIViewController *TFAIISHPreviewController(NSDictionary *info,NSString *session){DylixISHPreviewPage *page=[DylixISHPreviewPage new];page.info=info;page.session=session;return page;}
void TFAIISHReadPreview(NSDictionary *info,NSString *session,void(^completion)(NSDictionary *,NSError *)){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{TFAIISHReadPreview(info,session,completion);});return;}
 DylixISHWeb *reader=PreviewBrowser(session,info[@"process_id"]);[reader load:info session:session completion:^(NSDictionary *r,NSError *e){if(e){completion(nil,e);return;}[reader observe:completion];}];
}
void TFAIISHBrowserAction(NSDictionary *arguments,NSString *session,void(^completion)(NSDictionary *,NSError *)){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{TFAIISHBrowserAction(arguments,session,completion);});return;}NSString *process=arguments[@"process_id"];DylixISHWeb *reader=PreviewPool()[PreviewKey(session,process?:@"")];if(!reader){completion(nil,PreviewError(@"请先用 sandbox_preview 打开当前进程的页面"));return;}if(reader.completion||reader.web.loading){completion(nil,PreviewError(@"页面正在加载，请稍后重新观察"));return;}[reader perform:arguments completion:completion];
}

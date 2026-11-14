#import "DXAppUpdate.h"
static NSError *UpdateError(NSString *text){return [NSError errorWithDomain:@"Dylix.Update" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}
static BOOL ValidVersion(NSString *value){if(![value isKindOfClass:NSString.class]||value.length>40)return NO;return [[NSRegularExpression regularExpressionWithPattern:@"^[0-9]+(?:\\.[0-9]+){1,3}$" options:0 error:nil] firstMatchInString:value options:0 range:NSMakeRange(0,value.length)]!=nil;}
BOOL DXAppVersionIsNewer(NSString *remote,NSString *installed){if(!ValidVersion(remote)||!ValidVersion(installed))return NO;NSArray *a=[remote componentsSeparatedByString:@"."],*b=[installed componentsSeparatedByString:@"."];for(NSUInteger i=0;i<MAX(a.count,b.count);i++){unsigned long long x=i<a.count?[a[i] longLongValue]:0,y=i<b.count?[b[i] longLongValue]:0;if(x!=y)return x>y;}return NO;}
NSDictionary *DXAppUpdateFromHTML(NSString *html,NSURL *page,NSError **error){
 if(![page.scheme isEqual:@"https"]||![page.host.lowercaseString isEqual:@"dylib.cn"]){if(error)*error=UpdateError(@"更新来源不是 dylib.cn。");return nil;}
 // Read a real IPA link, never marketing text or an arbitrary version in scripts.
 NSRegularExpression *anchors=[NSRegularExpression regularExpressionWithPattern:@"<a\\b[^>]*>" options:NSRegularExpressionCaseInsensitive error:nil];
 NSRegularExpression *href=[NSRegularExpression regularExpressionWithPattern:@"\\bhref\\s*=\\s*([\"'])(.*?)\\1" options:NSRegularExpressionCaseInsensitive error:nil];
 NSRegularExpression *filename=[NSRegularExpression regularExpressionWithPattern:@"^Dylix-([0-9]+(?:\\.[0-9]+){1,3})(?:-build([0-9]+))?(?:-unsigned)?\\.ipa$" options:NSRegularExpressionCaseInsensitive error:nil];
 NSDictionary *best=nil;
 for(NSTextCheckingResult *a in [anchors matchesInString:html options:0 range:NSMakeRange(0,html.length)]){NSString *tag=[html substringWithRange:a.range];NSTextCheckingResult *link=[href firstMatchInString:tag options:0 range:NSMakeRange(0,tag.length)];if(!link)continue;NSString *raw=[[tag substringWithRange:[link rangeAtIndex:2]] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];NSURL *url=[NSURL URLWithString:raw relativeToURL:page].absoluteURL;
 if(![url.scheme isEqual:@"https"]||![url.host.lowercaseString isEqual:@"dylib.cn"]||url.user||url.password||url.port||![url.path hasPrefix:@"/downloads/"])continue;
 NSString *name=url.lastPathComponent;NSTextCheckingResult *match=[filename firstMatchInString:name options:0 range:NSMakeRange(0,name.length)];if(!match)continue;NSString *version=[name substringWithRange:[match rangeAtIndex:1]];if(!ValidVersion(version))continue;
 NSDictionary *row=@{@"version":version,@"ipaURL":url.absoluteString,@"website":@"https://dylib.cn/"};if(!best||DXAppVersionIsNewer(version,best[@"version"]))best=row;
 }if(!best&&error)*error=UpdateError(@"官网暂未提供可识别的 Dylix IPA 版本，请稍后重试。");return best;
}
@interface DXAppUpdate () <NSURLSessionDataDelegate>
@property(nonatomic,readwrite) NSDictionary *latestRelease;
@property(nonatomic,readwrite) BOOL checking;
@property NSMutableArray *callbacks;
@property NSMutableData *data;
@property NSURLSession *session;
@property NSError *failure;
@end
@implementation DXAppUpdate
+ (instancetype)shared{static id value;static dispatch_once_t once;dispatch_once(&once,^{value=[self new];});return value;}
- (void)ignoreVersion:(NSString *)version{
 if(ValidVersion(version))[NSUserDefaults.standardUserDefaults setObject:version forKey:@"DylixIgnoredUpdateVersion"];
}
- (BOOL)shouldOfferRelease:(NSDictionary *)release installedVersion:(NSString *)installed manual:(BOOL)manual{
 NSString *version=release[@"version"];
 if(!DXAppVersionIsNewer(version,installed))return NO;
 NSString *ignored=[NSUserDefaults.standardUserDefaults stringForKey:@"DylixIgnoredUpdateVersion"];
 BOOL same=ValidVersion(ignored)&&!DXAppVersionIsNewer(version,ignored)&&!DXAppVersionIsNewer(ignored,version);
 return manual||!same;
}
- (void)check:(void(^)(NSDictionary *,NSError *))completion{
 dispatch_async(dispatch_get_main_queue(),^{if(self.checking){[self.callbacks addObject:[completion copy]];return;}self.checking=YES;self.callbacks=[NSMutableArray arrayWithObject:[completion copy]];self.data=[NSMutableData new];self.failure=nil;
 NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.timeoutIntervalForRequest=20;config.timeoutIntervalForResource=30;config.URLCache=nil;config.HTTPCookieStorage=nil;self.session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://dylib.cn/"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];[[self.session dataTaskWithRequest:request] resume];});
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void(^)(NSURLRequest *))handler{BOOL same=[request.URL.scheme isEqual:@"https"]&&[request.URL.host.lowercaseString isEqual:@"dylib.cn"]&&!request.URL.user&&!request.URL.password;handler(same?request:nil);}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void(^)(NSURLSessionResponseDisposition))handler{if([(NSHTTPURLResponse *)response statusCode]!=200||response.expectedContentLength>2*1024*1024){self.failure=UpdateError(@"官网更新检测暂不可用，请稍后重试。");handler(NSURLSessionResponseCancel);return;}handler(NSURLSessionResponseAllow);}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data{if(self.data.length+data.length>2*1024*1024){self.failure=UpdateError(@"官网响应过大，已停止更新检测。");[task cancel];return;}[self.data appendData:data];}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
 NSError *failure=self.failure?:error;NSDictionary *release=nil;if(!failure){NSString *html=[[NSString alloc]initWithData:self.data encoding:NSUTF8StringEncoding];if(html)release=DXAppUpdateFromHTML(html,task.response.URL,&failure);else failure=UpdateError(@"官网内容格式无法识别。");}
 if(release)self.latestRelease=release;NSArray *callbacks=self.callbacks.copy;self.callbacks=nil;self.checking=NO;self.data=nil;[session finishTasksAndInvalidate];self.session=nil;for(void(^callback)(NSDictionary *,NSError *) in callbacks)callback(release,failure);
}
@end

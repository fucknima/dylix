#import <WebKit/WebKit.h>
/// Per-browser, ephemeral DOM snapshots. Page strings are always untrusted data.
@interface TFAIWebDOM : NSObject
- (instancetype)initWithWebView:(WKWebView *)web validator:(BOOL(^)(NSURL *))validator;
- (void)invalidate;
- (void)perform:(NSDictionary *)arguments completion:(void(^)(NSDictionary *,NSError *))completion;
@end

#import "../AIContracts.h"
#import <WebKit/WebKit.h>
@interface TFAIReadOnlyBrowser : NSObject
+ (instancetype)browserForSession:(NSString *)sessionID;
+ (NSArray<NSDictionary *> *)tabsForSession:(NSString *)sessionID;
+ (BOOL)selectTab:(NSString *)identifier session:(NSString *)sessionID;
+ (BOOL)AIBlockedForSession:(NSString *)sessionID;
+ (BOOL)setManualLogin:(BOOL)manual session:(NSString *)sessionID;
+ (BOOL)newTabForSession:(NSString *)sessionID;
+ (void)closeTab:(NSString *)identifier session:(NSString *)sessionID;
+ (void)clearSession:(NSString *)sessionID completion:(dispatch_block_t)completion;
- (void)read:(NSString *)url completion:(TFAIResult)completion;
- (void)perform:(NSDictionary *)arguments completion:(TFAIResult)completion;
- (void)cancel;
@property(nonatomic,readonly) WKWebView *webView;
@end
FOUNDATION_EXPORT UIViewController *TFAIReadOnlyBrowserController(void);
FOUNDATION_EXPORT UIViewController *TFAIReadOnlyBrowserControllerWithAsk(NSString *sessionID,void (^onAsk)(NSString *url));

#import <UIKit/UIKit.h>
FOUNDATION_EXPORT UIViewController *TFAIISHPreviewController(NSDictionary *info,NSString *session);
FOUNDATION_EXPORT void TFAIISHReadPreview(NSDictionary *info,NSString *session,void(^completion)(NSDictionary *,NSError *));

FOUNDATION_EXPORT void TFAIISHBrowserAction(NSDictionary *arguments,NSString *session,void(^completion)(NSDictionary *,NSError *));

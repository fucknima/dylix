#import <Foundation/Foundation.h>
// Home is injected for isolated export/import tests; never supplied by a model.
NSURL *TFAISessionArchiveExport(NSDictionary *session,NSString *home,NSError **error);
NSURL *TFAISessionArchiveExportWithAttachments(NSDictionary *session,NSString *home,BOOL includeAttachments,NSError **error);
BOOL TFAISessionArchiveRecognizes(NSString *path);
NSDictionary *TFAISessionArchiveImport(NSString *path,NSString *home,NSError **error);
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
void TFAISessionArchiveShare(UIViewController *host,NSDictionary *summary,UIView *anchor);
#endif

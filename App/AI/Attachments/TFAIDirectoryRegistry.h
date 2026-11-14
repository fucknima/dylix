#import <Foundation/Foundation.h>
@interface TFAIDirectoryRegistry : NSObject
+ (NSArray<NSDictionary *> *)entries;
+ (NSDictionary *)add:(NSURL *)url error:(NSError **)error;
+ (BOOL)remove:(NSString *)identifier error:(NSError **)error;
@end
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
UIViewController *TFAIDirectoryRegistryController(NSString *session);
// relativePath is nil for the whole grant; otherwise an explicitly selected file.
UIViewController *TFAIMountedAttachmentBrowser(void(^selection)(NSDictionary *grant,NSString *relativePath));
#endif

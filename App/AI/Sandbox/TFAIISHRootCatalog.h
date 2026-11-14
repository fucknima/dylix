#import <Foundation/Foundation.h>
@interface TFAIISHRootCatalog : NSObject <NSURLSessionDownloadDelegate>
+ (instancetype)shared;
+ (NSArray<NSDictionary *> *)catalog;
+ (NSDictionary *)cacheInfo:(NSString *)identifier;
+ (BOOL)removeArchive:(NSString *)identifier error:(NSError **)error;
+ (NSDictionary *)selection:(NSString *)sessionKey;
+ (NSString *)archive:(NSString *)sessionKey error:(NSError **)error;
+ (BOOL)select:(NSString *)identifier sessionKey:(NSString *)key error:(NSError **)error;
- (void)download:(NSString *)identifier progress:(void(^)(double))progress completion:(void(^)(NSError *))completion;
- (void)cancelDownload;
@end
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
UIViewController *TFAIISHRootCatalogController(NSString *session);
#endif

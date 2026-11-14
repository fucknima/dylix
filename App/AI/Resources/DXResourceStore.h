#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSNotificationName const DXResourceStatusChanged;
/// Pinned, inert SDK/guest archives only. Never loads downloaded iOS libraries.
@interface DXResourceStore : NSObject <NSURLSessionDownloadDelegate>
+ (instancetype)shared;
+ (NSArray<NSDictionary *> *)catalog;
+ (NSString *)directory;
+ (NSDictionary *)entry:(NSString *)identifier;
+ (NSString *)verifiedPath:(NSString *)identifier error:(NSError **)error;
- (NSDictionary *)status:(NSString *)identifier;
- (void)fetch:(NSString *)identifier completion:(void(^)(NSString *,NSError *))completion;
- (void)cancel:(NSString *)identifier;
- (BOOL)remove:(NSString *)identifier error:(NSError **)error;
@end

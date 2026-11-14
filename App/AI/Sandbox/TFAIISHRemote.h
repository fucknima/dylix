#import <Foundation/Foundation.h>
/// Volatile phone-native grant; never persisted or accepted from a remote request.
@interface TFAIISHRemote : NSObject
+ (BOOL)allowed:(NSString *)session;
+ (void)setAllowed:(BOOL)allowed session:(NSString *)session;
+ (void)perform:(NSString *)operation arguments:(NSDictionary *)arguments session:(NSString *)session device:(NSString *)device completion:(void(^)(NSDictionary *,NSError *))completion;
+ (void)revokeDevice:(NSString *)device;
@end

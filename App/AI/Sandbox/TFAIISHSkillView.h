#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface TFAIISHSkillView : NSObject
+ (nullable NSString *)refresh:(nullable NSString *)root sessionKey:(NSString *)key error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>
@class TFAIISHRuntime;
/// One serial install queue per environment; continues while the page is closed.
@interface DXLinuxToolBatch : NSObject
+ (instancetype)shared;
@property(nonatomic,strong) TFAIISHRuntime *runtime;
- (NSDictionary *)status:(NSString *)session;
- (NSArray<NSString *> *)pending:(NSDictionary *)inventory sdkInstalled:(BOOL)sdk;
- (BOOL)start:(NSArray<NSString *> *)identifiers session:(NSString *)session;
- (void)cancelPending:(NSString *)session;
@end

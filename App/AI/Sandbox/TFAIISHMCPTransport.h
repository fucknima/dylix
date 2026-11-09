#import <Foundation/Foundation.h>
@interface TFAIISHMCPTransport : NSObject
@property(readonly) BOOL ready;
- (void)start:(NSString *)command arguments:(NSArray *)arguments session:(NSString *)session completion:(void(^)(NSError *))completion;
- (void)start:(NSString *)command arguments:(NSArray *)arguments environment:(NSDictionary *)environment session:(NSString *)session completion:(void(^)(NSError *))completion;
- (void)request:(NSDictionary *)body completion:(void(^)(NSDictionary *,NSError *))completion;
- (void)close;
@end

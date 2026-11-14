#import <Foundation/Foundation.h>
typedef dispatch_block_t (^TFAISubtaskExecutor)(NSDictionary *task,void(^update)(NSString *stage,NSString *partial),void(^done)(NSDictionary *result,NSError *error));
@interface TFAISubtasks : NSObject
+ (instancetype)shared;
- (instancetype)initWithPath:(NSString *)path;
- (NSArray<NSDictionary *> *)tasks:(NSString *)parent;
- (NSDictionary *)start:(NSString *)kind prompt:(NSString *)prompt parent:(NSString *)parent root:(NSString *)root executor:(TFAISubtaskExecutor)executor error:(NSError **)error;
- (NSDictionary *)resume:(NSString *)identifier parent:(NSString *)parent executor:(TFAISubtaskExecutor)executor error:(NSError **)error;
- (BOOL)canResume:(NSString *)identifier parent:(NSString *)parent;
- (BOOL)cancel:(NSString *)identifier parent:(NSString *)parent;
- (void)cancelParent:(NSString *)parent;
@end
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
UIViewController *TFAISubtaskController(NSString *session);
#endif

#import <UIKit/UIKit.h>

// In-process UIKit event delivery. Never invokes arbitrary gesture targets.
// Call on main; callers retain normal FLEX control approval and app scope.
@interface FLEXDylixTouchDriver : NSObject
@property (nonatomic, readonly) BOOL running;
+ (NSDictionary *)backendCapabilities;
- (void)performPaths:(NSArray<NSArray<NSValue *> *> *)paths
             window:(UIWindow *)window duration:(NSTimeInterval)duration
         completion:(void (^)(NSDictionary *result, NSString *error))completion;
- (void)cancel;
@end

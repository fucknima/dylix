#import <UIKit/UIKit.h>

// All operations run on the main thread. IDs refer only to weakly held views
// discovered in the current view tree or explicitly selected in FLEX.
@interface FLEXDylixRuntime : NSObject
@property (nonatomic, weak) id selectedObject;
- (NSDictionary *)execute:(NSString *)operation arguments:(NSDictionary *)arguments error:(NSString **)error;
- (NSArray<NSDictionary *> *)toolCatalog;
- (UIViewController *)controllerForTool:(NSString *)identifier error:(NSString **)error;
- (void)performGesture:(NSDictionary *)arguments completion:(void (^)(NSDictionary *,NSString *))completion;
- (void)cancelPendingInput;
@end

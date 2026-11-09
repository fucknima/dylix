#import <UIKit/UIKit.h>

@interface FLEXDylixChatViewController : UIViewController
@property(nonatomic,copy) NSString *(^reportProvider)(void);
@property(nonatomic,weak) id selectedObject;
- (instancetype)initWithReport:(NSString *)report className:(NSString *)className;
- (void)updateReport:(NSString *)report className:(NSString *)className selectedObject:(id)object;
@end

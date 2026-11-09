#import <UIKit/UIKit.h>

/// A non-key, pass-through window. Only the compact status capsule receives touches.
@interface FLEXDylixStatusWindow : UIWindow
@property (nonatomic,copy) dispatch_block_t openChat;
@property (nonatomic,readonly) UIButton *capsule;
- (void)updateTitle:(NSString *)title detail:(NSString *)detail color:(UIColor *)color busy:(BOOL)busy;
- (void)clampToSafeArea;
@end

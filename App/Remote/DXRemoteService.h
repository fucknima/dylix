#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface DXRemoteService : NSObject
+ (instancetype)shared;
// Main-thread control API. Listener/access state is serialized internally.
@property(atomic,readonly) NSDictionary *localState;
- (void)start;
- (void)stop;
- (void)refresh;
- (void)rotateCode;
- (void)setFixedCode:(NSString *)code;
- (void)approve:(NSString *)identifier accepted:(BOOL)accepted;
- (void)revoke:(nullable NSString *)identifier;
- (void)setPort:(NSUInteger)port;
- (void)setWebDAVPort:(NSUInteger)port;
- (void)startWebDAVProject:(NSString *)project readOnly:(BOOL)readOnly;
- (void)stopWebDAV;
- (void)setNetworkMode:(NSString *)mode;
@end
UIViewController *DXRemoteSettingsController(void);
NS_ASSUME_NONNULL_END

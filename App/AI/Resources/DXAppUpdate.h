#import <Foundation/Foundation.h>
NSDictionary *DXAppUpdateFromHTML(NSString *html,NSURL *page,NSError **error);
BOOL DXAppVersionIsNewer(NSString *remote,NSString *installed);
@interface DXAppUpdate : NSObject
+ (instancetype)shared;
@property(nonatomic,readonly) NSDictionary *latestRelease;
@property(nonatomic,readonly) BOOL checking;
- (void)ignoreVersion:(NSString *)version;
- (BOOL)shouldOfferRelease:(NSDictionary *)release installedVersion:(NSString *)installed manual:(BOOL)manual;
- (void)check:(void(^)(NSDictionary *,NSError *))completion;
@end
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
void DXAppUpdatePresent(UIViewController *host,BOOL manual);
void DXAppUpdateOnLaunch(UIViewController *root);
UIViewController *DXAppUpdateWebsite(void);
#endif

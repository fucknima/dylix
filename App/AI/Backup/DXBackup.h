#import <Foundation/Foundation.h>
NSArray<NSDictionary *> *DXBackupCategories(void);
// Read-only source inventory, excludes the same cache/link/grant paths as export.
NSDictionary *DXBackupEstimate(NSString *home, NSSet<NSString *> *categories, NSError **error);
// Publishes completed categories as they are scanned; partial results are not a backup manifest.
NSDictionary *DXBackupEstimateProgress(NSString *home, NSSet<NSString *> *categories, NSProgress *progress, void(^update)(NSDictionary *partial), NSError **error);
// Root is injectable for isolated round-trip tests. Never pass model-controlled paths.
NSDictionary *DXBackupCreate(NSString *home,NSSet<NSString *> *categories,NSString *password,BOOL secrets,NSProgress *progress,NSError **error);
NSDictionary *DXBackupInspect(NSURL *package,NSString *password,NSProgress *progress,NSError **error);
BOOL DXBackupSchedule(NSString *home,NSDictionary *inspection,NSSet<NSString *> *categories,NSError **error);
BOOL DXBackupApplyPending(NSString *home,NSError **error);
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
UIViewController *DXBackupController(void);
#endif

NSString *DXBackupRememberedPassword(void);
BOOL DXBackupSavePassword(NSString *password,NSError **error);

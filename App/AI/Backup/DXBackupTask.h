#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSNotificationName const DXBackupTaskChanged;
@interface DXBackupTask : NSObject
+ (instancetype)shared;
@property(nonatomic,readonly) BOOL busy;
@property(nonatomic,readonly) NSProgress *progress;
@property(nonatomic,readonly) NSTimeInterval startedAt;
@property(nonatomic,readonly) NSTimeInterval finishedAt;
@property(nonatomic,readonly) NSDictionary *result;
@property(nonatomic,readonly) NSError *error;
- (BOOL)start:(NSSet<NSString *> *)categories password:(NSString *)password secrets:(BOOL)secrets;
/// Claim the terminal notification once across all backup page instances.
- (BOOL)claimCompletionNotification;
- (void)cancel;
@end

#import <Foundation/Foundation.h>

// Network-only projection. Never replace the execution transcript with its output.
@interface TFAIContextProjection : NSObject
+ (NSUInteger)budgetKiB;
+ (BOOL)setBudgetKiB:(NSUInteger)value;
+ (NSDictionary *)schema;
+ (NSArray *)project:(NSArray *)messages connection:(NSDictionary *)connection schemas:(NSArray *)schemas statistics:(NSDictionary **)statistics error:(NSError **)error;
+ (NSArray *)project:(NSArray *)messages schemas:(NSArray *)schemas statistics:(NSDictionary **)statistics error:(NSError **)error;
+ (NSDictionary *)read:(NSDictionary *)arguments messages:(NSArray *)messages error:(NSError **)error;
+ (NSDictionary *)read:(NSDictionary *)arguments messages:(NSArray *)messages visibleMessages:(NSArray *)visibleMessages error:(NSError **)error;
+ (BOOL)containsPlaceholder:(id)value;
+ (NSString *)usageReport:(NSDictionary *)statistics providerUsage:(NSDictionary *)usage;
@end

// Per-run frozen network history. Original transcripts remain the source of truth.
// A new checkpoint is built only under budget pressure or after a prefix change.
@interface TFAIContextSessionProjection : NSObject
- (NSArray *)project:(NSArray *)messages transient:(NSArray *)transient connection:(NSDictionary *)connection schemas:(NSArray *)schemas statistics:(NSDictionary **)statistics error:(NSError **)error;
@end

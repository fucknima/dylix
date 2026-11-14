#import <Foundation/Foundation.h>

// Native metadata is kept out of provider wire schemas. Missing declarations fail closed.
@interface TFAIToolRegistry : NSObject
+ (NSArray<NSString *> *)modules;
+ (NSArray<NSString *> *)toolNames;
+ (NSSet<NSString *> *)disabledTools:(NSString *)root;
+ (void)setTool:(NSString *)name enabled:(BOOL)enabled root:(NSString *)root;
+ (BOOL)enabled:(NSString *)module;
+ (void)setEnabled:(BOOL)enabled module:(NSString *)module;
+ (NSDictionary *)descriptor:(NSString *)name;
+ (NSArray<NSDictionary *> *)entries:(NSArray *)schemas context:(NSDictionary *)context;
+ (NSArray<NSDictionary *> *)schemas:(NSArray *)schemas context:(NSDictionary *)context;
+ (NSDictionary *)actionCatalog:(NSDictionary *)catalog context:(NSDictionary *)context;
+ (BOOL)preflight:(NSDictionary *)call schemas:(NSArray *)schemas context:(NSDictionary *)context error:(NSError **)error;
@end

#import "../AIContracts.h"
@interface TFAIMCP : NSObject
+ (instancetype)shared;
- (NSArray<NSDictionary *> *)servers;
- (BOOL)importJSON:(NSString *)text error:(NSError **)error;
- (BOOL)setEnvironment:(NSDictionary *)environment server:(NSString *)identifier error:(NSError **)error;
- (NSDictionary *)diagnostics:(NSString *)identifier session:(NSString *)session;
- (void)remove:(NSString *)identifier;
- (void)setEnabled:(BOOL)enabled server:(NSString *)identifier session:(NSString *)session;
- (BOOL)enabled:(NSString *)identifier session:(NSString *)session;
- (BOOL)setAllowed:(BOOL)allowed tool:(NSString *)name server:(NSString *)identifier error:(NSError **)error;
- (void)discover:(NSString *)identifier completion:(TFAIResult)completion;
- (void)discover:(NSString *)identifier session:(NSString *)session launchApproved:(BOOL)approved completion:(TFAIResult)completion;
- (NSArray *)schemas:(NSString *)session;
- (void)call:(NSString *)name arguments:(NSDictionary *)arguments session:(NSString *)session completion:(TFAIResult)completion;
+ (BOOL)availableTool:(NSDictionary *)tool;
- (NSDictionary *)approvalInfo:(NSString *)name session:(NSString *)session;
- (void)call:(NSString *)name arguments:(NSDictionary *)arguments session:(NSString *)session approved:(BOOL)approved completion:(TFAIResult)completion;
+ (BOOL)readOnlyTool:(NSDictionary *)tool;
@end

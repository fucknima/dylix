#import <Foundation/Foundation.h>
@interface TFAIAgentContext : NSObject
+ (NSArray<NSDictionary *> *)skills:(NSString *)root;
+ (NSDictionary *)readSkill:(NSString *)identifier root:(NSString *)root error:(NSError **)error;
+ (BOOL)installSkills:(NSString *)root error:(NSError **)error;
+ (NSString *)metadata:(NSString *)root;
+ (NSString *)memory:(NSString *)root error:(NSError **)error;
+ (BOOL)saveMemory:(NSString *)text root:(NSString *)root expected:(NSString *)expected error:(NSError **)error;
+ (BOOL)appendDaily:(NSString *)text identifier:(NSString *)identifier expected:(NSString *)expected error:(NSError **)error;
+ (NSArray<NSDictionary *> *)memoryEntries:(NSString *)root query:(NSString *)query;
+ (NSString *)readNote:(NSString *)identifier root:(NSString *)root error:(NSError **)error;
+ (BOOL)saveNote:(NSString *)text identifier:(NSString *)identifier root:(NSString *)root expected:(NSString *)expected error:(NSError **)error;
+ (NSDictionary *)memoryResult:(NSDictionary *)arguments root:(NSString *)root error:(NSError **)error;
+ (NSString *)fingerprint:(NSString *)text;
+ (NSArray *)compact:(NSArray *)messages root:(NSString *)root session:(NSString *)session error:(NSError **)error;
@end

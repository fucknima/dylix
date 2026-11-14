#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *const TFAIPersonaDidChangeNotification;
FOUNDATION_EXPORT NSString *const TFAIPersonaBeginMarker;
FOUNDATION_EXPORT NSString *const TFAIPersonaEndMarker;
FOUNDATION_EXPORT NSArray *TFAIPersonasSorted(NSArray *items);
FOUNDATION_EXPORT NSString *TFAIPersonaModeLabel(NSString *mode);

// Persona is an optional layer; developer prompt and identity/Soul stay separate.
@interface TFAIPersona : NSObject
@property(nonatomic,readonly,copy) NSString *identifier,*name,*body,*mode;
@property(nonatomic,readonly,copy) NSString *builtinKey,*summary,*replyPrefix,*selfCheckCommand,*selfCheckReply;
@property(nonatomic,readonly,copy) NSString *generation;
@property(nonatomic,readonly,copy) NSArray<NSString *> *modelPatterns,*providerIDs;
@property(nonatomic,readonly) NSInteger matchPriority;
@property(nonatomic,readonly) BOOL isBuiltin,pinned;
@property(nonatomic,readonly) NSTimeInterval updatedAt;
@property(nonatomic,readonly) NSUInteger byteCount;
- (nullable instancetype)initWithJSON:(NSDictionary *)json;
- (NSDictionary *)JSON;
@end

@interface TFAIPersonaStore : NSObject
+ (instancetype)shared;
- (instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithURL:(NSURL *)url builtinsURL:(nullable NSURL *)builtinsURL;
@property(nonatomic,readonly) BOOL enabled;
@property(nonatomic,readonly,copy) NSArray<TFAIPersona *> *personas;
@property(nonatomic,readonly,copy) NSArray<TFAIPersona *> *builtins;
@property(nonatomic,readonly,copy,nullable) NSString *activeID;
@property(nonatomic,readonly,nullable) NSError *loadError;
- (NSDictionary *)snapshot;
- (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error;
- (BOOL)setMatchingMode:(NSString *)mode error:(NSError **)error;
- (BOOL)setIncludeDeveloperPrompt:(BOOL)include error:(NSError **)error;
- (BOOL)activateOnly:(nullable NSString *)identifier error:(NSError **)error;
- (BOOL)saveName:(NSString *)name body:(NSString *)body mode:(NSString *)mode identifier:(nullable NSString *)identifier error:(NSError **)error;
- (BOOL)saveName:(NSString *)name body:(NSString *)body mode:(NSString *)mode summary:(NSString *)summary replyPrefix:(NSString *)prefix selfCheckCommand:(NSString *)command selfCheckReply:(NSString *)reply identifier:(nullable NSString *)identifier error:(NSError **)error;
- (BOOL)setTailEnabled:(BOOL)enabled error:(NSError **)error;
- (BOOL)resetBuiltin:(NSString *)identifier error:(NSError **)error;
- (BOOL)restoreBuiltins:(NSError **)error;
- (BOOL)remove:(NSString *)identifier error:(NSError **)error;
- (BOOL)setPinned:(BOOL)pinned identifier:(NSString *)identifier error:(NSError **)error;
- (NSString *)statusBadge;
@end

@interface TFAIPersonaEngine : NSObject
+ (NSString *)strip:(NSString *)text;
+ (NSString *)wrap:(NSString *)body;
+ (nullable NSDictionary *)active:(NSDictionary *)snapshot;
+ (nullable NSDictionary *)recommended:(NSDictionary *)snapshot connection:(nullable NSDictionary *)connection;
+ (nullable NSDictionary *)effective:(NSDictionary *)snapshot connection:(nullable NSDictionary *)connection;
+ (NSString *)build:(NSString *)developerPrompt snapshot:(NSDictionary *)snapshot;
+ (NSString *)build:(NSString *)developerPrompt snapshot:(NSDictionary *)snapshot connection:(nullable NSDictionary *)connection;
+ (nullable NSString *)selfCheckResponse:(NSArray<NSDictionary *> *)messages snapshot:(NSDictionary *)snapshot;
+ (nullable NSString *)selfCheckResponse:(NSArray<NSDictionary *> *)messages snapshot:(NSDictionary *)snapshot connection:(nullable NSDictionary *)connection;
+ (NSDictionary *)preview:(NSString *)developerPrompt snapshot:(NSDictionary *)snapshot;
+ (NSDictionary *)preview:(NSString *)developerPrompt snapshot:(NSDictionary *)snapshot connection:(nullable NSDictionary *)connection;
@end
// Last request base is kept in memory only, never in persona JSON or chat history.
FOUNDATION_EXPORT void TFAIPersonaRecordRequest(NSString *developerPrompt, NSString *system);
FOUNDATION_EXPORT void TFAIPersonaRecordRequestConnection(NSString *developerPrompt, NSString *system, NSDictionary * _Nullable connection);
FOUNDATION_EXPORT NSDictionary *TFAIPersonaRequestPreviewContext(void);
NS_ASSUME_NONNULL_END

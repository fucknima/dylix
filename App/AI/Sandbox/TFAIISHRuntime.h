#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// An embedded Linux runtime. No host subprocess, shell fallback, or live project mount.
@interface TFAIISHRuntime : NSObject
+ (instancetype)shared;
+ (BOOL)available;
+ (NSDictionary *)executeSchema;
+ (NSDictionary *)importSchema;
+ (NSDictionary *)exportSchema;
+ (NSArray<NSDictionary *> *)processSchemas;
+ (BOOL)developerToolsAvailable;
+ (BOOL)reverseToolsAvailable;
- (void)installReverseTools:(NSString *)session completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
- (void)analyzeBinaryFile:(NSURL *)file arguments:(NSDictionary *)arguments session:(NSString *)session completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
- (void)installDeveloperTools:(NSString *)session completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
- (void)performProcess:(NSString *)operation arguments:(NSDictionary *)arguments session:(NSString *)session completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
- (void)preview:(NSString *)processID port:(NSInteger)port path:(NSString *)path session:(NSString *)session completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
- (BOOL)ownsPreviewURL:(NSURL *)url process:(NSString *)processID session:(NSString *)session;
- (NSArray<NSDictionary *> *)processes:(NSString *)session;
- (void)prepareSession:(NSString *)session completion:(void (^)(NSError *_Nullable))completion;
- (void)execute:(NSString *)command session:(NSString *)session timeout:(NSTimeInterval)timeout
        output:(void (^_Nullable)(NSData *))output completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
- (void)openTerminal:(NSString *)session columns:(int)columns rows:(int)rows
         completion:(void (^)(NSError *_Nullable))completion;
- (void)writeTerminal:(NSString *)session data:(NSData *)data;
- (void)resizeTerminal:(NSString *)session columns:(int)columns rows:(int)rows;
- (NSData *)terminalReplay:(NSString *)session;
- (void)closeTerminal:(NSString *)session;
- (void)cancelCommands:(NSString *)session;
- (NSDictionary *)status:(NSString *)session;
/// Copies only explicitly selected local files into guest /workspace/imports, through the VFS.
- (void)importFile:(NSURL *)file name:(NSString *)name session:(NSString *)session completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
- (void)exportFile:(NSString *)path session:(NSString *)session completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
/// VFS-only browsing and bounded UTF-8 editing. Never touches host project paths.
- (void)fileOperation:(NSString *)operation path:(NSString *)path arguments:(NSDictionary *)arguments session:(NSString *)session completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
/// Structured guest executable, raw stdin/stdout/stderr, never a host subprocess.
- (void)openStdio:(NSString *)executable arguments:(NSArray<NSString *> *)arguments session:(NSString *)session completion:(void (^)(NSString *_Nullable,NSError *_Nullable))completion;
- (void)openStdio:(NSString *)executable arguments:(NSArray<NSString *> *)arguments environment:(NSDictionary<NSString *,NSString *> *)environment session:(NSString *)session completion:(void (^)(NSString *_Nullable,NSError *_Nullable))completion;
- (void)stdio:(NSString *)identifier input:(NSData *_Nullable)input session:(NSString *)session completion:(void (^)(NSDictionary *_Nullable,NSError *_Nullable))completion;
- (BOOL)isStdioRunning:(NSString *)identifier session:(NSString *)session;
- (void)closeStdio:(NSString *)identifier session:(NSString *)session;
@end

FOUNDATION_EXPORT NSNotificationName const TFAIISHTerminalOutput;
FOUNDATION_EXPORT NSNotificationName const TFAIISHStatusChanged;
NS_ASSUME_NONNULL_END

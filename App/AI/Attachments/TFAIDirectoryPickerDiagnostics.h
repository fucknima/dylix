#import <Foundation/Foundation.h>
// These are on-disk declared metadata checks, not a signature/trust verifier.
NSDictionary *TFAIDirectorySigningChecks(NSString *bundleID, NSDictionary *entitlements, NSDictionary *profile);
NSDictionary *TFAIDirectoryPickerDiagnostics(void);

// Returns nil when metadata is unavailable or no definite mismatch was found.
FOUNDATION_EXPORT NSString *TFAIDirectorySigningWarning(NSDictionary *checks);

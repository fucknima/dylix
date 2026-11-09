#import <Foundation/Foundation.h>
NSDictionary *TFAIBinaryStage(NSData *data,NSString *name,NSError **error);
NSArray<NSDictionary *> *TFAIBinarySchemas(void);
NSArray<NSDictionary *> *TFAIObfuscationSchemas(void) __attribute__((weak_import));
NSDictionary *TFAIBinaryExecute(NSString *identifier,NSDictionary *arguments,NSError **error);
NSDictionary *TFAIBinaryParse(NSData *data,NSDictionary *arguments,NSError **error);

NSSet *TFAIBinarySelectedIDs(NSDictionary *references);

/// Returns only a hash-validated selected staging file; caller must copy, never mutate.
FOUNDATION_EXPORT NSURL *TFAIBinaryInputURL(NSString *identifier,NSError **error);

// Verified, decrypted ARM64/arm64e thin copy; never forwards an ambiguous FAT image.
FOUNDATION_EXPORT NSURL *TFAIBinarySliceURL(NSString *identifier,NSUInteger slice,NSError **error);

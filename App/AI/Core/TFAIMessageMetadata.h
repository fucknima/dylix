#import <Foundation/Foundation.h>
NSArray<NSDictionary *> *TFAIMessageMetadata(NSArray<NSDictionary *> *messages,NSDictionary *legacyTimes);
BOOL TFAIValidMessageTime(id value);

// User-authored text only; attachment/context payload remains in content for the model.
NSString *TFAIMessageVisibleText(NSDictionary *message);
NSString *TFAIMessageUserPayload(NSDictionary *message);

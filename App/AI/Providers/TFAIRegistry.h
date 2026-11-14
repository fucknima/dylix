#import <Foundation/Foundation.h>
NSArray<NSDictionary *> *TFAIProviderRegistry(void);
NSDictionary *TFAIProvider(NSString *identifier);
NSString *TFAIWireProtocol(NSString *identifier);
NSArray<NSDictionary *> *TFAIFamilyReasoningOptions(NSDictionary *connection);
NSDictionary *TFAIObservedCapabilities(NSDictionary *connection);
NSString *TFAIConnectionCaption(NSDictionary *connection);

NSString *TFAINormalizedModelID(NSString *model);
NSString *TFAIModelMetadataScope(NSDictionary *connection);
NSString *TFAICapabilityScope(NSDictionary *connection);
NSDictionary *TFAISanitizeModelMetadata(id row);
NSDictionary *TFAIModelMetadata(NSDictionary *connection);
NSDictionary *TFAIResolvedCapability(NSDictionary *connection,NSString *capability);
BOOL TFAIToolsAllowed(NSDictionary *connection);
NSArray<NSString *> *TFAIThinkingWires(NSString *protocol);
NSArray<NSString *> *TFAIThinkingLevelsForWire(NSString *wire);

// Unknown is permitted to try; diagnostics never grant or revoke tool permissions.
BOOL TFAIImagesAllowed(NSDictionary *connection);
NSDictionary *TFAICatalogModelMetadata(NSDictionary *connection);

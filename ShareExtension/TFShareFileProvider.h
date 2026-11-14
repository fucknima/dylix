#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

BOOL TFShareProviderHasFile(NSItemProvider *provider);
// Consume/copy the URL synchronously: provider access expires after this callback.
void TFShareLoadFile(NSItemProvider *provider, void (^consume)(NSURL * _Nullable, NSString * _Nullable, NSError * _Nullable));

NS_ASSUME_NONNULL_END

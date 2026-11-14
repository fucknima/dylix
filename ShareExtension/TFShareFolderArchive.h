#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Produces a private temporary ZIP snapshot. Caller removes its parent directory.
NSURL * _Nullable TFShareFolderArchive(NSURL *folder, NSString *name, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END

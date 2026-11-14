#import "TFShareFileProvider.h"
#import "TFShareFolderArchive.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSError *FileError(NSString *message) {
    return [NSError errorWithDomain:@"TweakForge.Share" code:3 userInfo:@{NSLocalizedDescriptionKey:message}];
}
BOOL TFShareProviderHasFile(NSItemProvider *provider) {
    return [provider hasItemConformingToTypeIdentifier:UTTypeFileURL.identifier] ||
           [provider hasItemConformingToTypeIdentifier:UTTypeFolder.identifier] ||
           [provider hasItemConformingToTypeIdentifier:UTTypeData.identifier];
}
static void ConsumeURL(NSURL *url, NSString *suggestedName, void (^consume)(NSURL *, NSString *, NSError *)) {
    if (![url isKindOfClass:NSURL.class] || !url.isFileURL || (url.host.length && ![url.host isEqual:@"localhost"])) {
        consume(nil,nil,FileError(@"来源未提供本地文件，请在「文件」App 中分享文件本身。"));return;
    }
    BOOL scoped=[url startAccessingSecurityScopedResource];
    @try {
        // Reject links before coordination as well as at the coordinated URL.
        NSError *error=nil;
        NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        // Missing attributes can mean an iCloud placeholder; coordination must
        // get a chance to materialize it. An existing link is always rejected.
        if (attrs && ![attrs[NSFileType] isEqual:NSFileTypeRegular] && ![attrs[NSFileType] isEqual:NSFileTypeDirectory]) {
            consume(nil,nil,FileError(@"不接收符号链接或特殊文件；请分享原始文件或文件夹。"));return;
        }
        NSFileCoordinator *coordinator=[[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block BOOL called=NO;
        [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingWithoutChanges error:&error byAccessor:^(NSURL *readURL) {
            called=YES;
            NSError *readError=nil;
            NSDictionary *readAttrs=[NSFileManager.defaultManager attributesOfItemAtPath:readURL.path error:&readError];
            BOOL directory=[readAttrs[NSFileType] isEqual:NSFileTypeDirectory];
            if(!directory && ![readAttrs[NSFileType] isEqual:NSFileTypeRegular]) {
                consume(nil,nil,readError?:FileError(@"不接收符号链接或特殊文件；请分享原始文件或文件夹。"));return;
            }
            NSString *name=suggestedName.length?suggestedName:url.lastPathComponent;
            if (![name isEqual:name.lastPathComponent] || [name containsString:@"\\"] || [name hasPrefix:@"."] ||
                [name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound) name=url.lastPathComponent;
            if(directory){
                NSURL *snapshot=TFShareFolderArchive(readURL,name,&readError);
                @try {consume(snapshot,snapshot.lastPathComponent,readError);}
                @finally {if(snapshot)[NSFileManager.defaultManager removeItemAtURL:snapshot.URLByDeletingLastPathComponent error:nil];}
            }else consume(readURL,name,nil);
        }];
        if (!called) consume(nil,nil,error?:FileError(@"文件不可读取，请先下载到本机后重新分享。"));
    } @finally { if(scoped)[url stopAccessingSecurityScopedResource]; }
}
void TFShareLoadFile(NSItemProvider *provider, void (^consume)(NSURL *, NSString *, NSError *)) {
    if ([provider hasItemConformingToTypeIdentifier:UTTypeFileURL.identifier]) {
        // public.file-url conforms to public.data, but its DATA representation is
        // the URL text, not the file. Never fall back to that placeholder.
        [provider loadItemForTypeIdentifier:UTTypeFileURL.identifier options:nil completionHandler:^(id item,NSError *error) {
            if(error){consume(nil,nil,error);return;}
            NSURL *url=nil;
            if([item isKindOfClass:NSURL.class])url=item;
            else if([item isKindOfClass:NSData.class])url=[NSURL absoluteURLWithDataRepresentation:item relativeToURL:nil];
            else if([item isKindOfClass:NSString.class])url=[NSURL URLWithString:item];
            ConsumeURL(url,nil,consume);
        }];return;
    }
    NSString *identifier=nil;
    if([provider hasItemConformingToTypeIdentifier:UTTypeFolder.identifier])identifier=UTTypeFolder.identifier;
    for(NSString *candidate in provider.registeredTypeIdentifiers) {
        if(identifier)break;
        UTType *type=[UTType typeWithIdentifier:candidate];
        if([type conformsToType:UTTypeData] && ![type conformsToType:UTTypeURL] && ![candidate isEqual:UTTypeData.identifier]) {identifier=candidate;break;}
    }
    if(!identifier && [provider hasItemConformingToTypeIdentifier:UTTypeData.identifier])identifier=UTTypeData.identifier;
    if(!identifier){consume(nil,nil,FileError(@"来源未提供文件副本。"));return;}
    [provider loadFileRepresentationForTypeIdentifier:identifier completionHandler:^(NSURL *url,NSError *error) {
        if(error){consume(nil,nil,error);return;}
        NSString *name=provider.suggestedName;
        // Keep a concrete temporary extension if the provider suggests only a stem.
        if(name.length && !name.pathExtension.length && url.pathExtension.length)name=[name stringByAppendingPathExtension:url.pathExtension];
        ConsumeURL(url,name,consume);
    }];
}

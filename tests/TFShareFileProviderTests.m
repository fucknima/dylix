#import "../ShareExtension/TFShareFileProvider.h"
#import "../App/ArchiveImport.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "../Vendor/libarchive-headers/archive.h"
#import "../Vendor/libarchive-headers/archive_entry.h"
#import <fcntl.h>
#import <unistd.h>
@interface FileProviderFixture:NSItemProvider
@property id value;
@property NSArray *types;
@property NSString *requested;
@property BOOL fileCalled;
@property NSURL *temporaryURL;
@end
@implementation FileProviderFixture
- (NSArray *)registeredTypeIdentifiers{return self.types;}
- (BOOL)hasItemConformingToTypeIdentifier:(NSString *)type {for(NSString *candidate in self.types)if([[UTType typeWithIdentifier:candidate] conformsToType:[UTType typeWithIdentifier:type]])return YES;return NO;}
- (void)loadItemForTypeIdentifier:(NSString *)type options:(NSDictionary *)options completionHandler:(NSItemProviderCompletionHandler)completion {self.requested=type;completion(self.value,nil);}
- (NSProgress *)loadFileRepresentationForTypeIdentifier:(NSString *)type completionHandler:(void (^)(NSURL *,NSError *))completion {self.requested=type;self.fileCalled=YES;completion(self.temporaryURL,nil);[NSFileManager.defaultManager removeItemAtURL:self.temporaryURL error:nil];return [NSProgress progressWithTotalUnitCount:1];}
@end
static int checks=0;
static void Check(BOOL condition,NSString *message){checks++;if(!condition){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
static NSDictionary *ZipContents(NSURL *url){
 struct archive *a=archive_read_new();archive_read_support_format_zip(a);Check(archive_read_open_filename(a,url.fileSystemRepresentation,65536)==ARCHIVE_OK,@"folder ZIP readable");NSMutableDictionary *items=[NSMutableDictionary new];struct archive_entry *e;int result;
 while((result=archive_read_next_header(a,&e))==ARCHIVE_OK){NSString *name=@(archive_entry_pathname(e));Check(!archive_entry_symlink(e)&&!archive_entry_hardlink(e),@"snapshot has no links");if(archive_entry_filetype(e)==AE_IFDIR)items[name]=@"directory";else {NSMutableData *data=[NSMutableData data];char buf[4096];la_ssize_t n;while((n=archive_read_data(a,buf,sizeof(buf)))>0)[data appendBytes:buf length:n];Check(n==0,@"ZIP payload complete");items[name]=data;}}
 Check(result==ARCHIVE_EOF,@"ZIP complete to end");archive_read_free(a);return items;
}
static NSURL *CopyProvider(NSItemProvider *provider,NSString *folder,BOOL success){
 __block BOOL done=NO;__block NSURL *target=nil;__block NSError *failure=nil;
 TFShareLoadFile(provider,^(NSURL *url,NSString *name,NSError *error){failure=error;if(url&&!error){[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&failure];target=[NSURL fileURLWithPath:[folder stringByAppendingPathComponent:name]];[NSFileManager.defaultManager copyItemAtURL:url toURL:target error:&failure];}done=YES;});
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:10];while(!done&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
 Check(done,@"provider callback completed");Check(success?target&&!failure:failure!=nil,@"expected file result");return target;
}
int main(int argc,const char **argv){@autoreleasepool{
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
 NSURL *source=[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"KOOKNoAds.xm"]];NSData *bytes=argc>1?[NSData dataWithContentsOfFile:@(argv[1])]:[@"// import fixture\n" dataUsingEncoding:NSUTF8StringEncoding];Check(bytes.length>0,@"fixture loaded");[bytes writeToURL:source atomically:YES];
 NSUInteger i=0;for(id item in @[source,source.dataRepresentation,source.absoluteString]){
 FileProviderFixture *p=[FileProviderFixture new];p.types=@[UTTypeFileURL.identifier,UTTypeData.identifier];p.value=item;
 NSURL *copy=CopyProvider(p,[root stringByAppendingPathComponent:[NSString stringWithFormat:@"url-%lu",(unsigned long)i++]],YES);
 Check([p.requested isEqual:UTTypeFileURL.identifier]&&!p.fileCalled,@"file URL preferred over generic data");Check([copy.lastPathComponent isEqual:@"KOOKNoAds.xm"],@"source name preserved");Check([[NSData dataWithContentsOfURL:copy] isEqual:bytes],@"source bytes preserved");
 NSError *error=nil;NSDictionary *config=TMCPrepareImportedProject(copy.URLByDeletingLastPathComponent.path,@"KOOKNoAds",&error);Check(config&&!error,@"single xm creates project");NSDictionary *manifest=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[copy.URLByDeletingLastPathComponent.path stringByAppendingPathComponent:@"MobileCompiler.json"]] options:0 error:nil];Check([manifest[@"sources"] containsObject:@"KOOKNoAds.xm"],@"generated manifest includes actual xm");
 }
 for(id item in @[[NSURL URLWithString:@"https://example.com/source.xm"],[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"missing.xm"]],@42]){FileProviderFixture *p=[FileProviderFixture new];p.types=@[UTTypeFileURL.identifier];p.value=item;CopyProvider(p,[root stringByAppendingPathComponent:NSUUID.UUID.UUIDString],NO);Check(!p.fileCalled,@"invalid file URL never falls back to URL text");}
 NSString *link=[root stringByAppendingPathComponent:@"link.xm"];[NSFileManager.defaultManager createSymbolicLinkAtPath:link withDestinationPath:source.path error:nil];FileProviderFixture *p=[FileProviderFixture new];p.types=@[UTTypeFileURL.identifier];p.value=[NSURL fileURLWithPath:link];CopyProvider(p,[root stringByAppendingPathComponent:@"symlink"],NO);
 for(NSArray *types in @[@[UTTypeUTF8PlainText.identifier,UTTypeData.identifier],@[UTTypeData.identifier]]){FileProviderFixture *f=[FileProviderFixture new];f.types=types;f.suggestedName=@"Tweak.xm";f.temporaryURL=[NSURL fileURLWithPath:[root stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];[bytes writeToURL:f.temporaryURL atomically:YES];NSURL *copy=CopyProvider(f,[root stringByAppendingPathComponent:NSUUID.UUID.UUIDString],YES);Check([f.requested isEqual:types.firstObject],@"concrete file type preferred");Check([[NSData dataWithContentsOfURL:copy] isEqual:bytes],@"copied before temporary representation expires");Check([copy.lastPathComponent isEqual:@"Tweak.xm"],@"suggested filename preserved");}
 NSItemProvider *real=[[NSItemProvider alloc] initWithItem:source typeIdentifier:UTTypeFileURL.identifier];NSURL *copy=CopyProvider(real,[root stringByAppendingPathComponent:@"real"],YES);Check([[NSData dataWithContentsOfURL:copy] isEqual:bytes],@"real NSURL provider byte-exact");
 // Directory providers are snapshots, not external persistent directory grants.
 NSString *folder=[root stringByAppendingPathComponent:@"分享工程"];
 [NSFileManager.defaultManager createDirectoryAtPath:[folder stringByAppendingPathComponent:@"嵌套/空目录"] withIntermediateDirectories:YES attributes:nil error:nil];
 [bytes writeToFile:[folder stringByAppendingPathComponent:@"嵌套/Tweak.xm"] atomically:YES];
 [bytes writeToFile:[folder stringByAppendingPathComponent:@".hidden"] atomically:YES];
 FileProviderFixture *directory=[FileProviderFixture new];directory.types=@[UTTypeFileURL.identifier];directory.value=[NSURL fileURLWithPath:folder];
 Check(TFShareProviderHasFile(directory),@"file URL directory recognized");
 NSURL *z=CopyProvider(directory,[root stringByAppendingPathComponent:@"folder-import"],YES);Check([z.lastPathComponent isEqual:@"分享工程.zip"],@"folder name becomes ZIP");
 NSDictionary *items=ZipContents(z);Check([items[@"分享工程/嵌套/Tweak.xm"] isEqual:bytes],@"nested source byte-exact");Check([items[@"分享工程/.hidden"] isEqual:bytes],@"hidden files preserved");Check([items[@"分享工程/嵌套/空目录/"] isEqual:@"directory"],@"empty folders preserved");
 Check([NSFileManager.defaultManager fileExistsAtPath:[folder stringByAppendingPathComponent:@"嵌套/Tweak.xm"]],@"source directory untouched");
 FileProviderFixture *folderType=[FileProviderFixture new];folderType.types=@[UTTypeFolder.identifier];folderType.suggestedName=@"Project";folderType.temporaryURL=[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"temporary-folder"]];[NSFileManager.defaultManager copyItemAtPath:folder toPath:folderType.temporaryURL.path error:nil];
 Check(TFShareProviderHasFile(folderType),@"folder-only provider recognized");NSURL *fz=CopyProvider(folderType,[root stringByAppendingPathComponent:@"folder-only-import"],YES);Check([fz.lastPathComponent isEqual:@"Project.zip"],@"folder UTI uses file representation");Check([ZipContents(fz)[@"Project/嵌套/Tweak.xm"] isEqual:bytes],@"folder-only provider copied before expiry");
 [NSFileManager.defaultManager createSymbolicLinkAtPath:[folder stringByAppendingPathComponent:@"outside"] withDestinationPath:source.path error:nil];CopyProvider(directory,[root stringByAppendingPathComponent:@"nested-link-rejected"],NO);[NSFileManager.defaultManager removeItemAtPath:[folder stringByAppendingPathComponent:@"outside"] error:nil];
 NSString *tooBig=[folder stringByAppendingPathComponent:@"large.bin"];int fd=open(tooBig.fileSystemRepresentation,O_CREAT|O_WRONLY,0600);Check(fd>=0&&ftruncate(fd,512LL*1024*1024+1)==0,@"oversize sparse fixture");close(fd);CopyProvider(directory,[root stringByAppendingPathComponent:@"oversize-rejected"],NO);[NSFileManager.defaultManager removeItemAtPath:tooBig error:nil];
 __block NSURL *temporaryZip=nil;TFShareLoadFile(directory,^(NSURL *url,NSString *name,NSError *error){Check(url&&!error,@"directory callback has snapshot");temporaryZip=url;Check([NSFileManager.defaultManager fileExistsAtPath:url.path],@"snapshot exists inside callback");});Check(temporaryZip&&![NSFileManager.defaultManager fileExistsAtPath:temporaryZip.URLByDeletingLastPathComponent.path],@"snapshot cleaned after callback");
 [NSFileManager.defaultManager removeItemAtPath:root error:nil];printf("PASS: %d file-provider/import checks (%lu-byte fixture)\n",checks,(unsigned long)bytes.length);return 0;
}}

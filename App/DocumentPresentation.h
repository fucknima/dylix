#import <Foundation/Foundation.h>
#import <sys/stat.h>

// Internal identifiers remain stable. Files.app sees named receipts and exports,
// while work directories keep their original paths for sessions and build tools.
static inline BOOL TMCRegularDocument(NSString *path,BOOL directory){struct stat st;return path.length&&lstat(path.fileSystemRepresentation,&st)==0&&(directory?S_ISDIR(st.st_mode):S_ISREG(st.st_mode));}
static inline BOOL TMCDocumentUUID(id value){return [value isKindOfClass:NSString.class]&&[[NSUUID alloc]initWithUUIDString:value]!=nil;}
static inline NSDictionary *TMCDocumentJSON(NSString *path){if(!TMCRegularDocument(path,NO))return @{};NSDictionary *a=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];if([a[NSFileSize] unsignedLongLongValue]>1024*1024)return @{};id v=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]?:NSData.data options:0 error:nil];return [v isKindOfClass:NSDictionary.class]?v:@{};}
static inline NSString *TMCDocumentSafeName(NSString *name){
 if(![name isKindOfClass:NSString.class])name=@"";NSMutableString *out=[NSMutableString new];
 [name enumerateSubstringsInRange:NSMakeRange(0,name.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *s,NSRange a,NSRange b,BOOL *stop){if([out lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+[s lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>100){*stop=YES;return;}if([s rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound&&![s containsString:@"/"]&&![s containsString:@"\\"]&&![s containsString:@":"])[out appendString:s];}];
 NSString *clean=[out stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" .\n\t"]];return clean.length?clean:@"未命名文件";
}
static inline BOOL TMCDocumentHide(NSString *path){if(!TMCRegularDocument(path,YES)&&!TMCRegularDocument(path,NO))return NO;return [[NSURL fileURLWithPath:path] setResourceValue:@YES forKey:NSURLIsHiddenKey error:nil];}
static inline BOOL TMCDocumentWorkspace(NSString *name){
 if([@[@"AIClassDumpInputs",@"Incoming",@"ClassDumpExports"] containsObject:name])return YES;
 for(NSString *prefix in @[@"Build-",@"Snapshot-",@"Imported-",@"ClassDump-"])if([name hasPrefix:prefix]){NSString *suffix=[name substringFromIndex:prefix.length];if(TMCDocumentUUID(suffix))return YES;if([prefix isEqual:@"ClassDump-"]&&suffix.length==82&&TMCDocumentUUID([suffix substringToIndex:36])&&[[suffix substringFromIndex:36] hasPrefix:@".previous-"]&&TMCDocumentUUID([suffix substringFromIndex:46]))return YES;}
 return NO;
}
static inline BOOL TMCDocumentUserDirectory(NSString *path,NSError **error){
 if([NSFileManager.defaultManager fileExistsAtPath:path]&&!TMCRegularDocument(path,YES))return NO;
 NSString *expected=[path.stringByStandardizingPath.stringByDeletingLastPathComponent.stringByResolvingSymlinksInPath stringByAppendingPathComponent:path.lastPathComponent];if(![path.stringByResolvingSymlinksInPath isEqual:expected])return NO;
 return [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]&&TMCRegularDocument(path,YES);
}
static inline NSString *TMCDocumentStamp(NSString *path){NSDate *date=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileCreationDate]?:NSDate.date;NSDateFormatter *f=[NSDateFormatter new];f.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];f.dateFormat=@"yyyy-MM-dd HHmmss";return [f stringFromDate:date];}
static inline NSString *TMCDocumentProjectName(NSString *root){
 if(!TMCRegularDocument(root,YES))return nil;NSString *name=TMCDocumentJSON([root stringByAppendingPathComponent:@"MobileCompiler.json"])[@"name"];
 if([name isKindOfClass:NSString.class]&&name.length)return name;
 NSString *control=[root stringByAppendingPathComponent:@"control"];NSDictionary *a=[NSFileManager.defaultManager attributesOfItemAtPath:control error:nil];if(TMCRegularDocument(control,NO)&&[a[NSFileSize] unsignedLongLongValue]<65536)for(NSString *line in [[NSString stringWithContentsOfFile:control encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByString:@"\n"])if([line hasPrefix:@"Name:"])return [[line substringFromIndex:5] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
 return [root.lastPathComponent hasPrefix:@"Imported-"]?@"历史导入项目":root.lastPathComponent;
}
static inline NSString *TMCDocumentInputName(NSString *docs,NSString *identifier){
 NSDictionary *meta=TMCDocumentJSON([[[docs stringByAppendingPathComponent:@"AIClassDumpInputs"] stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:@"metadata.json"]);
 NSString *name=meta[@"name"];if([name isKindOfClass:NSString.class]&&name.length)return name;
 meta=TMCDocumentJSON([[docs stringByAppendingPathComponent:[@"ClassDump-" stringByAppendingString:identifier]] stringByAppendingPathComponent:@".tweakforge-display-name.json"]);name=meta[@"name"];if([name isKindOfClass:NSString.class]&&name.length)return name;
 NSString *support=NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject;
 meta=TMCDocumentJSON([[[support stringByAppendingPathComponent:@"TweakForgeAI/Binaries"] stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:@"metadata.json"]);name=meta[@"name"];return [name isKindOfClass:NSString.class]&&name.length?name:@"应用";
}
static inline NSString *TMCDocumentDisplayName(NSString *path){
 NSString *raw=path.lastPathComponent;NSDictionary *meta=TMCDocumentJSON([path stringByAppendingPathComponent:@"receipt.json"]);NSString *name=meta[@"name"];if([name isKindOfClass:NSString.class]&&name.length)return name;
 meta=TMCDocumentJSON([path stringByAppendingPathComponent:@"metadata.json"]);name=meta[@"name"];if([name isKindOfClass:NSString.class]&&name.length)return name;
 if([raw hasPrefix:@"Build-"]&&TMCDocumentUUID([raw substringFromIndex:6])){meta=TMCDocumentJSON([path stringByAppendingPathComponent:@".studio-cache-owner.json"]);name=TMCDocumentProjectName(meta[@"project"]);return [NSString stringWithFormat:@"%@ · 构建 · %@",name?:@"项目",TMCDocumentStamp(path)];}
 if([raw hasPrefix:@"Snapshot-"]&&TMCDocumentUUID([raw substringFromIndex:9]))return [NSString stringWithFormat:@"%@ · 源码快照 · %@",TMCDocumentProjectName(path)?:@"项目",TMCDocumentStamp(path)];
 if([raw hasPrefix:@"Imported-"]&&TMCDocumentUUID([raw substringFromIndex:9]))return [NSString stringWithFormat:@"%@ · %@",TMCDocumentProjectName(path)?:@"历史导入项目",TMCDocumentStamp(path)];
 if([raw hasPrefix:@"ClassDump-"]&&raw.length>=46){NSString *identifier=[raw substringWithRange:NSMakeRange(10,36)];if(TMCDocumentUUID(identifier))return [NSString stringWithFormat:@"%@ · 头文件 · %@",TMCDocumentInputName(path.stringByDeletingLastPathComponent,identifier),TMCDocumentStamp(path)];}
 if(TMCDocumentUUID(raw.stringByDeletingPathExtension)&&[path.stringByDeletingLastPathComponent.lastPathComponent isEqual:@"ClassDumpExports"])return [NSString stringWithFormat:@"%@ · 头文件.zip",TMCDocumentInputName(path.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent,raw.stringByDeletingPathExtension)];
 return raw;
}
static inline NSDictionary *TMCDocumentPresentIncoming(NSString *docs,NSDictionary *record,NSError **error){
 @synchronized(NSFileManager.class){
 NSString *identifier=record[@"id"],*file=record[@"path"],*name=record[@"name"];if(!TMCDocumentUUID(identifier)||![file isKindOfClass:NSString.class]||![name isKindOfClass:NSString.class]||![name isEqual:name.lastPathComponent]||![file.lastPathComponent isEqual:name])return nil;
 NSFileManager *fm=NSFileManager.defaultManager;NSString *old=[[[docs stringByAppendingPathComponent:@"Incoming"] stringByAppendingPathComponent:identifier] stringByStandardizingPath];
 if(![fm fileExistsAtPath:old]){NSString *existing=[docs stringByAppendingPathComponent:@"接收文件"];if(TMCRegularDocument(existing,YES))for(NSString *entry in [fm contentsOfDirectoryAtPath:existing error:nil]){NSString *directory=[existing stringByAppendingPathComponent:entry];if(!TMCRegularDocument(directory,YES))continue;NSDictionary *saved=TMCDocumentJSON([directory stringByAppendingPathComponent:@"receipt.json"]);if([saved[@"id"] isEqual:identifier]&&[saved[@"name"] isEqual:name]&&[saved[@"path"] isEqual:[directory stringByAppendingPathComponent:name]]&&TMCRegularDocument(saved[@"path"],NO))return saved;}return nil;}
 if(![file.stringByDeletingLastPathComponent isEqual:old]||!TMCRegularDocument(old,YES)||!TMCRegularDocument(file,NO)||![old.stringByResolvingSymlinksInPath isEqual:[docs.stringByResolvingSymlinksInPath stringByAppendingPathComponent:[@"Incoming" stringByAppendingPathComponent:identifier]]])return nil;
 NSString *parent=[docs stringByAppendingPathComponent:@"接收文件"];if(!TMCDocumentUserDirectory(parent,error))return nil;
 NSString *folder=[NSString stringWithFormat:@"%@ · %@ · %@",TMCDocumentSafeName(name),TMCDocumentStamp(old),[identifier substringToIndex:8]],*dest=[parent stringByAppendingPathComponent:folder];if([fm fileExistsAtPath:dest])return nil;
 if(![fm moveItemAtPath:old toPath:dest error:error])return nil;
 NSMutableDictionary *updated=[record mutableCopy];updated[@"path"]=[dest stringByAppendingPathComponent:name];NSData *data=[NSJSONSerialization dataWithJSONObject:updated options:NSJSONWritingPrettyPrinted error:error];
 if(!data||![data writeToFile:[dest stringByAppendingPathComponent:@"receipt.json"] options:NSDataWritingAtomic error:error]){[fm moveItemAtPath:dest toPath:old error:nil];return nil;}
 TMCDocumentHide([dest stringByAppendingPathComponent:@"receipt.json"]);return updated;
 }
}
static inline BOOL TMCDocumentCopyOnce(NSString *source,NSString *target,NSError **error){
 NSFileManager *fm=NSFileManager.defaultManager;if(!TMCRegularDocument(source,NO))return NO;if([fm fileExistsAtPath:target])return TMCRegularDocument(target,NO);
 NSString *staging=[target.stringByDeletingLastPathComponent stringByAppendingPathComponent:[@".dylix-export-" stringByAppendingString:NSUUID.UUID.UUIDString]];if(![fm copyItemAtPath:source toPath:staging error:error]){[fm removeItemAtPath:staging error:nil];return NO;}
 BOOL ok=[fm moveItemAtPath:staging toPath:target error:error];if(!ok)[fm removeItemAtPath:staging error:nil];return ok;
}
static inline BOOL TMCDocumentPublishBuild(NSString *docs,NSString *build,NSError **error){
 @synchronized(NSFileManager.class){
 NSString *id=build.lastPathComponent;if(![build.stringByDeletingLastPathComponent isEqual:docs]||![id hasPrefix:@"Build-"]||!TMCDocumentUUID([id substringFromIndex:6])||!TMCRegularDocument(build,YES))return NO;
 TMCDocumentHide(build);if(!TMCRegularDocument([build stringByAppendingPathComponent:@"report.json"],NO))return NO;
 NSFileManager *fm=NSFileManager.defaultManager;NSMutableArray *files=[NSMutableArray new];for(NSString *file in [fm contentsOfDirectoryAtPath:build error:nil])if([@[@"deb",@"dylib"] containsObject:file.pathExtension.lowercaseString]&&TMCRegularDocument([build stringByAppendingPathComponent:file],NO))[files addObject:file];
 // Failed builds remain inspectable in the App; don't create empty public folders.
 if(!files.count)return YES;
 NSDictionary *owner=TMCDocumentJSON([build stringByAppendingPathComponent:@".studio-cache-owner.json"]);NSString *name=TMCDocumentProjectName(owner[@"project"]);if(!name.length)name=[files.firstObject stringByDeletingPathExtension];
 NSString *parent=[docs stringByAppendingPathComponent:@"构建产物"];if(!TMCDocumentUserDirectory(parent,error))return NO;
 NSString *saved=TMCDocumentJSON([build stringByAppendingPathComponent:@".dylix-published-name.json"])[@"name"];if(![saved isKindOfClass:NSString.class]||![saved isEqual:saved.lastPathComponent]||[saved hasPrefix:@"."])saved=nil;
 NSString *visible=saved?:[NSString stringWithFormat:@"%@ · %@ · %@",TMCDocumentSafeName(name),TMCDocumentStamp(build),[[id substringFromIndex:6] substringToIndex:8]],*dest=[parent stringByAppendingPathComponent:visible];
 if(saved&&![fm fileExistsAtPath:dest])return YES; // A user-removed export must not grow back on every launch.
 if(!TMCDocumentUserDirectory(dest,error))return NO;
 for(NSString *file in [files arrayByAddingObjectsFromArray:@[@"build.log",@"report.json"]]){NSString *source=[build stringByAppendingPathComponent:file],*target=[dest stringByAppendingPathComponent:[@{@"build.log":@"构建日志.txt",@"report.json":@"构建报告.json"} objectForKey:file]?:file];if(!TMCRegularDocument(source,NO))continue;if([fm fileExistsAtPath:target]){if(!TMCRegularDocument(target,NO))return NO;continue;}if(!TMCDocumentCopyOnce(source,target,error))return NO;}
 [[NSJSONSerialization dataWithJSONObject:@{@"name":visible} options:0 error:nil] writeToFile:[build stringByAppendingPathComponent:@".dylix-published-name.json"] atomically:YES];return YES;
 }
}
static inline BOOL TMCDocumentPublishHeaders(NSString *docs,NSString *identifier,NSString *name,NSString *zip,NSError **error){
 @synchronized(NSFileManager.class){
 if(!TMCDocumentUUID(identifier)||!TMCRegularDocument(zip,NO)||![zip.stringByDeletingLastPathComponent isEqual:[docs stringByAppendingPathComponent:@"ClassDumpExports"]])return NO;
 TMCDocumentHide(zip.stringByDeletingLastPathComponent);TMCDocumentHide([docs stringByAppendingPathComponent:[@"ClassDump-" stringByAppendingString:identifier]]);
 NSString *parent=[docs stringByAppendingPathComponent:@"头文件导出"];if(!TMCDocumentUserDirectory(parent,error))return NO;
 NSString *marker=[zip stringByAppendingString:@".published.json"],*saved=TMCDocumentJSON(marker)[@"name"];if(![saved isKindOfClass:NSString.class]||![saved isEqual:saved.lastPathComponent]||![saved.pathExtension isEqual:@"zip"]||[saved hasPrefix:@"."])saved=nil;
 NSString *file=saved?:[[NSString stringWithFormat:@"%@ · 头文件 · %@ · %@",TMCDocumentSafeName(name.stringByDeletingPathExtension),TMCDocumentStamp(zip),[identifier substringToIndex:8]] stringByAppendingPathExtension:@"zip"],*target=[parent stringByAppendingPathComponent:file];
 if(saved&&![NSFileManager.defaultManager fileExistsAtPath:target])return YES;
 BOOL ok=TMCDocumentCopyOnce(zip,target,error);if(ok)[[NSJSONSerialization dataWithJSONObject:@{@"name":file} options:0 error:nil] writeToFile:marker atomically:YES];return ok;
 }
}
static inline void TMCPrepareDocumentPresentation(NSString *docs){
 NSFileManager *fm=NSFileManager.defaultManager;for(NSString *name in [fm contentsOfDirectoryAtPath:docs error:nil]){
  if(TMCDocumentWorkspace(name)){NSString *path=[docs stringByAppendingPathComponent:name];if(TMCRegularDocument(path,YES))TMCDocumentHide(path);if([name hasPrefix:@"Build-"])TMCDocumentPublishBuild(docs,path,nil);}
 }
 NSString *incoming=[docs stringByAppendingPathComponent:@"Incoming"];if(TMCRegularDocument(incoming,YES)&&[incoming.stringByResolvingSymlinksInPath isEqual:[docs.stringByResolvingSymlinksInPath stringByAppendingPathComponent:@"Incoming"]])for(NSString *id in [fm contentsOfDirectoryAtPath:incoming error:nil])if(TMCDocumentUUID(id)){NSDictionary *record=TMCDocumentJSON([[incoming stringByAppendingPathComponent:id] stringByAppendingPathComponent:@"receipt.json"]);if([record[@"id"] isEqual:id])TMCDocumentPresentIncoming(docs,record,nil);}
 NSString *exports=[docs stringByAppendingPathComponent:@"ClassDumpExports"];if(TMCRegularDocument(exports,YES))for(NSString *file in [fm contentsOfDirectoryAtPath:exports error:nil])if([file.pathExtension isEqual:@"zip"]&&TMCDocumentUUID(file.stringByDeletingPathExtension))TMCDocumentPublishHeaders(docs,file.stringByDeletingPathExtension,TMCDocumentInputName(docs,file.stringByDeletingPathExtension),[exports stringByAppendingPathComponent:file],nil);
 NSString *readme=[docs stringByAppendingPathComponent:@"文件分类说明.txt"];
 if(![fm fileExistsAtPath:readme])[@"Dylix 文件分类\n\nProjects：项目源码。\n接收文件：收到的原文件，按原文件名、时间归档。\n构建产物：按项目、时间整理的 deb、dylib 和构建记录。\n头文件导出：按原应用名称整理的头文件 ZIP。\n\n内部编号不是乱码。构建快照、分析副本及历史导入工作目录已从普通浏览隐藏，原始路径和会话引用保持不变；可在 Dylix 的项目、会话文件及设置 → 存储空间中访问或清理。历史导入源码仍由项目列表管理。这里的产物是独立导出副本，不会因自动构建缓存清理而丢失。\n" writeToFile:readme atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

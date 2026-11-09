#import <Foundation/Foundation.h>
#import "TFAISessionResources.h"
#import "../Sandbox/TFAIISHExports.h"
#import "../Attachments/TFAIAttachmentStore.h"
#import "../Attachments/TFAIAttachmentNames.h"
#import "../ClassDump/TFAIClassDumpExecution.h"
static NSString *SFText(id value){return [value isKindOfClass:NSString.class]?value:@"";}
#import "../UI/TFAISessionFilePaths.h"
static NSDictionary *SFLocal(NSString *path,NSString *label){BOOL folder=NO;if(!path.length||!SFInside(path.stringByDeletingLastPathComponent,path)||![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&folder])return nil;return @{@"name":label.length?label:path.lastPathComponent,@"localPath":path,@"accessBoundary":path.stringByDeletingLastPathComponent.stringByResolvingSymlinksInPath,@"modified":@([[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileModificationDate] timeIntervalSince1970]),@"folder":@(folder),@"bytes":@([[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue])};}

NSArray *TFAISessionResourceIndex(NSDictionary *snapshot,NSString *project,NSString *directory,NSString *boundary,NSString *sourceMessageID){
NSMutableArray *items=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];__block NSString *origin=@"",*source=@"附件";__block NSNumber *fallbackTime=@0;void(^add)(NSDictionary *)=^(NSDictionary *item){if(!item)return;NSMutableDictionary *enriched=[item mutableCopy];enriched[@"messageID"]=origin?:@"";enriched[@"source"]=source;if(![enriched[@"modified"] doubleValue]&&fallbackTime.doubleValue>0){enriched[@"modified"]=fallbackTime;enriched[@"timeLabel"]=@"记录于";}enriched[@"category"]=item[@"category"]?:source;item=enriched;NSString *key=item[@"localPath"]?:[NSString stringWithFormat:@"%@/%@/%@",origin?:@"",item[@"name"]?:@"",item[@"category"]?:@""];if([seen containsObject:key])return;[seen addObject:key];[items addObject:item];};
 if(directory){if(SFInside(boundary,directory))for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil]){if([name hasPrefix:@"."])continue;NSString *path=SFPath(boundary,[[directory stringByAppendingPathComponent:name] substringFromIndex:boundary.length+1]);if(path){origin=sourceMessageID?:@"";add(SFLocal(path,TFAIAttachmentFolderName(path)));}}}
 else{
 NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
 for(NSDictionary *message in snapshot[@"messages"]){fallbackTime=[message[@"timestamp"] isKindOfClass:NSNumber.class]?message[@"timestamp"]:@0;origin=SFText(message[@"messageID"]);source=@"附件";NSArray *attachments=message[@"attachments"];NSDictionary *references=message[@"localAttachmentReferences"];for(NSDictionary *entry in attachments){source=@"附件";NSString *name=SFText(entry[@"path"]);NSMutableDictionary *item=[@{@"name":name.lastPathComponent.length?name.lastPathComponent:@"附件",@"category":entry[@"directoryGrant"]?@"目录授权 · 只读按需访问":@"参考附件",@"previewItem":entry} mutableCopy];for(NSDictionary *ref in references.allValues)if([ref[@"path"] isEqual:name]){NSMutableDictionary *preview=[entry mutableCopy];preview[@"preview"]=ref[@"content"]?:entry[@"preview"]?:@"";preview[@"previewTruncated"]=@NO;item[@"previewItem"]=preview;NSString *local=TFAIAttachmentLocalPath(([ref[@"localSnapshot"] isKindOfClass:NSDictionary.class]?ref[@"localSnapshot"]:nil),nil);NSDictionary *localItem=local.length?SFLocal(local,name.lastPathComponent):nil;if(localItem)[item addEntriesFromDictionary:localItem];break;}add(item);
 NSString *job=SFText(entry[@"classDumpJobID"]);if([[NSUUID alloc]initWithUUIDString:job]){source=@"头文件";add(SFLocal([docs stringByAppendingPathComponent:[@"ClassDump-" stringByAppendingString:job]],@"附件头文件"));add(SFLocal(TFAIClassDumpExportURL(job).path,@"附件头文件.zip"));}
 NSString *binary=SFText(entry[@"binaryInputID"]);if([[NSUUID alloc]initWithUUIDString:binary]){NSString *support=NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject;add(SFLocal([support stringByAppendingPathComponent:[NSString stringWithFormat:@"TweakForgeAI/Binaries/%@/input.dylib",binary]],name));}
 NSString *input=SFText(entry[@"classDumpInputID"]);if([[NSUUID alloc]initWithUUIDString:input])add(SFLocal([docs stringByAppendingPathComponent:[NSString stringWithFormat:@"AIClassDumpInputs/%@/input.ipa",input]],name));}
 NSUInteger index=0;for(NSDictionary *image in message[@"images"]){index++;add(@{@"name":[NSString stringWithFormat:@"图片 %lu",(unsigned long)index],@"category":@"图片",@"previewItem":@{@"kind":@"image",@"data":image[@"data"]?:@""}});}}
 for(NSDictionary *record in snapshot[@"processRecords"]){if(![record[@"status"] isEqual:@"completed"])continue;origin=SFText(record[@"assistantMessageID"]?:record[@"messageID"]);source=@"生成";fallbackTime=[record[@"startedAt"] isKindOfClass:NSNumber.class]?record[@"startedAt"]:@0;NSDictionary *result=[record[@"result"] isKindOfClass:NSDictionary.class]?record[@"result"]:@{},*args=[record[@"arguments"] isKindOfClass:NSDictionary.class]?record[@"arguments"]:@{};NSString *name=SFText(record[@"name"]),*job=SFText(result[@"jobID"]);if([[NSUUID alloc]initWithUUIDString:job]){source=@"头文件";add(SFLocal([docs stringByAppendingPathComponent:[@"ClassDump-" stringByAppendingString:job]],@"导出的头文件"));add(SFLocal(TFAIClassDumpExportURL(job).path,SFText(result[@"name"]).length?[SFText(result[@"name"]) stringByAppendingString:@" · 头文件.zip"]:@"头文件.zip"));}
 if([name isEqual:@"sandbox_export_file"]){NSURL *url=TFAIISHExportURL(result,SFText(snapshot[@"id"]));if(url){source=@"Linux 导出";add(SFLocal(url.path,result[@"name"]));source=@"生成";}}
 NSString *build=SFBuildPath(docs,result[@"buildID"]);if(build){source=@"构建";add(SFLocal(build,[NSString stringWithFormat:@"构建结果 · %@",[build.lastPathComponent substringToIndex:MIN(14,build.lastPathComponent.length)]]));for(id artifact in result[@"artifacts"]){if(![artifact isKindOfClass:NSDictionary.class])continue;NSString *file=SFText(artifact[@"name"]);if([@[@"deb",@"dylib"] containsObject:file.pathExtension])add(SFLocal(SFPath(build,file),file));}source=@"生成";}
 if([record[@"status"] isEqual:@"completed"]&&SFInside(docs,project)){
 if([@[@"create_file",@"download_file",@"extract_archive"] containsObject:name]){NSString *relative=[name isEqual:@"extract_archive"]?(result[@"directory"]?:args[@"destination"]):(result[@"path"]?:args[@"path"]);add(SFLocal(SFPath(project,SFText(relative)),nil));}
 for(NSDictionary *edit in result[@"edits"])if([edit isKindOfClass:NSDictionary.class])add(SFLocal(SFPath(project,SFText(edit[@"path"])),nil));
 if([@[@"apply_approved_patch",@"create_file"] containsObject:name]&&[result[@"files"] isKindOfClass:NSArray.class])for(id relative in result[@"files"])add(SFLocal(SFPath(project,SFText(relative)),nil));
 }}
 // Project files are explicit and separate from uploaded reference snapshots.
 origin=@"";source=@"项目";if(SFInside(docs,project))add(SFLocal(project,TFAIAttachmentFolderName(project)));
 }
 [items sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){BOOL af=[a[@"folder"] boolValue],bf=[b[@"folder"] boolValue];if(af!=bf)return af?NSOrderedAscending:NSOrderedDescending;NSComparisonResult date=[(b[@"modified"]?:@0) compare:(a[@"modified"]?:@0)];return date!=NSOrderedSame?date:[a[@"name"] localizedStandardCompare:b[@"name"]];}];
 return items;
}

// Project Remote runtime events into the same durable records the native chat indexes.
BOOL TFAIRecordSessionToolEvent(NSMutableDictionary *session,NSDictionary *event){
 NSString *type=SFText(event[@"type"]),*identifier=SFText(event[@"id"]);
 if([type isEqual:@"assistant_start"]){session[@"remoteAssistantMessageID"]=SFText(event[@"messageID"]);return NO;}
 if(![@[@"tool_call",@"tool_started",@"tool_progress",@"tool_result"] containsObject:type]||!identifier.length)return NO;
 NSMutableArray *records=[session[@"processRecords"] mutableCopy]?:[NSMutableArray new];NSUInteger index=[records indexOfObjectPassingTest:^BOOL(NSDictionary *r,NSUInteger i,BOOL *stop){return [r[@"id"] isEqual:identifier];}];
 NSMutableDictionary *record=index==NSNotFound?[NSMutableDictionary new]:[records[index] mutableCopy];record[@"id"]=identifier;
 if(event[@"name"])record[@"name"]=event[@"name"];if(event[@"arguments"])record[@"arguments"]=event[@"arguments"];
 if(!record[@"assistantMessageID"]&&[session[@"remoteAssistantMessageID"] length])record[@"assistantMessageID"]=session[@"remoteAssistantMessageID"];
 if([type isEqual:@"tool_call"])record[@"status"]=@"requested";
 if([type isEqual:@"tool_started"]){record[@"status"]=@"running";record[@"startedAt"]=@(NSDate.date.timeIntervalSince1970);}
 if([type isEqual:@"tool_progress"])record[@"summary"]=[NSString stringWithFormat:@"%.0f%% · %@",[event[@"progress"] doubleValue]*100,event[@"message"]?:@""];
 if([type isEqual:@"tool_result"]){NSDictionary *result=[event[@"result"] isKindOfClass:NSDictionary.class]?event[@"result"]:@{};record[@"result"]=result;
  BOOL failed=result[@"error"]||([record[@"name"] isEqual:@"build_project"]&&result[@"success"]&&![result[@"success"] boolValue]);record[@"status"]=failed?@"failed":@"completed";
  if([@[@"interrupted",@"cancelled",@"stopped"] containsObject:result[@"state"]]||[result[@"interrupted"] boolValue])record[@"status"]=@"interrupted";
  record[@"finishedAt"]=@(NSDate.date.timeIntervalSince1970);if(record[@"startedAt"])record[@"duration"]=@(MAX(0,[record[@"finishedAt"] doubleValue]-[record[@"startedAt"] doubleValue]));[record removeObjectForKey:@"summary"];
 }
 if(index==NSNotFound)[records addObject:record];else records[index]=record;session[@"processRecords"]=records;return YES;
}

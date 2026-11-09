#import "../Sandbox/TFAIISHRuntime.h"
#import "TFAIToolAvailability.h"
#import "TFAIToolRegistry.h"
#import "TFAIToolIsolation.h"
#import "../Agent/TFAIAgentContext.h"
#import "../Agent/TFAIMCP.h"
#import "../Attachments/TFAIAttachmentStore.h"
#import "../Tools/TFAIWebTools.h"
#import "../../Remote/DXRemoteService.h"
#import "../../Remote/DXFlexBridge.h"
#import <WebKit/WebKit.h>

static BOOL Regular(NSString *path,unsigned long long maximum){NSDictionary *a=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];return [a[NSFileType] isEqual:NSFileTypeRegular]&&[a[NSFileSize] unsignedLongLongValue]<=maximum&&[NSFileManager.defaultManager isReadableFileAtPath:path];}
static BOOL Directory(NSString *path){NSDictionary *a=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];return [a[NSFileType] isEqual:NSFileTypeDirectory]&&[NSFileManager.defaultManager isReadableFileAtPath:path];}
static BOOL PresentID(id value){return value&&!([value isKindOfClass:NSString.class]&&![value length]);}
static BOOL UUID(id value){return [value isKindOfClass:NSString.class]&&[[NSUUID alloc]initWithUUIDString:value]!=nil;}
static BOOL Grant(NSString *identifier){NSDictionary *entry=@{@"directoryGrant":identifier};if(!TFAIReadDirectoryReference(entry,@{@"action":@"validate"},nil))return NO;NSURL *url=TFAIDirectoryBrowserURL(entry,nil);if(!url)return NO;BOOL scoped=[url startAccessingSecurityScopedResource];BOOL valid=Directory(url.path);if(scoped)[url stopAccessingSecurityScopedResource];return valid;}
static NSString *Documents(void){return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;}
static BOOL Binary(NSString *identifier){if(!UUID(identifier))return NO;NSString *parent=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"TweakForgeAI/Binaries"],*dir=[parent stringByAppendingPathComponent:identifier];return Directory(parent)&&Directory(dir)&&Regular([dir stringByAppendingPathComponent:@"input.dylib"],64ULL*1024*1024)&&Regular([dir stringByAppendingPathComponent:@"metadata.json"],1024*1024);}
static BOOL IPA(NSString *identifier){if(!UUID(identifier))return NO;NSString *parent=[Documents() stringByAppendingPathComponent:@"AIClassDumpInputs"],*dir=[parent stringByAppendingPathComponent:identifier];return Directory(parent)&&Directory(dir)&&Regular([dir stringByAppendingPathComponent:@"input.ipa"],4ULL*1024*1024*1024)&&Regular([dir stringByAppendingPathComponent:@"metadata.json"],1024*1024);}
static BOOL Headers(NSString *identifier){if(!UUID(identifier))return NO;NSString *dir=[Documents() stringByAppendingPathComponent:[@"ClassDump-" stringByAppendingString:identifier]];return Directory(dir)&&Regular([dir stringByAppendingPathComponent:@"index.json"],20*1024*1024);}
NSDictionary *TFAIToolValidReferences(NSDictionary *references){NSMutableDictionary *valid=[NSMutableDictionary new];for(id key in references){id ref=references[key];if(![key isKindOfClass:NSString.class]||![ref isKindOfClass:NSDictionary.class])continue;if(ref[@"derivedDirectoryGrant"]&&(!UUID(ref[@"derivedDirectoryGrant"])||!Grant(ref[@"derivedDirectoryGrant"])))continue;if(ref[@"directoryGrant"]){if(UUID(ref[@"directoryGrant"])&&Grant(ref[@"directoryGrant"]))valid[key]=ref;continue;}
 if(ref[@"localSnapshot"]){if(![ref[@"localSnapshot"] isKindOfClass:NSDictionary.class])continue;NSString *path=TFAIAttachmentLocalPath(ref[@"localSnapshot"],nil);if(!path||!Regular(path,20*1024*1024))continue;}
 if(PresentID(ref[@"binaryInputID"])&&!Binary(ref[@"binaryInputID"])&&!Headers(ref[@"binaryInputID"]))continue;
 if(PresentID(ref[@"classDumpInputID"])&&!IPA(ref[@"classDumpInputID"])&&!Headers(ref[@"classDumpInputID"]))continue;
 if(PresentID(ref[@"classDumpJobID"])&&!Headers(ref[@"classDumpJobID"]))continue;
 if([ref[@"content"] isKindOfClass:NSString.class]||ref[@"localSnapshot"]||ref[@"binaryInputID"]||ref[@"classDumpInputID"]||ref[@"classDumpJobID"])valid[key]=ref;
 }return valid;
}
NSDictionary *TFAIToolRemoteStatus(void){if(![TFAIToolRegistry enabled:@"remote"])return @{};NSDictionary *state=DXRemoteService.shared.localState;if(![state[@"state"] isEqual:@"running"]&&![state[@"davState"] isEqual:@"running"])return @{};NSMutableDictionary *public=[NSMutableDictionary new];for(NSString *key in @[@"state",@"davState",@"httpEnabled",@"davEnabled",@"online",@"lifecycle",@"port",@"davPort",@"tls"])if(state[key])public[key]=state[key];return public;}
NSDictionary *TFAIToolContext(NSString *root,NSString *session,NSDictionary *references,BOOL bridge,BOOL approval,BOOL readOnly){
 BOOL sandbox=NO;
#if DYLIX_HAS_ISH
 sandbox=[TFAIISHRuntime available];
#endif
NSDictionary *valid=TFAIToolValidReferences(references?:@{});NSMutableArray *attachment=[NSMutableArray new],*binary=[NSMutableArray new],*ipa=[NSMutableArray new],*headers=[NSMutableArray new],*skills=[NSMutableArray new],*mcp=[NSMutableArray new],*mcpConfirm=[NSMutableArray new];for(NSString *key in valid){NSDictionary *r=valid[key];if(r[@"directoryGrant"]||r[@"localSnapshot"]||[r[@"content"] isKindOfClass:NSString.class])[attachment addObject:key];if(Binary(r[@"binaryInputID"]))[binary addObject:r[@"binaryInputID"]];if(IPA(r[@"classDumpInputID"]))[ipa addObject:r[@"classDumpInputID"]];for(NSString *field in @[@"classDumpJobID",@"classDumpInputID",@"binaryInputID"])if(Headers(r[field]))[headers addObject:r[field]];}
 if([TFAIToolRegistry enabled:@"skills"])for(NSDictionary *s in [TFAIAgentContext skills:root])[skills addObject:s[@"id"]];if([TFAIToolRegistry enabled:@"mcp"])for(NSDictionary *s in [TFAIMCP.shared schemas:session?:@""]){[mcp addObject:s[@"name"]];if([[TFAIMCP.shared approvalInfo:s[@"name"] session:session][@"requiresApproval"] boolValue])[mcpConfirm addObject:s[@"name"]];}
 BOOL foreground=UIApplication.sharedApplication.applicationState==UIApplicationStateActive,compiler=YES;NSString *bundle=NSBundle.mainBundle.bundlePath;for(NSString *name in @[@"clang",@"lld"]){NSString *file=[bundle stringByAppendingPathComponent:[NSString stringWithFormat:@"Frameworks/%@.framework/%@",name,name]];if(!Regular(file,512ULL*1024*1024))compiler=NO;}if(!Regular([bundle stringByAppendingPathComponent:@"SDK.zip"],2ULL*1024*1024*1024))compiler=NO;
 NSArray *apps=[TFAIToolIsolation.shared availableTargets:@"app"],*logs=[TFAIToolIsolation.shared availableTargets:@"log"];
 return @{@"sandboxAvailable":@(sandbox),@"hasProject":@(root.length&&Directory(root)),@"hasSession":@(session.length>0),@"hasBridge":@(bridge),@"hasApproval":@(approval),@"readOnly":@(readOnly),@"foreground":@(foreground),@"compilerAvailable":@(compiler),@"webEnabled":@(TFAIWebTools.enabled),@"browserAvailable":@(NSClassFromString(@"WKWebView")!=nil),@"attachmentIDs":attachment,@"binaryIDs":binary,@"ipaIDs":ipa,@"headerIDs":headers,@"skillIDs":skills,@"mcpNames":mcp,@"mcpConfirmNames":mcpConfirm,@"remoteAvailable":@(TFAIToolRemoteStatus().count>0),@"flexContextAvailable":@([DXFlexBridge.shared hasContextForSession:session]),@"flexLiveAvailable":@([DXFlexBridge.shared hasLiveAgentForSession:session]),@"flexTouchAvailable":@([[DXFlexBridge.shared contextForSession:session][@"capabilities"][@"touchGestures"] boolValue]),@"isolationEnabled":@([TFAIToolRegistry enabled:@"isolation"]),@"targetAppIDs":[apps valueForKey:@"id"],@"pluginLogIDs":[logs valueForKey:@"id"]};
}

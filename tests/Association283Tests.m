#import "../App/AI/AIV2Contracts.h"
static int checks=0,failures=0;
static void Check(BOOL pass,NSString *name){checks++;if(!pass)failures++;printf("%s %s\n",pass?"PASS":"FAIL",name.UTF8String);}
int main(){@autoreleasepool{
 NSString *scope=[@"association283-" stringByAppendingString:NSUUID.UUID.UUIDString];
 for(NSString *kind in @[@"ordinary",@"dump",@"shared-file"]){
 NSMutableDictionary *record=[TFAISessions create:scope title:kind];NSString *identifier=record[@"id"];
 record[@"messages"]=@[@{@"role":@"user",@"content":@"Existing task"},@{@"role":@"assistant",@"content":@"Completed header dump"}];
 record[@"processRecords"]=@[@{@"tool":@"classdump",@"jobID":@"original-job",@"result":@{@"path":@"Headers/Example.h"}}];record[@"pendingAttachments"]=@[@{@"id":@"shared-original",@"path":@"Original.xm"}];record[@"draft"]=@"unfinished input";record[@"permissionPreset"]=@"full";
 Check([TFAISessions save:record project:scope error:nil],@"fixture saved");NSDictionary *before=[TFAISessions loadSession:identifier project:scope];NSUInteger count=[TFAISessions summaries:scope].count;
 for(NSString *target in @[@"project-a",@"project-b"]){
 Check([TFAISessions saveMetadata:@{@"projectName":target,@"projectRoot":[@"/projects/" stringByAppendingString:target],@"associatedProjectID":target,@"workspaceID":target} identifier:identifier project:scope error:nil],@"associate existing session");
 [TFAISessions save:record project:scope error:nil]; // Previously queued snapshot predates the association.
 NSDictionary *after=[TFAISessions loadSession:identifier project:scope];
 Check([after[@"id"] isEqual:identifier]&&[after[@"storageProjectID"] isEqual:scope],@"storage identity retained");
 Check([after[@"messages"] isEqual:before[@"messages"]]&&[after[@"processRecords"] isEqual:before[@"processRecords"]],@"history and dump job retained");
 Check([after[@"pendingAttachments"] isEqual:before[@"pendingAttachments"]]&&[after[@"draft"] isEqual:before[@"draft"]],@"shared attachment and draft retained");
 Check([after[@"workspaceID"] isEqual:target]&&[after[@"associatedProjectID"] isEqual:target],@"stale snapshot cannot revert binding");
 Check([TFAISessions summaries:scope].count==count&&![TFAISessions loadSession:identifier project:target],@"no new conversation or storage copy");
 NSDictionary *summary=[TFAISessions summaries:scope].firstObject;Check([summary[@"workspaceID"] isEqual:target],@"project list uses updated association");
 }
 TFAISetSessionLiveRun(scope,identifier,YES);NSError *error=nil;Check(![TFAISessions saveMetadata:@{@"associatedProjectID":@"project-c",@"workspaceID":@"project-c"} identifier:identifier project:scope error:&error]&&error,@"active run association rejected");TFAISetSessionLiveRun(scope,identifier,NO);Check([[TFAISessions loadSession:identifier project:scope][@"workspaceID"] isEqual:@"project-b"],@"active run keeps previous workspace");
 [TFAISessions remove:identifier project:scope];
 }
 NSString *root=[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"TweakForgeAI/Sessions"] stringByAppendingPathComponent:scope];[NSFileManager.defaultManager removeItemAtPath:root error:nil];printf("%d checks, %d failures\n",checks,failures);return failures?1:0;
}}

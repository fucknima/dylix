#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
static NSString *RunProgressJSON(id object){NSData *d=[NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingSortedKeys|NSJSONWritingFragmentsAllowed error:nil];return d?[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]:@"{}";}
static NSString *RunProgressDigest(id object){NSData *d=[RunProgressJSON(object) dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,hash);NSMutableString *s=[NSMutableString new];for(NSUInteger i=0;i<sizeof(hash);i++)[s appendFormat:@"%02x",hash[i]];return s;}
static id RunProgressStable(id value){
 if([value isKindOfClass:NSDictionary.class]){NSMutableDictionary *out=[NSMutableDictionary new];for(NSString *k in value)if(![@[@"duration",@"timestamp",@"export_id",@"request_id",@"elapsed",@"queriedAt"] containsObject:k])out[k]=RunProgressStable(value[k]);return out;}
 if([value isKindOfClass:NSArray.class]){NSMutableArray *out=[NSMutableArray new];for(id v in value)[out addObject:RunProgressStable(v)];return out;}return value;
}
static BOOL RunProgressPolling(NSDictionary *call,NSDictionary *value){NSString *n=call[@"name"];return [n hasPrefix:@"sandbox_process_"]||[n hasPrefix:@"flex_"]||[n isEqual:@"subtask_task"]||[n isEqual:@"read_app_state"];}
static BOOL RunProgressApplied(NSDictionary *call,NSDictionary *value){
 if(value[@"error"]||![@[@"apply_approved_patch",@"create_file"] containsObject:call[@"name"]])return NO;
 return [value[@"applied"] isEqual:@YES]||([value[@"status"] isEqual:@"applied"]&&[value[@"files"] isKindOfClass:NSArray.class]&&[value[@"files"] count]>0);
}
static BOOL RunProgressMilestone(NSDictionary *call,NSDictionary *value){return value[@"proposal_id"]||value[@"export_id"]||value[@"artifact_id"]||value[@"build_id"]||value[@"jobID"]||RunProgressApplied(call,value)||[call[@"name"] isEqual:@"build_project"];}
static NSDictionary *RunProgressFacts(NSDictionary *value){NSMutableDictionary *out=[NSMutableDictionary new];for(NSString *k in @[@"proposal_id",@"previewStoredLocally",@"edit_count",@"export_id",@"artifact_id",@"build_id",@"jobID",@"name",@"bytes",@"success",@"applied",@"copied",@"status",@"files",@"state",@"sha256"])if(value[k]&&[RunProgressJSON(@{k:value[k]}) length]<512)out[k]=value[k];return out;}
// Compare actual outcomes, not display titles, transient receipt IDs or archive wrappers.
static NSString *RunProgressCallKey(NSDictionary *call){NSMutableDictionary *a=[call[@"arguments"] mutableCopy]?:[NSMutableDictionary new];[a removeObjectForKey:@"tool_title"];return RunProgressDigest(@{@"name":call[@"name"]?:@"",@"arguments":a});}
static NSString *RunProgressOutcome(NSDictionary *call,NSDictionary *value){
 id stable=RunProgressStable(value);
 if([call[@"name"] isEqual:@"read_context"]){
  // A different result: ID must not turn the same historical page into new evidence.
  id page=value;
  for(NSUInteger i=0;i<32&&[page isKindOfClass:NSDictionary.class]&&[page[@"historical"] boolValue]&&[page[@"text"] isKindOfClass:NSString.class];i++){
   NSString *text=page[@"text"];id decoded=[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingFragmentsAllowed error:nil];page=decoded?:text;
  }
  stable=RunProgressStable(page);
 }
 if([call[@"name"] hasPrefix:@"propose_"]&&[stable isKindOfClass:NSDictionary.class]){NSMutableDictionary *v=[stable mutableCopy];[v removeObjectForKey:@"proposal_id"];stable=v;}
 return RunProgressDigest(stable);
}
static BOOL RunProgressContinuation(NSDictionary *message){
 if([message[@"localRecovery"] boolValue])return YES;
 NSString *text=[message[@"content"] isKindOfClass:NSString.class]?[message[@"content"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]:@"";
 return [@[@"继续",@"继续。",@"继续啊",@"继续处理",@"continue",@"Continue"] containsObject:text]||[text hasPrefix:@"继续此前尚未完成的任务，保留已收到的答复和工具结果。"];
}

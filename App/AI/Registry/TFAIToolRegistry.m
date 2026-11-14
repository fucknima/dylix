#import "TFAIToolRegistry.h"
#import <CommonCrypto/CommonDigest.h>
#import <math.h>

static NSDictionary *Declarations(void){
 static NSDictionary *declarations;static dispatch_once_t once;dispatch_once(&once,^{
  NSMutableDictionary *all=[NSMutableDictionary new];
  void(^add)(NSArray *,NSString *,NSString *,NSString *,NSString *,BOOL,NSString *,NSString *)=^(NSArray *names,NSString *effect,NSString *scope,NSString *tier,NSString *approval,BOOL foreground,NSString *module,NSString *availability){
   for(NSString *name in names)all[name]=@{@"name":name,@"description":[NSString stringWithFormat:@"%@ (%@; %@)",name,effect,scope],@"effect":effect,@"scope":scope,@"tier":tier,@"permissionTier":tier,@"approvalPolicy":approval,@"requiresUserApproval":@(![approval isEqual:@"none"]),@"requiresForeground":@(foreground),@"module":module,@"availability":availability};
  };
  add(@[@"read_development_guide",@"read_app_state",@"search_tools"],@"read",@"app_public_state",@"A",@"none",NO,@"core",@"always");
  add(@[@"update_plan"],@"transcript",@"current_session_plan",@"A",@"none",NO,@"core",@"session");
  add(@[@"read_context"],@"read",@"current_session_history",@"A",@"none",NO,@"core",@"session");
  add(@[@"set_app_settings"],@"write",@"declared_app_preferences",@"A",@"existing",YES,@"core",@"always");
  add(@[@"app_action"],@"mixed",@"declared_app_actions",@"A",@"existing",NO,@"core",@"actions");
  add(@[@"list_projects"],@"read",@"local_project_index",@"A",@"none",NO,@"core",@"bridge");
  add(@[@"create_project",@"clone_project",@"select_project"],@"write",@"confirmed_workspace",@"A",@"existing",YES,@"core",@"bridge");
  add(@[@"list_files",@"read_file",@"search_text",@"list_symbols",@"read_project_config",@"git_status",@"git_diff",@"git_history"],@"read",@"current_project",@"A",@"none",NO,@"core",@"project");
  add(@[@"propose_patch",@"propose_config_change",@"propose_build_settings"],@"read",@"current_project_proposal",@"A",@"none",NO,@"core",@"project");
  add(@[@"apply_approved_patch",@"create_directory",@"create_file",@"request_delete",@"prepare_project",@"git_stage",@"git_save_version",@"git_download_updates",@"git_upload",@"download_file",@"extract_archive"],@"write",@"current_project",@"A",@"existing",NO,@"core",@"project");
  add(@[@"list_builds",@"read_diagnostics",@"list_artifacts"],@"read",@"current_project_builds",@"A",@"none",NO,@"core",@"projectBridge");
  add(@[@"clean_builds",@"cancel_build"],@"write",@"current_project_builds",@"A",@"existing",NO,@"core",@"projectBridge");
  add(@[@"build_project"],@"write",@"current_project_build",@"A",@"existing",NO,@"core",@"compiler");
  add(@[@"binary_inspect",@"binary_obfuscation_scan"],@"read",@"selected_staged_binary",@"A",@"none",NO,@"core",@"binary");
  add(@[@"classdump_export"],@"read",@"selected_staged_ipa_derived_output",@"A",@"none",NO,@"core",@"ipa");
  add(@[@"classdump_headers"],@"read",@"selected_local_headers",@"A",@"none",NO,@"core",@"headers");
  add(@[@"web_read",@"web_search",@"github_query"],@"read",@"public_web",@"A",@"none",NO,@"core",@"web");
  add(@[@"sandbox_install_tools",@"sandbox_process_start",@"sandbox_process_write",@"sandbox_process_resize",@"sandbox_process_stop"],@"write",@"session_linux_process",@"A",@"existing",NO,@"sandbox",@"sandbox");
  add(@[@"sandbox_process_read",@"sandbox_process_list",@"sandbox_files"],@"read",@"session_linux_process",@"A",@"none",NO,@"sandbox",@"sandbox");
  add(@[@"sandbox_preview"],@"read",@"session_owned_loopback_http",@"A",@"none",YES,@"sandbox",@"sandbox");
  add(@[@"sandbox_reverse"],@"mixed",@"selected_binary_in_session_linux",@"A",@"existing",NO,@"sandbox",@"sandbox");
  add(@[@"sandbox_browser"],@"mixed",@"session_owned_loopback_http",@"A",@"existing",YES,@"sandbox",@"sandbox");
  add(@[@"sandbox_execute",@"sandbox_import_attachment",@"sandbox_export_file"],@"write",@"session_linux_sandbox",@"A",@"existing",NO,@"sandbox",@"sandbox");
  add(@[@"agent_skill_read"],@"read",@"project_or_bundled_skill_text",@"A",@"none",NO,@"skills",@"skills");
  add(@[@"web_browse"],@"mixed",@"ephemeral_public_web",@"A",@"existing",YES,@"browser",@"browser");
  add(@[@"agent_memory_append"],@"write",@"confirmed_local_daily_note",@"A",@"every_call",YES,@"memory",@"always");
  add(@[@"agent_memory_read"],@"read",@"project_or_local_MEMORY.md",@"A",@"none",NO,@"memory",@"always");
  add(@[@"subtask_task"],@"mixed",@"current_project_child_tasks",@"A",@"existing",NO,@"build_queue",@"projectBridge");
  add(@[@"agent_build_tasks"],@"read",@"current_project_tasks",@"A",@"none",NO,@"build_queue",@"projectBridge");
  add(@[@"read_attachment"],@"read",@"selected_attachment_or_live_directory_grant",@"B",@"none",NO,@"core",@"attachment");
  add(@[@"remote_workspace_status"],@"read",@"explicitly_enabled_remote_service",@"B",@"none",NO,@"remote",@"remote");
  add(@[@"flex_current_context"],@"read",@"paired_FLEX_selected_object",@"B",@"none",NO,@"core",@"flexContext");
  add(@[@"flex_live_read"],@"read",@"paired_FLEX_live_runtime",@"B",@"none",NO,@"core",@"flexLive");
  add(@[@"flex_sensitive_read"],@"read",@"paired_FLEX_sensitive_content",@"B",@"every_call",NO,@"core",@"flexLive");
  add(@[@"flex_control"],@"write",@"paired_FLEX_bounded_controls",@"B",@"every_call",NO,@"core",@"flexLive");
  add(@[@"target_app_metadata"],@"read",@"one_native_enrolled_app_Info.plist",@"C",@"every_call",YES,@"isolation",@"targetApp");
  add(@[@"own_plugin_logs"],@"read",@"one_native_enrolled_own_plugin_log",@"C",@"every_call",YES,@"isolation",@"pluginLog");
  declarations=all.copy;
 });return declarations;
}
static BOOL ActionAvailable(NSString *name,NSDictionary *context){
 if([name hasPrefix:@"git_"]&&![context[@"hasProject"] boolValue])return NO;
 if(([name hasPrefix:@"open_"]||[name isEqual:@"choose_attachment"])&&![context[@"foreground"] boolValue])return NO;
 if([@[@"session_info",@"session_rename",@"session_pin",@"list_session_files",@"read_session_file",@"open_model_controls",@"open_permissions",@"choose_attachment"] containsObject:name]&&![context[@"hasSession"] boolValue])return NO;
 return YES;
}
static BOOL Available(NSDictionary *entry,NSDictionary *c){
 if(!entry||![TFAIToolRegistry enabled:entry[@"module"]])return NO;
 // Browser confirmation does not satisfy the isolated tier's phone-native consent.
 if([entry[@"tier"] isEqual:@"C"]&&[c[@"remoteExecution"] boolValue])return NO;
 if([entry[@"requiresForeground"] boolValue]&&![c[@"foreground"] boolValue])return NO;
 NSString *check=entry[@"availability"];
 if([check isEqual:@"always"]||[check isEqual:@"actions"])return YES;
 if([check isEqual:@"sandbox"])return [c[@"sandboxAvailable"] boolValue]&&[c[@"hasSession"] boolValue]&&[c[@"hasApproval"] boolValue]&&![c[@"readOnly"] boolValue]&&(![entry[@"name"] isEqual:@"sandbox_import_attachment"]||[c[@"attachmentIDs"] count]>0)&&(![entry[@"name"] isEqual:@"sandbox_reverse"]||[c[@"binaryIDs"] count]>0);
 if([check isEqual:@"session"])return [c[@"hasSession"] boolValue];
 if([check isEqual:@"bridge"])return [c[@"hasBridge"] boolValue];
 if([check isEqual:@"project"])return [c[@"hasProject"] boolValue];
 if([check isEqual:@"projectBridge"])return [c[@"hasProject"] boolValue]&&[c[@"hasBridge"] boolValue];
 if([check isEqual:@"compiler"])return [c[@"hasProject"] boolValue]&&[c[@"hasBridge"] boolValue]&&[c[@"compilerAvailable"] boolValue];
 if([check isEqual:@"binary"])return [c[@"binaryIDs"] count]>0;
 if([check isEqual:@"ipa"])return [c[@"ipaIDs"] count]>0;
 if([check isEqual:@"headers"])return [c[@"headerIDs"] count]>0;
 if([check isEqual:@"attachment"])return [c[@"attachmentIDs"] count]>0;
 if([check isEqual:@"web"])return [c[@"webEnabled"] boolValue];
 if([check isEqual:@"browser"])return [c[@"webEnabled"] boolValue]&&[c[@"browserAvailable"] boolValue];
 if([check isEqual:@"skills"])return [c[@"skillIDs"] count]>0;
 if([check isEqual:@"remote"])return [c[@"remoteAvailable"] boolValue];
 if([check isEqual:@"flexContext"])return [c[@"flexContextAvailable"] boolValue];
 if([check isEqual:@"flexLive"])return [c[@"flexLiveAvailable"] boolValue]&&([entry[@"effect"] isEqual:@"read"]||![c[@"readOnly"] boolValue]);
 if([entry[@"tier"] isEqual:@"C"]){if(![c[@"isolationEnabled"] boolValue]||[c[@"readOnly"] boolValue]||![c[@"hasApproval"] boolValue])return NO;return [c[[check isEqual:@"targetApp"]?@"targetAppIDs":@"pluginLogIDs"] count]>0;}
 return [check isEqual:@"mcp"]&&[c[@"mcpNames"] containsObject:entry[@"name"]];
}
// Report only schema constraints and field paths, never caller-supplied values.
static NSString *FieldPath(NSString *parent,NSString *key){
 NSString *field=key.length>64?[[key substringToIndex:64] stringByAppendingString:@"…"]:key;
 return [parent stringByAppendingFormat:@".%@",field];
}
static BOOL Invalid(NSDictionary **issue,NSString *path,NSString *rule,NSString *message){
 if(issue)*issue=@{@"parameter":path?:@"arguments",@"rule":rule,@"message":message};return NO;
}
static BOOL Validate(id value,NSDictionary *s,NSUInteger depth,NSString *path,NSDictionary **issue){
 if(depth>16)return Invalid(issue,path,@"depth",@"参数嵌套层级超过上限 16");
 if(![s isKindOfClass:NSDictionary.class])return YES;
 NSString *type=[s[@"type"] isKindOfClass:NSString.class]?s[@"type"]:nil;
 if([s[@"enum"] isKindOfClass:NSArray.class]&&![s[@"enum"] containsObject:value])return Invalid(issue,path,@"enum",@"必须使用本轮工具声明中的可选值或已下发 ID");
 BOOL number=[value isKindOfClass:NSNumber.class],boolean=number&&CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID();
 if([type isEqual:@"string"]){
  if(![value isKindOfClass:NSString.class])return Invalid(issue,path,@"type",@"必须是字符串");
  if(s[@"minLength"]&&[value length]<[s[@"minLength"] unsignedIntegerValue])return Invalid(issue,path,@"minLength",[NSString stringWithFormat:@"长度不得少于 %@ 个 UTF-16 单位",s[@"minLength"]]);
  if(s[@"maxLength"]&&[value length]>[s[@"maxLength"] unsignedIntegerValue])return Invalid(issue,path,@"maxLength",[NSString stringWithFormat:@"长度不得超过 %@ 个 UTF-16 单位",s[@"maxLength"]]);
 }else if([type isEqual:@"boolean"]){
  if(!boolean)return Invalid(issue,path,@"type",@"必须是布尔值");
 }else if([type isEqual:@"number"]||[type isEqual:@"integer"]){
  if(!number||boolean||!isfinite([value doubleValue])||([type isEqual:@"integer"]&&floor([value doubleValue])!=[value doubleValue]))return Invalid(issue,path,@"type",[type isEqual:@"integer"]?@"必须是整数，不能使用布尔值或小数":@"必须是有限数值，不能使用布尔值");
  if(s[@"minimum"]&&[value doubleValue]<[s[@"minimum"] doubleValue])return Invalid(issue,path,@"minimum",[NSString stringWithFormat:@"必须大于或等于 %@",s[@"minimum"]]);
  if(s[@"maximum"]&&[value doubleValue]>[s[@"maximum"] doubleValue])return Invalid(issue,path,@"maximum",[NSString stringWithFormat:@"必须小于或等于 %@",s[@"maximum"]]);
 }else if([type isEqual:@"array"]){
  if(![value isKindOfClass:NSArray.class])return Invalid(issue,path,@"type",@"必须是数组");
  if(s[@"minItems"]&&[value count]<[s[@"minItems"] unsignedIntegerValue])return Invalid(issue,path,@"minItems",[NSString stringWithFormat:@"至少需要 %@ 项",s[@"minItems"]]);
  if(s[@"maxItems"]&&[value count]>[s[@"maxItems"] unsignedIntegerValue])return Invalid(issue,path,@"maxItems",[NSString stringWithFormat:@"最多允许 %@ 项",s[@"maxItems"]]);
  NSUInteger index=0;for(id item in value){if(!Validate(item,s[@"items"],depth+1,[path stringByAppendingFormat:@"[%lu]",(unsigned long)index],issue))return NO;index++;}
 }else if([type isEqual:@"object"]){
  if(![value isKindOfClass:NSDictionary.class])return Invalid(issue,path,@"type",@"必须是 JSON 对象");
  if(s[@"minProperties"]&&[value count]<[s[@"minProperties"] unsignedIntegerValue])return Invalid(issue,path,@"minProperties",[NSString stringWithFormat:@"至少需要 %@ 个字段",s[@"minProperties"]]);
  NSDictionary *props=[s[@"properties"] isKindOfClass:NSDictionary.class]?s[@"properties"]:@{};
  for(NSString *key in s[@"required"])if(!value[key]||value[key]==NSNull.null)return Invalid(issue,FieldPath(path,key),@"required",@"缺少必填字段");
  for(id key in value){
   if(![key isKindOfClass:NSString.class])return Invalid(issue,path,@"type",@"对象字段名必须是字符串");
   NSString *child=FieldPath(path,key);
   if(!props[key]&&[s[@"additionalProperties"] isEqual:@NO])return Invalid(issue,child,@"additionalProperties",@"该字段未在工具参数中声明，请移除");
   if(!Validate(value[key],props[key]?:([s[@"additionalProperties"] isKindOfClass:NSDictionary.class]?s[@"additionalProperties"]:nil),depth+1,child,issue))return NO;
  }
 }
 return YES;
}
static BOOL PreflightError(NSError **error,NSInteger code,NSString *name,NSString *reason,NSString *phase,NSDictionary *issue,NSString *message,NSString *action){
 NSMutableDictionary *recovery=[@{@"tool":name?:@"",@"reason":reason,@"phase":phase,@"executed":@NO,@"nextAction":action} mutableCopy];
 if(issue){recovery[@"parameter"]=issue[@"parameter"];recovery[@"rule"]=issue[@"rule"];}
 if([reason isEqual:@"invalid_arguments"])recovery[@"requiresUserAuthorization"]=@NO;
 if(error)*error=[NSError errorWithDomain:@"Dylix.ToolRegistry" code:code userInfo:@{NSLocalizedDescriptionKey:message,@"TFAIToolRecovery":recovery.copy}];return NO;
}
static NSString *WorkspacePreferencesKey(NSString *root){if(!root.length)return nil;NSData *data=[root.stringByStandardizingPath.stringByResolvingSymlinksInPath dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[32];CC_SHA256(data.bytes,(CC_LONG)data.length,hash);NSMutableString *key=[NSMutableString stringWithString:@"Dylix.DisabledTools.v1."];for(int i=0;i<32;i++)[key appendFormat:@"%02x",hash[i]];return key;}
@implementation TFAIToolRegistry
+ (NSArray *)modules{return @[@"skills",@"mcp",@"browser",@"memory",@"build_queue",@"sandbox",@"remote",@"isolation"];}
+ (NSArray *)toolNames{return [Declarations().allKeys sortedArrayUsingSelector:@selector(compare:)];}
+ (NSSet *)disabledTools:(NSString *)root{NSString *key=WorkspacePreferencesKey(root);id values=key?[NSUserDefaults.standardUserDefaults objectForKey:key]:nil;if(![values isKindOfClass:NSArray.class])return [NSSet set];NSMutableSet *names=[NSMutableSet new];for(id name in values)if([name isKindOfClass:NSString.class])[names addObject:name];return names;}
+ (void)setTool:(NSString *)name enabled:(BOOL)enabled root:(NSString *)root{@synchronized(self){NSString *key=WorkspacePreferencesKey(root);if(!key||!Declarations()[name])return;NSMutableSet *names=[[self disabledTools:root] mutableCopy];if(enabled)[names removeObject:name];else[names addObject:name];[NSUserDefaults.standardUserDefaults setObject:[names.allObjects sortedArrayUsingSelector:@selector(compare:)] forKey:key];[NSNotificationCenter.defaultCenter postNotificationName:@"DylixToolRegistryChanged" object:root];}}
+ (BOOL)enabled:(NSString *)module{if([module isEqual:@"core"])return YES;if(![self.modules containsObject:module])return NO;id value=[NSUserDefaults.standardUserDefaults objectForKey:[@"Dylix.Tools.v1." stringByAppendingString:module]];return value?[value boolValue]:![@[@"isolation",@"remote"] containsObject:module];}
+ (void)setEnabled:(BOOL)enabled module:(NSString *)module{if(![self.modules containsObject:module])return;[NSUserDefaults.standardUserDefaults setBool:enabled forKey:[@"Dylix.Tools.v1." stringByAppendingString:module]];[NSNotificationCenter.defaultCenter postNotificationName:@"DylixToolRegistryChanged" object:module];}
+ (NSDictionary *)descriptor:(NSString *)name{return Declarations()[name];}
+ (NSArray *)entries:(NSArray *)schemas context:(NSDictionary *)context{
 NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];NSSet *disabled=[self disabledTools:context[@"projectRoot"]];
 for(id raw in schemas){if(![raw isKindOfClass:NSDictionary.class]||![raw[@"name"] isKindOfClass:NSString.class])continue;NSString *name=raw[@"name"];if([disabled containsObject:name])continue;if([seen containsObject:name])continue;[seen addObject:name];NSMutableDictionary *entry=[Declarations()[name] mutableCopy];
  if(!entry&&[name hasPrefix:@"mcp_"]&&[context[@"mcpNames"] containsObject:name])entry=[@{@"name":name,@"effect":@"read",@"scope":@"user_allowed_MCP_query",@"tier":@"A",@"permissionTier":@"A",@"approvalPolicy":@"none",@"requiresUserApproval":@NO,@"requiresForeground":@NO,@"module":@"mcp",@"availability":@"mcp"} mutableCopy];
  if([name hasPrefix:@"mcp_"]&&[context[@"mcpConfirmNames"] containsObject:name]){entry[@"effect"]=@"control";entry[@"scope"]=@"user_enabled_MCP_service";entry[@"approvalPolicy"]=@"confirmation";entry[@"requiresUserApproval"]=@YES;if([context[@"readOnly"] boolValue]||![context[@"hasApproval"] boolValue])continue;}
  if(!Available(entry,context))continue;
  NSMutableDictionary *wire=[raw mutableCopy],*parameters=[raw[@"parameters"] mutableCopy];NSMutableDictionary *props=[parameters[@"properties"] mutableCopy];
  NSDictionary *ids=@{@"sandbox_import_attachment":@[@"id",@"attachmentIDs"],@"read_attachment":@[@"id",@"attachmentIDs"],@"binary_inspect":@[@"binary_id",@"binaryIDs"],@"binary_obfuscation_scan":@[@"binary_id",@"binaryIDs"],@"sandbox_reverse":@[@"binary_id",@"binaryIDs"],@"classdump_export":@[@"input_id",@"ipaIDs"],@"classdump_headers":@[@"job_id",@"headerIDs"],@"agent_skill_read":@[@"id",@"skillIDs"],@"target_app_metadata":@[@"target_id",@"targetAppIDs"],@"own_plugin_logs":@[@"target_id",@"pluginLogIDs"]};
  if(ids[name]){NSArray *pair=ids[name];NSMutableDictionary *field=[props[pair[0]] mutableCopy]?:[NSMutableDictionary new];field[@"enum"]=context[pair[1]]?:@[];props[pair[0]]=field;}
  if([name isEqual:@"app_action"]){NSMutableDictionary *action=[props[@"action"] mutableCopy];NSMutableArray *names=[NSMutableArray new];for(NSString *value in action[@"enum"])if(ActionAvailable(value,context))[names addObject:value];if(!names.count)continue;action[@"enum"]=names;props[@"action"]=action;}
  if(props){parameters[@"properties"]=props;wire[@"parameters"]=parameters;}entry[@"description"]=[wire[@"description"] isKindOfClass:NSString.class]?wire[@"description"]:@"";entry[@"schema"]=wire.copy;[out addObject:entry.copy];
 }return out.copy;
}
+ (NSArray *)schemas:(NSArray *)schemas context:(NSDictionary *)context{NSMutableArray *out=[NSMutableArray new];for(NSDictionary *entry in [self entries:schemas context:context])[out addObject:entry[@"schema"]];return out.copy;}
+ (NSDictionary *)actionCatalog:(NSDictionary *)catalog context:(NSDictionary *)context{NSMutableDictionary *result=[catalog mutableCopy],*actions=[NSMutableDictionary new];for(NSString *name in catalog[@"actions"])if(ActionAvailable(name,context)){NSMutableDictionary *entry=[catalog[@"actions"][name] mutableCopy];entry[@"tier"]=@"A";entry[@"scope"]=[name hasPrefix:@"git_"]?@"current_project":@"declared_app_action";entry[@"requiresUserApproval"]=entry[@"mutates"]?:@NO;entry[@"requiresForeground"]=@([name hasPrefix:@"open_"]||[name isEqual:@"choose_attachment"]);actions[name]=entry;}result[@"actions"]=actions;return result;}
+ (BOOL)preflight:(NSDictionary *)call schemas:(NSArray *)schemas context:(NSDictionary *)context error:(NSError **)error{
 if(![call isKindOfClass:NSDictionary.class]||![call[@"name"] isKindOfClass:NSString.class]||![call[@"arguments"] isKindOfClass:NSDictionary.class])return PreflightError(error,1,@"",@"invalid_arguments",@"advertised",nil,@"工具名称或参数格式有误；参数必须是 JSON 对象。未执行，无需重新授权。",@"Correct the tool name and JSON argument object; do not request user authorization for a formatting error.");
 NSString *name=call[@"name"];NSDictionary *sent=nil;
 for(NSDictionary *schema in schemas)if([schema[@"name"] isEqual:name]){sent=schema;break;}
 if(!sent)return PreflightError(error,2,@"",@"tool_not_advertised",@"advertised",nil,@"此工具未在本轮下发，未执行。请只使用当前请求提供的工具，不要重放历史工具调用。",@"Use only currently advertised tool schemas; do not replay an old call or ask for unrelated authorization.");
 NSDictionary *issue=nil;
 if(!Validate(call[@"arguments"],sent[@"parameters"],0,@"arguments",&issue)){
  NSString *hint=[name isEqual:@"read_context"]?@"此工具只回读当前会话原文。原始分页的 limit 可省略（默认 4096），或使用 1–4096 的整数；offset 从 0 开始，续读使用返回的 next_offset。文本字段模式使用 field、start_line、line_count、column，max_chars 为 1–16384 的整数；预算紧张时建议 512–1024，不能与 offset/limit 混用。":@"请按本轮工具声明修正参数后重试。";
  NSString *message=[NSString stringWithFormat:@"工具 %@ 参数不符合声明：%@ %@。未执行；这是参数校验失败，无需重新授权。%@",name,issue[@"parameter"],issue[@"message"],hint];
  return PreflightError(error,3,name,@"invalid_arguments",@"advertised",issue,message,[NSString stringWithFormat:@"Correct %@ to match the advertised schema and retry this tool only. Do not replay completed side effects or request authorization to fix an argument error. %@",issue[@"parameter"],hint]);
 }
 for(NSDictionary *current in [self schemas:schemas context:context])if([current[@"name"] isEqual:name]){
  issue=nil;if(Validate(call[@"arguments"],current[@"parameters"],0,@"arguments",&issue))return YES;
  return PreflightError(error,5,name,@"authorization_changed",@"current",issue,[NSString stringWithFormat:@"工具 %@ 的当前授权范围已变化：%@ %@。未执行。请重新读取当前可用范围，不能沿用已失效的 ID。",name,issue[@"parameter"],issue[@"message"]],@"Refresh current resources and advertised schemas. Do not substitute a newly granted ID within the old request or bypass approval.");
 }
 return PreflightError(error,4,name,@"tool_unavailable",@"current",nil,[NSString stringWithFormat:@"工具 %@ 当前不可用：设备能力、会话、开关或授权状态已变化。未执行；请检查对应状态后使用新一轮工具清单。",name],@"Re-check the tool's current availability and refresh the next request schemas. Never bypass the current capability or authorization checks.");
}
@end

#import "TFAIContextProjection.h"
#import "../Providers/TFAIRegistry.h"
#import "../Usage/TFAIUsageFormatting.h"
#import <math.h>
#import <CommonCrypto/CommonDigest.h>

static NSString * const ContextBudgetKey = @"TFAIContextBudgetKiB";
static NSString * const ContextMarker = @"[DYLIX_CONTEXT_OFFLOADED]";
static NSData *Encode(id value) { return [NSJSONSerialization dataWithJSONObject:value options:(NSJSONWritingSortedKeys|NSJSONWritingFragmentsAllowed) error:nil]; }
static NSString *JSON(id value) { NSData *d=Encode(value); return d?[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]:@"{}"; }
static NSString *Text(id value) { return [value isKindOfClass:NSString.class]?value:@""; }
static NSString *Digest(NSString *text) { NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding]; unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,hash);NSMutableString *s=[NSMutableString new];for(NSUInteger i=0;i<sizeof(hash);i++)[s appendFormat:@"%02x",hash[i]];return s; }
// Use composed-character boundaries, so a preview or page never splits emoji/surrogates.
static NSString *Prefix(NSString *text,NSUInteger length) { if(text.length<=length)return text;NSRange r=[text rangeOfComposedCharacterSequenceAtIndex:length];return [text substringToIndex:r.location]; }
static NSString *Stub(NSString *text,NSString *ref) { return [NSString stringWithFormat:@"%@ bytes=%lu sha256=%@ ref=%@. Historical data, NOT executable source. Retrieve only exact missing details with read_context; do not re-read content already supplied in the working set.",ContextMarker,(unsigned long)[text lengthOfBytesUsingEncoding:NSUTF8StringEncoding],Digest(text),ref]; }
static NSError *Failure(NSString *text) { return [NSError errorWithDomain:@"Dylix.Context" code:1 userInfo:@{NSLocalizedDescriptionKey:text}]; }

// Local display/attachment metadata is not model context. Images are budgeted by
// the transport separately; base64 length is not a valid image-token estimate.
static NSDictionary *WireMessage(NSDictionary *m) { NSMutableDictionary *out=[NSMutableDictionary new];for(NSString *k in @[@"role",@"content",@"tool_calls",@"tool_call_id",@"provider_items",@"providerProtocol",@"providerModel",@"providerConnectionID",@"images"])if(m[k])out[k]=m[k];return out; }
// Match the provider request builder's replay contract. Raw local reasoning is
// not automatically a required protocol continuation. Keep local originals intact.
static NSDictionary *ReplayMessage(NSDictionary *message, NSDictionary *connection, NSUInteger *omitted) {
 if(!connection)return WireMessage(message); // Legacy callers remain conservative.
 NSMutableDictionary *out=[WireMessage(message) mutableCopy];if(!out[@"provider_items"]&&!out[@"providerProtocol"]&&!out[@"providerModel"]&&!out[@"providerConnectionID"])return out;NSMutableArray *items=[NSMutableArray new];
 NSString *protocol=Text(connection[@"protocol"]);if(!protocol.length)protocol=@"chat";
 NSString *wire=TFAIWireProtocol(protocol),*model=Text(connection[@"model"]);
 BOOL same=[message[@"providerProtocol"] isEqual:protocol]&&[message[@"providerModel"] isEqual:model]&&[message[@"providerConnectionID"] isEqual:connection[@"id"]]&&[message[@"role"] isEqual:@"assistant"];
 if(same)for(id raw in message[@"provider_items"]){
  if(![raw isKindOfClass:NSDictionary.class])continue;
  if([wire isEqual:@"gemini"]&&[raw[@"type"] isEqual:@"gemini_content"]&&[raw[@"parts"] isKindOfClass:NSArray.class])[items addObject:raw];
  else if([wire isEqual:@"responses"]&&[raw[@"type"] isEqual:@"reasoning"]&&Text(raw[@"encrypted_content"]).length)[items addObject:@{@"type":@"reasoning",@"id":Text(raw[@"id"]),@"summary":@[],@"encrypted_content":raw[@"encrypted_content"]}];
  else if([wire isEqual:@"chat"]&&([protocol isEqual:@"deepseek"]||[model.lowercaseString.lastPathComponent hasPrefix:@"deepseek"])&&[raw[@"type"] isEqual:@"deepseek_reasoning"])[items addObject:@{@"type":@"deepseek_reasoning",@"content":Text(raw[@"content"])}];
 }
 NSUInteger before=Encode(out).length;
 if(items.count)out[@"provider_items"]=items;else for(NSString *key in @[@"provider_items",@"providerProtocol",@"providerModel",@"providerConnectionID"])[out removeObjectForKey:key];
 NSUInteger after=Encode(out).length;if(omitted&&before>after)*omitted+=before-after;
 return out;
}
static NSUInteger Measure(NSArray *messages,NSArray *schemas) { NSMutableArray *text=[NSMutableArray new];for(NSDictionary *m in messages){NSMutableDictionary *v=[m mutableCopy];if(v[@"images"]){v[@"imageCount"]=@([v[@"images"] count]);[v removeObjectForKey:@"images"];}[text addObject:v];}return Encode(@{@"messages":text,@"tools":schemas?:@[]}).length; }
static NSDictionary *Composition(NSArray *messages,NSArray *schemas) {
 NSMutableDictionary *bytes=[@{@"system":@0,@"user":@0,@"assistant":@0,@"tool":@0,@"other":@0} mutableCopy];
 NSUInteger sum=0;for(NSDictionary *m in messages){NSMutableDictionary *v=[m mutableCopy];if(v[@"images"]){v[@"imageCount"]=@([v[@"images"] count]);[v removeObjectForKey:@"images"];}NSUInteger size=Encode(v).length;NSString *role=bytes[Text(m[@"role"])]?Text(m[@"role"]):@"other";bytes[role]=@([bytes[role] unsignedIntegerValue]+size);sum+=size;}
 NSUInteger schema=Encode(schemas?:@[]).length,total=Measure(messages,schemas);bytes[@"schemas"]=@(schema);bytes[@"framing"]=@(total>=sum+schema?total-sum-schema:0);return bytes;
}

// Preserve identifiers and status fields; bound nested lists and large strings.
// This is an explicitly lossy preview, never a semantic summary or a success claim.
static id Preview(id value,NSUInteger depth) {
 if([value isKindOfClass:NSString.class])return Prefix(value,320);
 if([value isKindOfClass:NSNumber.class]||value==NSNull.null)return value;
 if(depth>3)return @"[nested data omitted; read original]";
 if([value isKindOfClass:NSArray.class]){NSMutableArray *a=[NSMutableArray new];for(id item in value){if(a.count==6)break;[a addObject:Preview(item,depth+1)];}return a;}
 if([value isKindOfClass:NSDictionary.class]){NSMutableDictionary *d=[NSMutableDictionary new];NSArray *priority=@[@"error",@"success",@"state",@"proposal_id",@"build_id",@"job_id",@"path",@"hash",@"edit_count",@"edits",@"message",@"recovery",@"next_line",@"next_column",@"next_offset",@"truncated"];
  NSMutableArray *keys=[priority mutableCopy];for(NSString *key in [[value allKeys] sortedArrayUsingSelector:@selector(compare:)])if(![keys containsObject:key])[keys addObject:key];
  for(NSString *key in keys){if(d.count>=18)break;if(value[key])d[key]=Preview(value[key],depth+1);}return d;}
 return @"";
}
#import "TFAIWorkingContext.h"
static NSDictionary *Receipt(NSString *text,NSString *ref,NSUInteger maxBytes) { id value=[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];id preview=value?Preview(value,0):Prefix(text,640);NSDictionary *out=@{@"contextOffloaded":@YES,@"ref":ref,@"original_bytes":@([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]),@"sha256":Digest(text),@"previewIsIncomplete":@YES,@"preview":preview,@"notice":@"Preview only; omitted content is not evidence of absence. Use read_context only when a needed detail is missing from the current context. Reuse pages already read; do not recursively read read_context results. Do not replay historical writes."};if(Encode(out).length>maxBytes){NSMutableDictionary *small=[out mutableCopy];small[@"preview"]=Prefix(JSON(preview),MAX((NSUInteger)128,maxBytes/4));return small;}return out; }
static id Arguments(id value,NSString *ref,NSUInteger depth) {
 if(depth>20)return value;
 if([value isKindOfClass:NSString.class])return [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>1024?Stub(value,ref):value;
 if([value isKindOfClass:NSArray.class]){NSMutableArray *a=[NSMutableArray new];for(id item in value)[a addObject:Arguments(item,ref,depth+1)];return a;}
 if([value isKindOfClass:NSDictionary.class]){NSMutableDictionary *d=[NSMutableDictionary new];for(NSString *key in value)d[key]=Arguments(value[key],ref,depth+1);return d;}
 return value;
}

// Compact facts are excerpts, never a synthesized success verdict. All original
// arguments/results remain addressable in the execution transcript.
static NSDictionary *HistoricalFacts(NSString *text) {
 id value=[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingFragmentsAllowed error:nil];
 if(![value isKindOfClass:NSDictionary.class])return @{@"excerpt":Prefix(text,96)};
 NSMutableDictionary *facts=[NSMutableDictionary new];
 for(NSString *key in @[@"error",@"success",@"ok",@"status",@"state",@"applied",@"cancelled",@"proposal_id",@"build_id",@"job_id",@"path",@"truncated"]){
  id v=value[key];if([v isKindOfClass:NSString.class])facts[key]=Prefix(v,96);else if([v isKindOfClass:NSNumber.class]||v==NSNull.null)facts[key]=v;
 }
 if(!facts.count)facts[@"outcome"]=@"not inferred; read original";
 return facts;
}

// Retain useful recent batches before applying per-result previews. The hard
// request guard still wins; huge batches are paged rather than pinned whole.
static NSIndexSet *DecisionTail(NSArray *messages,NSUInteger budget){
 NSMutableArray *groups=[NSMutableArray new];
 for(NSUInteger i=0;i<messages.count;i++){NSArray *calls=messages[i][@"tool_calls"];if(!calls.count)continue;NSUInteger end=i+1;NSMutableSet *ids=[NSMutableSet new];while(end<messages.count&&[messages[end][@"role"] isEqual:@"tool"]){[ids addObject:Text(messages[end][@"tool_call_id"])];end++;}BOOL complete=ids.count==calls.count;for(NSDictionary *c in calls)if(![ids containsObject:Text(c[@"id"])])complete=NO;if(complete)[groups addObject:@{@"start":@(i),@"end":@(end)}];i=end-1;}
 NSMutableIndexSet *keep=[NSMutableIndexSet new];NSUInteger used=0,allowance=MIN(192*1024,budget/2);
 for(NSDictionary *g in groups.reverseObjectEnumerator){if(keep.count>=6)break;NSUInteger bytes=0;for(NSUInteger i=[g[@"start"] unsignedIntegerValue];i<[g[@"end"] unsignedIntegerValue];i++)bytes+=Encode(messages[i]).length;if(bytes<=allowance-used){[keep addIndex:[g[@"start"] unsignedIntegerValue]];used+=bytes;}}
 return keep;
}
static NSDictionary *FieldPage(NSString *original,NSString *ref,NSDictionary *a,NSString *tool,NSError **error){
 NSString *field=Text(a[@"field"]);id object=[NSJSONSerialization JSONObjectWithData:[original dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
 if(![@[@"content",@"text",@"message",@"error"] containsObject:field]||![object isKindOfClass:NSDictionary.class]||![object[field] isKindOfClass:NSString.class]||a[@"offset"]||a[@"limit"]){if(error)*error=Failure(@"field 必须选择原始结果的文本字段，不能与 offset/limit 混用。 ");return nil;}
 for(NSString *k in @[@"start_line",@"line_count",@"column",@"max_chars"]){id v=a[k];if(v&&(![v isKindOfClass:NSNumber.class]||CFGetTypeID((__bridge CFTypeRef)v)==CFBooleanGetTypeID()||[v doubleValue]>9007199254740991.0||!isfinite([v doubleValue])||floor([v doubleValue])!=[v doubleValue]||[v doubleValue]<([k isEqual:@"column"]?0:1))){if(error)*error=Failure(@"字段行号、列偏移或行数无效。 ");return nil;}}
 NSString *body=object[field];NSUInteger line=a[@"start_line"]?[a[@"start_line"] unsignedIntegerValue]:1,count=a[@"line_count"]?[a[@"line_count"] unsignedIntegerValue]:200,column=[a[@"column"] unsignedIntegerValue];NSArray *lines=[body componentsSeparatedByString:@"\n"];
 NSUInteger fieldLimit=a[@"max_chars"]?[a[@"max_chars"] unsignedIntegerValue]:16384;
 if(!fieldLimit||fieldLimit>16384||!count||count>400||!line||line>lines.count||column>[lines[line-1] length]){if(error)*error=Failure(@"字段分页越界；line_count 范围为 1–400。 ");return nil;}
 NSUInteger start=0;for(NSUInteger i=0;i<line-1;i++)start+=[lines[i] length]+1;start+=column;
 if(start<body.length&&[body rangeOfComposedCharacterSequenceAtIndex:start].location!=start){if(error)*error=Failure(@"列偏移位于组合字符内。 ");return nil;}
 NSUInteger end=start,current=line-1,taken=0;BOOL cut=NO;
 while(current<lines.count&&taken<count){NSUInteger remaining=[lines[current] length]-(taken?0:column)+(current+1<lines.count?1:0);if(end-start+remaining>fieldLimit){if(taken)break;end=MIN(body.length,start+fieldLimit);if(end<body.length)end=[body rangeOfComposedCharacterSequenceAtIndex:end].location;cut=YES;break;}end+=remaining;current++;taken++;}
 if(end==start&&start<body.length){if(error)*error=Failure(@"单个组合字符超过字段分页限制。 ");return nil;}
 NSUInteger base=[object[@"start_line"] isKindOfClass:NSNumber.class]?[object[@"start_line"] unsignedIntegerValue]:1;
 NSMutableDictionary *page=[@{@"historical":@YES,@"view":@"field",@"ref":ref,@"original_tool":tool?:@"",@"field":field,@"field_start_line":@(line),@"column":@(column),@"start_line":@(base+line-1),@"text":[body substringWithRange:NSMakeRange(start,end-start)],@"offset":@(start),@"sha256":Digest(body),@"original_sha256":Digest(original),@"total_utf16":@(body.length),@"original_bytes":@([original lengthOfBytesUsingEncoding:NSUTF8StringEncoding]),@"truncated_line":@(cut),@"next_line":end<body.length?@(cut?line:current+1):NSNull.null,@"next_column":cut?@(column+end-start):@0} mutableCopy];
 if(object[@"path"])page[@"path"]=object[@"path"];if(object[@"sha256"])page[@"source_sha256"]=object[@"sha256"];return page;
}
@implementation TFAIContextProjection
+ (NSUInteger)budgetKiB {
 id stored=[NSUserDefaults.standardUserDefaults objectForKey:ContextBudgetKey];
 if(![stored isKindOfClass:NSNumber.class])return 256;
 double value=[stored doubleValue];return isfinite(value)&&value>=64&&value<=16384&&floor(value)==value?(NSUInteger)value:256;
}
+ (BOOL)setBudgetKiB:(NSUInteger)value {
 if(value<64||value>16384)return NO;
 [NSUserDefaults.standardUserDefaults setInteger:value forKey:ContextBudgetKey];return YES;
}
+ (NSString *)usageReport:(NSDictionary *)stats providerUsage:(NSDictionary *)usage {
 if(!stats.count)return @"发送一次消息后即可查看本轮上下文统计。";
 BOOL blocked=[stats[@"blockedBeforeRequest"] boolValue];
 NSNumber *actual=usage[@"prompt_tokens"]?:usage[@"input_tokens"]?:usage[@"promptTokenCount"];
 if(usage[@"input_tokens"]&&!usage[@"prompt_tokens"]&&(usage[@"cache_read_input_tokens"]||usage[@"cache_creation_input_tokens"]))actual=@([usage[@"input_tokens"] unsignedLongLongValue]+[usage[@"cache_read_input_tokens"] unsignedLongLongValue]+[usage[@"cache_creation_input_tokens"] unsignedLongLongValue]);
 NSMutableString *report=[NSMutableString stringWithFormat:@"%@\n整理前：%.1f KiB\n整理后：%.1f KiB\n应用保护预算：%.0f KiB\n\n参数卸载：%@ 次\n结果预览：%@ 次\n历史工具批次折叠：%@ 次\n历史 AI 回复卸载：%@ 次",blocked?@"本次被本机保护拦截，未向模型发送":@"最近请求文本 JSON（含工具定义）",[stats[@"beforeTextJSONBytes"] doubleValue]/1024.0,[stats[@"afterTextJSONBytes"] doubleValue]/1024.0,stats[@"budgetBytes"]?[stats[@"budgetBytes"] doubleValue]/1024.0:256,stats[@"argumentCallsOffloaded"]?:@0,stats[@"resultsOffloaded"]?:@0,stats[@"toolBatchesCollapsed"]?:@0,stats[@"assistantMessagesOffloaded"]?:@0];
 if(stats[@"pressureResultsPreviewed"])[report appendFormat:@"\n预算紧张后进一步缩小结果预览：%@ 次",stats[@"pressureResultsPreviewed"]];
 if(stats[@"historyTargetBytes"])[report appendFormat:@"\n\n旧历史整理目标：%.0f KiB\n旧历史保留：%.1f KiB\n主动折叠旧工具批次：%@ 次\n最近保留工具批次：%@ 次\n目标仅约束可整理旧历史；系统、用户原文、最近结果等另计。",[stats[@"historyTargetBytes"] doubleValue]/1024.0,[stats[@"historyRetainedBytes"] doubleValue]/1024.0,stats[@"proactiveToolBatchesCollapsed"]?:@0,stats[@"recentToolBatchesKept"]?:@0];
 if([stats[@"unusedProviderReplayBytesOmitted"] unsignedIntegerValue])[report appendFormat:@"\n未用于当前连接的推理副本：已排除 %.1f KiB（本地原文保留）",[stats[@"unusedProviderReplayBytesOmitted"] doubleValue]/1024.0];
 if([stats[@"historyBatchesArchived"] unsignedIntegerValue])[report appendFormat:@"\n工具回执合并归档：%@ 批",stats[@"historyBatchesArchived"]];
 NSDictionary *composition=stats[@"afterCompositionBytes"];
 if(composition.count){[report appendString:@"\n\n整理后构成（JSON 字节）："];for(NSString *key in @[@"system",@"user",@"assistant",@"tool",@"schemas",@"other",@"framing"]){if([composition[key] unsignedIntegerValue]==0)continue;[report appendFormat:@"\n%@：%.1f KiB",@{@"system":@"系统 / 人设",@"user":@"用户消息",@"assistant":@"AI 回复 / 工具参数 / 历史回执",@"tool":@"工具结果",@"schemas":@"工具定义",@"other":@"其他消息",@"framing":@"JSON 结构"}[key],[composition[key] doubleValue]/1024.0];}}
 [report appendFormat:@"\n\n服务商本轮输入 tokens（含显式缓存）：%@\n文本 tokens 粗估：%@\n\n粗估不是精确分词，不含图片 token。应用保护预算不是模型窗口大小，累计消耗也不是当前占用。完整历史原文保留在本机会话，可按需回读。",blocked?@"未发送，本次无模型请求用量":TFAITokenCountString(actual),TFAITokenCountString(stats[@"estimatedTextTokens"]?:@0)];
 NSDictionary *diagnostics=stats[@"agentDiagnostics"];if(diagnostics.count){[report appendFormat:@"\n\n本次执行诊断\n自动纠偏：%@ 次\n纠偏后实际修改：%@ 次\n可见原文复用：%@ 次\n策略版本：%@",diagnostics[@"recoveryAttempts"]?:@0,diagnostics[@"recoveriesWithAppliedChange"]?:@0,diagnostics[@"visibleReuses"]?:@0,diagnostics[@"contextPolicyVersion"]?:@271];}
 NSDictionary *breakdown=stats[@"toolBreakdown"];
 NSArray *names=[breakdown.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){NSUInteger x=[breakdown[a][@"argumentsJSONBytes"] unsignedIntegerValue]+[breakdown[a][@"resultsUTF8Bytes"] unsignedIntegerValue],y=[breakdown[b][@"argumentsJSONBytes"] unsignedIntegerValue]+[breakdown[b][@"resultsUTF8Bytes"] unsignedIntegerValue];return x>y?NSOrderedAscending:x<y?NSOrderedDescending:NSOrderedSame;}];
 if(names.count)[report appendString:@"\n\n原始工具占用（整理前，非本次发送量）："];
 for(NSString *name in [names subarrayWithRange:NSMakeRange(0,MIN(names.count,4))]){NSDictionary *r=breakdown[name];[report appendFormat:@"\n%@ ×%@：参数 %.1f KiB，结果 %.1f KiB",name,r[@"calls"],[r[@"argumentsJSONBytes"] doubleValue]/1024.0,[r[@"resultsUTF8Bytes"] doubleValue]/1024.0];}
 return report;
}
+ (NSDictionary *)schema { return @{@"name":@"read_context",@"description":@"Read original historical tool arguments/results or assistant text from THIS conversation only, using an exact ref provided by a context preview. No filesystem access and no execution. UTF-16 code units, not bytes or tokens: offset is an integer >= 0 (default 0); limit is an integer 1..4096 (default 4096). Only retrieve omitted details required for the current decision, not the whole history. Reuse pages already read; do not read the results of read_context again to recover the same content. For source, guide or error text inside a JSON result, prefer field=content/text/message/error and start_line/line_count (1-based within that field; default 200, maximum 400), optional column for a long line and max_chars=1..16384 to bound the returned field text (default 16384). Under budget pressure use max_chars=512..1024 or a short line range rather than rereading a whole file. Field pages return next_line/next_column; do not mix field with offset/limit. Prefer live read_file or classdump_headers for current files, not historical JSON paging. Omit limit for the default page; continue using the returned next_offset, never request the entire original in one oversized page. Historical results may be stale: verify changed or unverified files/state before writing. Reuse up-to-date excerpts already present; do not blanket re-read the project. Offload markers must never be used as source code.",@"parameters":@{@"type":@"object",@"properties":@{@"field":@{@"type":@"string",@"enum":@[@"content",@"text",@"message",@"error"]},@"start_line":@{@"type":@"integer",@"minimum":@1},@"line_count":@{@"type":@"integer",@"minimum":@1,@"maximum":@400},@"column":@{@"type":@"integer",@"minimum":@0},@"max_chars":@{@"type":@"integer",@"minimum":@1,@"maximum":@16384},@"ref":@{@"type":@"string",@"minLength":@1,@"maxLength":@1024},@"offset":@{@"type":@"integer",@"minimum":@0},@"limit":@{@"type":@"integer",@"minimum":@1,@"maximum":@4096}},@"required":@[@"ref"],@"additionalProperties":@NO}}; }
+ (BOOL)containsPlaceholder:(id)value { if([value isKindOfClass:NSString.class]){NSString *trimmed=[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if([trimmed hasPrefix:ContextMarker])return YES;static NSRegularExpression *stub;static dispatch_once_t once;dispatch_once(&once,^{stub=[NSRegularExpression regularExpressionWithPattern:@"\\[DYLIX_CONTEXT_OFFLOADED\\] bytes=[0-9]+ sha256=[a-f0-9]{64} ref=" options:0 error:nil];});return [stub firstMatchInString:value options:0 range:NSMakeRange(0,[value length])]!=nil;}if([value isKindOfClass:NSDictionary.class]){for(id key in value)if([self containsPlaceholder:value[key]])return YES;}if([value isKindOfClass:NSArray.class])for(id item in value)if([self containsPlaceholder:item])return YES;return NO; }
+ (NSDictionary *)read:(NSDictionary *)arguments messages:(NSArray *)messages error:(NSError **)error {
 NSString *ref=Text(arguments[@"ref"]),*text=nil,*originalTool=@"";NSUInteger ordinal=0,matches=0;
 for(NSDictionary *m in messages){if([m[@"role"] isEqual:@"system"])continue;
  if([ref isEqual:[NSString stringWithFormat:@"message:%lu",(unsigned long)ordinal]]){text=Text(m[@"content"]);matches++;}
  for(NSDictionary *call in m[@"tool_calls"])if([ref isEqual:[@"arguments:" stringByAppendingString:Text(call[@"id"])]]){text=JSON(call[@"arguments"]?:@{});matches++;}
  if([m[@"role"] isEqual:@"tool"]&&[ref isEqual:[@"result:" stringByAppendingString:Text(m[@"tool_call_id"])]]){text=Text(m[@"content"]);matches++;}
  for(NSDictionary *c in m[@"tool_calls"])if([ref isEqual:[@"result:" stringByAppendingString:Text(c[@"id"])]])originalTool=Text(c[@"name"]);
  ordinal++;
 }
 if(!text||matches!=1){if(error)*error=Failure(@"原文引用不属于当前会话或已不存在，请重新查询。 ");return nil;}
 if(arguments[@"field"])return FieldPage(text,ref,arguments,originalTool,error);
 if(arguments[@"start_line"]||arguments[@"line_count"]||arguments[@"column"]||arguments[@"max_chars"]){if(error)*error=Failure(@"行分页需要指定 field。 ");return nil;}
 NSUInteger offset=[arguments[@"offset"] unsignedIntegerValue],limit=arguments[@"limit"]?[arguments[@"limit"] unsignedIntegerValue]:4096;
 if(!limit||limit>4096||offset>text.length){if(error)*error=Failure(@"原文分页范围无效。 ");return nil;}
 NSUInteger end=MIN(text.length,offset+limit);if(offset<text.length&&[text rangeOfComposedCharacterSequenceAtIndex:offset].location!=offset){if(error)*error=Failure(@"offset 位于组合字符内，请使用返回的 next_offset。 ");return nil;}
 if(end<text.length)end=[text rangeOfComposedCharacterSequenceAtIndex:end].location;
 // A single composed cluster can exceed a page; fail rather than return a stuck cursor.
 if(end==offset&&offset<text.length){if(error)*error=Failure(@"单个组合字符超过分页上限，无法安全分页。 ");return nil;}
 return @{@"ref":ref,@"text":[text substringWithRange:NSMakeRange(offset,end-offset)],@"offset":@(offset),@"next_offset":end<text.length?@(end):NSNull.null,@"total_utf16":@(text.length),@"original_bytes":@([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]),@"sha256":Digest(text),@"historical":@YES};
}
// Only omit a duplicate when its exact canonical page is still visible to the
// model. A page merely present in the local archive must remain retrievable.
static BOOL VisiblePage(id node,NSDictionary *page,NSUInteger depth){
 if(depth>12)return NO;
 if([node isKindOfClass:NSArray.class]){for(id v in node)if(VisiblePage(v,page,depth+1))return YES;}
 if([node isKindOfClass:NSDictionary.class]){
  if([node[@"ref"] isEqual:page[@"ref"]]&&[node[@"sha256"] isEqual:page[@"sha256"]]&&[node[@"offset"] isKindOfClass:NSNumber.class]&&[node[@"text"] isKindOfClass:NSString.class]){
   NSUInteger start=[node[@"offset"] unsignedIntegerValue],wanted=[page[@"offset"] unsignedIntegerValue];NSString *text=node[@"text"],*part=page[@"text"];
   if(wanted>=start&&wanted-start<=text.length&&part.length<=text.length-(wanted-start)&&[[text substringWithRange:NSMakeRange(wanted-start,part.length)] isEqual:part])return YES;
  }
  NSDictionary *source=[node[@"source"] isKindOfClass:NSDictionary.class]?node[@"source"]:nil;
  if(source&&[page[@"view"] isEqual:@"field"]&&[@[@"content",@"text"] containsObject:page[@"field"]]&&[page[@"path"] isEqual:source[@"path"]]&&[page[@"source_sha256"] isEqual:source[@"sha256"]]){
   NSUInteger base=[source[@"start_line"] unsignedIntegerValue],wanted=[page[@"start_line"] unsignedIntegerValue];NSString *text=Text(source[@"content"]);NSArray *lines=[text componentsSeparatedByString:@"\n"];if(wanted>=base&&wanted-base<lines.count){NSUInteger offset=0;for(NSUInteger i=0;i<wanted-base;i++)offset+=[lines[i] length]+1;offset+=[page[@"column"] unsignedIntegerValue];NSString *part=Text(page[@"text"]);if(offset<=text.length&&part.length<=text.length-offset&&[[text substringWithRange:NSMakeRange(offset,part.length)] isEqual:part])return YES;}
  }
  if([node[@"loaded_guides"] isKindOfClass:NSArray.class]&&[page[@"offset"] unsignedIntegerValue]==0){id decoded=[NSJSONSerialization JSONObjectWithData:[Text(page[@"text"]) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];if([decoded isKindOfClass:NSDictionary.class]&&[node[@"loaded_guides"] containsObject:decoded])return YES;}
  for(id key in node)if(VisiblePage(node[key],page,depth+1))return YES;
 }
 return NO;
}
+ (NSDictionary *)read:(NSDictionary *)arguments messages:(NSArray *)messages visibleMessages:(NSArray *)visibleMessages error:(NSError **)error {
 NSDictionary *page=[self read:arguments messages:messages error:error];if(!page||![page[@"text"] length])return page;
 for(NSDictionary *m in visibleMessages){NSString *content=Text(m[@"content"]);id data=nil;
  if([m[@"role"] isEqual:@"tool"]&&[page[@"ref"] isEqual:[@"result:" stringByAppendingString:Text(m[@"tool_call_id"])]]){
   NSString *expected=page[@"original_sha256"]?:page[@"sha256"];if([Digest(content) isEqual:expected]){NSMutableDictionary *reuse=[page mutableCopy];[reuse removeObjectForKey:@"text"];reuse[@"already_visible"]=@YES;reuse[@"visible_location"]=[@"tool_result:" stringByAppendingString:Text(m[@"tool_call_id"])];reuse[@"notice"]=@"原始结果仍完整可见，直接使用该工具结果，不再请求同一原文。";return reuse;}
  }
  if([m[@"role"] isEqual:@"tool"])data=[NSJSONSerialization JSONObjectWithData:[content dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
  else if([content hasPrefix:@"[DYLIX_WORKING_SET]"]){NSRange newline=[content rangeOfString:@"\n"];if(newline.location!=NSNotFound)data=[NSJSONSerialization JSONObjectWithData:[[content substringFromIndex:newline.location+1] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];}
  if(data&&VisiblePage(data,page,0)){NSMutableDictionary *reuse=[page mutableCopy];reuse[@"end_offset"]=@([page[@"offset"] unsignedIntegerValue]+[page[@"text"] length]);[reuse removeObjectForKey:@"text"];reuse[@"already_visible"]=@YES;reuse[@"visible_location"]=[content hasPrefix:@"[DYLIX_WORKING_SET]"]?@"working_set":@"historical_page";reuse[@"notice"]=@"原文已在所标注的当前工作证据/工具结果中；直接使用，只有缺失范围才需读取。";return reuse;}
 }
 return page;
}
+ (NSArray *)project:(NSArray *)messages schemas:(NSArray *)schemas statistics:(NSDictionary **)statistics error:(NSError **)error {
 return [self project:messages connection:nil schemas:schemas statistics:statistics error:error];
}
+ (NSArray *)project:(NSArray *)messages connection:(NSDictionary *)connection schemas:(NSArray *)schemas statistics:(NSDictionary **)statistics error:(NSError **)error {
 NSUInteger replayOmitted=0,rawBefore=0;
 NSMutableArray *raw=[NSMutableArray new];for(id m in messages)if([m isKindOfClass:NSDictionary.class])[raw addObject:WireMessage(m)];rawBefore=Measure(raw,schemas);
 NSUInteger ContextBudget=[self budgetKiB]*1024;
 NSMutableArray *out=[NSMutableArray new];NSUInteger ordinal=0,argumentsOffloaded=0,resultsOffloaded=0,collapsed=0,assistantOffloaded=0;NSMutableDictionary *refs=[NSMutableDictionary new];NSMutableArray *originals=[NSMutableArray new];NSMutableIndexSet *plainAssistants=[NSMutableIndexSet new];
 for(NSDictionary *m in messages){if(![m isKindOfClass:NSDictionary.class])continue;NSDictionary *wire=ReplayMessage(m,connection,&replayOmitted);[originals addObject:[wire copy]];[out addObject:[wire mutableCopy]];if([m[@"role"] isEqual:@"assistant"]&&![m[@"tool_calls"] count])[plainAssistants addIndex:out.count-1];if(![m[@"role"] isEqual:@"system"]){refs[@(out.count-1)]=[NSString stringWithFormat:@"message:%lu",(unsigned long)ordinal];ordinal++;}}
 NSMutableDictionary *breakdown=[NSMutableDictionary new],*names=[NSMutableDictionary new];
 for(NSDictionary *m in out)for(NSDictionary *call in m[@"tool_calls"]){NSString *name=Text(call[@"name"]);names[Text(call[@"id"])]=name;NSMutableDictionary *row=breakdown[name];if(!row){row=[@{@"calls":@0,@"argumentsJSONBytes":@0,@"resultsUTF8Bytes":@0} mutableCopy];breakdown[name]=row;}row[@"calls"]=@([row[@"calls"] unsignedIntegerValue]+1);row[@"argumentsJSONBytes"]=@([row[@"argumentsJSONBytes"] unsignedIntegerValue]+Encode(call[@"arguments"]?:@{}).length);}
 for(NSDictionary *m in out)if([m[@"role"] isEqual:@"tool"]){NSMutableDictionary *row=breakdown[names[Text(m[@"tool_call_id"])]?:@""];if(row)row[@"resultsUTF8Bytes"]=@([row[@"resultsUTF8Bytes"] unsignedIntegerValue]+[Text(m[@"content"]) lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);}
 NSUInteger before=Measure(out,schemas);BOOL canRead=NO;for(NSDictionary *schema in schemas)if([schema[@"name"] isEqual:@"read_context"])canRead=YES;
 if(!canRead){if(statistics)*statistics=@{@"beforeTextJSONBytes":@(rawBefore),@"unusedProviderReplayBytesOmitted":@(replayOmitted),@"afterTextJSONBytes":@(before),@"budgetBytes":@(ContextBudget),@"estimatedTextTokens":@((before+1)/2),@"estimateOnly":@YES,@"imageTokensIncluded":@NO,@"toolBreakdown":breakdown,@"afterCompositionBytes":Composition(out,schemas),@"blockedBeforeRequest":@(before>ContextBudget)};if(before>ContextBudget){if(error)*error=Failure(@"当前连接未开放原文回读工具，上下文超出文本保护预算；请开启工具或新建会话。完整记录未删除。");return nil;}return out;}
 NSIndexSet *decisionTail=DecisionTail(out,ContextBudget);
 NSMutableArray *groups=[NSMutableArray new];
 // Only completed, adjacent call/result batches can be rewritten. Never touch pending calls.
 for(NSUInteger i=0;i<out.count;i++){NSDictionary *m=out[i];NSArray *calls=m[@"tool_calls"];if(!calls.count)continue;NSUInteger end=i+1;NSMutableDictionary *results=[NSMutableDictionary new];while(end<out.count&&[out[end][@"role"] isEqual:@"tool"]){NSString *identifier=Text(out[end][@"tool_call_id"]);if(results[identifier])break;results[identifier]=@(end++);}
  BOOL complete=results.count==calls.count;NSMutableSet *seen=[NSMutableSet new];for(NSDictionary *call in calls){NSString *identifier=Text(call[@"id"]);if(!identifier.length||!results[identifier]||[seen containsObject:identifier])complete=NO;[seen addObject:identifier];}if(!complete)continue;
  [groups addObject:@{@"start":@(i),@"end":@(end)}];NSMutableDictionary *assistant=out[i];NSMutableArray *projected=[NSMutableArray new];BOOL changed=NO;
  for(NSDictionary *call in calls){NSMutableDictionary *c=[call mutableCopy];NSString *ref=[@"arguments:" stringByAppendingString:Text(call[@"id"])];
   if((![decisionTail containsIndex:i]||Encode(call[@"arguments"]?:@{}).length>16*1024)&&![call[@"name"] isEqual:@"read_context"]){id args=Arguments(call[@"arguments"],ref,0);if(![args isEqual:call[@"arguments"]]){c[@"arguments"]=args;argumentsOffloaded++;changed=YES;}}[projected addObject:c];}
  assistant[@"tool_calls"]=projected;
  // Gemini native replay carries another copy of functionCall.args. Update BOTH
  // copies, keeping thought signatures and native IDs paired with the same call.
  if(changed&&[assistant[@"providerProtocol"] isEqual:@"gemini"]){NSMutableArray *items=[NSMutableArray new];NSUInteger callIndex=0;for(NSDictionary *item in assistant[@"provider_items"]){NSMutableDictionary *v=[item mutableCopy];NSMutableArray *parts=[NSMutableArray new];for(NSDictionary *part in item[@"parts"]){NSMutableDictionary *p=[part mutableCopy];if(p[@"functionCall"]&&callIndex<projected.count){NSMutableDictionary *f=[p[@"functionCall"] mutableCopy];f[@"args"]=projected[callIndex++][@"arguments"];p[@"functionCall"]=f;}[parts addObject:p];}if(item[@"parts"])v[@"parts"]=parts;[items addObject:v];}assistant[@"provider_items"]=items;}
  for(NSDictionary *call in calls){NSUInteger index=[results[call[@"id"]] unsignedIntegerValue];NSMutableDictionary *r=out[index];NSString *text=Text(r[@"content"]);if(![decisionTail containsIndex:i]&&![call[@"name"] isEqual:@"read_context"]&&[text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>16*1024){r[@"content"]=JSON(Receipt(text,[@"result:" stringByAppendingString:call[@"id"]],12*1024));resultsOffloaded++;}}
  i=end-1;
 }
 // Keep an independent budget for ELIGIBLE OLD history. Raising the hard
 // guard must not rehydrate old observations up to that guard on each request.
 // System/user/schema, pending batches, the newest two complete tool batches,
 // the latest plain reply and opaque native continuation are protected here.
 const NSUInteger historyTarget=MIN(64*1024,MAX(16*1024,ContextBudget/4));
 NSMutableIndexSet *eligible=[NSMutableIndexSet new];NSUInteger latestPlain=plainAssistants.lastIndex;
 NSMutableArray *oldGroups=[NSMutableArray new];
 for(NSUInteger g=0;g+2<groups.count;g++){
  NSDictionary *group=groups[g];NSUInteger start=[group[@"start"] unsignedIntegerValue],end=[group[@"end"] unsignedIntegerValue];BOOL native=NO;
  for(NSUInteger j=start;j<end;j++)if([originals[j][@"provider_items"] count]||[originals[j][@"images"] count])native=YES;
  if(native)continue;
  [oldGroups addObject:group];[eligible addIndexesInRange:NSMakeRange(start,end-start)];
 }
 for(NSUInteger index=plainAssistants.firstIndex;index!=NSNotFound;index=[plainAssistants indexGreaterThanIndex:index])if(index!=latestPlain&&![originals[index][@"provider_items"] count]&&![originals[index][@"images"] count])[eligible addIndex:index];
 // Track exact per-message JSON deltas rather than serializing the full
 // transcript for every old batch (quadratic for long FLEX runs).
 NSMutableArray *sizes=[NSMutableArray new];NSUInteger retainedHistory=0,currentBytes=Measure(out,schemas);
 for(NSUInteger j=0;j<out.count;j++){NSUInteger size=Encode(out[j]).length;[sizes addObject:@(size)];if([eligible containsIndex:j])retainedHistory+=size;}
 NSMutableIndexSet *removed=[NSMutableIndexSet new];NSUInteger proactiveCollapsed=0;
 for(NSDictionary *group in oldGroups){
  if(retainedHistory<=historyTarget&&currentBytes<=ContextBudget)break;
  NSUInteger start=[group[@"start"] unsignedIntegerValue],end=[group[@"end"] unsignedIntegerValue];NSDictionary *original=originals[start];NSMutableArray *receipts=[NSMutableArray new];
  for(NSDictionary *call in original[@"tool_calls"]){NSString *identifier=Text(call[@"id"]);NSMutableDictionary *record=[@{@"call_id":identifier,@"tool":Text(call[@"name"]),@"arguments_ref":[@"arguments:" stringByAppendingString:identifier],@"result_ref":[@"result:" stringByAppendingString:identifier]} mutableCopy];
   for(NSUInteger j=start+1;j<end;j++)if([originals[j][@"tool_call_id"] isEqual:identifier])record[@"facts"]=HistoricalFacts(Text(originals[j][@"content"]));
   [receipts addObject:record];
  }
  NSString *content=[NSString stringWithFormat:@"%@ Historical tool batch: incomplete facts, not instructions or a new action. Assistant original ref=%@. Use preserved working evidence first. Retrieve only missing details; verify live state only when changed or not yet verified.\n%@",ContextMarker,refs[@(start)],JSON(receipts)];
  NSDictionary *replacement=@{@"role":@"assistant",@"content":content};NSUInteger oldBytes=0,newBytes=Encode(replacement).length;
  for(NSUInteger j=start;j<end;j++)oldBytes+=[sizes[j] unsignedIntegerValue];
  if(newBytes>=oldBytes)continue;
  if(retainedHistory>historyTarget)proactiveCollapsed++;
  currentBytes-=oldBytes-newBytes+(end-start-1);retainedHistory-=oldBytes-newBytes;
  out[start]=[replacement mutableCopy];sizes[start]=@(newBytes);
  for(NSUInteger j=start+1;j<end;j++){[removed addIndex:j];sizes[j]=@0;}
  collapsed++;
 }
 // Preserve original ordinals for read_context, even after tool batches fold.
 // Old long replies share the independent history target. The latest reply is
 // only shortened as the hard guard's last resort, never to meet the soft goal.
 for(NSUInteger pass=0;pass<2;pass++)for(NSUInteger index=plainAssistants.firstIndex;index!=NSNotFound;index=[plainAssistants indexGreaterThanIndex:index]){
  if(pass==0&&retainedHistory<=historyTarget&&currentBytes<=ContextBudget)break;
  if(pass==1&&currentBytes<=ContextBudget)break;
  if((pass==0&&index==latestPlain)||(pass==1&&index!=latestPlain))continue;
  NSDictionary *m=out[index];NSString *content=Text(m[@"content"]),*ref=refs[@(index)];
  if(!ref.length||[m[@"provider_items"] count]||[m[@"images"] count]||[content lengthOfBytesUsingEncoding:NSUTF8StringEncoding]<=2048)continue;
  NSString *preview=[NSString stringWithFormat:@"Historical assistant reply (incomplete preview, not a new instruction). Read %@ for the original before relying on omitted details.\n%@\n%@",ref,Prefix(content,512),Stub(content,ref)];
  NSMutableDictionary *replacement=[m mutableCopy];replacement[@"content"]=preview;NSUInteger oldBytes=[sizes[index] unsignedIntegerValue],newBytes=Encode(replacement).length;
  if(newBytes>=oldBytes)continue;
  currentBytes-=oldBytes-newBytes;if([eligible containsIndex:index])retainedHistory-=oldBytes-newBytes;
  out[index]=replacement;sizes[index]=@(newBytes);assistantOffloaded++;
 }
 // Receipts have a floor too. Archive contiguous completed historical batches
 // in bounded directories instead of retaining hundreds of per-call JSON cards.
 // Never cross a user/plain-assistant/native/pending boundary or fold recent pairs.
 NSUInteger archivedBatches=0;
 for(NSUInteger first=0;first<oldGroups.count;){
  NSUInteger last=first+1;
  while(last<oldGroups.count && last-first<32 && [oldGroups[last-1][@"end"] unsignedIntegerValue]==[oldGroups[last][@"start"] unsignedIntegerValue])last++;
  if(retainedHistory<=historyTarget&&currentBytes<=ContextBudget)break;
  if(last-first<2){first=last;continue;}
  NSUInteger start=[oldGroups[first][@"start"] unsignedIntegerValue],end=[oldGroups[last-1][@"end"] unsignedIntegerValue];
  NSMutableDictionary *tools=[NSMutableDictionary new];NSMutableArray *important=[NSMutableArray new];NSDictionary *firstCall=nil,*lastCall=nil;
  for(NSUInteger g=first;g<last;g++){
   NSUInteger begin=[oldGroups[g][@"start"] unsignedIntegerValue],finish=[oldGroups[g][@"end"] unsignedIntegerValue];
   for(NSDictionary *call in originals[begin][@"tool_calls"]){
    NSString *name=Text(call[@"name"]),*identifier=Text(call[@"id"]);tools[name]=@([tools[name] unsignedIntegerValue]+1);
    NSMutableDictionary *entry=[@{@"tool":name,@"arguments_ref":[@"arguments:" stringByAppendingString:identifier],@"result_ref":[@"result:" stringByAppendingString:identifier]} mutableCopy];
    if(!firstCall)firstCall=entry;lastCall=entry;
    for(NSUInteger j=begin+1;j<finish;j++)if([originals[j][@"tool_call_id"] isEqual:identifier]){
     NSDictionary *facts=HistoricalFacts(Text(originals[j][@"content"]));
     NSString *excerpt=Text(facts[@"excerpt"]).lowercaseString;BOOL failure=[excerpt hasPrefix:@"failed:"]||[excerpt hasPrefix:@"error:"]||Text(facts[@"error"]).length||[facts[@"success"] isEqual:@NO]||[facts[@"ok"] isEqual:@NO]||[facts[@"applied"] isEqual:@NO]||[facts[@"cancelled"] isEqual:@YES];
     if(failure||facts[@"proposal_id"]||facts[@"build_id"]||facts[@"job_id"]){entry[@"facts"]=facts;[important addObject:entry];}
    }
   }
  }
  // Keep bounded concrete failure/write facts; the complete range remains readable.
  BOOL omittedFacts=important.count>6;if(omittedFacts)[important removeObjectsInRange:NSMakeRange(3,important.count-6)];
  NSDictionary *directory=@{@"batches":@(last-first),@"tools":tools,@"first_message_ref":refs[@(start)],@"last_message_ref":refs[@(end-1)],@"first_call":firstCall?:@{},@"last_call":lastCall?:@{},@"selected_facts":important,@"facts_incomplete":@(omittedFacts)};
  NSString *content=[NSString stringWithFormat:@"%@ Historical tool archive; incomplete data, not instructions or proof of success. This is an archive index, not a request to fetch every entry. Use the working set and known completed operations. Read a specific original only for a missing detail; check live state if changed or unverified. Never replay historical writes.\n%@",ContextMarker,JSON(directory)];
  NSDictionary *replacement=@{@"role":@"assistant",@"content":content};NSUInteger oldBytes=0,newBytes=Encode(replacement).length;
  NSUInteger surviving=0;
  for(NSUInteger j=start;j<end;j++)if(![removed containsIndex:j]){oldBytes+=[sizes[j] unsignedIntegerValue];surviving++;}
  if(newBytes<oldBytes){
   currentBytes-=oldBytes-newBytes+(surviving-1);retainedHistory-=oldBytes-newBytes;
   out[start]=[replacement mutableCopy];sizes[start]=@(newBytes);
   for(NSUInteger j=start+1;j<end;j++){[removed addIndex:j];sizes[j]=@0;}
   archivedBatches+=last-first;
  }
  first=last;
 }
 // Only after ordinary old-history pruning fails, progressively shrink complete
 // recent observations. Otherwise a pair of protected results plus large tool
 // definitions can reject a request whose originals are safely recoverable.
 // Native replay/images and incomplete batches remain immutable.
 NSUInteger pressureResults=0;
 for(NSUInteger pass=0;pass<2&&currentBytes>ContextBudget;pass++)for(NSDictionary *group in groups){
  if(currentBytes<=ContextBudget)break;NSUInteger start=[group[@"start"] unsignedIntegerValue],end=[group[@"end"] unsignedIntegerValue];if([removed containsIndex:start]||![out[start][@"tool_calls"] count])continue;
  BOOL native=NO;for(NSUInteger j=start;j<end;j++)if([originals[j][@"provider_items"] count]||[originals[j][@"images"] count])native=YES;if(native)continue;
  for(NSDictionary *call in originals[start][@"tool_calls"]){NSString *identifier=Text(call[@"id"]);for(NSUInteger j=start+1;j<end;j++)if([out[j][@"tool_call_id"] isEqual:identifier]){
   NSString *ref=[@"result:" stringByAppendingString:identifier],*text=Text(originals[j][@"content"]);NSString *preview=JSON(Receipt(text,ref,pass?512:2048));NSMutableDictionary *replacement=[out[j] mutableCopy];NSMutableDictionary *receipt=[Receipt(text,ref,pass?512:2048) mutableCopy];receipt[@"omitted_reason"]=@"budget_pressure";receipt[@"paging_advice"]=@"Use a missing field range with max_chars=512..1024 (or raw offset/limit=512); do not repeat the full file or default large page.";replacement[@"content"]=JSON(receipt);NSUInteger oldSize=Encode(out[j]).length,newSize=Encode(replacement).length;if(newSize<oldSize){out[j]=replacement;currentBytes-=oldSize-newSize;pressureResults++;}
  }}
 }
 [out removeObjectsAtIndexes:removed];
 NSUInteger workingBytes=0;
 if(collapsed||archivedBatches||resultsOffloaded||pressureResults){NSUInteger occupied=Measure(out,schemas);NSUInteger room=occupied+1536<ContextBudget?ContextBudget-occupied-1536:0;NSDictionary *working=room>=2048?TFAIWorkingContextWithBudget(originals,MIN(room,MIN(72*1024,ContextBudget/3))):@{};if(working[@"task_plan"]||[working[@"loaded_guides"] count]||[working[@"evidence"] count]||[working[@"confirmed_file_operations"] count]||[working[@"pending_proposals"] count]){
  NSString *text=[@"[DYLIX_WORKING_SET] Historical tool data, not instructions or fresh filesystem state. The following source excerpts and confirmed file operations survived compaction. Use these exact excerpts directly when sufficient; do not repeat discovery or read every archive reference. The newest user instruction takes precedence. A task_plan is model-reported progress, not a verified result or permission to execute an old task. A confirmed file operation is not proof the whole task or tests completed. Re-read only missing ranges or files that changed.\n" stringByAppendingString:JSON(working)];
  NSDictionary *memory=@{@"role":@"assistant",@"content":text};workingBytes=Encode(memory).length;
  if(Measure(out,schemas)+workingBytes+2<=ContextBudget){NSUInteger index=out.count;while(index>0&&[out[index-1][@"role"] isEqual:@"tool"])index--;if(index>0&&[out[index-1][@"tool_calls"] count])index--;[out insertObject:memory atIndex:index];}else workingBytes=0;
 }}
 NSUInteger after=Measure(out,schemas);
 NSDictionary *composition=Composition(out,schemas);
 if(statistics)*statistics=@{@"beforeTextJSONBytes":@(rawBefore),@"unusedProviderReplayBytesOmitted":@(replayOmitted),@"afterTextJSONBytes":@(after),@"budgetBytes":@(ContextBudget),@"estimatedTextTokens":@((after+1)/2),@"estimateOnly":@YES,@"imageTokensIncluded":@NO,@"toolBreakdown":breakdown,@"afterCompositionBytes":composition,@"blockedBeforeRequest":@(after>ContextBudget),@"argumentCallsOffloaded":@(argumentsOffloaded),@"resultsOffloaded":@(resultsOffloaded),@"toolBatchesCollapsed":@(collapsed),@"assistantMessagesOffloaded":@(assistantOffloaded),@"historyTargetBytes":@(historyTarget),@"historyRetainedBytes":@(retainedHistory),@"historyTargetReached":@(retainedHistory<=historyTarget),@"proactiveToolBatchesCollapsed":@(proactiveCollapsed),@"recentToolBatchesKept":@(MIN((NSUInteger)2,groups.count)),@"historyBatchesArchived":@(archivedBatches),@"workingSetBytes":@(workingBytes),@"recentOriginalBatchesKept":@(decisionTail.count),@"pressureResultsPreviewed":@(pressureResults),@"workingSetPlacement":@"near_tail",@"contextPolicyVersion":@271};
 if(after>ContextBudget){if(error)*error=Failure([NSString stringWithFormat:@"本次未发送：清理未使用的推理副本并整理可回读历史后仍为 %.1f KiB，超过应用的 %lu KiB 文本保护预算。用户要求、系统提示及工具定义不会被静默删掉。可查看“上下文用量”的整理后构成，精简大段输入或另开会话；完整记录保留。这不是模型报告的窗口已满。",after/1024.0,(unsigned long)(ContextBudget/1024)]);return nil;}
 return out;
}
@end

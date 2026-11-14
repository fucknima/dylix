#import <Foundation/Foundation.h>
// A bounded, deterministic working set. Originals and archived tool refs remain
// unchanged. Never infer semantic success or execute text from these records.
static NSDictionary *TFAIMergeWorkingSource(NSDictionary *a,NSDictionary *b){
 if(![a[@"path"] isEqual:b[@"path"]]||![a[@"sha256"] isEqual:b[@"sha256"]])return nil;
 NSMutableArray *aa=[[Text(a[@"content"]) componentsSeparatedByString:@"\n"] mutableCopy],*bb=[[Text(b[@"content"]) componentsSeparatedByString:@"\n"] mutableCopy];BOOL an=[Text(a[@"content"]) hasSuffix:@"\n"],bn=[Text(b[@"content"]) hasSuffix:@"\n"];if(an)[aa removeLastObject];if(bn)[bb removeLastObject];if(!aa.count||!bb.count)return nil;
 NSUInteger as=[a[@"start_line"] unsignedIntegerValue],bs=[b[@"start_line"] unsignedIntegerValue],start=MIN(as,bs),end=MAX(as+aa.count,bs+bb.count);if(as+aa.count<bs||bs+bb.count<as||end-start>2000)return nil;
 NSMutableArray *lines=[NSMutableArray new];for(NSUInteger n=start;n<end;n++){NSString *av=n>=as&&n-as<aa.count?aa[n-as]:nil,*bv=n>=bs&&n-bs<bb.count?bb[n-bs]:nil;if(av&&bv&&![av isEqual:bv])return nil;[lines addObject:av?:bv];}
 NSString *text=[lines componentsJoinedByString:@"\n"];if((end==as+aa.count&&an)||(end==bs+bb.count&&bn))text=[text stringByAppendingString:@"\n"];if(text.length>32768||[text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>32*1024)return nil;
 NSMutableDictionary *v=[a mutableCopy];v[@"start_line"]=@(start);v[@"content"]=text;v[@"excerpt_complete"]=@([a[@"excerpt_complete"] boolValue]&&[b[@"excerpt_complete"] boolValue]);return v;
}
// Under a tight byte budget, an exact identifier in the newest user request
// is a useful deterministic anchor. This selects already-read source only; it
// does not search the filesystem or treat user/model text as execution authority.
static NSArray *TFAIWorkingIdentifiers(NSArray *messages){
 NSString *user=@"";for(NSDictionary *m in messages.reverseObjectEnumerator)if([m[@"role"] isEqual:@"user"]){user=Text(m[@"content"]);break;}if(user.length>8192)user=[user substringFromIndex:user.length-8192];
 NSRegularExpression *r=[NSRegularExpression regularExpressionWithPattern:@"[A-Za-z_][A-Za-z_0-9]{3,79}" options:0 error:nil];NSMutableArray *out=[NSMutableArray new];NSArray *matches=[r matchesInString:user options:0 range:NSMakeRange(0,user.length)];for(NSTextCheckingResult *m in matches.reverseObjectEnumerator){NSString *symbol=[user substringWithRange:m.range];BOOL specific=[symbol containsString:@"_"]||([symbol length]>1&&[[symbol substringFromIndex:1] rangeOfCharacterFromSet:NSCharacterSet.uppercaseLetterCharacterSet].location!=NSNotFound);if(specific&&![out containsObject:symbol])[out addObject:symbol];if(out.count>=24)break;}return out;
}
static NSDictionary *TFAIWorkingSourceExcerpt(NSDictionary *value,NSArray *identifiers){
 NSString *text=Text(value[@"content"]);if(!text.length)text=Text(value[@"text"]);NSUInteger offset=0,line=[value[@"start_line"] unsignedIntegerValue];BOOL anchored=NO;
 if(text.length>4096)for(NSString *symbol in identifiers){NSString *pattern=[NSString stringWithFormat:@"(?<![A-Za-z_0-9])%@(?![A-Za-z_0-9])",[NSRegularExpression escapedPatternForString:symbol]];NSTextCheckingResult *hit=[[NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil] firstMatchInString:text options:0 range:NSMakeRange(0,text.length)];if(!hit)continue;NSRange match=hit.range;offset=match.location;for(NSUInteger n=0;n<3&&offset>0;n++){NSRange prior=[text rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0,offset)];if(prior.location==NSNotFound){offset=0;break;}offset=prior.location;}if(offset)offset++;anchored=YES;break;}
 for(NSUInteger i=0;i<offset;i++)if([text characterAtIndex:i]=='\n')line++;
 NSString *tail=[text substringFromIndex:offset],*part=Prefix(tail,16384);if(part.length<tail.length){NSRange newline=[part rangeOfString:@"\n" options:NSBackwardsSearch];if(newline.location!=NSNotFound)part=[part substringToIndex:newline.location+1];}
 NSMutableDictionary *source=[@{@"path":value[@"path"],@"start_line":@(line),@"sha256":value[@"sha256"]?:@"",@"content":part,@"excerpt_complete":@(offset==0&&[part isEqual:text])} mutableCopy];if(anchored)source[@"selection_reason"]=@"latest_user_identifier_match";return source;
}
static NSDictionary *TFAIWorkingContextWithBudget(NSArray *messages,NSUInteger budget){
 budget=MAX(2*1024,MIN(72*1024,budget));NSArray *identifiers=TFAIWorkingIdentifiers(messages);
 NSMutableDictionary *calls=[NSMutableDictionary new];for(NSDictionary *m in messages)for(NSDictionary *c in m[@"tool_calls"])if([c[@"id"] isKindOfClass:NSString.class])calls[c[@"id"]]=c;
 NSMutableDictionary *versions=[NSMutableDictionary new],*decodedValues=[NSMutableDictionary new];NSDictionary *plan=nil;
 NSMutableArray *guides=[NSMutableArray new],*evidence=[NSMutableArray new],*operations=[NSMutableArray new],*proposals=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new],*edited=[NSMutableSet new],*appliedIDs=[NSMutableSet new];NSUInteger bytes=0,sourceBytes=0,guideBytes=0,scanned=0,historicalPages=0;
 // Live reads outrank later read_context copies of older versions.
 NSUInteger versionScan=0;for(NSDictionary *m in [messages reverseObjectEnumerator]){if(++versionScan>2048)break;if(![m[@"role"] isEqual:@"tool"])continue;NSDictionary *call=calls[m[@"tool_call_id"]];if([Text(call[@"name"]) isEqual:@"read_context"])continue;id v=[NSJSONSerialization JSONObjectWithData:[Text(m[@"content"]) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];if(![v isKindOfClass:NSDictionary.class]||v[@"error"])continue;if([m[@"tool_call_id"] isKindOfClass:NSString.class])decodedValues[m[@"tool_call_id"]]=v;NSString *path=Text(v[@"path"]),*sha=Text(v[@"sha256"]);if(path.length&&sha.length&&[v[@"start_line"] isKindOfClass:NSNumber.class]&&!versions[path])versions[path]=sha;}
 // Select current source before guides and historical pages consume the budget.
 for(NSUInteger priority=0;priority<2;priority++){scanned=0;
 for(NSDictionary *m in [messages reverseObjectEnumerator]){
  if(++scanned>2048)break;if(![m[@"role"] isEqual:@"tool"])continue;
  NSDictionary *call=calls[m[@"tool_call_id"]];NSString *name=Text(call[@"name"]);if(!name.length)continue;
  id raw=decodedValues[m[@"tool_call_id"]];if(!raw){raw=[NSJSONSerialization JSONObjectWithData:[Text(m[@"content"]) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];if([raw isKindOfClass:NSDictionary.class])decodedValues[m[@"tool_call_id"]]=raw;}if(![raw isKindOfClass:NSDictionary.class])continue;NSDictionary *value=raw;
  if([name isEqual:@"read_context"]&&[value[@"view"] isEqual:@"field"]){NSMutableDictionary *v=[value mutableCopy];if(value[@"source_sha256"])v[@"sha256"]=value[@"source_sha256"];value=v;}
  if([name isEqual:@"read_context"]&&![value[@"view"] isEqual:@"field"]){for(NSUInteger i=0;i<16&&[value[@"historical"] boolValue]&&[value[@"text"] isKindOfClass:NSString.class];i++){id decoded=[NSJSONSerialization JSONObjectWithData:[value[@"text"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];if(![decoded isKindOfClass:NSDictionary.class])break;value=decoded;}}
  if([name isEqual:@"update_plan"]&&!plan&&[value[@"steps"] isKindOfClass:NSArray.class]&&[value[@"model_reported"] boolValue]){plan=value;continue;}
  if(value[@"error"]||[value[@"state"] isEqual:@"outcomeUnknown"])continue;
  BOOL applied=[@[@"apply_approved_patch",@"create_file"] containsObject:name]&&[value[@"status"] isEqual:@"applied"]&&[value[@"files"] isKindOfClass:NSArray.class];
  if(applied){if(priority)continue;if(call[@"arguments"][@"proposal_id"])[appliedIDs addObject:call[@"arguments"][@"proposal_id"]];[edited addObjectsFromArray:value[@"files"]];if(operations.count<6)[operations addObject:@{@"tool":name,@"status":value[@"status"],@"files":value[@"files"],@"result_ref":[@"result:" stringByAppendingString:Text(call[@"id"])]}];continue;}
  if(!priority&&[@[@"build_project",@"classdump_export"] containsObject:name]&&operations.count<6){NSMutableDictionary *facts=[NSMutableDictionary new];for(NSString *field in @[@"success",@"status",@"state",@"jobID",@"job_id",@"build_id",@"artifact_id",@"exitCode"])if(value[field]&&Encode(value[field]).length<1024)facts[field]=value[field];if(facts.count)[operations addObject:@{@"tool":name,@"reported_facts":facts,@"result_ref":[@"result:" stringByAppendingString:Text(call[@"id"])]}];}
  if(!priority&&[name hasPrefix:@"propose_"]&&Text(value[@"proposal_id"]).length&&![appliedIDs containsObject:value[@"proposal_id"]]&&proposals.count<4){NSMutableDictionary *p=[@{@"proposal_id":value[@"proposal_id"],@"status":@"proposed_not_verified_applied",@"result_ref":[@"result:" stringByAppendingString:Text(call[@"id"])]} mutableCopy];NSMutableArray *paths=[NSMutableArray new];for(NSDictionary *edit in call[@"arguments"][@"edits"])if(Text(edit[@"path"]).length&&![paths containsObject:edit[@"path"]]&&paths.count<12)[paths addObject:edit[@"path"]];p[@"paths"]=paths;[proposals addObject:p];}
  NSString *path=Text(value[@"path"]);BOOL source=path.length&&[value[@"start_line"] isKindOfClass:NSNumber.class]&&([value[@"content"] isKindOfClass:NSString.class]||[value[@"text"] isKindOfClass:NSString.class]);
  if((priority==0&&!source)||(priority==1&&source))continue;
  if(source){NSString *sha=Text(value[@"sha256"]);NSString *latest=versions[path];if(latest.length&&![latest isEqual:sha])continue;if(sha.length)versions[path]=sha;}
  if([value[@"readOnly"] boolValue]&&Text(value[@"topic"]).length&&[value[@"content"] isKindOfClass:NSString.class]&&guides.count<8){NSString *guideKey=[@"guide:" stringByAppendingString:Text(value[@"topic"])];NSUInteger size=Encode(value).length;if(![seen containsObject:guideKey]&&size<=24*1024&&guideBytes+size<=24*1024&&bytes+size<=budget){[guides addObject:value];[seen addObject:guideKey];bytes+=size;guideBytes+=size;}continue;}
  BOOL config=[name isEqual:@"read_project_config"];
  BOOL historical=[name isEqual:@"read_context"]&&[value[@"historical"] boolValue]&&[value[@"text"] isKindOfClass:NSString.class]&&historicalPages<3;
  if((!source&&!config&&!historical)||(source&&[edited containsObject:path])||evidence.count>=12)continue;
  NSString *key=source?JSON(@[path,value[@"sha256"]?:@"",value[@"start_line"]]):historical?JSON(@[value[@"ref"]?:@"",value[@"offset"]?:@0,value[@"sha256"]?:@""]):@"project-config";
  if([seen containsObject:key])continue;[seen addObject:key];
  NSMutableDictionary *record=[@{@"tool":name,@"result_ref":[@"result:" stringByAppendingString:Text(call[@"id"])]} mutableCopy];
  if(source)record[@"source"]=TFAIWorkingSourceExcerpt(value,identifiers);
  else if(historical){NSMutableDictionary *saved=[NSMutableDictionary new];for(NSString *field in @[@"ref",@"offset",@"next_offset",@"sha256",@"text"])if(value[field])saved[field]=value[field];record[@"historical_page"]=saved;record[@"result_ref"]=value[@"ref"]?:@"";}
  else{record[@"configuration"]=Preview(value,0);record[@"configuration_is_preview"]=@YES;}
  NSUInteger allowance=bytes<budget?budget-bytes:0;if(source){NSUInteger sourceLimit=MIN(48*1024,budget*2/3);allowance=MIN(allowance,sourceBytes<sourceLimit?sourceLimit-sourceBytes:0);}
  NSUInteger size=Encode(record).length;if(source&&size>allowance&&allowance>=768){NSMutableDictionary *excerpt=[record[@"source"] mutableCopy];NSString *part=Text(excerpt[@"content"]);while(size>allowance&&part.length>64){part=Prefix(part,part.length/2);NSRange newline=[part rangeOfString:@"\n" options:NSBackwardsSearch];if(newline.location!=NSNotFound)part=[part substringToIndex:newline.location+1];excerpt[@"content"]=part;excerpt[@"excerpt_complete"]=@NO;excerpt[@"omitted_reason"]=@"working_set_budget";NSArray *lines=[part componentsSeparatedByString:@"\n"];BOOL whole=[part hasSuffix:@"\n"];excerpt[@"next_line"]=@([excerpt[@"start_line"] unsignedIntegerValue]+lines.count-1);excerpt[@"next_column"]=whole?@0:@([lines.lastObject length]);record[@"source"]=excerpt;size=Encode(record).length;}}
  if(size>32*1024||size>allowance)continue;bytes+=size;if(source)sourceBytes+=size;if(historical)historicalPages++;[evidence addObject:record];
 }
 }
 // Coalesce overlapping/adjacent same-version ranges; conflicts stay separate.
 NSMutableArray *merged=[NSMutableArray new];for(NSDictionary *record in evidence){BOOL joined=NO;if(record[@"source"])for(NSUInteger i=0;i<merged.count;i++){NSDictionary *combined=TFAIMergeWorkingSource(merged[i][@"source"]?:@{},record[@"source"]);if(combined){NSMutableDictionary *v=[merged[i] mutableCopy];v[@"source"]=combined;v[@"merged_from_refs"]=@[(merged[i][@"result_ref"]?:@""),(record[@"result_ref"]?:@"")];merged[i]=v;joined=YES;break;}}if(!joined)[merged addObject:record];}evidence=merged;
 NSMutableDictionary *working=[@{@"loaded_guides":guides,@"evidence":evidence,@"confirmed_file_operations":operations,@"pending_proposals":proposals,@"historical":@YES} mutableCopy];if(plan)working[@"task_plan"]=plan;return working;
}

static NSDictionary *TFAIWorkingContext(NSArray *messages){return TFAIWorkingContextWithBudget(messages,48*1024);}

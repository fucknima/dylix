#import "TFAIPersona.h"
NSString *const TFAIPersonaDidChangeNotification=@"TFAIPersonaDidChange";
NSString *const TFAIPersonaBeginMarker=@"<!-- dylix-persona:begin -->";
NSString *const TFAIPersonaEndMarker=@"<!-- dylix-persona:end -->";
NSArray *TFAIPersonasSorted(NSArray *items){NSMutableArray *pins=[NSMutableArray new],*rest=[NSMutableArray new];for(TFAIPersona *p in items)[p.pinned?pins:rest addObject:p];[pins sortUsingComparator:^NSComparisonResult(TFAIPersona *a,TFAIPersona *b){return a.updatedAt>b.updatedAt?NSOrderedAscending:a.updatedAt<b.updatedAt?NSOrderedDescending:NSOrderedSame;}];[pins addObjectsFromArray:rest];return pins.copy;}
static NSError *PersonaError(NSString *text){return [NSError errorWithDomain:@"Dylix.Persona" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}
static BOOL ModeValid(id mode){return [mode isKindOfClass:NSString.class]&&[@[@"prepend",@"append",@"replace"] containsObject:mode];}
static BOOL StringArrayValid(id value){if(value==nil)return YES;if(![value isKindOfClass:NSArray.class])return NO;for(id item in value)if(![item isKindOfClass:NSString.class])return NO;return YES;}
// Additive v3 metadata; v1/v2 readers migrate with a private snapshot.
static NSNumber *PersonaStorageVersion(void){return @3;}
NSString *TFAIPersonaModeLabel(NSString *mode){return [mode isEqual:@"prepend"]?@"前置":[mode isEqual:@"replace"]?@"替换":@"后置";}
@implementation TFAIPersona
- (instancetype)initWithJSON:(NSDictionary *)j {
 if(![j isKindOfClass:NSDictionary.class]||![j[@"id"] isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:j[@"id"]]||![j[@"name"] isKindOfClass:NSString.class]||![j[@"body"] isKindOfClass:NSString.class]||!ModeValid(j[@"mode"])||![j[@"updatedAt"] isKindOfClass:NSNumber.class]||![j[@"isBuiltin"] isKindOfClass:NSNumber.class])return nil;
 for(NSString *key in @[@"builtinKey",@"summary",@"replyPrefix",@"selfCheckCommand",@"selfCheckReply",@"generation"])if(j[key]&&![j[key] isKindOfClass:NSString.class])return nil;if(!StringArrayValid(j[@"modelPatterns"])||!StringArrayValid(j[@"providerIDs"])||(j[@"matchPriority"]&&![j[@"matchPriority"] isKindOfClass:NSNumber.class]))return nil;
 if(j[@"pinned"]&&![j[@"pinned"] isKindOfClass:NSNumber.class])return nil;
 if((self=[super init])){_pinned=[j[@"pinned"] boolValue];_identifier=[j[@"id"] copy];_name=[j[@"name"] copy];_body=[j[@"body"] copy];_mode=[j[@"mode"] copy];_isBuiltin=[j[@"isBuiltin"] boolValue];_updatedAt=[j[@"updatedAt"] doubleValue];_builtinKey=[j[@"builtinKey"] copy]?:@"";_summary=[j[@"summary"] copy]?:@"";_replyPrefix=[j[@"replyPrefix"] copy]?:@"";_selfCheckCommand=[j[@"selfCheckCommand"] copy]?:@"";_selfCheckReply=[j[@"selfCheckReply"] copy]?:@"";_generation=[j[@"generation"] copy]?:@"";_modelPatterns=[j[@"modelPatterns"] copy]?:@[];_providerIDs=[j[@"providerIDs"] copy]?:@[];_matchPriority=[j[@"matchPriority"] integerValue];}return self;
}
- (NSUInteger)byteCount{return [self.body lengthOfBytesUsingEncoding:NSUTF8StringEncoding];}
- (NSDictionary *)JSON{return @{@"pinned":@(self.pinned),@"id":self.identifier,@"name":self.name,@"body":self.body,@"mode":self.mode,@"isBuiltin":@(self.isBuiltin),@"updatedAt":@(self.updatedAt),@"builtinKey":self.builtinKey,@"summary":self.summary,@"replyPrefix":self.replyPrefix,@"selfCheckCommand":self.selfCheckCommand,@"selfCheckReply":self.selfCheckReply,@"generation":self.generation,@"modelPatterns":self.modelPatterns,@"providerIDs":self.providerIDs,@"matchPriority":@(self.matchPriority)};}
@end
@interface TFAIPersonaStore ()
@property NSURL *url;
@property NSRecursiveLock *lock;
@property NSDictionary *state,*catalog;
@property NSArray *cachedPersonas;
@property(nonatomic,readwrite) NSError *loadError;
- (BOOL)backupBeforeMigration:(NSError **)error;
@end
@implementation TFAIPersonaStore
+ (instancetype)shared{static TFAIPersonaStore *store;static dispatch_once_t once;dispatch_once(&once,^{NSURL *root=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;store=[[self alloc]initWithURL:[[root URLByAppendingPathComponent:@"DylixPersona" isDirectory:YES] URLByAppendingPathComponent:@"personas.json"]];});return store;}
- (instancetype)initWithURL:(NSURL *)url{return [self initWithURL:url builtinsURL:[NSBundle.mainBundle URLForResource:@"Builtins" withExtension:@"json" subdirectory:@"Personas"]];}
- (instancetype)initWithURL:(NSURL *)url builtinsURL:(NSURL *)builtinsURL {
 if((self=[super init])){
  _url=url;_lock=[NSRecursiveLock new];_catalog=@{};
  if(builtinsURL){NSData *data=[NSData dataWithContentsOfURL:builtinsURL];id j=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;BOOL valid=[j isKindOfClass:NSDictionary.class]&&[j[@"catalogVersion"] isKindOfClass:NSNumber.class]&&[j[@"catalogVersion"] integerValue]>=1&&[j[@"personas"] isKindOfClass:NSArray.class]&&[j[@"tailBody"] isKindOfClass:NSString.class]&&[j[@"prefixTemplate"] isKindOfClass:NSString.class]&&StringArrayValid(j[@"retiredBuiltinKeys"]);NSMutableSet *ids=[NSMutableSet new];
   if(valid)for(id row in j[@"personas"]){TFAIPersona *p=[[TFAIPersona alloc]initWithJSON:row];if(!p||!p.isBuiltin||[ids containsObject:p.identifier]){valid=NO;break;}[ids addObject:p.identifier];}
   if(valid)_catalog=j;else _loadError=PersonaError(@"内置人设资源异常，请重新安装完整版本。");
  }
  _state=@{@"schemaVersion":PersonaStorageVersion(),@"catalogVersion":@0,@"enabled":@NO,@"personas":@[],@"activeID":NSNull.null,@"hiddenBuiltins":@[],@"tailEnabled":@NO,@"matchingMode":@"auto",@"includeDeveloperPrompt":@YES};
  BOOL exists=[NSFileManager.defaultManager fileExistsAtPath:url.path];BOOL migration=NO;
  if(exists){NSError *e=nil;NSData *data=[NSData dataWithContentsOfURL:url options:0 error:&e];id j=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:&e]:nil;
   if(![j isKindOfClass:NSDictionary.class]||![@[@1,@2,@3] containsObject:j[@"schemaVersion"]]||![j[@"enabled"] isKindOfClass:NSNumber.class]||![j[@"personas"] isKindOfClass:NSArray.class])_loadError=e?:PersonaError(@"人设存储格式异常，原文件已保留。");
   else {NSMutableSet *ids=[NSMutableSet new];NSMutableArray *rows=[NSMutableArray new];BOOL valid=YES;for(id row in j[@"personas"]){TFAIPersona *p=[[TFAIPersona alloc]initWithJSON:row];if(!p||[ids containsObject:p.identifier]){valid=NO;break;}[ids addObject:p.identifier];[rows addObject:p.JSON];}
    id active=j[@"activeID"];if(active!=NSNull.null&&(![active isKindOfClass:NSString.class]||![ids containsObject:active]))valid=NO;
    id hidden=j[@"hiddenBuiltins"]?:@[];if(![hidden isKindOfClass:NSArray.class])valid=NO;else for(id v in hidden)if(![v isKindOfClass:NSString.class])valid=NO;
    if(j[@"tailEnabled"]&&![j[@"tailEnabled"] isKindOfClass:NSNumber.class])valid=NO;
    if(j[@"includeDeveloperPrompt"]&&![j[@"includeDeveloperPrompt"] isKindOfClass:NSNumber.class])valid=NO;
    NSString *matching=[j[@"matchingMode"] isKindOfClass:NSString.class]?j[@"matchingMode"]:nil;if(matching&&![@[@"auto",@"manual"] containsObject:matching])valid=NO;if(!matching)matching=[active isKindOfClass:NSString.class]?@"manual":@"auto";
    NSNumber *storedCatalog=[j[@"catalogVersion"] isKindOfClass:NSNumber.class]?j[@"catalogVersion"]:@0;
    if(valid){_state=@{@"schemaVersion":PersonaStorageVersion(),@"catalogVersion":storedCatalog,@"enabled":j[@"enabled"],@"personas":rows.copy,@"activeID":active,@"hiddenBuiltins":hidden,@"tailEnabled":j[@"tailEnabled"]?:@NO,@"matchingMode":matching,@"includeDeveloperPrompt":j[@"includeDeveloperPrompt"]?:@YES};migration=![j[@"schemaVersion"] isEqual:PersonaStorageVersion()]||j[@"matchingMode"]==nil;}else _loadError=PersonaError(@"人设记录异常，原文件已保留。");
   }
  }
  if(!_loadError){NSMutableArray *rows=[_state[@"personas"] mutableCopy];NSNumber *catalogVersion=_catalog[@"catalogVersion"]?:@0;BOOL catalogUpgrade=[catalogVersion integerValue]>[_state[@"catalogVersion"] integerValue];
   for(NSDictionary *p in _catalog[@"personas"]){NSUInteger index=NSNotFound;for(NSUInteger i=0;i<rows.count;i++)if([rows[i][@"id"] isEqual:p[@"id"]]){index=i;break;}if(index==NSNotFound){if(![_state[@"hiddenBuiltins"] containsObject:p[@"id"]]){[rows addObject:p];migration=YES;}}else if(catalogUpgrade&&[rows[index][@"isBuiltin"] boolValue]&&[rows[index][@"updatedAt"] doubleValue]==0&&![_state[@"hiddenBuiltins"] containsObject:p[@"id"]]){NSMutableDictionary *fresh=[p mutableCopy];for(NSString *key in @[@"pinned"])if(rows[index][key])fresh[key]=rows[index][key];rows[index]=fresh;migration=YES;}}
   // Catalog upgrades refresh untouched builtins, but never delete legacy records,
   // overwrite user-edited rows, or clear the current selection.
   if(catalogUpgrade)migration=YES;
   if(migration||(!exists&&[_catalog[@"personas"] count])){NSMutableDictionary *next=[_state mutableCopy];next[@"personas"]=rows.copy;next[@"catalogVersion"]=catalogVersion;NSError *e=nil;if(exists&&![self backupBeforeMigration:&e])_loadError=e;else if(![self commit:next error:&e])_loadError=e;}
  }
 }return self;
}
- (NSDictionary *)snapshot{[self.lock lock];NSMutableDictionary *copy=[self.state mutableCopy];copy[@"tailBody"]=self.catalog[@"tailBody"]?:@"";copy[@"prefixTemplate"]=self.catalog[@"prefixTemplate"]?:@"## 回复前缀约定\n每条回复以以下字符串开头：\n";[self.lock unlock];return copy.copy;}
- (BOOL)enabled{return [[self snapshot][@"enabled"] boolValue];}
- (NSString *)activeID{id value=[self snapshot][@"activeID"];return [value isKindOfClass:NSString.class]?value:nil;}
- (NSArray *)personas{[self.lock lock];if(!self.cachedPersonas){NSMutableArray *items=[NSMutableArray new];for(NSDictionary *row in self.state[@"personas"]){TFAIPersona *p=[[TFAIPersona alloc]initWithJSON:row];if(p)[items addObject:p];}self.cachedPersonas=items.copy;}NSArray *result=self.cachedPersonas;[self.lock unlock];return result;}
- (NSArray *)builtins{NSMutableArray *items=[NSMutableArray new];for(TFAIPersona *p in self.personas)if(p.isBuiltin)[items addObject:p];return items.copy;}
- (BOOL)backupBeforeMigration:(NSError **)error {
 NSFileManager *fm=NSFileManager.defaultManager;NSURL *folder=[[self.url URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"MigrationBackups" isDirectory:YES];
 if(![fm createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error])return NO;
 [folder setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
 NSURL *backup=[folder URLByAppendingPathComponent:[NSString stringWithFormat:@"personas-%@.json",NSUUID.UUID.UUIDString]];
 if(![fm copyItemAtURL:self.url toURL:backup error:error])return NO;
 return [fm setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:backup.path error:error];
}
- (BOOL)commit:(NSDictionary *)next error:(NSError **)error {
 if(self.loadError){if(error)*error=self.loadError;return NO;}NSMutableDictionary *write=[next mutableCopy];write[@"schemaVersion"]=PersonaStorageVersion();NSError *e=nil;NSURL *folder=[self.url URLByDeletingLastPathComponent];BOOL ok=[NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&e];
 if(ok){[folder setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];NSData *data=[NSJSONSerialization dataWithJSONObject:write options:NSJSONWritingSortedKeys|NSJSONWritingPrettyPrinted error:&e];ok=data&&[data writeToURL:self.url options:NSDataWritingAtomic error:&e];}
 if(!ok){if(error)*error=e?:PersonaError(@"保存人设失败。");return NO;}self.state=write.copy;self.cachedPersonas=nil;dispatch_async(dispatch_get_main_queue(),^{[NSNotificationCenter.defaultCenter postNotificationName:TFAIPersonaDidChangeNotification object:self];});return YES;
}
- (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error{[self.lock lock];NSMutableDictionary *s=[self.state mutableCopy];s[@"enabled"]=@(enabled);BOOL ok=[self commit:s error:error];[self.lock unlock];return ok;}
- (BOOL)setMatchingMode:(NSString *)mode error:(NSError **)error{if(![@[@"auto",@"manual"] containsObject:mode]){if(error)*error=PersonaError(@"匹配方式无效。");return NO;}[self.lock lock];NSMutableDictionary *s=[self.state mutableCopy];s[@"matchingMode"]=mode;BOOL ok=[self commit:s error:error];[self.lock unlock];return ok;}
- (BOOL)setIncludeDeveloperPrompt:(BOOL)include error:(NSError **)error{[self.lock lock];NSMutableDictionary *s=[self.state mutableCopy];s[@"includeDeveloperPrompt"]=@(include);BOOL ok=[self commit:s error:error];[self.lock unlock];return ok;}
- (BOOL)setTailEnabled:(BOOL)enabled error:(NSError **)error{[self.lock lock];NSMutableDictionary *s=[self.state mutableCopy];s[@"tailEnabled"]=@(enabled);BOOL ok=[self commit:s error:error];[self.lock unlock];return ok;}
- (BOOL)activateOnly:(NSString *)identifier error:(NSError **)error{[self.lock lock];BOOL found=!identifier;for(NSDictionary *p in self.state[@"personas"])if([p[@"id"] isEqual:identifier])found=YES;if(!found){if(error)*error=PersonaError(@"所选人设已不存在。");[self.lock unlock];return NO;}NSMutableDictionary *s=[self.state mutableCopy];s[@"activeID"]=identifier?:NSNull.null;BOOL ok=[self commit:s error:error];[self.lock unlock];return ok;}
- (BOOL)saveName:(NSString *)name body:(NSString *)body mode:(NSString *)mode identifier:(NSString *)identifier error:(NSError **)error {
 [self.lock lock];NSDictionary *old=nil;for(NSDictionary *p in self.state[@"personas"])if([p[@"id"] isEqual:identifier]){old=p;break;}
 BOOL ok=[self saveName:name body:body mode:mode summary:old[@"summary"]?:@"" replyPrefix:old[@"replyPrefix"]?:@"" selfCheckCommand:old[@"selfCheckCommand"]?:@"" selfCheckReply:old[@"selfCheckReply"]?:@"" identifier:identifier error:error];[self.lock unlock];return ok;
}
- (BOOL)saveName:(NSString *)name body:(NSString *)body mode:(NSString *)mode summary:(NSString *)summary replyPrefix:(NSString *)prefix selfCheckCommand:(NSString *)command selfCheckReply:(NSString *)reply identifier:(NSString *)identifier error:(NSError **)error {
 name=[name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(!name.length||![body isKindOfClass:NSString.class]||!ModeValid(mode)){if(error)*error=PersonaError(@"请填写名称并选择注入方式。");return NO;}
 for(NSString *v in @[body,summary?:@"",prefix?:@"",command?:@"",reply?:@""])for(NSString *marker in @[TFAIPersonaBeginMarker,TFAIPersonaEndMarker,@"<!-- dylix-persona-tail:begin -->",@"<!-- dylix-persona-tail:end -->"])if([v containsString:marker]){if(error)*error=PersonaError(@"内容包含人设保留标记，请移除 begin / end 标记后保存。");return NO;}
 [self.lock lock];NSMutableArray *rows=[self.state[@"personas"] mutableCopy];NSUInteger index=NSNotFound;for(NSUInteger i=0;i<rows.count;i++)if([rows[i][@"id"] isEqual:identifier]){index=i;break;}
 if(identifier&&index==NSNotFound){if(error)*error=PersonaError(@"人设已被删除，请重新打开列表。");[self.lock unlock];return NO;}
 NSDictionary *old=index==NSNotFound?@{}:rows[index];NSDictionary *row=@{@"pinned":old[@"pinned"]?:@NO,@"id":identifier?:NSUUID.UUID.UUIDString,@"name":name,@"body":body,@"mode":mode,@"isBuiltin":old[@"isBuiltin"]?:@NO,@"builtinKey":old[@"builtinKey"]?:@"",@"updatedAt":@(NSDate.date.timeIntervalSince1970),@"summary":summary?:@"",@"replyPrefix":prefix?:@"",@"selfCheckCommand":command?:@"",@"selfCheckReply":reply?:@"",@"generation":old[@"generation"]?:@"",@"modelPatterns":old[@"modelPatterns"]?:@[],@"providerIDs":old[@"providerIDs"]?:@[],@"matchPriority":old[@"matchPriority"]?:@0};
 if(index==NSNotFound)[rows addObject:row];else rows[index]=row;NSMutableDictionary *s=[self.state mutableCopy];s[@"personas"]=rows.copy;BOOL ok=[self commit:s error:error];[self.lock unlock];return ok;
}
- (BOOL)updateLocalFields:(NSDictionary *)fields identifier:(NSString *)identifier error:(NSError **)error {
 [self.lock lock];NSMutableArray *rows=[self.state[@"personas"] mutableCopy];NSUInteger i=[rows indexOfObjectPassingTest:^BOOL(NSDictionary *row,NSUInteger i,BOOL *stop){return [row[@"id"] isEqual:identifier];}];if(i==NSNotFound){if(error)*error=PersonaError(@"人设已被删除，请重新打开列表。");[self.lock unlock];return NO;}NSMutableDictionary *row=[rows[i] mutableCopy];[row addEntriesFromDictionary:fields];rows[i]=row;NSMutableDictionary *next=[self.state mutableCopy];next[@"personas"]=rows;BOOL ok=[self commit:next error:error];[self.lock unlock];return ok;
}
- (BOOL)setPinned:(BOOL)pinned identifier:(NSString *)identifier error:(NSError **)error{return [self updateLocalFields:@{@"pinned":@(pinned)} identifier:identifier error:error];}
- (BOOL)remove:(NSString *)identifier error:(NSError **)error{[self.lock lock];NSMutableArray *rows=[NSMutableArray new],*hidden=[self.state[@"hiddenBuiltins"] mutableCopy];for(NSDictionary *row in self.state[@"personas"]){if(![row[@"id"] isEqual:identifier])[rows addObject:row];else if([row[@"isBuiltin"] boolValue]&&![hidden containsObject:identifier])[hidden addObject:identifier];}NSMutableDictionary *s=[self.state mutableCopy];s[@"personas"]=rows.copy;s[@"hiddenBuiltins"]=hidden.copy;if([s[@"activeID"] isEqual:identifier])s[@"activeID"]=NSNull.null;BOOL ok=[self commit:s error:error];[self.lock unlock];return ok;}
- (BOOL)resetBuiltin:(NSString *)identifier error:(NSError **)error {
 [self.lock lock];NSDictionary *original=nil;for(NSDictionary *p in self.catalog[@"personas"])if([p[@"id"] isEqual:identifier])original=p;
 if(!original){if(error)*error=PersonaError(@"没有对应的内置原文。");[self.lock unlock];return NO;}
 NSMutableArray *rows=[self.state[@"personas"] mutableCopy],*hidden=[self.state[@"hiddenBuiltins"] mutableCopy];BOOL found=NO;for(NSUInteger i=0;i<rows.count;i++)if([rows[i][@"id"] isEqual:identifier]){NSMutableDictionary *reset=[original mutableCopy];for(NSString *key in @[@"pinned"])if(rows[i][key])reset[key]=rows[i][key];rows[i]=reset;found=YES;break;}if(!found)[rows addObject:original];[hidden removeObject:identifier];NSMutableDictionary *s=[self.state mutableCopy];s[@"personas"]=rows.copy;s[@"hiddenBuiltins"]=hidden.copy;BOOL ok=[self commit:s error:error];[self.lock unlock];return ok;
}
- (BOOL)restoreBuiltins:(NSError **)error {
 [self.lock lock];NSMutableArray *rows=[self.state[@"personas"] mutableCopy];NSMutableSet *ids=[NSMutableSet new];for(NSDictionary *p in rows)[ids addObject:p[@"id"]];for(NSDictionary *p in self.catalog[@"personas"])if(![ids containsObject:p[@"id"]])[rows addObject:p];NSMutableDictionary *s=[self.state mutableCopy];s[@"personas"]=rows.copy;s[@"hiddenBuiltins"]=@[];BOOL ok=[self commit:s error:error];[self.lock unlock];return ok;
}
- (NSString *)statusBadge{NSDictionary *s=[self snapshot];if(![s[@"enabled"] boolValue])return @"已关闭";if([s[@"matchingMode"] isEqual:@"auto"])return @"自动匹配模型";NSDictionary *p=[TFAIPersonaEngine active:s];return p?[NSString stringWithFormat:@"（已启用·%@）",p[@"name"]]:@"未选择生效项";}
@end
@implementation TFAIPersonaEngine
+ (NSString *)strip:(NSString *)text begin:(NSString *)beginMarker end:(NSString *)endMarker{
 NSMutableString *s=[text mutableCopy];while(YES){NSRange begin=[s rangeOfString:beginMarker];if(begin.location==NSNotFound)break;NSUInteger pos=NSMaxRange(begin),depth=1,end=s.length;
 while(pos<s.length){NSRange search=NSMakeRange(pos,s.length-pos),b=[s rangeOfString:beginMarker options:0 range:search],e=[s rangeOfString:endMarker options:0 range:search];if(e.location==NSNotFound)break;if(b.location!=NSNotFound&&b.location<e.location){depth++;pos=NSMaxRange(b);}else{pos=NSMaxRange(e);if(--depth==0){end=pos;break;}}}
 NSRange cut=NSMakeRange(begin.location,end-begin.location);if(end+2<=s.length&&[[s substringWithRange:NSMakeRange(end,2)] isEqual:@"\n\n"])cut.length+=2;else if(begin.location>=2&&[[s substringWithRange:NSMakeRange(begin.location-2,2)] isEqual:@"\n\n"]){cut.location-=2;cut.length+=2;}[s deleteCharactersInRange:cut];}
 [s replaceOccurrencesOfString:endMarker withString:@"" options:0 range:NSMakeRange(0,s.length)];return s.copy;
}
+ (NSString *)strip:(NSString *)text{return [self strip:[self strip:text begin:TFAIPersonaBeginMarker end:TFAIPersonaEndMarker] begin:@"<!-- dylix-persona-tail:begin -->" end:@"<!-- dylix-persona-tail:end -->"];}
+ (NSString *)wrap:(NSString *)body{return [NSString stringWithFormat:@"%@\n%@\n%@",TFAIPersonaBeginMarker,body,TFAIPersonaEndMarker];}
+ (NSDictionary *)active:(NSDictionary *)s{if(![s[@"enabled"] boolValue]||![s[@"activeID"] isKindOfClass:NSString.class])return nil;for(NSDictionary *p in s[@"personas"])if([p[@"id"] isEqual:s[@"activeID"]]&&ModeValid(p[@"mode"])&&[p[@"body"] isKindOfClass:NSString.class]&&[[p[@"body"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length]&&![p[@"body"] containsString:TFAIPersonaBeginMarker]&&![p[@"body"] containsString:TFAIPersonaEndMarker])return p;return nil;}
+ (NSDictionary *)recommended:(NSDictionary *)s connection:(NSDictionary *)connection{NSString *model=[connection[@"model"] isKindOfClass:NSString.class]?[connection[@"model"] lowercaseString]:@"",*provider=[connection[@"protocol"] isKindOfClass:NSString.class]?[connection[@"protocol"] lowercaseString]:@"";if(!model.length)return nil;NSDictionary *best=nil;NSInteger score=NSIntegerMin;for(NSDictionary *p in s[@"personas"]){NSArray *providers=[p[@"providerIDs"] isKindOfClass:NSArray.class]?p[@"providerIDs"]:@[];if(providers.count&&![providers containsObject:provider])continue;NSArray *patterns=[p[@"modelPatterns"] isKindOfClass:NSArray.class]?p[@"modelPatterns"]:@[];BOOL match=NO;for(NSString *pattern in patterns)if([model rangeOfString:pattern options:NSRegularExpressionSearch].location!=NSNotFound){match=YES;break;}if(!match)continue;NSInteger candidate=[p[@"matchPriority"] integerValue];if(candidate>score){best=p;score=candidate;}}return best;}
+ (NSDictionary *)effective:(NSDictionary *)s connection:(NSDictionary *)connection{if(![s[@"enabled"] boolValue])return nil;if([s[@"matchingMode"] isEqual:@"auto"]&&[connection[@"model"] length])return [self recommended:s connection:connection];return [self active:s];}
+ (NSString *)build:(NSString *)developerPrompt snapshot:(NSDictionary *)snapshot{return [self build:developerPrompt snapshot:snapshot connection:nil];}
+ (NSString *)build:(NSString *)developerPrompt snapshot:(NSDictionary *)snapshot connection:(NSDictionary *)connection {
 NSString *base=[self strip:developerPrompt];NSDictionary *p=[self effective:snapshot connection:connection];
 if(snapshot[@"includeDeveloperPrompt"]&&![snapshot[@"includeDeveloperPrompt"] boolValue])return p?p[@"body"]:@"";
 if(!p)return base;
 NSMutableString *body=[p[@"body"] mutableCopy];if([p[@"replyPrefix"] length])[body appendFormat:@"\n\n%@%@",snapshot[@"prefixTemplate"]?:@"## 回复前缀约定\n每条回复以以下字符串开头：\n",p[@"replyPrefix"]];
 NSString *block=[self wrap:body],*system;if([p[@"mode"] isEqual:@"replace"]||!base.length)system=block;else system=[p[@"mode"] isEqual:@"prepend"]?[NSString stringWithFormat:@"%@\n\n%@",block,base]:[NSString stringWithFormat:@"%@\n\n%@",base,block];
 if([snapshot[@"tailEnabled"] boolValue]&&[snapshot[@"tailBody"] length])system=[system stringByAppendingFormat:@"\n\n<!-- dylix-persona-tail:begin -->\n%@\n<!-- dylix-persona-tail:end -->",snapshot[@"tailBody"]];return system;
}
+ (NSString *)selfCheckResponse:(NSArray<NSDictionary *> *)messages snapshot:(NSDictionary *)snapshot{return [self selfCheckResponse:messages snapshot:snapshot connection:nil];}
+ (NSString *)selfCheckResponse:(NSArray<NSDictionary *> *)messages snapshot:(NSDictionary *)snapshot connection:(NSDictionary *)connection {
 NSDictionary *p=[self effective:snapshot connection:connection],*last=messages.lastObject;id text=last[@"content"];
 if(!p||![last[@"role"] isEqual:@"user"]||![text isKindOfClass:NSString.class]||[last[@"localAttachmentReferences"] count]||[last[@"attachments"] count]||[last[@"images"] count]||![p[@"selfCheckCommand"] length]||![p[@"selfCheckReply"] length])return nil;
 return [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] isEqual:p[@"selfCheckCommand"]]?p[@"selfCheckReply"]:nil;
}
+ (NSDictionary *)preview:(NSString *)base snapshot:(NSDictionary *)snapshot{return [self preview:base snapshot:snapshot connection:nil];}
+ (NSDictionary *)preview:(NSString *)base snapshot:(NSDictionary *)snapshot connection:(NSDictionary *)connection{NSString *system=[self build:base snapshot:snapshot connection:connection];NSDictionary *p=[self effective:snapshot connection:connection];return @{@"system":system,@"activeCount":@(p?1:0),@"byteCount":@([system lengthOfBytesUsingEncoding:NSUTF8StringEncoding]),@"personaByteCount":@([p[@"body"] lengthOfBytesUsingEncoding:NSUTF8StringEncoding]),@"name":p[@"name"]?:@"",@"mode":p[@"mode"]?:@"",@"enabled":snapshot[@"enabled"]?:@NO,@"matchingMode":snapshot[@"matchingMode"]?:@"manual",@"model":connection[@"model"]?:@""};}
@end
static NSString *LastBase,*LastSystem;static NSDictionary *LastConnection;
void TFAIPersonaRecordRequest(NSString *base,NSString *system){@synchronized(TFAIPersonaEngine.class){LastBase=base.copy;LastSystem=system.copy;LastConnection=nil;}}
void TFAIPersonaRecordRequestConnection(NSString *base,NSString *system,NSDictionary *connection){@synchronized(TFAIPersonaEngine.class){LastBase=base.copy;LastSystem=system.copy;LastConnection=connection.copy;}}
NSDictionary *TFAIPersonaRequestPreviewContext(void){@synchronized(TFAIPersonaEngine.class){if(!LastBase)return @{};NSMutableDictionary *result=[@{@"developerPrompt":LastBase,@"sentSystem":LastSystem} mutableCopy];if(LastConnection)result[@"connection"]=LastConnection;return result.copy;}}

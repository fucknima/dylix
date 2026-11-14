#pragma once
#import <Foundation/Foundation.h>

// Opt-in: existing conversations keep full tools until the user enables discovery.
static inline BOOL TFAILazyToolsEnabled(void) { return [NSUserDefaults.standardUserDefaults boolForKey:@"Dylix.AI.LazyTools"]; }
static inline NSString *TFAIAnswerStyle(void) {
 NSString *v=[NSUserDefaults.standardUserDefaults stringForKey:@"Dylix.AI.AnswerStyle"];
 return [@[@"concise",@"standard",@"detailed"] containsObject:v]?v:@"standard";
}
static inline NSString *TFAIAnswerGuidance(void) {
 NSString *style=TFAIAnswerStyle();
 NSString *length=[style isEqual:@"concise"]?@"简洁回答，先给结论。简单问题通常用一到三句话；复杂任务只列关键改动、必要验证和未解决项。不要为凑短删代码、漏条件或省略失败。":([style isEqual:@"detailed"]?@"详细回答，按问题解释关键机制、实现依据、验证和限制；需要时给例子。展开有用的推理依据，不用同义改写、复述过程或重复总结来增加篇幅。":@"回答长度与任务复杂度匹配，先给结果，再补必要依据。事实、已验证结果、推测和未验证项分清；同一结论只讲一次。");
 return [length stringByAppendingString:@"复杂任务可用update_plan，只在进展变化时更新；计划不是执行证据。工作时以当前用户目标为准：复用上下文中的源码和已验证结果，先完成一个可验证的小改动，再按新结果决定下一步。每次补查应解决一个明确缺口；仅当用户已要求且授权修改、已有足够原文时才生成并按权限应用提案，不反复宣布准备修改。修改后只验证受影响的范围，不重做全项目发现流程。执行中只播报有新信息的进展，不逐条复述工具参数或重复宣布即将操作；结果已经明确就交付。完整保留用户需要的代码、验证证据与重要限制，不为简短省略必要工作。用户明确指定的回答格式和详细程度优先于风格设置。仅问解释或方案时，不把建议说成已经改好。工具返回成功不等于整个任务验证通过，失败和限制要如实交代；没有真实数据时不给循环概率、耗时或费用百分比。"];
}
static inline NSDictionary *TFAIToolSearchSchema(NSArray *available) {
 NSMutableArray *names=[NSMutableArray new];for(NSDictionary *s in available)[names addObject:s[@"name"]];
 return @{@"name":@"search_tools",@"description":[@"Discover and load tools for the NEXT request. Use names for exact loading (up to 12), query for keyword lookup in names/descriptions, or empty arguments to list the catalog. Loading never grants permissions. Keep working in this conversation. Available names: " stringByAppendingString:[names componentsJoinedByString:@", "]],@"parameters":@{@"type":@"object",@"properties":@{@"query":@{@"type":@"string",@"maxLength":@256},@"names":@{@"type":@"array",@"items":@{@"type":@"string"},@"maxItems":@12}},@"additionalProperties":@NO}};
}
static inline NSArray *TFAISelectRequestTools(NSArray *available, NSSet *loaded) {
 NSSet *base=[NSSet setWithArray:@[@"update_plan",@"read_context",@"read_development_guide",@"read_app_state",@"read_file",@"list_files",@"read_attachment",@"agent_skill_read",@"list_projects",@"select_project"]];
 NSMutableArray *out=[NSMutableArray arrayWithObject:TFAIToolSearchSchema(available)];
 for(NSDictionary *s in available)if([base containsObject:s[@"name"]]||([loaded containsObject:s[@"name"]]||([s[@"name"] isEqual:@"binary_inspect"]&&[loaded containsObject:@"binary_obfuscation_scan"])))[out addObject:s];return out;
}
static inline NSDictionary *TFAILoadTools(NSDictionary *args,NSArray *available,NSMutableSet *loaded,NSError **error) {
 if(![args isKindOfClass:NSDictionary.class]){if(error)*error=[NSError errorWithDomain:@"Dylix.ToolDiscovery" code:1 userInfo:@{NSLocalizedDescriptionKey:@"工具查询参数必须为对象。"}];return nil;}
 id query=args[@"query"],names=args[@"names"];
 BOOL valid=[args isKindOfClass:NSDictionary.class]&&args.count<=2&&(!query||([query isKindOfClass:NSString.class]&&[query length]<=256))&&(!names||([names isKindOfClass:NSArray.class]&&[names count]<=12));
 for(id key in args)if(![@[@"query",@"names"] containsObject:key])valid=NO;
 for(id n in ([names isKindOfClass:NSArray.class]?names:@[]))if(![n isKindOfClass:NSString.class])valid=NO;
 if(!valid){if(error)*error=[NSError errorWithDomain:@"Dylix.ToolDiscovery" code:1 userInfo:@{NSLocalizedDescriptionKey:@"使用 query 或最多 12 个 names 查询工具。"}];return nil;}
 NSMutableArray *catalog=[NSMutableArray new],*selected=[NSMutableArray new],*missing=[NSMutableArray new];NSMutableSet *found=[NSMutableSet new];
 BOOL listing=![query length]&&![names count];
 for(NSDictionary *s in available){NSString *name=s[@"name"],*desc=s[@"description"]?:@"";BOOL exact=[names containsObject:name];BOOL match=[query length]&&([[name stringByAppendingFormat:@" %@",desc] rangeOfString:query options:NSCaseInsensitiveSearch].location!=NSNotFound);
 if(listing||exact||match){[catalog addObject:@{@"name":name,@"description":desc.length>180?[desc substringToIndex:180]:desc}];if((exact||match)&&selected.count<12){[selected addObject:name];[loaded addObject:name];}[found addObject:name];}}
 for(NSString *n in names)if(![found containsObject:n])[missing addObject:n];
 return @{@"catalog":catalog,@"loaded":selected,@"unavailable":missing,@"effective":@"next_request",@"permissionsUnchanged":@YES};
}

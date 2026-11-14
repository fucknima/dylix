#pragma once
#import <Foundation/Foundation.h>
// Transcript-only progress; this tool neither executes work nor verifies success.
static inline NSDictionary *TFAITaskPlanSchema(void) {
 return @{@"name":@"update_plan",@"description":@"Record a plan for complex multi-step work in this conversation. Replace all steps when real progress changes; an empty array clears the plan. Reuse visible evidence and work on the current step instead of repeating discovery. Status is model-reported, not proof of execution. Do not use for trivial tasks or repeat unchanged updates. Latest user instructions override any old plan.",@"parameters":@{@"type":@"object",@"properties":@{@"steps":@{@"type":@"array",@"maxItems":@20,@"items":@{@"type":@"object",@"properties":@{@"content":@{@"type":@"string",@"minLength":@1,@"maxLength":@240},@"status":@{@"type":@"string",@"enum":@[@"pending",@"in_progress",@"completed",@"blocked"]}},@"required":@[@"content",@"status"],@"additionalProperties":@NO}},@"explanation":@{@"type":@"string",@"maxLength":@600}},@"required":@[@"steps"],@"additionalProperties":@NO}};
}
static inline NSDictionary *TFAITaskPlanResult(NSDictionary *args,NSError **error) {
 BOOL valid=[args isKindOfClass:NSDictionary.class];id steps=valid?args[@"steps"]:nil;valid=valid&&[steps isKindOfClass:NSArray.class]&&[steps count]<=20;
 if(valid){for(id key in args)if(![@[@"steps",@"explanation"] containsObject:key])valid=NO;id why=args[@"explanation"];if(why&&(![why isKindOfClass:NSString.class]||[why length]>600))valid=NO;
 for(id step in steps){if(![step isKindOfClass:NSDictionary.class]||[step count]!=2){valid=NO;break;}id text=step[@"content"],status=step[@"status"];if(![text isKindOfClass:NSString.class]||![text length]||[text length]>240||![@[@"pending",@"in_progress",@"completed",@"blocked"] containsObject:status?:NSNull.null])valid=NO;}}
 if(!valid){if(error)*error=[NSError errorWithDomain:@"Dylix.TaskPlan" code:1 userInfo:@{NSLocalizedDescriptionKey:@"任务计划需要最多 20 个步骤，每项含 content（1–240 字符）与有效 status。"}];return nil;}
 NSMutableDictionary *result=[@{@"steps":steps,@"model_reported":@YES,@"execution_verified":@NO} mutableCopy];if(args[@"explanation"])result[@"explanation"]=args[@"explanation"];return result;
}

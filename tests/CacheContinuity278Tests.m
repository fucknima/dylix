#import <Foundation/Foundation.h>
#import "../App/AI/Core/TFAIContextProjection.h"
static NSUInteger checks=0;
static void Check(BOOL ok,NSString *s){checks++;if(!ok){fprintf(stderr,"FAIL: %s\n",s.UTF8String);exit(1);}}
static NSString *Text(NSUInteger size){return [@"evidence 中文 source line\n" stringByPaddingToLength:size withString:@"evidence 中文 source line\n" startingAtIndex:0];}
static NSArray *Clean(NSArray *messages){NSMutableArray *a=[NSMutableArray new];for(NSDictionary *m in messages){NSMutableDictionary *v=[m mutableCopy];[v removeObjectForKey:@"_cacheBoundary"];[a addObject:v];}return a;}
static void PairCheck(NSArray *a){for(NSUInteger i=0;i<a.count;i++){NSArray *calls=a[i][@"tool_calls"];if(!calls.count)continue;NSMutableSet *ids=[NSMutableSet new];for(NSDictionary *c in calls)[ids addObject:c[@"id"]];NSUInteger j=i+1;while(j<a.count&&[a[j][@"role"] isEqual:@"tool"]){Check([ids containsObject:a[j][@"tool_call_id"]],@"result belongs to adjacent call");[ids removeObject:a[j][@"tool_call_id"]];j++;}Check(!ids.count,@"complete parallel batch preserved");}}
int main(){@autoreleasepool{
 [TFAIContextProjection setBudgetKiB:256];
 NSArray *schemas=@[TFAIContextProjection.schema,@{@"name":@"read_file",@"parameters":@{@"type":@"object"}}];
 NSDictionary *c=@{@"id":@"fixture",@"protocol":@"chat",@"model":@"fixture-model"};
 NSMutableArray *raw=[NSMutableArray arrayWithArray:@[@{@"role":@"system",@"content":@"Stable policy"},@{@"role":@"user",@"content":@"Keep API compatibility; preserve the original file; finish the outstanding fix."}]];
 TFAIContextSessionProjection *session=[TFAIContextSessionProjection new];
 NSArray *previous=nil;NSUInteger unchanged=0, transitions=0, checkpoints=0, legacyStable=0;NSArray *legacyPrevious=nil;
 for(NSUInteger round=0;round<160;round++){
  NSString *cid=[NSString stringWithFormat:@"call-%lu",(unsigned long)round];
  [raw addObject:@{@"role":@"assistant",@"content":@"Inspect relevant source",@"tool_calls":@[@{@"id":cid,@"name":@"read_file",@"arguments":@{@"path":@"Tweak.xm",@"start_line":@(round*30+1)}}]}];
  [raw addObject:@{@"role":@"tool",@"tool_call_id":cid,@"content":Text(2200)}];
  if(round%20==19)[raw addObject:@{@"role":@"user",@"content":[NSString stringWithFormat:@"Constraint %lu: retain existing behavior and report verification.",(unsigned long)round]}];
  NSArray *tail=@[@{@"role":@"assistant",@"content":[NSString stringWithFormat:@"Environment observation round=%lu",(unsigned long)round]}];
  NSDictionary *stats=nil;NSError *error=nil;NSArray *out=[session project:raw transient:tail connection:c schemas:schemas statistics:&stats error:&error];
  Check(out!=nil,error.localizedDescription?:@"long trace projects");Check([stats[@"afterTextJSONBytes"] unsignedIntegerValue]<=256*1024,@"hard budget respected");
  NSArray *canonical=Clean([out subarrayWithRange:NSMakeRange(0,out.count-tail.count)]);
  if(previous){transitions++;if(canonical.count>=previous.count&&[[canonical subarrayWithRange:NSMakeRange(0,previous.count)] isEqual:previous])unchanged++;else Check([stats[@"projectionCheckpoint"] boolValue],@"history changes only at checkpoint");}
  if([stats[@"projectionCheckpoint"] boolValue])checkpoints++;
  Check([canonical containsObject:raw[1]],@"original user constraints remain exact");
  Check([canonical containsObject:raw.lastObject],@"latest observation remains exact");PairCheck(canonical);
  previous=canonical;
  NSArray *legacy=[TFAIContextProjection project:raw connection:c schemas:schemas statistics:nil error:nil];
  if(legacyPrevious&&legacy.count>=legacyPrevious.count&&[[legacy subarrayWithRange:NSMakeRange(0,legacyPrevious.count)] isEqual:legacyPrevious])legacyStable++;
  legacyPrevious=legacy;
 }
 Check(checkpoints>0&&checkpoints<12,@"bounded compaction checkpoints");Check(unchanged>transitions*9/10,@"at least 90 percent exact historical prefix continuity");
 NSDictionary *stats=nil;NSError *error=nil;
 raw[1]=@{@"role":@"user",@"content":@"Edited requirement replaces previous instruction"};
 NSArray *edited=[session project:raw transient:@[] connection:c schemas:schemas statistics:&stats error:&error];
 Check(![stats[@"projectionPrefixReused"] boolValue]&&[Clean(edited) containsObject:raw[1]],@"editing history invalidates frozen projection");
 NSMutableDictionary *other=[c mutableCopy];other[@"model"]=@"other-model";
 Check([session project:raw transient:@[] connection:other schemas:schemas statistics:&stats error:&error]!=nil&&! [stats[@"projectionPrefixReused"] boolValue],@"model switch invalidates projection");
 NSMutableArray *huge=[raw mutableCopy];[huge addObject:@{@"role":@"user",@"content":Text(400*1024)}];
 Check(![session project:huge transient:@[] connection:c schemas:schemas statistics:&stats error:&error],@"irreducible input fails before network");
 Check([raw[2][@"tool_calls"][0][@"arguments"][@"path"] isEqual:@"Tweak.xm"],@"original arguments untouched");
 Check([raw[3][@"content"] isEqual:Text(2200)],@"original evidence untouched");
 TFAIContextSessionProjection *small=[TFAIContextSessionProjection new];NSArray *simple=@[@{@"role":@"user",@"content":@"hi"}];
 NSArray *a=[small project:simple transient:@[] connection:c schemas:@[] statistics:nil error:nil];
 Check([a.lastObject[@"_cacheBoundary"] boolValue],@"history boundary is explicit");
 Check(![small project:simple transient:@[@{@"role":@"assistant",@"content":Text(400*1024)}] connection:c schemas:@[] statistics:nil error:nil],@"transient data included in hard guard");
 printf("PASS %lu checks; rounds=160 transitions=%lu stable=%lu checkpoints=%lu baseline_stable=%lu\n",(unsigned long)checks,(unsigned long)transitions,(unsigned long)unchanged,(unsigned long)checkpoints,(unsigned long)legacyStable);
 [NSUserDefaults.standardUserDefaults removeObjectForKey:@"TFAIContextBudgetKiB"];
}return 0;}

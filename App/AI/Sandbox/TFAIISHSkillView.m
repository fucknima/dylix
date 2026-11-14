#import "TFAIISHSkillView.h"
#import "../Agent/TFAIAgentContext.h"
#import "../Registry/TFAIToolRegistry.h"
#import <sys/stat.h>
@implementation TFAIISHSkillView
+ (NSString *)refresh:(NSString *)root sessionKey:(NSString *)key error:(NSError **)error{
 if(key.length!=64||[key rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location!=NSNotFound)return nil;
 NSFileManager *fm=NSFileManager.defaultManager;NSString *base=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject.stringByResolvingSymlinksInPath stringByAppendingPathComponent:@"Dylix/SkillViews"],*path=[base stringByAppendingPathComponent:key];
 if(![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error]||![path isEqual:path.stringByResolvingSymlinksInPath])return nil;
 NSMutableSet *keep=[NSMutableSet new];NSArray *skills=[TFAIToolRegistry enabled:@"skills"]?[TFAIAgentContext skills:root]:@[];
 for(NSDictionary *skill in skills){NSString *name=skill[@"id"];if(!name.length||[name containsString:@"/"]||[name hasPrefix:@"."])continue;NSDictionary *text=[TFAIAgentContext readSkill:name root:root error:nil];if(!text)continue;
  NSString *directory=[path stringByAppendingPathComponent:name],*file=[directory stringByAppendingPathComponent:@"SKILL.md"];struct stat st;
  if((!lstat(directory.fileSystemRepresentation,&st)&&!S_ISDIR(st.st_mode))||(!lstat(file.fileSystemRepresentation,&st)&&!S_ISREG(st.st_mode)))return nil;
  if(![fm fileExistsAtPath:directory]&&![fm createDirectoryAtPath:directory withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0755} error:error])return nil;
  NSString *body=[NSString stringWithFormat:@"# %@\n\n%@\n\n%@",skill[@"name"],skill[@"description"],text[@"body"]];
  NSString *old=[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];if(![old isEqual:body]&&![body writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:error])return nil;
  [fm setAttributes:@{NSFilePosixPermissions:@0444} ofItemAtPath:file error:nil];[keep addObject:name];
 }
 for(NSString *name in [fm contentsOfDirectoryAtPath:path error:error])if(![keep containsObject:name]&&![fm removeItemAtPath:[path stringByAppendingPathComponent:name] error:error])return nil;
 return path;
}
@end

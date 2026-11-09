#import "TFAIISHExports.h"
NSURL *TFAIISHExportURL(NSDictionary *result,NSString *session){
 NSString *identifier=result[@"export_id"],*name=result[@"name"];
 if([name isEqual:@".dylix-export.plist"]||!session.length||![identifier isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:identifier]||![name isKindOfClass:NSString.class]||!name.length||![name isEqual:name.lastPathComponent]||[name isEqual:@"."]||[name isEqual:@".."]||[name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return nil;
 NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject.stringByResolvingSymlinksInPath;
 NSString *root=[[docs stringByAppendingPathComponent:@"DylixLinuxExports"] stringByAppendingPathComponent:identifier];
 if(![root.stringByResolvingSymlinksInPath isEqual:root.stringByStandardizingPath])return nil;
 NSDictionary *metadata=[NSDictionary dictionaryWithContentsOfFile:[root stringByAppendingPathComponent:@".dylix-export.plist"]];
 if(![metadata[@"session"] isEqual:session]||![metadata[@"name"] isEqual:name])return nil;
 NSString *path=[root stringByAppendingPathComponent:name];NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
 return [attributes[NSFileType] isEqual:NSFileTypeRegular]&&[attributes[NSFileSize] isEqual:metadata[@"bytes"]]?[NSURL fileURLWithPath:path]:nil;
}

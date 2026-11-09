#import <Foundation/Foundation.h>
#import "../App/AI/Binary/TFAIBinary.h"
int main(int argc,char **argv){@autoreleasepool{
 NSData *data=[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%s/fixture.dylib",argv[1]]];NSError *error=nil;
 NSDictionary *r=TFAIBinaryParse(data,@{ @"action":@"obfuscation_scan" },&error);
 if(!r||error||![r[@"metrics"] isKindOfClass:NSDictionary.class]||![r[@"findings"] isKindOfClass:NSArray.class]){NSLog(@"obfuscation scan failed: %@",error);return 1;}
 if([r[@"confidence"] isEqual:@"confirmed"]){NSLog(@"plain fixture incorrectly confirmed encrypted");return 2;}
 NSLog(@"PASS obfuscation scan: %@",r[@"metrics"]);return 0;
}}

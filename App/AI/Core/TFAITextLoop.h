#pragma once
#import <Foundation/Foundation.h>
// Conservative natural-language suffix detector. Never scans code/table/list
// output as prose. Returns NSNotFound for productive or intentionally formatted text.
static inline BOOL TFAIExplicitRepetitionRequest(NSString *text){
 static NSRegularExpression *pattern;static dispatch_once_t once;dispatch_once(&once,^{pattern=[NSRegularExpression regularExpressionWithPattern:@"(重复.{0,10}[0-9一二三四五六七八九十百]+次|重复输出|重复写|原样重复|repeat.{0,24}(times|exactly)|verbatim)" options:NSRegularExpressionCaseInsensitive error:nil];});return [pattern firstMatchInString:text?:@"" options:0 range:NSMakeRange(0,[text length])]!=nil;
}
static inline NSUInteger TFAIRepeatingProse(NSString *text){
 if(text.length<192||[text containsString:@"```"]||[text containsString:@"~~~"])return NSNotFound;
 NSString *tail=[text substringFromIndex:text.length>8192?text.length-8192:0];
 for(NSString *line in [tail componentsSeparatedByString:@"\n"]){NSString *s=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if([s hasPrefix:@"|"]||[s hasPrefix:@">"]||[s hasPrefix:@"- "]||[s hasPrefix:@"* "]||[s hasPrefix:@"#"]||[s containsString:@";"]||[s containsString:@"{"])return NSNotFound;}
 for(NSUInteger period=24;period<=MIN(512,tail.length/6);period++){
  NSString *unit=[tail substringFromIndex:tail.length-period];if([unit rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"。！？.!?\n"]].location==NSNotFound)continue;
  NSUInteger repeats=1;while((repeats+1)*period<=tail.length&&[[tail substringWithRange:NSMakeRange(tail.length-(repeats+1)*period,period)] isEqual:unit])repeats++;
  if(repeats>=6)return text.length-repeats*period+period;
 }
 return NSNotFound;
}

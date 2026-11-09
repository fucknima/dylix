#import "FLEXDylixMarkdown.h"

static NSString *DXTrim(NSString *value) { return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; }

static NSArray<NSString *> *DXCells(NSString *line) {
 NSMutableArray *cells=[NSMutableArray new];
 for(NSString *part in [line componentsSeparatedByString:@"|"])if(DXTrim(part).length)[cells addObject:DXTrim(part)];
 return cells;
}

static BOOL DXDivider(NSString *line) {
 NSString *check=[[line stringByReplacingOccurrencesOfString:@"|" withString:@""] stringByReplacingOccurrencesOfString:@":" withString:@""];
 check=[check stringByReplacingOccurrencesOfString:@"-" withString:@""];
 return DXTrim(check).length==0 && [line containsString:@"-"];
}

static void DXAppendInline(NSMutableAttributedString *output, NSString *line, NSDictionary *base, UIFont *font, UIColor *color) {
 NSUInteger i=0;
 while(i<line.length){
  NSString *tail=[line substringFromIndex:i];NSString *marker=nil;NSRange end=NSMakeRange(NSNotFound,0);NSDictionary *attributes=base;NSUInteger start=0,advance=0;
  if([tail hasPrefix:@"**"]||[tail hasPrefix:@"__"]){marker=[tail substringToIndex:2];start=2;end=[tail rangeOfString:marker options:0 range:NSMakeRange(2,tail.length-2)];if(end.location!=NSNotFound){attributes=@{NSFontAttributeName:[UIFont systemFontOfSize:font.pointSize weight:UIFontWeightBold],NSForegroundColorAttributeName:color};advance=2;}}
  else if([tail hasPrefix:@"`"]){marker=@"`";start=1;end=[tail rangeOfString:marker options:0 range:NSMakeRange(1,tail.length-1)];if(end.location!=NSNotFound){attributes=@{NSFontAttributeName:[UIFont monospacedSystemFontOfSize:font.pointSize-1 weight:UIFontWeightRegular],NSForegroundColorAttributeName:color,NSBackgroundColorAttributeName:UIColor.tertiarySystemFillColor};advance=1;}}
  else if([tail hasPrefix:@"["]){NSRange split=[tail rangeOfString:@"]("];if(split.location!=NSNotFound){NSRange close=[tail rangeOfString:@")" options:0 range:NSMakeRange(NSMaxRange(split),tail.length-NSMaxRange(split))];if(close.location!=NSNotFound){NSString *url=[tail substringWithRange:NSMakeRange(NSMaxRange(split),close.location-NSMaxRange(split))];if([url hasPrefix:@"https://"]||[url hasPrefix:@"http://"]){NSString *label=[tail substringWithRange:NSMakeRange(1,split.location-1)];[output appendAttributedString:[[NSAttributedString alloc]initWithString:label attributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:UIColor.systemBlueColor,NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle),NSLinkAttributeName:url}]];i+=close.location+1;continue;}}}}
  else if([tail hasPrefix:@"*"]){marker=@"*";start=1;end=[tail rangeOfString:marker options:0 range:NSMakeRange(1,tail.length-1)];if(end.location!=NSNotFound){attributes=@{NSFontAttributeName:[UIFont italicSystemFontOfSize:font.pointSize],NSForegroundColorAttributeName:color};advance=1;}}
  if(end.location!=NSNotFound && end.location>start){NSString *value=[tail substringWithRange:NSMakeRange(start,end.location-start)];[output appendAttributedString:[[NSAttributedString alloc]initWithString:value attributes:attributes]];i+=end.location+advance;continue;}
  [output appendAttributedString:[[NSAttributedString alloc]initWithString:[line substringWithRange:NSMakeRange(i,1)] attributes:base]];i++;
 }
}

NSAttributedString *FLEXDylixRenderMarkdown(NSString *source, UIColor *color) {
 if(!source.length)return [[NSAttributedString alloc]initWithString:@"正在回复…" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15],NSForegroundColorAttributeName:color?:UIColor.labelColor}];
 NSMutableAttributedString *output=[NSMutableAttributedString new];NSArray *lines=[source componentsSeparatedByString:@"\n"];NSArray *headers=nil;BOOL code=NO;UIColor *ink=color?:UIColor.labelColor;
 for(NSUInteger n=0;n<lines.count;n++){
  NSString *line=lines[n];NSString *trim=DXTrim(line);BOOL heading=NO,quote=NO,bullet=NO,table=NO;
  if([trim hasPrefix:@"```"]){code=!code;continue;}
  if(!code&&[trim hasPrefix:@"|"]){if(DXDivider(trim))continue;NSArray *cells=DXCells(trim);if(n+1<lines.count&&DXDivider(DXTrim(lines[n+1]))){headers=cells;continue;}if(cells.count){NSMutableArray *parts=[NSMutableArray new];for(NSUInteger c=0;c<cells.count;c++){NSString *name=c<headers.count?headers[c]:@"";[parts addObject:name.length?[NSString stringWithFormat:@"%@: %@",name,cells[c]]:cells[c]];}line=[parts componentsJoinedByString:@"   ·   "];table=YES;}}
  else if(!code){headers=nil;
   if([trim hasPrefix:@"#"]){NSUInteger count=0;while(count<trim.length&&[trim characterAtIndex:count]=='#')count++;if(count<trim.length&&[trim characterAtIndex:count]==' '){line=DXTrim([trim substringFromIndex:count]);heading=YES;}}
   else if([trim hasPrefix:@"> "]){line=[@"▏ " stringByAppendingString:[trim substringFromIndex:2]];quote=YES;}
   else if([trim hasPrefix:@"- "]||[trim hasPrefix:@"* "]||[trim hasPrefix:@"+ "]){line=[@"•  " stringByAppendingString:[trim substringFromIndex:2]];bullet=YES;}
   else if([trim isEqual:@"---"]||[trim isEqual:@"***"]){line=@"────────";quote=YES;}
  }
  UIFont *font=code?[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular]:[UIFont systemFontOfSize:heading?17:15 weight:heading?UIFontWeightSemibold:UIFontWeightRegular];
  UIColor *lineColor=quote?UIColor.secondaryLabelColor:ink;
  NSMutableParagraphStyle *paragraph=[NSMutableParagraphStyle new];paragraph.lineSpacing=3;paragraph.paragraphSpacing=heading?8:(bullet||table?3:5);paragraph.lineBreakMode=NSLineBreakByWordWrapping;
  NSDictionary *base=@{NSFontAttributeName:font,NSForegroundColorAttributeName:lineColor,NSParagraphStyleAttributeName:paragraph};
  if(code){NSMutableDictionary *attrs=[base mutableCopy];attrs[NSBackgroundColorAttributeName]=UIColor.tertiarySystemFillColor;[output appendAttributedString:[[NSAttributedString alloc]initWithString:line attributes:attrs]];}
  else DXAppendInline(output,line,base,font,lineColor);
  if(n+1<lines.count)[output appendAttributedString:[[NSAttributedString alloc]initWithString:@"\n" attributes:base]];
 }
 return output;
}

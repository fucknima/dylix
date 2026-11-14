#import "TFAIDirectoryPickerDiagnostics.h"
#import "../../Incoming/TFShareGroups.h"
static NSString *String(id value){return [value isKindOfClass:NSString.class]?value:@"";}
static BOOL Allows(NSString *pattern,NSString *identifier){
 if(!pattern.length||!identifier.length)return NO;
 if([pattern isEqual:identifier])return YES;
 if(![pattern hasSuffix:@".*"])return NO;
 NSString *prefix=[pattern substringToIndex:pattern.length-1];
 return ![prefix containsString:@"*"]&&[identifier hasPrefix:prefix]&&identifier.length>prefix.length;
}
NSDictionary *TFAIDirectorySigningChecks(NSString *bundleID,NSDictionary *e,NSDictionary *profile){
 NSString *appid=String(e[@"application-identifier"]),*team=String(e[@"com.apple.developer.team-identifier"]);
 NSDictionary *rights=[profile[@"Entitlements"] isKindOfClass:NSDictionary.class]?profile[@"Entitlements"]:@{};
 NSString *allowed=String(rights[@"application-identifier"]);
 NSString *prefix=nil;
 id prefixes=profile[@"ApplicationIdentifierPrefix"];
 if([prefixes isKindOfClass:NSArray.class])for(id value in prefixes){NSString *candidate=String(value);if(candidate.length&&[allowed hasPrefix:[candidate stringByAppendingString:@"."]]){prefix=candidate;break;}}
 // Application-ID prefixes have no dots. Do not assume they equal Team ID.
 NSRange dot=[allowed rangeOfString:@"."];
 if(!prefix.length&&dot.location!=NSNotFound&&dot.location>0)prefix=[allowed substringToIndex:dot.location];
 NSString *profileBundle=prefix.length?[allowed substringFromIndex:prefix.length+1]:@"";
 BOOL supported=profileBundle.length&&(![profileBundle containsString:@"*"]||[profileBundle isEqual:@"*"]||([profileBundle hasSuffix:@".*"]&&[[profileBundle componentsSeparatedByString:@"*"] count]==2));
 id profileMatches=(supported&&bundleID.length)?@(Allows(allowed,[NSString stringWithFormat:@"%@.%@",prefix,bundleID])):NSNull.null;
 // Missing XML data can mean DER-only entitlements. Treat it as unknown,
 // not proof that the effective entitlement is absent.
 BOOL decoded=e.count>0;NSString *suffix=[@"." stringByAppendingString:bundleID?:@""];
 NSMutableDictionary *r=[@{
  @"signedEntitlementsMetadata":decoded?@"decoded_xml":@"unavailable_or_der_only",
  @"applicationIdentifierPresent":decoded?@(appid.length>0):NSNull.null,
  @"applicationIdentifierMatchesBundleID":appid.length&&bundleID.length?@([appid hasSuffix:suffix]&&appid.length>suffix.length):NSNull.null,
  @"teamMatchesApplicationIdentifier":team.length&&appid.length?@([appid hasPrefix:[team stringByAppendingString:@"."]]):NSNull.null,
  @"profileMetadataAvailable":@(rights.count>0),
  @"profileAllowsSignedApplicationIdentifier":allowed.length&&appid.length?@(Allows(allowed,appid)):NSNull.null,
  @"note":@"仅核对安装包声明的标识关系，不验证签名信任，不包含证书、密钥、设备标识或书签。null 表示无法判定。"
 } mutableCopy];
 r[@"bundleID"]=bundleID?:@"";
 r[@"profileMatchesBundleID"]=profileMatches;
 r[@"profileBundleIdentifier"]=profileBundle;
 r[@"suggestedBundleIdentifier"]=(supported&&![profileBundle containsString:@"*"])?profileBundle:@"";
 r[@"signedApplicationIdentifier"]=appid;
 r[@"profileApplicationIdentifier"]=allowed;
 BOOL mismatch=[profileMatches isEqual:@NO]||[r[@"applicationIdentifierMatchesBundleID"] isEqual:@NO]||[r[@"profileAllowsSignedApplicationIdentifier"] isEqual:@NO];
 r[@"identityStatus"]=mismatch?@"mismatch":(appid.length&&allowed.length?@"metadata_consistent":@"unknown");
 r[@"signingAdvice"]=mismatch?@"重签名时必须使主应用 Bundle ID、application-identifier 和描述文件授权匹配；分享/灵动岛扩展也需各自匹配的描述文件。优先保留原 Bundle ID。更换 Bundle ID 会建立新沙盒，请先备份；App Group 可用不能替代标识校验。此异常尚不能单独证明目录选择失败的根因。":@"这里只核对签名元数据；应用标识前缀可能与 Team ID 不同，需以描述文件为准。";
 return r;
}
NSString *TFAIDirectorySigningWarning(NSDictionary *checks){
 BOOL mismatch=[checks[@"profileMatchesBundleID"] isEqual:@NO]||[checks[@"applicationIdentifierMatchesBundleID"] isEqual:@NO]||[checks[@"profileAllowsSignedApplicationIdentifier"] isEqual:@NO];
 if(!mismatch)return nil;
 NSString *bundle=String(checks[@"bundleID"]),*suggested=String(checks[@"suggestedBundleIdentifier"]);
 NSMutableString *message=[NSMutableString stringWithFormat:@"检测到当前软件 Bundle ID 与签名或描述文件的应用标识不一致，可能导致系统文件夹点“打开”无反应。\n\n当前 Bundle ID：%@",bundle.length?bundle:@"未读取到"];
 if(suggested.length)[message appendFormat:@"\n描述文件对应的 Bundle ID：%@\n\n请在签名软件中把软件的 Bundle ID 改成 %@ 后重新签名安装，不要带前面的 App ID 前缀。",suggested,suggested];
 else [message appendString:@"\n\n请让签名软件同步软件 Bundle ID、签名应用标识和描述文件的授权范围。通配描述文件不需要改成字面上的 *。"];
 [message appendString:@"\n\n分享和灵动岛扩展也需匹配。更改 Bundle ID 可能成为新应用，请先备份项目和会话。"];
 return message;
}
static NSData *BoundedFile(NSString *path,uint64_t limit){
 if(!path.length)return nil;NSDictionary *a=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
 if(![a[NSFileType] isEqual:NSFileTypeRegular]||[a[NSFileSize] unsignedLongLongValue]>limit)return nil;
 return [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
}
static NSDictionary *ProfileMetadata(NSData *data){
 if(!data.length)return @{};
 // Extract only the plist carried in the CMS envelope. This deliberately does
 // not claim to validate the CMS signature or provisioning trust.
 NSData *start=[@"<plist" dataUsingEncoding:NSUTF8StringEncoding],*end=[@"</plist>" dataUsingEncoding:NSUTF8StringEncoding];
 NSRange a=[data rangeOfData:start options:0 range:NSMakeRange(0,data.length)];if(a.location==NSNotFound)return @{};
 NSRange b=[data rangeOfData:end options:0 range:NSMakeRange(a.location,data.length-a.location)];if(b.location==NSNotFound)return @{};
 id value=[NSPropertyListSerialization propertyListWithData:[data subdataWithRange:NSMakeRange(a.location,NSMaxRange(b)-a.location)] options:NSPropertyListImmutable format:nil error:nil];
 return [value isKindOfClass:NSDictionary.class]?value:@{};
}
NSDictionary *TFAIDirectoryPickerDiagnostics(void){
 NSBundle *bundle=NSBundle.mainBundle;NSDictionary *e=TFShareSignedEntitlements(BoundedFile(bundle.executablePath,64ULL*1024*1024));
 NSData *profile=BoundedFile([bundle.bundlePath stringByAppendingPathComponent:@"embedded.mobileprovision"],4ULL*1024*1024);
 NSMutableDictionary *r=[TFAIDirectorySigningChecks(bundle.bundleIdentifier,e,ProfileMetadata(profile)) mutableCopy];
 r[@"bundleID"]=bundle.bundleIdentifier?:@"";r[@"embeddedProfilePresent"]=@(profile!=nil);
 r[@"supportsOpeningDocumentsInPlace"]=@([bundle.infoDictionary[@"LSSupportsOpeningDocumentsInPlace"] boolValue]);
 r[@"fileSharingEnabled"]=@([bundle.infoDictionary[@"UIFileSharingEnabled"] boolValue]);
 return r;
}

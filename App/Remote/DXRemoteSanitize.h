#import <Foundation/Foundation.h>
#import "../AI/Permissions/TFAIPolicy.h"

// Credential names are case/separator independent. Do not match "token" as a
// substring: inputTokens, tokenUsage and cachedTokens are ordinary usage data.
static id Clean(id value){
 if([value isKindOfClass:NSString.class])return TFAIContainsSecret(value)?@"[已隐藏疑似凭据]":value;
 if([value isKindOfClass:NSArray.class]){NSMutableArray *out=[NSMutableArray new];for(id item in value)[out addObject:Clean(item)];return out;}
 if([value isKindOfClass:NSDictionary.class]){
  static NSSet *sensitive;static dispatch_once_t once;dispatch_once(&once,^{sensitive=[NSSet setWithArray:@[@"root",@"projectroot",@"secret",@"secrets",@"token",@"accesstoken",@"refreshtoken",@"idtoken",@"apikey",@"xapikey",@"baseurl",@"authorization",@"proxyauthorization",@"cookie",@"setcookie",@"password",@"passwd",@"privatekey",@"clientsecret"]];});
  NSMutableDictionary *out=[NSMutableDictionary new];
  for(id key in value){if(![key isKindOfClass:NSString.class])continue;NSString *normalized=[[[key lowercaseString] stringByReplacingOccurrencesOfString:@"_" withString:@""] stringByReplacingOccurrencesOfString:@"-" withString:@""];if(![sensitive containsObject:normalized])out[key]=Clean(value[key]);}
  return out;
 }
 return value?:NSNull.null;
}

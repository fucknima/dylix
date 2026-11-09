#import "FLEXDylixPreferences.h"
#import <Security/Security.h>

static NSString *const DXPreferencesKey=@"FLEX.Dylix.Connection.v1";
static NSString *DXStatePath(void){NSString *base=NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject;return [[base stringByAppendingPathComponent:@"FLEXDylix"] stringByAppendingPathComponent:@"connection.plist"];}
static NSDictionary *DXMetadata(void){
 NSString *path=DXStatePath();if([NSFileManager.defaultManager fileExistsAtPath:path]){id object=[NSDictionary dictionaryWithContentsOfFile:path];return [object isKindOfClass:NSDictionary.class]?object:@{};}
 // One-time import for versions that stored only non-secret preferences.
 id legacy=[NSUserDefaults.standardUserDefaults objectForKey:DXPreferencesKey];return [legacy isKindOfClass:NSDictionary.class]?legacy:@{};
}
static NSArray *DXPublicKeys(void){return @[@"host",@"port",@"projectID",@"projectName",@"connectionID",@"modelID",@"modelName",@"sessionID",@"sessionTitle"];}
static NSArray *DXSecretKeys(void){return @[@"authorizationCode",@"token",@"csrf"];}
static NSMutableDictionary *DXSecretQuery(void){return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:@"FLEX.Dylix.ConnectionSecrets.v1",(__bridge id)kSecAttrAccount:NSBundle.mainBundle.bundleIdentifier?:@"host"} mutableCopy];}
static NSError *DXStorageError(OSStatus status){return [NSError errorWithDomain:@"FLEX.Dylix.Storage" code:status userInfo:@{NSLocalizedDescriptionKey:@"连接配置的安全存储失败，请检查目标 App 的签名和钥匙串权限；本次连接仍可继续使用。"}];}
static NSDictionary *DXCachedSecrets;
static NSDictionary *DXReadSecrets(void){
 if(DXCachedSecrets)return DXCachedSecrets;
 NSMutableDictionary *query=DXSecretQuery();query[(__bridge id)kSecReturnData]=@YES;query[(__bridge id)kSecMatchLimit]=(__bridge id)kSecMatchLimitOne;
 CFTypeRef value=NULL;OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)query,&value);
 NSData *data=CFBridgingRelease(value);id object=status==errSecSuccess&&data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
 if([object isKindOfClass:NSDictionary.class])DXCachedSecrets=object;
 else if(status==errSecItemNotFound)DXCachedSecrets=@{};
 return DXCachedSecrets?:@{};
}
@implementation FLEXDylixPreferences
+ (NSDictionary *)loadState {@synchronized(self){
 id raw=DXMetadata();NSMutableDictionary *state=[NSMutableDictionary new];
 if([raw isKindOfClass:NSDictionary.class])for(NSString *key in DXPublicKeys()){id value=raw[key];if(([key isEqual:@"port"]&&[value isKindOfClass:NSNumber.class]&&[value unsignedIntegerValue]>0&&[value unsignedIntegerValue]<=65535)||(![key isEqual:@"port"]&&[value isKindOfClass:NSString.class]&&[value length]<=2048))state[key]=value;}
 NSDictionary *secret=DXReadSecrets();for(NSString *key in DXSecretKeys())if([secret[key] isKindOfClass:NSString.class]&&[secret[key] length]<=2048)state[key]=secret[key];
 return state.copy;
}}
+ (BOOL)saveState:(NSDictionary *)state error:(NSError **)error {@synchronized(self){
 NSMutableDictionary *metadata=[NSMutableDictionary new],*secrets=[NSMutableDictionary new];
 for(NSString *key in DXPublicKeys()){id value=state[key];if([key isEqual:@"port"]){if([value isKindOfClass:NSNumber.class]&&[value unsignedIntegerValue]>0&&[value unsignedIntegerValue]<=65535)metadata[key]=value;}else if([value isKindOfClass:NSString.class]&&[value length]<=2048)metadata[key]=value;}
 for(NSString *key in DXSecretKeys())if([state[key] isKindOfClass:NSString.class]&&[state[key] length]&&[state[key] length]<=2048)secrets[key]=state[key];
 BOOL ok=YES;if(![DXReadSecrets() isEqual:secrets]){
  NSMutableDictionary *query=DXSecretQuery();OSStatus status;
  if(!secrets.count){status=SecItemDelete((__bridge CFDictionaryRef)query);if(status==errSecItemNotFound)status=errSecSuccess;}
  else {NSData *data=[NSJSONSerialization dataWithJSONObject:secrets options:0 error:nil];NSDictionary *attrs=@{(__bridge id)kSecValueData:data,(__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};status=SecItemUpdate((__bridge CFDictionaryRef)query,(__bridge CFDictionaryRef)attrs);if(status==errSecItemNotFound){[query addEntriesFromDictionary:attrs];status=SecItemAdd((__bridge CFDictionaryRef)query,NULL);}}
  ok=status==errSecSuccess;if(ok)DXCachedSecrets=secrets.copy;else if(error)*error=DXStorageError(status);
 }
 NSString *path=DXStatePath();if(![DXMetadata() isEqual:metadata]||![NSFileManager.defaultManager fileExistsAtPath:path]){
  NSError *failure=nil;NSData *data=[NSPropertyListSerialization dataWithPropertyList:metadata format:NSPropertyListBinaryFormat_v1_0 options:0 error:&failure];
  if(!data||![NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&failure]||![data writeToFile:path options:NSDataWritingAtomic|NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:&failure]){ok=NO;if(error)*error=failure;}
  else [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:path error:nil];
 }
 return ok;
}}
+ (BOOL)clearAuthorization:(NSError **)error {@synchronized(self){OSStatus status=SecItemDelete((__bridge CFDictionaryRef)DXSecretQuery());if(status!=errSecSuccess&&status!=errSecItemNotFound){if(error)*error=DXStorageError(status);return NO;}DXCachedSecrets=@{};return YES;}}
+ (BOOL)clearAll:(NSError **)error {@synchronized(self){if(![self clearAuthorization:error]||![self saveState:@{} error:error])return NO;[NSUserDefaults.standardUserDefaults removeObjectForKey:DXPreferencesKey];[NSUserDefaults.standardUserDefaults synchronize];return YES;}}
@end

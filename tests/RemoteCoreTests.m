#import <Foundation/Foundation.h>
#import "../App/Remote/DXRemoteAccess.h"
#import "../App/Remote/DXRemoteHTTP.h"
#import "../App/Remote/DXRemoteTLS.h"
#import "../App/Remote/DXRemoteNetwork.h"
static NSUInteger count;
static void Check(BOOL ok,NSString *name){if(!ok){fprintf(stderr,"FAIL %s\n",name.UTF8String);exit(1);}count++;printf("PASS %s\n",name.UTF8String);}
static NSInteger Parse(NSData *data){BOOL complete=NO;NSInteger fail=0;NSDictionary *r=DXRemoteParseRequest(data,&complete,&fail);return fail?:complete&&r?200:0;}
static NSData *Bytes(NSString *s){return [s dataUsingEncoding:NSUTF8StringEncoding];}
int main(int argc,char **argv){@autoreleasepool{
 Check([DXRemoteSelectedMode(@"local") isEqual:@"local"]&&[DXRemoteSelectedMode(@"wifi") isEqual:@"wifi"],@"only LAN and local mode selected");
 Check([DXRemoteSelectedMode(@"tailnet") isEqual:@"wifi"]&&[DXRemoteSelectedMode(@"invalid") isEqual:@"wifi"],@"removed and invalid stored modes safely fall back to LAN");
 Check(!DXRemoteInterfaceAllowed(@"100.88.1.2",@"utun7",YES,@"wifi"),@"VPN interface never advertised");
 Check(!DXRemoteInterfaceAllowed(@"100.88.1.2",@"pdp_ip0",YES,@"wifi"),@"carrier CGNAT never advertised");
 Check(DXRemoteInterfaceAllowed(@"192.168.1.2",@"en0",YES,@"wifi")&&!DXRemoteInterfaceAllowed(@"192.168.1.2",@"en0",NO,@"wifi"),@"LAN requires active Wi-Fi interface");
 Check(!DXRemotePeerAllowed(@"100.99.1.2",@"192.168.1.2")&&!DXRemotePeerAllowed(@"8.8.8.8",@"192.168.1.2"),@"LAN listener rejects overlay and public peers");
 Check(DXRemotePeerAllowed(@"192.168.1.3",@"192.168.1.2")&&DXRemotePeerAllowed(@"127.0.0.1",@"192.168.1.2"),@"existing LAN and local access preserved");
 Check(DXRemotePeerAllowed(@"127.0.0.1",@"127.0.0.1")&&!DXRemotePeerAllowed(@"192.168.1.2",@"127.0.0.1"),@"same-device mode only accepts loopback");
 Check(Parse(Bytes(@"GET / HTTP/1.1\r\nHost: 127.0.0.1:8787\r\n\r\n"))==200,@"valid HTTP request");
 Check(Parse(Bytes(@"GET / HTTP/1.1\r\nHost: local\r\n"))==0,@"partial header waits");
 Check(Parse(Bytes(@"POST /api HTTP/1.1\r\nHost: local\r\nContent-Length: 5\r\n\r\n123"))==0,@"partial body waits");
 Check(Parse(Bytes(@"POST /api HTTP/1.1\r\nHost: local\r\nContent-Length: 5\r\n\r\n12345"))==200,@"complete body accepted");
 NSArray *bad=@[
 @"GET / HTTP/1.1\r\n\r\n",
 @"GET / HTTP/1.1\r\nHost: a\r\nHost: b\r\n\r\n",
 @"GET / HTTP/1.1\r\nHost: a\r\nhOsT: b\r\n\r\n",
 @"GET / HTTP/1.1\r\nHost : a\r\n\r\n",
 @"GET / HTTP/1.1\r\nHost: a\r\n folded: b\r\n\r\n",
 @"POST / HTTP/1.1\r\nHost: a\r\nContent-Length: -1\r\n\r\n",
 @"POST / HTTP/1.1\r\nHost: a\r\nContent-Length: +1\r\n\r\nx",
 @"POST / HTTP/1.1\r\nHost: a\r\nContent-Length: 1.0\r\n\r\nx",
 @"POST / HTTP/1.1\r\nHost: a\r\nContent-Length: 0\r\nContent-Length: 1\r\n\r\n",
 @"POST / HTTP/1.1\r\nHost: a\r\nTransfer-Encoding: chunked\r\n\r\n",
 @"GET / HTTP/1.1\r\nHost: a\r\nUpgrade: websocket\r\n\r\n",
 @"POST / HTTP/1.1\r\nHost: a\r\nExpect: 100-continue\r\n\r\n",
 @"GET / HTTP/1.1\r\nHost: a\r\nContent-Length: 1\r\n\r\nx",
 @"GET / HTTP/1.0\r\nHost: a\r\n\r\n",
 @"GET http://elsewhere/ HTTP/1.1\r\nHost: a\r\n\r\n",
 @"GET / HTTP/1.1\r\nHost: a\r\n\r\nGET / HTTP/1.1\r\nHost: a\r\n\r\n"];
 for(NSString *s in bad)Check(Parse(Bytes(s))==400,@"reject smuggling or malformed HTTP");
 Check(Parse(Bytes(@"PUT / HTTP/1.1\r\nHost: a\r\nContent-Length: 0\r\n\r\n"))==200,@"PUT parser accepted for WebDAV");
 Check(Parse(Bytes(@"POST / HTTP/1.1\r\nHost: a\r\nContent-Length: 8193\r\n\r\n"))==413,@"body limit enforced");
 Check(Parse(Bytes([@"GET / HTTP/1.1\r\nHost: a\r\nX: " stringByAppendingString:[@"a" stringByPaddingToLength:16400 withString:@"a" startingAtIndex:0]]))==431,@"header limit enforced");
 NSMutableData *nul=[Bytes(@"GET / HTTP/1.1\r\nHost: a\r\n\r\n") mutableCopy];((char *)nul.mutableBytes)[5]=0;Check(Parse(nul)==400,@"NUL header rejected");
 NSString *tmp=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"RemoteCore-" stringByAppendingString:NSUUID.UUID.UUIDString]],*store=[tmp stringByAppendingPathComponent:@"devices.json"];
 DXRemoteAccess *access=[[DXRemoteAccess alloc]initWithStore:store];Check(!access.pairingCode.length&&access.devices.count==0,@"default no pairing or devices");[access rotateCode];Check(access.pairingCode.length==8,@"eight digit code generated");
 NSDictionary *request=@{@"name":@"Test browser",@"code":access.pairingCode},*pair=[access beginPair:request peer:@"127.0.0.1"];
 Check([pair[@"status"] integerValue]==200&&access.pending.count==0&&access.devices.count==1,@"valid code authorizes directly without pending phone step");
 Check([[access beginPair:request peer:@"127.0.0.1"][@"status"] integerValue]==403,@"random code consumed after successful persistence");
 NSString *token=pair[@"token"];Check(token.length==64,@"256-bit credential issued");
 Check(![access authenticateCookie:@"session=wrong" name:@"session"],@"invalid cookie rejected");
 NSDictionary *device=[access authenticateCookie:[@"session=" stringByAppendingString:token] name:@"session"];
 Check([device[@"name"] isEqual:@"Test browser"]&&[device[@"csrf"] length]==64,@"cookie maps device and CSRF");
 Check([device[@"permission"] isEqual:@"overview:read"],@"workspace access remains opt-in");
 Check(![access authenticateCookie:[NSString stringWithFormat:@"session=%@; session=%@",token,token] name:@"session"],@"duplicate cookie rejected");
 Check([access.devices[0][@"online"] boolValue],@"recent authenticated device online");
 NSString *disk=[NSString stringWithContentsOfFile:store encoding:NSUTF8StringEncoding error:nil];Check(![disk containsString:token]&&[disk containsString:DXRemoteHash(token)],@"disk stores hash instead of bearer token");
 Check(![[access.devices description] containsString:token]&&![[access.events description] containsString:token],@"device list and audit exclude token");
 Check([device[@"csrf"] isEqual:[access csrfForToken:token]],@"CSRF bound to session");
 DXRemoteAccess *restored=[[DXRemoteAccess alloc]initWithStore:store];Check(restored.devices.count==1&&![restored.devices[0][@"online"] boolValue],@"restore device offline");
 Check([restored authenticateCookie:[@"session=" stringByAppendingString:token] name:@"session"]!=nil,@"persistent device authenticates");
 [restored revoke:device[@"id"] error:nil];Check(![restored authenticateCookie:[@"session=" stringByAppendingString:token] name:@"session"],@"revocation invalidates token");
 Check(![access setFixedCode:@"１２３４５６" error:nil]&&![access setFixedCode:@"123" error:nil],@"fixed code validates ASCII digits and length");
 Check([access setFixedCode:@"654321" error:nil]&&access.fixedCode&&access.codeExpiry==0,@"fixed code has no countdown expiry");
 NSDictionary *fixed=[access beginPair:@{@"code":@"654321",@"name":@"Workspace",@"workspace":@YES} peer:@"fixed1"];
 Check([fixed[@"status"] integerValue]==200&&[access.pairingCode isEqual:@"654321"],@"fixed code retained after pairing");
 NSDictionary *second=[access beginPair:@{@"code":@"654321",@"name":@"Second"} peer:@"fixed2"];
 Check([second[@"status"] integerValue]==200&&![second[@"token"] isEqual:fixed[@"token"]],@"each fixed-code device receives independent token");
 Check([[access authenticateCookie:[@"s=" stringByAppendingString:fixed[@"token"]] name:@"s"][@"permission"] isEqual:@"workspace"],@"explicit workspace request grants workspace");
 Check([[access beginPair:@{@"code":@"654321",@"name":@"Bad type",@"workspace":@"yes"} peer:@"typed"][@"status"] integerValue]==400,@"malformed permission field rejected");
 [access rotateCode];Check(!access.fixedCode&&access.pairingCode.length==8,@"switch to random clears fixed mode");
 [access setValue:@0 forKey:@"codeExpiry"];Check([[access beginPair:@{@"code":access.pairingCode,@"name":@"Expired"} peer:@"expiry"][@"status"] integerValue]==403,@"random code expiration enforced");
 DXRemoteAccess *limited=[[DXRemoteAccess alloc]initWithStore:[tmp stringByAppendingPathComponent:@"limit.json"]];
 for(NSUInteger i=0;i<5;i++)Check([[limited beginPair:@{@"code":@"bad",@"name":@"x"} peer:@"one"][@"status"] integerValue]==403,@"bad attempts counted");
 [limited rotateCode];Check([[limited beginPair:@{@"code":limited.pairingCode,@"name":@"x"} peer:@"one"][@"status"] integerValue]==429,@"pair rate limit enforced");
 DXRemoteAccess *blocked=[[DXRemoteAccess alloc]initWithStore:@"/dev/null/impossible.json"];[blocked rotateCode];NSString *original=blocked.pairingCode;
 Check([[blocked beginPair:@{@"code":original,@"name":@"x"} peer:@"one"][@"status"] integerValue]==503&&blocked.devices.count==0&&[blocked.pairingCode isEqual:original],@"storage failure issues no token and retains retry code");
 CFErrorRef keyError=NULL;SecKeyRef key=SecKeyCreateRandomKey((__bridge CFDictionaryRef)@{(__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeECSECPrimeRandom,(__bridge id)kSecAttrKeySizeInBits:@256},&keyError);
 Check(key!=NULL,@"TLS P-256 key generated");NSError *certificateError=nil;NSData *der=DXRemoteCreateCertificate(key,@"127.0.0.1",&certificateError);Check(der.length>200&&!certificateError,@"fixed-schema self-signed DER certificate generated");
 SecCertificateRef certificate=SecCertificateCreateWithData(NULL,(__bridge CFDataRef)der);Check(certificate!=NULL,@"Security parses generated certificate");
 if(argc>1)[der writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES];
 CFRelease(certificate);CFRelease(key);if(keyError)CFRelease(keyError);
 [access resetEphemeral];Check(access.pending.count==0&&!access.pairingCode.length,@"stopping clears pending and pairing code");
 for(NSUInteger i=0;i<240;i++)[access record:@"test_event"];Check(access.events.count==200,@"audit bounded");
 [access revoke:nil error:nil];Check(access.devices.count==0,@"disconnect all revokes devices");
 [NSFileManager.defaultManager removeItemAtPath:tmp error:nil];printf("TOTAL %lu checks passed\n",(unsigned long)count);
}}

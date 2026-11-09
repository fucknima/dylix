#import <Foundation/Foundation.h>
#import "FLEXDylixConnection.h"
#import "FLEXDylixAddress.h"
#import <errno.h>

int main(int argc, const char **argv) { @autoreleasepool {
    if(argc==2&&!strcmp(argv[1],"--scopes")){
        NSMutableDictionary *checks=[NSMutableDictionary new];NSString *host=nil;NSUInteger port=0;
        checks[@"local address and actual port accepted"]=@(FLEXDylixParseAddress(@"http://127.0.0.1:9456",&host,&port,NULL)&&[host isEqual:@"127.0.0.1"]&&port==9456);
        checks[@"LAN private address accepted"]=@(FLEXDylixParseAddress(@"http://192.168.1.9:9456",NULL,NULL,NULL));
        checks[@"removed VPN address rejected"]=@(!FLEXDylixParseAddress(@"http://100.88.1.2:9456",NULL,NULL,NULL));
        checks[@"public address rejected"]=@(!FLEXDylixParseAddress(@"http://8.8.8.8:9456",NULL,NULL,NULL));
        checks[@"removed HTTPS relay address rejected"]=@(!FLEXDylixParseAddress(@"https://example.com",NULL,NULL,NULL));
        checks[@"domain relay address rejected"]=@(!FLEXDylixParseAddress(@"http://example.com:9456",NULL,NULL,NULL));
        NSError *error=nil;NSDictionary *result=FLEXDylixHTTPRequest(@"100.88.1.2",9456,@"/api/v1/status",@{},nil,nil,.1,NULL,&error);checks[@"stale saved VPN endpoint rejected before socket connection"]=@(result==nil&&error.code==EINVAL);
        NSData *json=[NSJSONSerialization dataWithJSONObject:checks options:0 error:nil];fwrite(json.bytes,1,json.length,stdout);return 0;
    }
    if(argc==3 && !strcmp(argv[1],"--live")) {
        NSDictionary *state=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]]?:NSData.data options:0 error:nil];
        if(![state[@"state"] isEqual:@"running"] || ![state[@"address"] isEqual:@"127.0.0.1"] || ![state[@"code"] length])return 3;
        NSString *host=state[@"address"],*token=nil;NSUInteger port=[state[@"port"] unsignedIntegerValue];NSError *error=nil;
        NSDictionary *unauth=FLEXDylixHTTPRequest(host,port,@"/api/v1/status",@{},nil,nil,3,NULL,&error);
        BOOL authCheck=!unauth && [error.domain isEqual:@"FLEX.Dylix.HTTP"] && error.code==401;
        NSDictionary *pair=FLEXDylixHTTPRequest(host,port,@"/api/v1/pair",@{@"code":state[@"code"],@"name":@"Build196 socket regression",@"workspace":@YES},nil,nil,3,&token,&error);
        BOOL paired=[pair[@"state"] isEqual:@"approved"] && token.length>0 && !error;
        NSDictionary *status=FLEXDylixHTTPRequest(host,port,@"/api/v1/status",@{},token,nil,3,NULL,&error);
        NSString *csrf=status[@"session"][@"csrf"];
        BOOL statusOK=csrf.length>0 && [status[@"session"][@"permission"] isEqual:@"workspace"] && !error;
        NSDictionary *next=FLEXDylixHTTPRequest(host,port,@"/api/v1/flex/next",@{},token,csrf,3,NULL,&error);
        BOOL nextOK=next!=nil && !error;
        NSDictionary *report=@{@"unauthorized401":@(authCheck),@"pairAndCookie":@(paired),@"statusAndCSRF":@(statusOK),@"authenticatedHeartbeat":@(nextOK)};
        NSData *json=[NSJSONSerialization dataWithJSONObject:report options:0 error:nil];fwrite(json.bytes,1,json.length,stdout);
        return authCheck && paired && statusOK && nextOK?0:1;
    }
    if(argc==2 && !strcmp(argv[1],"--errors")) {
        NSMutableArray *reports=[NSMutableArray new];
        for(NSNumber *code in @[@EACCES,@EPERM,@EHOSTUNREACH,@ENETUNREACH,@ECONNREFUSED,@ETIMEDOUT,@EAGAIN,@ECONNRESET,@EPIPE,@EMFILE,@EINVAL]) {
            NSError *error=FLEXDylixConnectionError(@"192.168.20.10",9432,@"/api/v1/pair",@"connect",code.integerValue,0);
            [reports addObject:@{@"code":code,@"description":error.localizedDescription,@"report":error.userInfo[FLEXDylixConnectionDiagnosticKey]}];
        }
        NSError *read=FLEXDylixConnectionError(@"192.168.20.10",9432,@"/api/v1/status",@"read",ETIMEDOUT,0);
        [reports addObject:@{@"description":read.localizedDescription,@"report":read.userInfo[FLEXDylixConnectionDiagnosticKey]}];
        NSData *json=[NSJSONSerialization dataWithJSONObject:reports options:0 error:nil];fwrite(json.bytes,1,json.length,stdout);return 0;
    }
    if(argc<4)return 2;
    NSString *token=nil;NSError *error=nil;
    NSTimeInterval before=NSProcessInfo.processInfo.systemUptime;
    NSDictionary *data=FLEXDylixHTTPRequest(@"127.0.0.1",strtoul(argv[1],NULL,10),[NSString stringWithUTF8String:argv[2]],
        @{@"code":@"fixture-code-never-log",@"workspace":@YES},@"fixture-token-never-log",@"fixture-csrf-never-log",atof(argv[3]),&token,&error);
    NSDictionary *result=@{@"ok":@(data!=nil),@"data":data?:@{},@"token":token?:@"",@"domain":error.domain?:@"",@"code":@(error.code),
        @"description":error.localizedDescription?:@"",@"report":error.userInfo[FLEXDylixConnectionDiagnosticKey]?:@"",
        @"elapsed":@(NSProcessInfo.processInfo.systemUptime-before)};
    NSData *json=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];fwrite(json.bytes,1,json.length,stdout);return 0;
} }

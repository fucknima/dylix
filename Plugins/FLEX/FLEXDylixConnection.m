#import "FLEXDylixConnection.h"
#import <arpa/inet.h>
#import <errno.h>
#import <fcntl.h>
#import <limits.h>
#import <math.h>
#import <poll.h>
#import <string.h>
#import <sys/socket.h>
#import <unistd.h>

NSString *const FLEXDylixConnectionDiagnosticKey = @"FLEXDylixConnectionDiagnostic";

NSError *FLEXDylixConnectionError(NSString *host, NSUInteger port, NSString *path,
                                 NSString *stage, NSInteger posixCode, NSInteger httpStatus) {
    BOOL connecting = [stage isEqual:@"connect"] || [stage isEqual:@"socket"];
    NSString *reason = @"Dylix 返回的响应格式不正确", *advice = @"确认访问地址属于 Dylix HTTP 远程服务，而非 WebDAV 端口，并更新两端版本。";
    if (posixCode) {
        switch (posixCode) {
            case EACCES: case EPERM:
                reason = @"系统策略拒绝了网络访问";
                advice = @"检查被注入 App 的本地网络权限、VPN 和设备管理限制。此错误本身不能确定是哪项策略。"; break;
            case EHOSTUNREACH: case ENETUNREACH: case EADDRNOTAVAIL:
                reason = @"无法到达 Dylix 的网络地址";
                advice = @"确认两台设备在可互通的 Wi-Fi，重新复制手机当前地址；检查 VPN、访客网络和路由器设备隔离。"; break;
            case ECONNREFUSED:
                reason = @"目标地址拒绝连接";
                advice = @"确认手机远程服务显示运行中，IP 与 HTTP 端口和复制的地址完全一致；检查 VPN 或防火墙。"; break;
            case ETIMEDOUT: case EAGAIN:
                reason = connecting ? @"连接 Dylix 超时" : @"等待 Dylix 响应超时";
                advice = connecting ? @"检查手机服务状态、Wi-Fi 互通、VPN 与路由器设备隔离。" : @"连接已建立，但未在时限内完成响应；检查手机服务状态、锁屏及网络中断。"; break;
            case ECONNRESET: case EPIPE: case ENOTCONN:
                reason = @"Dylix 连接中断"; advice = @"检查手机服务是否重启、锁屏或网络切换；配置已保留，可重试。"; break;
            case EMFILE: case ENFILE: case ENOBUFS: case ENOMEM:
                reason = @"无法分配网络连接资源"; advice = @"关闭不需要的任务，重新打开被注入 App 后重试。"; break;
            case EINVAL:
                reason = @"连接地址或请求无效"; advice = @"粘贴 Dylix 复制的完整 HTTP IPv4 地址，包含实际端口。"; break;
            default: reason = @"网络请求失败"; advice = @"复制诊断信息，根据失败阶段和系统错误码排查。"; break;
        }
    } else if (httpStatus) {
        reason = [NSString stringWithFormat:@"Dylix 返回 HTTP %ld", (long)httpStatus];
        if (httpStatus == 401) advice = @"网络已连通，保存的授权可能失效；重新输入当前授权码配对。";
        else if (httpStatus == 403) advice = @"网络已连通，请求被服务端权限或同源校验拒绝；确认使用手机复制的地址，重新配对。";
        else if (httpStatus == 423) advice = @"手机已锁定；解锁运行 Dylix 的设备后重试。";
        else if (httpStatus == 429) advice = @"请求或配对尝试过于频繁，请稍后使用有效授权码重试。";
        else if (httpStatus == 404 || (httpStatus >= 300 && httpStatus < 400)) advice = @"目标服务可达，但接口不匹配；确认是 Dylix HTTP 地址而非 WebDAV 或代理页面。未自动跟随重定向。";
        else if (httpStatus >= 500) advice = @"手机端服务返回错误；检查 Dylix 服务日志后重试。";
        else advice = @"网络已连通；检查授权码是否有效、两端版本和 Dylix 服务日志。";
    } else if ([stage isEqual:@"response_limit"]) {
        reason = @"Dylix 响应超过当前会话读取上限";
        advice = @"请缩小本次会话或操作结果后重试。";
    } else if ([stage isEqual:@"read_incomplete"]) {
        reason = @"Dylix 响应尚未接收完整，连接已关闭";
        advice = @"检查手机服务中断、VPN 或网络切换后重试。";
    }
    NSString *message = [NSString stringWithFormat:@"%@\n%@%@", reason, advice,
                          connecting ? @"\n尚未进入授权码验证，请勿据此判断授权码有误。" : @""];
    struct in_addr ip;
    NSString *destination = host.length && inet_pton(AF_INET, host.UTF8String, &ip) == 1 && port > 0 && port <= 65535
        ? [NSString stringWithFormat:@"http://%@:%lu", host, (unsigned long)port] : @"无效地址";
    NSSet *paths = [NSSet setWithArray:@[@"/api/v1/pair", @"/api/v1/status", @"/api/v1/workspace", @"/api/v1/jobs/get", @"/api/v1/jobs/confirm", @"/api/v1/flex/next", @"/api/v1/flex/reply"]];
    NSDictionary *info = NSBundle.mainBundle.infoDictionary ?: @{};
    NSString *systemError = posixCode ? [NSString stringWithUTF8String:strerror((int)posixCode)] : @"无";
    NSString *diagnostic = [NSString stringWithFormat:
        @"FLEX Dylix 连接诊断 · 1.0.3 / Build236\n时间：%@\n目标：%@\n接口：%@\n阶段：%@\nPOSIX：%ld (%@)\nHTTP：%ld\n宿主：%@\n宿主版本：%@ (%@)\n系统：%@\n宿主本地网络用途说明：%@\n%@\n\n排查：在运行 FLEX 的设备上用 Safari 打开上述目标地址。若也打不开，先检查手机服务、Wi-Fi、VPN 与设备隔离；若能打开但插件失败，再检查被注入 App 的本地网络权限和策略。权限说明存在与否不代表已获授权，本报告不能单独判断权限状态。\n不包含授权码、令牌、Cookie、会话正文。",
        NSDate.date, destination, [paths containsObject:path] ? path : @"其他接口", stage,
        (long)posixCode, systemError, (long)httpStatus, NSBundle.mainBundle.bundleIdentifier ?: @"未知",
        info[@"CFBundleShortVersionString"] ?: @"未知", info[@"CFBundleVersion"] ?: @"未知",
        NSProcessInfo.processInfo.operatingSystemVersionString,
        [info[@"NSLocalNetworkUsageDescription"] isKindOfClass:NSString.class] && [info[@"NSLocalNetworkUsageDescription"] length] ? @"存在" : @"缺失",
        message];
    NSMutableDictionary *metadata = [@{NSLocalizedDescriptionKey:message, FLEXDylixConnectionDiagnosticKey:diagnostic} mutableCopy];
    if (posixCode) metadata[NSUnderlyingErrorKey] = [NSError errorWithDomain:NSPOSIXErrorDomain code:posixCode userInfo:nil];
    return [NSError errorWithDomain:httpStatus ? @"FLEX.Dylix.HTTP" : @"FLEX.Dylix.Connection"
                              code:httpStatus ?: posixCode userInfo:metadata];
}

// poll + monotonic deadlines also bound connect(), unlike SO_SNDTIMEO/SO_RCVTIMEO.
static BOOL DXWait(int fd, short events, NSTimeInterval deadline, int *failure) {
    for (;;) {
        NSTimeInterval remaining = deadline - NSProcessInfo.processInfo.systemUptime;
        if (remaining <= 0) { *failure = ETIMEDOUT; return NO; }
        struct pollfd p = {fd, events, 0};
        int result = poll(&p, 1, (int)MIN(INT_MAX, MAX(1, remaining * 1000)));
        if (result > 0) {
            if (p.revents & POLLNVAL) { *failure = EBADF; return NO; }
            return YES; // send/recv or SO_ERROR report the actual failure / EOF.
        }
        if (!result) { *failure = ETIMEDOUT; return NO; }
        if (errno != EINTR) { *failure = errno; return NO; }
    }
}

static NSError *DXHTTPError(NSString *host, NSUInteger port, NSString *path, NSInteger status, NSData *payload) {
    NSError *base=FLEXDylixConnectionError(host,port,path,@"http",0,status);
    id object=[NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
    id detail=[object isKindOfClass:NSDictionary.class]?object[@"error"]:nil;
    id code=[detail isKindOfClass:NSDictionary.class]?detail[@"code"]:nil;
    NSDictionary *known=@{@"invalid_code":@"配对码无效或已过期，请在手机 Dylix 重新获取当前授权码。网络已连通。",
        @"rate_limited":@"配对请求过多，请一分钟后再试。网络已连通。",
        @"device_limit":@"已授权设备数量达到上限，请在 Dylix 管理已授权设备。网络已连通。",
        @"workspace_required":@"此连接没有工作区权限，请在 Dylix 重新授权 FLEX 工作区。",
        @"csrf_rejected":@"请求确认信息已过期，请重新配对。网络已连通。",
        @"origin_required":@"请求地址与 Dylix 监听地址不一致，请重新复制完整 HTTP 地址。网络已连通。",
        @"authentication_required":@"保存的授权无效或已过期，请重新配对。网络已连通。",
        @"device_locked":@"Dylix 设备已锁定，请解锁后重试。",
        @"storage_failed":@"Dylix 未能保存设备授权，请检查手机服务日志和可用存储。",
        @"entropy_unavailable":@"Dylix 随机数服务暂未就绪，请重试。"};
    NSString *message=[code isKindOfClass:NSString.class]?known[code]:nil;
    if(!message)return base;
    NSMutableDictionary *info=[base.userInfo mutableCopy];
    info[NSLocalizedDescriptionKey]=[NSString stringWithFormat:@"%@ (HTTP %ld)",message,(long)status];
    info[FLEXDylixConnectionDiagnosticKey]=[NSString stringWithFormat:@"%@\n服务端错误：%@\n%@",base.userInfo[FLEXDylixConnectionDiagnosticKey],code,message];
    return [NSError errorWithDomain:base.domain code:base.code userInfo:info];
}

NSDictionary *FLEXDylixHTTPRequest(NSString *host, NSUInteger port, NSString *path, NSDictionary *body,
                                  NSString *token, NSString *csrf, NSTimeInterval timeout,
                                  NSString **newToken, NSError **error) {
    if (newToken) *newToken = nil;
    if (error) *error = nil;
    NSString *stage = @"connect"; int failure = 0; NSInteger status = 0; int fd = -1;
    struct in_addr address;
    BOOL validHost=host.length&&inet_pton(AF_INET,host.UTF8String,&address)==1;uint32_t ip=validHost?ntohl(address.s_addr):0;
    BOOL localHost=validHost&&((ip>>24)==127||(ip>>24)==10||(ip>>20)==0xac1||(ip>>16)==0xc0a8||(ip>>16)==0xa9fe);
    if (!localHost || !port || port > 65535 ||
        ![path hasPrefix:@"/api/v1/"] || [path rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound ||
        (token.length && [token rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location != NSNotFound) ||
        (csrf.length && [csrf rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location != NSNotFound) ||
        !isfinite(timeout) || timeout <= 0) {
        if (error) *error = FLEXDylixConnectionError(host,port,path,stage,EINVAL,0); return nil;
    }
    // Sending credentials to another origin via redirects is deliberately unsupported.
    BOOL get = [path isEqual:@"/api/v1/status"] || [path isEqual:@"/api/v1/flex/next"];
    NSData *json = [NSJSONSerialization dataWithJSONObject:body ?: @{} options:0 error:nil];
    if (!json) { if(error)*error=FLEXDylixConnectionError(host,port,path,@"encode",EINVAL,0); return nil; }
    NSString *origin = [NSString stringWithFormat:@"http://%@:%lu",host,(unsigned long)port];
    NSMutableString *header = [NSMutableString stringWithFormat:@"%@ %@ HTTP/1.1\r\nHost: %@:%lu\r\nOrigin: %@\r\nContent-Type: application/json\r\nContent-Length: %lu\r\nConnection: close\r\n",get?@"GET":@"POST",path,host,(unsigned long)port,origin,(unsigned long)(get?0:json.length)];
    if (token.length) [header appendFormat:@"Cookie: DylixRemoteSession=%@\r\n",token];
    if (csrf.length) [header appendFormat:@"x-dylix-csrf: %@\r\n",csrf];
    [header appendString:@"\r\n"];
    NSMutableData *wire = [[header dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    if (!get) [wire appendData:json];
    NSDictionary *result = nil;
    do {
        stage = @"socket"; fd = socket(AF_INET,SOCK_STREAM,0);
        if (fd < 0) { failure = errno; break; }
        int one = 1;
        if (setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one)) != 0) { failure=errno; break; }
        int flags = fcntl(fd,F_GETFL,0);
        if (flags < 0 || fcntl(fd,F_SETFL,flags|O_NONBLOCK) < 0) { failure=errno; break; }
        struct sockaddr_in destination = {0}; destination.sin_family=AF_INET;
        destination.sin_port=htons((uint16_t)port); destination.sin_addr=address;
        stage = @"connect"; NSTimeInterval deadline=NSProcessInfo.processInfo.systemUptime+timeout;
        if (connect(fd,(struct sockaddr *)&destination,sizeof(destination)) != 0) {
            failure=errno;
            if (failure != EINPROGRESS && failure != EINTR) break;
            failure=0;
            if (!DXWait(fd,POLLOUT,deadline,&failure)) break;
            socklen_t size=sizeof(failure);
            if (getsockopt(fd,SOL_SOCKET,SO_ERROR,&failure,&size) != 0) failure=errno;
            if (failure) break;
        }
        stage=@"send"; deadline=NSProcessInfo.processInfo.systemUptime+timeout;
        NSUInteger sent=0;
        while (sent<wire.length) {
            if (!DXWait(fd,POLLOUT,deadline,&failure)) break;
            ssize_t n=send(fd,(const uint8_t *)wire.bytes+sent,wire.length-sent,0);
            if (n>0) sent+=(NSUInteger)n;
            else if (n<0 && (errno==EINTR || errno==EAGAIN)) continue;
            else { failure=n<0?errno:EPIPE; break; }
        }
        if (failure) break;
        stage=@"read"; deadline=NSProcessInfo.processInfo.systemUptime+timeout;
        NSMutableData *response=[NSMutableData new]; uint8_t buffer[16384];
        NSData *separator=[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
        NSRange split=NSMakeRange(NSNotFound,0); NSUInteger expected=NSNotFound;
        const NSUInteger maxResponse=40*1024*1024;
        BOOL eof=NO;
        while (!failure) {
            if (!DXWait(fd,POLLIN,deadline,&failure)) break;
            ssize_t n=recv(fd,buffer,sizeof(buffer),0);
            if (n<0) { if(errno==EINTR || errno==EAGAIN)continue; failure=errno; break; }
            if (!n) { eof=YES; break; }
            [response appendBytes:buffer length:(NSUInteger)n];
            if(response.length>maxResponse){stage=@"response_limit";break;}
            if(split.location==NSNotFound) {
                split=[response rangeOfData:separator options:0 range:NSMakeRange(0,response.length)];
                if(split.location==NSNotFound){if(response.length>65536){stage=@"headers";break;}continue;}
                NSString *head=[[NSString alloc]initWithData:[response subdataWithRange:NSMakeRange(0,split.location)] encoding:NSISOLatin1StringEncoding];
                NSArray *lines=[head componentsSeparatedByString:@"\r\n"];
                NSArray *first=[lines.firstObject componentsSeparatedByString:@" "];
                if(first.count<2 || ![first[0] hasPrefix:@"HTTP/1."]){stage=@"headers";break;}
                status=[first[1] integerValue];
                for(NSString *line in lines) {
                    NSRange colon=[line rangeOfString:@":"];if(colon.location==NSNotFound)continue;
                    NSString *key=[[line substringToIndex:colon.location] lowercaseString];
                    NSString *value=[[line substringFromIndex:NSMaxRange(colon)] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
                    if([key isEqual:@"content-length"]) {
                        NSScanner *scanner=[NSScanner scannerWithString:value];unsigned long long length=0;
                        if(![scanner scanUnsignedLongLong:&length] || !scanner.isAtEnd || length>maxResponse || (expected!=NSNotFound && expected!=length)){stage=@"headers";failure=EPROTO;break;}
                        expected=(NSUInteger)length;
                    }
                    if([key isEqual:@"transfer-encoding"] && ![value.lowercaseString isEqual:@"identity"]){stage=@"headers";failure=EPROTO;break;}
                }
                if(failure)break;
            }
            if(expected!=NSNotFound && response.length>=NSMaxRange(split)+expected)break;
        }
        if(failure || response.length>maxResponse || [stage isEqual:@"headers"])break;
        if(split.location==NSNotFound){stage=@"headers";break;}
        NSUInteger available=response.length-NSMaxRange(split);
        if(expected!=NSNotFound && available<expected){stage=@"read_incomplete";break;}
        if(!eof && expected==NSNotFound){stage=@"read_incomplete";break;}
        stage=@"http";
        NSData *payload=[response subdataWithRange:NSMakeRange(NSMaxRange(split),expected==NSNotFound?available:expected)];
        if(status<200 || status>=300){if(error)*error=DXHTTPError(host,port,path,status,payload);break;}
        id object=[NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
        stage=@"json";
        if(![object isKindOfClass:NSDictionary.class] || ![object[@"data"] isKindOfClass:NSDictionary.class])break;
        NSMutableDictionary *data=[object[@"data"] mutableCopy];
        if(get && object[@"session"]){if(![object[@"session"] isKindOfClass:NSDictionary.class])break;data[@"session"]=object[@"session"];}
        NSString *head=[[NSString alloc]initWithData:[response subdataWithRange:NSMakeRange(0,split.location)] encoding:NSISOLatin1StringEncoding];
        for(NSString *line in [head componentsSeparatedByString:@"\r\n"]) {
            if(![line.lowercaseString hasPrefix:@"set-cookie:"])continue;
            NSString *value=[[line substringFromIndex:11] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if(![value hasPrefix:@"DylixRemoteSession="])continue;
            if(newToken)*newToken=[[value substringFromIndex:[@"DylixRemoteSession=" length]] componentsSeparatedByString:@";"].firstObject;
        }
        result=data;
    } while(NO);
    if(fd>=0)close(fd); // errno was captured before any cleanup.
    if(!result && error && !*error)*error=FLEXDylixConnectionError(host,port,path,stage,failure,[stage isEqual:@"http"]?status:0);
    return result;
}

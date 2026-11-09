#import "FLEXDylixAddress.h"
#import <arpa/inet.h>

BOOL FLEXDylixParseAddress(NSString *raw, NSString **host, NSUInteger *port, NSString **errorMessage) {
    NSString *text = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURLComponents *parts = [NSURLComponents componentsWithString:text ?: @""];
    NSNumber *number = parts.port;
    NSString *address = parts.host;
    struct in_addr ipv4;
    BOOL ipv4Valid=address.length&&inet_pton(AF_INET,address.UTF8String,&ipv4)==1;
    uint32_t value=ipv4Valid?ntohl(ipv4.s_addr):0;
    BOOL local=ipv4Valid&&((value>>24)==127||(value>>24)==10||(value>>20)==0xac1||(value>>16)==0xc0a8||(value>>16)==0xa9fe);
    BOOL valid = [parts.scheme.lowercaseString isEqualToString:@"http"] &&
        address.length && number && number.unsignedIntegerValue > 0 && number.unsignedIntegerValue <= 65535 &&
        local &&
        !parts.user.length && !parts.password.length && !parts.query.length && !parts.fragment.length &&
        (!parts.path.length || [parts.path isEqualToString:@"/"]);
    if (!valid) {
        if (errorMessage) *errorMessage = @"请粘贴 Dylix 显示的完整局域网或本机 HTTP 地址（包含实际端口）";
        return NO;
    }
    if (host) *host = address;
    if (port) *port = number.unsignedIntegerValue;
    return YES;
}

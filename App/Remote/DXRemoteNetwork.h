#import <Foundation/Foundation.h>
#import <arpa/inet.h>

static inline BOOL DXRemoteIPv4(NSString *text,uint32_t *value){struct in_addr a;if(![text isKindOfClass:NSString.class]||inet_pton(AF_INET,text.UTF8String,&a)!=1)return NO;if(value)*value=ntohl(a.s_addr);return YES;}
// Unsupported values from experimental builds fall back to the original LAN mode.
static inline NSString *DXRemoteSelectedMode(NSString *stored){return [stored isEqual:@"local"]?@"local":@"wifi";}
static inline BOOL DXRemotePrivateIPv4(NSString *text){uint32_t v=0;return DXRemoteIPv4(text,&v)&&((v>>24)==10||(v>>20)==0xac1||(v>>16)==0xc0a8||(v>>16)==0xa9fe);}
static inline BOOL DXRemoteInterfaceAllowed(NSString *address,NSString *name,BOOL up,NSString *mode){
 if(!up)return NO;
 return [name isEqual:@"en0"]&&DXRemotePrivateIPv4(address);
}
static inline BOOL DXRemotePeerAllowed(NSString *peer,NSString *bound){
 uint32_t p=0,b=0;if(!DXRemoteIPv4(peer,&p)||!DXRemoteIPv4(bound,&b))return NO;
 if((b>>24)==127)return (p>>24)==127;
 return DXRemotePrivateIPv4(bound)&&(DXRemotePrivateIPv4(peer)||(p>>24)==127);
}

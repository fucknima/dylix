#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import "DXRemoteHTTP.h"
#import "DXRemoteNetwork.h"
#import <Network/Network.h>
#import <arpa/inet.h>

NSDictionary *DXRemoteResponse(NSInteger status,NSDictionary *json){
 return @{@"status":@(status),@"type":@"application/json; charset=utf-8",@"body":[NSJSONSerialization dataWithJSONObject:json options:0 error:nil]?:NSData.data};
}
NSDictionary *DXRemoteParseRequest(NSData *bytes,BOOL *complete,NSInteger *failure){
 *complete=NO;*failure=0;
 NSData *marker=[@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];NSRange end=[bytes rangeOfData:marker options:0 range:NSMakeRange(0,bytes.length)];
 if(end.location==NSNotFound){if(bytes.length>16384)*failure=431;return nil;}
 NSUInteger headerEnd=NSMaxRange(end);if(headerEnd>16384){*failure=431;return nil;}
 NSString *text=[[NSString alloc]initWithData:[bytes subdataWithRange:NSMakeRange(0,end.location)] encoding:NSASCIIStringEncoding];
 if(!text||memchr(bytes.bytes,0,end.location)){*failure=400;return nil;}
 NSArray *lines=[text componentsSeparatedByString:@"\r\n"],*start=[lines.firstObject componentsSeparatedByString:@" "];
 if(start.count!=3||[start[1] rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound||![start[2] isEqual:@"HTTP/1.1"]||![start[1] hasPrefix:@"/"]||[start[1] length]>2048){*failure=400;return nil;}
 if(![@[@"GET",@"HEAD",@"POST",@"OPTIONS",@"PROPFIND",@"PUT",@"MKCOL",@"MOVE",@"COPY",@"DELETE",@"LOCK",@"UNLOCK"] containsObject:start[0]]){*failure=405;return nil;}
 NSMutableDictionary *headers=[NSMutableDictionary new];NSCharacterSet *valid=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-"];
 for(NSUInteger i=1;i<lines.count;i++){
  NSString *line=lines[i];NSRange colon=[line rangeOfString:@":"];
  if(colon.location==NSNotFound||colon.location==0){*failure=400;return nil;}
  NSString *key=[[line substringToIndex:colon.location] lowercaseString],*value=[[line substringFromIndex:colon.location+1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
  if([key rangeOfCharacterFromSet:valid.invertedSet].location!=NSNotFound||headers[key]||[value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound){*failure=400;return nil;}headers[key]=value;
 }
 if(![headers[@"host"] length]||headers[@"transfer-encoding"]||headers[@"upgrade"]||headers[@"expect"]){*failure=400;return nil;}
 NSString *length=headers[@"content-length"];NSUInteger count=0;
 if(length){if(!length.length||length.length>8||[length rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location!=NSNotFound){*failure=400;return nil;}count=length.integerValue;}
 NSUInteger maxBody=[start[1] isEqual:@"/api/v1/workspace"]?2*1024*1024:([start[1] isEqual:@"/api/v1/flex/reply"]?4*1024*1024:([start[0] isEqual:@"PUT"]?8*1024*1024:8192));
 if(count>maxBody){*failure=413;return nil;}
 if(![@[@"POST",@"PUT",@"PROPFIND",@"LOCK"] containsObject:start[0]]&&count){*failure=400;return nil;}
 if(bytes.length<headerEnd+count)return nil;
 if(bytes.length!=headerEnd+count){*failure=400;return nil;}
 *complete=YES;return @{@"method":start[0],@"path":start[1],@"headers":headers,@"body":[bytes subdataWithRange:NSMakeRange(headerEnd,count)]};
}
@interface DXRemotePeer : NSObject
@property nw_connection_t connection;
@property NSMutableData *bytes;
@property BOOL finished;
@property BOOL responding;
@property NSFileHandle *file;
@property unsigned long long remaining;
@property dispatch_source_t sendTimer;
@end
@implementation DXRemotePeer
@end
@interface DXRemoteHTTP ()
@property dispatch_queue_t queue;
@property nw_listener_t listener;
@property NSString *origin;
@property NSMutableSet<DXRemotePeer *> *peers;
@property NSUInteger generation;
@end
@implementation DXRemoteHTTP
- (instancetype)initWithQueue:(dispatch_queue_t)queue{if((self=[super init])){_queue=queue;_peers=[NSMutableSet new];}return self;}
- (BOOL)startAddress:(NSString *)address port:(NSUInteger)port error:(NSError **)error{
 [self stop];struct in_addr ip;if(!port||port<1024||port>65535||inet_pton(AF_INET,address.UTF8String,&ip)!=1){if(error)*error=[NSError errorWithDomain:@"Dylix.Remote" code:1 userInfo:@{NSLocalizedDescriptionKey:@"请使用有效的局域网 IPv4 和 1024–65535 端口"}];return NO;}
 SecIdentityRef identity=self.tlsIdentity;
 nw_parameters_t parameters=identity?nw_parameters_create_secure_tcp(^(nw_protocol_options_t options){sec_protocol_options_t security=nw_tls_copy_sec_protocol_options(options);sec_protocol_options_set_min_tls_protocol_version(security,tls_protocol_version_TLSv12);sec_protocol_options_set_local_identity(security,sec_identity_create(identity));sec_protocol_options_add_tls_application_protocol(security,"http/1.1");},NW_PARAMETERS_DEFAULT_CONFIGURATION):nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,NW_PARAMETERS_DEFAULT_CONFIGURATION);
 nw_parameters_set_local_endpoint(parameters,nw_endpoint_create_host(address.UTF8String,[[NSString stringWithFormat:@"%lu",(unsigned long)port] UTF8String]));
 nw_parameters_set_include_peer_to_peer(parameters,false);
 nw_listener_t listener=nw_listener_create(parameters);if(!listener){if(error)*error=[NSError errorWithDomain:@"Dylix.Remote" code:2 userInfo:@{NSLocalizedDescriptionKey:@"创建网络监听失败"}];return NO;}
 self.listener=listener;self.origin=[NSString stringWithFormat:@"%@://%@:%lu",identity?@"https":@"http",address,(unsigned long)port];NSUInteger generation=++self.generation;__weak typeof(self) weak=self;
 nw_listener_set_queue(listener,self.queue);
 nw_listener_set_state_changed_handler(listener,^(nw_listener_state_t state,nw_error_t failure){
  DXRemoteHTTP *s=weak;if(!s||generation!=s.generation)return;
  if(state==nw_listener_state_ready){if(s.stateChanged)s.stateChanged(@"running");}
  else if(state==nw_listener_state_failed){[s stop];if(s.stateChanged)s.stateChanged(@"failed");}
 });
 nw_listener_set_new_connection_handler(listener,^(nw_connection_t connection){
  DXRemoteHTTP *s=weak;if(!s||generation!=s.generation){nw_connection_cancel(connection);return;}
  nw_endpoint_t endpoint=nw_connection_copy_endpoint(connection);const char *host=nw_endpoint_get_hostname(endpoint);BOOL local=host&&DXRemotePeerAllowed([NSString stringWithUTF8String:host],address);
  if(!local||s.peers.count>=16){nw_connection_cancel(connection);return;}
  DXRemotePeer *p=[DXRemotePeer new];p.connection=connection;p.bytes=[NSMutableData new];[s.peers addObject:p];nw_connection_set_queue(connection,s.queue);
  nw_connection_set_state_changed_handler(connection,^(nw_connection_state_t st,nw_error_t err){if(st==nw_connection_state_failed||st==nw_connection_state_cancelled)[weak close:p];});
  nw_connection_start(connection);[s read:p peer:host?[NSString stringWithUTF8String:host]:@"local"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),s.queue,^{if(!p.finished&&!p.responding)[weak close:p];});
 });nw_listener_start(listener);return YES;
}
- (void)close:(DXRemotePeer *)peer{if(peer.finished)return;peer.finished=YES;if(peer.sendTimer){dispatch_source_cancel(peer.sendTimer);peer.sendTimer=nil;}[peer.file closeAndReturnError:nil];peer.file=nil;nw_connection_set_state_changed_handler(peer.connection,nil);nw_connection_cancel(peer.connection);[self.peers removeObject:peer];}
- (void)read:(DXRemotePeer *)peer peer:(NSString *)address{
 __weak typeof(self) weak=self;nw_connection_receive(peer.connection,1,4096,^(dispatch_data_t content,nw_content_context_t context,bool eof,nw_error_t error){
  DXRemoteHTTP *s=weak;if(!s||peer.finished)return;
  if(content)dispatch_data_apply(content,^bool(dispatch_data_t region,size_t offset,const void *bytes,size_t size){[peer.bytes appendBytes:bytes length:size];return true;});
  BOOL complete=NO;NSInteger failure=0;NSDictionary *request=DXRemoteParseRequest(peer.bytes,&complete,&failure);
  if(failure){[s send:DXRemoteResponse(failure,@{@"error":@{@"code":@"invalid_http",@"message":@"请求格式或大小超出允许范围"}}) peer:peer head:NO];return;}
  if(complete){
   NSString *host=request[@"headers"][@"host"],*origin=request[@"headers"][@"origin"];
   NSString *scheme=[s.origin hasPrefix:@"https://"]?@"https://":@"http://";
   if(![[scheme stringByAppendingString:host] isEqual:s.origin]||(origin&&![origin isEqual:s.origin])){
    [s send:DXRemoteResponse(403,@{@"error":@{@"code":@"origin_rejected",@"message":@"请使用手机显示的访问地址"}}) peer:peer head:NO];return;
   }
   NSMutableDictionary *r=[request mutableCopy];r[@"peer"]=address;
   if(s.asyncHandler){NSUInteger generation=s.generation;s.asyncHandler(r,^(NSDictionary *response){dispatch_async(s.queue,^{if(generation==s.generation&&!peer.finished)[s send:response peer:peer head:[request[@"method"] isEqual:@"HEAD"]];});});return;}
   NSDictionary *response=s.handler?s.handler(r):DXRemoteResponse(503,@{@"error":@{@"code":@"unavailable",@"message":@"服务未就绪"}});
   [s send:response peer:peer head:[request[@"method"] isEqual:@"HEAD"]];return;
  }
  if(eof||error){[s close:peer];return;}[s read:peer peer:address];
 });
}
// File transfers use one bounded chunk in flight. The watchdog measures stalled
// progress rather than imposing a total transfer duration or file-size ceiling.
- (void)armSendTimeout:(DXRemotePeer *)peer{
 if(!peer.sendTimer){peer.sendTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,self.queue);__weak typeof(self) weak=self;__weak DXRemotePeer *weakPeer=peer;dispatch_source_set_event_handler(peer.sendTimer,^{DXRemotePeer *p=weakPeer;if(p)[weak close:p];});dispatch_resume(peer.sendTimer);}dispatch_source_set_timer(peer.sendTimer,dispatch_time(DISPATCH_TIME_NOW,120*NSEC_PER_SEC),DISPATCH_TIME_FOREVER,NSEC_PER_SEC);
}
- (void)sendFileChunk:(DXRemotePeer *)peer{
 if(peer.finished)return;if(!peer.remaining){[self close:peer];return;}
 NSError *error=nil;NSData *data=[peer.file readDataUpToLength:(NSUInteger)MIN(peer.remaining,256*1024ULL) error:&error];if(error||!data.length){[self close:peer];return;}peer.remaining-=data.length;[self armSendTimeout:peer];
 dispatch_data_t payload=dispatch_data_create(data.bytes,data.length,self.queue,^{(void)data.length;});__weak typeof(self) weak=self;
 nw_connection_send(peer.connection,payload,NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,true,^(nw_error_t failure){DXRemoteHTTP *s=weak;if(!s)return;dispatch_async(s.queue,^{if(peer.finished)return;if(failure)[s close:peer];else [s sendFileChunk:peer];});});
}
- (void)send:(NSDictionary *)response peer:(DXRemotePeer *)peer head:(BOOL)head{
 if(peer.finished)return;
 NSData *body=response[@"body"]?:NSData.data;unsigned long long length=body.length;
 NSString *filePath=response[@"filePath"];
 if(filePath){int fd=open(filePath.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);struct stat st;if(fd<0||fstat(fd,&st)!=0||!S_ISREG(st.st_mode)||st.st_size<0){if(fd>=0)close(fd);[self send:DXRemoteResponse(404,@{@"error":@"文件已不存在或暂不可读取"}) peer:peer head:head];return;}peer.file=[[NSFileHandle alloc]initWithFileDescriptor:fd closeOnDealloc:YES];length=(unsigned long long)st.st_size;peer.remaining=length;}
 peer.responding=YES;[self armSendTimeout:peer];
 NSMutableString *headers=[NSMutableString stringWithFormat:@"HTTP/1.1 %ld Response\r\nContent-Type: %@\r\nContent-Length: %llu\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\nPermissions-Policy: camera=(), microphone=(), geolocation=()\r\nContent-Security-Policy: default-src 'none'; script-src 'self' 'unsafe-eval'; worker-src 'self' blob:; font-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'\r\n",(long)[response[@"status"] integerValue],response[@"type"]?:@"application/octet-stream",length];
 for(NSString *name in response[@"headers"])[headers appendFormat:@"%@: %@\r\n",name,response[@"headers"][name]];
 [headers appendString:@"\r\n"];NSMutableData *data=[[headers dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];if(!head&&!filePath)[data appendData:body];
 dispatch_data_t payload=dispatch_data_create(data.bytes,data.length,self.queue,^{(void)data.length;});__weak typeof(self) weak=self;
 nw_connection_send(peer.connection,payload,NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,true,^(nw_error_t error){DXRemoteHTTP *s=weak;if(!s)return;dispatch_async(s.queue,^{if(peer.finished)return;if(error||head||!filePath)[s close:peer];else [s sendFileChunk:peer];});});
}
- (void)stop{
 self.generation++;if(self.listener){nw_listener_set_new_connection_handler(self.listener,nil);nw_listener_set_state_changed_handler(self.listener,nil);nw_listener_cancel(self.listener);self.listener=nil;}
 for(DXRemotePeer *peer in self.peers.copy)[self close:peer];
}
@end

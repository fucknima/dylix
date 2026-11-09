// Dylix local STDIO MCP, independently implemented against the MCP JSON-RPC spec.
#import "TFAIISHMCPTransport.h"
#import "TFAIISHRuntime.h"
static NSError *WireError(NSString *s){return [NSError errorWithDomain:@"Dylix.LocalMCP" code:1 userInfo:@{NSLocalizedDescriptionKey:s}];}
@interface TFAIISHMCPTransport ()
@property NSString *handle,*session;
@property NSMutableArray *queue;
@property NSMutableData *buffer;
@property NSDictionary *active;
@property NSUInteger generation,received;
@end
@implementation TFAIISHMCPTransport
- (instancetype)init{if((self=[super init])){_queue=[NSMutableArray new];_buffer=[NSMutableData new];}return self;}
- (BOOL)ready{return self.handle.length>0&&[TFAIISHRuntime.shared isStdioRunning:self.handle session:self.session];}
- (void)start:(NSString *)command arguments:(NSArray *)args session:(NSString *)session completion:(void(^)(NSError *))completion{[self start:command arguments:args environment:@{} session:session completion:completion];}
- (void)start:(NSString *)command arguments:(NSArray *)args environment:(NSDictionary *)environment session:(NSString *)session completion:(void(^)(NSError *))completion{
 [self close];self.session=session;NSUInteger gen=self.generation;[TFAIISHRuntime.shared openStdio:command arguments:args environment:environment session:session completion:^(NSString *handle,NSError *e){if(gen!=self.generation){if(handle)[TFAIISHRuntime.shared closeStdio:handle session:session];completion(WireError(@"本地 MCP 启动已取消"));return;}self.handle=handle;completion(e);}];
}
- (void)request:(NSDictionary *)body completion:(void(^)(NSDictionary *,NSError *))completion{
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self request:body completion:completion];});return;}
 if(!self.ready||self.queue.count>=16){completion(nil,WireError(@"本地 MCP 未启动或请求队列已满，请重新发现"));return;}
 [self.queue addObject:@{@"body":body,@"completion":[completion copy]}];[self next];
}
- (void)next{
 if(self.active||!self.queue.count)return;self.active=self.queue.firstObject;[self.queue removeObjectAtIndex:0];self.received=0;NSUInteger gen=++self.generation;NSDictionary *body=self.active[@"body"];NSMutableData *data=[[NSJSONSerialization dataWithJSONObject:body options:0 error:nil] mutableCopy];if(!data){[self finish:nil error:WireError(@"MCP 请求编码失败")];return;}[data appendBytes:"\n" length:1];
 [TFAIISHRuntime.shared stdio:self.handle input:data session:self.session completion:^(NSDictionary *r,NSError *e){if(gen!=self.generation)return;if(e){[self fail:e];return;}[self consume:r generation:gen];}];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(gen==self.generation&&self.active)[self fail:WireError(@"本地 MCP 30 秒内未返回匹配响应，已关闭管道；请重新发现")];});
}
- (void)consume:(NSDictionary *)value generation:(NSUInteger)gen{
 if(gen!=self.generation||!self.active)return;NSData *data=value[@"stdout"];self.received+=data.length;if([value[@"overflow"] boolValue]||self.received>8*1024*1024){[self fail:WireError(@"本地 MCP 响应超过 8 MiB，已停止服务")];return;}[self.buffer appendData:data];
 while(self.active){const uint8_t *bytes=self.buffer.bytes;const uint8_t *end=memchr(bytes,'\n',self.buffer.length);if(!end)break;NSUInteger length=end-bytes;NSData *line=[self.buffer subdataWithRange:NSMakeRange(0,length)];[self.buffer replaceBytesInRange:NSMakeRange(0,length+1) withBytes:NULL length:0];if(!line.length)continue;id json=[NSJSONSerialization JSONObjectWithData:line options:0 error:nil];if(![json isKindOfClass:NSDictionary.class]||![json[@"jsonrpc"] isEqual:@"2.0"]){[self fail:WireError(@"本地 MCP stdout 含非 JSON-RPC 内容；日志应写入 stderr")];return;}
  if(json[@"method"]){if(json[@"id"]){NSDictionary *reply=@{@"jsonrpc":@"2.0",@"id":json[@"id"],@"error":@{@"code":@(-32601),@"message":@"Client requests are disabled"}};NSMutableData *d=[[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil] mutableCopy];[d appendBytes:"\n" length:1];[TFAIISHRuntime.shared stdio:self.handle input:d session:self.session completion:^(NSDictionary *r,NSError *e){}];}continue;}
  if(![json[@"id"] isEqual:self.active[@"body"][@"id"]])continue;
  if(json[@"error"]||![json[@"result"] isKindOfClass:NSDictionary.class]){[self finish:nil error:WireError(@"本地 MCP 拒绝调用或响应格式无效")];return;}[self finish:json[@"result"] error:nil];return;
 }
 if(!self.active[@"body"][@"id"]){[self finish:@{} error:nil];return;}
 if(![value[@"running"] boolValue]){[self fail:WireError(@"本地 MCP 进程已退出，未返回匹配响应；请检查命令和安装依赖")];return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(gen!=self.generation||!self.active)return;[TFAIISHRuntime.shared stdio:self.handle input:nil session:self.session completion:^(NSDictionary *r,NSError *e){if(gen!=self.generation)return;if(e)[self fail:e];else[self consume:r generation:gen];}];});
}
- (void)finish:(NSDictionary *)result error:(NSError *)error{void(^done)(NSDictionary *,NSError *)=self.active[@"completion"];self.active=nil;self.generation++;if(done)done(result,error);[self next];}
- (void)fail:(NSError *)error{[self closeWithError:error];}
- (void)closeWithError:(NSError *)error{
 self.generation++;NSString *handle=self.handle;self.handle=nil;if(handle)[TFAIISHRuntime.shared closeStdio:handle session:self.session];NSMutableArray *pending=[self.queue mutableCopy];if(self.active)[pending insertObject:self.active atIndex:0];self.active=nil;[self.queue removeAllObjects];[self.buffer setLength:0];for(NSDictionary *row in pending){void(^cb)(NSDictionary *,NSError *)=row[@"completion"];cb(nil,error);}
}
- (void)close{[self closeWithError:WireError(@"本地 MCP 已关闭或配置已变更")];}
@end

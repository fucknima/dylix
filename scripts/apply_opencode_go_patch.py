#!/usr/bin/env python3
"""Re-apply the OpenCode Go integration on top of upstream Dylix sources.

Idempotent: markers already present are left untouched. Exits non-zero when an
upstream anchor moved, so the sync workflow stops instead of guessing.
"""
from __future__ import annotations
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name: str) -> str:
    return (ROOT / name).read_text(encoding='utf-8')


def save(name: str, data: str) -> None:
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data, encoding='utf-8')
    print('patched:', name)


def replace_once(data: str, old: str, new: str, filename: str) -> str:
    count = data.count(old)
    if count != 1:
        raise RuntimeError(f'{filename}: 上游代码锚点预期出现 1 次，实际出现 {count} 次，已停止以免改错。\n锚点：{old[:180]}')
    return data.replace(old, new, 1)


def patch_providers() -> None:
    name = 'Resources/AIProviders/Providers.json'
    catalog = json.loads(load(name))
    providers = catalog['providers']
    ids = [p.get('id') for p in providers]
    if 'opencode-go' in ids:
        return
    entry = {
        'id': 'opencode-go', 'name': 'OpenCode Go',
        'baseURL': 'https://opencode.ai/inference/go/openai/v1',
        'description': 'OpenCode Go 订阅服务；同一对话自动携带稳定的 x-opencode-session（需自己的 Go API Key）',
        'wireProtocol': 'chat', 'auth': ['apiKey'],
        'capabilities': {'text': 'unknown', 'stream': 'unknown', 'image': 'unknown', 'tools': 'unknown', 'thinking': 'unknown'},
        'modelsURL': 'https://opencode.ai/inference/go/v1/models',
    }
    at = ids.index('custom') if 'custom' in ids else len(providers)
    providers.insert(at, entry)
    save(name, json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')


def patch_protocol() -> None:
    name = 'App/AI/Providers/TFAIProtocol.m'
    s = load(name)
    if 'if(models&&[original isEqual:@"opencode-go"]' in s:
        return
    old = ' u.path=[p stringByAppendingString:models?@"/models":[protocol isEqual:@"responses"]?@"/responses":[protocol isEqual:@"anthropic"]?@"/messages":@"/chat/completions"];return u.URL;'
    new = (' // OpenCode Go publishes its model catalog at a separate, official HTTPS path.\n'
           ' if(models&&[original isEqual:@"opencode-go"]&&[u.host.lowercaseString isEqualToString:@"opencode.ai"]){u.path=@"/inference/go/v1/models";return u.URL;}\n' + old)
    save(name, replace_once(s, old, new, name))


def patch_runtime() -> None:
    name = 'App/AI/Core/AIRuntime.m'
    s = load(name)
    if 'goConnection[@"goSessionID"]' in s:
        return
    old = ' [self.transport send:projected connection:self.connection tools:schemas event:^(NSDictionary *event){'
    new = (' // OpenCode Go: preserve the same UUID across tool calls and follow-up rounds.\n'
           ' NSDictionary *transportConnection=self.connection;\n'
           ' if([self.connection[@"protocol"] isEqualToString:@"opencode-go"]){NSMutableDictionary *goConnection=[self.connection mutableCopy];goConnection[@"goSessionID"]=self.sessionID?:@"";transportConnection=goConnection;}\n'
           ' [self.transport send:projected connection:transportConnection tools:schemas event:^(NSDictionary *event){')
    save(name, replace_once(s, old, new, name))


def patch_transport() -> None:
    name = 'App/AI/Transport/TFAITransport.m'
    s = load(name)
    if '@property NSString *goRequestSessionID;' in s:
        return
    s = replace_once(s, '@property NSString *mode;', '@property NSString *mode;\n@property NSString *goRequestSessionID;', name)
    s = replace_once(s, 'self.connection=[connection copy];self.requestHeaders=nil;',
                     'self.connection=[connection copy];self.requestHeaders=nil;self.goRequestSessionID=NSUUID.UUID.UUIDString;', name)
    old = ' if(userAgent.length)[request setValue:userAgent forHTTPHeaderField:@"User-Agent"];'
    new = (' if(userAgent.length)[request setValue:userAgent forHTTPHeaderField:@"User-Agent"];\n'
           ' else if([connection[@"protocol"] isEqualToString:@"opencode-go"])[request setValue:@"Dylix-Go/1.0" forHTTPHeaderField:@"User-Agent"];')
    s = replace_once(s, old, new, name)
    helper = ('- (void)applyGoSessionHeader:(NSMutableURLRequest *)request connection:(NSDictionary *)connection{'
              'NSString *value=[connection[@"goSessionID"] isKindOfClass:NSString.class]?connection[@"goSessionID"]:@"";'
              'NSUUID *valid=[[NSUUID alloc]initWithUUIDString:value];'
              '[request setValue:valid?valid.UUIDString:(self.goRequestSessionID?:NSUUID.UUID.UUIDString) forHTTPHeaderField:@"x-opencode-session"];}\n')
    s = replace_once(s, '- (void)start:(NSDictionary *)connection messages:', helper + '- (void)start:(NSDictionary *)connection messages:', name)
    old = ' for(NSString *name in self.requestHeaders)[request setValue:self.requestHeaders[name] forHTTPHeaderField:name];'
    new = (old + '\n'
           ' // OpenCode Go requires a stable per-conversation session header; user headers must not drop it.\n'
           ' if([connection[@"protocol"] isEqualToString:@"opencode-go"]){[self applyGoSessionHeader:request connection:connection];}')
    s = replace_once(s, old, new, name)
    old = 'for(NSString *name in self.requestHeaders)[redirect setValue:self.requestHeaders[name] forHTTPHeaderField:name];completionHandler(redirect);}'
    new = ('for(NSString *name in self.requestHeaders)[redirect setValue:self.requestHeaders[name] forHTTPHeaderField:name];'
           'if([self.connection[@"protocol"] isEqualToString:@"opencode-go"]){[self applyGoSessionHeader:redirect connection:self.connection];}completionHandler(redirect);}')
    save(name, replace_once(s, old, new, name))


def patch_settings() -> None:
    name = 'App/AI/UI/TFAISettings.m'
    s = load(name)
    if '([entry[@"id"] isEqualToString:@"opencode-go"]?@"glm-5.3-flash":@"")' in s:
        return
    old = '@"model":@"",@"models":@[],@"authMethod":@"apiKey"'
    new = '@"model":([entry[@"id"] isEqualToString:@"opencode-go"]?@"glm-5.3-flash":@""),@"models":@[],@"authMethod":@"apiKey"'
    save(name, replace_once(s, old, new, name))


def patch_readme() -> None:
    name = 'README.md'
    s = load(name)
    if '## OpenCode Go（独立 Fork 增强）' in s:
        return
    appendix = '''\n\n## OpenCode Go（独立 Fork 增强）\n\n进入「AI 模型与连接」→「添加服务商」→「OpenCode Go」，填入从 OpenCode Console 获取的 Go API Key；默认模型为 `glm-5.3-flash`，也可获取实时模型列表重新选择。\n\n正式对话、工具续轮与同源重定向均携带稳定的 `x-opencode-session`（使用本地会话 UUID）；模型发现和能力测试使用临时 UUID。默认 `User-Agent` 为 `Dylix-Go/1.0`，与上游自定义请求头功能共存，且会话头在自定义头之后写入，不会被覆盖。API Key 仍按原版机制保存在 iOS 钥匙串。\n\n官方接口：`https://opencode.ai/inference/go/openai/v1/chat/completions`；模型列表：`https://opencode.ai/inference/go/v1/models`。OpenCode Go 主要服务于代码 Agent 场景，模型和能力按服务商当前政策、订阅权限和实际测试结果决定。\n\n本 Fork 在 `.github/workflows/` 增加构建及上游同步：同步成功时自动触发新的无个人证书 IPA 编译；存在合并冲突时停止而非强制覆盖。构建生成的 `Dylix-Go-unsigned.ipa` 是需后续自行签名的安装包，不是已用个人开发者证书签署的包。\n'''
    save(name, s.rstrip() + '\n' + appendix)


def main() -> int:
    if not (ROOT / 'App/AI/Core/AIRuntime.m').is_file():
        print(f'{ROOT} 不是 Dylix 源码根目录', file=sys.stderr)
        return 2
    try:
        patch_providers()
        patch_protocol()
        patch_runtime()
        patch_transport()
        patch_settings()
        patch_readme()
    except (RuntimeError, json.JSONDecodeError) as exc:
        print('补丁失败：', exc, file=sys.stderr)
        return 1
    print('OpenCode Go 补丁已就绪')
    return 0


if __name__ == '__main__':
    sys.exit(main())

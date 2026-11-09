#!/usr/bin/env python3
"""Offline regression guards for provider configuration, URL routing and session headers.

These are static integration gates, not a live API test and not an iOS compiler.
"""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
catalog=json.loads((root/'Resources/AIProviders/Providers.json').read_text())
assert catalog.get('schemaVersion')==1, 'provider catalog schemaVersion must stay 1'
providers=catalog['providers']
go=[x for x in providers if x.get('id')=='opencode-go']
assert len(go)==1, 'missing/duplicate OpenCode Go provider'
c=go[0]
assert c['wireProtocol']=='chat' and c['baseURL']=='https://opencode.ai/inference/go/openai/v1'
assert c['modelsURL']=='https://opencode.ai/inference/go/v1/models'
assert c['auth']==['apiKey']
proto=(root/'App/AI/Providers/TFAIProtocol.m').read_text()
transport=(root/'App/AI/Transport/TFAITransport.m').read_text()
runtime=(root/'App/AI/Core/AIRuntime.m').read_text()
ui=(root/'App/AI/UI/TFAISettings.m').read_text()
assert 'if(models&&[original isEqual:@"opencode-go"]' in proto
assert '@"/inference/go/v1/models"' in proto
# upstream Build225 custom headers must survive the merge
assert 'TFAIValidatedCustomHeaders' in proto and 'customHeaders' in transport
assert 'self.requestHeaders=nil;' in transport
assert '@property NSString *goRequestSessionID;' in transport
assert 'self.requestHeaders=nil;self.goRequestSessionID=NSUUID.UUID.UUIDString;' in transport
assert 'applyGoSessionHeader' in transport and transport.count('applyGoSessionHeader')==3
assert 'for(NSString *name in self.requestHeaders)[request setValue:self.requestHeaders[name] forHTTPHeaderField:name];' in transport
assert 'connection[@"goSessionID"]' in transport
assert 'forHTTPHeaderField:@"x-opencode-session"' in transport
assert 'self.goRequestSessionID?:NSUUID.UUID.UUIDString' in transport, 'header value must never be nil'
assert 'else if([connection[@"protocol"] isEqualToString:@"opencode-go"])[request setValue:@"Dylix-Go/1.0"' in transport
assert 'goConnection[@"goSessionID"]=self.sessionID' in runtime
assert 'connection:transportConnection tools:schemas' in runtime
assert '[entry[@"id"] isEqualToString:@"opencode-go"]?@"glm-5.3-flash"' in ui
assert (root/'.github/workflows/build-ipa.yml').is_file()
assert (root/'.github/workflows/sync-upstream.yml').is_file()
build=(root/'.github/workflows/build-ipa.yml').read_text()
assert 'DYLIX_SDK_26_0' in build and 'LocalSDKs/iPhoneOS26.0.sdk' in build
print('OpenCode Go static integration checks: OK')

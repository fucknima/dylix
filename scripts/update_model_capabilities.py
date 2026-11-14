#!/usr/bin/env python3
"""Create a small, deterministic capability snapshot from models.dev registry data.

Usage: update_model_capabilities.py /path/to/models-dev-api.json
Only bounded model declarations are copied. No code, pricing, credentials, URLs
from arbitrary entries, or response prose enters the application resource.
"""
import collections, hashlib, json, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
HOSTS = {
 'openai':['api.openai.com'], 'anthropic':['api.anthropic.com'],
 'google':['generativelanguage.googleapis.com'], 'deepseek':['api.deepseek.com'],
 'siliconflow':['api.siliconflow.cn','api.siliconflow.com'],
 'alibaba':['dashscope.aliyuncs.com','dashscope-intl.aliyuncs.com'],
 'zhipuai':['open.bigmodel.cn','api.z.ai'], 'moonshotai':['api.moonshot.cn','api.moonshot.ai'],
 'xai':['api.x.ai'], 'openrouter':['openrouter.ai'], 'cerebras':['api.cerebras.ai'],
 'groq':['api.groq.com'], 'mistral':['api.mistral.ai'],
}
LEVELS = ['none','minimal','low','medium','high','xhigh','ultra','max','enabled']
def key(name):
 return re.sub(r'[._ ]','-',name.rsplit('/',1)[-1].strip().lower())
def row(model):
 caps={}; modalities=model.get('modalities',{}); inputs=modalities.get('input') if isinstance(modalities,dict) else None
 if isinstance(inputs,list):
  for k in ('text','image'):caps[k]='supported' if k in inputs else 'unsupported'
 for source,k in [('tool_call','tools'),('reasoning','thinking')]:
  if type(model.get(source)) is bool:caps[k]='supported' if model[source] else 'unsupported'
 out={'capabilities':caps}
 options=model.get('reasoning_options')
 if isinstance(options,list):
  tiers=set()
  for opt in options:
   if isinstance(opt,dict) and opt.get('type')=='effort' and isinstance(opt.get('values'),list):tiers.update(x for x in opt['values'] if x in LEVELS)
  if tiers:out['efforts']=[x for x in LEVELS if x in tiers];out['reasoningControl']='effort'
  elif any(isinstance(x,dict) and x.get('type')=='toggle' for x in options):out['reasoningControl']='toggle'
  elif any(isinstance(x,dict) and x.get('type')=='budget_tokens' for x in options):out['reasoningControl']='budget'
  elif caps.get('thinking')=='supported':out['reasoningControl']='fixed'
 return out
if __name__=='__main__':
 source=Path(sys.argv[1]);raw=source.read_bytes();registry=json.loads(raw);providers=[];all_rows=collections.defaultdict(list)
 for provider in sorted(registry):
  p=registry[provider]
  if not isinstance(p,dict) or not isinstance(p.get('models'),dict):continue
  models={}
  for name in sorted(p['models']):
   model=p['models'][name]
   if not isinstance(model,dict) or not isinstance(name,str) or len(name)>255:continue
   r=row(model);normalized=key(name)
   if not normalized or not r['capabilities']:continue
   models.setdefault(normalized,r);all_rows[normalized].append((provider,r))
  if provider in HOSTS:providers.append({'id':provider,'hosts':HOSTS[provider],'models':models})
 fallback={}
 for name,candidates in sorted(all_rows.items()):
  # Cross-provider matches are hints. Never borrow a negative flag from another endpoint.
  caps={k:'supported' for k in ('text','image','tools','thinking') if any(r['capabilities'].get(k)=='supported' for _,r in candidates)}
  r={'capabilities':caps};efforts=[(p,v['efforts']) for p,v in candidates if v.get('efforts')]
  if efforts:
   votes=collections.Counter(tuple(v) for _,v in efforts);winner=sorted(votes,key=lambda x:(-votes[x],x))[0];r['efforts']=list(winner);r['reasoningControl']='effort'
  if caps:fallback[name]=r
 result={'schemaVersion':1,'source':'models.dev registry snapshot via OpenMinis/OpenMinis@1a71df0f381cefde80bf912b723de6f9831bc177','sourceSHA256':hashlib.sha256(raw).hexdigest(),'providers':providers,'fallback':fallback}
 target=ROOT/'Resources/AIProviders/ModelCapabilities.json';target.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
 print(f'{len(providers)} endpoint catalogs; {len(fallback)} normalized hints; {target.stat().st_size} bytes')

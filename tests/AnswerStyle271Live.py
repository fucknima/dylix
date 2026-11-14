import os,json,pathlib,urllib.request,concurrent.futures,time,re,ast,statistics
out=pathlib.Path(os.environ.get('DYLIX_STYLE_OUT','/tmp/dylix271-style-live'));out.mkdir(exist_ok=True)
port=json.load(open('/tmp/dylix270-live-gateway.json'))['port']
questions={
 'exact':'0x10 转成十进制是多少？只回答数字，不要其它内容。',
 'json':'只输出一个 JSON 对象，且只包含这三个字段：budgetKiB 为整数 256，isModelTokenLimit 为 false，unit 为 "KiB"。不要 Markdown，不要解释。',
 'explain':'解释 Dylix 的历史上下文压缩、原文回读和上下文保护大小分别是什么，它们有什么关系？是不是保护值越小越省钱？',
 'code':'只输出一个 Python 代码块，不要解释。实现 clamp_budget_kib(value)：只接受 type(value) is int 且 64 <= value <= 16384，返回原值；其他输入统一抛 ValueError。不要导入模块，不要执行示例，不要额外函数。'
}
def judge(task,text):
 checks={}
 if task=='exact':checks['exact_user_format']=text.strip()=='16'
 elif task=='json':
  try:checks['exact_json_schema']=json.loads(text)=={'budgetKiB':256,'isModelTokenLimit':False,'unit':'KiB'}
  except Exception:checks['exact_json_schema']=False
 elif task=='explain':
  checks['mentions_archive_recovery']=any(x in text for x in ['原文','原始','保留','归档']) and any(x in text for x in ['回读','取回','恢复'])
  checks['distinguishes_units']='token' in text.lower() and any(x in text.lower() for x in ['kib','字节'])
  checks['not_always_cheaper']=any(x in text for x in ['不一定','并不','未必','不代表','不等于','不是越小','不必然','不一定越小'])
  checks['no_unsupported_zero_loop_claim']=not re.search(r'(循环概率[为是]?[零0]|保证.*不.*循环|彻底杜绝.*循环)',text)
 else:
  matches=re.findall(r'```(?:python)?\s*\n(.*?)```',text,re.S);checks['code_only']=len(matches)==1 and not re.sub(r'```(?:python)?\s*\n.*?```','',text,flags=re.S).strip()
  try:
   tree=ast.parse(matches[0]);assert len(tree.body)==1 and isinstance(tree.body[0],ast.FunctionDef)
   assert not any(isinstance(n,(ast.Import,ast.ImportFrom,ast.Attribute,ast.Global,ast.Nonlocal)) for n in ast.walk(tree))
   safe={'ValueError':ValueError,'type':type,'int':int,'bool':bool,'isinstance':isinstance};scope={};exec(compile(tree,'<model-test>','exec'),{'__builtins__':safe},scope);fn=scope['clamp_budget_kib']
   checks['valid_boundaries']=all(fn(n)==n for n in [64,65,256,16384])
   ok=True
   for value in [True,False,63,16385,'256',256.0,None,float('nan'),[],{}]:
    try:fn(value);ok=False
    except ValueError:pass
    except Exception:ok=False
   checks['invalid_types_and_range']=ok
  except Exception:checks['valid_boundaries']=False;checks['invalid_types_and_range']=False
 return checks
def trial(job):
 model,style,task,variant=job;captured=json.load(open('/tmp/dylix271-style-'+variant+'.json'));messages=captured[style]+[{'role':'user','content':questions[task]}];payload={'model':model,'messages':messages,'max_tokens':1200,'stream':False};start=time.monotonic()
 try:
  r=json.load(urllib.request.urlopen(urllib.request.Request(f'http://127.0.0.1:{port}/chat',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'}),timeout=120));body=r['response'];text=body.get('choices',[{}])[0].get('message',{}).get('content') or '';status=r['http_status'];checks=judge(task,text) if status==200 else {}
 except Exception as e:body={};text='';status=0;checks={}
 result={'model':model,'style':style,'task':task,'variant':variant,'http_status':status,'usage':body.get('usage',{}),'response_model':body.get('model'),'finish_reason':body.get('choices',[{}])[0].get('finish_reason'),'elapsed_seconds':time.monotonic()-start,'characters':len(text),'checks':checks,'passed':status==200 and all(checks.values()) and bool(checks),'answer':text};(out/f'{model}-{style}-{task}-{variant}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps({k:result[k] for k in ['model','style','task','variant','http_status','passed','characters']},ensure_ascii=False),flush=True);return result
if __name__=='__main__':
 jobs=[(model,style,task,v) for model in ['gpt-5.6-sol','gpt-6-sol','gpt-6.1-sol'] for style in ['concise','standard','detailed'] for task in questions for v in ['baseline','new']]
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(trial,jobs))

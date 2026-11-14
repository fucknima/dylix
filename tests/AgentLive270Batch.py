import os,json,pathlib,subprocess,hashlib,concurrent.futures,time,sys
out=pathlib.Path(os.environ.get('DYLIX_LIVE_OUT','/tmp/dylix270-live-results'));out.mkdir(exist_ok=True)
def sha(s):return hashlib.sha256(s.encode()).hexdigest()
def trial(model,scenario,seed,variant):
 tag=f'{model}-{scenario}-{seed}-{variant}';folder=out/tag;folder.mkdir(exist_ok=True)
 old=100+seed;new=900+seed
 lines=[f'int filler_{i}(void) {{ return {i}; }}' for i in range(740)]
 index=seed*13+430;lines[index]=f'int target_{seed}(void) {{ return {old}; }}';historical='\n'.join(lines)+'\n';actual=historical
 if scenario=='stale':actual=historical.replace(f'return {old}; }}\n',f'return {old}; }}\n',1).replace(f'int target_{seed}(void) {{ return {old}; }}',f'int target_{seed}(void) {{ return {old+3}; }}')
 expected=actual.replace(f'int target_{seed}(void) {{ return {old+3 if scenario=="stale" else old}; }}',f'int target_{seed}(void) {{ return {new}; }}')
 file=folder/'Main.m';file.write_text(actual)
 user=f'In Main.m change only function target_{seed} to return {new}. Use the available source evidence, propose and apply the exact change, then run read_diagnostics and report its real result. Do not change unrelated code. This disposable project is authorized for editing.'
 messages=[{'role':'user','content':user}]
 def add(cid,start,body):
  messages.extend([{'role':'assistant','content':'','tool_calls':[{'id':cid,'name':'read_file','arguments':{'path':'Main.m','start_line':start}}]},{'role':'tool','tool_call_id':cid,'content':json.dumps({'path':'Main.m','start_line':start,'sha256':sha(historical),'content':body},ensure_ascii=False)}])
 if scenario=='overlap':
  add('seed-first',1,'\n'.join(lines[:500])+'\n');add('seed-second',400,'\n'.join(lines[399:])+'\n')
 else:add('seed-source',1,historical)
 if scenario=='stale':messages.append({'role':'user','content':'The file was changed externally after that historical read. Check the current target before proposing; the requested final value remains unchanged.'})
 config={'file':str(file),'expected':expected,'model':model,'scenario':scenario,'seed':seed,'variant':variant,'messages':messages,'report':str(folder/'result.json')};path=folder/'config.json';path.write_text(json.dumps(config));start=time.monotonic()
 with open(folder/'runner.log','w') as f:
  try:r=subprocess.run([os.environ.get('DYLIX_LIVE_BINARY_PREFIX','/tmp/dylix270-live-')+variant],env={**os.environ,'DYLIX_LIVE_CONFIG':str(path)},stdout=f,stderr=f,timeout=950);code=r.returncode
  except subprocess.TimeoutExpired:code=124
 if (folder/'result.json').exists():result=json.load(open(folder/'result.json'))
 else:result={'model':model,'scenario':scenario,'seed':seed,'variant':variant,'state':'runner_failure','requests':[]}
 result['runner_exit']=code;result['wall_seconds']=time.monotonic()-start;result['passed']=code==0 and result.get('actual_file_correct',False) and result.get('model_ran_acceptance_tests',False) and result.get('state')=='completed';(folder/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps({k:result.get(k) for k in ['model','scenario','seed','variant','state','passed','wall_seconds']},ensure_ascii=False),flush=True);return result
if __name__=='__main__':
 models=sys.argv[1].split(',');seeds=int(sys.argv[2]);jobs=[(m,s,n,v) for m in models for n in range(seeds) for s in ['recent_large','overlap','stale'] for v in (['baseline','new'] if n%2==0 else ['new','baseline'])]
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(lambda x:trial(*x),jobs))

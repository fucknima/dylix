#!/usr/bin/env python3
"""Fail closed if a public export contains private client/server code or credentials."""
from pathlib import Path
import argparse,re,sys,json
p=argparse.ArgumentParser();p.add_argument('--binary',type=Path);a=p.parse_args();root=Path(__file__).resolve().parents[1]
forbidden=[b'TFAIPromptHub',b'dylixPromptHub',b'Dylix.PromptHub',b'dylix_hub',b'/hub/api/v1',b'dylib.cn/hub',b'dylix.cn/hub',b'hubContentHash',b'persona-prompt-hub',b'StudioFeedbackEndpoint']
secret=re.compile(rb'(github_pat_[A-Za-z0-9_]{30,}|ghp_[A-Za-z0-9]{30,}|-----BEGIN (?:RSA |EC )?PRIVATE KEY-----)')
violations=[];checked=0
paths=[a.binary.resolve()] if a.binary else root.rglob('*')
for path in paths:
 if not path.is_file() or any(x in path.relative_to(root).parts for x in ('.git','build','__pycache__','.theos','target')) and not a.binary:continue
 if path.resolve()==Path(__file__).resolve():continue
 if path.is_symlink():continue
 data=path.read_bytes();checked+=1
 if any(x in data for x in forbidden) or secret.search(data):violations.append(str(path.relative_to(root)))
 if not a.binary and (path.suffix in ('.p12','.pfx','.mobileprovision') or 'prompt-hub' in str(path.relative_to(root)).lower()):violations.append(str(path.relative_to(root)))
print(json.dumps({'passed':not violations,'checkedFiles':checked,'violatingFiles':sorted(set(violations))},ensure_ascii=False,indent=2))
sys.exit(bool(violations))

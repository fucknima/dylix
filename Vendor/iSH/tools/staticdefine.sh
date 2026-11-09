#!/usr/bin/env python3
# Dylix patch: preserve argv quoting for SDK/project paths with spaces or Unicode.
import json, pathlib, re, shlex, subprocess, sys
commands, source, output, dep = sys.argv[1:]
items = json.loads(pathlib.Path(commands).read_text())
entry = next(x for x in items if x['file'].endswith('asbestos/asbestos.c'))
args = entry.get('arguments') or shlex.split(entry['command'])
clean = []
i = 0
while i < len(args):
    if args[i] in ('-o', '-MF', '-MQ', '-MT'):
        i += 2
    elif args[i] in ('-c', '-MD', '-MMD'):
        i += 1
    elif args[i].endswith('asbestos/asbestos.c'):
        i += 1
    else:
        clean.append(args[i]); i += 1
result = subprocess.run(clean + ['-MD', '-MQ', output, '-MF', dep, source, '-include', str(pathlib.Path(__file__).with_name('staticdefine.h')), '-S', '-o', '-'], cwd=entry['directory'], check=True, stdout=subprocess.PIPE, text=True)
lines = []
for line in result.stdout.splitlines():
    m = re.search(r'\.ascii\s+"(->.*?)"', line)
    if not m: continue
    text = m.group(1)
    if text.startswith('->#'): lines.append('/* ' + text[3:] + ' */')
    else:
        m = re.match(r'->(\S+) [#$]*(\S+) (.*)', text)
        if m: lines.append('#define %s %s /* %s */' % m.groups())
pathlib.Path(output).write_text('\n'.join(lines) + '\n')

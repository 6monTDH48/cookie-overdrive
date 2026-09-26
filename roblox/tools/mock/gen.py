#!/usr/bin/env python3
"""Generates out/api.luau (classes/enums from globalTypes.d.luau) and out/bundle.luau (Rojo tree + sources)."""
import json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROBLOX = os.path.normpath(os.path.join(HERE, '..', '..'))
DEFS = '/home/user/tools/globalTypes.d.luau'
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)

def lq(s):
    n = 0
    while (']' + '=' * n + ']') in s: n += 1
    return '[' + '=' * n + '[' + s + ']' + '=' * n + ']'

# ---------- API
txt = open(DEFS, encoding='utf-8').read()
classes, enums = {}, {}
cur = None
for line in txt.split('\n'):
    m = re.match(r'declare extern type (\w+) extends (\w+) with', line) or re.match(r'declare extern type (\w+) with', line)
    if m:
        name = m.group(1); sup = m.group(2) if m.lastindex and m.lastindex >= 2 else None
        cur = {'super': sup, 'props': {}, 'methods': {}, 'events': {}}
        classes[name] = cur
        continue
    if line.startswith('end'):
        cur = None; continue
    if cur is None: continue
    s = line.strip()
    m = re.match(r'function (\w+)\(', s)
    if m: cur['methods'][m.group(1)] = True; continue
    m = re.match(r'(\w+): (.+)$', s)
    if m:
        k, t = m.group(1), m.group(2).strip()
        if t.startswith('RBXScriptSignal'): cur['events'][k] = True
        else: cur['props'][k] = t
for name, c in list(classes.items()):
    if name.startswith('Enum') and name.endswith('_INTERNAL'):
        en = name[4:-9]
        enums[en] = [k for k, t in c['props'].items()]
def isinst(n):
    seen = 0
    while n and seen < 50:
        if n == 'Instance': return True
        n = classes.get(n, {}).get('super'); seen += 1
    return False
out = ['return {classes = {']
for name, c in classes.items():
    if not (isinst(name) or name == 'Object'): continue
    props = ', '.join('[%s]=%s' % (json.dumps(k), json.dumps(v)) for k, v in c['props'].items())
    meth = ', '.join('[%s]=true' % json.dumps(k) for k in c['methods'])
    ev = ', '.join('[%s]=true' % json.dumps(k) for k in c['events'])
    out.append('[%s]={super=%s, props={%s}, methods={%s}, events={%s}},' % (json.dumps(name), json.dumps(c['super']) if c['super'] else 'nil', props, meth, ev))
out.append('}, enums = {')
for en, items in enums.items():
    out.append('[%s]={%s},' % (json.dumps(en), ', '.join(json.dumps(i) for i in items)))
meta = json.loads(txt.split('\n', 1)[0][len('--#METADATA#'):])
out.append('}, creatable = {%s}, services = {%s}}' % (', '.join('[%s]=true' % json.dumps(x) for x in meta['CREATABLE_INSTANCES']), ', '.join('[%s]=true' % json.dumps(x) for x in meta['SERVICES'])))
open(os.path.join(OUT, 'api.luau'), 'w', encoding='utf-8').write('\n'.join(out))

# ---------- bundle
proj = json.load(open(os.path.join(ROBLOX, 'default.project.json')))
def node_from_path(name, path):
    full = os.path.join(ROBLOX, path)
    if os.path.isdir(full):
        n = {'name': name, 'class': 'Folder', 'children': []}
        for f in sorted(os.listdir(full)):
            c = file_node(os.path.join(full, f), os.path.relpath(os.path.join(full, f), ROBLOX))
            if c: n['children'].append(c)
        return n
    return file_node(full, path)
def file_node(full, rel):
    base = os.path.basename(full)
    if os.path.isdir(full): return node_from_path(base, rel)
    for suf, cls in (('.server.lua', 'Script'), ('.client.lua', 'LocalScript'), ('.lua', 'ModuleScript'), ('.luau', 'ModuleScript')):
        if base.endswith(suf):
            n = {'name': base[:-len(suf)], 'class': cls, 'children': []}
            if '/ImageData/' in full.replace('\\', '/') and n['name'] != '_index':
                n['native'] = os.path.relpath(full[:-len(suf)], HERE)  # loaded lazily with the CLI require
            else:
                n['source'] = open(full, encoding='utf-8').read()
            return n
    return None
def walk(name, t):
    if '$path' in t:
        n = node_from_path(name, t['$path'])
    else:
        n = {'name': name, 'class': t.get('$className', name), 'children': []}
    n['props'] = t.get('$properties', {})
    for k, v in t.items():
        if not k.startswith('$'): n['children'].append(walk(k, v))
    return n
tree = walk('game', proj['tree'])
def emit(n):
    parts = ['{name=%s, class=%s' % (json.dumps(n['name']), json.dumps(n['class']))]
    if 'source' in n: parts.append('source=' + lq(n['source']))
    if 'native' in n: parts.append('native=%s' % json.dumps(n['native']))
    parts.append('children={' + ','.join(emit(c) for c in n['children']) + '}')
    return ', '.join(parts) + '}'
open(os.path.join(OUT, 'bundle.luau'), 'w', encoding='utf-8').write('return ' + emit(tree) + '\n')
print('gen ok: %d classes, %d enums' % (len(classes), len(enums)))

#!/usr/bin/env python3
"""Check tracked publication content without printing matched values."""
from pathlib import Path
import re,subprocess,sys
root=Path(__file__).resolve().parents[1]
files=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
errors=[]
for name in filter(None,files):
    p=Path(name)
    if any(x in p.parts for x in ['_devlog','.build','.runtime','.codex','dist','private-recovery']) or p.name.startswith('.env'):
        errors.append(name+': private/generated path');continue
    data=(root/p).read_bytes()
    if p.suffix.lower() in {'.png','.icns','.jpg','.zip'}:continue
    text=data.decode('utf-8',errors='replace')
    patterns=['/'+'Users/'+r'[^/\s]+/',r'gh[pousr]_[A-Za-z0-9]{30,}',r'github_pat_[A-Za-z0-9_]{30,}',r'AKIA[0-9A-Z]{16}',r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',r'\b[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}\b']
    if any(re.search(pattern,text) for pattern in patterns):errors.append(name+': private literal or credential-like pattern')
if errors:print('\n'.join(errors));sys.exit(1)
print(f'Publication check passed: {len(list(filter(None,files)))} tracked files; no matched private paths or credential patterns.')

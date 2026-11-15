#!/usr/bin/env python3
"""Package only approved public files. Works before or after committing."""
from pathlib import Path
import hashlib,zipfile
root=Path(__file__).resolve().parents[1]
version=(root/'VERSION').read_text().strip()
name=root.name.lower()
out=root/'dist';out.mkdir(exist_ok=True)
archive=out/f'{name}-{version}-source.zip'
allowed_dirs={'extension','tests','Sources','Tests','script','docs','.github'}
allowed_root={'README.md','LICENSE','CONTRIBUTING.md','SECURITY.md','Package.swift','VERSION','.gitignore','.dockerignore'}
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for file in sorted(root.rglob('*')):
        rel=file.relative_to(root)
        if not file.is_file() or file.is_symlink():continue
        if rel.parts[0] not in allowed_dirs and str(rel) not in allowed_root:continue
        if file.suffix in {'.pyc','.log'} or '__pycache__' in rel.parts or file.name=='.DS_Store':continue
        z.write(file,Path(root.name)/rel)
(out/'SHA256SUMS-source.txt').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n')
print(archive)

"""Build reproducible player/developer ZIPs using explicit include rules.

Run: python tools/build_release.py --output /path/to/output
Does not include game files, dependency sources, saved config, or logs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT=Path(__file__).resolve().parents[1]
TOP={'Draftout.json','main.lua','config.lua','LICENSE','README.md','CHANGELOG.md'}


def selected(root,developer=False):
    files=[]
    for p in root.rglob('*'):
        if not p.is_file() or p.is_symlink():continue
        rel=p.relative_to(root)
        if any(part.startswith('.') or part=='__pycache__' for part in rel.parts):continue
        keep=str(rel) in TOP or (rel.parts[0]=='draftout' and p.suffix=='.lua') or (rel.parts[0]=='assets' and p.suffix=='.png')
        if rel.as_posix() in {'assets/fonts/Bungee-Regular.ttf','assets/fonts/OFL.txt'}:keep=True
        if developer and rel.parts[0] in {'docs','tests','tools'} and p.suffix in {'.md','.txt','.lua','.py'}:keep=True
        if keep:files.append(p)
    return sorted(files)


def validate(root,files):
    names={p.relative_to(root).as_posix() for p in files}
    assert TOP<=names, 'Missing release document/entry point'
    meta=json.loads((root/'Draftout.json').read_text())
    assert meta['id']=='Draftout' and re.fullmatch(r'\d+\.\d+\.\d+',meta['version'])
    assert meta['author']==['Fantom and Cjpep']
    assert sum(n.endswith('Draftout.json') for n in names)==1
    assert sum(n.endswith('main.lua') for n in names)==1
    for p in files:
        if p.suffix=='.lua':
            for ref in re.findall(r"SMODS\.load_file\(['\"]([^'\"]+)",p.read_text()):
                assert ref in names, f'Missing runtime module: {ref}'
    for scale in (1,2):
        for name in ('burglar_lobby.png','selection_caret.png'):
            assert f'assets/{scale}x/{name}' in names
    assert {'assets/fonts/Bungee-Regular.ttf','assets/fonts/OFL.txt'}<=names
    assert 'diagnostics = false' in (root/'config.lua').read_text()
    assert '# Draftout v'+meta['version'] in (root/'README.md').read_text()
    return meta['version']


def archive(root,files,destination,prefix):
    entries={prefix+'/'+p.relative_to(root).as_posix():p.read_bytes() for p in files}
    inventory=''.join(hashlib.sha256(data).hexdigest()+'  '+name+'\n' for name,data in sorted(entries.items()))
    entries[prefix+'/CONTENTS.sha256']=inventory.encode()
    with zipfile.ZipFile(destination,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,data in sorted(entries.items()):
            entry=zipfile.ZipInfo(name,(2026,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED
            entry.create_system=3;entry.external_attr=0o100644<<16
            z.writestr(entry,data,compresslevel=9)
    with zipfile.ZipFile(destination) as z:assert z.testzip() is None


def build(root,output):
    output.mkdir(parents=True,exist_ok=True)
    player=selected(root);version=validate(root,player)
    developer=selected(root,True);validate(root,developer)
    releases=[]
    for files,label,prefix in ((player,'MPAPI_PvP','Draftout'),(developer,'Developer','Draftout-source')):
        path=output/f'Draftout_v{version}_{label}.zip';archive(root,files,path,prefix);releases.append(path)
    return releases


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=ROOT.parent/'dist')
    for path in build(ROOT,parser.parse_args().output):
        print(f'{path.name}: {path.stat().st_size} bytes; SHA256 {hashlib.sha256(path.read_bytes()).hexdigest()}')

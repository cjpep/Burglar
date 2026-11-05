"""Build Standard player, Thunderstore, and GitHub source ZIPs (Python 3.10+).
Run: python tools/build_release.py --output /path/to/releases
No game files or dependency mods are bundled. Spectator is deprecated.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOP = {'Burglar.json', 'main.lua', 'config.lua', 'LICENSE', 'README.md',
       'INSTALL.md', 'CHANGELOG.md', 'RELEASE_NOTES.md'}


def selected(root, source=False):
    entries = {}
    for p in sorted(root.rglob('*')):
        if not p.is_file() or p.is_symlink():
            continue
        rel = p.relative_to(root)
        name = rel.as_posix()
        if any(part.startswith('.') or part == '__pycache__' for part in rel.parts):
            continue
        keep = name in TOP or (rel.parts[0] == 'burglar' and p.suffix == '.lua')
        keep |= rel.parts[0] == 'cubes' and p.suffix in {'.json', '.md'}
        keep |= rel.parts[0] == 'assets' and p.suffix == '.png'
        keep |= name in {'assets/fonts/Bungee-Regular.ttf', 'assets/fonts/OFL.txt'}
        keep |= source and rel.parts[0] in {'docs', 'tests', 'tools'} and p.suffix in {'.md', '.txt', '.lua', '.py'}
        keep |= source and name in {'icon.png', 'manifest.json'}
        # Inactive historical spectator sources remain available to developers,
        # but never enter either installable package.
        if not source and name.startswith('burglar/spectator'):
            keep = False
        if name == 'cubes/example_pool.json':
            keep = False
        if keep:
            entries[name] = p.read_bytes()
    if source:
        entries['.gitignore'] = (root / '.gitignore').read_bytes()
    return entries


def validate(entries, source=False):
    assert TOP <= entries.keys(), 'Missing entry point or release document'
    meta = json.loads(entries['Burglar.json'])
    assert meta['id'] == 'Draftout' and meta['prefix'] == 'draftout'  # Save/protocol compatibility.
    assert meta['name'] == 'Burglar' and meta['author'] == ['Cjpep', 'Fantom_Balatro']
    assert re.fullmatch(r'\d+\.\d+\.\d+', meta['version'])
    for name, data in entries.items():
        assert 'draftout' not in name.lower(), name
        if name.endswith('.lua') and not name.startswith('tests/'):
            text = data.decode()
            for ref in re.findall(r"SMODS\.load_file\(['\"]([^'\"]+)", text):
                assert ref in entries, f'{name}: missing {ref}'
            if not source:
                assert 'D.spectator' not in text and 'draftout_spectate_' not in text, name
    for scale in (1, 2):
        for name in ('burglar_lobby.png', 'selection_caret.png'):
            assert f'assets/{scale}x/{name}' in entries
    assert {'assets/fonts/Bungee-Regular.ttf', 'assets/fonts/OFL.txt'} <= entries.keys()
    assert 'diagnostics = false' in entries['config.lua'].decode()
    assert 'spectator' not in entries['main.lua'].decode()
    assert 'cubes/example_pool.json' not in entries
    if not source:
        assert not any(n.startswith('burglar/spectator') for n in entries)
    return meta['version']


def player_entries(root, spectator=False):
    assert not spectator, 'The Spectator edition is deprecated; build Standard.'
    entries = selected(root)
    entries['EDITION.txt'] = b'Burglar - Standard (no spectator feature)\nEveryone must use the same version. Replace the entire Burglar folder.\n'
    validate(entries)
    return entries


def archive(entries, destination, prefix=''):
    entries = {(prefix + '/' if prefix else '') + name: data for name, data in entries.items()}
    inventory = (prefix + '/' if prefix else '') + 'CONTENTS.sha256'
    entries[inventory] = ''.join(
        hashlib.sha256(data).hexdigest() + '  ' + name + '\n'
        for name, data in sorted(entries.items())).encode()
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in sorted(entries.items()):
            entry = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            z.writestr(entry, data, compresslevel=9)
    with zipfile.ZipFile(destination) as z:
        assert z.testzip() is None


def build(root, output):
    output.mkdir(parents=True, exist_ok=True)
    entries = player_entries(root)
    version = validate(entries)
    paths = [output / f'Burglar_v{version}_{label}.zip'
             for label in ('Standard', 'Standard_Thunderstore', 'GitHub_Source')]
    archive(entries, paths[0], 'Burglar')
    manifest = json.loads((root / 'manifest.json').read_text())
    assert manifest['name'] == 'Burglar' and manifest['version_number'] == version
    mod = json.loads(entries['Burglar.json'])
    for dep in ('MultiplayerAPI', 'MultiplayerPvP'):
        minimum = next(x for x in mod['dependencies'] if x.startswith(dep+' (>=')).split('>=')[1].rstrip(')')
        assert f'BalatroMultiplayer-{dep}-{minimum}' in manifest['dependencies']
    icon = (root / 'icon.png').read_bytes()
    assert icon[:8] == b'\x89PNG\r\n\x1a\n' and icon[16:24] == b'\x00\x00\x01\x00'*2, 'Icon must be 256x256 PNG'
    thunder = {'Burglar/'+name: data for name, data in entries.items()}
    thunder.update({name: (root / name).read_bytes() for name in ('manifest.json', 'icon.png', 'README.md', 'CHANGELOG.md')})
    archive(thunder, paths[1])
    source = selected(root, source=True)
    validate(source, source=True)
    archive(source, paths[2], 'Burglar-source')
    return paths


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT.parent / 'dist')
    for path in build(ROOT, parser.parse_args().output):
        print(f'{path.name}: {path.stat().st_size} bytes; SHA256 {hashlib.sha256(path.read_bytes()).hexdigest()}')

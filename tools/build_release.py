"""Build Standard, Spectator, and GitHub source ZIPs. Python 3.10+, no packages.
Run: python tools/build_release.py --output /path/to/releases
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOP = {'Burglar.json', 'main.lua', 'config.lua', 'LICENSE', 'README.md', 'INSTALL.md', 'CHANGELOG.md'}
STRIP = {
    'main.lua': ["assert(SMODS.load_file('burglar/spectator.lua', mod.id))()(D)",
                 "        row({button('Local spectator preview','draftout_spectate_demo',nil,5)}),"],
    'config.lua': ['    spectator_enabled = true, -- Experimental delayed read-only board viewer.'],
    'burglar/mpapi.lua': ['            if D.spectator and D.spectator.receive(from,packet) then return end',
                        '            if D.spectator then pcall(D.spectator.event,l,kind,id) end'],
}

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
        keep |= rel.parts[0] == 'assets' and p.suffix == '.png'
        keep |= name in {'assets/fonts/Bungee-Regular.ttf', 'assets/fonts/OFL.txt'}
        keep |= source and rel.parts[0] in {'docs', 'tests', 'tools'} and p.suffix in {'.md', '.txt', '.lua', '.py'}
        if keep:
            entries[name] = p.read_bytes()
    if source:
        entries['.gitignore'] = (root / '.gitignore').read_bytes()
    return entries

def validate(entries, spectator):
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
            if not spectator:
                assert 'D.spectator' not in text and 'draftout_spectate_' not in text, name
    for scale in (1, 2):
        for name in ('burglar_lobby.png', 'selection_caret.png'):
            assert f'assets/{scale}x/{name}' in entries
    assert {'assets/fonts/Bungee-Regular.ttf', 'assets/fonts/OFL.txt'} <= entries.keys()
    assert 'diagnostics = false' in entries['config.lua'].decode()
    assert bool('burglar/spectator.lua' in entries) == spectator
    assert '# Burglar' in entries['README.md'].decode()
    return meta['version']

def player_entries(root, spectator):
    entries = selected(root)
    if not spectator:
        entries = {name: data for name, data in entries.items() if not name.startswith('burglar/spectator')}
        for name, lines in STRIP.items():
            text = entries[name].decode()
            for line in lines:
                assert text.count(line) == 1, f'Spectator removal needs updating: {name}: {line}'
                text = text.replace(line + '\n', '')
            entries[name] = text.encode()
    edition = 'Spectator (experimental viewer included)' if spectator else 'Standard (spectator code excluded)'
    entries['EDITION.txt'] = (f'Burglar — {edition}\nInstall only one edition. Everyone should use the same edition and version.\n').encode()
    validate(entries, spectator)
    return entries

def archive(entries, destination, prefix):
    entries = {prefix + '/' + name: data for name, data in entries.items()}
    entries[prefix + '/CONTENTS.sha256'] = ''.join(
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
    version = json.loads((root / 'Burglar.json').read_text())['version']
    releases = []
    for spectator, label in ((False, 'Standard'), (True, 'Spectator')):
        path = output / f'Burglar_v{version}_{label}.zip'
        archive(player_entries(root, spectator), path, 'Burglar')
        releases.append(path)
    source = selected(root, source=True)
    validate(source, True)
    path = output / f'Burglar_v{version}_GitHub_Source.zip'
    archive(source, path, 'Burglar-source')
    releases.append(path)
    return releases

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT.parent / 'dist')
    for path in build(ROOT, parser.parse_args().output):
        print(f'{path.name}: {path.stat().st_size} bytes; SHA256 {hashlib.sha256(path.read_bytes()).hexdigest()}')

"""Release identity, deterministic archives, runtime references, and edition isolation."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('builder', ROOT/'tools/build_release.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)

class PackagingTests(unittest.TestCase):
    def test_one_manifest_and_compatible_identity(self):
        manifests = [p for p in ROOT.rglob('*.json') if json.loads(p.read_text()).get('id') == 'Draftout']
        self.assertEqual(manifests, [ROOT/'Burglar.json'])
        self.assertEqual(list(ROOT.rglob('main.lua')), [ROOT/'main.lua'])
        meta = json.loads(manifests[0].read_text())
        self.assertEqual(meta['name'], 'Burglar')
        self.assertEqual(meta['author'], ['Cjpep', 'Fantom_Balatro'])

    def test_standard_removes_spectator_code_and_hooks(self):
        standard = builder.player_entries(ROOT, False)
        spectator = builder.player_entries(ROOT, True)
        self.assertFalse(any('spectator' in n for n in standard))
        self.assertEqual(len([n for n in spectator if n.startswith('burglar/spectator')]), 6)
        for name, data in standard.items():
            if name.endswith('.lua'):
                self.assertNotIn(b'D.spectator', data)
                self.assertNotIn(b'draftout_spectate_', data)
        for name in standard.keys() & spectator.keys():
            if name not in {*builder.STRIP, 'EDITION.txt'}:
                self.assertEqual(standard[name], spectator[name], name)

    def test_reproducible_archives_and_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            first = builder.build(ROOT, Path(directory)/'first')
            second = builder.build(ROOT, Path(directory)/'second')
            self.assertEqual(len(first), 3)
            for index, (a, b) in enumerate(zip(first, second)):
                self.assertEqual(a.read_bytes(), b.read_bytes())
                with zipfile.ZipFile(a) as z:
                    names = z.namelist()
                    self.assertIsNone(z.testzip())
                    self.assertFalse(any('__pycache__' in n or 'reference_' in n or n.endswith('.log') for n in names))
                    self.assertFalse(any('draftout' in n.lower() for n in names))
                    self.assertEqual(sum(n.endswith('/Burglar.json') for n in names), 1)
                    inventory = z.read(next(n for n in names if n.endswith('/CONTENTS.sha256'))).decode()
                    for line in inventory.splitlines():
                        digest, name = line.split('  ', 1)
                        self.assertEqual(hashlib.sha256(z.read(name)).hexdigest(), digest)
                    if index < 2:
                        self.assertTrue(all(n.startswith('Burglar/') for n in names))
                        self.assertFalse(any('/tests/' in n or '/tools/' in n or '/docs/' in n for n in names))
                    else:
                        self.assertIn('Burglar-source/tools/build_release.py', names)
                        self.assertIn('Burglar-source/.gitignore', names)

if __name__ == '__main__':
    unittest.main()

"""Prevent an embedded install from competing with the actual mod entry point."""
import json
from pathlib import Path
import unittest
import importlib.util
import tempfile
import zipfile
import hashlib

ROOT = Path(__file__).resolve().parents[1]


class PackagingTests(unittest.TestCase):
    def test_only_one_draftout_manifest_and_entry_point(self):
        manifests = [path for path in ROOT.rglob('*.json')
                     if json.loads(path.read_text()).get('id') == 'Draftout']
        self.assertEqual(manifests, [ROOT / 'Draftout.json'])
        self.assertEqual(list(ROOT.rglob('main.lua')), [ROOT / 'main.lua'])

    def test_registered_art_exists_at_both_texture_scales(self):
        for scale in (1, 2):
            for name in ('burglar_lobby.png', 'selection_caret.png'):
                self.assertTrue((ROOT / 'assets' / f'{scale}x' / name).is_file())

    def test_reproducible_release_contents_and_inventory(self):
        spec=importlib.util.spec_from_file_location('release_builder',ROOT/'tools/build_release.py')
        builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
        with tempfile.TemporaryDirectory() as directory:
            first=builder.build(ROOT,Path(directory)/'first')
            second=builder.build(ROOT,Path(directory)/'second')
            for a,b in zip(first,second):self.assertEqual(a.read_bytes(),b.read_bytes())
            for index,path in enumerate(first):
                with zipfile.ZipFile(path) as z:
                    names=z.namelist()
                    self.assertFalse(any('__pycache__' in n or 'reference_' in n or n.endswith('.log') for n in names))
                    self.assertEqual(sum(n.endswith('/Draftout.json') for n in names),1)
                    inventory=z.read(next(n for n in names if n.endswith('/CONTENTS.sha256'))).decode()
                    for line in inventory.splitlines():
                        digest,name=line.split('  ',1)
                        self.assertEqual(hashlib.sha256(z.read(name)).hexdigest(),digest)
                    if index==0:
                        self.assertTrue(all(n.startswith('Draftout/') for n in names))
                        self.assertFalse(any('/tests/' in n or '/tools/' in n or '/docs/' in n for n in names))
                    else:
                        self.assertTrue(any('/tests/roster_duel_spec.py' in n for n in names))
                        self.assertTrue(any('/tools/build_release.py' in n for n in names))


if __name__ == '__main__':
    unittest.main()

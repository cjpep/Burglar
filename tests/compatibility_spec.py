"""Source-level compatibility checks; does not launch Windows/Lovely/LÖVE.

Uses unmodified functions from the exact beta-1814a source under LuaJIT.
Set DRAFTOUT_LEGACY_SMODS and DRAFTOUT_LOVELY_REFERENCE to extracted releases.
"""
import json
import os
from pathlib import Path
import re
import tomllib
import unittest
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SMODS = Path(os.environ.get('DRAFTOUT_LEGACY_SMODS', ROOT.parent/'reference_smods/smods-1.0.0-beta-1814a'))
LOVELY = Path(os.environ.get('DRAFTOUT_LOVELY_REFERENCE', ROOT.parent/'reference_lovely/lovely-injector-0.9.0'))
MP = Path(os.environ.get('DRAFTOUT_MP_REFERENCE', ROOT.parent/'reference_mp_100'))


def function(path, name):
    match = re.search(r'function '+re.escape(name)+r'\(.*?\nend', path.read_text(), re.S)
    assert match, name
    return match.group()


class CompatibilityTests(unittest.TestCase):
    def setUp(self):
        if not SMODS.exists():
            self.skipTest('Provide beta-1814a source via DRAFTOUT_LEGACY_SMODS')
        self.lua = LuaRuntime(unpack_returned_tuples=True)

    def test_version_constraints_with_actual_beta_parser(self):
        lua = self.lua
        lua.globals().V = lua.execute((SMODS/'src/preflight/sharedUtil.lua').read_text()).V
        version = lua.execute((SMODS/'version.lua').read_text()).replace('-STEAMODDED', '')
        versions = {'Balatro': '1.0.1o', 'Steamodded': version, 'Lovely':os.environ.get('DRAFTOUT_LOVELY_VERSION','0.9.0'), 'MultiplayerAPI':'1.0.0', 'MultiplayerPvP':'1.0.0'}
        metadata = [ROOT/'Burglar.json', MP/'BalatroMultiplayer-MultiplayerAPI-1.0.0/MultiplayerAPI.json', MP/'BalatroMultiplayer-MultiplayerPvP-1.0.0/MultiplayerPvP.json']
        compare = lua.eval('function(a,op,b) if op==">=" then return V(a)>=V(b) else assert(op=="=="); return V(a)==V(b) end end')
        for path in metadata:
            for dep in json.loads(path.read_text())['dependencies']:
                if '(' not in dep:
                    self.assertIn(dep, versions)
                    continue
                name, op, required = re.fullmatch(r'(\w+) \((>=|==)([^)]+)\)', dep).groups()
                self.assertTrue(compare(versions[name], op, required), dep)
        self.assertFalse(compare('0.8.0','>=','0.9.0'))
        self.assertFalse(compare('1.0.0~BETA-1620a','>=','1.0.0~BETA-1814a'))

    def test_full_adapter_with_actual_legacy_helpers_and_json(self):
        lua = self.lua
        lua.globals().legacy_load = function(SMODS/'src/preflight/loader.lua', 'SMODS.load_file')
        lua.globals().legacy_save = function(SMODS/'src/ui.lua', 'SMODS.save_mod_config')
        lua.globals().legacy_showman = function(SMODS/'src/utils.lua', 'SMODS.showman')
        lua.globals().json_source = (SMODS/'libs/json/json.lua').read_text()
        lua.execute('package.preload.json=function() return assert(loadstring(json_source))() end')
        # Preserve real filesystem reads; capture writes in memory. Rendering and
        # native serialization remain mocked by this offline adapter harness.
        prelude = '''
SMODS.current_mod.path='./'
SMODS.Mods={Burglar=SMODS.current_mod}
SMODS.find_card=function() return {} end
NFS={read=function(path) local f=assert(io.open(path,'rb')); local s=f:read('*a'); f:close(); return s end,
    createDirectory=function() end,
    write=function(path,data) assert(path=='config/Burglar.jkr'); assert(data=='return {}'); saved_config=saved_config+1 end}
serialize=function() return '{}' end
assert(loadstring(legacy_load))()
assert(loadstring(legacy_save))()
assert(loadstring(legacy_showman))()
'''
        source = (ROOT/'tests/adapter_spec.lua').read_text()
        self.assertEqual(source.count("dofile('main.lua')"), 1)
        old = Path.cwd()
        try:
            os.chdir(ROOT)
            lua.execute(source.replace("dofile('main.lua')", prelude+"\ndofile('main.lua')"))
        finally:
            os.chdir(old)

    def test_no_direct_lovely_dependency_in_draftout_code(self):
        self.assertFalse(list(ROOT.rglob('*.toml')))
        for path in [ROOT/'main.lua', *(ROOT/'burglar').glob('*.lua')]:
            self.assertIsNone(re.search(r'require\s*\(?\s*[\'\"]lovely[\'\"]',path.read_text()))

    def test_upstream_patch_fields_exist_in_lovely_schema(self):
        if not LOVELY.exists() or not MP.exists():
            self.skipTest('Provide Lovely patch schema and Multiplayer 1.0.0 source')
        base = LOVELY/'crates/lovely-core/src/patch'
        fields = {}
        for kind, filename, struct in [('manifest','mod.rs','Manifest'), ('pattern','pattern.rs','PatternPatch'), ('regex','regex.rs','RegexPatch'), ('module','module.rs','ModulePatch'), ('copy','copy.rs','CopyPatch')]:
            body = re.search(r'pub struct '+struct+r' \{(.*?)\n\}',(base/filename).read_text(),re.S).group(1)
            fields[kind] = set(re.findall(r'^\s*pub (\w+):',body,re.M))
        paths = list((SMODS/'lovely').rglob('*.toml'))
        for name in ('MultiplayerAPI','MultiplayerPvP'):
            paths += list((MP/f'BalatroMultiplayer-{name}-1.0.0'/'lovely').rglob('*.toml'))
        self.assertGreater(len(paths), 20)
        for path in paths:
            data = tomllib.loads(path.read_text())
            self.assertFalse(set(data)-{'manifest','patches','vars'},str(path))
            self.assertFalse(set(data['manifest'])-fields['manifest'],str(path))
            for patch in data['patches']:
                for kind, payload in patch.items():
                    self.assertIn(kind, fields, str(path))
                    self.assertFalse(set(payload)-fields[kind],str(path))
        print(f'Checked field compatibility for {len(paths)} upstream Lovely manifests (not patch execution).')


if __name__=='__main__':
    unittest.main(verbosity=2)

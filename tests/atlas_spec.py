"""Regression for MP blind icons missing SMODS 26.x atlas column metadata."""
from pathlib import Path
import os
import re
import unittest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SMODS = Path(os.environ.get('DRAFTOUT_SMODS_REFERENCE', str(ROOT.parent/'reference_smods/smods-26.1002.0')))


class AtlasTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().compat_source = (ROOT/'burglar/atlas_compat.lua').read_text()
        self.lua.execute('''
            C=assert(loadstring(compat_source))()
            image={getWidth=function() return 714 end, getHeight=function() return 102 end}
            atlas={image=image, px=34, py=34, frames=21}
        ''')

    def test_actual_smods_getter_crashes_before_and_succeeds_after(self):
        path = SMODS/'src/overrides.lua'
        if not path.exists():
            self.skipTest('Set DRAFTOUT_SMODS_REFERENCE to the extracted 26.1002.0 source')
        source = re.search(r'function AnimatedSprite:get_pos_pixel\(\).*?\nend', path.read_text(), re.S)
        self.assertIsNotNone(source)
        self.lua.execute('AnimatedSprite={}')
        self.lua.execute(source.group())
        self.lua.execute('''sprite=setmetatable({atlas=atlas, RETS={},
            sprite_args={start_pos={x=2,y=1}}, current_animation={current=25},
            animation={w=34,h=34}}, {__index=AnimatedSprite})''')
        ok, error = self.lua.execute('return pcall(sprite.get_pos_pixel,sprite)')
        self.assertFalse(ok)
        self.assertIn('columns', error)
        self.lua.execute('C.repair(atlas)')
        self.assertEqual(self.lua.eval('atlas.columns'),21)
        self.assertEqual(self.lua.eval('atlas.rows'),3)
        values = self.lua.execute('local v=sprite:get_pos_pixel(); return v[1],v[2],v[3],v[4]')
        self.assertEqual(values,(6,2,34,34))

    def test_existing_metadata_and_frame_count_are_preserved(self):
        self.lua.execute('atlas.columns=9; atlas.rows=7; C.repair(atlas)')
        self.assertEqual(self.lua.eval('atlas.columns'),9)
        self.assertEqual(self.lua.eval('atlas.rows'),7)
        self.assertEqual(self.lua.eval('atlas.frames'),21)

    def test_invalid_sizes_are_not_replaced_by_invented_defaults(self):
        self.lua.execute('atlas.px=0; atlas.py=nil; C.repair(atlas)')
        self.assertIsNone(self.lua.eval('atlas.columns'))
        self.assertIsNone(self.lua.eval('atlas.rows'))
        self.assertIsNone(self.lua.execute('return C.repair(nil)'))
        self.assertFalse(self.lua.execute('return C.install(nil)'))

    def test_mp_getter_preserves_identity_and_unknown_keys(self):
        self.lua.execute('''
            local original_atlas=atlas
            mp={PLATFORM={BALATRO={get_animation_atlas=function(key)
                if key=='blind_chips' then return original_atlas end
            end}}}
            assert(C.install(mp))
            result=mp.PLATFORM.BALATRO.get_animation_atlas('blind_chips')
        ''')
        self.assertTrue(self.lua.eval('result==atlas'))
        self.assertEqual(self.lua.eval('result.columns'),21)
        self.assertIsNone(self.lua.execute("return mp.PLATFORM.BALATRO.get_animation_atlas('missing')"))


if __name__=='__main__':
    unittest.main(verbosity=2)

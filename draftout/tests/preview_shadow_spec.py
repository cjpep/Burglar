"""Exercise preview layering alongside the actual SMODS native shadow step."""
from pathlib import Path
import os
import re
import unittest
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
SMODS=Path(os.environ.get('DRAFTOUT_LEGACY_SMODS',ROOT.parent/'reference_smods/smods-1.0.0-beta-1814a'))


@unittest.skipUnless((SMODS/'src/card_draw.lua').exists(),'Provide SMODS shadow source')
class PreviewShadowTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            SMODS={DrawStep=function(step) native_shadow=step.func end}
            G={SETTINGS={GRAPHICS={shadows='On'}},TIMERS={REAL=1}}
            draws={}
            sprite={VT={},draw_shader=function(_,shader,height)
                draws[#draws+1]={shader=shader,height=height}
            end}
            card={states={visible=true,drag={is=false}},VT={scale=1,r=0},ARGS={},
                tilt_var={amt=0},velocity={x=0},ability={},sprite_facing='front',
                children={center=sprite},area={config={type='title'}},
                should_draw_shadow=function(self)return not self.ignore_shadow end}
            function card:draw(layer)
                layer=layer or 'both'
                if not self.states.visible then return end
                if layer=='shadow' or layer=='both' then native_shadow(self) end
                if layer=='card' or layer=='both' then draws[#draws+1]={art=true} end
                return 'native-result'
            end
        ''')
        step=re.search(r"SMODS.DrawStep \{\s*key = 'shadow',.*?\n\}",(SMODS/'src/card_draw.lua').read_text(),re.S)
        self.assertIsNotNone(step)
        self.lua.execute(step.group())
        self.lua.globals().S=self.lua.execute((ROOT/'draftout/preview_shadow.lua').read_text())
        self.lua.execute('S.attach(card);card.draftout_selected=true')

    def test_split_layers_draw_one_raised_shadow_before_art(self):
        self.lua.execute("card:draw('shadow');card:draw('card')")
        self.assertEqual(self.lua.eval('#draws'),2)
        self.assertEqual(self.lua.eval('draws[1].height'),0.28)
        self.assertTrue(self.lua.eval('draws[2].art'))
        self.assertIsNone(self.lua.eval('card.no_shadow'))

    def test_focus_and_card_only_draw_paths_keep_shadow(self):
        for call in ('card:draw()', "card:draw('card')"):
            self.lua.execute('draws={}');result=self.lua.execute('return '+call)
            self.assertEqual(result,'native-result')
            self.assertEqual(self.lua.eval('#draws'),2)
            self.assertEqual(self.lua.eval('draws[1].height'),0.28)

    def test_deselect_returns_to_native_shadow_and_attach_is_idempotent(self):
        self.lua.execute('S.attach(card);card.draftout_selected=false;card:draw()')
        self.assertEqual(self.lua.eval('#draws'),2)
        self.assertEqual(self.lua.eval('draws[1].height'),0.1)

    def test_settings_hidden_cards_and_native_suppression_are_respected(self):
        for setup in ("G.SETTINGS.GRAPHICS.shadows='Off'",'card.no_shadow=true',
                      'card.ignore_shadow=true','card.greyed=true','card.states.visible=false'):
            self.setUp();self.lua.execute(setup+';card:draw()')
            self.assertEqual(self.lua.eval('(function() local n=0;for _,v in ipairs(draws) do if v.height then n=n+1 end end;return n end)()'),0)


if __name__=='__main__':unittest.main()

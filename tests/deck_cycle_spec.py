"""Reproduce stale mod-Collection context using supplied vanilla callbacks,
SMODS' actual Lovely payloads/collection filter and PvP's actual pool wrappers.
Back objects and graphics are mocked; no Windows game is launched.
"""
import os
from pathlib import Path
import re
import tomllib
import unittest
from lupa.luajit21 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
SMODS=Path(os.environ.get('DRAFTOUT_LEGACY_SMODS',ROOT.parent/'reference_smods/smods-1.0.0-beta-1814a'))
PVP=Path(os.environ.get('DRAFTOUT_PVP_REFERENCE',ROOT.parent/'reference_mp_100/BalatroMultiplayer-MultiplayerPvP-1.0.0'))
GAME=Path(os.environ.get('DRAFTOUT_GAME_REFERENCE',ROOT.parent/'upload'))

class CycleTests(unittest.TestCase):
    def setUp(self):
        if not all(p.exists() for p in (SMODS,PVP,GAME/'button_callbacks.lua.txt')):
            self.skipTest('Supply SMODS, PvP and vanilla source references')
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            SMODS={injectItems=function() end}
            draftout_mod={id='Draftout'}
            PVP={id='MultiplayerPvP',LOBBY={},config={},current_ruleset=function() return {multiplayer_content=allow_mp} end}
            G={FUNCS={},UIDEF={},GAME={},P_CENTER_POOLS={},P_CENTERS={},CHALLENGES={},SETTINGS={profile=1},
                PROFILES={{MEMORY={}}},ACTIVE_MOD_UI=draftout_mod}
            local red={key='b_red',name='Red Deck',order=1}
            local blue={key='b_blue',name='Blue Deck',order=3}
            local yellow={key='b_yellow',name='Yellow Deck',order=4}
            local mp={key='b_mp_test',name='MP Deck',order=2,mod=PVP}
            G.P_CENTER_POOLS.Back={red,mp,blue,yellow}; G.P_CENTER_POOLS.Stake={}
            for _,v in ipairs(G.P_CENTER_POOLS.Back) do G.P_CENTERS[v.key]=v end
            G.GAME.viewed_back={change_to=function(self,center)
                center=center or red; self.name=center.name; self.effect={center=center}
            end}
            G.GAME.viewed_back:change_to(red)
            get_deck_win_sticker=function(center) return center.key..'_sticker' end
            get_deck_win_stake=function() return 8 end
            local card={T={x=2,y=3},config={center={}},children={center={VT={}}},
                set_ability=function(self) self.children.back={VT={},name=G.GAME.viewed_back.name} end}
            G.sticker_card=card; card.area={cards={card}}
            copy_table=function(t) local r={}; for k,v in pairs(t) do r[k]=v end; return r end
            create_option_cycle=function(args) cycle=args; return args end
            G.UIDEF.run_setup_option=function()
                local names={}; for _,c in ipairs(G.P_CENTER_POOLS.Back) do names[#names+1]=c.name end
                return create_option_cycle({options=names,opt_callback='change_viewed_back'})
            end
            for _,key in ipairs({'deck_stake_column','current_stake','stake_option','challenges','challenge_list','challenge_list_page'}) do
                G.UIDEF[key]=function() end
            end
            G.FUNCS.change_selected_back=function() end
        ''')
        util=(SMODS/'src/utils.lua').read_text()
        self.lua.execute(re.search(r'SMODS.collection_pool = function\(_base_pool\).*?\nend',util,re.S).group())
        callback=re.search(r'G.FUNCS.change_viewed_back = function\(args\).*?\nend',(GAME/'button_callbacks.lua.txt').read_text(),re.S).group()
        for filename in ('ui.toml','back.toml'):
            for patch in tomllib.loads((SMODS/'lovely'/filename).read_text())['patches']:
                p=patch.get('pattern',{})
                if p.get('target')=='functions/button_callbacks.lua' and p.get('pattern') in callback:
                    pattern=p['pattern']; payload=p['payload']
                    callback=callback.replace(pattern,payload if p['position']=='at' else pattern+'\n'+payload)
        self.lua.execute(callback)
        self.lua.execute((PVP/'overrides/hide_content.lua').read_text())
        self.lua.execute('SMODS.injectItems()')
        self.lua.globals().compat=self.lua.execute((ROOT/'burglar/deck_cycle_compat.lua').read_text())

    def run_lua(self,code): return self.lua.execute(code)
    def value(self,code): return self.lua.eval(code)
    def choose(self,index):
        self.run_lua(f'G.FUNCS.change_viewed_back({{to_key={index},to_val=cycle.options[{index}],cycle_config=cycle}})')

    def test_reproduces_red_fallback_and_saved_correct_name_before_fix(self):
        self.run_lua('G.UIDEF.run_setup_option()')
        self.choose(2)
        self.assertEqual(self.value('G.GAME.viewed_back.name'),'Red Deck')
        self.assertEqual(self.value('G.PROFILES[1].MEMORY.deck'),'Blue Deck')

    def test_singleplayer_and_private_lobby_scrolling_after_fix(self):
        self.run_lua('assert(compat.install()); assert(not compat.install())')
        for lobby in (False,True):
            self.run_lua("PVP.LOBBY.code="+('"ROOM"' if lobby else 'nil')+'; G.UIDEF.run_setup_option()')
            for index,name in ((2,'Blue Deck'),(3,'Yellow Deck'),(1,'Red Deck'),(3,'Yellow Deck')):
                self.choose(index)
                self.assertEqual(self.value('G.GAME.viewed_back.name'),name)
                self.assertEqual(self.value('G.sticker_card.children.back.name'),name)
                self.assertEqual(self.value('G.PROFILES[1].MEMORY.deck'),name)
                self.assertTrue(self.value('G.ACTIVE_MOD_UI==draftout_mod'))

    def test_full_pool_multiplayer_ruleset_and_genuine_mod_collection(self):
        self.run_lua('compat.install(); allow_mp=true; PVP.LOBBY.code="ROOM"; G.UIDEF.run_setup_option()')
        self.choose(3)
        self.assertEqual(self.value('G.GAME.viewed_back.name'),'Blue Deck')
        self.run_lua('''G.ACTIVE_MOD_UI=PVP
            G.FUNCS.change_viewed_back({to_key=1,to_val='b_mp_test',cycle_config={options={'b_mp_test'}}})''')
        self.assertEqual(self.value('G.GAME.viewed_back.name'),'MP Deck')
        self.assertTrue(self.value('G.ACTIVE_MOD_UI==PVP'))

    def test_context_and_cycle_builder_restored_on_error(self):
        self.run_lua("G.UIDEF.run_setup_option=function() error('build failure') end; original_cycle=create_option_cycle; compat.install()")
        ok,err=self.run_lua('return pcall(G.UIDEF.run_setup_option)')
        self.assertFalse(ok);self.assertIn('build failure',err)
        self.assertTrue(self.value('G.ACTIVE_MOD_UI==draftout_mod and create_option_cycle==original_cycle'))

    def test_callback_errors_restore_context_and_return_values_preserved(self):
        self.run_lua("G.FUNCS.change_viewed_back=function() error('callback failure') end; compat.install(); G.UIDEF.run_setup_option()")
        ok,err=self.run_lua('return pcall(G.FUNCS.change_viewed_back,{cycle_config=cycle})')
        self.assertFalse(ok);self.assertIn('callback failure',err)
        self.assertTrue(self.value('G.ACTIVE_MOD_UI==draftout_mod'))

    def test_no_stale_context_and_unrelated_cycles_unchanged(self):
        self.run_lua("G.ACTIVE_MOD_UI=nil; compat.install(); G.UIDEF.run_setup_option()")
        self.choose(2)
        self.assertEqual(self.value('G.GAME.viewed_back.name'),'Blue Deck')
        self.assertIsNone(self.value('G.ACTIVE_MOD_UI'))
        self.run_lua("other=create_option_cycle({options={'a','b'},opt_callback='change_stake'})")
        self.assertIsNone(self.value('other.draftout_run_setup_cycle'))

if __name__=='__main__': unittest.main(verbosity=2)

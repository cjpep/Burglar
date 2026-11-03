"""Draftout-scoped rarity changes and native Wraith-pool eligibility. No game launch."""
from pathlib import Path
import os
import re
import unittest
from lupa.luajit21 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
SMODS=Path(os.environ.get('DRAFTOUT_LEGACY_SMODS',ROOT.parent/'reference_smods/smods-1.0.0-beta-1814a'))
EVENTS=Path(os.environ.get('DRAFTOUT_GAME_EVENTS',ROOT.parent/'upload/common_events.lua.txt'))


class ShowmanTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().root=str(ROOT)
        self.lua.execute('''
            G={STAGE=1,STAGES={RUN=1,MAIN_MENU=2},P_CENTERS={},ARGS={TEMP_POOL={}},
                GAME={round_resets={ante=1},used_jokers={},pool_flags={},banned_keys={}}}
            showman={key='j_ring_master',name='Showman',set='Joker',rarity=2,order=2,unlocked=true}
            joker={key='j_joker',set='Joker',rarity=1,order=1,unlocked=true}
            rare={key='j_rare',set='Joker',rarity=3,order=3,unlocked=true}
            G.P_CENTERS={j_ring_master=showman,j_joker=joker,j_rare=rare}
            G.P_JOKER_RARITY_POOLS={[1]={joker},[2]={showman},[3]={rare}}
            SMODS={ObjectTypes={Joker={rarity_pools={[1]={joker},[2]={showman},[3]={rare}}}},
                load_file=function(path) return loadfile(root..'/'..path) end,
                add_to_pool=function() return true,{} end,showman=function() return false end}
            Game={update=function() end};D={mod={id='Draftout'}}
            function EMPTY(t) for k in pairs(t) do t[k]=nil end;return t end
            function find_joker() return {} end
            function count(pool,key) local n=0;for _,c in ipairs(pool) do if c.key==key then n=n+1 end end;return n end
            function contains(pool,key) for _,v in ipairs(pool) do if v==key then return true end end;return false end
        ''')
        self.lua.execute((ROOT/'draftout/showman.lua').read_text())(self.lua.globals().D)

    def run_lua(self,source): return self.lua.execute(source)

    def test_scoped_rarity_and_registry_order_restore(self):
        self.run_lua('''D.showman.sync();assert(showman.rarity==2)
            G.GAME.draftout_pool={keys={'j_joker'}}
            for i=1,20 do Game:update(0) end
            assert(showman.rarity==3)
            for _,registry in ipairs({G.P_JOKER_RARITY_POOLS,SMODS.ObjectTypes.Joker.rarity_pools}) do
                assert(#registry[2]==0 and #registry[3]==2)
                assert(registry[3][1]==showman and registry[3][2]==rare)
            end
            G.STAGE=2;Game:update(0)
            assert(showman.rarity==2)
            for _,registry in ipairs({G.P_JOKER_RARITY_POOLS,SMODS.ObjectTypes.Joker.rarity_pools}) do
                assert(#registry[2]==1 and registry[2][1]==showman)
                assert(#registry[3]==1 and registry[3][1]==rare)
            end
        ''')

    def test_aliased_registries_do_not_duplicate_showman(self):
        self.run_lua('''SMODS.ObjectTypes.Joker.rarity_pools=G.P_JOKER_RARITY_POOLS
            D.showman.set(true);D.showman.set(true)
            assert(count(G.P_JOKER_RARITY_POOLS[3],'j_ring_master')==1)
            D.showman.set(false)
            assert(count(G.P_JOKER_RARITY_POOLS[2],'j_ring_master')==1)
            assert(count(G.P_JOKER_RARITY_POOLS[3],'j_ring_master')==0)
        ''')

    def test_new_normal_run_and_saved_draft_run_switch_independently(self):
        self.run_lua('''local saved={draftout_pool={keys={'j_joker'}}}
            G.GAME=saved;D.showman.sync();assert(showman.rarity==3)
            G.GAME={};D.showman.sync();assert(showman.rarity==2)
            G.GAME=saved;D.showman.sync();assert(showman.rarity==3)
            G.GAME={draftout_pool=false};D.showman.sync();assert(showman.rarity==2)
        ''')

    def test_other_pool_entries_are_preserved(self):
        self.run_lua('''D.showman.set(true)
            local other={key='j_other',rarity=3,order=4}
            table.insert(G.P_JOKER_RARITY_POOLS[3],other)
            D.showman.set(false)
            assert(G.P_JOKER_RARITY_POOLS[3][1]==rare and G.P_JOKER_RARITY_POOLS[3][2]==other)
        ''')

    def test_native_wraith_rare_pool_can_roll_showman(self):
        if not EVENTS.exists():self.skipTest('Supply Balatro common_events via DRAFTOUT_GAME_EVENTS')
        function=re.search(r'function get_current_pool\(_type, _rarity, _legendary, _append\).*?\nend',EVENTS.read_text(),re.S).group()
        self.run_lua(function)
        self.run_lua('''assert(not contains(get_current_pool('Joker',0.99,nil,'wra'),'j_ring_master'))
            D.showman.set(true)
            assert(contains(get_current_pool('Joker',0.99,nil,'wra'),'j_ring_master'))
            assert(not contains(get_current_pool('Joker',0.8,nil,'wra'),'j_ring_master'))
            G.GAME.banned_keys.j_ring_master=true
            assert(not contains(get_current_pool('Joker',0.99,nil,'wra'),'j_ring_master'))
            G.GAME.banned_keys.j_ring_master=nil;showman.unlocked=false
            assert(not contains(get_current_pool('Joker',0.99,nil,'wra'),'j_ring_master'))
            showman.unlocked=true;D.showman.set(false)
            assert(not contains(get_current_pool('Joker',0.99,nil,'wra'),'j_ring_master'))
        ''')

    def test_smods_culling_sees_rare_showman(self):
        if not (SMODS/'src/utils/weights.lua').exists():self.skipTest('Supply SMODS source')
        function=re.search(r'function SMODS.cull_pool\(pool, args\).*?\nend',(SMODS/'src/utils/weights.lua').read_text(),re.S).group()
        self.run_lua(function)
        self.run_lua('''D.showman.set(true)
            assert(contains(SMODS.cull_pool({'j_ring_master'},{rarity=3,append='wra'}),'j_ring_master'))
            assert(not contains(SMODS.cull_pool({'j_ring_master'},{rarity=2,append='wra'}),'j_ring_master'))
            G.GAME.banned_keys.j_ring_master=true
            assert(not contains(SMODS.cull_pool({'j_ring_master'},{rarity=3,append='wra'}),'j_ring_master'))
        ''')

if __name__=='__main__':unittest.main(verbosity=2)

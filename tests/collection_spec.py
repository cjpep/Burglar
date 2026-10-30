"""Real SMODS collection builder/pager, with graphics mocked. No game launch."""
import os
from pathlib import Path
import re
import unittest
from lupa.luajit21 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
SMODS=Path(os.environ.get('DRAFTOUT_COLLECTION_REFERENCE',ROOT.parent/'reference_smods/smods-1.0.0-beta-1814a'))

class CollectionTests(unittest.TestCase):
    def setUp(self):
        if not (SMODS/'src/ui.lua').exists(): self.skipTest('Supply Steamodded source')
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            SMODS={}; G={FUNCS={},STAGE=1,STAGES={RUN=1,MAIN_MENU=2},GAME={draftout_pool={keys={}}},
                ROOM={T={x=0,y=0,w=10},},CARD_W=1,CARD_H=1,UIT={R=1,O=2},
                P_CENTER_POOLS={Joker={}},P_CARDS={empty={}},C={BLACK={},RED={}}}
            for i=1,45 do
                G.P_CENTER_POOLS.Joker[i]={key='j_'..i,set='Joker',discovered=false,unlocked=false}
                if i<=37 then G.GAME.draftout_pool.keys[i]='j_'..i end
            end
            -- Owned exceptions have no place in the roster browser.
            G.jokers={cards={{config={center=G.P_CENTER_POOLS.Joker[44]}}}}
            function localize(key) return type(key)=='table' and (G.P_CENTER_POOLS.Joker[tonumber(key.key:sub(3))].name or key.key) or key end
            function CardArea(x,y,w,h,config)
                return {T={x=x,y=y,w=w,h=h},cards={},config=config,
                    emplace=function(self,c) self.cards[#self.cards+1]=c end,
                    remove_card=function(self,c)
                        for i,v in ipairs(self.cards) do if v==c then table.remove(self.cards,i); return c end end
                    end}
            end
            function Card(x,y,w,h,front,center)
                return {params={},config={card=front,center=center},
                    set_sprites=function(self,c) self.art_visible=self.bypass_discovery_center and self.bypass_lock end,
                    remove=function() end,start_materialize=function() end}
            end
            function get_joker_win_sticker(c) return c.key..'_win' end
            function INIT_COLLECTION_CARD_ALERTS() end
            function create_option_cycle(args) if args.opt_callback=='SMODS_card_collection_page' then last_cycle=args else sort_cycle=args end; return {config=args} end
            function create_UIBox_generic_options(args) return args end
            function shown()
                local out={}; for _,area in ipairs(G.your_collection or {}) do
                    for _,c in ipairs(area.cards) do out[#out+1]=c.config.center.key end
                end; return table.concat(out,',')
            end
        ''')
        utils=(SMODS/'src/utils.lua').read_text()
        hidden=re.search(r'function SMODS.hide_from_collection\(prototype_obj, args\).*?\nend',utils,re.S)
        if hidden: self.lua.execute(hidden.group())
        self.lua.execute(re.search(r'SMODS.collection_pool = function\(_base_pool\).*?\nend',utils,re.S).group())
        ui=(SMODS/'src/ui.lua').read_text()
        self.lua.execute(re.search(r'SMODS.card_collection_UIBox = function\(_pool, rows, args\).*?\nend',ui,re.S).group())
        self.lua.execute(re.search(r'create_UIBox_your_collection_jokers = function\(\).*?\nend',ui,re.S).group())
        self.lua.globals().compat=self.lua.execute((ROOT/'burglar/collection.lua').read_text())
        self.lua.execute('original_pool=G.P_CENTER_POOLS.Joker; assert(compat.install()); assert(not compat.install()); G.FUNCS.your_collection_jokers=function() ui=create_UIBox_your_collection_jokers() end')

    def run_lua(self,code): return self.lua.execute(code)
    def value(self,code): return self.lua.eval(code)

    def test_duplicate_copies_render_as_separate_roster_entries(self):
        self.run_lua("G.GAME.draftout_pool.keys={'j_1','j_1#2','j_2'};ui=create_UIBox_your_collection_jokers()")
        self.assertEqual(self.value('shown()'),'j_1,j_1,j_2')

    def test_all_drafted_types_paginate_and_owned_exceptions_do_not(self):
        self.run_lua('ui=create_UIBox_your_collection_jokers()')
        self.assertEqual(self.value('#last_cycle.options'),3)
        self.assertEqual(self.value('shown()'),','.join('j_'+str(i) for i in range(1,16)))
        self.run_lua('G.FUNCS.SMODS_card_collection_page({cycle_config={current_option=3}})')
        self.assertEqual(self.value('shown()'),','.join('j_'+str(i) for i in range(31,38)))
        self.assertTrue(self.value('G.P_CENTER_POOLS.Joker==original_pool and #original_pool==45'))

    def test_unlocks_and_discovery_unchanged_but_roster_art_visible(self):
        self.run_lua('create_UIBox_your_collection_jokers()')
        self.assertTrue(self.value('G.your_collection[1].cards[1].art_visible'))
        self.assertFalse(self.value('original_pool[1].discovered'))
        self.assertFalse(self.value('original_pool[1].unlocked'))

    def test_native_sprite_refresh_never_adds_a_playing_card_front(self):
        overrides=(SMODS/'src/overrides.lua').read_text()
        sprites=re.search(r'function Card:set_sprites\(_center, _front\).*?\nend',overrides,re.S).group()
        front=re.search(r'function get_front_spriteinfo\(_front\).*?\nend',overrides,re.S).group()
        self.run_lua('''
            NativeCard={}
            G.SETTINGS={colour_palettes={}};G.P_CENTERS={b_red={pos={x=0,y=0}}}
            SMODS.UndiscoveredCompat={};SMODS.UndiscoveredSprites={}
            SMODS.get_atlas=function(key) return type(key)=='string' and {name=key} or nil end
            SMODS.create_sprite=function(x,y,w,h,atlas,pos)
                return {atlas=atlas,pos=pos or {x=0,y=0},scale={x=1,y=1},
                    states={hover={},click={},drag={},collide={}},
                    set_role=function() end,remove=function(self) self.removed=true end}
            end
            old_card=Card
            Card=function(...)
                local card=old_card(...)
                card.T={x=0,y=0,w=1,h=1};card.states={hover={},click={},drag={}}
                card.children={};card.set_sprites=NativeCard.set_sprites
                return card
            end
        ''')
        self.run_lua(sprites.replace('Card:set_sprites','NativeCard:set_sprites',1))
        self.run_lua(front)
        self.run_lua('create_UIBox_your_collection_jokers()')
        for page in (1,2,3,1):
            self.run_lua(f'G.FUNCS.SMODS_card_collection_page({{cycle_config={{current_option={page}}}}})')
            self.assertTrue(self.value('''(function()
                for _,area in ipairs(G.your_collection) do for _,card in ipairs(area.cards) do
                    if card.children.front or not card.children.center or card.children.center.atlas~='Joker' then return false end
                end end
                return true
            end)()'''),'Every page contains Joker art without a playing-card overlay')
        self.assertTrue(self.value('next(G.P_CARDS.empty)==nil'))
        self.assertFalse(self.value('original_pool[1].discovered'))
        self.assertFalse(self.value('original_pool[1].unlocked'))

    def test_main_menu_and_unrelated_run_show_full_collection(self):
        for transition in ('G.STAGE=2','G.STAGE=1; G.GAME.draftout_pool=nil'):
            self.run_lua(transition+'; create_UIBox_your_collection_jokers()')
            self.run_lua('G.FUNCS.SMODS_card_collection_page({cycle_config={current_option=3}})')
            self.assertEqual(len(self.value('shown()').split(',')),15)
            self.assertTrue(self.value("shown():find('j_45')~=nil"))

    def test_mod_menu_context_cannot_hide_roster_and_is_restored(self):
        self.run_lua("context={id='Draftout'}; G.ACTIVE_MOD_UI=context; ui=create_UIBox_your_collection_jokers()")
        self.assertEqual(self.value('#last_cycle.options'),3)
        self.assertTrue(self.value('G.ACTIVE_MOD_UI==context'))
        self.assertEqual(self.value('ui.back_func'),'your_collection')
        self.run_lua('G.FUNCS.SMODS_card_collection_page({cycle_config={current_option=2}})')
        self.assertTrue(self.value("shown():find('j_16')~=nil"))

    def test_other_collection_types_and_shops_keep_original_pools(self):
        self.run_lua("G.P_CENTER_POOLS.Tarot={{key='c_fool',set='Tarot'}}; create_UIBox_your_collection_jokers()")
        self.assertEqual(self.value('#SMODS.collection_pool(G.P_CENTER_POOLS.Tarot)'),1)
        self.assertEqual(self.value('#SMODS.collection_pool(original_pool)'),45)

    def test_sort_controls_name_rarity_and_draft_order_with_native_pager(self):
        self.run_lua("""
            G.GAME.draftout_pool.keys={'j_3','j_1','j_2','j_4'}
            original_pool[1].name='Zulu';original_pool[1].rarity=1
            original_pool[2].name='Alpha';original_pool[2].rarity=2
            original_pool[3].name='Beta';original_pool[3].rarity=3
            original_pool[4].name='Alpha';original_pool[4].rarity=1
            create_UIBox_your_collection_jokers()
        """)
        self.assertEqual(self.value('#sort_cycle.options'),4)
        self.assertEqual(self.value('shown()'),'j_1,j_2,j_3,j_4')
        self.assertEqual(self.value('ui==nil'),True)
        for option,expected in [(2,'j_3,j_1,j_2,j_4'),(3,'j_2,j_4,j_3,j_1'),(4,'j_3,j_2,j_4,j_1'),(1,'j_1,j_2,j_3,j_4')]:
            self.run_lua(f'G.FUNCS.draftout_collection_sort({{cycle_config={{current_option={option}}}}})')
            self.assertEqual(self.value('shown()'),expected)
            self.assertEqual(self.value('sort_cycle.current_option'),option)
            self.assertEqual(self.value('last_cycle.current_option'),1)
        self.assertEqual(self.value('table.concat(G.GAME.draftout_pool.keys,",")'),'j_3,j_1,j_2,j_4')
        self.assertTrue(self.value('G.P_CENTER_POOLS.Joker==original_pool and #original_pool==45'))
        self.assertFalse(self.value('original_pool[1].unlocked or original_pool[1].discovered'))

    def test_sort_is_inserted_in_native_card_panel_and_stays_scoped(self):
        self.run_lua('ui=create_UIBox_your_collection_jokers()')
        self.assertEqual(self.value('ui.contents[1].nodes[1].nodes[1].config.opt_callback'),'draftout_collection_sort')
        self.run_lua('G.FUNCS.SMODS_card_collection_page({cycle_config={current_option=3}})')
        self.run_lua('G.FUNCS.draftout_collection_sort({cycle_config={current_option=2}})')
        self.assertEqual(len(self.value('shown()').split(',')),15)
        self.assertEqual(self.value('shown():sub(1,3)'),'j_1')
        self.run_lua('create_UIBox_your_collection_jokers()')
        self.assertEqual(self.value('sort_cycle.current_option'),2,'Reopening same run retains sort')
        self.run_lua('G.STAGE=2;create_UIBox_your_collection_jokers();G.FUNCS.draftout_collection_sort({cycle_config={current_option=4}})')
        self.assertEqual(self.value('compat.sort'),2,'Old controls cannot change unrelated collection')
        self.run_lua("G.STAGE=1;G.GAME.draftout_pool={keys={'j_4','j_2'}};create_UIBox_your_collection_jokers()")
        self.assertEqual(self.value('compat.sort'),1,'New roster starts in Collection order')
        self.assertEqual(self.value('shown()'),'j_2,j_4')

    def test_context_restored_if_native_builder_raises(self):
        self.run_lua("G.ACTIVE_MOD_UI={id='Draftout'}; context=G.ACTIVE_MOD_UI; SMODS.card_collection_UIBox=function() error('native failure') end")
        ok,err=self.run_lua('return pcall(create_UIBox_your_collection_jokers)')
        self.assertFalse(ok);self.assertIn('native failure',err)
        self.assertTrue(self.value('G.ACTIVE_MOD_UI==context'))

if __name__=='__main__': unittest.main(verbosity=2)

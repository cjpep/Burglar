"""Run the supplied PvP 1.0.4 balanced tag implementations through Burglar.

Rendering/materialization and the vanilla Tag dispatcher are mocked; the
ReworkCenter apply functions, Burglar create_card wrapper and copy ledger are real.
"""
import os
from pathlib import Path
import re
import unittest
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
PVP=Path(os.environ.get('DRAFTOUT_PVP_REFERENCE','missing-pvp-reference'))


@unittest.skipUnless((PVP/'rulesets/release.lua').exists(),'Set DRAFTOUT_PVP_REFERENCE')
class NativeRarityTagTests(unittest.TestCase):
    def test_actual_balanced_tag_creation_and_duplicate_caps(self):
        previous=Path.cwd()
        try:
            os.chdir(ROOT)
            lua=LuaRuntime()
            lua.execute("dofile('tests/adapter_spec.lua'); native_tag_reworks={}; PVP={ReworkCenter=function(key,def) native_tag_reworks[key]=def end}")
            source=(PVP/'rulesets/release.lua').read_text()
            for key in ('tag_rare','tag_uncommon'):
                match=re.search(r'PVP\.ReworkCenter\("'+key+r'", \{.*?\n\}\)',source,re.S)
                self.assertIsNotNone(match,key)
                lua.execute(match.group())
            lua.execute('''
                local D=DRAFTOUT
                Tag={apply_to_run=function(self,context)
                    if not self.triggered then return native_tag_reworks[self.key].apply(nil,self,context) end
                end}
                local make=create_card
                create_card=function(...)
                    local c=make(...)
                    c.config={center=G.P_CENTERS[c.key]};c.states={visible=true}
                    c.start_materialize=function(self) self.materialized=true end
                    return c
                end
                create_shop_card_ui=function(card,set,area) card.shop_ui=true end
                local function new_tag(key)
                    return setmetatable({key=key,yep=function(self,_,_,callback) assert(callback()) end,
                        nope=function() error('Eligible drafted Rare must not be denied') end},{__index=Tag})
                end
                G.P_CENTERS.j_blueprint={key='j_blueprint',rarity=3,set='Joker'}
                G.P_CENTERS.j_shortcut={key='j_shortcut',rarity=2,set='Joker'}
                G.P_CENTERS.j_hanging_chad={key='j_hanging_chad',rarity=1,set='Joker'}
                G.P_JOKER_RARITY_POOLS={[3]={G.P_CENTERS.j_blueprint,G.P_CENTERS.j_blueprint}}
                G.jokers={cards={}};G.shop_jokers={cards={}};G.pack_cards={cards={}}
                G.GAME={draftout_pool={keys={'j_blueprint','j_blueprint#2','j_shortcut','j_hanging_chad'},copy_limits=true},used_jokers={}}
                local context={type='store_joker_create',area=G.shop_jokers}
                local first=new_tag('tag_rare');local c=first:apply_to_run(context)
                assert(c.key=='j_blueprint' and c.shop_ui and c.materialized and first.triggered)
                G.shop_jokers.cards[1]=c
                local second=new_tag('tag_rare');local c2=second:apply_to_run(context)
                assert(c2.key=='j_blueprint' and second.triggered)
                G.shop_jokers.cards[2]=c2
                local third=new_tag('tag_rare')
                assert(third:apply_to_run(context).key=='j_joker' and third.triggered)
                c2.removed=true;table.remove(G.shop_jokers.cards,2)
                local fourth=new_tag('tag_rare');assert(fourth:apply_to_run(context).key=='j_blueprint' and fourth.triggered)
                local uncommon=new_tag('tag_uncommon');local u=uncommon:apply_to_run(context)
                assert(u.key=='j_shortcut' and uncommon.triggered and u.shop_ui and u.materialized)
                local exhausted=new_tag('tag_uncommon')
                assert(exhausted:apply_to_run(context).key=='j_joker' and exhausted.triggered)
            ''')
        finally:
            os.chdir(previous)


if __name__=='__main__':unittest.main()

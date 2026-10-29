"""Exercise persistent panel ownership and replacement with a UIBox harness.
Uses the embedded UIBox lifecycle from native tab switching; no GPU rendering.
"""
from pathlib import Path
import unittest
from lupa.luajit21 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
class OverlayTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            G={UIT={ROOT=1,O=2}}; opened=0; removed=0; recalculated=0
            function UIBox(args)
                if fail_build then error('layout failure') end
                return {definition=args.definition,config=args.config,
                    remove=function(self) self.removed=true; removed=removed+1 end}
            end
            function create_UIBox_generic_options(args) return args end
            G.FUNCS={overlay_menu=function(args)
                opened=opened+1
                if G.OVERLAY_MENU then G.OVERLAY_MENU:remove() end
                local panel=UIBox(args)
                local slot=args.definition.contents[1]
                slot.UIBox=panel
                panel.get_UIE_by_ID=function(_,id) if slot.config.id==id then return slot end end
                panel.recalculate=function() recalculated=recalculated+1 end
                G.OVERLAY_MENU=panel
            end}
            owner={}; other={}; screen={n=1,config={},nodes={}}
        ''')
        self.lua.globals().show=self.lua.execute((ROOT/'burglar/overlay.lua').read_text())
    def test_outer_panel_and_cursor_context_survive_many_updates(self):
        self.lua.execute('''show(owner,screen); original=owner.overlay
            for i=1,20 do show(owner,{n=1,config={text=tostring(i)}}) end
            assert(owner.overlay==original and G.OVERLAY_MENU==original)
            assert(opened==1 and recalculated==20 and removed==20)
            assert(original:get_UIE_by_ID('draftout_live_content').config.object.definition.nodes[1].config.text=='20')
        ''')
    def test_another_menu_is_not_mistaken_for_our_panel(self):
        self.lua.execute('show(owner,screen); show(other,screen); show(owner,screen); assert(opened==3)')
    def test_failed_replacement_keeps_old_content(self):
        self.lua.execute("show(owner,screen); old=owner.overlay:get_UIE_by_ID('draftout_live_content').config.object; fail_build=true")
        ok,_=self.lua.execute('return pcall(show,owner,screen)')
        self.assertFalse(ok)
        self.lua.execute("assert(not old.removed and owner.overlay:get_UIE_by_ID('draftout_live_content').config.object==old)")
if __name__=='__main__': unittest.main(verbosity=2)

"""Outline geometry and drawing-state checks; no GPU rendering."""
from pathlib import Path
import unittest
from lupa.luajit21 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
class BorderTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            clock=0;depth=0;lines={};original_draws=0
            love={timer={getTime=function() return clock end},graphics={}}
            local lg=love.graphics
            lg.push=function() depth=depth+1 end
            lg.pop=function() depth=depth-1;assert(depth>=0) end
            lg.setShader=function() end;lg.setLineStyle=function() end
            lg.setLineWidth=function() end;lg.setColor=function() end
            lg.line=function(x,y,xx,yy) lines[#lines+1]={x,y,xx,yy} end
            prep_draw=function() depth=depth+1 end
            node={states={visible=true},VT={w=9,h=6},draw=function() original_draws=original_draws+1;return 42 end}
            box={get_UIE_by_ID=function(_,id) assert(id=='draftout_border_surface');return node end}
            owner={mod={config={}},overlay={}};G={SETTINGS={},OVERLAY_MENU=owner.overlay}
        ''')
        self.lua.globals().B=self.lua.execute((ROOT/'burglar/border.lua').read_text())
    def test_path_wraps_and_stays_on_stepped_perimeter(self):
        self.lua.execute('''
            local p=B.path(9,6)
            for i=0,1000 do
                local d=p.total*i/1000
                local x,y=B.point(p,d);local xx,yy=B.point(p,d+p.total)
                assert(math.abs(x-xx)<0.000001 and math.abs(y-yy)<0.000001)
                assert(x>=0 and x<=9 and y>=0 and y<=6)
                assert(x<=0.1 or x>=8.9 or y<=0.1 or y>=5.9)
            end
        ''')
    def test_draw_restores_stack_animates_and_caches_resized_geometry(self):
        self.lua.execute('''
            B.attach(box,owner);local draw=node.draw;B.attach(box,owner);assert(draw==node.draw)
            assert(node:draw()==42 and depth==0 and original_draws==1 and #lines==84)
            local p=node.draftout_border_path;local first=lines[83]
            clock=1;lines={};node:draw();assert(node.draftout_border_path==p and depth==0)
            assert(first[1]~=lines[83][1] or first[2]~=lines[83][2])
            node.VT.w=7;node:draw();assert(node.draftout_border_path~=p and depth==0)
            assert(owner.border_started==0)
        ''')
    def test_reduced_motion_effects_off_and_hidden_menu(self):
        self.lua.execute('''
            B.attach(box,owner);G.SETTINGS.reduced_motion=true;node:draw();assert(#lines==20 and depth==0)
            G.SETTINGS.reduced_motion=false;owner.mod.config.pack_effects=false
            lines={};clock=5;node:draw();assert(#lines==20)
            lines={};G.OVERLAY_MENU={};node:draw();assert(#lines==0 and depth==0)
            G.OVERLAY_MENU=owner.overlay;node.states.visible=false;node:draw();assert(#lines==0)
        ''')
if __name__=='__main__':unittest.main()

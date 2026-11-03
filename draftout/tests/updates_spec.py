"""One Draftout update hook, ordered callbacks and native return preservation."""
from pathlib import Path
import unittest
from lupa.luajit21 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute("Game={update=function(self,dt) steps='native'; return 17,nil,'third' end}; D={}")
        self.lua.globals().make=self.lua.execute((ROOT/'draftout/updates.lua').read_text())
    def test_one_hook_and_ordered_callbacks_preserve_all_returns(self):
        self.lua.execute("u=make(D); wrapped=Game.update; assert(make(D)==u and Game.update==wrapped); u.add('one',function() steps=steps..',one' end); u.add('two',function() steps=steps..',two' end)")
        self.assertEqual(self.lua.execute('return Game:update(0.1)'),(17,None,'third'))
        self.assertEqual(self.lua.eval('steps'),'native,one,two')
    def test_native_zero_returns_remain_zero_returns(self):
        self.lua.execute("Game.update=function() end; make(D); assert(select('#',Game:update(0.1))==0)")
    def test_duplicate_callback_registration_is_an_explicit_error(self):
        self.lua.execute("u=make(D); u.add('one',function() end)")
        ok,err=self.lua.execute("return pcall(u.add,'one',function() end)")
        self.assertFalse(ok);self.assertIn('Duplicate Draftout',err)
if __name__=='__main__': unittest.main(verbosity=2)

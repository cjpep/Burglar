"""Custom pools over the real MPAPI action dispatch and simulated relay."""
import json
import unittest
from mpapi_spec import Bus

class CubeTests(unittest.TestCase):
    def install_file(self,c,keys):
        c.lua.globals().cube_text=json.dumps({'version':1,'name':'Test cube','jokers':keys})
        c.lua.globals().decode_cube=lambda value:c.lua.table_from(json.loads(value),recursive=True)
        c.run("""
            D.mod.path='test/';D.mod.config.draft_cube='test_cube.json'
            NFS={read=function(path) assert(path=='test/cubes/test_cube.json');return cube_text end,
                getDirectoryItems=function() return {'test_cube.json','ignore.lua','bad.name.json'} end}
            MPAPI.json_decode=decode_cube
        """)

    def test_host_only_file_sync_and_complete_unique_draft(self):
        bus=Bus();host=bus.clients[0];keys=host.value('keys')[:40]
        self.install_file(host,keys)
        host.run('D.mod.config.packs_per_player=1')
        for guest in bus.clients[1:]:guest.run("D.mod.config.draft_cube='not_on_this_computer.json'")
        bus.draft()
        all_picks=[]
        for c in bus.clients:
            self.assertEqual(c.value('B.cube_name'),'Test cube')
            self.assertEqual(c.value('B.catalog_keys'),sorted(keys))
            pool=c.value('B.pool.keys');self.assertEqual(len(pool),9)
            self.assertTrue(set(pool)<=set(keys));all_picks.extend(pool)
        self.assertEqual(len(set(all_picks)),36)
        host.run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
        for c in bus.clients:self.assertEqual(c.value('run_pool.keys'),c.value('B.pool.keys'))

    def test_duplicate_cube_roundtrip_and_saved_rosters(self):
        bus=Bus();host=bus.clients[0]
        self.install_file(host,['j_blueprint']*36)
        host.run('D.mod.config.packs_per_player=1')
        bus.draft()
        ids=[]
        for c in bus.clients:
            self.assertTrue(c.value('B.pool.copy_limits'))
            pool=c.value('B.pool.keys');self.assertEqual(len(pool),9);ids.extend(pool)
            c.run("G.P_CENTERS.j_blueprint={set='Joker',rarity=3};assert(loadfile(root..'/burglar/roster_duel.lua'))()(D);D.roster_duel.capture()")
            self.assertTrue(c.value('D.mod.config.bracket_roster.copy_limits'))
        self.assertEqual(len(set(ids)),36)
        host.run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
        for c in bus.clients:
            self.assertTrue(c.value('run_pool.copy_limits'))
        # Host checkpoint serialization includes distinct copy IDs in its recap.
        self.assertTrue(host.value('D.average_pvp.active()'))

    def test_prepared_pool_is_frozen_when_file_changes(self):
        bus=Bus();host=bus.clients[0];keys=host.value('keys')[:40]
        self.install_file(host,keys);host.run('D.mod.config.packs_per_player=1');bus.begin()
        host.lua.globals().cube_text='bad json now'
        host.run('B.start_draft()');bus.flush()
        self.assertEqual(host.value('B.catalog_keys'),sorted(keys))
        self.assertEqual(host.value('B.phase'),'draft')

    def test_bad_files_and_insufficient_capacity_do_not_begin(self):
        bus=Bus();host=bus.clients[0];keys=host.value('keys')[:40]
        self.install_file(host,keys)
        ok,err=host.run('return pcall(B.begin)')
        self.assertFalse(ok);self.assertIn('need 108',err)
        host.run('D.mod.config.packs_per_player=1')
        for data in [dict(version=1,jokers=['j_ring_master']),
                     dict(version=1,jokers=[]),dict(version=2,jokers=keys)]:
            host.lua.globals().cube_text=json.dumps(data)
            self.assertFalse(host.run('return pcall(B.begin)')[0])
        host.lua.globals().cube_text='invalid json'
        self.assertFalse(host.run('return pcall(B.begin)')[0])
        host.run("D.mod.config.draft_cube='../outside.json'")
        self.assertFalse(host.run('return pcall(B.begin)')[0])
        self.assertEqual(host.value('B.phase'),'idle')
        self.assertEqual(host.value('D.cubes.choices()'),['default','test_cube.json'])

    def test_guest_rejects_unavailable_host_joker(self):
        bus=Bus();host=bus.clients[0];keys=host.value('keys')[:40]
        self.install_file(host,keys);host.run('D.mod.config.packs_per_player=1')
        guest=bus.clients[1]
        guest.run('local base=D.catalog;D.catalog=function() local k=base();table.remove(k,1);return k end')
        bus.begin()
        self.assertEqual(guest.value('B.phase'),'error')
        self.assertFalse(host.value("B.hello.p2==true"))

if __name__=='__main__':unittest.main()

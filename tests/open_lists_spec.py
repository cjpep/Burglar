"""Open lists through actual MPAPI action dispatch; the relay is simulated."""
import copy
import unittest
from mpapi_spec import Bus
import cubes_spec


class OpenListsTests(unittest.TestCase):
    def send_view(self, client, data, sender='p1'):
        client.receive({'cid':'open-list-test','action':'draftout_pack_v4','from':sender,
            'to':f'p{client.index}','params':{'packet':{
                'protocol':4,'kind':'view','room':'ROOM','session':client.value('B.session'),
                'recipient':f'p{client.index}','data':data}}})

    def test_default_off_never_sends_opponent_lists(self):
        bus=Bus();bus.draft()
        for _,packet in bus.views:
            self.assertFalse(packet['data']['open_deck_lists'])
            self.assertNotIn('open_rosters',packet['data'])
        for c in bus.clients:
            c.run("D.mode='mp'")
            self.assertFalse(c.value('D.open_lists.available()'))

    def test_enabled_reveals_complete_lists_for_two_and_four_players(self):
        for players in (2,4):
            with self.subTest(players=players):
                bus=Bus(player_count=players);host=bus.clients[0]
                host.run('D.mod.config.open_deck_lists=true;D.mod.config.packs_per_player=4')
                bus.draft()
                expected=host.value('B.host_state.pools')
                for _,packet in bus.views:
                    data=packet['data']
                    self.assertTrue(data['open_deck_lists'])
                    if data['done']:self.assertEqual(data['open_rosters'],expected)
                    else:self.assertNotIn('open_rosters',data)
                for c in bus.clients:
                    c.run("D.mode='mp'")
                    self.assertTrue(c.value('D.open_lists.available()'))
                    self.assertEqual(c.value('B.view.open_rosters'),expected)
                    self.assertEqual(c.value('B.pool.keys'),expected[c.index-1])
                    self.assertEqual(len(c.value('B.pool.keys')),35)
                    c.run('G.FUNCS.draftout_open_lists()')
                    self.assertTrue(c.value('D.open_lists.open'))
                host.run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
                for c in bus.clients:
                    self.assertFalse(c.value('D.open_lists.available()'))
                    self.assertFalse(c.value('D.open_lists.open'))
                    self.assertEqual(c.value('run_pool.keys'),expected[c.index-1])

    def test_duplicate_copies_are_reviewed_as_separate_entries(self):
        bus=Bus();host=bus.clients[0]
        cubes_spec.CubeTests().install_file(host,['j_blueprint']*36)
        host.run('D.mod.config.open_deck_lists=true;D.mod.config.packs_per_player=1')
        bus.draft()
        for c in bus.clients:
            rosters=c.value('B.view.open_rosters')
            self.assertTrue(all(len(r)==9 for r in rosters))
            self.assertEqual(len({key for r in rosters for key in r}),36)
            self.assertTrue(c.value('B.pool.copy_limits'))

    def test_reject_early_reveal_changed_setting_and_guest_forgery(self):
        bus=Bus();bus.begin();host,guest=bus.clients[:2]
        host.run('D.mod.config.open_deck_lists=true;B.start_draft()');bus.flush()
        original=guest.value('B.view')
        for change in ({'open_rosters':[['j_blueprint']]}, {'open_deck_lists':False},
                       {'open_deck_lists':'true'}):
            data=copy.deepcopy(original);data.update(change);data['revision']=999
            self.send_view(guest,data)
            self.assertEqual(guest.value('B.view.revision'),original['revision'])
        data=copy.deepcopy(original);data['revision']=999
        self.send_view(guest,data,sender='p3')
        self.assertEqual(guest.value('B.view.revision'),original['revision'])
        # A subsequent refresh keeps the setting captured at draft start.
        host.run("D.mod.config.open_deck_lists=false")
        guest.run("B.transport.send({protocol=4,kind='refresh',session=B.session,room='ROOM',recipient='p1',data={}},'p1')")
        bus.flush()
        self.assertTrue(guest.value('B.view.open_deck_lists'))

    def test_reject_malformed_completed_lists_and_accept_refresh(self):
        bus=Bus();bus.clients[0].run('D.mod.config.open_deck_lists=true');bus.draft()
        guest=bus.clients[1];original=guest.value('B.view')
        variants=[]
        data=copy.deepcopy(original);del data['open_rosters'];variants.append(data)
        data=copy.deepcopy(original);data['open_rosters'][0].pop();variants.append(data)
        data=copy.deepcopy(original);data['open_rosters'][0][0]='j_not_in_catalog';variants.append(data)
        data=copy.deepcopy(original);data['open_rosters'][0][0]=data['open_rosters'][2][0];variants.append(data)
        data=copy.deepcopy(original);data['open_rosters'][1].reverse();variants.append(data)
        data=copy.deepcopy(original);data['open_rosters'].append([]);variants.append(data)
        for data in variants:
            data['revision']=999
            self.send_view(guest,data)
            self.assertEqual(guest.value('B.view.revision'),original['revision'])
        self.send_view(guest,original)
        self.assertEqual(guest.value('B.view.open_rosters'),original['open_rosters'])
        guest.run("D.mode='mp';G.FUNCS.draftout_open_lists();current._destroyed=true")
        self.assertFalse(guest.value('D.open_lists.available()'))
        # Stale UI must not render cached opponent cards after lobby teardown.
        self.assertIsNotNone(guest.value('D.open_lists.screen()'))


if __name__=='__main__':unittest.main()

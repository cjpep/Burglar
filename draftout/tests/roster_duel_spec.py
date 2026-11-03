"""Saved roster rounds through the actual MPAPI action/metadata/start flow.
Server relay and renderer remain mocked; native PvP owns combat.
"""
import copy
import json
import unittest
import mpapi_spec as api


@unittest.skipUnless((api.API/'api/lobby/state.lua').exists() and (api.PVP/'pvp_api/flow.lua').exists(),
                     'Provide MultiplayerAPI/PvP 1.0.0 references')
class RosterDuelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source=api.Bus();source.draft()
        cls.tickets=[]
        for c in source.clients:
            cls.attach(c)
            c.run('D.roster_duel.capture()')
            cls.tickets.append(c.value('D.mod.config.bracket_roster'))

    @staticmethod
    def attach(c):
        c.lua.globals().python_json_decode=lambda value: c.lua.table_from(json.loads(value),recursive=True)
        c.run("for _,key in ipairs(keys) do G.P_CENTERS[key]={key=key,set='Joker',rarity=1} end;MPAPI.json_decode=python_json_decode; D.now=function()return clock end; assert(loadfile(root..'/draftout/roster_duel.lua'))()(D)")

    def lobby(self, seats=(0,1)):
        bus=api.Bus(player_count=2)
        for c,seat in zip(bus.clients,seats):
            self.attach(c)
            c.lua.globals().saved_ticket=c.lua.table_from(copy.deepcopy(self.tickets[seat]),recursive=True)
            c.run("current._metadata.queue_mode='pvp_nemesis';D.mod.config.bracket_roster=saved_ticket")
        return bus

    def agree(self,bus):
        bus.clients[0].run('D.roster_duel.enable()');bus.flush()
        bus.clients[1].run('D.roster_duel.enable()')
        for _ in range(3):
            for c in bus.clients:c.run('clock=clock+2;Game:update(0.02)')
            bus.flush()
        self.assertTrue(bus.clients[0].run('return D.roster_duel.ready()')[0])

    def test_export_import_roundtrip_and_validation_before_save(self):
        bus=self.lobby();c=bus.clients[0]
        code=c.run('return D.roster_duel.export()')
        self.assertTrue(code.startswith('DRAFTROSTER1:'))
        self.assertNotIn('session',code)
        self.assertNotIn('Player1',code)
        c.lua.globals().code=code;c.run('D.mod.config.bracket_roster=nil;D.roster_duel.import(code)')
        self.assertEqual(c.value('D.mod.config.bracket_roster'),self.tickets[0])
        for bad in ('garbage','DRAFTROSTER1:'+('x'*8000),'DRAFTROSTER1:{}'):
            c.lua.globals().code=bad
            self.assertFalse(c.run('return pcall(D.roster_duel.import,code)')[0])
            self.assertEqual(c.value('D.mod.config.bracket_roster'),self.tickets[0])
        for change in ('t.keys[1]=t.keys[2]',"t.keys[1]='j_ring_master'",'t.seat=5','t.keys[28]=t.keys[1]'):
            c.run('t=D.core.copy(D.mod.config.bracket_roster);'+change)
            self.assertFalse(c.run('return pcall(D.roster_duel.validate,t)')[0])

    def test_explicit_consent_starts_fresh_native_duels_with_original_rosters(self):
        for seats in ((0,1),(2,3),(0,2)):
            bus=self.lobby(seats);host,guest=bus.clients
            self.agree(bus)
            host.run('PVP.pvp_start_match()');bus.flush()
            self.assertEqual(len(bus.starts),1)
            self.assertEqual(bus.starts[0]['params']['options']['queue_mode'],'pvp_nemesis')
            for c,seat in zip(bus.clients,seats):
                self.assertEqual(c.value('game_starts'),1)
                self.assertEqual(c.value('run_pool.keys'),self.tickets[seat]['keys'])
                self.assertEqual(c.value('run_pool.source'),'draftout_bracket')
                self.assertEqual(c.value('PVP.LOBBY.config.starting_lives'),4)
                self.assertFalse(c.value('D.average_pvp.active()'))
                self.assertTrue(c.value('PVP.referee_resolve_2p_round==native_two_player_resolver'))
            # Match end disarms the lobby, keeping only the reusable ticket.
            for c in bus.clients:c.run("current:_fire('game_ended',{runId='run-1'});")
            bus.flush()
            for c,seat in zip(bus.clients,seats):
                self.assertFalse(c.value('D.roster_duel.enabled'))
                self.assertIsNone(c.run('return B.prepare_run()'))
                self.assertEqual(c.value('D.mod.config.bracket_roster'),self.tickets[seat])

    def test_unarmed_normal_lobby_does_not_inherit_roster(self):
        bus=self.lobby();host=bus.clients[0]
        host.run('PVP.pvp_start_match()');bus.flush()
        self.assertEqual(len(bus.starts),1)
        for c in bus.clients:self.assertIsNone(c.value('run_pool'))

    def test_native_full_match_and_fresh_next_round_keep_only_roster(self):
        bus=self.lobby();host=bus.clients[0];self.agree(bus)
        host.run('PVP.pvp_start_match()');bus.flush()
        wire=api.ApiTests.wire
        for ante in range(2,6):
            for i,c in enumerate(bus.clients,1):
                c.run(f'G.GAME.round_resets={{ante={ante}}};G.GAME.round={ante*3};test_pvp=true')
                wire(self,bus,i,'setAnte',ante=ante)
                wire(self,bus,i,'newRound')
                wire(self,bus,i,'readyBlind',startingHands=4)
            wire(self,bus,2,'playHand',score='100',handsLeft=0)
            wire(self,bus,1,'playHand',score='200',handsLeft=3)
            self.assertEqual(host.value('PVP.REF.players.p2.lives'),5-ante)
            self.assertEqual(host.value('PVP.REF.players.p1.hands_left'),3,'Native early finish retained')
        self.assertEqual(api.ApiTests.outcome_count(self,host,'pvp_win'),1)
        for c in bus.clients:
            c.run("MPAPI._internal.lobby.apply_game_ended(current,{runId='run-1',status='agreed'})")
        bus.flush()
        self.agree(bus)
        host.run('PVP.pvp_start_match()');bus.flush()
        self.assertEqual(host.value('PVP.REF.players.p1.lives'),4)
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),4)
        for i,c in enumerate(bus.clients):self.assertEqual(c.value('run_pool.keys'),self.tickets[i]['keys'])

    def test_one_sided_consent_cannot_start_and_disable_restores_normal_start(self):
        bus=self.lobby();host=bus.clients[0]
        host.run('D.roster_duel.enable()');bus.flush()
        host.run('PVP.pvp_start_match()');bus.flush()
        self.assertEqual(len(bus.starts),0)
        host.run('D.roster_duel.disable()');bus.flush()
        host.run('PVP.pvp_start_match()');bus.flush()
        self.assertEqual(len(bus.starts),1)
        self.assertIsNone(host.value('run_pool'))

    def test_mismatched_duplicate_or_overlapping_rosters_never_arm(self):
        for change in ("D.mod.config.bracket_roster.event='other-draft'",'D.mod.config.bracket_roster.seat=1',
                       "D.mod.config.bracket_roster.keys[1]='%s'"%self.tickets[0]['keys'][0]):
            bus=self.lobby();host,guest=bus.clients
            guest.run(change)
            host.run('D.roster_duel.enable()');bus.flush();guest.run('D.roster_duel.enable()')
            for c in bus.clients:c.run('clock=clock+2;Game:update(0.02)')
            bus.flush();host.run('PVP.pvp_start_match()');bus.flush()
            self.assertEqual(len(bus.starts),0)

    def test_dropped_consent_retries_and_lobby_change_clears_activation(self):
        bus=self.lobby();host,guest=bus.clients;dropped=[False]
        def drop(sender,packet):
            if packet.get('params',{}).get('packet',{}).get('kind')=='bracket_consent' and not dropped[0]:
                dropped[0]=True;return True
            return False
        bus.drop=drop;self.agree(bus);self.assertTrue(dropped[0])
        for c in bus.clients:
            c.run("new_lobby('MultiplayerPvP','private','pvp_nemesis');Game:update(0.02)")
            self.assertFalse(c.value('D.roster_duel.enabled'))
            self.assertIsNone(c.run('return B.prepare_run()'))

    def test_ranked_public_royale_and_wrong_player_counts_rejected(self):
        for setup in ("current.type='public'","current._metadata.queue_mode='pvp_royale'",
                      "current._players.p3={id='p3'}"):
            bus=self.lobby();c=bus.clients[0];c.run(setup)
            self.assertFalse(c.run('return pcall(D.roster_duel.enable)')[0])


if __name__=='__main__':unittest.main()

"""Two real clients through MPAPI actions; no phantom seats or referee resets."""
import copy
import unittest
import mpapi_spec as api


@unittest.skipUnless((api.API/'api/lobby/state.lua').exists() and (api.PVP/'pvp_api/flow.lua').exists(),
                     'Provide MultiplayerAPI/PvP 1.0.0 references')
class TwoPlayerTests(unittest.TestCase):
    wire = api.ApiTests.wire
    wire_open = api.ApiTests.wire_open
    outcome_count = api.ApiTests.outcome_count
    finish_match = api.ApiTests.finish_match

    def start_match(self, native=False):
        bus=api.Bus(player_count=2,checkpoints=True,native_outcomes=native)
        bus.clients[0].run('D.mod.config.picks_per_turn=1')
        bus.draft()
        bus.clients[0].run('PVP.pvp_start_match();Game:update(0.02)')
        bus.flush()
        return bus

    def test_two_player_drafts_all_pack_and_pick_options(self):
        for rounds in (1,2,3,4):
            for picks in (1,2):
                with self.subTest(rounds=rounds,picks=picks):
                    bus=api.Bus(player_count=2);host=bus.clients[0]
                    host.run(f'D.mod.config.packs_per_player={rounds};D.mod.config.picks_per_turn={picks}')
                    bus.begin();host.run('B.start_draft()');bus.flush()
                    while not host.value('B.host_state.done'):
                        for seat,c in enumerate(bus.clients,1):
                            view=c.value('B.view');r,p=view['round'],view['pick']
                            origin=((seat-1-(p-1)*(1 if r%2 else -1))%2)+1
                            self.assertEqual(view['player_count'],2)
                            self.assertEqual(len(view['roster']),2)
                            self.assertEqual(view['token']['pack_id'],f'r{r}s{origin}')
                            self.assertNotIn('pools',view)
                            c.run('local choices={};for i=1,math.min(B.view.picks_per_turn,#B.view.cards) do choices[i]=B.view.cards[i] end;B.pick(choices,B.view.token)')
                            bus.flush()
                    size=35 if rounds==4 else 9*rounds
                    pools=[c.value('B.pool.keys') for c in bus.clients]
                    self.assertEqual([len(p) for p in pools],[size,size])
                    self.assertEqual(len(set(pools[0]+pools[1])),2*size)
                    self.assertEqual(host.value('B.host_state.total'),2*size)
                    self.assertTrue(host.value('B.launch_ready()'))
                    host.run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
                    self.assertEqual(len(bus.starts),1)
                    self.assertEqual([c.value('run_pool.keys') for c in bus.clients],pools)
                    self.assertTrue(all(c.value('D.average_pvp.duel') for c in bus.clients))
                    self.finish_match(bus,order=(1,0))
                    for c in bus.clients:
                        recap=c.value('D.mod.config.last_recap')
                        self.assertEqual(len(recap['players']),2)
                        self.assertEqual(len(recap['omitted']),141-2*size)

    def test_two_player_timeout_finishes_without_missing_seats(self):
        bus=api.Bus(player_count=2);host,guest=bus.clients
        host.run("D.mod.config.pick_seconds='scaling';D.mod.config.picks_per_turn=1")
        bus.begin();host.run('B.start_draft()');bus.flush()
        wanted=guest.value('B.view.cards[4]')
        guest.run('B.intent({B.view.cards[4]},B.view.token,1)');bus.flush()
        turns=0
        while not host.value('B.host_state.done'):
            turns+=1;self.assertLessEqual(turns,27)
            host.run('clock=clock+50;Game:update(0.02)');bus.flush()
        self.assertEqual(turns,27)
        self.assertEqual(guest.value('B.pool.keys[1]'),wanted)
        self.assertTrue(host.value('B.launch_ready()'))

    def test_fifty_ties_then_full_duel_to_one_winner_with_native_outcomes(self):
        bus=self.start_match(native=True);host=bus.clients[0]
        pools=[c.value('run_pool.keys') for c in bus.clients]
        self.assertTrue(host.value('PVP.referee_resolve_2p_round==native_two_player_resolver'))
        for ante in range(2,52):
            self.wire_open(bus,ante)
            for i in (1,2):self.wire(bus,i,'playHand',score='1e300',handsLeft=0)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),50)
        lives=[4,4]
        for ante,loser in enumerate((1,2,1,2,1,2,2),52):
            self.wire_open(bus,ante)
            self.wire(bus,loser,'playHand',score='100',handsLeft=0)
            winner=3-loser
            self.wire(bus,winner,'playHand',score='200',handsLeft=3)
            lives[loser-1]-=1
            for c in bus.clients:
                self.assertEqual([c.value(f'client_lives.p{i}') for i in (1,2)],lives)
                self.assertTrue(c.value('D.average_pvp.duel'))
                self.assertEqual(c.value('D.average_pvp.view.mode'),'duel')
            self.assertEqual(host.value(f'PVP.REF.players.p{winner}.hands_left'),3,'Native early finish stays intact')
        self.assertEqual(lives,[1,0])
        self.assertEqual(self.outcome_count(host,'pvp_start_blind'),57)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),56)
        self.assertEqual(self.outcome_count(host,'pvp_win'),1)
        for c in bus.clients:self.assertEqual(c.value('server_results'),['p1'])
        self.assertEqual([c.value('run_pool.keys') for c in bus.clients],pools)
        self.finish_match(bus)
        for c in bus.clients:
            self.assertTrue(c.value('D.recap.available()'))
            self.assertEqual(len(c.value('D.mod.config.last_recap.players')),2)

    def test_duplicate_and_stale_scores_do_not_resolve_next_duel(self):
        bus=self.start_match();host,guest=bus.clients
        self.wire_open(bus,2)
        self.wire(bus,1,'playHand',score='200',handsLeft=3)
        guest.run("Client.send({action='playHand',score='100',handsLeft=0})")
        sender,packet=copy.deepcopy(bus.queue[0]);bus.flush()
        envelope=copy.deepcopy(packet);envelope['from']=sender
        self.wire(bus,2,'newRound')
        for c in bus.clients:c.receive(copy.deepcopy(envelope))
        bus.flush()
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),3)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),1)
        self.wire_open(bus,3)
        # Also reject an old-round report even with a new sequence number.
        envelope['params']['_draftout']['seq']+=10000
        for c in bus.clients:c.receive(copy.deepcopy(envelope))
        bus.flush()
        self.assertEqual(host.value('PVP.REF.players.p2.hands_left'),4)
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),3)
        self.assertTrue(host.value('D.average_pvp.rounds.open'))
        self.wire(bus,1,'playHand',score='200',handsLeft=3)
        self.wire(bus,2,'playHand',score='100',handsLeft=0)
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),2,'Stale sequence cannot block fresh reports')

    def test_two_player_ready_and_start_retry(self):
        for dropped_action in ('pvp_ready_blind','pvp_start_blind'):
            with self.subTest(dropped_action=dropped_action):
                bus=self.start_match();host,guest=bus.clients
                dropped=[False]
                def drop(sender,packet):
                    if packet.get('action')==dropped_action and not dropped[0]:
                        dropped[0]=True;return True
                    return False
                bus.drop=drop
                for i,c in enumerate(bus.clients,1):
                    c.run("G.GAME.round_resets={ante=2};G.GAME.round=6;G.GAME.blind_on_deck='Boss';test_pvp=true;PVP.GAME.ready_blind=true")
                    self.wire(bus,i,'setAnte',ante=2)
                    self.wire(bus,i,'newRound')
                    self.wire(bus,i,'readyBlind',startingHands=4)
                for c in bus.clients:c.run('clock=clock+3;Game:update(0.02)')
                bus.flush()
                self.assertTrue(dropped[0])
                for c in bus.clients:self.assertEqual(self.outcome_count(c,'pvp_start_blind'),1)
                self.wire(bus,1,'playHand',score='100',handsLeft=0)
                self.wire(bus,2,'playHand',score='200',handsLeft=3)
                self.assertEqual(host.value('PVP.REF.players.p1.lives'),3)

    def test_host_or_guest_departure_awards_survivor_once_and_recovers_recap(self):
        for host_leaves in (False,True):
            with self.subTest(host_leaves=host_leaves):
                bus=self.start_match(native=True);host,guest=bus.clients
                expected=host.value('D.recap.context.payload')
                self.wire_open(bus,2)
                if host_leaves:
                    bus.handover(1,2);survivor=guest;winner='p2'
                else:
                    bus.offline.add(2)
                    host.run("MPAPI._internal.lobby.apply_event(current,{type='player_left',playerId='p2'})")
                    bus.flush();survivor=host;winner='p1'
                self.assertEqual(self.outcome_count(survivor,'pvp_win'),1)
                self.assertEqual(survivor.value('server_results'),[winner])
                self.assertEqual(survivor.value(f'PVP.REF.players.{winner}.lives'),4)
                self.finish_match(bus)
                self.assertEqual(survivor.value('D.mod.config.last_recap'),expected)

    def test_ante_one_failure_costs_one_life_and_ante_two_is_a_duel(self):
        bus=self.start_match();host,guest=bus.clients
        for i,c in enumerate(bus.clients,1):
            c.run("G.GAME.round_resets={ante=1};G.GAME.round=3;G.GAME.blind_on_deck='Boss';test_pvp=false")
            self.wire(bus,i,'setAnte',ante=0)
        self.wire(bus,2,'newRound');self.wire(bus,2,'failRound')
        self.wire(bus,2,'newRound');self.wire(bus,2,'failRound')
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),3)
        self.assertEqual(self.outcome_count(host,'pvp_start_blind'),0)
        self.wire_open(bus,2)
        self.assertTrue(host.value('D.average_pvp.rounds.duel'))

    def test_unsupported_counts_and_roster_changes_require_new_check(self):
        for count in (1,3,5):
            bus=api.Bus(player_count=count)
            ok,error=bus.clients[0].run('return pcall(B.begin)')
            self.assertFalse(ok)
            self.assertIn('Exactly two or four players',error)
        bus=api.Bus(player_count=2);bus.begin();host=bus.clients[0]
        host.run("current._players.p3={id='p3',displayName='Third'};Game:update(0.02)")
        self.assertFalse(host.value('B.matches()'))
        self.assertEqual(host.value('B.phase'),'error')


if __name__=='__main__':
    unittest.main()

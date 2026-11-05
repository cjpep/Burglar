"""1.0.5 regression simulations: actual startup, action dispatch and ready handshake.
Rendering, Steam, the server, and event timing are simulated; no live playtest.
"""
import copy
import unittest
import mpapi_spec as api
from mpapi_spec import Bus, PVP
import roster_duel_spec as roster

@unittest.skipUnless((PVP/'lib/ready_check.lua').exists(), 'Requires supplied Multiplayer 1.0.5')
class Compatibility105Tests(unittest.TestCase):
    wire = api.ApiTests.wire
    wire_open = api.ApiTests.wire_open
    outcome_count = api.ApiTests.outcome_count

    def start(self, players=4, cocktail=False):
        bus=Bus(player_count=players, native_startup=True, native_outcomes=True)
        if cocktail:
            bus.clients[0].run("test_recipe={name='Test recipe',decks={'b_red','b_blue'}}")
        bus.draft()
        bus.clients[0].run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
        return bus

    def test_native_startup_two_three_four_players_and_cocktail(self):
        for n in (2,3,4):
            bus=self.start(n,cocktail=True)
            for c in bus.clients:
                self.assertEqual(c.value('game_starts'),1)
                self.assertEqual(c.value('run_pool.keys'),c.value('B.pool.keys'))
                self.assertEqual(c.value('PVP.LOBBY.deck.cocktail_recipe.decks'),['b_red','b_blue'])
                self.assertTrue(c.value('B.hooks_ready'))
            self.wire_open(bus,2)
            for i in range(1,n+1):self.wire(bus,i,'playHand',score='100',handsLeft=0)
            self.assertFalse(bus.clients[0].value('D.average_pvp.rounds.open'))

    def test_actual_startup_long_ffa_then_native_final_duel(self):
        bus=self.start();host=bus.clients[0]
        for ante in range(2,14):
            self.wire_open(bus,ante)
            for i in range(1,5):self.wire(bus,i,'playHand',score='100',handsLeft=0)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),12)
        # Eliminate two players through real score reports, then retain the
        # upstream early-finish comparison for the last pair.
        for ante,loser in enumerate([4]*4+[3]*4,14):
            ids=self.wire_open(bus,ante)
            for i in ids:self.wire(bus,i,'playHand',score='0' if i==loser else '100',handsLeft=0)
        for ante in range(22,26):
            self.wire_open(bus,ante)
            self.wire(bus,2,'playHand',score='100',handsLeft=0)
            self.wire(bus,1,'playHand',score='200',handsLeft=3)
        self.assertEqual(self.outcome_count(host,'pvp_win'),1)
        self.assertTrue(host.value('PVP.referee_resolve_2p_round==native_two_player_resolver'))
        self.assertEqual(host.value('PVP.REF.players.p1.lives'),4)
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),0)

    def test_native_startup_host_departure(self):
        bus=self.start();self.wire_open(bus,2)
        for i in (1,2):self.wire(bus,i,'playHand',score='100',handsLeft=0)
        bus.handover(1,2)
        for i in (3,4):self.wire(bus,i,'playHand',score='100',handsLeft=0)
        host=bus.clients[1]
        self.assertFalse(host.value('D.average_pvp.rounds.open'))
        self.assertEqual(host.value('PVP.REF.players.p1.lives'),0)
        for i in (2,3,4):self.assertEqual(host.value(f'PVP.REF.players.p{i}.lives'),4)

    def native_pair(self, tickets):
        bus=Bus(player_count=2,native_startup=True)
        for c,ticket in zip(bus.clients,tickets):
            roster.RosterDuelTests.attach(c)
            c.lua.globals().ticket=c.lua.table_from(copy.deepcopy(ticket),recursive=True)
            c.run("current._metadata.queue_mode='pvp_nemesis';D.mod.config.bracket_roster=ticket")
            # Keep timer events queued so a stale Ready is resolved by real acks,
            # not the upstream two-second backwards-compatibility timeout.
            c.run('''
                G.STATES.BLIND_SELECT=3;G.STATES.SELECTING_HAND=4
                Event=function(e)return e end
                events={};G.E_MANAGER={add_event=function(_,e)events[#events+1]=e end}
            ''')
        roster.RosterDuelTests.agree(self,bus)
        bus.clients[0].run('PVP.pvp_start_match()');bus.flush()
        return bus

    def ready_pair(self,bus,ante,refuse=False):
        for i,c in enumerate(bus.clients,1):
            c.run(f'G.GAME.round_resets={{ante={ante}}};G.GAME.round={ante*3};test_pvp=true;PVP.GAME.ready_blind=true;G.STATE=G.STATES.BLIND_SELECT')
            if refuse and i==2:c.run('G.STATE=G.STATES.SELECTING_HAND')
            self.wire(bus,i,'setAnte',ante=ante)
            self.wire(bus,i,'newRound')
            self.wire(bus,i,'readyBlind',startingHands=4)

    def test_two_semifinal_rooms_ready_independently_and_fresh_final(self):
        draft=Bus();draft.draft();tickets=[]
        for c in draft.clients:
            roster.RosterDuelTests.attach(c);c.run('D.roster_duel.capture()')
            tickets.append(c.value('D.mod.config.bracket_roster'))
        left=self.native_pair(tickets[:2]);right=self.native_pair(tickets[2:])
        self.ready_pair(left,2,refuse=True)
        self.assertEqual(self.outcome_count(left.clients[0],'pvp_start_blind'),0)
        self.ready_pair(right,2)
        self.assertEqual(self.outcome_count(right.clients[0],'pvp_start_blind'),1)
        left.clients[1].run('G.STATE=G.STATES.BLIND_SELECT')
        self.wire(left,2,'readyBlind',startingHands=4)
        for bus in (left,right):
            self.assertEqual(self.outcome_count(bus.clients[0],'pvp_start_blind'),1)
            for ante in range(2,6):
                if ante>2:self.ready_pair(bus,ante)
                self.wire(bus,2,'playHand',score='100',handsLeft=0)
                self.wire(bus,1,'playHand',score='200',handsLeft=3)
            self.assertEqual(self.outcome_count(bus.clients[0],'pvp_win'),1)
            self.assertFalse(bus.clients[0].value('D.average_pvp.active()'))
        final=self.native_pair([tickets[0],tickets[2]])
        for i,c in enumerate(final.clients):
            self.assertEqual(c.value('run_pool.keys'),tickets[2*i]['keys'])
        for i in (1,2):self.assertEqual(final.clients[0].value(f'PVP.REF.players.p{i}.lives'),4)
        self.ready_pair(final,2)
        self.assertEqual(self.outcome_count(final.clients[0],'pvp_start_blind'),1)

if __name__=='__main__':unittest.main()

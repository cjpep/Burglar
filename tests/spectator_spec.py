"""Spectator integration through the supplied MPAPI action dispatcher and relay.

No live server or LÖVE renderer is simulated. PvP reports/outcomes, including
round/run tags and host authority, use the real API and existing combat harness.
"""
import copy
import json
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime
import mpapi_spec as mp


class SpectatorTests(unittest.TestCase):
    wire=mp.ApiTests.wire
    wire_open=mp.ApiTests.wire_open
    outcome_count=mp.ApiTests.outcome_count

    def setUp(self):
        self.bus=mp.Bus(checkpoints=True,native_outcomes=True)
        self.bus.draft()
        self.bus.clients[0].run('PVP.pvp_start_match();Game:update(0.02)')
        self.bus.flush()
        for c in self.bus.clients:
            c.lua.globals().python_json_decode=lambda value,c=c: c.lua.table_from(json.loads(value),recursive=True)
            c.run('''
                MPAPI.json_decode=python_json_decode
                D.now=function() return clock end
                G.STATES.SHOP=20;G.STATES.BLIND_SELECT=21;G.STATES.SELECTING_HAND=22
                G.STATE=20
                G.GAME.draftout_pool=run_pool;G.GAME.chips=123;G.GAME.dollars=17
                G.GAME.blind={name='Small Blind',chips=300}
                G.GAME.current_round.hands_left=4;G.GAME.current_round.discards_left=3
                G.jokers={cards={{config={center_key='j_joker',center={set='Joker',name='Joker'}},
                    ability={name='Joker',mult=4},facing='front',cost=2}}}
                G.hand={cards={}};G.play={cards={}};G.deck={cards={{secret='DRAW ORDER MUST NOT LEAK'}}}
                G.playing_cards={{},{}}
                PVP.end_screen_buttons=function() return {{button='native_results'}} end
                UIBox_button=function(o) return o end
                assert(loadfile(root..'/burglar/spectator.lua'))()(D)
                MPAPI._internal.run_ready_callbacks()
                S=D.spectator
                S.refresh=function() rendered=(rendered or 0)+1 end
                S.tick()
            ''')
        self.ante=2

    def eliminate(self,index):
        host=self.bus.clients[self.bus.host_index]
        while host.value(f'PVP.REF.players.p{index}.lives')>0:
            ids=self.wire_open(self.bus,self.ante);self.ante+=1
            for i in ids:
                self.wire(self.bus,i,'playHand',score='0' if i==index else '1000',handsLeft=0)

    def advance(self,seconds=1):
        for c in self.bus.clients:
            if c.index not in self.bus.offline:c.run(f'clock=clock+{seconds};S.tick()')
        self.bus.flush()

    def test_alive_players_cannot_subscribe_even_with_forged_request(self):
        viewer,target=self.bus.clients[:2]
        self.assertFalse(viewer.value("S.select('p2')"))
        viewer.run("current:action(B.transport.action):send('p2',{packet={protocol=4,kind='spectator_v2',session=B.session,room=B.room,recipient='p2',data={run=D.average_pvp.run,op='watch',token='forged'}}})")
        self.bus.flush();self.advance()
        self.assertIsNone(target.value('next(S.subscribers)'))

    def test_checkpoint_then_delay_and_live_values(self):
        self.eliminate(4);viewer=self.bus.clients[3];target=self.bus.clients[1]
        target.run('G.STATE=22')
        self.assertTrue(viewer.value("S.select('p2')"));self.bus.flush();self.advance()
        self.assertIsNone(viewer.value('S.receiver.received'))
        target.run('G.STATE=20;G.GAME.dollars=42')
        self.advance()
        self.assertIsNotNone(viewer.value('S.receiver.received'))
        self.assertIsNone(viewer.value('S.frame'))
        self.advance(4.9);self.assertIsNone(viewer.value('S.frame'))
        self.advance(.1)
        self.assertEqual(viewer.value('S.frame.dollars'),'42')
        self.assertNotIn('DRAW ORDER',json.dumps(viewer.value('S.frame')))
        target.run('G.GAME.dollars=99;G.STATE=22')
        self.advance(1);self.advance(5)
        self.assertEqual(viewer.value('S.frame.dollars'),'99')

    def test_shop_and_pack_fields_follow_delayed_real_api_frames(self):
        self.eliminate(4);viewer=self.bus.clients[3];target=self.bus.clients[1]
        target.run('G.GAME.current_round.reroll_cost=0')
        viewer.run("S.select('p2')");self.bus.flush();self.advance();self.advance(5)
        self.assertEqual(viewer.value('S.frame.reroll_cost'),'0')
        target.run('G.GAME.current_round.reroll_cost=6;G.GAME.dollars=11')
        self.advance(.25)
        self.assertEqual(viewer.value('S.frame.reroll_cost'),'0')
        self.advance(5)
        self.assertEqual(viewer.value('S.frame.reroll_cost'),'6')
        target.run('G.STATES.TAROT_PACK=23;G.STATE=23;G.GAME.pack_choices=2')
        self.advance(.25);self.advance(5)
        self.assertEqual(viewer.value('S.frame.phase'),'tarot pack')
        self.assertEqual(viewer.value('S.frame.pack_choices'),'2')
        self.assertEqual(viewer.value('S.frame.reroll_cost'),'')
        target.run('G.STATE=20')
        self.advance(.25);self.advance(5)
        self.assertEqual(viewer.value('S.frame.pack_choices'),'')

    def test_eliminated_host_watches_through_twelve_rounds_without_extra_outcomes(self):
        self.eliminate(1);host=self.bus.clients[0]
        self.assertTrue(host.value('PVP.GAME.eliminated'))
        self.assertTrue(host.value("S.select('p2')"));self.bus.flush()
        self.advance();self.advance(5)
        self.assertIsNotNone(host.value('S.frame'))
        # Keep the actual host watching while native 3-player then 1v1 scoring
        # finishes the game. Every score is a real action with run/round tags.
        expected=[0,4,4,4]
        for loser in [4]*4+[3]*4:
            ids=self.wire_open(self.bus,self.ante);self.ante+=1
            for i in ids:
                self.wire(self.bus,i,'playHand',score='0' if i==loser else '1000',handsLeft=0)
            expected[loser-1]-=1
            self.advance(1)
            self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],expected)
            self.assertTrue(host.value('PVP.referee_resolve_2p_round==native_two_player_resolver'))
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),11) # Final round sends win instead.
        self.assertEqual(self.outcome_count(host,'pvp_win'),1)
        self.assertIsNone(host.value('S.target'))
        self.assertIsNone(host.value('next(S.subscribers)'))

    def test_viewer_never_executes_or_changes_the_run(self):
        self.eliminate(4);viewer=self.bus.clients[3]
        viewer.run('''
            saved_game=G.GAME;saved_pvp=PVP.GAME;saved_ref=PVP.REF
            saved_run=MPAPI.json_encode(G.GAME);saved_lives=PVP.GAME.lives
            Game.start_run=function() error('spectator loaded a run') end
            save_run=function() error('spectator saved a run') end
            Card=function() error('spectator created a gameplay card') end
            math.random=function() error('spectator consumed RNG') end
            MPAPI.playback={new_driver=function() error('spectator executed replay') end}
        ''')
        viewer.run("S.select('p2')");self.bus.flush();self.advance();self.advance(6)
        self.assertIsNotNone(viewer.value('S.frame'))
        self.assertTrue(viewer.value('saved_game==G.GAME and saved_pvp==PVP.GAME and saved_ref==PVP.REF'))
        self.assertEqual(viewer.value('MPAPI.json_encode(G.GAME)'),viewer.value('saved_run'))
        self.assertEqual(viewer.value('PVP.GAME.lives'),viewer.value('saved_lives'))

    def test_switch_rejects_late_old_player_frames_and_old_tokens(self):
        self.eliminate(4);viewer=self.bus.clients[3]
        viewer.run("S.select('p2')");self.bus.flush()
        self.bus.drop=lambda sender,p:p.get('params',{}).get('packet',{}).get('data',{}).get('op')=='frame'
        self.advance();old=copy.deepcopy(self.bus.dropped)
        self.bus.drop=None;viewer.run("S.select('p3')");self.bus.flush()
        for p in old:
            p['from']='p2';p['cid']='old-view';viewer.receive(p)
        self.assertIsNone(viewer.value('S.receiver.received'))
        self.advance();self.advance(5)
        self.assertEqual(viewer.value('S.target'),'p3')
        self.assertIsNotNone(viewer.value('S.frame'))

    def test_subscription_expires_when_viewer_stops_sending(self):
        self.eliminate(4);viewer=self.bus.clients[3];target=self.bus.clients[1]
        viewer.run("S.select('p2')");self.bus.flush();self.advance()
        self.assertTrue(target.value('S.subscribers.p4~=nil'))
        target.run('clock=clock+13;S.tick()')
        self.assertIsNone(target.value('S.subscribers.p4'))

    def test_wrong_run_and_recipient_rejected_without_draft_error(self):
        self.eliminate(4);viewer=self.bus.clients[3];target=self.bus.clients[1]
        viewer.run("S.select('p2')");self.bus.flush()
        self.bus.drop=lambda sender,p:p.get('params',{}).get('packet',{}).get('data',{}).get('op')=='frame'
        self.advance();frames=copy.deepcopy(self.bus.dropped);self.bus.drop=None
        for field in ('run','recipient','session'):
            for original in frames:
                p=copy.deepcopy(original);p['from']='p2';p['cid']='stale-'+field
                packet=p['params']['packet']
                if field=='run':packet['data']['run']='previous-match'
                else:packet[field]='wrong'
                viewer.receive(p)
        self.assertIsNone(viewer.value('S.receiver.received'))
        self.assertEqual(viewer.value('B.phase'),'playing')

    def test_host_migration_keeps_viewer_and_new_host_authority_separate(self):
        self.eliminate(4);viewer=self.bus.clients[3]
        viewer.run("S.select('p2')");self.bus.flush();self.advance();self.advance(5)
        self.bus.handover(1,2)
        self.advance(1)
        self.assertEqual(viewer.value('S.target'),'p2')
        host=self.bus.clients[1]
        self.assertTrue(host.value('current.is_host'))
        ids=self.wire_open(self.bus,self.ante)
        for i in ids:self.wire(self.bus,i,'playHand',score='1000' if i==2 else '0',handsLeft=0)
        self.assertEqual(host.value('PVP.REF.players.p3.lives'),3)
        self.assertEqual(host.value('PVP.REF.players.p4.lives'),0)

    def test_target_leaving_and_new_lobby_clear_all_view_state(self):
        self.eliminate(4);viewer=self.bus.clients[3]
        viewer.run("S.select('p2')");self.bus.flush();self.advance();self.advance(5)
        viewer.run("current._players.p2=nil;S.tick()")
        self.assertIsNone(viewer.value('S.frame'))
        self.assertIsNone(viewer.value('S.target'))
        viewer.run("current:_fire('disconnected');S.tick()")
        self.assertIsNone(viewer.value('next(S.subscribers)'))

    def test_results_button_only_appears_after_elimination(self):
        viewer=self.bus.clients[3]
        self.assertEqual(viewer.value('#PVP.end_screen_buttons()'),1)
        self.eliminate(4)
        self.assertEqual(viewer.value("PVP.end_screen_buttons()[1].button"),'draftout_spectate_open')
        viewer.run("current._game.started=nil")
        self.assertEqual(viewer.value('#PVP.end_screen_buttons()'),1)

    def test_reordered_fragmented_frames_and_missing_frame_recover(self):
        self.eliminate(4);viewer=self.bus.clients[3];target=self.bus.clients[1]
        target.run('''
            G.jokers.cards={}
            for i=1,24 do G.jokers.cards[i]={config={center_key='j_joker',center={set='Joker'}},
                ability={name=string.rep('J',80),mult=i,extra={chips=200,mult=10,retriggers=3}},
                facing='front',cost=7} end
        ''')
        viewer.run("S.select('p2')");self.bus.flush()
        self.bus.drop=lambda sender,p:p.get('params',{}).get('packet',{}).get('data',{}).get('op')=='frame'
        self.advance();first=copy.deepcopy(self.bus.dropped);self.bus.dropped=[]
        self.assertGreater(len(first),1)
        # Lose a part of frame one. Later complete frame two must recover.
        for p in first[:-1]:
            p['from']='p2';p['cid']='partial';viewer.receive(p)
        self.assertIsNone(viewer.value('S.receiver.received'))
        target.run('G.GAME.dollars=88')
        self.advance();second=copy.deepcopy(self.bus.dropped);self.bus.drop=None
        for p in reversed(second):
            p['from']='p2';p['cid']='shuffled';viewer.receive(p)
            viewer.receive(copy.deepcopy(p))
        self.assertEqual(viewer.value('#S.receiver.queue'),1)
        viewer.run('clock=clock+5;S.tick()')
        self.assertEqual(viewer.value('#S.frame.areas.jokers'),24)
        self.assertEqual(viewer.value('S.receiver.last'),2)

    def test_missing_frame_acks_do_not_accumulate_pending_callbacks(self):
        self.eliminate(4);viewer=self.bus.clients[3];target=self.bus.clients[1]
        viewer.run("S.select('p2')");self.bus.flush()
        self.bus.drop=lambda sender,p:p.get('params',{}).get('packet',{}).get('data',{}).get('op')=='frame'
        for _ in range(20):self.advance()
        self.assertIsNone(target.value('next(current._pending_actions)'))
        self.assertIsNone(viewer.value('next(current._pending_actions)'))
        self.assertTrue(target.value('S.subscribers.p4~=nil'),'Leases renew even while frames are lost')

    def test_quarter_second_changes_and_idle_heartbeat(self):
        self.eliminate(4);viewer=self.bus.clients[3];target=self.bus.clients[1]
        viewer.run("S.select('p2')");self.bus.flush();self.advance(.25)
        seq=target.value('S.subscribers.p4.seq')
        self.advance(.25)
        self.assertEqual(target.value('S.subscribers.p4.seq'),seq,'Identical frames are suppressed')
        target.run('G.GAME.dollars=101');self.advance(.25)
        self.assertEqual(target.value('S.subscribers.p4.seq'),seq+1,'Changed state can arrive at 4 Hz')
        self.advance(2)
        self.assertEqual(target.value('S.subscribers.p4.seq'),seq+2,'Idle heartbeat keeps the feed alive')

    def test_card_identity_and_selection_survive_network_transfer(self):
        self.eliminate(4);viewer=self.bus.clients[3];target=self.bus.clients[1]
        target.run("card={config={center_key='c_base',card_key='H_A'},ability={},facing='front',highlighted=true};G.hand.cards={card}")
        viewer.run("S.select('p2')");self.bus.flush();self.advance(.25);self.advance(5)
        identity=viewer.value('S.frame.areas.hand[1].uid')
        self.assertTrue(viewer.value('S.frame.areas.hand[1].selected'))
        target.run('G.hand.cards={};G.play.cards={card};card.highlighted=false;G.STATE=22')
        self.advance(.25);self.advance(5)
        self.assertEqual(viewer.value('S.frame.areas.play[1].uid'),identity)
        self.assertFalse(viewer.value('S.frame.areas.play[1].selected'))


if __name__=='__main__':unittest.main()

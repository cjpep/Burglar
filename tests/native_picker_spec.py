"""PvP 1.0.3 native lobby/picker integration; game rendering remains mocked."""
import unittest
from mpapi_spec import Bus, API

@unittest.skipUnless((API/'api/matchmaking/group/party.lua').exists(), 'Requires Multiplayer 1.0.3 references')
class NativePickerTests(unittest.TestCase):
    def test_host_guest_buttons_share_existing_slot(self):
        bus=Bus()
        for index,c in enumerate(bus.clients):
            c.run('''
                function find_id(n,id)
                    if n.config and n.config.id==id then return n end
                    for _,child in ipairs(n.nodes or {}) do local f=find_id(child,id);if f then return f end end
                end
                controls=PVP.lobby.build_controls()
                draft_button=find_id(controls,'draftout_lobby_draft')
                native_button=find_id(controls,'mp_pvp_choose_deck')
            ''')
            self.assertEqual(c.value('#controls.nodes'),1)
            self.assertEqual(c.value('#controls.nodes[1].nodes'),5 if index==0 else 4)
            self.assertEqual(c.value('draft_button.config.button'),'draftout_lobby_draft')
            self.assertEqual(c.value('native_button.config.button'),'lobby_choose_deck' if index==0 else None)
            self.assertEqual(c.value('native_button.config.minh'),0.70)
            c.run('G.FUNCS.lobby_choose_deck({})')
            self.assertEqual(c.value('native_picker_opens'),1 if index==0 else None)

    def test_native_deck_stake_and_balance_keep_completed_pools(self):
        bus=Bus(checkpoints=True);bus.draft();host=bus.clients[0]
        sessions=[c.value('B.session') for c in bus.clients]
        pools=[c.value('B.pool.keys') for c in bus.clients]
        host.run('''
            PVP.LOBBY.code=current.code;PVP.LOBBY.is_host=true
            PVP._pvp_kind='private';PVP._pvp_gamemode='pvp_royale'
            G.FUNCS.lobby_choose_deck({})
            G.FUNCS.start_run({}, {deck=G.P_CENTERS.b_blue,stake=2})
        ''')
        self.assertFalse(host.value('D.deck_picker.synced()'))
        self.assertFalse(host.value('B.launch_ready()'))
        bus.flush()
        self.assertTrue(host.value('D.deck_picker.synced()'))
        host.run('G.FUNCS.mp_pvp_change_ruleset({to_key=2})');bus.flush()
        for i,c in enumerate(bus.clients):
            self.assertEqual(c.value('B.session'),sessions[i])
            self.assertEqual(c.value('B.pool.keys'),pools[i])
            self.assertEqual(c.value('current:get_metadata().deck'),'Blue Deck')
            self.assertEqual(c.value('tonumber(current:get_metadata().stake)'),2)
            self.assertEqual(c.value('current:get_metadata().ruleset'),'ruleset_mp_balanced')
            self.assertTrue(c.value('B.pool_ready()'))
        self.assertTrue(host.value('B.launch_ready()'))
        self.assertIsNone(host.value('native_run_starts'))

    def test_pending_launch_and_unrelated_lobby_are_respected(self):
        bus=Bus();host=bus.clients[0]
        host.run('B.pending_launch=true;G.FUNCS.lobby_choose_deck({})')
        self.assertIsNone(host.value('native_picker_opens'))
        host.run("B.pending_launch=nil;current._metadata.queue_mode='pvp_nemesis';G.FUNCS.lobby_choose_deck({})")
        self.assertEqual(host.value('native_picker_opens'),1)
        host.run('''
            function has_draft(n)
                if n.config and n.config.id=='draftout_lobby_draft' then return true end
                for _,child in ipairs(n.nodes or {}) do if has_draft(child) then return true end end
                return false
            end
        ''')
        self.assertFalse(host.value('has_draft(PVP.lobby.build_controls())'))

if __name__=='__main__': unittest.main()

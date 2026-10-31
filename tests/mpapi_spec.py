"""Four clients with supplied MPAPI code and a simulated Nakama relay.

Set DRAFTOUT_API_REFERENCE and DRAFTOUT_PVP_REFERENCE for the target version.

Uses the real API lobby factory, action registration/validation/dispatch,
on_loaded lifecycle and built-in start flow, plus PvP's actual start function.
Game rendering and the official server are not part of this test.
"""
import copy
import random
import json
import os
import re
from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime, lua_type

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT.parent / 'reference_mp_100'
API = Path(os.environ.get('DRAFTOUT_API_REFERENCE', str(BASE / 'BalatroMultiplayer-MultiplayerAPI-1.0.0')))
PVP = Path(os.environ.get('DRAFTOUT_PVP_REFERENCE', str(BASE / 'BalatroMultiplayer-MultiplayerPvP-1.0.0')))


def plain(value):
    if lua_type(value) != 'table':
        return value
    values = dict(value.items())
    if values and set(values) == set(range(1, len(values)+1)):
        return [plain(values[i]) for i in range(1, len(values)+1)]
    return {k: plain(v) for k, v in values.items()}


class Client:
    def __init__(self, index, bus):
        self.index, self.bus = index, bus
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        g = self.lua.globals()
        g.checkpoints_enabled=bus.checkpoints
        g.native_outcomes=bus.native_outcomes
        g.player_count=bus.player_count
        g.python_json_encode=lambda value: json.dumps(plain(value),sort_keys=True)
        g.root, g.api_root, g.pvp_root, g.own_id = str(ROOT), str(API), str(PVP), f'p{index}'
        g.python_send = lambda packet: bus.queue.append((f'p{index}', plain(packet)))
        self.lua.execute('''
            clock=10; uid=0; warnings={}; ui_shows=0; original_starts=0; game_starts=0
            love={timer={getTime=function() return clock end}, math={random=math.random}}
            G={FUNCS={}, UIT={C=1}, TIMERS={REAL=0}, P_CENTERS={},C={MULTIPLAYER={}}}
            G.FUNCS.exit_overlay_menu=function() G.OVERLAY_MENU=nil end
            Game={update=function() end,TIMERS=G.TIMERS}
            SMODS={current_mod={id='MultiplayerAPI'},save_mod_config=function() config_saves=(config_saves or 0)+1 end,
                load_file=function(path) return loadfile(root..'/'..path) end}
            -- Minimal SMODS object machinery; API ActionType itself is real code.
            SMODS.GameObject={}
            function SMODS.GameObject:extend(def)
                def.super=self
                return setmetatable(def,{__index=self,__call=function(cls,o)
                    assert(o.mod==nil); o.mod=SMODS.current_mod
                    setmetatable(o,{__index=cls}); o:register(); return o
                end})
            end
            function SMODS.GameObject:register()
                self.obj_table[self.key]=self; self.obj_buffer[#self.obj_buffer+1]=self.key
            end
            MPAPI={id='MultiplayerAPI',_internal={},update=function() end,
                networking={nakama_lobby={ClientOp={ACTION=1,SET_METADATA=2},SERVER_TARGET='server'}},
                connection_state={},ErrorKind={VALIDATION='validation',ACTION_REJECTED='rejected',NOT_CONNECTED='offline'},
                GameModes={pvp_royale={new_instance=function() return {} end}}}
            function MPAPI.load_mpapi_file(path) return assert(loadfile(api_root..'/'..path))() end
            MPAPI.get_current_lobby=function() return current end
            MPAPI.sendWarnMessage=function(msg) warnings[#warnings+1]=msg end
            MPAPI.sendDebugMessage=function() end
            MPAPI.make_error=function(kind,message) return {kind=kind,message=message} end
            MPAPI.json_encode=function(value) return python_json_encode(value) end
            MPAPI.generate_id=function() uid=uid+1; return own_id..':'..uid end
            MPAPI.set_player_ready=function() end
            MPAPI.networking.nakama_lobby.send=function(op,packet)
                if socket_down then return false end
                python_send(packet); return true
            end
            MPAPI.load_mpapi_file('domain/lobby_event.lua')
            MPAPI.load_mpapi_file('api/connection/lifecycle.lua')
            MPAPI.load_mpapi_file('api/lobby/state.lua')
            MPAPI.load_mpapi_file('api/lobby/events.lua')
            MPAPI.load_mpapi_file('api/lobby_flow.lua')
            MPAPI.load_mpapi_file('api/action/validation.lua')
            MPAPI.load_mpapi_file('api/action/instance.lua')
            MPAPI.load_mpapi_file('api/action/dispatch.lua')
            MPAPI.load_mpapi_file('api/action/builtin.lua')
            PVP={id='MultiplayerPvP',LOBBY={deck={stake=1},config={}},
                GamemodeKey={PVP_NEMESIS='pvp_nemesis'},UI={UTILS={overlay_message=function() end}}}
            SMODS.current_mod=PVP
        ''')
        source = (PVP/'pvp_api/flow.lua').read_text()
        flow = re.search(r'function PVP\.pvp_start_match\(\).*?\nend', source, re.S).group()
        self.lua.globals().pvp_start_source = source if (API/'api/matchmaking/group/party.lua').exists() else flow
        rules=(PVP/'rulesets/_rulesets.lua').read_text()
        enum=re.search(r'PVP\.RulesetKey = \{.*?\n\}',rules,re.S)
        self.lua.globals().ruleset_keys_source=enum.group() if enum else ''
        mirror=re.search(r'local function mirror_metadata\(lobby\).*?\nend',(PVP/'pvp_api/lobby_bridge.lua').read_text(),re.S).group()
        self.lua.globals().mirror_source=mirror.replace('local function mirror_metadata','function PVP.test_mirror_metadata',1)
        self.lua.execute('''
            -- PvP installs its flow in on_loaded, before Burglar's callback.
            MPAPI.on_loaded(function()
                assert(loadstring(ruleset_keys_source))()
                local party=loadfile(api_root..'/api/matchmaking/group/party.lua')
                if party then
                    party()
                    MPAPI.shallow_copy=function(t) local out={};for k,v in pairs(t) do out[k]=v end;return out end
                    UIBox_button=function(args)
                        local texts={}
                        for _,label in ipairs(type(args.label)=='table' and args.label or {args.label}) do
                            texts[#texts+1]={n=G.UIT.R,config={align='cm'},nodes={{n=G.UIT.T,config={text=label,scale=args.scale}}}}
                        end
                        return {n=G.UIT.C,config={align='cm',padding=0.05},nodes={{n=G.UIT.C,
                            config={id=args.id,button=args.button,colour=args.colour,minh=args.minh,minw=args.minw},nodes=texts}}}
                    end
                    assert(loadfile(api_root..'/lib/ui.lua'))()
                    assert(loadfile(api_root..'/api/ui_element.lua'))()
                    G.FUNCS.start_run=function() native_run_starts=(native_run_starts or 0)+1 end
                    G.FUNCS.setup_run=function() native_picker_opens=(native_picker_opens or 0)+1 end
                    PVP.DECK={MAX_STAKE=8}
                    assert(loadfile(pvp_root..'/ui/lobby/code.lua'))()
                    assert(loadfile(pvp_root..'/overrides/run_start.lua'))()
                    SMODS.stake_from_index=function() return 'stake_white' end
                    G.P_CENTERS.stake_white={name='White Stake'}
                end
                PVP.UTILS={version_mismatches=function() return {} end,string_split=function(value)
                    local out={}; for part in value:gmatch('[^e]+') do out[#out+1]=part end; return out
                end}
                number_format=tostring
                local legacy=loadfile(pvp_root..'/lib/insane_int.lua');if legacy then legacy() end
                if loadfile(pvp_root..'/lib/score.lua') then
                    assert(loadfile(api_root..'/lib/big_score.lua'))()
                    assert(loadfile(pvp_root..'/lib/score.lua'))()
                    -- Test helpers keep their old spelling, but produce native 1.0.4 score text.
                    PVP.INSANE_INT={empty=function() return '0' end,
                        from_string=PVP.Score.from_game_value,to_string=function(v) return v end,
                        greater_than=PVP.Score.greater,equal=PVP.Score.equal,
                        create=function(c,e) return PVP.Score.from_game_value(tostring(c)..'e'..tostring(e)) end}

                    assert(loadfile(pvp_root..'/pvp_api/round_sync.lua'))()
                    sendDebugMessage=function() end;sendWarnMessage=function() end
                end
                for _,path in ipairs({'lib/pending_death.lua','pvp_api/server_hold.lua','lib/ante_nemesis.lua','ui/game/pending_death.lua'}) do
                    local f=loadfile(pvp_root..'/'..path);if f then f() end
                end
                assert(loadfile(pvp_root..'/pvp_api/referee.lua'))()
                native_two_player_resolver=PVP.referee_resolve_2p_round
                -- Server checkpoint storage is outside this relay harness.
                if not checkpoints_enabled then PVP.referee_checkpoint=function() end end
                if checkpoints_enabled then
                    PVP.PVP_GAMEMODES={pvp_royale={}}
                    MPAPI.apply_default_modifiers=function() end
                    MPAPI.modifiers_serialize=function() return {} end
                    PVP.SETUP={apply_results=function() end}
                    assert(loadstring(mirror_source))()
                end
                PVP.Gamemodes={gamemode_mp_attrition={get_blinds_by_ante=function() return 'native' end}}
                PVP.GAME={enemy={score=PVP.INSANE_INT.empty(),real_score=PVP.INSANE_INT.empty(),
                    highest_score=PVP.INSANE_INT.empty(),skips=0,hands=4}}
                SMODS.Atlas=function() end
                MPAPI.Blinds={}
                MPAPI.Blind=function(def) MPAPI.Blinds.bl_mp_nemesis=def end
                assert(loadfile(pvp_root..'/objects/blinds/nemesis.lua'))()
                test_pvp=false; test_layer=false
                PVP.is_pvp_boss=function() return test_pvp end
                PVP.is_layer_active=function() return test_layer end
                PVP.is_byed=function() return false end
                PVP.current_target_id=function() return 'p2' end
                PVP.UI.ease_enemy_score=function(score) PVP.GAME.enemy.score=score end
                PVP.UI.cam_timer_opponent=function() return 'native timer' end
                PVP.UI.update_blind_HUD=function() native_hud_updates=(native_hud_updates or 0)+1 end
                PVP.dispatch_action=function(kind) native_dispatch=kind end
                PVP.UI.reset_blind_HUD=function()
                    if score_label then score_label.config.text='ph_blind_score_at_least' end
                end
                localize=function(key) return type(key)=='table' and G.P_CENTERS[key.key].name or key end
                for key,name in pairs({b_red='Red Deck',b_blue='Blue Deck',b_yellow='Yellow Deck'}) do
                    G.P_CENTERS[key]={key=key,name=name,set='Back'}
                end
                PVP.UTILS.get_deck_key_from_name=function(name)
                    for key,c in pairs(G.P_CENTERS) do if c.set=='Back' and c.name==name then return key end end
                end
                PVP.lobby={buttons={}}
                for _,key in ipairs({'start_game','lobby_options','ready','view_code','copy_code','leave'}) do
                    PVP.lobby.buttons[key]={node={config={id=key}}}
                end
                G.C.PURPLE={}; G.C.UI={}; G.UIT.R=2; G.UIT.T=3
                PVP.is_matchmaking=function() return current and current.type~='private' end
                assert(loadfile(pvp_root..'/ui/lobby/controls.lua'))()
                assert(loadfile(pvp_root..'/ui/lobby/lobby_options.lua'))()
                function find_deck(node)
                    if node.config and node.config.id=='draftout_shared_deck' then return node end
                    for _,child in ipairs(node.nodes or {}) do local found=find_deck(child); if found then return found end end
                end
                G.FUNCS.multiplayer_blind_chip_UI_scale=function() return 'native HUD' end
                G.STAGES={RUN=1};G.STAGE=1
                G.GAME={current_round={hands_played=1}}; G.STATES={ROUND_EVAL=1,NEW_ROUND=2}
                outcomes={}; client_lives={}; client_eliminated={}
                for _,key in ipairs({'pvp_player_lives','pvp_eliminated','pvp_end_pvp','pvp_win','pvp_royale_target','pvp_start_blind'}) do
                    local action_key=key
                    MPAPI.ActionType({key=key,prefix_config={key=false},parameters={},on_receive=function(_,from,data)
                        if from~=current.host_id then return end
                        outcomes[#outcomes+1]={key=action_key,data=data}
                        if action_key=='pvp_player_lives' then
                            if data.player_id=='*all*' then for i=1,player_count do client_lives['p'..i]=data.lives end
                            else client_lives[data.player_id]=data.lives end
                        elseif action_key=='pvp_eliminated' then client_eliminated[data.player_id]=true
                            if data.player_id==own_id then PVP.GAME.eliminated=true end end
                    end})
                end
                test_outcome_handlers={}
                for _,key in ipairs({'pvp_start_blind','pvp_royale_target'}) do test_outcome_handlers[key]=MPAPI.ActionTypes[key].on_receive end
                assert(loadfile(pvp_root..'/pvp_api/actions/_helpers.lua'))()
                assert(loadfile(pvp_root..'/pvp_api/actions/score_resolution.lua'))()
                assert(loadfile(pvp_root..'/pvp_api/actions/blind_handshake.lua'))()
                assert(loadfile(pvp_root..'/pvp_api/actions/round_resolution.lua'))()
                if native_outcomes then
                    local recorded={}
                    for _,key in ipairs({'pvp_player_lives','pvp_eliminated','pvp_end_pvp','pvp_win'}) do
                        recorded[key]=MPAPI.ActionTypes[key].on_receive
                    end
                    assert(loadfile(pvp_root..'/lib/lives_lookup.lua'))()
                    MPAPI.has_server_referee=function() return true end
                    server_results={};native_actions={}
                    PVP.report_server_result=function(_,winner) server_results[#server_results+1]=winner end
                    PVP.OPPONENT_SIGNALS={lives_dropped=function(a,b) return a and b<a end,
                        play_life_lost=function() end}
                    PVP.dispatch_action=function(kind,data)
                        native_actions[#native_actions+1]={kind=kind,data=data}
                        if kind=='playerInfo' then PVP.GAME.lives=data.lives end
                    end
                    assert(loadfile(pvp_root..'/pvp_api/actions/outcomes.lua'))()
                    for key,record in pairs(recorded) do
                        local action=MPAPI.ActionTypes[key];local native=action.on_receive
                        action.on_receive=function(at,from,data) record(at,from,data);return native(at,from,data) end
                    end
                end
                PVP._pvp_action_helpers.A('pvp_forfeit',function(_,from) PVP.referee_n_player_forfeit(from) end)
                for key,record in pairs(test_outcome_handlers) do
                    local action=MPAPI.ActionTypes[key];local native=action.on_receive
                    action.on_receive=function(at,from,data) record(at,from,data);return native(at,from,data) end
                end
                PVP.current_ruleset=function() return {} end; PVP.UI.restore_timer=function() end
                Client={};assert(loadfile(pvp_root..'/pvp_api/net.lua'))()
                assert(loadstring(pvp_start_source))()
                local original=PVP.pvp_start_match
                PVP.pvp_start_match=function(...) original_starts=original_starts+1; return original(...) end
                PVP.on_game_start=function(params)
                    game_starts=game_starts+1; run_seed=params.seed; run_back=PVP.LOBBY.deck.back; PVP.GAME.eliminated=nil
                    if current.is_host then PVP.referee_reset(PVP.LOBBY.config.starting_lives) end
                    run_pool=D.mpbridge.prepare_run()
                end
            end)
            local core=assert(loadfile(root..'/burglar/core.lua'))()
            keys=assert(loadfile(root..'/burglar/vanilla_keys.lua'))()
            local ui={show=function() ui_shows=ui_shows+1 end,
                line=function(text) return {config={text=text}} end,row=function(nodes) return {nodes=nodes} end,
                button=function(label,action,data) return {n=G.UIT.C,config={text=label,button=action,ref_table=data},nodes={{n=G.UIT.T,config={text=label}}}} end}
            local mod={id='Draftout',config={native_draft=true,picks_per_turn=2,packs_per_player=3}}
            SMODS.current_mod=mod
            D={mod=mod,core=core,ui=ui,pack_ui={unlock=function() end,clear=function() end,confirmed=function() end},
                catalog=function() return keys end}
            D.draft_options=function() return {pack_size=9,packs_per_player=mod.config.packs_per_player,picks_per_turn=mod.config.picks_per_turn} end
            D.draft_settings=function() return {} end
            local seed=assert(loadfile(root..'/burglar/seed.lua'))()
            D.fresh_seed=function() return seed(mod.config,love.math.random) end
            D.clock=assert(loadfile(root..'/burglar/turn_clock.lua'))()
            assert(loadfile(root..'/burglar/mpapi.lua'))()(D)
            B=D.mpbridge
            assert(PVP.pvp_start_match==nil,'Start hook must wait for PvP startup')
            MPAPI._internal.run_ready_callbacks()
            assert(B.transport.ready and B.hooks_ready,table.concat(warnings,';'))
            function new_lobby(mod_id,kind,mode)
                current=MPAPI._internal.lobby.create_object({code='ROOM',mod_id=mod_id,
                    type=kind,player_id=own_id,is_host=own_id=='p1',nakama=true,
                    metadata={queue_mode=mode,ruleset='ruleset_mp_vanilla',kind='private'}})
                current.host_id='p1'; PVP.lobby.ref=current
                -- The upstream bridge invokes takeover on the elected host.
                -- The complete bridge's menus/renderer remain outside this harness.
                current:on('host_changed',function(id)
                    PVP._pvp_action_helpers.note_host(current,id)
                    if current.is_host then PVP.referee_take_over() end
                end)
                current:on('player_left',function(id)
                    if D.average_pvp.active() then PVP.referee_n_player_forfeit(id) end
                end)
                if checkpoints_enabled then current:on('metadata_changed',function() PVP.test_mirror_metadata(current) end) end
                for i=1,player_count do current._players['p'..i]={id='p'..i,displayName='Player'..i} end
                current:on('game_started',function(started) PVP.on_game_start(started) end)
            end
            new_lobby('MultiplayerPvP','private','pvp_royale')
        ''')

    def run(self, code):
        return self.lua.execute(code)

    def value(self, expression):
        return plain(self.lua.eval(expression))

    def receive(self, envelope):
        self.lua.globals().envelope = self.lua.table_from(envelope, recursive=True)
        self.run('MPAPI._internal.lobby.deliver_action(current,envelope)')


class Bus:
    def __init__(self, broadcast=False, checkpoints=False,native_outcomes=False,player_count=4):
        self.player_count=player_count
        self.checkpoints=checkpoints
        self.native_outcomes=native_outcomes
        self.drop=None; self.dropped=[]; self.metadata=[]
        self.queue, self.broadcast, self.views, self.starts = [], broadcast, [], []
        self.offline=set();self.host_index=0
        self.clients = [Client(i,self) for i in range(1,player_count+1)]

    def flush(self):
        count = 0
        while self.queue:
            sender, packet = self.queue.pop(0)
            count += 1
            assert count < 1500, 'Message loop'
            if self.drop and self.drop(sender,packet):
                self.dropped.append(copy.deepcopy(packet)); continue
            if 'metadata' in packet and 'action' not in packet:
                if sender!=f'p{self.host_index+1}':continue
                self.metadata.append(copy.deepcopy(packet['metadata']))
                for c in self.clients:
                    if c.index in self.offline:continue
                    c.lua.globals().meta_patch=c.lua.table_from(packet['metadata'],recursive=True)
                    c.run("for key,value in pairs(meta_patch) do current._metadata[key]=value end; current:_fire('metadata_changed',current._metadata)")
                continue
            if packet['action'] == 'mpapi_start_game':
                self.starts.append(copy.deepcopy(packet))
                result = {'cid':packet['cid'],'action':packet['action'],'from':'server','to':'*',
                          'params':{'seed':'SERVERSEED','runId':'run-1','stake':1,'options':packet['params']['options'],
                                    'players':[f'p{i}' for i in range(1,self.player_count+1)]}}
                for c in self.clients:
                    c.receive(copy.deepcopy(result))
                continue
            envelope = copy.deepcopy(packet)
            envelope['from'] = sender
            if 'responseTo' in envelope:
                envelope['response_to'] = envelope.pop('responseTo')
            recipients = range(self.player_count) if self.broadcast or packet['to']=='*' else [int(packet['to'][1:])-1]
            if self.broadcast:
                envelope['to'] = '*'
            for index in recipients:
                if index+1 in self.offline:continue
                data = envelope.get('params',{}).get('packet',{})
                if data.get('kind') == 'view':
                    self.views.append((index+1,copy.deepcopy(data)))
                self.clients[index].receive(copy.deepcopy(envelope))

    def handover(self,old,new,away=False,left_first=True):
        self.offline.add(old);self.host_index=new-1
        for c in self.clients:
            if c.index in self.offline:continue
            left=f"MPAPI._internal.lobby.apply_event(current,{{type='{'player_disconnected' if away else 'player_left'}',playerId='p{old}'}})"
            changed=f"MPAPI._internal.lobby.apply_event(current,{{type='host_changed',playerId='p{new}'}})"
            c.run(left+';'+changed if left_first else changed+';'+left)
        self.flush()
        for c in self.clients:
            if c.index not in self.offline:c.run('Game:update(0.02)')
        self.flush()

    def begin(self):
        self.clients[0].run('PVP.pvp_start_match()')
        self.flush()
        for c in self.clients:
            c.run('clock=13')

    def draft(self):
        self.begin()
        self.clients[0].run('B.start_draft()')
        self.flush()
        guard = 0
        while not self.clients[0].value('B.host_state.done'):
            guard += 1
            assert guard < 40
            for c in self.clients:
                if not c.value('B.view.picked'):
                    c.run('local chosen={}; for i=1,math.min(B.view.picks_per_turn,#B.view.cards) do chosen[i]=B.view.cards[i] end; B.pick(chosen,B.view.token)')
                    self.flush()


@unittest.skipUnless((API/'api/lobby/state.lua').exists() and (PVP/'pvp_api/flow.lua').exists(),
                     'Set DRAFTOUT_API_REFERENCE and DRAFTOUT_PVP_REFERENCE to the 1.0.0 source folders')
class ApiTests(unittest.TestCase):
    def test_all_four_packs_alternate_direction_online_and_in_recap(self):
        for picks in (1,2):
            with self.subTest(picks=picks):
                bus=Bus();host=bus.clients[0]
                host.run(f'D.mod.config.packs_per_player=4;D.mod.config.picks_per_turn={picks}')
                bus.begin();host.run('B.start_draft()');bus.flush()
                while not host.value('B.host_state.done'):
                    for seat,c in enumerate(bus.clients,1):
                        view=c.value('B.view');r,p=view['round'],view['pick']
                        expected=((seat-1-(p-1)*(1 if r%2 else -1))%4)+1
                        self.assertEqual(view['token']['pack_id'],f'r{r}s{expected}')
                        c.run('local chosen={};for i=1,math.min(B.view.picks_per_turn,#B.view.cards) do chosen[i]=B.view.cards[i] end;B.pick(chosen,B.view.token)')
                        bus.flush()
                host.run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
                expected=host.value('D.recap.context.payload')
                for seat,player in enumerate(expected['players'],1):
                    for entry in player['history']:
                        r,p=entry['round'],entry['pick']
                        origin=((seat-1-(p-1)*(1 if r%2 else -1))%4)+1
                        self.assertEqual(entry['pack_id'],f'r{r}s{origin}')
                bus.handover(1,2)
                self.assertEqual(bus.clients[1].value('D.recap.context.payload'),expected,'Compact recovery reconstructs reverse-passed histories')
                self.finish_match(bus)
                for c in bus.clients[1:]:self.assertEqual(c.value('D.mod.config.last_recap'),expected)

    def test_dropped_offer_retry_uses_current_rules_version(self):
        bus=Bus();dropped=[False]
        def drop(sender,packet):
            data=packet.get('params',{}).get('packet',{})
            if data.get('kind')=='offer' and packet.get('to')=='p2' and not dropped[0]:
                dropped[0]=True;return True
            return False
        bus.drop=drop;bus.begin()
        self.assertEqual(bus.clients[1].value('B.phase'),'idle')
        bus.clients[0].run('Game:update(0.02)');bus.flush()
        self.assertEqual(bus.clients[1].value('B.phase'),'checking')
        self.assertTrue(bus.clients[0].value('B.hello.p2'))

    def test_host_pick_and_pack_options_produce_exact_rosters(self):
        for picks in (1,2):
            for rounds in (1,2,3,4):
                with self.subTest(picks=picks,rounds=rounds):
                    bus=Bus(); host=bus.clients[0]
                    host.run(f'D.mod.config.picks_per_turn={picks}; D.mod.config.packs_per_player={rounds}')
                    # Guests' preferences cannot override the host's authoritative rules.
                    for guest in bus.clients[1:]:
                        guest.run(f'D.mod.config.picks_per_turn={3-picks}; D.mod.config.packs_per_player={5-rounds}')
                    bus.draft()
                    pools=[set(c.value('B.pool.keys')) for c in bus.clients]
                    count=35 if rounds==4 else 9*rounds
                    self.assertTrue(all(len(pool)==count for pool in pools))
                    self.assertEqual(len(set.union(*pools)),4*count)
                    self.assertEqual(host.value('B.host_state.revision'),4*(((9+picks-1)//picks)*min(rounds,3)+((8+picks-1)//picks if rounds==4 else 0)))
                    self.assertTrue(all(c.value('B.view.picks_per_turn')==picks for c in bus.clients))
                    self.assertTrue(all(c.value('B.launch_ready()') for c in bus.clients))
                    missing=set(host.value('keys'))-set.union(*pools)
                    self.assertEqual(len(missing),141-4*count)
                    for c in bus.clients:
                        self.assertTrue(missing.isdisjoint(c.value('B.pool.keys')))

    def test_single_pick_timeout_and_extra_pick_rejection(self):
        bus=Bus();bus.begin();host=bus.clients[0]
        host.run('D.mod.config.picks_per_turn=1; D.mod.config.packs_per_player=4; D.mod.config.pick_seconds=5; B.start_draft()');bus.flush()
        host.run('B.pick({B.view.cards[1],B.view.cards[2]},B.view.token)');bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),0)
        guest=bus.clients[1]
        keep=guest.value('B.view.cards[4]')
        guest.run('B.intent({B.view.cards[4]},B.view.token,1)');bus.flush()
        for _ in range(35):
            host.run('clock=clock+6; Game:update(0.02)');bus.flush()
        self.assertTrue(host.value('B.host_state.done'))
        self.assertEqual(guest.value('B.pool.keys[1]'),keep)
        self.assertTrue(all(len(c.value('B.pool.keys'))==35 for c in bus.clients))
        self.assertEqual(host.value('B.host_state.revision'),140)

    def finish_match(self,bus,order=None):
        for index in (range(bus.player_count) if order is None else order):
            if index+1 in bus.offline:continue
            bus.clients[index].run("MPAPI._internal.lobby.apply_game_ended(current,{runId='run-1',status='agreed'})")
        bus.flush()

    def test_recap_stays_private_until_match_ends_then_survives_reset(self):
        bus=Bus();bus.draft();host=bus.clients[0]
        self.assertTrue(all(not c.value('D.recap.available()') for c in bus.clients))
        self.assertTrue(all('history' not in view['data'] and 'pools' not in view['data'] for _,view in bus.views))
        host.run('PVP.pvp_start_match(); Game:update(0.02)');bus.flush()
        self.assertTrue(all(not c.value('D.recap.available()') for c in bus.clients))
        expected=host.value('D.recap.context.payload')
        self.finish_match(bus)
        for c in bus.clients:
            self.assertEqual(c.value('D.mod.config.last_recap'),expected)
            self.assertEqual(c.value('B.phase'),'idle')
            self.assertIsNone(c.value('B.pool'))
            self.assertEqual(len(c.value('D.mod.config.last_recap.omitted')),33)
            self.assertTrue(c.value('D.recap.context.saved'))
        before=[c.value('config_saves') for c in bus.clients]
        self.finish_match(bus)
        self.assertEqual(before,[c.value('config_saves') for c in bus.clients],'Duplicate end events do not resave or broadcast')

    def test_recap_recovers_a_missing_part_after_session_teardown(self):
        bus=self.start_average_match();host=bus.clients[0]
        dropped=[False]
        def drop(sender,packet):
            data=packet.get('params',{}).get('packet',{})
            if data.get('kind')=='recap_part' and packet.get('to')=='p3' and data['data']['slot']==2 and not dropped[0]:
                dropped[0]=True;return True
            return False
        bus.drop=drop;self.finish_match(bus)
        guest=bus.clients[2]
        self.assertFalse(guest.value('D.recap.available()'))
        self.assertIsNone(guest.value('B.session'))
        self.assertTrue(bus.clients[1].value('D.recap.available()'))
        guest.run('clock=30; Game:update(0.02)');bus.flush()
        self.assertTrue(guest.value('D.recap.available()'))
        self.assertEqual(guest.value('D.mod.config.last_recap'),host.value('D.mod.config.last_recap'))
        self.assertTrue(dropped[0])

    def test_recap_handles_delivery_before_the_receivers_end_event(self):
        bus=self.start_average_match();host=bus.clients[0];guest=bus.clients[1]
        host.run("MPAPI._internal.lobby.apply_game_ended(current,{runId='run-1',status='agreed'})");bus.flush()
        self.assertTrue(host.value('D.recap.available()'))
        self.assertEqual(guest.value('#D.recap.context.parts'),5)
        self.assertFalse(guest.value('D.recap.available()'),'Packets may queue but cannot expose a running match')
        for c in bus.clients[1:]:c.run("MPAPI._internal.lobby.apply_game_ended(current,{runId='run-1',status='agreed'})")
        self.assertTrue(all(c.value('D.recap.available()') for c in bus.clients))

    def test_recap_rejects_wrong_sender_run_lobby_and_incomplete_catalog(self):
        bus=self.start_average_match();host=bus.clients[0];guest=bus.clients[1]
        ctx={key:host.value('D.recap.context.'+key) for key in ('session','identity')}
        player=host.value('D.recap.context.payload.players[1]')
        packet={'protocol':4,'kind':'recap_part','session':ctx['session'],'room':'ROOM','recipient':'p2',
                'data':{'run':ctx['identity'],'slot':1,'player':player}}
        def deliver(sender,body):
            guest.receive({'cid':'test-recap','action':'draftout_pack_v4','from':sender,'to':'p2','params':{'packet':body}})
        deliver('p3',packet);self.assertIsNone(guest.value('D.recap.context.parts[1]'))
        wrong=copy.deepcopy(packet);wrong['data']['run']='old-match';deliver('p1',wrong)
        self.assertIsNone(guest.value('D.recap.context.parts[1]'))
        wrong=copy.deepcopy(packet);wrong['recipient']='p4';deliver('p1',wrong)
        self.assertIsNone(guest.value('D.recap.context.parts[1]'))
        wrong=copy.deepcopy(packet);wrong['data']['player']['keys']*=3;deliver('p1',wrong)
        self.assertIsNone(guest.value('D.recap.context.parts[1]'))
        guest.run("old=current; new_lobby('MultiplayerPvP','private','pvp_royale')")
        deliver('p1',packet);self.assertIsNone(guest.value('D.recap.context.parts[1]'))
        self.assertFalse(guest.value('D.recap.available()'))

    def test_recap_reaches_remaining_players_after_a_player_leaves(self):
        bus=self.start_average_match()
        for c in bus.clients:
            c.run("current._players.p4=nil; current:_fire('player_left','p4')")
        self.finish_match(bus,order=(0,1,2))
        for c in bus.clients[:3]:
            self.assertTrue(c.value('D.recap.available()'))
            self.assertEqual(len(c.value('D.mod.config.last_recap.players')),4)
        self.assertFalse(bus.clients[3].value('D.recap.available()'))

    def test_four_pack_recap_contains_exact_pick_history_and_one_omission(self):
        bus=Bus();host=bus.clients[0]
        host.run('D.mod.config.packs_per_player=4; D.mod.config.picks_per_turn=1')
        bus.draft();host.run('PVP.pvp_start_match(); Game:update(0.02)');bus.flush()
        self.finish_match(bus,order=(1,2,3,0))
        for c in bus.clients:
            recap=c.value('D.mod.config.last_recap')
            self.assertEqual(len(recap['omitted']),1)
            for player in recap['players']:
                self.assertEqual(len(player['keys']),35)
                self.assertEqual(len(player['history']),35)
                self.assertEqual([e['keys'][0] for e in player['history']],player['keys'])
                self.assertEqual(player['history'][-1]['round'],4)

    @unittest.skipIf((API/'api/matchmaking/group/party.lua').exists(),
        'Legacy picker; native_picker_spec covers the 1.0.3 replacement')
    def test_shared_deck_host_alone_and_guests_read_only(self):
        bus=Bus(); host=bus.clients[0]
        host.run("saved_players=current._players; current._players={p1=saved_players.p1}")
        self.assertTrue(host.value('D.deck_picker.can_select()'))
        host.run("D.deck_picker.select('b_blue',current)")
        self.assertFalse(host.value('D.deck_picker.synced()'))
        bus.flush()
        for c in bus.clients:
            self.assertEqual(c.value('current:get_metadata().deck'),'Blue Deck')
        self.assertTrue(host.value('D.deck_picker.synced()'))
        host.run('current._players=saved_players')
        for c in bus.clients:
            c.run('deck_node=find_deck(PVP.lobby.build_controls())')
            self.assertTrue(c.value('deck_node~=nil'))
            self.assertEqual(c.value('deck_node.config.button'),'draftout_deck_open' if c.index==1 else None)
        guest=bus.clients[1]
        ok,_=guest.run("return pcall(D.deck_picker.select,'b_red',current)")
        self.assertFalse(ok)
        self.assertEqual(len(bus.queue),0)
        ok,_=host.run("return pcall(D.deck_picker.select,'b_modded',current)")
        self.assertFalse(ok)

    @unittest.skipIf((API/'api/matchmaking/group/party.lua').exists(),
        'Legacy picker; native_picker_spec covers the 1.0.3 replacement')
    def test_shared_deck_after_draft_launch_and_native_run_handoff(self):
        bus=Bus(); bus.draft(); host=bus.clients[0]
        pools=[c.value('B.pool.keys') for c in bus.clients]
        host.run("D.deck_picker.select('b_yellow',current)")
        self.assertFalse(host.value('B.launch_ready()'))
        bus.flush()
        for c in bus.clients:
            c.run('PVP.LOBBY.config.different_decks=true; PVP.LOBBY.config.random_loadout=true')
        host.run('PVP.pvp_start_match(); Game:update(0.02)'); bus.flush()
        native_start=re.search(r'function PVP\.on_game_start\(params\).*?\nend',(PVP/'pvp_api/actions/run_lifecycle.lua').read_text(),re.S).group()
        handlers=(PVP/'networking/action_handlers.lua').read_text()
        copy_deck=re.search(r'function G\.FUNCS\.copy_host_deck\(\).*?\nend',handlers,re.S).group()
        run_start=re.search(r'function G\.FUNCS\.lobby_start_run\(e, args\).*?\nend',handlers,re.S).group()
        for i,c in enumerate(bus.clients):
            self.assertEqual(c.value('run_back'),'Yellow Deck')
            self.assertEqual(c.value('run_pool.keys'),pools[i])
            self.assertFalse(c.value('PVP.LOBBY.config.different_decks'))
            self.assertFalse(c.value('D.deck_picker.can_select()'))
            c.run(native_start+'\n'+copy_deck+'\n'+run_start)
            c.run("""
                MPAPI.has_server_referee=function() return false end
                MPAPI.back_for_key=function(key) return {key=key} end
                PVP.UTILS.get_deck_key_from_name=function(name)
                    for key,center in pairs(G.P_CENTERS) do if center.name==name then return key end end
                end
                PVP.publish_drafted_loadout=function() end
                PVP.dispatch_action=function(_,args) G.FUNCS.lobby_start_run(nil,args) end
                G.FUNCS.start_run=function(_,args) native_back=G.GAME.viewed_back.key; native_seed=args.seed end
                PVP.on_game_start({seed='NATIVESEED',stake=1})
            """)
            self.assertEqual(c.value('native_back'),'b_yellow')
            self.assertEqual(c.value('native_seed'),'NATIVESEED')

    def test_shared_deck_picker_buttons_apply_and_close(self):
        bus=Bus(); host=bus.clients[0]
        host.run("""
            D.ui.line=function(text) return {config={text=text}} end
            D.ui.row=function(nodes) return {nodes=nodes} end
            D.ui.button=function(label,action,data) return {n=G.UIT.C,config={text=label,button=action,ref_table=data},nodes={{n=G.UIT.T,config={text=label}}}} end
            create_UIBox_generic_options=function(options) return options end
            G.FUNCS.overlay_menu=function(options) picker_definition=options.definition; G.OVERLAY_MENU={} end
            MPAPI.refresh_current_view=function() refreshed=true end
            G.FUNCS.draftout_deck_open()
            picker_rows=picker_definition.contents
            function find_choice(node,key)
                if node.config and node.config.button=='draftout_deck_select'
                    and node.config.ref_table.key==key then return node end
                for _,child in ipairs(node.nodes or node.contents or {}) do
                    local found=find_choice(child,key);if found then return found end
                end
            end
            blue_button=find_choice(picker_definition,'b_blue')
        """)
        self.assertEqual(host.value('blue_button.config.text'),'Blue Deck')
        self.assertEqual(host.value('picker_definition.back_func'),'draftout_deck_close')
        host.run('G.FUNCS.draftout_deck_select(blue_button)')
        self.assertEqual(len(bus.queue),0,'Preview must not apply the deck')
        self.assertEqual(host.value('D.deck_picker.preview_key'),'b_blue')
        host.run('G.FUNCS.draftout_deck_apply({config={ref_table={key=D.deck_picker.preview_key,lobby=current}}})')
        self.assertIsNone(host.value('G.OVERLAY_MENU'))
        self.assertTrue(host.value('refreshed'))
        bus.flush()
        self.assertEqual(host.value('current:get_metadata().deck'),'Blue Deck')

    def test_deck_art_and_description_preview_does_not_change_shared_choice(self):
        bus=Bus(); host=bus.clients[0]
        host.run("""
            G.CARD_W=1.4; G.CARD_H=1.9; G.ASSET_ATLAS={centers={}}
            G.P_CENTERS.b_blue.pos={x=1,y=0}
            original_viewed={name='original'}; G.GAME.viewed_back=original_viewed
            preview_created=0;preview_removed=0
            Sprite=function(x,y,w,h,atlas,pos)
                preview_pos=pos;preview_created=preview_created+1
                return {remove=function() preview_removed=preview_removed+1 end}
            end
            Back=function(center) return {generate_UI=function(_,target)
                preview_description=target.key
                return {n=G.UIT.ROOT,config={id='native_deck_description'},nodes={
                    {config={text='First line'}},{config={text='Second line'}},{config={text='Third line'}}}}
            end} end
            UIBox=function() error('Description must participate in the parent layout, not be a detached UIBox') end
            create_UIBox_generic_options=function(args) return args end
            G.FUNCS.overlay_menu=function(args) preview_definition=args.definition;G.OVERLAY_MENU={} end
            G.FUNCS.draftout_deck_open()
            G.FUNCS.draftout_deck_select({config={ref_table={key='b_blue',lobby=current}}})
        """)
        self.assertEqual(host.value('preview_pos.x'),1)
        self.assertEqual(host.value('preview_description'),'b_blue')
        host.run("""
            function find_description(n)
                if n.config and n.config.id=='native_deck_description' then return n end
                for _,child in ipairs(n.nodes or n.contents or {}) do
                    local found=find_description(child);if found then return found end
                end
            end
            description_node=find_description(preview_definition)
        """)
        self.assertEqual(host.value('#description_node.nodes'),3)
        self.assertIsNone(host.value('description_node.config.maxh'))
        self.assertTrue(host.value('G.GAME.viewed_back==original_viewed'))
        self.assertEqual(len(bus.queue),0)
        host.run('G.FUNCS.draftout_deck_close()')
        self.assertEqual(host.value('preview_created'),host.value('preview_removed'))
        self.assertEqual(len(bus.queue),0)

    def test_shared_deck_stale_lobby_and_other_modes_are_blocked(self):
        bus=Bus(); host=bus.clients[0]
        host.run("old_lobby=current; new_lobby('MultiplayerPvP','private','pvp_royale')")
        ok,_=host.run("return pcall(D.deck_picker.select,'b_blue',old_lobby)")
        self.assertFalse(ok)
        for mode in ('pvp_nemesis','pvp_teams'):
            host.run(f"current._metadata.queue_mode='{mode}'")
            self.assertFalse(host.value('D.deck_picker.can_select()'))
            self.assertIsNone(host.value('find_deck(PVP.lobby.build_controls())'))
        host.run("current._metadata.queue_mode='pvp_royale'; D.mod.config.native_draft=false")
        self.assertFalse(host.value('D.deck_picker.can_select()'))

    def test_lobby_close_and_pointer_change_clear_ephemeral_session(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run("old_session=B.session; current:_fire('lobby_closed')")
        self.assertEqual(host.value('B.phase'),'idle')
        self.assertIsNone(host.value('B.session'))
        host.run("D.message='local menu'; for i=1,100 do Game:update(0.01) end")
        self.assertEqual(host.value('D.message'),'local menu')
        host.run("new_lobby('MultiplayerPvP','private','pvp_royale'); B.begin(); current=nil; Game:update(0.01)")
        self.assertIsNone(host.value('B.host_state'))
        self.assertIsNone(host.value('B.room'))

    def test_frame_checks_are_throttled_but_commands_validate_fresh(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run("""
            original_get_players=current.get_players; roster_reads=0
            current.get_players=function(self) roster_reads=roster_reads+1; return original_get_players(self) end
            for i=1,300 do clock=13+i/60; Game:update(1/60) end
        """)
        self.assertLessEqual(host.value('roster_reads'),25)
        host.run("current._players.p4=nil")
        ok,_=host.run('return pcall(B.start_draft)')
        self.assertFalse(ok)

    def test_missing_release_and_completion_ack_recover_without_repeated_saves(self):
        for missing in ('final_view','complete_ack','release','release_ack'):
            with self.subTest(missing=missing):
                bus=Bus(); remaining=[True]
                def drop(sender,packet):
                    kind=packet.get('params',{}).get('packet',{}).get('kind')
                    if (kind==missing or (missing=='final_view' and kind=='view' and packet['params']['packet']['data'].get('done'))) and remaining[0]: remaining[0]=False; return True
                    return False
                bus.drop=drop; bus.draft()
                for n in range(4):
                    for c in bus.clients: c.run(f'clock={20+n*2}; Game:update(0.02)')
                    bus.flush()
                self.assertEqual(len(bus.dropped),1)
                self.assertTrue(bus.clients[0].value('B.launch_ready()'))
                for c in bus.clients: self.assertEqual(c.value('config_saves'),1)

    def test_retired_session_offer_cannot_reopen_a_closed_draft(self):
        bus=Bus(); bus.begin(); host,guest=bus.clients[:2]
        session=guest.value('B.session')
        catalog='|'.join(host.value('keys'))
        guest.run("current:_fire('lobby_closed')")
        guest.receive({'cid':'retired','action':'draftout_pack_v4','from':'p1','to':'p2',
            'params':{'packet':{'protocol':4,'kind':'offer','room':'ROOM','session':session,'recipient':'p2',
            'data':{'ids':['p1','p2','p3','p4'],'catalog':catalog,'rules':5}}}})
        self.assertIsNone(guest.value('B.session'))
        self.assertEqual(guest.value('B.phase'),'idle')

    def test_malformed_average_packets_are_ignored_without_touching_revision(self):
        bus=self.start_average_match(); guest=bus.clients[1]
        for mean,count,finished,final in [('bad',4,4,True),('100',-1,0,False),('100',4,5,True),('100',4,4,False)]:
            packet={'protocol':4,'kind':'combat_average','session':guest.value('B.session'),'room':'ROOM','recipient':'p2',
                'data':{'revision':999,'average':mean,'safe':{},'count':count,'finished':finished,'final':final}}
            guest.receive({'cid':'malformed','action':'draftout_pack_v4','from':'p1','to':'p2','params':{'packet':packet}})
            self.assertNotEqual(guest.value('D.average_pvp.received'),999)

    def test_completed_draft_survives_balance_and_deck_changes_for_two_and_four(self):
        for players in (2,4):
            bus=Bus(player_count=players);bus.draft();host=bus.clients[0]
            saved=[(c.value('B.session'),c.value('B.pool.keys')) for c in bus.clients]
            host.run("D.deck_picker.select('b_blue',current)");bus.flush()
            # Actual native lobby-option callback, wrapped by the mod. Native
            # config.back is deliberately stale to reproduce the deck reset.
            host.run("PVP.LOBBY.config.back='Red Deck';G.FUNCS.mp_pvp_change_ruleset({to_key=2})")
            self.assertFalse(host.value('B.launch_ready()'))
            bus.flush()
            for c,(session,pool) in zip(bus.clients,saved):
                c.run('Game:update(0.01)')
                self.assertEqual(c.value('B.phase'),'complete')
                self.assertEqual(c.value('B.session'),session)
                self.assertEqual(c.value('B.pool.keys'),pool)
                self.assertEqual(c.value('current:get_metadata().ruleset'),'ruleset_mp_balanced')
                self.assertEqual(c.value('current:get_metadata().deck'),'Blue Deck')
            host.run("D.deck_picker.select('b_yellow',current,'ruleset_mp_vanilla')")
            bus.flush();host.run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
            for c,(_,pool) in zip(bus.clients,saved):
                self.assertEqual(c.value('run_pool.keys'),pool)
                if c.value('D.deck_picker.native_picker'):
                    self.assertEqual(c.value('current:get_metadata().deck'),'Yellow Deck')
                else:self.assertEqual(c.value('run_back'),'Yellow Deck')
                self.assertEqual(c.value('current:get_metadata().ruleset'),'ruleset_mp_vanilla')

    def test_balance_controls_block_guests_active_draft_and_unacked_release(self):
        bus=Bus();host,guest=bus.clients[:2]
        ok,_=guest.run("return pcall(D.deck_picker.select_balance,'ruleset_mp_balanced',current)")
        self.assertFalse(ok)
        bus.begin()
        ok,_=host.run("return pcall(D.deck_picker.select_balance,'ruleset_mp_balanced',current)")
        self.assertFalse(ok)
        bus.draft()
        host.run('B.release_ack.p2=nil')
        self.assertFalse(host.value('D.deck_picker.can_balance()'))
        host.run('B.release_ack.p2=true;B.pending_launch=true')
        self.assertFalse(host.value('D.deck_picker.can_balance()'))

    def test_lobby_draft_button_for_host_and_guest_keeps_existing_draft(self):
        bus=Bus();host,guest=bus.clients[:2]
        for c in bus.clients:
            c.run("""
                function find_draft(node)
                    if node.config and node.config.id=='draftout_lobby_draft' then return node end
                    for _,child in ipairs(node.nodes or {}) do
                        local found=find_draft(child);if found then return found end
                    end
                end
                draft_button=find_draft(PVP.lobby.build_controls())
            """)
            self.assertEqual(c.value('draft_button.config.button'),'draftout_lobby_draft')
        guest.run('G.FUNCS.draftout_lobby_draft()')
        self.assertEqual(guest.value('ui_shows'),1)
        self.assertIsNone(guest.value('B.session'))
        host.run('G.FUNCS.draftout_lobby_draft()');bus.flush()
        self.assertEqual(host.value('B.phase'),'checking')
        bus.draft();session=host.value('B.session')
        for c in bus.clients:c.run('G.FUNCS.draftout_lobby_draft()')
        self.assertEqual(host.value('B.session'),session)
        self.assertTrue(host.value('B.launch_ready()'))

    def test_metadata_change_invalidates_cached_display_check_immediately(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run("clock=13; Game:update(0.01); current._metadata.ruleset='changed'; current:_fire('metadata_changed'); Game:update(0.01)")
        self.assertEqual(host.value('B.phase'),'error')

    def test_duplicate_game_started_does_not_reset_lives_or_start_twice(self):
        bus=self.start_average_match(); host=bus.clients[0]
        self.play_average_round(bus,{1:1000,2:100,3:100,4:100})
        for c in bus.clients: c.run("PVP.on_game_start(current._game.started)")
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),3)
        for c in bus.clients: self.assertEqual(c.value('game_starts'),1)

    def test_new_seed_restart_is_not_mistaken_for_a_duplicate_notification(self):
        bus=self.start_average_match()
        for c in bus.clients:
            c.run("PVP.on_game_start({run_id='run-1',seed='RESTARTSEED',restarted=true})")
            self.assertEqual(c.value('game_starts'),2)
            self.assertEqual(c.value('run_seed'),'RESTARTSEED')
            c.run("PVP.on_game_start({run_id='run-1',seed='RESTARTSEED',restarted=true})")
            self.assertEqual(c.value('game_starts'),2)

    def test_real_referee_checkpoint_metadata_echo_does_not_restart_draft(self):
        bus=Bus(checkpoints=True); bus.draft(); host=bus.clients[0]
        host.run('PVP.pvp_start_match(); Game:update(0.02)'); bus.flush()
        self.assertTrue(any('_pvp_ref' in p for p in bus.metadata))
        self.play_average_round(bus,{1:400,2:300,3:200,4:100})
        checkpoint=host.value('current:get_metadata()._pvp_ref')
        self.assertEqual(checkpoint['players']['p4']['lives'],3)
        for c in bus.clients:
            c.run('clock=20; Game:update(0.02)')
            self.assertEqual(c.value('B.phase'),'playing')
            self.assertEqual(c.value('game_starts'),1)

    def start_average_match(self):
        bus=Bus(); bus.draft()
        bus.clients[0].run('PVP.pvp_start_match(); Game:update(0.02)'); bus.flush()
        return bus

    def open_average_round(self,bus,ante=None):
        host=bus.clients[0]
        if ante is None:ante=(host.value('D.average_pvp.rounds.ante') or 1)+1
        for c in bus.clients:c.run(f'G.GAME.round_resets={{ante={ante}}}; G.GAME.round={ante*3};test_pvp=true')
        for i in range(1,5):
            if host.value(f'PVP.REF.players.p{i}.lives')>0 and host.value(f'current._players.p{i}~=nil'):
                host.run(f"PVP.referee_on_set_ante('p{i}',{{ante={ante}}});PVP.referee_on_new_round('p{i}');PVP.referee_on_ready_blind('p{i}',4)")
        bus.flush()

    def play_average_round(self,bus,scores):
        host=bus.clients[0]
        if not host.value('D.average_pvp.rounds.open'):self.open_average_round(bus)
        for i,score in scores.items():
            host.lua.globals().test_score=str(score)
            host.run(f"PVP.referee_on_play_hand('p{i}',{{score=test_score,handsLeft=0}})")
            bus.flush()

    def wire(self,bus,index,action,**params):
        client=bus.clients[index-1]
        client.lua.globals().report=client.lua.table_from(dict(action=action,**params),recursive=True)
        client.run('if PVP.Score and report.score then report.score=PVP.Score.from_game_value(report.score) end;Client.send(report)')
        bus.flush()

    def wire_open(self,bus,ante):
        host=bus.clients[bus.host_index]
        ids=[i for i in range(1,bus.player_count+1) if host.value(f'PVP.REF.players.p{i}.lives')>0 and host.value(f'current._players.p{i}~=nil')]
        for c in bus.clients:
            if c.index in bus.offline:continue
            c.run(f"G.GAME.round_resets={{ante={ante}}};G.GAME.round={ante*3};G.GAME.blind_on_deck='Boss';test_pvp=true")
        for i in ids:
            self.wire(bus,i,'setAnte',ante=ante)
            self.wire(bus,i,'newRound')
            self.wire(bus,i,'readyBlind',startingHands=4)
        self.assertTrue(host.value('D.average_pvp.rounds.open'))
        return ids

    def outcome_count(self,client,key):
        return client.value("(function() local n=0;for _,o in ipairs(outcomes) do if o.key=='"+key+"' then n=n+1 end end;return n end)()")

    def test_host_handover_between_normal_blinds_preserves_lives_and_pools(self):
        bus=self.start_average_match();pools=[c.value('run_pool.keys') for c in bus.clients]
        for c in bus.clients:c.run("G.GAME.round_resets={ante=1};G.GAME.round=1;G.GAME.blind_on_deck='Small';test_pvp=false")
        self.wire(bus,3,'failRound')
        expected=bus.clients[0].value('D.recap.context.payload')
        bus.handover(1,2)
        host=bus.clients[1]
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],[0,4,3,4])
        for c in bus.clients[1:]:
            self.assertEqual(c.value('B.phase'),'playing')
            self.assertEqual(c.value('B.owner'),'p2')
            self.assertEqual(c.value('run_pool.keys'),pools[c.index-1])
            self.assertFalse(c.value('D.recap.available()'))
            self.assertFalse(c.value('warnings'))
        self.wire_open(bus,2)
        for i,s in [(2,300),(3,200),(4,100)]:self.wire(bus,i,'playHand',score=str(s),handsLeft=0)
        self.assertEqual(host.value('D.average_pvp.view.average'),'200')
        self.assertEqual(host.value('PVP.REF.players.p4.lives'),3)
        self.finish_match(bus)
        for c in bus.clients[1:]:self.assertEqual(c.value('D.mod.config.last_recap'),expected)

    def test_host_handover_mid_pvp_preserves_scores_and_finishes_once(self):
        for left_first in (True,False):
            with self.subTest(left_first=left_first):
                bus=self.start_average_match();self.wire_open(bus,2)
                self.wire(bus,1,'playHand',score='1e30',handsLeft=2)
                self.wire(bus,2,'playHand',score='300',handsLeft=0)
                self.wire(bus,3,'playHand',score='200',handsLeft=0)
                bus.handover(1,2,left_first=left_first);host=bus.clients[1]
                self.assertTrue(host.value('D.average_pvp.rounds.open'))
                self.assertEqual(host.value('PVP.REF.players.p2.hands_left'),0)
                self.assertAlmostEqual(float(host.value('D.average_pvp.view.average')),500/3,places=5)
                self.wire(bus,4,'playHand',score='100',handsLeft=0)
                self.assertEqual(host.value('D.average_pvp.view.average'),'200')
                for c in bus.clients[1:]:
                    self.assertEqual(c.value('client_lives.p4'),3)
                    self.assertEqual(self.outcome_count(c,'pvp_end_pvp'),1)
                self.assertIsNone(host.value('D.average_pvp.rounds.handover.blocked'))

    def test_host_handover_restores_partially_ready_barrier(self):
        bus=self.start_average_match()
        for c in bus.clients:c.run("G.GAME.round_resets={ante=2};G.GAME.round=6;test_pvp=true")
        for i in (2,3,4):
            self.wire(bus,i,'setAnte',ante=2)
            self.wire(bus,i,'readyBlind',startingHands=i+1)
        self.assertFalse(bus.clients[0].value('D.average_pvp.rounds.open'))
        bus.handover(1,2);host=bus.clients[1]
        self.assertTrue(host.value('D.average_pvp.rounds.open'))
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.hands_left') for i in (2,3,4)],[3,4,5])
        self.assertTrue(all(self.outcome_count(c,'pvp_start_blind')==1 for c in bus.clients[1:]))

    def test_host_disconnect_forfeits_and_reconnect_cannot_restore_lives(self):
        bus=self.start_average_match();self.wire_open(bus,2)
        bus.handover(1,2,away=True);host=bus.clients[1]
        self.assertEqual(host.value('PVP.REF.players.p1.lives'),0)
        for c in bus.clients[1:]:
            c.run("MPAPI._internal.lobby.apply_event(current,{type='player_reconnected',playerId='p1'})")
        host.run("PVP.referee_on_player_reconnected('p1')");bus.flush()
        self.assertEqual(host.value('PVP.REF.players.p1.lives'),0)
        host.run("PVP.referee_n_player_forfeit('p1')");bus.flush()
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],[0,4,4,4])

    def test_unacknowledged_report_is_retried_on_new_host(self):
        bus=self.start_average_match();self.wire_open(bus,2)
        bus.drop=lambda sender,p:sender=='p3' and p.get('action')=='pvp_play_hand'
        self.wire(bus,3,'playHand',score='200',handsLeft=0)
        self.assertEqual(bus.clients[0].value('PVP.REF.players.p3.hands_left'),4)
        self.assertTrue(bus.clients[2].value('next(D.average_pvp.rounds.handover.journal)~=nil'))
        bus.drop=None;bus.handover(1,2);host=bus.clients[1]
        self.assertEqual(host.value('PVP.REF.players.p3.hands_left'),0)
        self.assertFalse(bus.clients[2].value('next(D.average_pvp.rounds.handover.journal)~=nil'))
        for i,s in [(2,300),(4,100)]:self.wire(bus,i,'playHand',score=str(s),handsLeft=0)
        self.assertEqual(host.value('PVP.REF.players.p4.lives'),3)
        self.assertTrue(all(self.outcome_count(c,'pvp_end_pvp')==1 for c in bus.clients[1:]))

    def test_committed_unsent_outcomes_recover_without_duplicate_life_loss(self):
        for dropped in (False,True):
            with self.subTest(dropped=dropped):
                bus=self.start_average_match();self.wire_open(bus,2)
                if dropped:bus.drop=lambda sender,p:sender=='p1' and p.get('action') in ('pvp_player_lives','pvp_end_pvp')
                for i,s in [(1,300),(2,300),(3,300),(4,100)]:self.wire(bus,i,'playHand',score=str(s),handsLeft=0)
                if not dropped:self.wire(bus,4,'newRound')
                bus.drop=None;bus.handover(1,2);host=bus.clients[1]
                self.assertEqual(host.value('PVP.REF.players.p4.lives'),3)
                self.assertFalse(host.value('D.average_pvp.rounds.open'))
                for c in bus.clients[1:]:
                    self.assertEqual(c.value('client_lives.p4'),3)
                    self.assertEqual(self.outcome_count(c,'pvp_end_pvp'),1)
                self.wire_open(bus,3)
                for i,s in [(2,300),(3,300),(4,100)]:self.wire(bus,i,'playHand',score=str(s),handsLeft=0)
                self.assertEqual(host.value('PVP.REF.players.p4.lives'),2)

    def test_two_host_departures_keep_native_final_duel_and_recap(self):
        bus=self.start_average_match();self.wire_open(bus,2)
        for i in (1,2,3,4):self.wire(bus,i,'playHand',score='100',handsLeft=0)
        bus.handover(1,2)
        for ante in range(3,8):
            self.wire_open(bus,ante)
            for i in (2,3,4):self.wire(bus,i,'playHand',score='100',handsLeft=0)
        self.wire_open(bus,8)
        self.wire(bus,3,'playHand',score='200',handsLeft=3)
        bus.handover(2,3);host=bus.clients[2]
        self.assertTrue(host.value('PVP.referee_resolve_2p_round==native_two_player_resolver'))
        self.assertTrue(all(c.value('D.average_pvp.duel') for c in bus.clients[2:]))
        self.wire(bus,4,'playHand',score='100',handsLeft=0)
        self.assertEqual(host.value('PVP.REF.players.p4.lives'),3)
        self.assertEqual(host.value('PVP.REF.players.p3.hands_left'),3,'Native early finish does not wait for the winner')
        for ante in range(9,12):
            self.wire_open(bus,ante)
            self.wire(bus,3,'playHand',score='200',handsLeft=3)
            self.wire(bus,4,'playHand',score='100',handsLeft=0)
        self.assertEqual(host.value('PVP.REF.players.p4.lives'),0)
        self.assertEqual(self.outcome_count(host,'pvp_win'),1)
        self.assertTrue(host.value('D.average_pvp.rounds.finished'))
        self.finish_match(bus)
        self.assertTrue(all(c.value('D.recap.available()') for c in bus.clients[2:]))
        self.assertEqual(bus.clients[2].value('D.mod.config.last_recap'),bus.clients[3].value('D.mod.config.last_recap'))

    def test_eliminated_player_can_take_over_referee_without_rejoining_match(self):
        bus=self.start_average_match();host=bus.clients[0]
        host.run("PVP.referee_n_player_forfeit('p4')");bus.flush()
        self.assertTrue(bus.clients[3].value('PVP.GAME.eliminated'))
        bus.handover(1,4);host=bus.clients[3]
        self.assertEqual(host.value('PVP.REF.players.p4.lives'),0)
        self.assertTrue(host.value('PVP.GAME.eliminated'))
        self.wire_open(bus,2)
        self.wire(bus,2,'playHand',score='200',handsLeft=3)
        self.wire(bus,3,'playHand',score='100',handsLeft=0)
        self.assertEqual(host.value('PVP.REF.players.p3.lives'),3)
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),4)

    def test_invalid_handover_checkpoint_pauses_instead_of_rebuilding_lives(self):
        for corruption in ("current._metadata._pvp_ref=nil", "current._metadata._pvp_ref.draftout.run='stale'",
                           "current._metadata._pvp_ref.draftout.recap.pools[1][1]=9999"):
            with self.subTest(corruption=corruption):
                bus=self.start_average_match();bus.clients[1].run(corruption)
                bus.handover(1,2);host=bus.clients[1]
                self.assertTrue(host.value('D.average_pvp.rounds.handover.blocked'))
                self.assertEqual(host.value('B.phase'),'error')
                self.assertIn('Host handover paused',host.value('B.message'))
                self.assertEqual(self.outcome_count(host,'pvp_win'),0)

    def test_old_host_outcomes_and_duplicate_host_change_are_ignored(self):
        bus=self.start_average_match();self.wire_open(bus,2)
        bus.handover(1,2);host=bus.clients[1]
        before=[c.value('client_lives') for c in bus.clients[1:]]
        for c in bus.clients[1:]:
            c.run("MPAPI._internal.lobby.apply_event(current,{type='host_changed',playerId='p2'})")
        bus.flush()
        self.assertEqual(host.value('D.average_pvp.rounds.handover.authority'),1)
        bus.clients[0].run("current:action(MPAPI.ActionTypes.pvp_player_lives):broadcast({player_id='p3',lives=0})")
        bus.flush()
        self.assertEqual([c.value('client_lives') for c in bus.clients[1:]],before)

    def test_recovery_checkpoint_is_compact_and_recap_ui_stays_locked(self):
        bus=Bus();bus.clients[0].run('D.mod.config.packs_per_player=4;D.mod.config.picks_per_turn=1')
        bus.draft();bus.clients[0].run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
        snap=bus.clients[0].value('current:get_metadata()._pvp_ref')
        self.assertLess(len(json.dumps(snap)),7000)
        self.assertEqual(len(snap['draftout']['recap']['pools'][0]),35)
        bus.handover(1,2)
        self.assertTrue(all(not c.value('D.recap.available()') for c in bus.clients[1:]))
        self.finish_match(bus)
        self.assertEqual(len(bus.clients[1].value('D.mod.config.last_recap.omitted')),1)

    def test_handover_with_actual_native_outcome_handlers_reports_one_winner(self):
        bus=Bus(native_outcomes=True);bus.draft()
        bus.clients[0].run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
        bus.handover(1,2);host=bus.clients[1]
        host.run("PVP.referee_n_player_forfeit('p4')");bus.flush()
        self.assertTrue(bus.clients[3].value('PVP.GAME.eliminated'))
        for ante in range(2,6):
            self.wire_open(bus,ante)
            self.wire(bus,3,'playHand',score='200',handsLeft=3)
            self.wire(bus,2,'playHand',score='100',handsLeft=0)
        for c in bus.clients[1:]:
            self.assertEqual(c.value('server_results'),['p3'])
            self.assertEqual(c.value('PVP._player_lives_cache.p2'),0)
        self.assertEqual(bus.clients[2].value('PVP.GAME.lives'),4)
        self.assertTrue(bus.clients[2].value("native_actions[#native_actions].kind=='winGame'"))
        self.finish_match(bus)
        self.assertTrue(all(c.value('D.recap.available()') for c in bus.clients[1:]))

    def test_rapid_host_departures_use_last_committed_checkpoint(self):
        bus=self.start_average_match()
        bus.offline={1,2};bus.host_index=2
        for c in bus.clients[2:]:
            # Both host changes arrive before the first successor's writes can
            # reach the server. Recovery must still forfeit both departed seats.
            c.run("MPAPI._internal.lobby.apply_event(current,{type='host_changed',playerId='p2'});"
                  "MPAPI._internal.lobby.apply_event(current,{type='host_changed',playerId='p3'})")
        bus.flush()
        for c in bus.clients[2:]:c.run('Game:update(0.02)')
        bus.flush();host=bus.clients[2]
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],[0,0,4,4])
        self.assertEqual(host.value('D.average_pvp.rounds.handover.authority'),2)
        self.wire_open(bus,2)
        self.wire(bus,3,'playHand',score='200',handsLeft=3)
        self.wire(bus,4,'playHand',score='100',handsLeft=0)
        self.assertEqual(host.value('PVP.REF.players.p4.lives'),3)

    def recovery_tick(self,bus):
        for c in bus.clients:
            if c.index not in bus.offline:c.run('clock=clock+4;Game:update(0.02)')
        bus.flush()

    def test_recovery_retries_missing_final_report_through_api(self):
        bus=self.start_average_match();host=bus.clients[0]
        self.wire_open(bus,2)
        bus.drop=lambda sender,p:sender=='p4' and p.get('action')=='pvp_play_hand'
        for i in range(1,5):self.wire(bus,i,'playHand',score=str(i*100),handsLeft=0)
        self.assertTrue(host.value('D.average_pvp.rounds.open'))
        bus.drop=None;self.recovery_tick(bus)
        self.assertFalse(host.value('D.average_pvp.rounds.open'))
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),1)
        self.recovery_tick(bus)
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],[3,3,4,4])
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),1)

    def test_recovery_retains_outcome_after_next_ante_metadata(self):
        bus=self.start_average_match();host=bus.clients[0]
        self.wire_open(bus,2)
        bus.drop=lambda _,p:p.get('action') in ('pvp_end_pvp','pvp_player_lives')
        for i in range(1,5):self.wire(bus,i,'playHand',score=str(i*100),handsLeft=0)
        self.assertEqual(self.outcome_count(bus.clients[3],'pvp_end_pvp'),0)
        bus.drop=None
        host.run('G.GAME.round_resets.ante=3')
        self.wire(bus,1,'setAnte',ante=3);self.wire(bus,1,'newRound')
        self.recovery_tick(bus)
        for c in bus.clients[1:]:
            self.assertEqual(self.outcome_count(c,'pvp_end_pvp'),1)
            self.assertEqual(c.value('client_lives.p2'),3)
        self.recovery_tick(bus)
        for c in bus.clients[1:]:self.assertEqual(self.outcome_count(c,'pvp_end_pvp'),1)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),0,'Do not apply old outcomes to a new ante')

    def test_recovery_twelve_rounds_lost_results_and_native_duel(self):
        bus=Bus(checkpoints=True,native_outcomes=True);bus.draft();host=bus.clients[0]
        host.run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
        for offset,loser in enumerate([4]*4+[3]*4+[2]*4):
            ids=self.wire_open(bus,offset+2)
            bus.drop=lambda _,p:p.get('action') in ('pvp_end_pvp','pvp_win','pvp_eliminated','pvp_player_lives')
            for i in reversed(ids):self.wire(bus,i,'playHand',score='0' if i==loser else '100',handsLeft=0)
            bus.drop=None;self.recovery_tick(bus);self.recovery_tick(bus)
            self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),min(offset+1,11))
            self.assertEqual(host.value(f'PVP.REF.players.p{loser}.lives'),3-offset%4)
        for c in bus.clients:
            self.assertEqual(self.outcome_count(c,'pvp_win'),1)
            self.assertEqual(c.value('server_results'),['p1'])
        self.assertTrue(host.value('PVP.referee_resolve_2p_round==native_two_player_resolver'))

    def test_recovery_before_match_ended_and_after_host_change(self):
        bus=self.start_average_match();host=bus.clients[0]
        self.wire_open(bus,2)
        bus.drop=lambda _,p:p.get('action')=='pvp_end_pvp'
        for i in range(1,5):self.wire(bus,i,'playHand',score='100',handsLeft=0)
        bus.drop=None;bus.handover(1,2)
        self.recovery_tick(bus)
        for c in bus.clients[1:]:self.assertEqual(self.outcome_count(c,'pvp_end_pvp'),1)
        # A terminal server notification can precede the next recovery tick.
        bus=self.start_average_match();host=bus.clients[0]
        self.wire_open(bus,2)
        bus.drop=lambda _,p:p.get('action')=='pvp_win'
        for i in (4,3,2):
            host.run(f"PVP.referee_n_player_forfeit('p{i}')");bus.flush()
        bus.drop=None
        for c in bus.clients:
            c.run("current:_fire('game_ended',{})")
            self.assertEqual(self.outcome_count(c,'pvp_win'),1)
            self.assertFalse(c.value('D.average_pvp.active()'))

    def test_recovery_ignores_checkpoint_from_other_run_or_authority(self):
        bus=self.start_average_match();self.wire_open(bus,2)
        bus.drop=lambda _,p:p.get('action')=='pvp_end_pvp'
        for i in range(1,5):self.wire(bus,i,'playHand',score='100',handsLeft=0)
        bus.drop=None;guest=bus.clients[1]
        for field,value in [('run',"'old-run'"),('owner',"'p4'"),('authority','999')]:
            guest.run(f"saved=current._metadata._pvp_ref.draftout.{field};current._metadata._pvp_ref.draftout.{field}={value};clock=clock+4;Game:update(0.02)")
            self.assertEqual(self.outcome_count(guest,'pvp_end_pvp'),0)
            guest.run(f'current._metadata._pvp_ref.draftout.{field}=saved')
        guest.run('clock=clock+4;Game:update(0.02)')
        self.assertEqual(self.outcome_count(guest,'pvp_end_pvp'),1)

    def test_twelve_consecutive_pvps_reach_one_winner_and_recap(self):
        bus=Bus(checkpoints=True);bus.draft();host=bus.clients[0]
        host.run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
        pools=[c.value('run_pool.keys') for c in bus.clients]
        lives=[4,4,4,4]
        for offset,loser in enumerate([4]*4+[3]*4+[2]*4):
            ante=offset+2;ids=self.wire_open(bus,ante)
            for hands in (3,2,1,0):
                for i in reversed(ids):
                    score=0 if i==loser else (4-hands)*25
                    self.wire(bus,i,'playHand',score=str(score),handsLeft=hands)
            lives[loser-1]-=1
            for c in bus.clients:
                self.assertEqual([c.value(f'client_lives.p{i}') for i in range(1,5)],lives)
                self.assertEqual(c.value('run_pool.keys'),pools[c.index-1])
                self.assertEqual(c.value('D.average_pvp.view.ante'),ante)
                self.assertTrue(c.value('D.average_pvp.view.final'))
            self.assertEqual(host.value('D.average_pvp.view.count'),len(ids))
            self.assertEqual(self.outcome_count(host,'pvp_start_blind'),offset+1)
            self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),min(offset+1,11))
        self.assertEqual(lives,[4,0,0,0])
        self.assertEqual(self.outcome_count(host,'pvp_win'),1)
        self.assertTrue(host.value("outcomes[#outcomes].data.winner_id=='p1'"))
        self.assertTrue(host.value('D.average_pvp.rounds.finished'))
        self.finish_match(bus)
        self.assertTrue(all(c.value('D.recap.available()') for c in bus.clients))
        self.assertTrue(all(not c.value('D.average_pvp.active()') for c in bus.clients))

    def test_fifty_tied_pvps_preserve_lives_and_allow_a_later_finish(self):
        bus=self.start_average_match();host=bus.clients[0]
        for ante in range(2,52):
            ids=self.wire_open(bus,ante)
            for i in ids:self.wire(bus,i,'playHand',score='1e300',handsLeft=0)
            self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in ids],[4]*4)
            self.assertEqual(host.value('D.average_pvp.ui.average'),'1e300')
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),50)
        self.assertEqual(self.outcome_count(host,'pvp_win'),0)
        for i in (4,3,2):
            host.run(f"PVP.referee_n_player_forfeit('p{i}')");bus.flush()
        self.assertEqual(self.outcome_count(host,'pvp_win'),1)

    def test_randomized_complete_matches_match_exact_life_model(self):
        for seed in range(5):
            with self.subTest(seed=seed):
                rng=random.Random(seed);bus=self.start_average_match();host=bus.clients[0]
                expected=[4]*4;ante=1
                while sum(v>0 for v in expected)>1:
                    ante+=1;self.assertLess(ante,40)
                    ids=self.wire_open(bus,ante)
                    scores={i:rng.randrange(0,1000000) for i in ids}
                    total=sum(scores.values());losers=[i for i in ids if scores[i]*len(ids)<total]
                    order=ids[:];rng.shuffle(order)
                    for i in order:self.wire(bus,i,'playHand',score=str(scores[i]),handsLeft=0)
                    for i in losers:expected[i-1]-=1
                    for c in bus.clients:self.assertEqual([c.value(f'client_lives.p{i}') for i in range(1,5)],expected)
                winner=expected.index(next(v for v in expected if v>0))+1
                self.assertEqual(self.outcome_count(host,'pvp_win'),1)
                self.assertEqual(host.value('outcomes[#outcomes].data.winner_id'),f'p{winner}')

    def test_closed_round_late_reports_cannot_cost_an_extra_life_or_reopen(self):
        bus=self.start_average_match();host=bus.clients[0]
        self.wire_open(bus,2)
        for i,score in enumerate((400,300,200,100),1):self.wire(bus,i,'playHand',score=str(score),handsLeft=0)
        before=[host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)]
        for i in range(1,5):
            self.wire(bus,i,'newRound');self.wire(bus,i,'readyBlind',startingHands=4)
            self.wire(bus,i,'playHand',score='100',handsLeft=0)
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],before)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),1)
        self.assertEqual(self.outcome_count(host,'pvp_start_blind'),1)
        # A previously captured score cannot enter the next ante, even with a new CID.
        client=bus.clients[3]
        client.run("Client.send({action='playHand',score='999999',handsLeft=0})")
        sender,old_packet=bus.queue.pop(0)
        self.wire_open(bus,3)
        old_packet['cid']='delayed-score';old_packet['from']=sender
        for c in bus.clients:c.receive(copy.deepcopy(old_packet))
        self.assertEqual(host.value('PVP.REF.players.p4.hands_left'),4)
        self.assertEqual(host.value('PVP.INSANE_INT.to_string(PVP.REF.players.p4.score)'),'0')
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),1)

    def test_two_remaining_players_use_native_one_v_one_early_finish(self):
        bus=self.start_average_match();host=bus.clients[0]
        for i in (3,4):host.run(f"PVP.referee_n_player_forfeit('p{i}')")
        for c in bus.clients:c.run('current._players.p3=nil;current._players.p4=nil')
        self.wire_open(bus,2)
        self.wire(bus,1,'playHand',score='100',handsLeft=0)
        self.wire(bus,2,'playHand',score='200',handsLeft=3)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),1,'Native 1v1 ends once the exhausted player is behind')
        self.assertTrue(all(c.value('D.average_pvp.duel') for c in bus.clients[:2]))
        self.assertTrue(all(c.value('D.average_pvp.view.mode')=='duel' for c in bus.clients[:2]))
        self.assertEqual(host.value('PVP.REF.players.p2.hands_left'),3)
        self.wire(bus,2,'playHand',score='300',handsLeft=0)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),1,'Late winning score cannot resolve again')
        self.assertEqual(host.value('PVP.REF.players.p1.lives'),3)

    def test_departure_rechecks_survivors_already_waiting_at_ready_barrier(self):
        bus=self.start_average_match();host=bus.clients[0]
        for i,c in enumerate(bus.clients[:3],1):
            c.run('G.GAME.round_resets={ante=2};G.GAME.round=6;test_pvp=false')
            self.wire(bus,i,'setAnte',ante=2);self.wire(bus,i,'readyBlind',startingHands=4)
        self.assertFalse(host.value('D.average_pvp.rounds.open'))
        for c in bus.clients[:3]:
            c.run("MPAPI._internal.lobby.apply_event(current,{type='player_left',playerId='p4'})")
        bus.offline.add(4);bus.flush()
        self.assertTrue(host.value('D.average_pvp.rounds.open'))
        self.assertEqual(self.outcome_count(host,'pvp_start_blind'),1)
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],[4,4,4,0])

    def test_ready_and_start_retries_after_eliminated_player_leaves(self):
        for lost_action in ('pvp_ready_blind','pvp_start_blind'):
            with self.subTest(lost_action=lost_action):
                bus=self.start_average_match();host=bus.clients[0]
                for ante in range(2,6):
                    self.wire_open(bus,ante)
                    for i in range(1,5):self.wire(bus,i,'playHand',score='100' if i<3 else '0',handsLeft=0)
                for c in bus.clients:
                    c.run("MPAPI._internal.lobby.apply_event(current,{type='player_left',playerId='p4'})")
                bus.offline.add(4);bus.flush()
                dropped=[False]
                def drop(sender,packet):
                    if packet.get('action')==lost_action and not dropped[0]:
                        dropped[0]=True;return True
                    return False
                bus.drop=drop
                for i,c in enumerate(bus.clients[:2],1):
                    c.run("G.GAME.round_resets={ante=6};G.GAME.round=18;test_pvp=false;PVP.GAME.ready_blind=true")
                    self.wire(bus,i,'setAnte',ante=6);self.wire(bus,i,'readyBlind',startingHands=4)
                before=self.outcome_count(host,'pvp_start_blind')
                for c in bus.clients[:2]:c.run('clock=clock+3;Game:update(0.02)')
                bus.flush()
                self.assertTrue(dropped[0])
                self.assertTrue(host.value('D.average_pvp.rounds.open'))
                self.assertEqual(self.outcome_count(host,'pvp_start_blind'),5)
                for c in bus.clients[:2]:
                    self.assertIsNone(c.value('D.average_pvp.rounds.pending_ready'))
                    c.run('test_pvp=true;clock=clock+3;Game:update(0.02)')
                bus.flush()
                self.assertEqual(self.outcome_count(host,'pvp_start_blind'),5)
                self.wire(bus,1,'playHand',score='100',handsLeft=0)
                self.wire(bus,2,'playHand',score='200',handsLeft=3)
                self.assertEqual(host.value('PVP.REF.players.p1.lives'),3)
                self.assertEqual(host.value('PVP.REF.players.p2.lives'),4)

    def test_eliminated_departures_preserve_next_ready_barrier(self):
        for departed in ((3,), (3,4), (1,3)):
            with self.subTest(departed=departed):
                bus=Bus(checkpoints=True,native_outcomes=True);bus.draft()
                bus.clients[0].run('PVP.pvp_start_match();Game:update(0.02)');bus.flush()
                losers=(1,3) if 1 in departed else (3,4)
                for ante in range(2,6):
                    self.wire_open(bus,ante)
                    for i in range(1,5):self.wire(bus,i,'playHand',score='0' if i in losers else '100',handsLeft=0)
                for i in departed:
                    if i==1:bus.handover(1,2)
                    else:
                        bus.offline.add(i)
                        for c in bus.clients:
                            if c.index not in bus.offline:c.run(f"MPAPI._internal.lobby.apply_event(current,{{type='player_left',playerId='p{i}'}})")
                        bus.flush()
                self.wire_open(bus,6)
                host=bus.clients[bus.host_index]
                self.assertTrue(host.value('D.average_pvp.rounds.open'))
                self.assertTrue(host.value('D.average_pvp.duel'))

    def test_eliminations_enter_native_duel_with_four_players_still_in_lobby(self):
        bus=self.start_average_match();host=bus.clients[0]
        for ante in range(2,6):
            self.wire_open(bus,ante)
            for i in (1,2,3,4):self.wire(bus,i,'playHand',score='100' if i<3 else '0',handsLeft=0)
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],[4,4,0,0])
        self.assertEqual(host.value('#current:get_players()'),4)
        self.wire_open(bus,6)
        self.assertTrue(host.value('PVP.referee_resolve_2p_round==native_two_player_resolver'),'The upstream 1v1 comparison function is untouched')
        self.assertTrue(all(c.value('D.average_pvp.duel') for c in bus.clients))
        before=self.outcome_count(host,'pvp_end_pvp')
        self.wire(bus,1,'playHand',score='100',handsLeft=0)
        self.wire(bus,2,'playHand',score='101',handsLeft=3)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),before+1)
        self.assertEqual(host.value('PVP.REF.players.p1.lives'),3)
        guest=bus.clients[1]
        guest.run("test_pvp=true;test_layer=true;PVP.LOBBY.config.timer=true;PVP.GAME.timer=30;hud={config={}}")
        self.assertEqual(guest.run('return G.FUNCS.multiplayer_blind_chip_UI_scale(hud)'),'native HUD')
        self.assertTrue(guest.value("hud.config.ref_table==PVP.GAME.enemy and hud.config.ref_value=='score_text'"))
        self.assertEqual(guest.value('PVP.UI.cam_timer_opponent()'),'native timer')
        self.wire_open(bus,7)
        self.wire(bus,1,'playHand',score='100',handsLeft=0)
        self.wire(bus,2,'playHand',score='100',handsLeft=3)
        self.assertTrue(host.value('D.average_pvp.rounds.open'),'Native tied scores wait while one player still has hands')
        self.wire(bus,2,'playHand',score='100',handsLeft=0)
        self.assertEqual(host.value('PVP.REF.players.p1.lives'),3)
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),4)

    def test_delayed_start_cannot_reopen_a_round_after_its_end(self):
        bus=self.start_average_match();host=bus.clients[0]
        bus.drop=lambda _,packet:packet.get('action')=='pvp_start_blind'
        self.wire_open(bus,2)
        delayed=copy.deepcopy(bus.dropped[0])
        bus.drop=None
        for i,score in enumerate((400,300,200,100),1):self.wire(bus,i,'playHand',score=str(score),handsLeft=0)
        delayed.update(cid='delayed-start',**{'from':'p1'})
        for c in bus.clients:
            c.receive(copy.deepcopy(delayed))
            self.assertEqual(self.outcome_count(c,'pvp_start_blind'),0)
            self.assertEqual(self.outcome_count(c,'pvp_end_pvp'),1)

    def test_native_start_keeps_duel_mode_if_custom_status_is_delayed(self):
        bus=self.start_average_match();host=bus.clients[0]
        for i in (3,4):host.run(f"PVP.referee_n_player_forfeit('p{i}')")
        bus.flush()
        bus.drop=lambda _,packet:packet.get('params',{}).get('packet',{}).get('kind')=='combat_duel'
        self.wire_open(bus,2)
        self.assertTrue(bus.clients[1].value('D.average_pvp.duel'))
        self.assertEqual(bus.clients[1].value('D.average_pvp.view.mode'),'duel')
        self.assertTrue(host.value('PVP.referee_resolve_2p_round==native_two_player_resolver'))

    def test_prior_run_reports_and_outcomes_are_rejected_after_reseed(self):
        bus=self.start_average_match();host=bus.clients[0]
        self.wire_open(bus,2)
        source=bus.clients[2]
        source.run("Client.send({action='playHand',score='999999',handsLeft=0})")
        sender,old_report=bus.queue.pop(0)
        host.run("current:action(MPAPI.ActionTypes.pvp_player_lives):broadcast({player_id='p1',lives=0})")
        _,old_life=bus.queue.pop(0)
        for c in bus.clients:
            c.run("PVP.on_game_start({run_id='run-1',seed='FRESHSEED',restarted=true})")
        bus.flush()
        old_report.update(cid='old-run-report',**{'from':sender})
        old_life.update(cid='old-run-life',**{'from':'p1'})
        for c in bus.clients:
            c.receive(copy.deepcopy(old_report));c.receive(copy.deepcopy(old_life))
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],[4]*4)
        self.assertTrue(all(c.value('client_lives.p1')==4 for c in bus.clients))
        self.assertFalse(host.value('D.average_pvp.rounds.open'))

    def test_native_startup_zero_ante_cannot_suppress_ante_one_boss_loss(self):
        bus=self.start_average_match();host=bus.clients[0]
        # Native action_start_game sends setAnte(0) before the real run starts.
        # Do not artificially repair referee ante fields before testing failures.
        for i,c in enumerate(bus.clients,1):
            c.run("G.GAME.round_resets={ante=1};G.GAME.round=0;test_pvp=false")
            self.wire(bus,i,'setAnte',ante=0)
        client=bus.clients[1]
        client.run("G.GAME.round=3;G.GAME.blind_on_deck='Boss'")
        self.wire(bus,2,'newRound')
        # Exercise the actual PvP failed-score hook, not just its report handler.
        native_state=(PVP/'ui/game/game_state.lua').read_text()
        native_fail=(PVP/'networking/action_handlers.lua').read_text()
        client.run('''
            Game.update_new_round=function() G.STATE_COMPLETE=true end
            PVP.is_mp_or_practice=function() return true end
            PVP.is_practice_mode=function() return false end
            to_big=tonumber;PVP.ACTIONS={}
            G.GAME.blind={chips=600};G.GAME.chips=100
            G.GAME.current_round={hands_played=4};G.STATE_COMPLETE=false
        ''')
        blind_report=re.search(r'function PVP\.ACTIONS\.blind_result\(beaten[^)]*\).*?\nend',native_fail,re.S)
        if blind_report: client.run(blind_report.group())
        client.run(re.search(r'function PVP\.ACTIONS\.fail_round\(hands_used\).*?\nend',native_fail,re.S).group())
        client.run('local update_new_round_ref=Game.update_new_round\n'+re.search(r'function Game:update_new_round\(dt\).*?\nend',native_state,re.S).group())
        client.run('Game:update_new_round(0.02)');bus.flush()
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),3)
        self.wire(bus,2,'newRound');self.wire(bus,2,'failRound')
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),3,'Same failed boss still costs only one life')
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),0)
        self.assertTrue(all(c.value('client_lives.p2')==3 for c in bus.clients))
        self.wire_open(bus,2)
        for i in range(1,5):self.wire(bus,i,'playHand',score='100',handsLeft=0)
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),3)
        client.run("G.GAME.round=7;G.GAME.blind_on_deck='Small';G.GAME.round_resets.ante=3;test_pvp=false")
        self.wire(bus,2,'setAnte',ante=3);self.wire(bus,2,'newRound');self.wire(bus,2,'failRound')
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),2)

    def test_regular_blind_failures_do_not_resolve_a_pvp(self):
        bus=self.start_average_match();host=bus.clients[0];client=bus.clients[1]
        client.run("G.GAME.round_resets={ante=1};G.GAME.round=1;G.GAME.blind_on_deck='Small';test_pvp=false")
        self.wire(bus,2,'setAnte',ante=1);self.wire(bus,2,'newRound')
        self.wire(bus,2,'playHand',score='0',handsLeft=4)
        self.wire(bus,2,'failRound');self.wire(bus,2,'newRound');self.wire(bus,2,'failRound')
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),3)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),0)
        client.run("G.GAME.round=2;G.GAME.blind_on_deck='Big'")
        self.wire(bus,2,'newRound');self.wire(bus,2,'failRound')
        self.assertEqual(host.value('PVP.REF.players.p2.lives'),2)
        self.assertEqual(self.outcome_count(host,'pvp_end_pvp'),0)
        self.wire_open(bus,2)
        self.assertEqual(host.value('D.average_pvp.ui.average'),'0')

    def test_average_one_two_three_losers_and_ties(self):
        for scores,expected in [([400,400,400,100],[4,4,4,3]),
                                ([400,300,200,100],[4,4,3,3]),
                                ([1000,100,100,100],[4,3,3,3]),
                                ([100,100,100,100],[4,4,4,4]),
                                ([0,100,100,200],[3,4,4,4])]:
            with self.subTest(scores=scores):
                bus=self.start_average_match()
                self.play_average_round(bus,dict(enumerate(scores,1)))
                self.assertEqual([bus.clients[0].value(f"PVP.REF.players.p{i}.lives") for i in range(1,5)],expected)
                for c in bus.clients:
                    self.assertEqual([c.value(f"client_lives.p{i}") for i in range(1,5)],expected)
                    self.assertTrue(c.value('D.average_pvp.view.final'))

    def test_average_waits_for_every_player_and_deducts_once(self):
        bus=self.start_average_match(); host=bus.clients[0]
        self.open_average_round(bus)
        for i,score in enumerate([1000,100,100],1):
            host.run(f"PVP.referee_on_play_hand('p{i}',{{score='{score}',handsLeft=0}})"); bus.flush()
        self.assertEqual([host.value(f"PVP.REF.players.p{i}.lives") for i in range(1,5)],[4]*4)
        self.assertFalse(host.value('D.average_pvp.view.final'))
        host.run("PVP.referee_on_play_hand('p4',{score='100',handsLeft=0})"); bus.flush()
        self.assertEqual(host.value('D.average_pvp.ui.average'),'325')
        for _ in range(3): host.run("PVP.referee_on_play_hand('p4',{score='100',handsLeft=0})")
        bus.flush()
        self.assertEqual([host.value(f"PVP.REF.players.p{i}.lives") for i in range(1,5)],[4,3,3,3])

    def test_average_elimination_three_and_two_survivors(self):
        bus=self.start_average_match(); host=bus.clients[0]
        host.run('PVP.REF.players.p4.lives=1')
        self.play_average_round(bus,{1:400,2:400,3:400,4:100})
        self.assertEqual(host.value('PVP.REF.players.p4.lives'),0)
        self.assertTrue(all(c.value('client_eliminated.p4') for c in bus.clients))
        self.play_average_round(bus,{1:900,2:100,3:100})
        self.assertEqual(host.value('D.average_pvp.view.count'),3)
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)],[4,3,3,0])
        host.run('PVP.REF.players.p3.lives=1')
        self.play_average_round(bus,{1:400,2:400,3:100})
        self.play_average_round(bus,{1:100,2:100})
        self.assertEqual(host.value('D.average_pvp.view.count'),2)
        self.assertEqual([host.value('PVP.REF.players.p1.lives'),host.value('PVP.REF.players.p2.lives')],[4,3])
        host.run('PVP.REF.players.p2.lives=1')
        self.play_average_round(bus,{1:101,2:100})
        self.assertTrue(host.value("outcomes[#outcomes].key=='pvp_win' and outcomes[#outcomes].data.winner_id=='p1'"))

    def test_average_scope_schedule_and_older_client_rejection(self):
        bus=self.start_average_match(); host=bus.clients[0]
        self.assertEqual(host.value('current:get_metadata().starting_lives'),4)
        self.assertEqual(host.value('current:get_metadata().pvp_start_round'),2)
        for c in bus.clients:
            self.assertTrue(c.value('D.average_pvp.active()'))
            self.assertIsNone(c.run('local _,_,boss=PVP.Gamemodes.gamemode_mp_attrition:get_blinds_by_ante(1); return boss'))
            self.assertEqual(c.run('local _,_,boss=PVP.Gamemodes.gamemode_mp_attrition:get_blinds_by_ante(2); return boss'),'bl_mp_nemesis')
        host.run("new_lobby('MultiplayerPvP','private','pvp_nemesis')")
        self.assertFalse(bool(host.value('D.average_pvp.active()')))
        self.assertEqual(host.run('return PVP.Gamemodes.gamemode_mp_attrition:get_blinds_by_ante(2)'),'native')
        bus=Bus(); bus.begin(); guest=bus.clients[1]
        guest.run("B.receive('p1',{protocol=4,kind='offer',room='ROOM',session='older',recipient='p2',data={ids={'p1','p2','p3','p4'},catalog=table.concat(keys,'|'),rules=7}})")
        self.assertEqual(guest.value('B.phase'),'error')

    def test_average_hud_and_native_raw_score_cannot_replace_mean(self):
        bus=self.start_average_match(); host=bus.clients[0]
        self.play_average_round(bus,{1:1000,2:100,3:100,4:100})
        guest=bus.clients[1]
        guest.run('test_pvp=true; test_layer=true; PVP.LOBBY.config.timer=true; PVP.GAME.timer=30')
        guest.run('hud={config={}}; G.FUNCS.multiplayer_blind_chip_UI_scale(hud)')
        self.assertTrue(guest.value("hud.config.ref_table==D.average_pvp.ui and hud.config.ref_value=='average'"))
        self.assertEqual(guest.value('D.average_pvp.ui.average'),'325')
        guest.run('''score_label={config={text='k_enemy_score'}}; hands_label={config={text='k_enemy_hands'}}
            title={config={object={config={},update_text=function() end}}}
            hud_root={children={score_label,hands_label}}
            G.HUD_blind={get_UIE_by_ID=function(_,id) return id=='HUD_blind' and hud_root or title end}
            PVP.UI.update_blind_HUD()
        ''')
        self.assertTrue(guest.value("score_label.config.ref_table==D.average_pvp.ui and score_label.config.ref_value=='label'"))
        self.assertEqual(guest.value('hands_label.config.text'),'Players done')
        self.assertTrue(guest.value("title.config.object.config.string[1].ref_value=='title'"))
        self.assertFalse(guest.value('PVP.UI.cam_timer_opponent()'))
        guest.run("PVP.GAME.timer_started=true; MPAPI.Blinds.bl_mp_nemesis:receive({from='p2',data={score='100',handsLeft=0,skips=0}})")
        self.assertEqual(guest.value("PVP.Score and tonumber(PVP.GAME.enemy.real_score) or PVP.GAME.enemy.real_score.coeffiocient"),100)
        self.assertEqual(guest.value('D.average_pvp.ui.average'),'325')
        self.assertFalse(guest.value('PVP.GAME.timer_started'))
        guest.run('PVP.LOBBY.config.hide_score_until_played=true; G.GAME.current_round.hands_played=0; G.FUNCS.multiplayer_blind_chip_UI_scale(hud)')
        self.assertEqual(guest.value('D.average_pvp.ui.average'),'???')
        guest.run('G.GAME.current_round.hands_played=1; G.FUNCS.multiplayer_blind_chip_UI_scale(hud)')
        self.assertEqual(guest.value('D.average_pvp.ui.average'),'325')
        guest.run("PVP.UI.reset_blind_HUD()")
        self.assertIsNone(guest.value('score_label.config.ref_table'))
        self.assertEqual(guest.value('score_label.config.text'),'ph_blind_score_at_least')
        guest.run('D.average_pvp.stop()')
        self.assertEqual(guest.run('return G.FUNCS.multiplayer_blind_chip_UI_scale(hud)'),'native HUD')
        self.assertEqual(guest.value('PVP.UI.cam_timer_opponent()'),'native timer')
        self.assertEqual(guest.run("return #PVP.referee_rank_royale({{id='1',score=PVP.INSANE_INT.from_string('0')},{id='2',score=PVP.INSANE_INT.from_string('100')},{id='3',score=PVP.INSANE_INT.from_string('100')},{id='4',score=PVP.INSANE_INT.from_string('200')}}).losers"),3)

    def test_average_display_resets_across_pvp_and_normal_blinds(self):
        bus=self.start_average_match(); guest=bus.clients[1]
        for scores,mean in [({1:1000,2:100,3:100,4:100},'325'),({1:400,2:400,3:400,4:400},'400')]:
            self.play_average_round(bus,scores)
            guest.run("test_pvp=true; hud={config={}}; G.FUNCS.multiplayer_blind_chip_UI_scale(hud)")
            self.assertEqual(guest.value('hud.config.ref_table.average'),mean)
            guest.run("test_pvp=false; G.GAME.blind={chip_text='5000'}; G.FUNCS.multiplayer_blind_chip_UI_scale(hud)")
            self.assertTrue(guest.value("hud.config.ref_table==G.GAME.blind and hud.config.ref_value=='chip_text'"))
            self.assertEqual(guest.value('hud.config.func'),'blind_chip_UI_scale')
            guest.run("PVP.dispatch_action('startBlind'); test_pvp=true; G.FUNCS.multiplayer_blind_chip_UI_scale(hud)")
            self.assertEqual(guest.value('hud.config.ref_table.average'),'0')
            self.assertIsNone(guest.value('D.average_pvp.view'))

    def test_native_ready_barrier_repeats_and_forfeit_never_adds_lives(self):
        bus=self.start_average_match(); host=bus.clients[0]
        for turn in range(3):
            for c in bus.clients:c.run(f'G.GAME.round_resets={{ante={turn+2}}};test_pvp=true')
            for i in range(1,5):host.run(f"PVP.referee_on_set_ante('p{i}',{{ante={turn+2}}});PVP.referee_on_new_round('p{i}')")
            before=host.value("#outcomes")
            for index in (2,4,1):
                host.run(f"PVP.referee_on_ready_blind('p{index}',4)")
            self.assertEqual(host.value("#outcomes"),before)
            host.run("PVP.referee_on_ready_blind('p3',4)"); bus.flush()
            self.assertEqual(host.value("(function() local n=0; for _,o in ipairs(outcomes) do if o.key=='pvp_start_blind' then n=n+1 end end; return n end)()"),turn+1)
            self.assertEqual(host.value('D.average_pvp.view.average'),'0')
            self.play_average_round(bus,{1:1000,2:100,3:100,4:100})
        old=[host.value(f'PVP.REF.players.p{i}.lives') for i in range(1,5)]
        host.run("PVP.referee_n_player_forfeit('p4')"); bus.flush()
        self.assertEqual(host.value('PVP.REF.players.p4.lives'),0)
        for i in range(1,4):
            self.assertLessEqual(host.value(f'PVP.REF.players.p{i}.lives'),old[i-1])

    def test_fresh_average_before_start_is_kept_and_wrong_ante_is_ignored(self):
        bus=self.start_average_match(); guest=bus.clients[1]
        guest.run("""G.GAME.round_resets={ante=3}
            fresh={protocol=4,kind='combat_average',run=D.average_pvp.run,session=B.session,room='ROOM',recipient='p2',
                data={revision=100,average='250',safe={p2=true},finished=0,count=4,final=false,ante=3}}
            D.average_pvp.receive('p1',fresh)
            PVP.dispatch_action('startBlind')
        """)
        self.assertEqual(guest.value('D.average_pvp.view.average'),'250')
        guest.run("fresh.data={revision=101,average='999',safe={},finished=4,count=4,final=true,ante=2}; D.average_pvp.receive('p1',fresh)")
        self.assertEqual(guest.value('D.average_pvp.view.average'),'250')
        self.assertEqual(guest.value('D.average_pvp.received'),100)

    def test_average_packet_rejects_guests_stale_and_wrong_matches(self):
        bus=self.start_average_match(); host=bus.clients[0]
        self.play_average_round(bus,{1:400,2:300,3:200,4:100})
        guest=bus.clients[1]
        guest.run("forged={protocol=4,kind='combat_average',run=D.average_pvp.run,session=B.session,room='ROOM',recipient='p2',data={revision=999,average='99999',safe={},finished=4,count=4,final=true}}")
        guest.run("D.average_pvp.receive('p3',forged)")
        self.assertEqual(guest.value('D.average_pvp.ui.average'),'250')
        guest.run("forged.session='wrong'; D.average_pvp.receive('p1',forged)")
        self.assertEqual(guest.value('D.average_pvp.ui.average'),'250')
        guest.run("forged.session=B.session; forged.data.revision=0; D.average_pvp.receive('p1',forged)")
        self.assertEqual(guest.value('D.average_pvp.ui.average'),'250')

    def test_full_draft_actual_api_and_server_start_handoff(self):
        bus=Bus()
        bus.draft()
        pools=[set(c.value('B.pool.keys')) for c in bus.clients]
        self.assertEqual(sorted(map(len,pools)),[27,27,27,27])
        self.assertEqual(len(set.union(*pools)),108)
        self.assertTrue(set.union(*pools).issubset(set(bus.clients[0].value('keys'))))
        self.assertTrue(all(c.value('B.launch_ready()') for c in bus.clients))
        self.assertTrue(all(view['data']['seat']==index for index,view in bus.views))
        self.assertTrue(all('packs' not in view['data'] for _,view in bus.views))
        host=bus.clients[0]
        self.assertEqual(host.value('original_starts'),0)
        host.run('PVP.pvp_start_match()')
        self.assertEqual(host.value('original_starts'),0,'Launch must wait for the next update tick')
        host.run('Game:update(0.02)')
        bus.flush()
        self.assertEqual(len(bus.starts),1)
        self.assertEqual(bus.starts[0]['params']['options']['queue_mode'],'pvp_royale')
        for c in bus.clients:
            self.assertEqual(c.value('game_starts'),1)
            self.assertEqual(c.value('run_seed'),'SERVERSEED')
            self.assertEqual(c.value('run_pool.source'),'mpapi_pvp')
            self.assertEqual(set(c.value('run_pool.keys')),set(c.value('B.pool.keys')))
            self.assertFalse(c.value('next(current._pending_actions)~=nil'),'Every request must be acknowledged')

    def test_delayed_send_error_cannot_change_replacement_lobby_or_session(self):
        bus=Bus();bus.begin();c=bus.clients[1]
        c.run("""
            B.transport.send({kind='refresh',session=B.session},'p1')
            for _,pending in pairs(current._pending_actions) do saved_callback=pending.callback end
            assert(saved_callback)
            new_lobby('MultiplayerPvP','private','pvp_royale')
            B.message='new lobby status'
            saved_callback(nil,nil,{message='late failure'})
            assert(B.message=='new lobby status')
        """)
        c.run("""
            B.session='fresh'
            B.transport.send({kind='refresh',session=B.session},'p1')
            for _,pending in pairs(current._pending_actions) do saved_callback=pending.callback end
            B.session='newer';B.message='new draft status'
            saved_callback(nil,nil,{message='late failure'})
            assert(B.message=='new draft status')
            B.session='fresh'
            saved_callback(nil,nil,{message='current failure'})
            assert(B.message:find('current failure'))
        """)

    def test_diagnostics_observe_actual_actions_without_changing_results(self):
        bus=self.start_average_match();host=bus.clients[0]
        for c in bus.clients:
            c.run("D.now=function()return clock end; assert(loadfile(root..'/burglar/diagnostics.lua'))()(D); D.diagnostics.set_enabled(true)")
        captured=[]
        bus.drop=lambda sender,packet: captured.append((sender,copy.deepcopy(packet))) or False
        ids=self.wire_open(bus,2)
        for i in ids:self.wire(bus,i,'playHand',score=str(i*100),handsLeft=0)
        log=host.run('return D.diagnostics.text()')
        self.assertIn('report_accept',log)
        self.assertIn('kind=pvp_ready_blind',log)
        self.assertIn('outcome_accept',log)
        self.assertIn('kind=pvp_player_lives',log)
        self.assertNotIn('ROOM',log)
        self.assertNotIn('SERVERSEED',log)
        self.assertNotIn('run-1',log)
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in ids],[3,3,4,4])
        # Replay a real action envelope through the actual MPAPI dispatcher.
        sender,report=next((sender,packet) for sender,packet in reversed(captured) if packet.get('action')=='pvp_play_hand')
        report['from']=sender
        host.receive(report)
        self.assertIn('reason=duplicate',host.run('return D.diagnostics.text()'))
        self.assertEqual([host.value(f'PVP.REF.players.p{i}.lives') for i in ids],[3,3,4,4])

    def test_action_ownership_and_other_lobby_isolation(self):
        c=Bus().clients[0]
        self.assertEqual(c.value('B.transport.action.mod.id'),'Draftout')
        self.assertTrue(c.value('current._action_types.draftout_pack_v4~=nil'))
        c.run("new_lobby('MultiplayerSPDRN','private','speedrun'); PVP.pvp_start_match()")
        self.assertTrue(c.value('current._action_types.draftout_pack_v4==nil'))
        self.assertIsNone(c.run('return B.prepare_run()'))
        self.assertEqual(c.value('original_starts'),1)
        self.assertIsNone(c.run("return MPAPI._internal.create_action_instance(current,B.transport.action):send('p2',{packet={}})"))
        self.assertEqual(c.value('#MPAPI._internal.foreign_actions_dropped'),1)
        c.run("new_lobby('MultiplayerPvP','public','pvp_royale'); PVP.pvp_start_match()")
        self.assertEqual(c.value('original_starts'),2)

    def test_forged_pair_replay_sender_and_revision(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run('B.start_draft()'); bus.flush()
        remote=bus.clients[1]
        remote.lua.globals().foreign=host.value('B.view.cards[1]')
        remote.run('B.pick({B.view.cards[1],foreign},B.view.token)'); bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),0)
        self.assertIn('pack',remote.value('B.message'))
        remote.run('old_token=D.core.copy(B.view.token); pair={B.view.cards[1],B.view.cards[2]}; B.pick(pair,old_token)')
        bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),1)
        remote.run('B.pick(pair,old_token)'); bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),1)
        # A guest cannot forge an owner view even if it supplies a playerId in params.
        fake={'cid':'forged','action':'draftout_pack_v4','from':'p3','to':'p2','params':{'packet':{
            'protocol':4,'kind':'view','room':'ROOM','session':remote.value('B.session'),'recipient':'p2',
            'data':{'revision':999,'seat':2,'cards':[],'drafted':[]}}}}
        remote.receive(fake)
        self.assertEqual(remote.value('B.view.revision'),1)

    def test_bad_broadcast_routing_fails_before_packs(self):
        bus=Bus(broadcast=True); bus.begin()
        self.assertEqual(bus.clients[0].value('B.phase'),'error')
        self.assertFalse(bus.views)

    def test_peer_disconnect_reconnect_and_host_change(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run('B.start_draft()'); bus.flush()
        for c in bus.clients:
            c.run("current._players.p3.is_away=true")
        self.assertFalse(host.value('B.launch_ready()'))
        for i,c in enumerate(bus.clients):
            if i!=2:
                c.run('B.pick({B.view.cards[1],B.view.cards[2]},B.view.token)'); bus.flush()
        self.assertEqual(host.value('B.host_state.pick'),1)
        for c in bus.clients:
            c.run("current._players.p3.is_away=false; current:_fire('player_reconnected','p3'); Game:update(0.02)")
        bus.flush()
        bus.clients[2].run('B.pick({B.view.cards[1],B.view.cards[2]},B.view.token)'); bus.flush()
        self.assertEqual(host.value('B.host_state.pick'),2)
        host.run("current.host_id='p2'; current.is_host=false; current:_fire('host_changed','p2')")
        self.assertEqual(host.value('B.phase'),'error')

    def test_catalog_mismatch_and_incomplete_start_are_blocked(self):
        bus=Bus(); bus.clients[2].run('table.remove(keys)')
        bus.begin()
        self.assertEqual(bus.clients[2].value('B.phase'),'error')
        result=bus.clients[0].run('return pcall(B.start_draft)')
        self.assertFalse(result[0] if isinstance(result,tuple) else result)
        c=Bus().clients[1]
        c.run("PVP.on_game_start({seed='EARLY'})")
        self.assertEqual(c.value('game_starts'),0)
        self.assertEqual(c.value('B.phase'),'error')

    def test_next_match_gets_a_fresh_draft(self):
        bus=Bus(); bus.draft(); host=bus.clients[0]
        seed=host.value('B.host_state.seed')
        host.run('PVP.pvp_start_match(); Game:update(0.02)'); bus.flush()
        for c in bus.clients:
            c.run("MPAPI._internal.lobby.apply_game_ended(current,{runId='run-1',status='agreed'})")
        host.run('PVP.pvp_start_match()'); bus.flush()
        for c in bus.clients:
            c.run('clock=16')
        host.run('B.start_draft()'); bus.flush()
        self.assertNotEqual(seed,host.value('B.host_state.seed'))
        self.assertTrue(all(len(c.value('B.view.cards'))==9 for c in bus.clients))
        self.assertTrue(all(not c.value('B.pool') for c in bus.clients))

    def test_delayed_duplicate_offer_does_not_reset_draft(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        packet={'protocol':4,'kind':'offer','room':'ROOM','session':host.value('B.session'),'recipient':'p2',
                'data':{'ids':['p1','p2','p3','p4'],'owner':'p1','catalog':'|'.join(host.value('keys')),'keys':host.value('keys'),'cube_name':'Default','rules':22}}
        host.run('B.start_draft()'); bus.flush()
        remote=bus.clients[1]
        remote.receive({'cid':'delayed','action':'draftout_pack_v4','from':'p1','to':'p2','params':{'packet':packet}})
        self.assertEqual(remote.value('B.phase'),'draft')
        self.assertEqual(len(remote.value('B.view.cards')),9)

    def test_timed_wave_keeps_intents_private_and_fills_missing_choices(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run('D.mod.config.pick_seconds=30; B.start_draft()'); bus.flush()
        guest=bus.clients[1]
        chosen=guest.value('B.view.cards[4]')
        guest.run('late_token=D.core.copy(B.view.token); keep=B.view.cards[4]; B.intent({keep},B.view.token,1)')
        other=bus.clients[2]
        pair=other.value('B.view.cards')[:2]
        other.run('B.intent({B.view.cards[1],B.view.cards[2]},B.view.token,2)')
        other.run('B.intent({B.view.cards[3]},B.view.token,1)')
        bus.flush()
        host.run('B.pick({B.view.cards[1],B.view.cards[2]},B.view.token)'); bus.flush()
        self.assertTrue(guest.value('B.view.roster[1].ready'))
        self.assertEqual(host.value('B.host_state.revision'),1)
        host.run('clock=44; Game:update(0.02)'); bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),4)
        self.assertIn(chosen,host.value('B.host_state.pools[2]'))
        self.assertEqual(set(pair),set(host.value('B.host_state.pools[3]')))
        self.assertEqual(host.value('B.host_state.pick'),2)
        self.assertEqual(guest.value('B.view.timer_left'),30)
        for _,view in bus.views:
            self.assertNotIn('intents',view['data'])
            for row in view['data']['roster']:
                self.assertEqual(set(row),{'id','name','connected','ready'})
        guest.run('B.pick({keep,B.view.cards[1]},late_token)'); bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),4,'Late picks cannot change a timed-out turn')
        host.run('Game:update(0.02)'); bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),4,'One expiration cannot consume the next turn')

    def test_timer_pauses_for_an_away_peer(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run('D.mod.config.pick_seconds=30; B.start_draft()'); bus.flush()
        for c in bus.clients:
            c.run("current._players.p3.is_away=true; clock=23")
        host.run('Game:update(0.02)'); bus.flush()
        self.assertEqual(host.value('B.clock.remaining'),20)
        self.assertTrue(bus.clients[1].value('B.view.timer_paused'))
        host.run('clock=500; Game:update(0.02)'); bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),0)
        for c in bus.clients:
            c.run("clock=500; current._players.p3.is_away=false")
        host.run('Game:update(0.02)'); bus.flush()
        self.assertEqual(host.value('B.clock.deadline'),520)
        host.run('clock=519; Game:update(0.02)'); bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),0)
        host.run('clock=521; Game:update(0.02)'); bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),4)

    def test_all_timeouts_still_draft_every_joker_once(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run('D.mod.config.pick_seconds=5; B.start_draft()'); bus.flush()
        guard=0
        while not host.value('B.host_state.done'):
            guard+=1; self.assertLess(guard,25)
            host.run('clock=clock+6; Game:update(0.02)'); bus.flush()
        pools=[set(c.value('B.pool.keys')) for c in bus.clients]
        self.assertEqual(sorted(map(len,pools)),[27,27,27,27])
        self.assertEqual(len(set.union(*pools)),108)
        self.assertEqual(host.value('B.host_state.revision'),60)
        self.assertTrue(host.value('B.launch_ready()'))

    def test_clean_draft_ui_preserves_choices_timer_and_host_only_utilities(self):
        bus=Bus();bus.begin();host,guest=bus.clients[:2]
        host.run('D.mod.config.pick_seconds=30;B.start_draft()');bus.flush()
        for c in (host,guest):
            c.run("""
                D.mode='mp';D.now=function() return clock end;D.mod.config.pack_effects=false
                G.UIT.O=4;G.ROOM={T={x=0,y=0}};G.CARD_W=1.4;G.CARD_H=1.9
                G.C.WHITE={};G.C.BLACK={};G.C.BLUE={};G.C.GREEN={};G.C.RED={}
                G.C.UI.BACKGROUND_INACTIVE={}
                D.ui.line=function(text,scale) return {n=G.UIT.R,config={},nodes={{n=G.UIT.T,config={text=text,scale=scale}}}} end
                D.ui.row=function(nodes) return {n=G.UIT.R,config={},nodes=nodes} end
                D.ui.button=function(label,action,data,width)
                    return {n=G.UIT.C,config={button=action,ref_table=data,minw=width},nodes={{n=G.UIT.T,config={text=label}}}}
                end
                for _,key in ipairs(keys) do G.P_CENTERS[key]={key=key,rarity=1,set='Joker'} end
                CardArea=function(x,y,w,h,config)
                    return {T={x=x,y=y,w=w,h=h},config=config,cards={},emplace=function(self,card)
                        self.cards[#self.cards+1]=card;card.area=self
                    end}
                end
                Card=function(x,y,w,h,_,center)
                    return {T={x=x,y=y,w=w,h=h},config={center=center},states={drag={},hover={}},juice_up=function() end}
                end
                assert(loadfile(root..'/burglar/draft_views.lua'))()(D)
                assert(loadfile(root..'/burglar/pack_ui.lua'))()(D)
                function has_action(node,key)
                    if node.config and node.config.button==key then return true end
                    for _,child in ipairs(node.nodes or {}) do if has_action(child,key) then return true end end
                    return false
                end
                function pack_cards(node,out)
                    out=out or {}
                    if node.n==G.UIT.O then for _,card in ipairs(node.config.object.cards) do
                        if not card.draftout_tray then out[#out+1]=card end
                    end end
                    for _,child in ipairs(node.nodes or {}) do pack_cards(child,out) end
                    return out
                end
                screen=D.multiplayer_screen();cards=pack_cards(screen)
                cards[1]:click();cards[2]:click()
                selected=table.concat(D.pack_ui.choices(),',')
                deadline=B.view.timer_left
                G.FUNCS.draftout_more()
                screen=D.multiplayer_screen();utilities=D.views.utilities()
                assert(#pack_cards(screen)==9)
                assert(table.concat(D.pack_ui.choices(),',')==selected)
                assert(not has_action(screen,'draftout_mp_refresh'))
                assert(not has_action(screen,'draftout_mp_check'))
                assert(has_action(utilities,'draftout_mp_refresh'))
                assert(has_action(utilities,'draftout_mp_check')==current.is_host)
                footer=D.pack_ui.footer()
                assert(has_action(footer,'draftout_pack_confirm') and has_action(footer,'draftout_close'))
                G.FUNCS.draftout_mp_refresh()
            """)
        deadline=host.value('B.clock.deadline');bus.flush()
        for c in (host,guest):
            c.run("screen=D.multiplayer_screen();assert(table.concat(D.pack_ui.choices(),',')==selected)")
        self.assertEqual(host.value('B.clock.deadline'),deadline)
        guest.run('G.FUNCS.draftout_pack_confirm();G.FUNCS.draftout_pack_confirm()');bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),1)
        guest.run("screen=D.multiplayer_screen();Game:update(0.02)")
        self.assertTrue(guest.value('B.view.picked'))
        self.assertIsNone(guest.value('D.pack_ui.active'))
        self.assertIn('30s',guest.value('D.pack_ui.ui.timer'),'Waiting header retains the countdown')
        self.assertEqual(len(guest.value('B.view.drafted')),2)
        self.assertEqual(host.value('B.clock.deadline'),deadline)
        self.assertEqual(host.value("table.concat(D.pack_ui.choices(),',')"),host.value('selected'))

    def test_readiness_updates_without_rebuilding_a_hovered_pack(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run('B.start_draft()'); bus.flush()
        guest=bus.clients[1]
        guest.run("D.views={update=function(rows) status_rows=rows end}; D.mode='mp'; G.OVERLAY_MENU={}; D.overlay=G.OVERLAY_MENU; Game:update(0.02)")
        shown=guest.value('ui_shows')
        host.run('B.pick({B.view.cards[1],B.view.cards[2]},B.view.token)'); bus.flush()
        guest.run('Game:update(0.02)')
        self.assertTrue(guest.value('status_rows[1].ready'))
        self.assertEqual(guest.value('ui_shows'),shown)

    def test_scaling_timer_four_packs_and_both_pick_modes(self):
        for picks in (1,2):
            with self.subTest(picks=picks):
                bus=Bus();bus.begin();host=bus.clients[0]
                host.run(f"D.mod.config.pick_seconds='scaling'; D.mod.config.picks_per_turn={picks}; D.mod.config.packs_per_player=4; B.start_draft()")
                bus.flush();waves=[]
                while not host.value('B.host_state.done'):
                    round_=host.value('B.host_state.round')
                    cards=len(host.value('B.host_state.current[1].cards'))
                    waves.append((round_,cards))
                    seconds=5*cards
                    self.assertTrue(all(c.value('B.view.timer_mode')=='scaling' for c in bus.clients))
                    self.assertTrue(all(c.value('B.view.timer_seconds')==seconds for c in bus.clients))
                    self.assertEqual(host.value('B.clock.seconds'),seconds)
                    host.run('clock=B.clock.deadline+0.01; Game:update(0.02)');bus.flush()
                self.assertIn((4,8),waves)
                self.assertIn((1,1),waves)
                self.assertTrue(all(len(c.value('B.pool.keys'))==35 for c in bus.clients))
                self.assertTrue(all(c.value('B.launch_ready()') for c in bus.clients))

    def test_scaling_refresh_confirm_pause_and_config_change_preserve_deadline(self):
        bus=Bus();bus.begin();host=bus.clients[0];guest=bus.clients[1]
        host.run("D.mod.config.pick_seconds='scaling'; D.mod.config.picks_per_turn=1; B.start_draft()");bus.flush()
        self.assertEqual(host.value('B.clock.deadline'),58)
        for c in bus.clients:c.run('clock=20')
        host.run("D.mod.config.pick_seconds=90; B.pick({B.view.cards[1]},B.view.token)");bus.flush()
        self.assertEqual(host.value('B.clock.deadline'),58)
        self.assertEqual(host.value('B.clock.seconds'),45)
        guest.run("B.transport.send({protocol=4,kind='refresh',session=B.session,room='ROOM',recipient='p1',data={}},'p1')");bus.flush()
        self.assertEqual(guest.value('B.view.timer_left'),38)
        for c in bus.clients[1:]:
            c.run('B.pick({B.view.cards[1]},B.view.token)');bus.flush()
        self.assertEqual(host.value('B.clock.seconds'),40)
        self.assertEqual(host.value('B.clock.deadline'),60)
        for c in bus.clients:c.run("clock=22; current._players.p3.is_away=true")
        host.run('Game:update(0.02)');bus.flush()
        self.assertEqual(guest.value('B.view.timer_left'),38)
        for c in bus.clients:c.run("clock=100; current._players.p3.is_away=false")
        host.run('Game:update(0.02)');bus.flush()
        self.assertEqual(host.value('B.clock.deadline'),138)
        self.assertEqual(host.value('B.clock.setting'),'scaling')

    def test_timer_defaults_off_and_only_changes_for_next_draft(self):
        bus=Bus(); bus.begin(); host=bus.clients[0]
        host.run('B.start_draft()'); bus.flush()
        host.run('D.mod.config.pick_seconds=30; clock=999; Game:update(0.02)'); bus.flush()
        self.assertEqual(host.value('B.host_state.revision'),0)
        self.assertEqual(host.value('B.clock.seconds'),0)

    def test_disabled_native_and_deferred_start_hooks(self):
        c=Bus().clients[0]
        c.run('D.mod.config.native_draft=false; PVP.pvp_start_match()')
        self.assertEqual(c.value('original_starts'),1)


if __name__=='__main__':
    unittest.main(verbosity=2)

-- Private two/four-player Royale integration for MPAPI + MultiplayerPvP 1.0.0.
-- The lobby host owns the draft; MPAPI carries directed actions with sender IDs.
return function(D)
    if not (MPAPI and PVP and PVP.id == 'MultiplayerPvP') then return end
    local C, core, U = D.mod.config, D.core, D.ui
    local RULES = 19
    local B = {phase = 'idle', serial = 0, attached = true, failed_sessions = {}}
    D.mpbridge = B
    local recap=D.recap or assert(SMODS.load_file('burglar/recap.lua',D.mod.id))()(D)
    local cubes=assert(SMODS.load_file('burglar/cubes.lua',D.mod.id))()(D)
    local T, session
    local function lobby() return MPAPI.get_current_lobby() end
    local function me() return lobby() and lobby().player_id end
    local function is_host() return lobby() and lobby().is_host end
    local function target(l)
        local meta = l and l:get_metadata() or {}
        return l and not l._destroyed and l.mod_id == 'MultiplayerPvP' and l._nakama
            and not l._local_mode and l.type == 'private' and meta.queue_mode == 'pvp_royale'
    end
    B.is_target = target
    local decks=assert(SMODS.load_file('burglar/deck_picker.lua',D.mod.id))()(D,B)
    local function profile(l) return tostring((l:get_metadata() or {}).ruleset or '') end
    local function connected(id)
        for _, p in ipairs(lobby() and lobby():get_players() or {}) do
            if p.id == id then return not p.is_away end
        end
        return false
    end
    local function all_connected()
        local current=lobby()
        if not current or not B.ids then return false end
        local available={}
        for _,player in ipairs(current:get_players()) do available[player.id]=not player.is_away end
        for _,id in ipairs(B.ids) do if not available[id] then return false end end
        return true
    end
    local function now() return love.timer.getTime() end
    local function message(text,notice) D.message = text; B.message = text; B.notice=notice end
    local function human_error(err) return tostring(err):gsub('^.-:%d+: ', ''):sub(1,120) end

    local function roster()
        local l = lobby()
        assert(T and T.ready and B.hooks_ready, 'Multiplayer API is starting. Launch Balatro through Steam.')
        assert(target(l), 'Join a private PvP Royale lobby first')
        T.attach(l)
        local ids, seen, owner = {}, {}, l.host_id
        local players = l:get_players()
        assert(#players == 2 or #players == 4, 'Exactly two or four players are required')
        for _, p in ipairs(players) do
            assert(type(p.id) == 'string' and not p.is_spectator and p.role ~= 'spectator', 'Spectators are not supported')
            assert(not seen[p.id], 'Duplicate lobby player identity')
            seen[p.id], ids[#ids+1] = true, p.id
        end
        if l.is_host then owner = me() end
        assert(owner and seen[owner] and seen[me()], 'Lobby owner/player identity is missing')
        table.sort(ids, function(a,b)
            if a == owner then return b ~= owner end
            if b == owner then return false end
            return a < b
        end)
        return ids, owner, tostring(l.code)
    end

    function B.matches()
        local ok, ids, owner, code = pcall(roster)
        local identity_ok=ok and B.ids and lobby() == B.lobby
            and code == B.room and owner == B.owner
            and table.concat(ids, '|') == table.concat(B.ids, '|')
        if not identity_ok then return false end
        if profile(lobby())~=B.profile then
            -- Once released, the drafted Joker identities are fixed. Balance
            -- changes affect the upcoming run, not ownership of those Jokers.
            if B.phase~='complete' or not B.pool or not B.released or B.started then return false end
            B.profile=profile(lobby())
        end
        return true
    end
    local function fail(text)
        if session then session.transition('error',text)
        else B.phase='error'; message(text) end
    end
    local function seat(id)
        for i, value in ipairs(B.ids or {}) do if value == id then return i end end
    end
    local function cache_catalog(keys,name)
        if not keys then keys,name=cubes.selected() end
        B.catalog_keys=core.copy(keys)
        B.cube_name=name or 'Default'
        B.catalog_set={}
        for _,key in ipairs(B.catalog_keys) do B.catalog_set[key]=true end
        B.catalog_signature=table.concat(B.catalog_keys,'|')
        B.catalog_count=#B.catalog_keys
    end
    local function signature() return B.catalog_signature or table.concat(D.catalog(), '|') end
    local function send(kind, data, recipient)
        local packet = {protocol = 4, kind = kind, session = B.session, room = B.room,
            recipient = recipient, data = data or {}}
        if connected(recipient) then return T.send(packet, recipient) end
    end
    local function every(map)
        for _, id in ipairs(B.ids or {}) do if not map[id] then return false end end
        return true
    end
    local combat=assert(SMODS.load_file('burglar/average_pvp.lua',D.mod.id))()(D,function(packet,recipient)
        return T.send(packet,recipient)
    end)

    session=assert(SMODS.load_file('burglar/session.lua',D.mod.id))()(B,{
        lobby=lobby,matches=B.matches,stop=combat.stop,message=message,
        clear_ui=function()
            D.more_open=false
            if D.pack_ui.reset_session then D.pack_ui.reset_session() else D.pack_ui.clear() end
            if D.views then D.views.team,D.views.final,D.views.tray,D.views.roster=nil,nil,nil,nil
            D.roster_context=nil end
            decks.pending=nil
            recap.open=false
        end,
    })
    B.reset=session.reset

    function B.begin()
        assert(is_host(), 'Only the lobby host can begin the draft')
        assert(not lobby():is_game_started(), 'Finish the current match first')
        assert(decks.synced(), 'Waiting for the server to confirm the selected deck')
        local ids,owner,room=roster()
        for _,id in ipairs(ids) do assert(connected(id),'All draft players must be connected') end
        local keys,cube_name=cubes.selected()
        local options=D.draft_options();options.player_count=#ids
        cubes.capacity(keys,options)
        session.reset()
        B.ids,B.owner,B.room=ids,owner,room
        B.lobby,B.profile=lobby(),profile(lobby())
        cache_catalog(keys,cube_name)
        B.serial = B.serial + 1
        B.session = me() .. ':' .. tostring(now()) .. ':' .. B.serial
        session.transition('checking')
        B.hello, B.completed, B.released, B.release_ack = {[me()] = true}, {}, false, {}
        B.last_offer = now()
        B.deadline = now() + 2
        C.armed_seat = false
        D.pack_ui.clear()
        message('Checking players. Draft pool: '..B.cube_name..' ('..B.catalog_count..' Jokers).')
        for _, id in ipairs(B.ids) do
            if id ~= me() then send('offer', {ids = B.ids, owner = B.owner, catalog = signature(), keys=B.catalog_keys, cube_name=B.cube_name, rules = RULES}, id) end
        end
    end

    local function publish()
        local s = B.host_state
        local rows = {}
        local players = {}
        for _,p in ipairs(lobby():get_players()) do players[p.id]=p end
        for i,id in ipairs(B.ids) do rows[i]={id=id,name=(players[id] or {}).displayName or ('Seat '..i),
            connected=connected(id),ready=s.done or not not s.submitted[i]} end
        for i, id in ipairs(B.ids) do
            send('view', {player_count = core.player_count(s), revision = s.revision, round = s.round, pick = s.pick, done = s.done,
                roster=rows,timer_mode=B.clock.setting=='scaling' and 'scaling' or 'fixed',timer_seconds=B.clock.seconds,timer_left=D.clock.left(B.clock,now()),timer_paused=B.clock.paused,
                rounds = s.rounds, pack_size=s.pack_size, picks_per_turn=s.picks_per_turn, total = s.total, seat = i, token = core.token(s, i), picked = not not s.submitted[i],
                cards = (s.done or s.submitted[i]) and {} or core.copy(s.current[i].cards),
                drafted = core.copy(s.pools[i])}, id)
        end
    end

    function B.start_draft()
        assert(is_host() and B.phase == 'checking', 'Run the lobby check first')
        assert(B.matches(), 'Lobby roster or ruleset changed; run the check again')
        assert(all_connected(), 'All draft players must be connected')
        assert(every(B.hello), 'Waiting for all Burglar players and private routing')
        assert(now() >= B.deadline, 'Wait two seconds for routing errors before beginning')
        local seed = D.fresh_seed()
        local options=D.draft_options()
        options.seed=seed
        options.player_count=#B.ids
        cubes.capacity(B.catalog_keys,options)
        B.host_state = core.new(B.catalog_keys, options)
        B.host_state.cube_name=B.cube_name
        session.transition('draft')
        B.clock=D.clock.new(C.pick_seconds)
        D.clock.reset(B.clock,B.host_state.round..':'..B.host_state.pick,now(),D.clock.cards(B.host_state))
        B.intents={}
        publish()
    end

    local function after_pick()
        local s=B.host_state
        local wave=s.round..':'..s.pick
        if s.done then B.clock.deadline=nil
        elseif wave~=B.clock.wave then D.clock.reset(B.clock,wave,now(),D.clock.cards(s)); B.intents={} end
        publish()
    end
    function B.tick(context_ok)
        if not is_host() or B.phase~='draft' or not B.host_state or B.host_state.done or B.expiring
            or not B.clock or B.clock.seconds==0 then return end
        if context_ok==nil then context_ok=B.matches() end
        if not context_ok then return end
        local changed,expired=D.clock.update(B.clock,now(),not all_connected())
        if expired then
            B.expiring=true
            local s,wave=B.host_state,B.clock.wave
            for i=1,#B.ids do
                if not s.done and s.round..':'..s.pick==wave and not s.submitted[i] then
                    local preferred=(B.intents[i] or {}).keys
                    assert(core.submit(s,i,core.auto_keys(s,i,preferred,love.math.random),core.token(s,i)))
                end
            end
            B.expiring=false; after_pick()
        elseif changed then publish() end
    end
    -- Recover a missed final pool/ack/release without changing picks or
    -- repeatedly saving the same completed pool. Bounded by one retry / 1.5s.
    function B.retry_completion(context_ok)
        if not context_ok or not is_host() or B.started or B.phase~='complete'
            or not B.host_state or not B.host_state.done then return end
        if B.last_finish_retry and now()-B.last_finish_retry<1.5 then return end
        B.last_finish_retry=now()
        if not every(B.completed) then
            publish()
        elseif not every(B.release_ack) then
            for _,id in ipairs(B.ids) do
                if not B.release_ack[id] then send('release',{},id) end
            end
        end
    end

    function B.time_left()
        local v=B.view
        if not v or v.done or type(v.timer_left)~='number' then return nil end
        if v.timer_paused then return v.timer_left,true end
        return math.max(0,v.timer_left-(now()-(v.timer_received or now()))),false
    end
    function B.readiness()
        local rows=core.copy(B.view and B.view.roster or {})
        local available={}
        for _,player in ipairs(lobby() and lobby():get_players() or {}) do available[player.id]=not player.is_away end
        for _,r in ipairs(rows) do r.connected=not not available[r.id] end
        return rows
    end

    local function valid_keys(list, limit)
        if type(list) ~= 'table' or #list > limit then return false end
        local allowed,seen=B.catalog_set or {},{}
        for _, key in ipairs(list) do
            if not allowed[key] or seen[key] then return false end
            seen[key] = true
        end
        return true
    end

    function B.receive(sender, p)
        if type(p) ~= 'table' or p.protocol ~= 4 then return end
        local ok, ids, owner, code = pcall(roster)
        if not ok or p.room ~= code then return end
        if type(sender) ~= 'string' then fail('Draft action has no sender identity'); return end
        local member = false
        for _, id in ipairs(ids) do if id == sender then member = true end end
        if not member then return end
        if p.recipient ~= me() then
            -- Only harmless offers/acks are sent until this routing check passes.
            fail('Server forwarded a private draft message to the wrong player')
            B.failed_sessions[p.session or ''] = true
            if owner ~= me() and p.kind ~= 'fault' then
                T.send({protocol = 4, kind = 'fault', session = p.session, room = code,
                    recipient = owner, data = {}}, owner)
            end
            return
        end
        local data = type(p.data) == 'table' and p.data or {}
        if p.kind == 'offer' then
            if type(p.session) ~= 'string' then return end
            if session.retired[p.session] then return end
            if B.failed_sessions[p.session or ''] then fail('Routing failed for this check; host must reset it'); return end
            if sender ~= owner or type(data.ids) ~= 'table'
                or table.concat(data.ids, '|') ~= table.concat(ids, '|') then return end
            if data.rules~=RULES then fail('Burglar versions differ');return end
            local valid,keys=pcall(cubes.validate,data.keys,true)
            if not valid or data.catalog~=table.concat(keys,'|') then
                fail('Host draft pool contains missing, excluded, or duplicate Jokers');return
            end
            if type(data.cube_name)~='string' or #data.cube_name>40 or data.cube_name:find('%c') then
                fail('Invalid host draft pool name');return
            end
            if B.session==p.session and data.catalog~=signature() then
                fail('Host draft pool changed; reset the draft');return
            end
            if B.session == p.session then
                if B.phase == 'checking' then send('hello', {catalog = signature(), rules = RULES}, owner) end
                return
            end
            session.reset()
            B.ids, B.owner, B.room, B.session = ids, owner, code, p.session
            cache_catalog(keys,data.cube_name)
            B.lobby, B.profile = lobby(), profile(lobby())
            session.transition('checking')
            C.armed_seat = false
            send('hello', {catalog = signature(), rules = RULES}, owner)
            message('Draft pool: '..B.cube_name..' ('..B.catalog_count..' Jokers). Waiting for host.')
        elseif p.session ~= B.session or not B.matches() then return
        elseif p.kind == 'fault' and is_host() then
            fail('Private custom-message routing failed; do not start the draft')
        elseif B.phase == 'error' then return
        elseif p.kind == 'hello' and is_host() and B.phase == 'checking' then
            if data.catalog ~= signature() or data.rules ~= RULES then fail('Joker catalogs or Burglar versions differ'); return end
            B.hello[sender] = true
            if every(B.hello) then message('All players checked: '..B.cube_name..'. Host can begin.') end
        elseif p.kind == 'intent' and is_host() and B.host_state then
            B.tick()
            local index=seat(sender)
            if not index or type(data.seq)~='number' or data.seq~=math.floor(data.seq) or data.seq<1 then return end
            local previous=B.intents[index]
            if previous and data.seq<=previous.seq then return end
            if core.validate_selection(B.host_state,index,data.keys,data.token,true) then
                B.intents[index]={seq=data.seq,keys=core.copy(data.keys)}
            end
        elseif p.kind == 'pick' and is_host() and B.host_state then
            B.tick()
            local index = seat(sender)
            if not index then return end
            local accepted, err = core.submit(B.host_state, index, data.keys, data.token)
            if not accepted then send('notice', {message = err}, sender); return end
            after_pick()
        elseif p.kind == 'refresh' and is_host() and B.host_state then publish()
        elseif p.kind == 'view' and sender == owner then
            if B.started then return end
            if type(data.revision) ~= 'number' or data.seat ~= seat(me())
                or not valid_keys(data.cards, B.catalog_count) or not valid_keys(data.drafted, B.catalog_count) then return end
            if B.view and data.revision < B.view.revision then return end
            if data.player_count~=#B.ids or data.pack_size~=9 or (data.picks_per_turn~=1 and data.picks_per_turn~=2)
                or type(data.rounds)~='number' or data.rounds~=math.floor(data.rounds) or data.rounds<1 or data.rounds>4
                or data.total~=#B.ids*core.roster_size(data.rounds) or data.total>B.catalog_count
                or #data.cards>9 or #data.drafted>core.roster_size(data.rounds) then return end
            if B.view and (data.rounds~=B.view.rounds or data.picks_per_turn~=B.view.picks_per_turn) then return end
            if data.done and #data.drafted~=core.roster_size(data.rounds) then return end
            local old_count=B.view and #B.view.drafted
            if old_count and #data.drafted>old_count and #data.drafted-old_count<=2 then
                D.pack_ui.confirmed()
            end
            B.view=core.copy(data)
            B.notice=nil
            session.transition(data.done and 'complete' or 'draft')
            B.view.timer_received=now()
            if data.done then
                if not B.pool then
                    B.pool = {schema = 1, source = 'mpapi_pvp', room = code, session = B.session,
                        copy_limits=core.has_copies(B.catalog_keys), draft_schema=core.SCHEMA, player_count=#B.ids, rounds=data.rounds, seat = data.seat, keys = core.copy(data.drafted)}
                    C.mp_last_pool = core.copy(B.pool)
                    SMODS.save_mod_config(D.mod)
                end
                send('complete_ack', {}, owner)
            end
        elseif p.kind == 'complete_ack' and is_host() and B.host_state and B.host_state.done then
            B.completed[sender] = true
            if every(B.completed) and not B.released then
                for _, id in ipairs(B.ids) do if id ~= me() then send('release', {}, id) end end
                B.released, B.release_ack[me()] = true, true
                message('Confirming all clients are ready to launch Royale...')
            end
        elseif p.kind == 'release' and sender == owner and B.pool then
            B.released = true; send('release_ack', {}, owner)
            message('Draft complete. Ready up in PvP, then wait for the host.')
        elseif p.kind == 'release_ack' and is_host() and B.released then
            B.release_ack[sender] = true
            if every(B.release_ack) then message('All pools ready. Ready up in PvP, then start Royale.') end
        elseif p.kind == 'notice' and sender == owner then
            D.pack_ui.unlock(); message(tostring(data.message):sub(1,120),true)
        end
    end

    local function safe_receive(from, packet)
        if D.diag then D.diag('packet_receive',{kind=type(packet)=='table' and packet.kind}) end
        local ok, err = pcall(function()
            if D.spectator and D.spectator.receive(from,packet) then return end
            if D.roster_duel and D.roster_duel.receive(from,packet) then return end
            if recap.receive(from,packet) then return end
            if combat.receive(from,packet) then return end
            B.receive(from,packet)
        end)
        if not ok then
            if D.diag then D.diag('packet_error',{reason='dispatch_error'}) end
            fail('Draft message failed: ' .. human_error(err))
        end
    end
    T = assert(SMODS.load_file('burglar/mpapi_transport.lua', D.mod.id))()(D, {
        packet = safe_receive,
        error = function(text) D.pack_ui.unlock(); message(text,true) end,
        event = function(l, kind, id)
            if D.spectator then pcall(D.spectator.event,l,kind,id) end
            if D.roster_duel then D.roster_duel.event(l,kind,id) end
            recap.event(l,kind,id)
            if B.lobby~=l then return end
            if D.diag and kind~='metadata_changed' then D.diag('lobby',{kind=kind}) end
            session.invalidate()
            if kind=='game_ended' or kind=='lobby_closed' then
                if kind=='game_ended' and combat.active() then
                    combat.rounds.handover.recover_outcome()
                end
                session.reset(kind=='game_ended' and 'Match ended. Start a fresh draft for the next match.' or 'Draft lobby closed.')
            elseif kind=='host_changed' then
                if B.started and combat.active() then
                    combat.rounds.handover.change(id)
                else
                    combat.stop()
                    fail('Host changed before the match. Reset the draft with two or four players.')
                end
            elseif kind=='metadata_changed' and combat.active() then
                combat.rounds.handover.observe()
            elseif kind=='player_left' and not B.started then
                fail('Lobby roster changed. Reset the draft before the next match.')
            elseif kind=='player_reconnected' or kind=='snapshot_applied' then
                if not B.started then B.refresh_due=true end
            elseif kind=='disconnected' then
                message('Connection lost. Rejoin the same lobby to resume if the host remains.',true)
            end
        end,
    })
    B.transport = T

    function B.pick(keys, token) send('pick', {keys = keys, token = token}, B.owner) end
    function B.intent(keys,token,seq)
        if B.view and (B.view.timer_seconds or 0)>0 then send('intent',{keys=keys,token=token,seq=seq},B.owner) end
    end
    function B.pool_ready()
        return B.matches() and B.pool and B.released and B.phase ~= 'error'
    end
    function B.launch_ready()
        return decks.synced() and B.pool_ready() and all_connected()
            and (not is_host() or every(B.release_ack))
    end
    function B.prepare_run()
        if D.roster_duel and D.roster_duel.advertised(lobby()) then return D.roster_duel.prepare_run() end
        if C.native_draft == false or not target(lobby()) then return end
        assert(B.pool_ready(), 'Burglar: finish the draft and receive all pools before starting Royale')
        B.started = true
        session.transition('playing')
        return core.copy(B.pool)
    end

    local start_ref
    MPAPI.on_loaded(function()
        local ok, err = pcall(function()
            combat.install()
            decks.install()
            start_ref = assert(PVP.pvp_start_match, 'PvP 1.0.0 start flow missing')
            function PVP.pvp_start_match(...)
                if D.roster_duel and (D.roster_duel.advertised(lobby())
                    or (D.roster_duel.enabled and D.roster_duel.lobby==lobby())) then
                    if not D.roster_duel.start_allowed() then return end
                end
                if C.native_draft ~= false and target(lobby()) and is_host() then
                    if not (B.launch_ready() and not B.started) then
                        if not B.matches() or B.started or B.phase == 'idle' then
                            local accepted, failure = pcall(B.begin)
                            if not accepted then message(human_error(failure)) end
                        end
                        D.mode = 'mp'; U.show(); return
                    end
                    B.pending_launch = true
                    return
                end
                return start_ref(...)
            end
            local on_game_start_ref = assert(PVP.on_game_start, 'PvP 1.0.0 game-start flow missing')
            function PVP.on_game_start(params)
                if D.roster_duel and not D.roster_duel.on_start(params) then return end
                local run_id=type(params)=='table' and params.run_id
                local run_identity=run_id and (tostring(run_id)..'|'..tostring(params.seed)..'|'..tostring(not not params.restarted))
                if target(lobby()) and run_identity and B.handled_run==run_identity then return end
                if C.native_draft ~= false and target(lobby()) and not B.pool_ready() then
                    fail('Royale started before every Burglar pool was ready. Return to the lobby and reset.')
                    D.mode = 'mp'; U.show(); return
                end
                if C.native_draft~=false and target(lobby()) and B.pool_ready() then
                    decks.apply_run()
                    combat.start(lobby(),B.session,run_identity)
                    recap.arm(lobby(),B,run_identity,run_id,function(packet,recipient) return T.send(packet,recipient) end)
                    B.handled_run=run_identity
                else combat.stop() end
                return on_game_start_ref(params)
            end
            B.hooks_ready = true
        end)
        if not ok then fail('PvP integration startup failed: ' .. human_error(err)) end
    end)

    function D.multiplayer_screen()
        local view = B.view
        local drafting=view and not view.done
        local nodes = {}
        if not drafting then nodes[#nodes+1]=U.line('BURGLAR / JOKER DRAFT',0.36) end
        if B.phase=='idle' and not is_host() then
            nodes[#nodes+1]=U.line('Waiting for the host to set up the draft.',0.26)
        end
        if not view or view.done then
            nodes[#nodes+1]=U.line(B.ids and #B.ids==2
                and '4 lives - PvP from Ante 2 - native 1v1 scoring'
                or '4 lives - PvP from Ante 2 - final two play 1v1',0.23)
        end
        if not view or view.done then
            nodes[#nodes+1] = U.line('Draft Jokers with 2 or 4 players.', 0.25)
        end
        if B.phase == 'checking' and is_host() then
            local count = 0
            for _, id in ipairs(B.ids or {}) do if B.hello[id] then count = count+1 end end
            nodes[#nodes+1] = U.line(count .. '/'..#B.ids..' players connected to draft')
            nodes[#nodes+1] = D.draft_settings()
            nodes[#nodes+1] = U.row({D.timer_button()})
            nodes[#nodes+1] = U.row({U.button('Start drafting', 'draftout_mp_begin', nil, 5)})
        elseif view and not view.done then
            nodes[#nodes+1]=D.views.header('BURGLAR  |  Pack '..view.round..'/'..view.rounds..'  -  Pick '..view.pick..'/'..math.ceil(core.round_size(view.round,view.rounds)/(view.picks_per_turn or 1)),B.time_left)
            nodes[#nodes+1]=D.views.readiness(B.readiness(),view.seat,view.round)
            if view.picked then
                nodes[#nodes+1] = D.views.waiting(function() return B.view and B.view.drafted or {} end,
                    'mp:'..B.session..':'..view.seat,{time_left=B.time_left,total=core.roster_size(view.rounds)}); D.pack_ui.clear()
            else
                nodes[#nodes+1] = D.pack_ui.build(view.cards, view.token,
                    'mp:' .. B.session .. ':' .. view.seat, B.pick,nil,
                    {time_left=B.time_left,on_change=B.intent,picks_per_turn=view.picks_per_turn,get_team=function() return B.view and B.view.drafted or {} end,
                        total=core.roster_size(view.rounds)})
            end
        elseif B.pool then
            nodes[#nodes+1]=D.views.completed(B.pool.keys,'Close this screen and Ready up in the PvP lobby.')
            if D.roster_duel then nodes[#nodes+1]=U.row({U.button('Save roster / bracket 1v1','draftout_bracket_open',nil,4)}) end
            if is_host() and B.launch_ready() then
                nodes[#nodes+1] = U.row({U.button('Start match', 'draftout_mp_start', nil, 5)})
            end
        end
        if not drafting then
            if recap.available() then nodes[#nodes+1]=U.row({recap.button()}) end
            if is_host() then
                if not B.pool and B.phase~='checking' then
                    nodes[#nodes+1]=D.draft_settings()
                    nodes[#nodes+1]=U.row({D.timer_button()})
                end
                local label = (B.host_state or B.pool) and 'Restart draft'
                    or B.phase == 'checking' and 'Check players again' or 'Prepare draft'
                nodes[#nodes+1]=U.row({U.button(label,'draftout_mp_check',nil,4.5)})
            end
        end
        -- Normal draft status is already represented by the header/seating strip.
        -- Retain errors and recovery controls without a permanent extra status row.
        if not drafting or B.phase=='error' or B.notice or D.more_open then
            nodes[#nodes+1] = U.line((B.message or ''):sub(1,95), 0.23)
        end
        return {n = G.UIT.C, config = {align = 'cm', padding = 0.06}, nodes = nodes}
    end
    local function action(fn)
        return function(e)
            local ok, err = pcall(fn,e)
            if not ok then message(human_error(err),true) end
            U.show()
        end
    end
    G.FUNCS.draftout_mp_open = function() D.mode = 'mp'; D.more_open=false; U.show() end
    G.FUNCS.draftout_mp_check = action(function() B.begin() end)
    G.FUNCS.draftout_mp_begin = action(function() B.start_draft() end)
    G.FUNCS.draftout_mp_refresh = action(function()
        if B.owner then send('refresh', {}, B.owner);message('Requested the current pack from the host.') end
    end)
    G.FUNCS.draftout_mp_start = action(function() PVP.pvp_start_match() end)

    local updates=assert(SMODS.load_file('burglar/updates.lua',D.mod.id))()(D)
    updates.add('multiplayer',function(self,dt)
        if D.roster_duel then D.roster_duel.tick() end
        recap.tick()
        combat.rounds.handover.tick()
        combat.rounds.retry_ready()
        local context_ok=session.poll(now())
        B.tick(context_ok)
        B.retry_completion(context_ok)
        local visible=D.mode=='mp' and D.overlay and G.OVERLAY_MENU==D.overlay
        if visible and D.views then D.views.update(B.readiness(),B.view and B.view.round) end
        local pressed = love.keyboard and love.keyboard.isDown('f8') or false
        if pressed and not B.key_down and target(lobby()) and not lobby():is_game_started() then
            D.mode = 'mp'; U.show()
        end
        B.key_down = pressed
        if B.refresh_due and context_ok then
            B.refresh_due = false
            if is_host() and B.host_state then publish()
            elseif B.owner and connected(B.owner) then send('refresh', {}, B.owner) end
        end
        if B.phase == 'checking' and is_host() and context_ok and now() - B.last_offer > 1.5 then
            B.last_offer = now()
            for _, id in ipairs(B.ids) do
                if not B.hello[id] then send('offer', {ids = B.ids, owner = B.owner,
                    catalog = signature(), keys=B.catalog_keys, cube_name=B.cube_name, rules = RULES}, id) end
            end
        end
        if B.pending_launch then
            B.pending_launch = false
            if B.launch_ready() and not B.started then
                if D.overlay and G.OVERLAY_MENU == D.overlay then G.FUNCS.exit_overlay_menu() end
                start_ref()
            else message('Draft launch paused. Check connections and refresh your pack.') end
        end
        if visible then
            local v = B.view or {}
            -- Other players confirming must not destroy this player's hovered card.
            local marker = B.phase .. ':' .. tostring(v.round) .. ':' .. tostring(v.pick)
                .. ':' .. tostring(v.token and v.token.pack_id) .. ':' .. tostring(v.picked)
                .. ':' .. table.concat(v.cards or {}, '|') .. ':' .. #(v.drafted or {})
                .. ':' .. tostring(B.released) .. ':' .. tostring(B.message) .. ':' .. tostring(context_ok and all_connected())
                .. ':' .. tostring(recap.available())
            if marker ~= B.last_marker then B.last_marker = marker; U.show() end
        end
    end)
end

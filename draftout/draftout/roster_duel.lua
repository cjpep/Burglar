-- Reusable roster tickets and explicit, lobby-scoped consent for native 1v1s.
-- Pairings are manual. No bracket referee or changes to upstream 1v1 scoring.
return function(D)
    local K={message='Save a completed roster, then join a private two-player Nemesis lobby.',page=1}
    D.roster_duel=K
    local C,U,core=D.mod.config,D.ui,D.core
    local allowed={};for _,key in ipairs(assert(SMODS.load_file('draftout/vanilla_keys.lua',D.mod.id))()) do allowed[key]=true end
    local function lobby() return MPAPI and MPAPI.get_current_lobby() end
    local function now() return D.now and D.now() or love.timer.getTime() end
    local function integer(n,a,b) return type(n)=='number' and n==math.floor(n) and n>=a and n<=b end
    local function save() SMODS.save_mod_config(D.mod) end
    function K.validate(data)
        assert(type(data)=='table' and data.schema==1,'Unsupported roster code')
        assert(type(data.event)=='string' and #data.event>=8 and #data.event<=64
            and data.event:match('^[%w-]+$'),'Invalid draft identifier')
        assert(data.players==2 or data.players==4,'Roster needs two or four original draft seats')
        assert(integer(data.seat,1,data.players) and integer(data.rounds,1,4),'Invalid roster seat or pack count')
        assert(type(data.keys)=='table' and #data.keys==core.roster_size(data.rounds),'Incomplete roster')
        local keys,seen={},{}
        for index,key in pairs(data.keys) do
            assert(integer(index,1,#data.keys) and type(key)=='string' and allowed[key]
                and G.P_CENTERS[key] and not seen[key],'Unknown, excluded or repeated Joker')
            seen[key]=true;keys[index]=key
        end
        return {schema=1,event=data.event,players=data.players,seat=data.seat,rounds=data.rounds,keys=keys}
    end
    -- Correlation only, not a signature. Do not export the source session's account ID.
    local function event_id(value)
        local a,b=5381,7919
        for i=1,#value do local n=value:byte(i);a=(a*33+n)%4294967291;b=(b*31+n)%4294967279 end
        return string.format('draft-%08x-%08x',a,b)
    end
    function K.capture()
        assert(not K.enabled,'Disable roster mode before changing the loaded roster')
        local pool=(D.mpbridge or {}).pool or C.mp_last_pool
        assert(pool and pool.draft_schema==core.SCHEMA and pool.session,'Finish an online draft first')
        C.bracket_roster=K.validate({schema=1,event=event_id(pool.session),players=pool.player_count or 4,
            rounds=pool.rounds or 3,seat=pool.seat,keys=pool.keys})
        save();K.page=1;K.message='Roster saved. You can reuse it in each bracket round.'
    end
    function K.export()
        return 'DRAFTROSTER1:'..MPAPI.json_encode(K.validate(C.bracket_roster))
    end
    function K.import(text)
        assert(not K.enabled,'Disable roster mode before importing another roster')
        assert(type(text)=='string' and #text<=8000 and text:sub(1,13)=='DRAFTROSTER1:','Copy a Draftout roster code first')
        local ticket=K.validate(MPAPI.json_decode(text:sub(14)))
        C.bracket_roster=ticket;save();K.page=1;K.message='Roster imported. Enable it only in the intended 1v1 lobby.'
    end
    local function target(l)
        return l and not l._destroyed and l.mod_id=='MultiplayerPvP' and l._nakama and not l._local_mode
            and l.type=='private' and (l:get_metadata() or {}).queue_mode=='pvp_nemesis'
    end
    local function pair(l)
        assert(target(l),'Join a private Nemesis (normal 1v1) lobby')
        local players=l:get_players();assert(#players==2,'Exactly two players must be in this lobby')
        local ids={}
        for _,p in ipairs(players) do
            assert(type(p.id)=='string' and not p.is_away and not p.is_spectator and p.role~='spectator','Both players must be connected')
            ids[#ids+1]=p.id
        end
        table.sort(ids);assert(ids[1]~=ids[2],'Duplicate player identity')
        assert(l.player_id==ids[1] or l.player_id==ids[2],'Local player is not in this lobby')
        return ids
    end
    local function same(a,b)
        return a.event==b.event and a.players==b.players and a.seat==b.seat and a.rounds==b.rounds
            and table.concat(a.keys,'|')==table.concat(b.keys,'|')
    end
    local function manifest(l) return (l and l:get_metadata() or {}).draftout_bracket end
    function K.advertised(l) return target(l) and type(manifest(l))=='table' end
    local function send(kind,data,to)
        local l=lobby()
        D.mpbridge.transport.send({protocol=4,kind=kind,recipient=to,
            session=D.mpbridge.session,data=data},to)
    end
    function K.disable()
        local l=lobby()
        assert(not (K.enabled and l==K.lobby and l:is_game_started()),'This roster belongs to the running match')
        if K.enabled and l==K.lobby then
            if PVP.signal_ready then PVP.signal_ready(false) end
            if l.is_host then l:set_metadata({draftout_bracket=false})
            else send('bracket_cancel',{token=K.token},l.host_id) end
        end
        K.enabled,K.lobby,K.ticket,K.token,K.ack,K.accepted=nil,nil,nil,nil,nil,nil
        K.message='Roster mode off. Saved roster retained; ordinary PvP uses normal shops.'
    end
    function K.enable()
        local l=lobby();pair(l)
        assert(not l:is_game_started(),'Enable the roster before starting a match')
        K.ticket=K.validate(C.bracket_roster)
        if PVP.signal_ready then PVP.signal_ready(false) end
        K.lobby,K.enabled,K.ack,K.started,K.accepted=l,true,nil,nil,nil
        if l.is_host then
            K.token=MPAPI.generate_id()
            l:set_metadata({draftout_bracket={schema=1,token=K.token,host=l.host_id,
                event=K.ticket.event,players={{id=l.player_id,roster=core.copy(K.ticket)}}},starting_lives=4})
        end
        K.next_tick=nil;K.message='Waiting for both players to enable matching saved rosters.'
    end
    local function checked(l,require_ack)
        assert(K.enabled and K.lobby==l,'Enable your saved roster for this lobby first')
        local ids=pair(l);local m=manifest(l)
        assert(type(m)=='table' and m.schema==1 and type(m.token)=='string' and #m.token<=160
            and m.host==l.host_id and type(m.players)=='table' and #m.players==2,'Waiting for roster confirmation')
        local entries,used,own={},{}
        for _,entry in ipairs(m.players) do
            assert(type(entry)=='table' and (entry.id==ids[1] or entry.id==ids[2]) and not entries[entry.id],'Lobby roster changed')
            local ticket=K.validate(entry.roster);entries[entry.id]=ticket
            assert(ticket.event==K.ticket.event and ticket.rounds==K.ticket.rounds and ticket.players==K.ticket.players,
                'These rosters came from different drafts')
            for _,key in ipairs(ticket.keys) do assert(not used[key],'These rosters contain overlapping Jokers');used[key]=true end
            if entry.id==l.player_id then own=ticket end
        end
        assert(entries[ids[1]].seat~=entries[ids[2]].seat,'Choose different draft seats')
        assert(own and same(own,K.ticket),'Your loaded roster differs from the confirmed roster')
        assert((l:get_metadata() or {}).starting_lives==4,'Waiting for four-life lobby settings')
        if require_ack and l.is_host then assert(K.ack==m.token,'Waiting for the opponent to confirm the roster') end
        return own,m
    end
    function K.ready() return pcall(checked,lobby(),true) end
    function K.receive(from,p)
        if type(p)~='table' or type(p.kind)~='string' or p.kind:sub(1,8)~='bracket_' then return false end
        local l=lobby()
        if not (K.enabled and K.lobby==l and target(l) and not l:is_game_started()
            and p.protocol==4 and p.recipient==l.player_id and from~=l.player_id) then return true end
        local ok,err=pcall(function()
            local ids=pair(l);assert(from==ids[1] or from==ids[2],'Unknown player')
            local m=manifest(l);local data=p.data
            assert(type(m)=='table' and m.host==l.host_id and type(data)=='table' and data.token==m.token,'Stale roster message')
            if l.is_host and p.kind=='bracket_consent' then
                local other=K.validate(data.roster)
                assert(other.event==K.ticket.event and other.rounds==K.ticket.rounds and other.players==K.ticket.players
                    and other.seat~=K.ticket.seat,'Use different seats from the same draft')
                local used={};for _,key in ipairs(K.ticket.keys) do used[key]=true end
                for _,key in ipairs(other.keys) do assert(not used[key],'These rosters overlap') end
                if #m.players==2 then
                    for _,entry in ipairs(m.players) do if entry.id==from then assert(same(K.validate(entry.roster),other),'Opponent changed roster');return end end
                    error('Lobby roster changed; disable and enable again')
                end
                local next_manifest=core.copy(m)
                next_manifest.players[2]={id=from,roster=other}
                l:set_metadata({draftout_bracket=next_manifest,starting_lives=4})
            elseif l.is_host and p.kind=='bracket_ack' then
                checked(l,false);K.ack=m.token
            elseif l.is_host and p.kind=='bracket_cancel' then
                K.ack=nil;K.disable()
            end
        end)
        if not ok then K.message=tostring(err):gsub('^.-:%d+: ',''):sub(1,120) end
        return true
    end
    function K.tick()
        if not K.enabled then return end
        local l=lobby()
        if K.lobby~=l or not target(l) then K.enabled,K.lobby,K.started,K.ticket=nil,nil,nil,nil;return end
        if l:is_game_started() then return end
        if K.next_tick and now()<K.next_tick then return end;K.next_tick=now()+1.5
        local m=manifest(l)
        if not l.is_host and type(m)=='table' and m.host==l.host_id and type(m.token)=='string' then
            K.token=m.token
            local ok=pcall(checked,l,false)
            send(ok and 'bracket_ack' or 'bracket_consent',{token=m.token,roster=core.copy(K.ticket)},l.host_id)
        end
        local ok,err=K.ready()
        K.message=ok and 'Rosters confirmed. Ready up in PvP; the host can start a fresh 1v1.'
            or tostring(err):gsub('^.-:%d+: ',''):sub(1,120)
    end
    function K.start_allowed()
        local ok,err=K.ready()
        if not ok then K.message=tostring(err):gsub('^.-:%d+: ',''):sub(1,120);D.mode='bracket';U.show();return false end
        return true
    end
    function K.on_start(params)
        local l=lobby()
        if not (K.advertised(l) or (K.enabled and K.lobby==l)) then return true end
        local identity=type(params)=='table' and params.run_id
        if K.started and K.started.lobby==l and K.started.run==identity then return false end
        local ok,ticket=pcall(checked,l,true)
        if not ok then K.message=tostring(ticket):gsub('^.-:%d+: ','');D.mode='bracket';U.show();return false end
        K.started={lobby=l,run=identity,ticket=core.copy(ticket)}
        -- Native PvP owns all combat; only apply its agreed four-life setting.
        PVP.LOBBY.config.starting_lives=4
        return true
    end
    function K.in_run() return K.enabled and K.started and K.started.lobby==lobby() end
    function K.prepare_run()
        if not K.advertised(lobby()) then return end
        assert(K.started and K.started.lobby==lobby(),'Saved-roster match was not confirmed')
        local t=K.started.ticket
        return {schema=1,draft_schema=core.SCHEMA,source='draftout_bracket',player_count=t.players,
            rounds=t.rounds,seat=t.seat,keys=core.copy(t.keys),event=t.event}
    end
    function K.event(l,kind)
        if K.lobby~=l then return end
        if kind=='game_ended' or kind=='lobby_closed' or kind=='host_changed' or kind=='player_left' then
            if D.diag then D.diag('lobby',{kind=kind}) end
            -- Native PvP resolves the match. A subsequent match needs fresh consent.
            K.enabled,K.lobby,K.ack,K.token=nil,nil,nil,nil
            if l==lobby() and l.is_host and kind~='lobby_closed' then l:set_metadata({draftout_bracket=false}) end
            K.message='Match/lobby changed. Saved roster retained; enable it again for the next round.'
        end
    end
    function K.screen()
        local nodes={D.views.header('SAVED-ROSTER 1v1'),U.line('Fresh run. Four lives. Same drafted Joker pool.',0.25)}
        local ok,t=pcall(K.validate,C.bracket_roster)
        if ok then
            nodes[#nodes+1]=U.line('Seat '..t.seat..' / '..t.players..'  |  '..#t.keys..' Jokers',0.28)
            local shown={};local pages=math.ceil(#t.keys/12);K.page=math.max(1,math.min(K.page,pages))
            for i=(K.page-1)*12+1,math.min(K.page*12,#t.keys) do shown[#shown+1]=t.keys[i] end
            nodes[#nodes+1]=D.pack_ui.grid(shown,{scale=0.42,per_row=6})
            nodes[#nodes+1]=U.row({U.button('<','draftout_bracket_prev',nil,1),U.line('Page '..K.page..'/'..pages,0.22),U.button('>','draftout_bracket_next',nil,1)})
        else nodes[#nodes+1]=U.line('No saved roster loaded.',0.28) end
        nodes[#nodes+1]=U.row({U.button('Save latest draft roster','draftout_bracket_capture',nil,3.6),U.button('Copy roster code','draftout_bracket_copy',nil,3)})
        nodes[#nodes+1]=U.row({U.button('Import from clipboard','draftout_bracket_import',nil,3.6),
            U.button(K.enabled and 'Disable roster mode' or 'Enable for this lobby','draftout_bracket_toggle',nil,3.6)})
        nodes[#nodes+1]=U.line(K.message,0.22)
        return {n=G.UIT.C,config={align='cm',padding=0.06},nodes=nodes}
    end
    local function action(fn) return function()
        local ok,err=pcall(fn);if not ok then K.message=tostring(err):gsub('^.-:%d+: ',''):sub(1,120) end
        U.show()
    end end
    G.FUNCS.draftout_bracket_open=function() D.mode='bracket';if D.recap then D.recap.open=false end;D.views.team=nil;U.show() end
    G.FUNCS.draftout_bracket_capture=action(K.capture)
    G.FUNCS.draftout_bracket_copy=action(function() love.system.setClipboardText(K.export());K.message='Roster code copied. Keep it for the next bracket round.' end)
    G.FUNCS.draftout_bracket_import=action(function() K.import(love.system.getClipboardText()) end)
    G.FUNCS.draftout_bracket_toggle=action(function() if K.enabled then K.disable() else K.enable() end end)
    G.FUNCS.draftout_bracket_prev=action(function() K.page=math.max(1,K.page-1) end)
    G.FUNCS.draftout_bracket_next=action(function() K.page=K.page+1 end)
    return K
end

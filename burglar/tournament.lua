-- Two independent native Nemesis games. The original room hosts semi 1 and
-- later the final; semi 2 uses a separate socket/room/referee. No four-seat PvP.
return function(D)
    local B,K,U,C=D.mpbridge,D.roster_duel,D.ui,D.mod.config
    if not (B and K and MPAPI) then return end
    local T={acks={},reports={}};D.tournament=T
    local function lobby() return MPAPI.get_current_lobby() end
    local function now() return D.now and D.now() or love.timer.getTime() end
    local function clone(v) return D.core.copy(v) end
    local function meta(l) return l and l:get_metadata() or {} end
    local function state() return type(C.tournament_session)=='table' and C.tournament_session end
    local function save(s) C.tournament_session=s;SMODS.save_mod_config(D.mod) end
    local function code(v) return type(v)=='string' and #v>0 and #v<=32 and v:match('^[%w]+$') end
    local function private(l) return l and not l._destroyed and l._nakama and l.type=='private' and l.mod_id=='MultiplayerPvP' end
    local function present(l,id) for _,p in ipairs(l:get_players()) do if p.id==id and not p.is_away then return true end end end
    local function seat(b,id) for i,x in ipairs(b.ids) do if x==id then return i end end end
    local function pair(b,n)
        if n==1 then return b.ids[1],b.ids[2] elseif n==2 then return b.ids[3],b.ids[4] end
        return b.wins[1],b.wins[2]
    end
    local phases={setup=true,allocating=true,semis=true,reunion=true,final=true,complete=true}
    local function valid(b)
        if type(b)~='table' or b.v~=2 or type(b.event)~='string' or #b.event>160 or not code(b.hub)
            or not phases[b.phase] or type(b.ids)~='table' or #b.ids~=4 or type(b.names)~='table'
            or type(b.wins)~='table' or type(b.opts)~='table' or (b.room and not code(b.room)) then return end
        local seen={};for _,id in ipairs(b.ids) do if type(id)~='string' or seen[id] then return end;seen[id]=true end
        for n=1,3 do if b.wins[n] then local a,c=pair(b,n);if b.wins[n]~=a and b.wins[n]~=c then return end end end
        if (b.phase=='final' or b.phase=='complete') and not (b.wins[1] and b.wins[2]) then return end
        return b
    end
    function T.board(l) local b=private(l) and valid(meta(l).burglar_tournament);return b and b.hub==l.code and b end
    function T.current_board(l)
        local s=state()
        return T.board(l) or (private(l) and s and s.board and l.code==s.board.room and valid(s.board))
    end
    local function put(l,b,extra)
        local m=extra or {};m.burglar_tournament=b;l:set_metadata(m)
    end
    local function epoch(b) return b.event..':'..b.phase..':'..tostring(b.room) end
    local function sync(l,b)
        local e=epoch(b)..':'..l.host_id
        if T.epoch~=e then T.epoch=e;T.acks={};T.reports={};T.committing=nil end
    end
    function T.requested(l) return private(l) and meta(l).queue_mode=='pvp_royale' and meta(l).burglar_format=='tournament' end
    function T.begin()
        local l=lobby();assert(private(l) and l.is_host and B.is_target(l) and not l:is_game_started() and not T.board(l),'Open a private Burglar draft first')
        assert(B.launch_ready() and #B.ids==4 and not B.started and not B.pending_launch,'Finish a four-player draft first')
        local m=meta(l);local names={}
        for i,id in ipairs(B.ids) do names[i]=id;for _,p in ipairs(l:get_players()) do if p.id==id then names[i]=p.displayName or id end end end
        local opts={starting_lives=4,kind='private',queue_mode='pvp_nemesis',gamemode=PVP.PVP_GAMEMODES.pvp_nemesis.gamemode,
            deck=m.deck or 'Red Deck',stake=m.stake or '1',ruleset=m.ruleset,trap_cards=m.trap_cards==true,
            pvp_start_round=m.pvp_start_round or 2,burglar_stake_stickers=m.burglar_stake_stickers==true}
        for _,key in ipairs({'modifier_layers','challenge','sleeve'}) do if m[key]~=nil then opts[key]=clone(m[key]) end end
        opts.back=opts.deck
        put(l,{v=2,event=MPAPI.generate_id(),draft=B.session,hub=l.code,ids=clone(B.ids),names=names,
            phase='setup',wins={},room=false,opts=opts},{spectatable=false})
    end
    local function capture(l,b)
        local s=state();if s and s.event==b.event and s.me==l.player_id then
            if not s.board or s.board.phase~=b.phase or s.board.room~=b.room then s.board=clone(b);save(s) end
            return s
        end
        local n=seat(b,l.player_id);local p=B.pool or C.mp_last_pool
        if not (n and p and p.session==b.draft and p.seat==n and p.player_count==4) then return end
        s={event=b.event,hub=b.hub,me=l.player_id,ticket=K.from_pool(p),board=clone(b),destination=l.code}
        save(s);return s
    end
    local function result_ok(r,b,n)
        local a,c=pair(b,n)
        return type(r)=='table' and r.stage==n and r.room==(n==2 and b.room or b.hub)
            and type(r.run)=='string' and #r.run>0 and #r.run<=160 and (r.winner==a or r.winner==c or r.winner==false)
    end
    local function send(l,b,s)
        local stamp=epoch(b)..':'..l.host_id..':'..tostring(s.result and s.result.run)..':'..tostring(s.reserved)..':'..tostring(s.reserve_error)
        if T.sent==stamp and now()<(T.send_after or 0) then return end
        T.sent=stamp;T.send_after=now()+5
        B.transport.send({kind='tourney_status',protocol=4,recipient=l.host_id,room=l.code,session=epoch(b),
            data={result=s.result,reserved=s.reserved,error=s.reserve_error}},l.host_id)
    end
    function T.receive(from,p)
        if type(p)~='table' or p.kind~='tourney_status' then return false end
        local l=lobby();local s=state();local b=T.board(l) or (private(l) and s and s.board and l.code==s.board.room and valid(s.board))
        if not (b and l.is_host and p.protocol==4 and p.recipient==l.player_id and p.room==l.code
            and p.session==epoch(b) and seat(b,from) and present(l,from) and type(p.data)=='table') then return true end
        sync(l,b);T.acks[from]=true
        if l.code==b.hub and b.phase=='allocating' and from==b.ids[3] then
            if code(p.data.reserved) and p.data.reserved~=b.hub then
                local n=clone(b);n.room=p.data.reserved;n.phase='semis';put(l,n)
            elseif p.data.error then T.note='Second room could not open. Return to setup and retry.' end
        end
        local r=p.data.result
        for n=1,3 do
            local a,c=pair(b,n)
            if not l:is_game_started() and not b.wins[n] and (from==a or from==c) and result_ok(r,b,n) and r.run~=meta(l).burglar_replay
                and (n==3 and b.phase=='final' or n~=3 and (b.phase=='semis' or b.phase=='reunion')) then
                T.reports[from]=clone(r)
                local x,y=T.reports[a],T.reports[c]
                if x and y and x.stage==n and y.stage==n and x.run==y.run and x.winner==y.winner then
                    if not x.winner then
                        -- Stay in this two-player room. A rematch is explicitly requested.
                        if meta(l).burglar_replay~=x.run then l:set_metadata({burglar_replay=x.run}) end
                    elseif l.code==b.hub then
                        if T.committing~=x.run then
                            T.committing=x.run;local nb=clone(b);nb.wins[n]=x.winner
                            if n==1 then nb.phase='reunion' elseif n==3 then nb.phase='complete' end
                            if nb.wins[1] and nb.wins[2] and n~=3 then nb.phase='final' end
                            -- Only advertise the finished room, never the active semifinal.
                            put(l,nb,{spectatable=nb.phase=='reunion'})
                        end
                    elseif n==2 and meta(l).burglar_pair_done~=x.run then l:set_metadata({burglar_pair_done=x.run}) end
                end
            end
        end
        return true
    end
    -- Never join/create before the preceding leave RPC has released our seat.
    local function move(l,destination,s)
        if T.travel then return end
        s.destination=destination;save(s);T.travel={old=l,to=destination}
        if G.OVERLAY_MENU and G.FUNCS.exit_overlay_menu then G.FUNCS.exit_overlay_menu() end
        if l then l:leave() end
    end
    -- Search one exact public match label. This reads occupancy without joining
    -- an active game. The server also rejects joins while game.started is set.
    local function room_ready(target,reunion,callback)
        local conn=MPAPI.get_connection();local client=conn and conn.nakama_client
        if not (client and client.list_matches) then T.note='Room discovery is unavailable. Reconnect to Multiplayer.';return end
        local q='+label.code:'..target..' +label.modId:MultiplayerPvP +label.started:F'
        if reunion then q=q..' +label.spectatable:T' end
        client.list_matches(1,true,nil,nil,nil,q,function(data)
            if type(data)~='table' or data.error then return end
            for _,m in ipairs(data.matches or {}) do
                local ok,label=pcall(MPAPI.json_decode,m.label or '')
                if ok and type(label)=='table' and label.code==target and label.modId=='MultiplayerPvP'
                    and label.started==false and (label.size or 0)>0 and label.open==true
                    and (not reunion or label.spectatable==true) then callback() end
            end
        end)
    end
    local function match_for(s,l)
        if not (private(l) and s and s.match and l.player_id==s.me and s.match.room==l.code) then return end
        return s.match
    end
    function T.block_start(l)
        local s=state();local b=T.board(l);local m=match_for(s,l)
        if not (b or meta(l).burglar_round) then return false end
        if not m or s.result then return true end
        if b and (b.phase~='semis' and b.phase~='final') then return true end
        local t=K.ticket
        return not (#l:get_players()==2 and present(l,m.a) and present(l,m.b)
            and meta(l).burglar_round==s.event..':'..m.stage and K.enabled and K.lobby==l and t
            and t.event==s.ticket.event and t.seat==s.ticket.seat and t.copy_limits==s.ticket.copy_limits
            and table.concat(t.keys,'|')==table.concat(s.ticket.keys,'|') and K.ready())
    end
    function T.started(l,p)
        local s=state();local run=(p and p.run_id) or (l and l._game and l._game.started and l._game.started.run_id)
        if match_for(s,l) and K.in_run() and run then s.run=run;s.result=nil;save(s) end
    end
    function T.ended(l,r)
        local s=state();local m=match_for(s,l)
        if not (m and s.run and type(r)=='table' and r.run_id==s.run) or s.result then return end
        local ranks={};for _,v in ipairs(type(r.placements)=='table' and r.placements or {}) do
            if type(v)=='table' and (v.playerId==m.a or v.playerId==m.b) then ranks[v.playerId]=v.place end end
        local winner=false
        if r.status=='agreed' and #r.placements==2 then
            if ranks[m.a]==1 and ranks[m.b]==2 then winner=m.a elseif ranks[m.b]==1 and ranks[m.a]==2 then winner=m.b end
        end
        s.result={room=l.code,stage=m.stage,run=s.run,winner=winner};save(s)
    end
    local function prepare(l,s,b,n)
        local a,c=pair(b,n);if s.me~=a and s.me~=c then return end
        local room=n==2 and b.room or b.hub
        if not s.match or s.match.stage~=n or s.match.room~=room then
            s.match={stage=n,room=room,a=a,b=c};s.run=nil;s.result=nil;save(s)
        end
        if l:is_game_started() or s.result or #l:get_players()~=2 or not present(l,a) or not present(l,c) then return end
        local mark=s.event..':'..n
        if meta(l).burglar_round~=mark or meta(l).queue_mode~='pvp_nemesis' then
            if l.is_host then local opts=clone(b.opts);opts.burglar_round=mark;opts.spectatable=false;l:set_metadata(opts) end
            return
        end
        if not K.enabled then K.enable(s.ticket) end
    end
    function T.tick()
        if T.next and now()<T.next then return end;T.next=now()+1
        local l=lobby();local s=state()
        if T.travel then
            local t=T.travel;if l==t.old and l and not l._destroyed then return end
            T.travel=nil
            if not l or l._destroyed then
                if t.to=='allocate' then
                    T.allocating=true
                    MPAPI.networking.nakama_lobby.create(PVP.id,2,function(err,data)
                        T.allocating=nil
                        if state()~=s or lobby() then return end
                        s.reserved=not err and data and code(data.code) and data.code or nil
                        s.reserve_error=not s.reserved and tostring(err or 'Invalid room code') or nil
                        s.destination=s.hub;save(s);PVP.pvp_join_lobby(s.hub)
                    end)
                elseif t.to then PVP.pvp_join_lobby(t.to) end
            end
            return
        end
        local b=T.board(l)
        if b then
            if b.phase=='complete' and not s then return end
            sync(l,b);local ok,record=pcall(capture,l,b)
            if not ok or not record then T.note='Could not load the original draft roster.';return end
            s=record
            if b.phase=='complete' then if not l:is_game_started() and G.STAGE~=G.STAGES.RUN then
                if l.is_host and meta(l).burglar_round then l:set_metadata({burglar_round=false,draftout_bracket=false}) end
                save(false)
            end;return end
            if not l:is_game_started() and G.STAGE~=G.STAGES.RUN then send(l,b,s) end
            if b.phase=='setup' then
                if l.is_host then
                    local ready=true;for _,id in ipairs(b.ids) do if not present(l,id) or not T.acks[id] then ready=false end end
                    if ready then local n=clone(b);n.phase='allocating';put(l,n) end
                end
            elseif b.phase=='allocating' then
                if s.me==b.ids[3] and not s.reserved and not s.reserve_error then move(l,'allocate',s) end
            elseif b.phase=='semis' or b.phase=='reunion' then
                if (s.me==b.ids[3] or s.me==b.ids[4]) and not s.result then
                    if s.me==b.ids[3] then move(l,b.room,s)
                    elseif not T.probe or now()>T.probe then
                        T.probe=now()+5;room_ready(b.room,false,function()
                            if lobby()==l and state()==s and not l:is_game_started() then move(l,b.room,s) end
                        end)
                    end
                elseif not b.wins[1] then prepare(l,s,b,1) end
            elseif b.phase=='final' then
                local a,c=pair(b,3)
                if s.me~=a and s.me~=c then
                    if not l:is_game_started() and G.STAGE~=G.STAGES.RUN then
                        T.note='Tournament finished for you. The finalists keep their original pools.';save(false);l:leave()
                    end
                else prepare(l,s,b,3) end
            end
        elseif private(l) and s and valid(s.board) and l.code==s.board.room then
            b=s.board
            if s.result then
                if not l:is_game_started() and G.STAGE~=G.STAGES.RUN then
                    send(l,b,s)
                    if meta(l).burglar_pair_done==s.result.run and (not T.probe or now()>T.probe) then
                        T.probe=now()+5;room_ready(s.hub,true,function()
                            if lobby()==l and state()==s and s.result and not l:is_game_started() then move(l,s.hub,s) end
                        end)
                    end
                end
            else prepare(l,s,b,2) end
        end
    end
    function T.screen(b)
        local nodes={U.line('BURGLAR / TOURNAMENT',0.38),U.line('Semifinals run in parallel. Four lives per match.',0.24)}
        local function name(id) return b.names[seat(b,id) or 0] or '?' end
        for n=1,3 do local a,c=pair(b,n)
            nodes[#nodes+1]=U.line((n==3 and 'Final' or 'Semifinal '..n)..': '..(a and name(a) or 'Winner of semi 1')..' vs '..(c and name(c) or 'Winner of semi 2'),0.28)
            if b.wins[n] then nodes[#nodes+1]=U.line('Winner: '..name(b.wins[n]),0.25) end
        end
        nodes[#nodes+1]=U.line(b.phase=='complete' and 'Champion: '..name(b.wins[3])
            or b.phase=='reunion' and 'Waiting for the other semifinal to finish and return.'
            or b.phase=='semis' and 'Ready up in your 1v1 lobby. Return to lobby after the match.'
            or b.phase=='final' and 'Finalists: ready up for a fresh run.' or 'Preparing the two match rooms...',0.24)
        if T.note then nodes[#nodes+1]=U.line(T.note,0.22) end
        local l=lobby()
        if l and l.is_host and b.phase=='allocating' and T.note then nodes[#nodes+1]=U.row({U.button('Retry room setup','burglar_tourney_next',nil,4)}) end
        if l and meta(l).burglar_replay then nodes[#nodes+1]=U.row({U.button('Replay drawn match','burglar_tourney_reset',nil,4)}) end
        return {n=G.UIT.C,config={align='cm',padding=0.06},nodes=nodes}
    end
    local function action(fn) return function()
        local ok,err=pcall(fn);if not ok then T.note=tostring(err):gsub('^.-:%d+: ','') end
        D.mode='mp';U.show()
    end end
    G.FUNCS.burglar_tourney_format=action(function()
        local l=lobby();assert(private(l) and B.is_target(l) and l.is_host and not l:is_game_started() and not T.board(l) and not B.host_state and not B.pool,'Choose the format before drafting')
        l:set_metadata({burglar_format=T.requested(l) and 'standard' or 'tournament'})
    end)
    G.FUNCS.burglar_tourney_begin=action(T.begin)
    G.FUNCS.burglar_tourney_next=action(function()
        local l=lobby();local b=T.board(l);assert(b and l.is_host and b.phase=='allocating' and #l:get_players()==4,'Wait for all four players')
        local n=clone(b);n.phase='setup';n.event=MPAPI.generate_id();T.note=nil;put(l,n)
    end)
    G.FUNCS.burglar_tourney_reset=action(function()
        local l=lobby();local s=state();assert(match_for(s,l) and not l:is_game_started() and s.result and s.result.winner==false and meta(l).burglar_replay==s.result.run,'No agreed draw to replay')
        s.result=nil;s.run=nil;save(s);T.reports={};K.enabled=nil
    end)
    G.FUNCS.burglar_tourney_home=action(function()
        local s=state();assert(s and (not lobby() or not lobby():is_game_started()),'Finish the match first')
        if s.result then T.note='Return to lobby on the results screen; the bracket reconnects automatically.'
        elseif not lobby() then PVP.pvp_join_lobby(s.destination=='allocate' and s.hub or s.destination or s.hub) end
    end)
    G.FUNCS.burglar_tourney_rejoin=G.FUNCS.burglar_tourney_home
    return T
end

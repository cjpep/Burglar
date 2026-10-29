-- Experimental delayed board viewer. Uses the existing directed MPAPI action,
-- but NEVER the replay driver or the native run loader. The host referee and
-- eliminated player's G.GAME remain in place for the entire viewing session.
return function(D)
    local W=assert(SMODS.load_file('burglar/spectator_wire.lua',D.mod.id))()
    local C=assert(SMODS.load_file('burglar/spectator_capture.lua',D.mod.id))()(W)
    local S={wire=W,capture=C,subscribers={},serial=0,status='Choose a remaining player.'}
    D.spectator=S
    local function now() return D.now and D.now() or love.timer.getTime() end
    local function current() return MPAPI and MPAPI.get_current_lobby and MPAPI.get_current_lobby() end
    function S.context()
        local B,M=D.mpbridge,D.average_pvp
        local l=current()
        if D.mod.config.spectator_enabled==false or not (B and M and l and B.started
            and B.lobby==l and M.active() and B.session and M.run and l:is_game_started())
            or (M.rounds and M.rounds.finished) then return end
        return {lobby=l,session=B.session,room=B.room,run=M.run,ids=B.ids}
    end
    local function member(ctx,id)
        for _,v in ipairs(ctx.ids or {}) do if v==id then return true end end
        return false
    end
    local function connected(ctx,id)
        if not member(ctx,id) then return false end
        for _,p in ipairs(ctx.lobby:get_players()) do
            if p.id==id then return not p.is_away and not p.is_spectator and p.role~='spectator' end
        end
        return false
    end
    function S.lives(ctx,id)
        if ctx.lobby.is_host then
            local p=PVP.REF and PVP.REF.players and PVP.REF.players[id]
            if p and type(p.lives)=='number' then return p.lives end
        end
        if id==ctx.lobby.player_id and PVP.GAME and type(PVP.GAME.lives)=='number' then return PVP.GAME.lives end
        local value=PVP._player_lives_cache and PVP._player_lives_cache[id]
        if type(value)=='number' then return value end
        -- Unknown is deliberately not treated as eliminated.
    end
    function S.allowed(ctx,viewer,target)
        if viewer==target or not connected(ctx,viewer) or not connected(ctx,target) then return false end
        local v,t=S.lives(ctx,viewer),S.lives(ctx,target)
        return v~=nil and v<=0 and t~=nil and t>0
    end
    function S.can_watch()
        local ctx=S.context()
        if not ctx or not (PVP.GAME and PVP.GAME.eliminated) then return false end
        for _,id in ipairs(ctx.ids or {}) do
            if S.allowed(ctx,ctx.lobby.player_id,id) then return true end
        end
        return false
    end
    function S.players()
        local ctx=S.context();local out={}
        if not ctx then return out end
        for _,p in ipairs(ctx.lobby:get_players()) do
            if S.allowed(ctx,ctx.lobby.player_id,p.id) then
                out[#out+1]={id=p.id,name=C.text(p.displayName or 'Player',40)}
            end
        end
        table.sort(out,function(a,b) return a.id<b.id end)
        return out
    end
    local function same(a,b)
        return a and b and a.lobby==b.lobby and a.session==b.session and a.run==b.run
    end
    local function send(ctx,id,data)
        local B=D.mpbridge
        if not (same(ctx,S.context()) and B.transport and B.transport.ready) then return false end
        data.run=ctx.run
        local packet={protocol=4,kind='spectator_v2',session=ctx.session,room=ctx.room,recipient=id,data=data}
        -- No per-frame response callback: MPAPI retains pending callbacks until
        -- an ACK arrives. Missing frame ACKs must not accumulate over a long
        -- match. Complete snapshots + renewable leases provide recovery.
        local ok,result=pcall(function()
            return ctx.lobby:action(B.transport.action):callback(nil):send(id,{packet=packet})
        end)
        if (not ok or result~=true) and S.target==id and data.token==S.token then
            S.status='Spectator connection interrupted; retrying.'
        end
        return ok and result==true
    end
    function S.stop_view()
        if S.ctx and S.target and S.token then send(S.ctx,S.target,{op='stop',token=S.token}) end
        S.target,S.token,S.receiver,S.frame,S.demo,S.last_request=nil,nil,nil,nil,nil,nil
    end
    function S.select(id)
        local ctx=S.context()
        if not ctx or not S.can_watch() or not S.allowed(ctx,ctx.lobby.player_id,id) then return false end
        S.stop_view();S.ctx=ctx;S.serial=S.serial+1
        S.target,S.token=id,tostring(now())..':'..S.serial
        S.receiver=W.receiver();S.last_request=now();S.selected_at=now()
        S.status='Waiting for their next shop or blind-selection screen...'
        send(ctx,id,{op='watch',token=S.token})
        return true
    end
    local function receive(from,packet)
        local ctx=S.context()
        if not ctx or packet.protocol~=4 or packet.session~=ctx.session or packet.room~=ctx.room
            or packet.recipient~=ctx.lobby.player_id or type(packet.data)~='table' then return end
        local p=packet.data
        if p.run~=ctx.run or type(p.token)~='string' or #p.token>80 then return end
        if not same(S.ctx,ctx) then
            S.stop_view();S.subscribers={};S.ctx=ctx
        end
        if p.op=='watch' then
            if not S.allowed(ctx,from,ctx.lobby.player_id) then return end
            local sub=S.subscribers[from]
            if sub and sub.token~=p.token and now()-(sub.created or 0)<1 then return end
            if not sub or sub.token~=p.token then
                sub={token=p.token,seq=0,created=now(),ctx=ctx};S.subscribers[from]=sub
            end
            sub.expires=now()+W.LEASE
        elseif p.op=='stop' then
            local sub=S.subscribers[from]
            if sub and sub.token==p.token then S.subscribers[from]=nil end
        elseif p.op=='frame' and from==S.target and p.token==S.token and S.receiver
            and same(S.ctx,ctx) and S.can_watch() and S.allowed(ctx,ctx.lobby.player_id,from) then
            if W.accept(S.receiver,p,now(),MPAPI.json_decode) then
                if not S.frame then S.status='Buffering the delayed view...' end
            end
        end
    end
    function S.receive(from,packet)
        if type(packet)~='table' or packet.kind~='spectator_v2' then return false end
        local ok=pcall(receive,from,packet)
        if not ok then S.last_error='Invalid spectator message ignored.' end
        return true
    end
    function S.event(lobby,kind)
        if S.ctx and S.ctx.lobby==lobby and (kind=='game_ended' or kind=='lobby_closed' or kind=='disconnected') then
            S.stop_view();S.ctx=nil;S.subscribers={}
            S.status=kind=='game_ended' and 'Match finished.' or 'Spectator connection ended.'
            if S.refresh then S.refresh() end
        end
    end
    local function publish(ctx)
        local viewers={}
        for id,sub in pairs(S.subscribers) do
            if not same(ctx,sub.ctx) or sub.expires<now() or not S.allowed(ctx,id,ctx.lobby.player_id) then
                S.subscribers[id]=nil
            else
                if not sub.ready and C.checkpoint() then sub.ready=true end
                if sub.ready then viewers[#viewers+1]={id=id,sub=sub} end
            end
        end
        if #viewers==0 then return end
        local frame=C.capture()
        if not frame then return end
        local encoded=MPAPI.json_encode(frame)
        local parts=W.split(encoded)
        if not parts then return end
        for _,v in ipairs(viewers) do
            if (v.sub.last_text~=encoded or now()-(v.sub.last_sent or 0)>=2)
                and now()-(v.sub.last_sent or -100)>= (#parts>4 and 1 or W.INTERVAL) then
            v.sub.last_text,v.sub.last_sent=encoded,now()
            v.sub.seq=v.sub.seq+1
            for index,text in ipairs(parts) do
                send(ctx,v.id,{op='frame',token=v.sub.token,seq=v.sub.seq,part=index,parts=#parts,text=text})
            end
            end
        end
    end
    function S.tick()
        if S.demo then
            if current() then S.stop_view();S.status='Local preview closed: joined a lobby.';return end
            if S.demo_tick then S.demo_tick() end
            return
        end
        local ctx=S.context()
        if not same(S.ctx,ctx) then
            if S.ctx or next(S.subscribers) then
                S.stop_view();S.subscribers={};S.status='Match or lobby changed. Watching stopped.'
                if S.refresh then S.refresh() end
            end
            S.ctx=ctx
        end
        if not ctx then return end
        if not S.last_publish or now()-S.last_publish>=W.INTERVAL then
            S.last_publish=now()
            local ok=pcall(publish,ctx)
            if not ok then S.last_error='Board update skipped.' end
        end
        if S.target then
            if not S.can_watch() or not S.allowed(ctx,ctx.lobby.player_id,S.target) then
                S.stop_view();S.status='That player is out or disconnected. Choose another player.'
                if S.refresh then S.refresh() end
                return
            end
            if now()-(S.last_request or 0)>=4 then
                S.last_request=now();send(ctx,S.target,{op='watch',token=S.token})
            end
            W.expire(S.receiver,now())
            local f=W.due(S.receiver,now())
            if f then S.frame=f;S.status='Delayed live board - at least 5 seconds behind.';if S.refresh then S.refresh() end end
            if now()-(S.receiver.received or S.selected_at)>12 then
                S.status='No recent board update. Waiting for checkpoint or connection.'
            end
        end
        if S.open and S.overlay and G.OVERLAY_MENU~=S.overlay then
            S.open=false;S.stop_view()
        end
    end
    if MPAPI and MPAPI.on_loaded then
        MPAPI.on_loaded(function()
            if not (PVP and type(PVP.end_screen_buttons)=='function') then return end
            local original=PVP.end_screen_buttons
            PVP.end_screen_buttons=function(...)
                local buttons=original(...)
                if S.can_watch() then
                    table.insert(buttons,1,UIBox_button({button='draftout_spectate_open',
                        label={'Watch remaining players'},colour={0.24,0.42,0.46,1},
                        minw=3.8,maxw=3.8,minh=0.65,scale=0.28}))
                end
                return buttons
            end
        end)
    end
    assert(SMODS.load_file('burglar/spectator_ui.lua',D.mod.id))()(D,S)
    if D.updates then D.updates.add('spectator',function()
        local ok=pcall(S.tick)
        if not ok then S.subscribers={};S.stop_view();S.status='Spectator stopped after a display error.' end
        local down=love.keyboard and love.keyboard.isDown('f9') or false
        if down and not S.key_down and S.can_watch() then G.FUNCS.draftout_spectate_open() end
        S.key_down=down
    end) end
    return S
end

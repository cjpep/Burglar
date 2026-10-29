-- Scoped recovery for the pinned PvP referee. One metadata write contains both
-- native score records and Draftout's lifecycle/outbox; never rebuild lives
-- from a guest's incomplete local referee. Other modes retain upstream behavior.
return function(D,M,R)
    local H={depth=0,pending={},last_events={},serial=0,authority=0,journal={}}
    R.handover=H
    local copy=D.core.copy
    local function lobby() return MPAPI.get_current_lobby() end
    local function active() return M.active() and not H.blocked end
    local function integer(v,lo,hi) return type(v)=='number' and v==math.floor(v) and v>=lo and v<=hi end
    local function int_out(v) return {v.coeffiocient or 0,v.exponent or 0,v.e_count or 0} end
    local function int_in(v)
        assert(type(v)=='table' and #v==3,'Invalid recovery score')
        for i=1,3 do assert(type(v[i])=='number' and v[i]==v[i] and math.abs(v[i])<math.huge,'Invalid recovery score') end
        return PVP.INSANE_INT.create(v[1],v[2],v[3])
    end
    function H.reset()
        H.depth,H.pending,H.last_events,H.serial,H.authority,H.journal=0,{},{},0,0,{}
        H.blocked,H.encoded,H.resend_due,H.owner=nil,nil,nil,lobby().host_id
        H.departed={}
    end
    local function snapshot()
        local players={}
        for id,p in pairs(PVP.REF.players) do
            players[id]={score=int_out(p.score),highest=int_out(p.highest_score),hands=p.hands_left,
                lives=p.lives,skips=p.skips,ante=p.ante,furthest=p.furthest_blind,
                played=p.played_this_blind and 1 or 0,ready=p.is_ready and 1 or 0,
                first=p.first_ready and 1 or 0,blocker=p.lives_blocker and 1 or 0,team=p.team_id,
                tracked_ready=PVP.REF.ready_tracker and PVP.REF.ready_tracker:is_ready(id) and 1 or 0}
        end
        local ref=PVP.REF
        local ctx=D.recap.context
        if ctx and ctx.payload and not ctx.recovery then ctx.recovery=D.recap.pack(ctx.payload,ctx.catalog) end
        return {v=1,tag=lobby()._game and lobby()._game.started and lobby()._game.started.run_id,
            players=players,nemesis_of=copy(ref.nemesis_of or {}),used_pairs=copy(ref.used_pairs or {}),
            nemesis_ante=ref.nemesis_ante_computed_for or 0,last_bye=ref.last_bye_id,
            team_lives=copy(ref.team_lives or {}),team_card_target=copy(ref.team_card_target or {}),
            team_card_ante=ref.team_card_ante_computed_for or 0,eliminated=copy(ref.eliminated or {}),
            draftout={v=1,session=M.session,run=M.run,owner=H.owner,authority=H.authority,
                ids=copy(R.ids),departed=copy(H.departed),ready=copy(R.ready),failed=copy(R.failed),sequences=copy(R.sequences),
                ready_serial=R.ready_serial,duel=R.duel,open=R.open,finished=R.finished,
                ante=R.ante,settled=R.settled,start_event=copy(R.start_event),serial=H.serial,events=copy(H.last_events),revision=M.revision,
                -- Recovery peers can inspect this metadata with code; the recap UI
                -- and normal recap packets remain gated on the local GAME_ENDED.
                recap=ctx and ctx.recovery and copy(ctx.recovery) or nil}}
    end
    function H.commit()
        if not active() or not lobby().is_host or H.depth>0 or not next(PVP.REF.players or {}) then return end
        if #H.pending>0 then H.last_events=copy(H.pending) end
        local snap=snapshot()
        local encoded=MPAPI.json_encode(snap)
        if encoded~=H.encoded then
            -- Same ordered connection as the subsequent actions: recovery state
            -- reaches the server before any outcome it may need to retransmit.
            lobby():set_metadata({[PVP.REF_CHECKPOINT_KEY or '_pvp_ref']=snap})
            H.encoded=encoded
        end
        local events=H.pending;H.pending={}
        for _,entry in ipairs(events) do H.deliver(entry) end
    end
    function H.deliver(entry)
        local action=assert(MPAPI.ActionTypes[entry.key])
        R.event_id=entry.id
        local ok,err=pcall(function() lobby():action(action):broadcast(copy(entry.data)) end)
        R.event_id=nil
        if not ok then error(err) end
    end
    function H.emit(key,data)
        -- Targets are display-only and can be recomputed after recovery.
        if key=='pvp_royale_target' then return lobby():action(MPAPI.ActionTypes[key]):broadcast(data) end
        H.serial=H.serial+1
        H.pending[#H.pending+1]={id=H.serial,key=key,data=copy(data)}
        local entry=H.pending[#H.pending]
        if H.depth==0 then H.commit() end
        return entry
    end
    function H.transaction(fn,...)
        H.depth=H.depth+1
        local ok,result=pcall(fn,...)
        H.depth=H.depth-1
        if not ok then error(result) end
        if H.depth==0 then H.commit() end
        return result
    end
    function H.record(key,params)
        if not H.resending then H.journal[params._draftout.seq]={key=key,data=copy(params)} end
    end
    function H.observe()
        if not M.active() then return end
        local snap=(lobby():get_metadata() or {})[PVP.REF_CHECKPOINT_KEY or '_pvp_ref']
        local s=type(snap)=='table' and snap.draftout
        if type(s)~='table' or s.run~=M.run or s.session~=M.session or type(s.sequences)~='table' then return end
        local ack=s.sequences[lobby().player_id] or 0
        if type(ack)~='number' then return end
        for seq in pairs(H.journal) do if seq<=ack then H.journal[seq]=nil end end
    end
    local function restore(snap,old)
        local s=type(snap)=='table' and snap.draftout
        assert(type(s)=='table' and s.v==1 and s.session==M.session and s.run==M.run
            and (s.owner==old or H.departed[s.owner]),
            'No matching Draftout recovery checkpoint')
        assert(type(s.ids)=='table' and table.concat(s.ids,'|')==table.concat(R.ids,'|'),'Recovery roster mismatch')
        assert(integer(s.authority,0,1000) and integer(s.serial,0,9007199254740991)
            and integer(s.settled,1,1000000) and integer(s.ready_serial,0,9007199254740991)
            and type(s.ready)=='table' and type(s.failed)=='table' and type(s.sequences)=='table'
            and type(s.open)=='boolean' and type(s.finished)=='boolean' and type(s.duel)=='boolean'
            and (not s.open or integer(s.ante,2,1000000)),'Invalid recovery lifecycle')
        local ctx=D.recap.context
        assert(ctx,'Missing recovery recap context')
        local recap=D.recap.unpack(s.recap,ctx)
        local players,tracker={},MPAPI.ReadyTracker()
        for _,id in ipairs(R.ids) do
            local p=type(snap.players)=='table' and snap.players[id]
            assert(type(p)=='table' and integer(p.lives,0,4) and integer(p.hands,0,100)
                and integer(p.ante,0,1000000),'Invalid recovery player')
            players[id]={id=id,score=int_in(p.score),highest_score=int_in(p.highest),hands_left=p.hands,
                lives=p.lives,skips=p.skips,ante=p.ante,furthest_blind=p.furthest,team_id=p.team,
                played_this_blind=p.played==1,is_ready=p.ready==1,first_ready=p.first==1,lives_blocker=p.blocker==1}
            if p.tracked_ready==1 then tracker:set(id,true) end
        end
        assert(type(s.events)=='table' and #s.events<=20,'Invalid recovery outbox')
        for _,entry in ipairs(s.events) do
            assert(type(entry)=='table' and R.outcomes[entry.key] and integer(entry.id,1,s.serial)
                and type(entry.data)=='table','Invalid recovery outcome')
        end
        local start=s.start_event
        assert(start==nil or (type(start)=='table' and start.key=='pvp_start_blind'
            and integer(start.id,1,s.serial) and type(start.data)=='table'),'Invalid recovery start event')
        R.start_event=copy(start)
        PVP.REF.players,PVP.REF.ready_tracker=players,tracker
        for key,source in pairs({nemesis_of='nemesis_of',used_pairs='used_pairs',team_lives='team_lives',
            team_card_target='team_card_target',eliminated='eliminated'}) do PVP.REF[key]=copy(snap[source] or {}) end
        PVP.REF.nemesis_ante_computed_for,PVP.REF.last_bye_id=snap.nemesis_ante,snap.last_bye
        PVP.REF.team_card_ante_computed_for,PVP.REF.first_ready_at=snap.team_card_ante,nil
        R.ready,R.failed,R.sequences=copy(s.ready),copy(s.failed),copy(s.sequences)
        R.ready_serial,R.duel,R.open,R.finished,R.ante,R.settled=s.ready_serial,s.duel,s.open,s.finished,s.ante,s.settled
        H.serial,H.authority,H.last_events=s.serial,math.max(H.authority,s.authority)+1,copy(s.events)
        for id in pairs(s.departed or {}) do if R.members[id] then H.departed[id]=true end end
        M.revision=math.max(M.revision,s.revision or 0)
        ctx.payload,ctx.recovery=recap,copy(s.recap)
        return s.events
    end
    function H.change(id)
        if not M.active() or id~=lobby().host_id then return false end
        if H.owner==id then return not H.blocked end
        local old=H.owner
        H.departed[old]=true
        M.host=id;M.received=0
        D.mpbridge.owner=id
        if D.recap.context then D.recap.context.owner=id end
        if PVP._pvp_action_helpers then PVP._pvp_action_helpers.note_host(lobby(),id) end
        if lobby().is_host then
            local ok,events=pcall(restore,(lobby():get_metadata() or {})[PVP.REF_CHECKPOINT_KEY or '_pvp_ref'],old)
            if not ok then
                H.blocked=true;H.owner=id
                D.mpbridge.phase='error'
                D.message='Host handover paused: '..tostring(events):gsub('^.-:%d+: ','')
                D.mpbridge.message=D.message
                return false
            end
            H.owner=id;H.encoded=nil
            -- Replay committed outcomes with stable IDs before considering the
            -- departed host. Peers which saw them already ignore the duplicates.
            for _,entry in ipairs(events) do H.deliver(entry) end
            H.transaction(function()
                for _,pid in ipairs(R.ids) do if H.departed[pid] then PVP.referee_n_player_forfeit(pid) end end
                for _,pid in ipairs(R.ids) do H.emit('pvp_player_lives',{player_id=pid,lives=PVP.REF.players[pid].lives}) end
                R.try_start()
                R.resolve()
            end)
            if PVP.ensure_gamemode_instance then PVP.ensure_gamemode_instance(lobby()) end
        else H.owner=id;H.authority=H.authority+1 end
        H.resend_due=true
        D.mpbridge.message='Host transferred. The match continues.'
        return true
    end
    function H.tick()
        if not active() or not H.resend_due then return end
        H.resend_due=nil;H.observe()
        local ordered={};for seq in pairs(H.journal) do ordered[#ordered+1]=seq end;table.sort(ordered)
        H.resending=true
        local ok,err=pcall(function()
            for _,seq in ipairs(ordered) do
                local entry=H.journal[seq]
                if entry then lobby():action(MPAPI.ActionTypes[entry.key]):broadcast(copy(entry.data)) end
            end
        end)
        H.resending=nil
        if not ok then error(err) end
    end
    function H.install()
        local original=PVP.referee_checkpoint
        PVP.referee_checkpoint=function(...)
            if M.active() then return H.commit() end
            return original(...)
        end
        local take_over=PVP.referee_take_over
        PVP.referee_take_over=function(...)
            if M.active() then
                if H.owner~=lobby().host_id then H.change(lobby().host_id) end
                return not H.blocked and 'draftout' or nil
            end
            return take_over(...)
        end
    end
    return H
end

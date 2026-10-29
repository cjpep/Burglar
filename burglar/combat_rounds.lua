-- Burglar's scoped host round lifecycle. Retains native outcome handlers,
-- score parser, 1v1 resolver, timers, HUD and checkpoints. Other modes pass through.
return function(D,A,M)
    local R={}
    M.rounds=R
    local function lobby() return MPAPI.get_current_lobby() end
    local H=assert(SMODS.load_file('burglar/handover.lua',D.mod.id))()(D,M,R)
    local function host() return M.active() and not H.blocked and lobby().is_host end
    local function integer(n,lo,hi) return type(n)=='number' and n==math.floor(n) and n>=lo and n<=hi end
    local function emit(key,data)
        local l=lobby();local action=MPAPI.ActionTypes[key]
        if l and action then return H.emit(key,data or {}) end
    end
    function R.reset()
        R.ids=D.core.copy(D.mpbridge.ids or {})
        R.members={};for _,id in ipairs(R.ids) do R.members[id]=true end
        R.ready,R.failed,R.sequences,R.seen_outcomes={},{},{},{}
        R.ready_serial,R.duel,R.closed_ante=0,false,0
        R.open,R.finished,R.ante,R.settled,R.outgoing=false,false,nil,1,0
        R.pending_ready,R.start_event=nil,nil
        H.reset()
    end
    local function player(id)
        if not R.members or not R.members[id] then return end
        return PVP.REF.players[id]
    end
    local function present(id)
        for _,p in ipairs(lobby():get_players()) do if p.id==id then return true end end
        return false
    end
    local function alive()
        local out={}
        for _,id in ipairs(R.ids or {}) do
            local p=player(id)
            if p and p.lives>0 and present(id) then out[#out+1]=p end
        end
        return out
    end
    local function eligible(id)
        local p=player(id)
        return host() and not R.finished and p and p.lives>0 and present(id) and p
    end
    local function lose(p)
        if p.lives<=0 or p.lives_blocker then return end
        p.lives=p.lives-1;p.lives_blocker=true
        emit('pvp_player_lives',{player_id=p.id,lives=p.lives,lost=1})
    end
    local function survivors()
        local players=alive()
        if #players<=1 then
            R.finished,R.open=true,false
            emit('pvp_win',#players==1 and {winner_id=players[1].id} or {draw=true})
            return true
        end
        PVP.REF.eliminated=PVP.REF.eliminated or {}
        for _,id in ipairs(R.ids) do
            local p=player(id)
            if p and p.lives<=0 and not PVP.REF.eliminated[id] then
                PVP.REF.eliminated[id]=true;emit('pvp_eliminated',{player_id=id})
            end
        end
        return false
    end
    local function board(players)
        if #players==2 then
            R.duel=true
            -- Preserve the pinned PvP mod's pure 1v1 scoring/early-finish rule.
            local outcome=PVP.referee_resolve_2p_round(players[1],players[2])
            M.publish_duel(players,outcome~=nil)
            emit('pvp_royale_target',{targets={[players[1].id]=players[2].id,[players[2].id]=players[1].id}})
            return nil,outcome
        end
        local rank=A.rank(players)
        M.publish(rank)
        local targets={}
        for i,p in ipairs(rank.ranked) do
            local neighbor=rank.ranked[i+(rank.is_loser[p.id] and 1 or -1)]
                or (#rank.ranked>1 and rank.ranked[i%#rank.ranked+1])
            targets[p.id]=neighbor and neighbor.id or ''
        end
        emit('pvp_royale_target',{targets=targets})
        return rank
    end
    function R.resolve()
        if not R.open or R.finished then return end
        local players=alive()
        if #players<2 then survivors();return end
        if #players==2 then
            local _,outcome=board(players)
            if not outcome then return end
            R.open,R.settled,R.ready=false,R.ante,{}
            outcome.winner.first_ready,outcome.loser.first_ready=false,false
            if not outcome.equal then lose(outcome.loser) end
            if not survivors() then emit('pvp_end_pvp',{loser_id=not outcome.equal and outcome.loser.id or '',pvp_timer_lost=false}) end
            return
        end
        local finished=true
        for _,p in ipairs(players) do if p.hands_left>0 then finished=false end end
        local rank=board(players)
        if not finished then return end
        -- Close before sending any outcomes: loopback and duplicate reports cannot
        -- re-enter resolution, including after somebody sends newRound.
        R.open,R.settled,R.ready=false,R.ante,{}
        for _,p in ipairs(rank.losers) do lose(p) end
        if not survivors() then emit('pvp_end_pvp',{loser_id='',pvp_timer_lost=false}) end
    end
    function R.try_start()
        if R.open or R.finished then return end
        local players=alive();if #players<2 then return end
        local ante
        for _,p in ipairs(players) do
            local ready=R.ready[p.id]
            if not ready or ready.ante~=p.ante or ready.ante<=R.settled then return end
            if ante and ante~=ready.ante then return end
            ante=ready.ante
        end
        R.ante,R.open,R.duel=ante,true,#players==2
        local hands={}
        for _,p in ipairs(players) do
            p.starting_hands=R.ready[p.id].hands;hands[p.id]=p.starting_hands
            p.score=PVP.INSANE_INT.empty();p.hands_left=p.starting_hands
            p.played_this_blind,p.is_ready,p.first_ready,p.lives_blocker=false,false,false,false
        end
        local first_player=''
        if #players==2 then
            first_player=R.ready[players[1].id].order<R.ready[players[2].id].order and players[1].id or players[2].id
        end
        R.ready={}
        if PVP.REF.ready_tracker then PVP.REF.ready_tracker:reset() end
        R.start_event=emit('pvp_start_blind',{first_player=first_player,starting_hands=hands})
        board(players)
    end
    local function report_current(p,pvp)
        local tag=R.report
        if not tag then return true end -- Internal calls/tests still use the scoped guards.
        return tag.ante==(R.open and R.ante or p.ante) and (not pvp or tag.pvp)
    end
    local handlers={}
    function handlers.ready(id,hands)
        local p=eligible(id);if not p then return end
        if R.open then
            if R.report and R.report.ante==R.ante and R.start_event then
                H.deliver(R.start_event) -- Same event ID: peers which started ignore it.
            end
            return
        end
        local ante=R.report and R.report.ante or p.ante
        if not integer(ante,2,1000000) or ante<=R.settled then return end
        p.ante=math.max(p.ante,ante)
        hands=tonumber(hands) or 4;if not integer(hands,1,100) then return end
        local previous=R.ready[id]
        if not previous or previous.ante~=ante then R.ready_serial=R.ready_serial+1 end
        R.ready[id]={ante=ante,hands=hands,order=previous and previous.ante==ante and previous.order or R.ready_serial}
        PVP.REF.ready_tracker=PVP.REF.ready_tracker or MPAPI.ReadyTracker()
        PVP.REF.ready_tracker:set(id,true)
        R.try_start()
    end
    function handlers.unready(id)
        if not eligible(id) or R.open then return end
        R.ready[id]=nil
        if PVP.REF.ready_tracker then PVP.REF.ready_tracker:set(id,false) end
    end
    function handlers.play(id,params)
        local p=eligible(id)
        if not p or not R.open or p.hands_left<=0 or not report_current(p,true) or type(params)~='table' then return end
        local hands=tonumber(params.handsLeft)
        if not integer(hands,0,p.hands_left) then return end
        local raw=tostring(params.score or '0')
        if #raw>128 or not (raw:match('^%d+%.?%d*$') or raw:match('^%d+%.?%d*[eE][+-]?%d+$')) then return end
        local ok,score=pcall(function()
            local value=PVP.INSANE_INT.from_string(raw)
            A.rank({{id=id,score=value}}) -- Validate before mutating authoritative state.
            return value
        end)
        if not ok then return end
        p.score,p.hands_left=score,hands
        if params.skips then p.skips=tonumber(params.skips) or p.skips end
        p.played_this_blind=PVP.INSANE_INT.greater_than(score,PVP.INSANE_INT.empty())
        if PVP.INSANE_INT.greater_than(score,p.highest_score) then p.highest_score=score end
        R.resolve()
    end
    function handlers.ante(id,params)
        local p=eligible(id);local ante=type(params)=='table' and tonumber(params.ante)
        if not p or not integer(ante,0,1000000) then return end
        -- Native action_start_game reports zero before creating the Ante 1 run.
        -- That is a lobby/startup marker, not a playable ante. Keeping it in the
        -- referee made every ordinary Ante 1 failure fail report_current().
        if ante==0 and not R.ante then return end
        if ante<p.ante or (R.open and ante>R.ante) then return end
        if ante~=p.ante then R.ready[id]=nil end
        p.ante=ante
    end
    function handlers.new_round(id)
        local p=eligible(id);if not p or R.open then return end
        p.lives_blocker=false
    end
    function handlers.fail(id)
        local p=eligible(id);if not p or not report_current(p,false) then return end
        local tag=R.report
        if tag and tag.pvp then
            if not R.open then return end
            lose(p);p.hands_left=0;R.resolve();return
        end
        if R.open then return end
        local key=tag and (tag.ante..':'..tag.round..':'..tag.blind) or tostring(p.ante)
        if R.failed[id]==key then return end
        R.failed[id]=key;lose(p);survivors()
    end
    function handlers.timer(id)
        local p=eligible(id)
        if not p or not R.open or p.hands_left<=0 or not report_current(p,true) then return end
        p.hands_left=p.hands_left-1
        emit('pvp_timer_hand_lost',{player_id=id})
        R.resolve()
    end
    function handlers.forfeit(id)
        if not host() or not player(id) then return false end
        local p=player(id)
        if R.finished then return true end
        if p.lives<=0 then
            R.ready[id]=nil
            R.try_start()
            return true
        end
        p.lives,p.hands_left,p.lives_blocker=0,0,true
        R.ready[id]=nil;emit('pvp_player_lives',{player_id=id,lives=0})
        -- Departure changes who the readiness barrier is waiting for as well as
        -- who participates in an open round. Keep existing survivors' readiness.
        if not survivors() then R.try_start();R.resolve() end
        return true
    end
    local reports={pvp_ready_blind=true,pvp_unready_blind=true,pvp_play_hand=true,pvp_set_ante=true,
        pvp_new_round=true,pvp_fail_round=true,pvp_fail_timer=true,pvp_fail_pvp_timer=true,pvp_forfeit=true}
    local outcomes={pvp_start_blind=true,pvp_end_pvp=true,pvp_win=true,pvp_eliminated=true,pvp_player_lives=true,pvp_timer_hand_lost=true}
    R.outcomes=outcomes
    local function valid_tag(tag)
        return type(tag)=='table' and tag.session==M.session and tag.run==M.run
            and integer(tag.seq,1,9007199254740991) and integer(tag.ante,0,1000000)
            and integer(tag.round,0,1000000) and type(tag.blind)=='string' and #tag.blind<100 and type(tag.pvp)=='boolean'
    end
    local function trace(event,key,from,tag,reason,params)
        if not (D.diag and D.diagnostics) then return end
        tag=type(tag)=='table' and tag or {}
        params=type(params)=='table' and params or {}
        D.diag(event,{kind=key,peer=D.diagnostics.seat(from),seat=D.diagnostics.seat(params.player_id),
            ante=tag.ante,round=tag.round,seq=tag.seq,event=tag.event,authority=tag.authority,
            lives=params.lives,reason=reason})
    end
    function R.retry_ready()
        local pending=R.pending_ready
        if not pending then return end
        local g=G.GAME or {}
        if not M.active() or R.finished or PVP.GAME.eliminated or not PVP.GAME.ready_blind
            or not g.round_resets or g.round_resets.ante~=pending.ante then
            R.pending_ready=nil;return
        end
        if H.blocked or love.timer.getTime()<pending.next_retry then return end
        pending.next_retry=love.timer.getTime()+2
        lobby():action(MPAPI.ActionTypes.pvp_ready_blind):broadcast({starting_hands=pending.hands})
    end
    function R.install()
        local mapping={referee_on_ready_blind='ready',referee_on_unready_blind='unready',referee_on_play_hand='play',
            referee_on_set_ante='ante',referee_on_new_round='new_round',referee_on_fail_round='fail',
            referee_on_fail_timer='fail',referee_on_fail_pvp_timer='timer',referee_n_player_forfeit='forfeit'}
        for key in pairs(mapping) do assert(type(PVP[key])=='function','PvP lifecycle contract missing: '..key) end
        for key in pairs(reports) do assert(MPAPI.ActionTypes[key],'PvP report action missing: '..key) end
        for key in pairs(outcomes) do assert(MPAPI.ActionTypes[key],'PvP outcome action missing: '..key) end
        assert(type(PVP.referee_resolve_2p_round)=='function','Native PvP 1v1 resolver missing')
        local create=assert(MPAPI._internal.create_action_instance)
        for key,handler in pairs(mapping) do
            local original=PVP[key]
            PVP[key]=function(...)
                if not M.active() then return original(...) end
                return H.transaction(handlers[handler],...)
            end
        end
        H.install()
        local reconnect=PVP.referee_on_player_reconnected
        PVP.referee_on_player_reconnected=function(id,...)
            if M.active() then R.ready[id]=nil end
            return reconnect(id,...)
        end
        -- Add epochs on the existing API actions, preserving the native net router,
        -- score relay and replay logging. No upstream files are changed.
        MPAPI._internal.create_action_instance=function(l,action)
            local instance=create(l,action)
            if reports[action.key] or outcomes[action.key] then
                for _,method in ipairs({'send','broadcast'}) do
                    local operation=method
                    local original=instance[operation]
                    instance[operation]=function(self,first,second)
                        if not M.active() or l~=M.lobby then return original(self,first,second) end
                        local params=operation=='send' and second or first
                        if outcomes[action.key] and not R.event_id then return H.emit(action.key,params or {}) end
                        local copy={};for k,v in pairs(params or {}) do copy[k]=v end
                        local g=G.GAME or {};local blind=g.blind and g.blind.config and g.blind.config.blind
                        if not (reports[action.key] and H.resending) then
                          R.outgoing=R.outgoing+1
                          copy._draftout={session=M.session,run=M.run,seq=R.outgoing,
                            ante=outcomes[action.key] and (R.ante or 0) or (g.round_resets and g.round_resets.ante or 0),
                            round=g.round or 0,blind=blind and blind.key or tostring(g.blind_on_deck or ''),pvp=not not PVP.is_pvp_boss(),
                            duel=outcomes[action.key] and R.duel or not not M.duel,event=R.event_id,authority=H.authority}
                        end
                        if not H.resending then
                            if action.key=='pvp_ready_blind' then
                                R.pending_ready={ante=copy._draftout.ante,hands=copy.starting_hands,
                                    next_retry=love.timer.getTime()+2}
                            elseif action.key=='pvp_unready_blind' then R.pending_ready=nil end
                        end
                        if reports[action.key] then H.record(action.key,copy) end
                        if operation=='send' then return original(self,first,copy) end
                        return original(self,copy)
                    end
                end
            end
            return instance
        end
        for key in pairs(reports) do
            local action=MPAPI.ActionTypes[key];local original=action.on_receive
            action.on_receive=function(at,from,params)
                local tag=type(params)=='table' and params._draftout
                if not M.active() then if tag then return end;return original(at,from,params) end
                if not lobby().is_host then return original(at,from,params) end
                if H.blocked then trace('report_reject',key,from,tag,'blocked');return end
                if not R.members[from] or not valid_tag(tag) then trace('report_reject',key,from,tag,'invalid');return end
                if tag.seq<=(R.sequences[from] or 0) then trace('report_reject',key,from,tag,'duplicate');return end
                local p=player(from)
                if p and tag.ante<p.ante and key~='pvp_set_ante' then trace('report_reject',key,from,tag,'stale');return end
                R.sequences[from]=tag.seq
                trace('report_accept',key,from,tag)
                local previous=R.report;R.report=tag
                local ok,result=pcall(original,at,from,params);R.report=previous
                if not ok then error(result) end
                return result
            end
        end
        for key in pairs(outcomes) do
            local action=MPAPI.ActionTypes[key];local original=action.on_receive
            action.on_receive=function(at,from,params)
                local tag=type(params)=='table' and params._draftout
                if not M.active() then if tag then return end;return original(at,from,params) end
                if from~=M.host or not valid_tag(tag) or tag.authority~=H.authority
                    or not integer(tag.event,1,9007199254740991) then trace('outcome_reject',key,from,tag,'invalid');return end
                local token=key..':'..tostring(params.player_id or '')
                if tag.event<=(R.seen_outcomes[token] or 0) then trace('outcome_reject',key,from,tag,'duplicate');return end
                local ante=G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
                if (key=='pvp_start_blind' or key=='pvp_end_pvp') and ante and tag.ante<ante then trace('outcome_reject',key,from,tag,'stale');return end
                if key=='pvp_start_blind' and (R.finished or tag.ante<=R.closed_ante) then trace('outcome_reject',key,from,tag,'closed');return end
                if key=='pvp_end_pvp' then R.closed_ante=math.max(R.closed_ante,tag.ante) end
                if key=='pvp_win' then R.finished=true end
                R.seen_outcomes[token]=tag.event
                trace('outcome_accept',key,from,tag,nil,params)
                if key=='pvp_start_blind' or key=='pvp_end_pvp' or key=='pvp_win'
                    or (key=='pvp_eliminated' and params.player_id==lobby().player_id) then R.pending_ready=nil end
                if key=='pvp_start_blind' and tag.duel==true then
                    M.enter_duel({mode='duel',count=2,finished=0,final=false,ante=tag.ante})
                end
                return original(at,from,params)
            end
        end
    end
    return R
end

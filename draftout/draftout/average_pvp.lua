-- Scoped adapter for the uploaded PvP 1.0.0 host referee and blind HUD.
return function(D,send)
    local A=assert(SMODS.load_file('draftout/average.lua',D.mod.id))()
    local M={ui={average='0',label='Average (live)',title='Draftout Average'}}
    D.average_pvp=M
    local rounds=assert(SMODS.load_file('draftout/combat_rounds.lua',D.mod.id))()(D,A,M)
    local function lobby() return MPAPI.get_current_lobby() end
    function M.active()
        local l=lobby()
        return M.lobby and M.lobby==l and M.session and not l._destroyed
            and (l:get_metadata() or {}).queue_mode=='pvp_royale'
    end
    function M.stop()
        if M.lobby==lobby() and M.saved then
            for key,entry in pairs(M.saved) do
                if PVP.LOBBY.config[key]==entry.applied then PVP.LOBBY.config[key]=entry.old end
            end
        end
        M.lobby,M.session,M.saved,M.view=nil,nil,nil,nil
    end
    function M.start(l,session,run)
        M.stop()
        M.lobby,M.session,M.host,M.revision,M.received=l,session,l.host_id,0,0
        M.run=run or session
        rounds.reset()
        M.saved={}
        for key,value in pairs({starting_lives=4,pvp_start_round=2,normal_bosses=false,
            death_on_round_loss=true,gamemode='gamemode_mp_attrition'}) do
            M.saved[key]={old=PVP.LOBBY.config[key],applied=value}
            PVP.LOBBY.config[key]=value
        end
        M.duel=#rounds.ids==2
        M.ui.average,M.ui.label='0',M.duel and 'Opponent score' or 'Average (live)'
        if l.is_host then l:set_metadata({starting_lives=4,pvp_start_round=2}) end
    end
    local function integer(value,minimum,maximum)
        return type(value)=='number' and value==math.floor(value) and value>=minimum and value<=maximum
    end
    function M.enter_duel(data)
        local changed=not M.duel
        M.duel=true
        M.view=data or {mode='duel',count=2,finished=0,final=false}
        M.ui.average,M.ui.label='0','Opponent score'
        if changed and G.HUD_blind and PVP.UI.reset_blind_HUD then
            -- A HUD rebuild must never block an authoritative mode/outcome action.
            pcall(PVP.UI.reset_blind_HUD)
            if PVP.is_pvp_boss() and PVP.UI.update_blind_HUD then pcall(PVP.UI.update_blind_HUD,G.GAME.blind) end
        end
    end
    function M.receive(from,p)
        if type(p)~='table' or (p.kind~='combat_average' and p.kind~='combat_duel') then return false end
        if not M.active() or p.protocol~=4 or p.session~=M.session or p.room~=tostring(lobby().code)
            or p.recipient~=lobby().player_id or from~=M.host or p.run~=M.run then return true end
        local data=p.data
        if p.kind=='combat_duel' then
            if type(data)~='table' or not integer(data.revision,1,9007199254740991) or data.revision<=M.received
                or data.count~=2 or not integer(data.finished,0,2) or type(data.final)~='boolean'
                or not integer(data.ante,2,1000000) then return true end
            local ante=G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
            if ante and data.ante~=ante then return true end
            M.received=data.revision
            M.enter_duel(data)
            return true
        end
        if M.duel then return true end
        if type(data)~='table' or not integer(data.revision,1,9007199254740991) or data.revision<=M.received
            or type(data.average)~='string' or #data.average>80 or type(data.safe)~='table'
            or not integer(data.count,1,4) or not integer(data.finished,0,data.count)
            or type(data.final)~='boolean' or data.final~=(data.finished==data.count) then return true end
        if not (data.average:match('^%d+%.?%d*$') or data.average:match('^%d+%.?%d*[eE][+-]?%d+$')) then return true end
        local ante=G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
        if ante and data.ante~=ante then return true end
        M.received,M.view=data.revision,data
        M.ui.average=data.average
        M.ui.label=data.final and 'Final average' or 'Average (live)'
        return true
    end
    -- Keep mean values out of native opponent score/timer/gameplay fields.
    function M.publish(rank)
        local l=lobby()
        if not M.active() or not l.is_host then return end
        local safe,finished={},0
        for _,p in ipairs(rank.ranked) do
            safe[p.id]=not rank.is_loser[p.id]
            if p.hands_left<1 then finished=finished+1 end
        end
        M.revision=M.revision+1
        local data={revision=M.revision,average=rank.average,safe=safe,
            finished=finished,count=#rank.ranked,final=finished==#rank.ranked,ante=rounds.ante or (rank.ranked[1] and rank.ranked[1].ante or 0)}
        for _,p in ipairs(l:get_players()) do
            if not p.is_away then send({protocol=4,kind='combat_average',room=tostring(l.code),
                session=M.session,run=M.run,recipient=p.id,data=data},p.id) end
        end
    end
    function M.publish_duel(players,final)
        local l=lobby()
        if not M.active() or not l.is_host then return end
        local finished=0;for _,p in ipairs(players) do if p.hands_left<1 then finished=finished+1 end end
        M.revision=M.revision+1
        local data={mode='duel',revision=M.revision,count=2,finished=finished,final=final,ante=rounds.ante}
        for _,p in ipairs(l:get_players()) do
            if not p.is_away then send({protocol=4,kind='combat_duel',room=tostring(l.code),
                session=M.session,run=M.run,recipient=p.id,data=data},p.id) end
        end
    end
    function M.trace(event)
        if D.diag then D.diag('blind_start',{ante=rounds.ante}) end
    end
    function M.install()
        if M.installed then return end
        -- Validate the pinned integration surface before replacing any function.
        for _,name in ipairs({'referee_on_ready_blind','referee_n_player_forfeit','referee_rank_royale','referee_reset'}) do
            assert(type(PVP[name])=='function','PvP 1.0.0 integration contract changed: '..name)
        end
        assert(PVP.Gamemodes and PVP.Gamemodes.gamemode_mp_attrition
            and type(PVP.Gamemodes.gamemode_mp_attrition.get_blinds_by_ante)=='function',
            'PvP 1.0.0 attrition contract changed')
        assert(type(PVP.UI)=='table' and G and type(G.FUNCS)=='table','PvP HUD API missing')
        rounds.install()
        M.installed=true
        local rank_ref=assert(PVP.referee_rank_royale,'PvP 1.0.0 Royale referee missing')
        PVP.referee_rank_royale=function(players)
            if not M.active() then return rank_ref(players) end
            local rank=A.rank(players); M.publish(rank); return rank
        end
        local reset_ref=assert(PVP.referee_reset,'PvP referee startup missing')
        PVP.referee_reset=function(lives)
            if M.active() then rounds.reset() end
            if M.active() then return rounds.handover.transaction(reset_ref,4) end
            return reset_ref(lives)
        end
        local gm=assert(PVP.Gamemodes and PVP.Gamemodes.gamemode_mp_attrition,'PvP attrition mode missing')
        local blinds_ref=gm.get_blinds_by_ante
        gm.get_blinds_by_ante=function(self,ante)
            if M.active() then return nil,nil,ante>=2 and 'bl_mp_nemesis' or nil end
            return blinds_ref(self,ante)
        end
        local name_ref=PVP.pvp_blind_opponent_name
        if name_ref then PVP.pvp_blind_opponent_name=function()
            return M.active() and not M.duel and M.ui.title or name_ref()
        end end
        local scale_ref=G.FUNCS.multiplayer_blind_chip_UI_scale
        if scale_ref then G.FUNCS.multiplayer_blind_chip_UI_scale=function(e)
            if not M.active() then return scale_ref(e) end
            if not PVP.is_pvp_boss() then
                e.config.ref_table,e.config.ref_value=G.GAME.blind,'chip_text'
                e.config.func='blind_chip_UI_scale'
                if G.FUNCS.blind_chip_UI_scale then return G.FUNCS.blind_chip_UI_scale(e) end
                return
            end
            if M.duel then
                e.config.ref_table,e.config.ref_value=PVP.GAME.enemy,'score_text'
                return scale_ref(e)
            end
            e.config.ref_table,e.config.ref_value=M.ui,'average'
            local hidden=PVP.LOBBY.config.hide_score_until_played and G.GAME.current_round
                and G.GAME.current_round.hands_played==0
            M.ui.average=hidden and '???' or (M.view and M.view.average or '0')
            e.config.scale=math.min(0.7,7/math.max(10,#M.ui.average))
            PVP.GAME.enemy.hands_text=M.view and (M.view.finished..'/'..M.view.count) or '0/4'
        end end
        local hud_ref=PVP.UI.update_blind_HUD
        if hud_ref then PVP.UI.update_blind_HUD=function(...)
            local result=hud_ref(...)
            if M.active() and not M.duel and PVP.is_pvp_boss() and G.HUD_blind then
                local seen={}
                local function labels(node)
                    if not node or seen[node] then return end; seen[node]=true
                    local c=node.config
                    if c and c.text==localize('k_enemy_score') then
                        c.text=nil; c.ref_table,c.ref_value=M.ui,'label'
                    elseif c and c.text==localize('k_enemy_hands') then c.text='Players done' end
                    for _,child in pairs(node.children or {}) do labels(child) end
                end
                labels(G.HUD_blind:get_UIE_by_ID('HUD_blind') or G.HUD_blind.UIRoot or G.HUD_blind)
                local name=G.HUD_blind:get_UIE_by_ID('HUD_blind_name')
                if name and name.config.object then
                    name.config.object.config.string={{ref_table=M.ui,ref_value='title'}}
                    name.config.object:update_text(true)
                end
            end
            return result
        end end
        local reset_hud_ref=PVP.UI.reset_blind_HUD
        if reset_hud_ref then PVP.UI.reset_blind_HUD=function(...)
            local result=reset_hud_ref(...)
            if M.active() and G.HUD_blind then
                local seen={}
                local function clear(node)
                    if not node or seen[node] then return end; seen[node]=true
                    local c=node.config
                    if c and c.ref_table==M.ui then c.ref_table,c.ref_value=nil,nil end
                    for _,child in pairs(node.children or {}) do clear(child) end
                end
                clear(G.HUD_blind:get_UIE_by_ID('HUD_blind') or G.HUD_blind.UIRoot or G.HUD_blind)
                local count=G.HUD_blind:get_UIE_by_ID('HUD_blind_count')
                if count then count.config.ref_table,count.config.ref_value=G.GAME.blind,'chip_text'
                    count.config.func='blind_chip_UI_scale' end
            end
            return result
        end end
        local dispatch_ref=PVP.dispatch_action
        if dispatch_ref then PVP.dispatch_action=function(kind,...)
            if M.active() and kind=='startBlind' then
                M.trace('startBlind received')
                local ante=G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
                -- Directed average packets and the native start action may be
                -- delivered in either order. Keep a fresh live board for this ante.
                if not (M.view and not M.view.final and ante and M.view.ante==ante) then
                    M.view=nil; M.ui.average,M.ui.label='0','Average (live)'
                end
            end
            return dispatch_ref(kind,...)
        end end
        -- Multiplayer interaction targets stay native. Timer eligibility follows
        -- the average rather than whichever adjacent player the target HUD chose.
        local timer_ref=PVP.UI.cam_timer_opponent
        if timer_ref then PVP.UI.cam_timer_opponent=function()
            if not M.active() or M.duel or not PVP.is_pvp_boss() or not PVP.is_layer_active('pvp_timer') then return timer_ref() end
            local g=PVP.GAME
            if not PVP.LOBBY.config.timer or g.pvp_countdown_in_progress or (g.timer or 0)<=0
                or g.nemesis_timer_started or g.end_pvp then return false end
            if G.STATE==G.STATES.ROUND_EVAL or G.STATE==G.STATES.NEW_ROUND then return false end
            if PVP.LOBBY.config.hide_score_until_played and G.GAME.current_round.hands_played==0 then return false end
            return M.view and M.view.safe[lobby().player_id] or false
        end end
        local blind=MPAPI.Blinds and MPAPI.Blinds.bl_mp_nemesis
        if blind and blind.receive then
            local receive_ref=blind.receive
            blind.receive=function(self,context)
                if not M.active() or M.duel then return receive_ref(self,context) end
                local g=PVP.GAME
                local own_timer,enemy_timer=g.timer_started,g.nemesis_timer_started
                local result=receive_ref(self,context)
                g.timer_started,g.nemesis_timer_started=own_timer,enemy_timer
                if M.view and PVP.is_pvp_boss() and PVP.is_layer_active('pvp_timer') then
                    if M.view.safe[lobby().player_id] then g.nemesis_timer_started=false
                    else g.timer_started=false end
                end
                return result
            end
        end
    end
    return M
end

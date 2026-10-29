-- One persistent watch-only table. Frames update its model; they never rebuild
-- the surrounding UI or instantiate a second gameplay run.
return function(D,S)
    local W,C,U=S.wire,S.capture,D.ui
    local M=assert(SMODS.load_file('draftout/spectator_table.lua',D.mod.id))()
    local painter=assert(SMODS.load_file('draftout/spectator_painter.lua',D.mod.id))()(D,S,M)
    local function now() return D.now and D.now() or love.timer.getTime() end
    function S.refresh()
        if not S.open or (S.overlay and G.OVERLAY_MENU~=S.overlay) then return end
        S.watching_name=S.demo and 'Practice opponent' or 'Waiting for a board'
        if not S.demo then
            for _,p in ipairs(S.players()) do if p.id==S.target then S.watching_name=p.name;break end end
        end
        if not S.overlay then
            local room=G.ROOM and G.ROOM.T or {w=20,h=11}
            local width=math.max(4,math.min(18,(room.w or 20)-0.6,((room.h or 11)-1.1)*2))
            S.stage=painter.new(width,width/2)
            local buttons={}
            if S.demo then
                buttons[#buttons+1]=U.button('Restart demo','draftout_spectate_restart',nil,2.6)
            else
                buttons[#buttons+1]=U.button('< Previous player','draftout_spectate_previous',nil,3)
                buttons[#buttons+1]=U.button('Next player >','draftout_spectate_next',nil,3)
            end
            buttons[#buttons+1]=U.button(S.demo and 'Close preview' or 'Back to results','draftout_spectate_close',nil,3)
            G.FUNCS.overlay_menu({config={offset={x=0,y=0}},definition={n=G.UIT.ROOT,
                config={align='cm',padding=0,colour=G.C.CLEAR},nodes={
                    {n=G.UIT.R,config={align='cm'},nodes={{n=G.UIT.O,config={object=S.stage}}}},
                    U.row(buttons),
                }}})
            S.overlay=G.OVERLAY_MENU
        end
        M.apply(S.stage.scene,S.frame,S.demo and 'demo' or S.token,now())
    end
    G.FUNCS.draftout_spectate_open=function()
        if not S.can_watch() then return end
        S.open=true;S.overlay=nil
        local players=S.players()
        if players[1] then S.select(players[1].id) end
        S.refresh()
    end
    local function cycle(direction)
        local players=S.players();if #players<2 then return end
        local index=0
        for i,p in ipairs(players) do if p.id==S.target then index=i end end
        local chosen=players[(index-1+direction)%#players+1]
        if chosen and S.select(chosen.id) then S.refresh() end
    end
    G.FUNCS.draftout_spectate_previous=function() cycle(-1) end
    G.FUNCS.draftout_spectate_next=function() cycle(1) end
    G.FUNCS.draftout_spectate_close=function()
        local demo=S.demo
        S.open=false;S.stop_view();S.overlay=nil;S.stage=nil
        G.FUNCS.exit_overlay_menu()
        if not demo and PVP and PVP.GAME and PVP.GAME.eliminated
            and G.FUNCS.overlay_endgame_menu and MPAPI.get_current_lobby() then G.FUNCS.overlay_endgame_menu() end
    end
    local function demo_frame(step)
        local t=step%16
        local phase=t==0 and 'draw to hand' or t<=2 and 'selecting hand' or t<=6 and 'hand played'
            or t==7 and 'round eval' or t<=10 and 'shop' or t<=13 and 'buffoon pack' or 'blind select'
        local score=t<3 and 0 or math.min(16800,(t-2)*4200)
        local f={version=W.VERSION,ante=3,deck=t==0 and 52 or 44,total=52,phase=phase,
            score=tostring(score),target='12,000',blind='PvP',dollars=t>=10 and '13' or '20',
            hands=t<3 and '4' or '3',discards='2',lives='2',areas={},hand_name=t>=3 and t<=6 and 'Straight Flush' or '',
            hand_chips=t>=3 and t<=6 and tostring(140+(t-3)*70) or '0',
            hand_mult=t>=3 and t<=6 and tostring(12+(t-3)*12) or '0'}
        for _,k in ipairs(W.GROUPS) do f.areas[k]={} end
        local function card(key,id,front)
            local center=G.P_CENTERS[key] or {}
            return {name=front or center.name or key,center=key,front=front or '',hidden=false,
                selected=false,debuff=false,edition='',seal='',detail='',price='7',uid=id}
        end
        for i,key in ipairs({'j_joker','j_burglar','j_blueprint','j_gros_michel','j_abstract'}) do
            if G.P_CENTERS[key] then f.areas.jokers[#f.areas.jokers+1]=card(key,'joker:'..i) end
        end
        if G.P_CENTERS.c_strength then f.areas.consumeables[1]=card('c_strength','consumable:1') end
        if t>0 and t<=6 then
            for i,key in ipairs({'H_A','H_K','H_Q','H_J','H_T','S_A','D_7','C_2'}) do
                if G.P_CARDS and G.P_CARDS[key] then
                    local c=card('c_base','hand:'..i,key)
                    c.selected=t==2 and i<=5
                    local area=t>=3 and i<=5 and f.areas.play or f.areas.hand
                    area[#area+1]=c
                end
            end
        end
        for i,key in ipairs({'j_droll','j_zany'}) do
            if G.P_CENTERS[key] then
                local c=card(key,'shop:'..i)
                if t>=10 and i==1 then f.areas.jokers[#f.areas.jokers+1]=c
                elseif t>=8 and t<=10 then f.areas.shop_jokers[#f.areas.shop_jokers+1]=c end
            end
        end
        if t>=8 and t<=10 then
            if G.P_CENTERS.v_overstock_norm then f.areas.shop_vouchers[1]=card('v_overstock_norm','voucher:1') end
            if G.P_CENTERS.p_buffoon_normal_1 then f.areas.shop_booster[1]=card('p_buffoon_normal_1','booster:1') end
        end
        for i,key in ipairs({'j_greedy_joker','j_lusty_joker','j_wrathful_joker'}) do
            if G.P_CENTERS[key] then
                local c=card(key,'pack:'..i)
                if t>=13 and i==1 then f.areas.jokers[#f.areas.jokers+1]=c
                elseif t>=11 and t<=12 then c.selected=t==12 and i==1;f.areas.pack_cards[#f.areas.pack_cards+1]=c end
            end
        end
        return W.frame(f)
    end
    S.demo_frame=demo_frame
    G.FUNCS.draftout_spectate_demo=function()
        if MPAPI and MPAPI.get_current_lobby and MPAPI.get_current_lobby() then return end
        S.stop_view();S.demo=true;S.open=true;S.overlay=nil
        S.demo_start=now();S.demo_step=0;S.frame=demo_frame(0)
        S.status='LOCAL DEMO - scripted preview; not connected to another player.'
        S.refresh()
    end
    G.FUNCS.draftout_spectate_restart=function()
        if not S.demo then return end
        S.demo_start=now();S.demo_step=0;S.frame=demo_frame(0)
        S.stage.scene=M.new();S.refresh()
    end
    function S.demo_tick()
        if S.overlay and G.OVERLAY_MENU~=S.overlay then S.open=false;S.stop_view();return end
        local step=math.floor((now()-S.demo_start)/1.2)
        if step~=S.demo_step then S.demo_step=step;S.frame=demo_frame(step);S.refresh() end
    end
end

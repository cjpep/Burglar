-- Pregame presentation only. Card:open/explode use in-run state and a timer
-- that freezes in menus, so use the real wrapper renderer on a wall clock.
return function(D, sound)
    local O={rounds={}}
    function O.get(identity,token,count)
        local key=identity..':'..token.round
        local state=O.rounds[key]
        if not state then
            local effects=D.mod.config.pack_effects~=false
                and not (G.SETTINGS and G.SETTINGS.reduced_motion)
            state={new_pack=token.pick==1,count=count,started=D.now(),duration=0.9}
            state.animate=state.new_pack and effects
                and G.P_CENTERS.p_buffoon_normal_1~=nil
            O.rounds[key]=state
        end
        return state
    end
    function O.running(state)
        return state and state.animate and D.mod.config.pack_effects~=false
            and D.now()<state.started+state.duration
    end
    function O.update(state,visible)
        if not state or not state.animate then return end
        local progress=math.max(0,math.min(1,(D.now()-state.started)/state.duration))
        if not state.buildup then
            state.buildup=true
            if visible then sound('explosion_buildup1') end
        end
        if progress>=0.6 and not state.released then
            state.released=true
            if visible then sound('explosion_release1') end
        end
        local card=state.card
        if card and not card.removed then
            card.juice={scale=0.1*progress,r=0.025*math.sin(progress*65)*progress,
                handled_elsewhere=true,start_time=state.started,end_time=state.started+state.duration}
            card.dissolve=math.max(0,(progress-0.6)/0.4)
        end
        if progress>=1 then state.card=nil end
    end
    function O.node(state)
        local scale=1.05
        local area=CardArea(G.ROOM.T.x,G.ROOM.T.y,G.CARD_W*scale*1.4,G.CARD_H*scale*1.2,
            {card_limit=1,type='title',highlight_limit=0,card_w=G.CARD_W*scale,draw_layers={'card'}})
        local card=Card(area.T.x,area.T.y,G.CARD_W*scale,G.CARD_H*scale,nil,
            G.P_CENTERS.p_buffoon_normal_1,
            {bypass_discovery_center=true,bypass_discovery_ui=true,bypass_lock=true})
        card.states.drag.can,card.states.hover.can=false,false
        card.facing,card.sprite_facing,card.flipping='front','front',nil
        card.dissolve_colours={G.C.WHITE}
        card.click=function() end
        area:emplace(card)
        state.card=card
        O.update(state,true)
        return D.ui.row({{n=G.UIT.C,config={align='cm',padding=0.05},nodes={
            D.ui.line('Opening Buffoon draft pack...',0.32),
            D.ui.row({{n=G.UIT.O,config={object=area}}}),
            D.ui.line(state.count..' Jokers',0.26),
        }}})
    end
    return O
end

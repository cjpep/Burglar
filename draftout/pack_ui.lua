-- Native card previews with private selections, read-only galleries and effects.
return function(D)
    local P, U, core = {active = nil, deals = {}, ui = {timer = ''}}, D.ui, D.core
    D.pack_ui = P
    local shadow=assert(SMODS.load_file('draftout/preview_shadow.lua',D.mod.id))()
    -- Accent colours are confined to Draftout's UI; gameplay colours are unchanged.
    local GOLD={1.00,0.71,0.28,1}
    local GOLD_TEXT={0.09,0.13,0.17,1}
    -- Each preview has its own single-card area. Native movement eases toward
    -- these targets, including when the menu moves or a saved selection returns.
    local function align_preview(area)
        for _, card in ipairs(area.cards) do
            card.T.x = area.T.x + (area.T.w - card.T.w) / 2
            card.T.y = area.T.y + (area.T.h - card.T.h) / 2
                - (card.draftout_selected and card.T.h * 0.14 or 0)
            card.T.r = 0
        end
    end
    local function now() return D.now() end
    local function sound(key)
        if D.mod.config.pack_effects ~= false and play_sound then play_sound(key, 1, 0.35) end
    end
    P.opening=assert(SMODS.load_file('draftout/pack_opening.lua',D.mod.id))()(D,sound)
    function P.clear()
        if P.active and P.active.opening then P.active.opening.card=nil end
        P.active = nil
    end
    function P.reset_session()
        P.clear()
        P.deals={}
        P.opening.rounds={}
        P.warning,P.header_time=nil,nil
    end
    function P.unlock() if P.active then P.active.pending = false end end
    function P.choices()
        local keys = {}
        for key in pairs(P.active and P.active.selected or {}) do keys[#keys+1] = key end
        table.sort(keys); return keys
    end
    function P.confirmed()
        sound('cardSlide2')
    end
    function P.timer_node()
        return {n = G.UIT.R, config = {align = 'cm'}, nodes = {
            {n = G.UIT.T, config = {ref_table = P.ui, ref_value = 'timer', scale = 0.24, colour = G.C.WHITE,func='draftout_timer_colour'}},
        }}
    end
    function P.grid(keys, options)
        local o, rows = options or {}, {}
        local scale, per_row = o.scale or 0.61, o.per_row or 7
        local slots=math.max(#keys,o.slots or 0)
        local row_ranges={}
        if o.center_pack_rows and slots==per_row*2 and #keys<=slots then
            -- Keep both rows at the same full width, but distribute remaining
            -- Jokers evenly (9 = 5+4, 7 = 4+3, 5 = 3+2, etc.).
            local top=math.ceil(#keys/2)
            row_ranges={{first=1,count=top},{first=top+1,count=#keys-top}}
        else
            for first=1,slots,per_row do
                row_ranges[#row_ranges+1]={first=first,count=math.min(per_row,slots-first+1)}
            end
        end
        for _,range in ipairs(row_ranges) do
            local cells = {}
            local first,last=range.first,range.first+range.count-1
            local blank_width=(per_row-range.count)*(G.CARD_W*scale*1.08+0.05)/2
            local function side_gap()
                return {n=G.UIT.B,config={w=blank_width,
                    h=G.CARD_H*scale*1.36+0.05,colour=G.C.CLEAR}}
            end
            if o.center_pack_rows and blank_width>0 then cells[#cells+1]=side_gap() end
            for index = first,last do
                local key = keys[index]
                if key then
                local area = CardArea(G.ROOM.T.x, G.ROOM.T.y,
                    G.CARD_W*scale*1.08, G.CARD_H*scale*1.36,
                    {card_limit=1,type='title',highlight_limit=0,card_w=G.CARD_W*scale,
                        draw_layers=o.choose and {'shadow','card'} or {'card'}})
                -- Reserve headroom inside the area so raised cards stay clear
                -- of the preceding row. This only changes Draftout previews.
                area.align_cards = align_preview
                local card = Card(area.T.x,area.T.y,G.CARD_W*scale,G.CARD_H*scale,nil,
                    assert(G.P_CENTERS[key],'Missing Joker: '..key),
                    {bypass_discovery_center=true,bypass_discovery_ui=true,bypass_lock=true})
                card.draftout_tray=o.tray or o.roster
                card.states.drag.can = false
                -- Menu previews must never rely on the run's flip state machine.
                card.facing,card.sprite_facing,card.flipping = 'front','front',nil
                card.draftout_selected = not not (o.selected and o.selected[key])
                if o.choose then shadow.attach(card) end
                if o.choose then
                    -- A card-owned Sprite is reliably drawn by native Card:draw.
                    -- Unlike a UI column, it adds ZERO grid height or padding.
                    local atlas=G.ASSET_ATLAS and G.ASSET_ATLAS['draftout_selection_caret']
                    if atlas and Sprite then
                        local caret=Sprite(card.T.x,card.T.y,0.22,0.14,atlas,{x=0,y=0})
                        caret:set_alignment({major=card,type='bm',offset={x=0,y=0.045},
                            bond='Strong',wh_bond='Weak',r_bond='Weak',scale_bond='Weak'})
                        caret.states.collide.can=false
                        caret.states.drag.can=false
                        caret.states.hover.can=false
                        caret.states.click.can=false
                        caret.states.visible=card.draftout_selected
                        card.children.draftout_selection_caret=caret
                    end
                end
                card.draftout_label = o.labels and o.labels[index] or ''
                local animate=o.deal_start and D.mod.config.pack_effects~=false
                    and not (G.SETTINGS and G.SETTINGS.reduced_motion)
                card.draftout_reveal_at=animate and (o.deal_start+(index-1)*0.035) or nil
                card.draftout_revealed=not animate or now()>=card.draftout_reveal_at
                card.states.visible=card.draftout_revealed
                card.states.hover.can=card.draftout_revealed
                if not card.draftout_revealed then P.deals[#P.deals+1]=card end
                card.click = function(self)
                    if not self.draftout_revealed then return end
                    if o.on_slot_click then o.on_slot_click((o.slot_offset or 0)+index);return end
                    if not o.choose or not o.choose(key) then return end
                    self.draftout_selected = not not o.selected[key]
                    if self.children and self.children.draftout_selection_caret then
                        self.children.draftout_selection_caret.states.visible=self.draftout_selected
                    end
                    self.area:align_cards()
                    self:juice_up(0.1,0.05)
                end
                if o.pop then card:juice_up(0.12,0.03) end
                area:emplace(card)
                area:align_cards()
                local content={
                    {n=G.UIT.R,config={align='cm'},nodes={{n=G.UIT.O,config={object=area}}}},
                }
                if o.labels then content[#content+1]={n=G.UIT.R,config={align='cm'},nodes={{n=G.UIT.T,config={ref_table=card,
                    ref_value='draftout_label',scale=0.19,colour=G.C.WHITE}}}} end
                cells[#cells+1] = {n=G.UIT.C,config={align='cm',padding=0.025,
                    r=o.roster and 0.045 or nil,
                    colour=o.roster and (((o.slot_offset or 0)+index)==o.selected_slot and GOLD
                        or {0.13,0.22,0.25,1}) or nil},nodes=content}
                else
                    -- Empty sleeves reserve exactly the footprint of a real
                    -- CardArea, so card-count changes never resize the panel.
                    cells[#cells+1]={n=G.UIT.C,config={align='cm',padding=0.025,
                        r=o.roster and 0.045 or nil,
                        colour=o.roster and G.C.CLEAR or nil,
                        outline=o.roster and 0.8 or nil,
                        outline_colour=o.roster and {0.52,0.70,0.69,0.22} or nil},nodes={{
                            n=G.UIT.B,config={w=G.CARD_W*scale*1.08,
                                h=G.CARD_H*scale*1.36,colour=G.C.CLEAR}
                        }}}
                end
            end
            if o.center_pack_rows and blank_width>0 then cells[#cells+1]=side_gap() end
            rows[#rows+1] = U.row(cells)
        end
        return U.row({{n=G.UIT.C,config={align='cm',padding=0.01},nodes=rows}})
    end
    G.FUNCS.draftout_confirm_text_colour=function(e)
        e.config.colour=P.ui.confirm_text_colour or G.C.WHITE
    end
    function P.confirm_button()
        local confirm=U.button('Confirm selection','draftout_pack_confirm',nil,3.3)
        confirm.config.func='draftout_pack_can_confirm'
        confirm.config.minh=0.58
        confirm.nodes[1].config.scale=0.3
        confirm.nodes[1].config.func='draftout_confirm_text_colour'
        return confirm
    end
    function P.footer()
        local a=P.active
        local controls=D.views.navigation()
        controls[#controls+1]={n=G.UIT.C,config={align='cm',minw=2},nodes={
            {n=G.UIT.T,config={ref_table=a,ref_value='status',scale=0.23,colour=G.C.WHITE}},
        }}
        controls[#controls+1]=P.confirm_button()
        return U.row(controls)
    end
    function P.build(keys,token,identity,commit,extra_button,options)
        local o = options or {}
        if o.get_team then
            D.roster_context={get_keys=o.get_team,identity=identity,total=o.total}
        end
        local signature = identity..':'..token.round..':'..token.pick..':'..token.pack_id..':'..tostring(o.picks_per_turn or 1)..':'..table.concat(keys,'|')
        local fresh = not P.active or P.active.signature ~= signature
        if fresh then P.clear(); P.active={signature=signature,selected={},needed=math.min(o.picks_per_turn or 1,#keys),intent_seq=0} end
        local a = P.active
        local opening=P.opening.get(identity,token,#keys)
        a.opening=opening
        a.commit,a.token,a.time_left = commit,core.copy(token),o.time_left
        a.status = #P.choices()..'/'..a.needed..' selected'
        local nodes={}
        if P.opening.running(opening) then
            nodes[#nodes+1]=P.opening.node(opening)
            a.showing_opening=true
        else
            a.showing_opening=false
            local pop=opening.new_pack and not opening.cards_shown and D.mod.config.pack_effects~=false
                and not (G.SETTINGS and G.SETTINGS.reduced_motion)
            opening.cards_shown=true
            if pop then sound('card1') end
            a.deal_started=a.deal_started or now()
            local grid=P.grid(keys,{scale=0.74,per_row=5,slots=10,center_pack_rows=true,
                pop=pop,deal_start=a.deal_started,selected=a.selected,choose=function(key)
                if P.active~=a or a.pending then return false end
                if a.selected[key] then a.selected[key]=nil
                elseif #P.choices()<a.needed then a.selected[key]=true
                else return false end
                a.intent_seq=a.intent_seq+1
                if o.on_change then o.on_change(P.choices(),core.copy(a.token),a.intent_seq) end
                return true
            end})
            nodes[#nodes+1]={n=G.UIT.C,config={align='cm',padding=0.08},nodes={grid}}
        end
        local pack=U.row({{n=G.UIT.C,config={align='cm',padding=0.02},nodes=nodes}})
        -- Sibling row surfaces share their parent column's width, unlike
        -- separately sized coloured columns. Match the status panel's edges.
        pack.config.padding=0.04
        pack.config.r=0.10
        pack.config.colour={0.18,0.28,0.31,0.92}
        pack.config.id='draftout_pack_selection'
        return pack
    end
    G.FUNCS.draftout_pack_can_confirm=function(e)
        local a=P.active
        local ready=a and not a.pending and not a.showing_opening and #P.choices()==a.needed
        e.config.button=ready and 'draftout_pack_confirm' or nil
        e.config.colour=ready and GOLD or G.C.UI.BACKGROUND_INACTIVE
        P.ui.confirm_text_colour=ready and GOLD_TEXT or G.C.WHITE
        if a then a.status=a.pending and 'Submitting...' or (#P.choices()..'/'..a.needed..' selected') end
    end
    G.FUNCS.draftout_pack_confirm=function()
        local a,keys=P.active,P.choices()
        if not a or a.pending or a.showing_opening or #keys~=a.needed then return end
        a.pending=true
        local ok,err=pcall(a.commit,keys,core.copy(a.token))
        if not ok then a.pending=false; D.message=tostring(err):sub(1,160) end
        U.show()
    end
    G.FUNCS.draftout_timer_colour=function(e) e.config.colour=P.ui.timer_colour or G.C.WHITE end
    local updates=assert(SMODS.load_file('draftout/updates.lua',D.mod.id))()(D)
    updates.add('pack_ui',function(self,dt)
        for i=#P.deals,1,-1 do
            local card=P.deals[i]
            if card.removed or card.REMOVED or now()>=card.draftout_reveal_at or D.mod.config.pack_effects==false
                or (G.SETTINGS and G.SETTINGS.reduced_motion) then
                if not card.removed and not card.REMOVED then
                    card.draftout_revealed=true; card.states.visible=true; card.states.hover.can=true
                    if D.mod.config.pack_effects~=false and not (G.SETTINGS and G.SETTINGS.reduced_motion) then card:juice_up(0.06,0.02) end
                end
                table.remove(P.deals,i)
            end
        end
        if D.local_tick then D.local_tick() end
        local team=D.views and D.views.team
        local a=P.active
        if a and a.showing_opening then
            local visible=not team and D.overlay and G.OVERLAY_MENU==D.overlay
            P.opening.update(a.opening,visible)
            if not P.opening.running(a.opening) then
                a.showing_opening=false
                if visible then U.show() end
            end
        end
        local source=team and team.time_left or P.active and P.active.time_left or P.header_time
        local left,paused
        if source then left,paused=source() end
        P.ui.timer_colour=not paused and left and (left<=5 and G.C.RED or left<=10 and (G.C.ORANGE or G.C.YELLOW or G.C.WHITE)) or G.C.WHITE
        if a then
            if not P.warning or P.warning.signature~=a.signature then P.warning={signature=a.signature} end
            if left and left<=5 and not paused and not a.pending and not P.warning.played
                and D.mod.config.timer_alerts~=false and play_sound then
                P.warning.played=true
                play_sound('highlight1',1,0.35)
            end
        end
        P.ui.timer=left and (paused and ('Timer paused: '..math.ceil(left)..'s') or ('Time left: '..math.ceil(left)..'s')) or ''
    end)
end

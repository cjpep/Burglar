-- Private Draftout lobby selector; uses PvP's existing shared deck metadata.
return function(D,B)
    local M={}
    D.deck_picker=M
    local keys={'b_red','b_blue','b_yellow','b_green','b_black','b_magic','b_nebula',
        'b_ghost','b_abandoned','b_checkered','b_zodiac','b_painted','b_anaglyph','b_plasma','b_erratic'}
    local function lobby() return MPAPI.get_current_lobby() end
    function M.active(l) return D.mod.config.native_draft~=false and B.is_target(l) end
    function M.synced()
        local p=M.pending
        if p and (p.lobby~=lobby() or (p.lobby:get_metadata() or {}).deck==p.name) then M.pending=nil end
        return M.pending==nil
    end
    function M.can_select()
        local l=lobby()
        return M.active(l) and l.is_host and not l:is_game_started() and not B.pending_launch
    end
    function M.choices()
        local out={}
        for _,key in ipairs(keys) do
            local c=G.P_CENTERS[key]
            if c and c.set=='Back' then out[#out+1]=c end
        end
        return out
    end
    function M.select(key,expected_lobby)
        assert(lobby()==expected_lobby and M.can_select(),'Only the current lobby host can change the deck before the match')
        local chosen
        for _,c in ipairs(M.choices()) do if c.key==key then chosen=c end end
        assert(chosen,'Choose a standard Balatro deck')
        M.pending={lobby=lobby(),name=chosen.name}
        lobby():set_metadata({deck=chosen.name})
        -- Never claim success until the server's metadata echo arrives.
    end
    function M.apply_run()
        if not M.active(lobby()) then return end
        local name=(lobby():get_metadata() or {}).deck
        if not name then return end -- Preserve native defaults for old lobbies.
        local found
        for _,c in ipairs(M.choices()) do if c.name==name or c.key==name then found=c end end
        assert(found,'Draftout: the shared deck is unavailable on this client')
        PVP.LOBBY.config.back,PVP.LOBBY.deck.back=found.name,found.name
        PVP.LOBBY.config.different_decks=false
        PVP.LOBBY.config.random_loadout=false
    end
    G.FUNCS.draftout_deck_close=function()
        M.open_lobby=nil
        G.FUNCS.exit_overlay_menu()
        if MPAPI.refresh_current_view then MPAPI.refresh_current_view() end
    end
    function M.render()
        if not M.can_select() or M.open_lobby~=lobby() then return end
        local U=D.ui
        local nodes={U.line('Choose the shared deck',0.38),
            U.line('Your Joker draft is kept. The host chooses for everyone.',0.26)}
        local preview=G.P_CENTERS[M.preview_key or 'b_red']
        if preview then
            nodes[#nodes+1]=U.line(localize({type='name_text',set='Back',key=preview.key}),0.34)
            if Back and Sprite and UIBox and G.ASSET_ATLAS then
                local w,h=G.CARD_W*0.85,G.CARD_H*0.85
                local sprite=Sprite(0,0,w,h,G.ASSET_ATLAS[preview.atlas or 'centers'],preview.pos)
                local description=UIBox{definition=Back(preview):generate_UI(preview),config={offset={x=0,y=0}}}
                nodes[#nodes+1]=U.row({{n=G.UIT.O,config={object=sprite}},
                    {n=G.UIT.O,config={object=description}}})
            end
        end
        local row={}
        for i,c in ipairs(M.choices()) do
            local label=localize({type='name_text',set='Back',key=c.key})
            row[#row+1]=U.button(label,'draftout_deck_select',{key=c.key,lobby=M.open_lobby},2.8)
            if #row==3 then nodes[#nodes+1]=U.row(row); row={} end
        end
        if #row>0 then nodes[#nodes+1]=U.row(row) end
        nodes[#nodes+1]=U.row({U.button('Use this deck for everyone','draftout_deck_apply',
            {key=M.preview_key,lobby=M.open_lobby},5),U.button('Cancel','draftout_deck_close',nil,2)})
        if U.overlay then U.overlay(M,{n=G.UIT.C,config={align='cm'},nodes=nodes})
        else G.FUNCS.overlay_menu({definition=create_UIBox_generic_options({back_func='draftout_deck_close',contents=nodes})}) end
    end
    G.FUNCS.draftout_deck_open=function()
        if not M.can_select() then return end
        M.open_lobby=lobby()
        local selected=(lobby():get_metadata() or {}).deck
        M.preview_key='b_red'
        for _,c in ipairs(M.choices()) do if c.name==selected or c.key==selected then M.preview_key=c.key end end
        M.render()
    end
    G.FUNCS.draftout_deck_select=function(e)
        local data=e.config.ref_table
        if data.lobby~=lobby() or not M.can_select() then return end
        M.preview_key=data.key; M.render()
    end
    G.FUNCS.draftout_deck_apply=function(e)
        local data=e.config.ref_table
        local ok,err=pcall(M.select,data.key,data.lobby)
        if ok then G.FUNCS.draftout_deck_close()
        else PVP.UI.UTILS.overlay_message(tostring(err):gsub('^.-:%d+: ','')) end
    end
    G.FUNCS.draftout_deck_enabled=function(e)
        e.config.button=M.can_select() and 'draftout_deck_open' or nil
    end
    function M.install()
        if M.installed or not (PVP.lobby and type(PVP.lobby.build_controls)=='function') then return end
        M.installed=true
        local original=PVP.lobby.build_controls
        function PVP.lobby.build_controls(...)
            local node=original(...)
            if not M.active(lobby()) then return node end
            -- Identify the read-only purple Deck panel in the pinned PvP 1.0 UI.
            local function decorate(n)
                local rows=n.nodes or {}
                local label=rows[1] and rows[1].nodes and rows[1].nodes[1]
                if n.config and n.config.colour==G.C.PURPLE and label and label.config
                    and label.config.text=='Deck' then
                    n.config.id='draftout_shared_deck'
                    n.config.hover=true
                    n.config.func='draftout_deck_enabled'
                    n.config.button=M.can_select() and 'draftout_deck_open' or nil
                    label.config.text=lobby().is_host and 'Change deck' or 'Shared deck'
                    n.config.tooltip={title='Shared starting deck',text={'Host chooses for everyone before the match.',
                        'Changing decks keeps your Joker draft.'}}
                    local value=rows[2] and rows[2].nodes and rows[2].nodes[1]
                    if value and not M.synced() then value.config.text='Syncing deck...' end
                    return
                end
                for _,child in ipairs(rows) do decorate(child) end
            end
            decorate(node)
            return node
        end
    end
    return M
end

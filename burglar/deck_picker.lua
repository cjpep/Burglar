-- Private Burglar lobby selector; uses PvP's existing shared deck metadata.
return function(D,B)
    local M={}
    local balances={
        {key='ruleset_mp_vanilla',name='Vanilla'},
        {key='ruleset_mp_balanced',name='Balanced'},
        {key='ruleset_mp_expanded',name='Expanded'},
        {key='ruleset_mp_smallworld',name='Small World'},
    }
    local function balance_name(key)
        for _,v in ipairs(balances) do if v.key==key then return v.name end end
        return tostring(key or 'Balanced')
    end
    D.deck_picker=M
    local keys={'b_red','b_blue','b_yellow','b_green','b_black','b_magic','b_nebula',
        'b_ghost','b_abandoned','b_checkered','b_zodiac','b_painted','b_anaglyph','b_plasma','b_erratic'}
    local function lobby() return MPAPI.get_current_lobby() end
    function M.active(l) return D.mod.config.native_draft~=false and (B.is_target(l) or (D.tournament and D.tournament.current_board(l))) end
    function M.synced()
        local p=M.pending
        if p and (p.lobby~=lobby() or ((not p.name or (p.lobby:get_metadata() or {}).deck==p.name)
            and (not p.stake or tonumber((p.lobby:get_metadata() or {}).stake)==tonumber(p.stake))
            and (not p.ruleset or (p.lobby:get_metadata() or {}).ruleset==p.ruleset))) then M.pending=nil end
        return M.pending==nil
    end
    function M.can_select()
        local l=lobby()
        return M.active(l) and not (D.tournament and D.tournament.current_board(l)) and l.is_host and not l:is_game_started() and not B.started and not B.pending_launch
    end
    function M.can_balance()
        return M.can_select() and (not B.session or B.phase=='idle'
            or (B.phase=='complete' and B.pool and B.released and B.launch_ready()))
    end
    function M.select_balance(key,expected_lobby)
        assert(lobby()==expected_lobby and M.can_balance(), 'Change balance before drafting or after the draft finishes')
        local known=false
        for _,v in ipairs(balances) do if v.key==key then known=true end end
        assert(known,'Choose a supported balance ruleset')
        assert(M.synced(),'Waiting for the server to confirm the previous settings')
        M.pending={lobby=lobby(),ruleset=key}
        -- Only change ruleset: the upstream full-metadata writer can otherwise
        -- overwrite the shared deck with its older config.back value.
        lobby():set_metadata({ruleset=key})
    end
    function M.choices()
        local out={}
        for _,key in ipairs(keys) do
            local c=G.P_CENTERS[key]
            if c and c.set=='Back' then out[#out+1]=c end
        end
        return out
    end
    function M.select(key,expected_lobby,ruleset)
        assert(lobby()==expected_lobby and M.can_select(),'Only the current lobby host can change the deck before the match')
        local chosen
        for _,c in ipairs(M.choices()) do if c.key==key then chosen=c end end
        assert(chosen,'Choose a standard Balatro deck')
        assert(M.synced(),'Waiting for the server to confirm the previous settings')
        local meta=lobby():get_metadata() or {}
        local changes={deck=chosen.name}
        if ruleset and ruleset~=meta.ruleset then
            assert(M.can_balance(),'Finish the draft before changing balance')
            local known=false
            for _,v in ipairs(balances) do if v.key==ruleset then known=true end end
            assert(known,'Choose a supported balance ruleset')
            changes.ruleset=ruleset
        end
        M.pending={lobby=lobby(),name=chosen.name,ruleset=changes.ruleset}
        lobby():set_metadata(changes)
        -- Never claim success until the server's metadata echo arrives.
    end
    function M.apply_run()
        if not M.active(lobby()) then return end
        -- PvP 1.0.1+ mirrors the native pick (including stake/challenge/sleeve).
        -- Do not replace that selection with our former standard-deck whitelist.
        if M.native_picker then return end
        local name=(lobby():get_metadata() or {}).deck
        if not name then return end -- Preserve native defaults for old lobbies.
        local found
        for _,c in ipairs(M.choices()) do if c.name==name or c.key==name then found=c end end
        assert(found,'Burglar: the shared deck is unavailable on this client')
        PVP.LOBBY.config.back,PVP.LOBBY.deck.back=found.name,found.name
        PVP.LOBBY.config.different_decks=false
        PVP.LOBBY.config.random_loadout=false
    end
    function M.clear_preview()
        if M.preview_sprite then
            if M.preview_sprite.remove then M.preview_sprite:remove() end
            M.preview_sprite=nil
        end
    end
    G.FUNCS.draftout_deck_close=function()
        M.clear_preview();M.open_lobby=nil
        G.FUNCS.exit_overlay_menu()
        if MPAPI.refresh_current_view then MPAPI.refresh_current_view() end
    end
    function M.render()
        if not M.can_select() or M.open_lobby~=lobby() then return end
        M.clear_preview()
        local U=D.ui
        local nodes={U.line('Shared deck & balance',0.40),
            U.line('Host settings for everyone. Your completed Joker draft is kept.',0.24)}
        local preview=G.P_CENTERS[M.preview_key or 'b_red']
        local left={}
        if preview then
            left[#left+1]=U.line(localize({type='name_text',set='Back',key=preview.key}),0.34)
            if Sprite and G.ASSET_ATLAS and preview.pos then
                local sprite=Sprite(0,0,G.CARD_W*0.80,G.CARD_H*0.80,
                    G.ASSET_ATLAS[preview.atlas or 'centers'],preview.pos)
                -- Some overlay owners remove embedded objects, others do not.
                -- Make this preview's cleanup safe through either path.
                local remove=sprite.remove
                if remove then
                    local removed=false
                    sprite.remove=function(self,...)
                        if removed then return end
                        removed=true;return remove(self,...)
                    end
                end
                M.preview_sprite=sprite
                left[#left+1]=U.row({{n=G.UIT.O,config={object=sprite}}})
            end
            if Back then
                local description=Back(preview):generate_UI(preview)
                if description then
                    -- Let the parent measure the native description directly.
                    -- No detached UIBox, fixed text height or clipping mask.
                    description.n=G.UIT.R
                    left[#left+1]=description
                end
            end
        end
        local right={U.line('Choose a deck',0.27)}
        local row={}
        for _,c in ipairs(M.choices()) do
            local label=localize({type='name_text',set='Back',key=c.key})
            local item=U.button(label,'draftout_deck_select',{key=c.key,lobby=M.open_lobby},2.25)
            if c.key==M.preview_key then
                item.config.colour={0.40,0.27,0.34,1};item.config.outline=1
                item.config.outline_colour={222/255,148/255,130/255,1}
            end
            row[#row+1]=item
            if #row==3 then right[#right+1]=U.row(row);row={} end
        end
        if #row>0 then right[#right+1]=U.row(row) end
        local function panel(contents,width)
            return {n=G.UIT.C,config={align='tm',padding=0.18,minw=width,
                colour={0.16,0.22,0.25,1},r=0.12},nodes=contents}
        end
        nodes[#nodes+1]=U.row({panel(left,4.5),panel(right,7.0)})
        nodes[#nodes+1]=U.line('Balance: '..balance_name(M.preview_ruleset),0.28)
        if M.can_balance() then
            local options={}
            for _,v in ipairs(balances) do
                local item=U.button(v.name,'draftout_balance_preview',{key=v.key,lobby=M.open_lobby},2.5)
                if v.key==M.preview_ruleset then item.config.colour={0.40,0.27,0.34,1} end
                options[#options+1]=item
            end
            nodes[#nodes+1]=U.row(options)
        else nodes[#nodes+1]=U.line('Balance can be changed after this draft finishes.',0.23) end
        nodes[#nodes+1]=U.row({U.button('Apply settings','draftout_deck_apply',
            {key=M.preview_key,ruleset=M.preview_ruleset,lobby=M.open_lobby},4),
            U.button('Cancel','draftout_deck_close',nil,2.5)})
        if U.overlay then U.overlay(M,{n=G.UIT.C,config={align='cm'},nodes=nodes})
        else G.FUNCS.overlay_menu({definition=create_UIBox_generic_options({back_func='draftout_deck_close',contents=nodes})}) end
        M.overlay=G.OVERLAY_MENU
    end
    G.FUNCS.draftout_deck_open=function()
        if not M.can_select() then return end
        M.open_lobby=lobby()
        local selected=(lobby():get_metadata() or {}).deck
        M.preview_ruleset=(lobby():get_metadata() or {}).ruleset or 'ruleset_mp_balanced'
        M.preview_key='b_red'
        for _,c in ipairs(M.choices()) do if c.name==selected or c.key==selected then M.preview_key=c.key end end
        M.render()
    end
    G.FUNCS.draftout_deck_select=function(e)
        local data=e.config.ref_table
        if data.lobby~=lobby() or not M.can_select() then return end
        M.preview_key=data.key; M.render()
    end
    G.FUNCS.draftout_balance_preview=function(e)
        local data=e.config.ref_table
        if data.lobby~=lobby() or not M.can_balance() then return end
        for _,v in ipairs(balances) do
            if v.key==data.key then M.preview_ruleset=data.key;M.render();return end
        end
    end
    G.FUNCS.draftout_deck_apply=function(e)
        local data=e.config.ref_table
        local ok,err=pcall(M.select,data.key,data.lobby,data.ruleset)
        if ok then G.FUNCS.draftout_deck_close()
        else PVP.UI.UTILS.overlay_message(tostring(err):gsub('^.-:%d+: ','')) end
    end
    G.FUNCS.draftout_deck_enabled=function(e)
        e.config.button=M.can_select() and 'draftout_deck_open' or nil
    end
    function M.install()
        if M.installed or not (PVP.lobby and type(PVP.lobby.build_controls)=='function') then return end
        M.installed=true
        local native_picker=G.FUNCS.lobby_choose_deck
        M.native_picker=type(native_picker)=='function'
        if M.native_picker then
            G.FUNCS.lobby_choose_deck=function(e)
                if M.active(lobby()) and not M.can_select() then return end
                return native_picker(e)
            end
            local start_run=G.FUNCS.start_run
            G.FUNCS.start_run=function(e,args)
                if M.active(lobby()) and PVP.LOBBY.code and args and not args.mp_start then
                    if not M.can_select() or not M.synced() then return end
                    local result=start_run(e,args)
                    -- The native picker publishes a full metadata snapshot.
                    -- Wait for the server echo before allowing the match to start.
                    M.pending={lobby=lobby(),name=PVP.LOBBY.deck.back,stake=PVP.LOBBY.deck.stake}
                    return result
                end
                return start_run(e,args)
            end
        end
        if D.updates then D.updates.add('deck_preview_cleanup',function()
            if M.open_lobby and (M.open_lobby~=lobby() or G.OVERLAY_MENU~=M.overlay or not M.can_select()) then
                M.clear_preview();M.open_lobby=nil
            end
        end) end
        local change_ruleset=G.FUNCS.mp_pvp_change_ruleset
        if change_ruleset then
            G.FUNCS.mp_pvp_change_ruleset=function(e)
                if not M.active(lobby()) then return change_ruleset(e) end
                local option=balances[e.to_key]
                if not option then return end
                local ok,err=pcall(M.select_balance,option.key,lobby())
                if not ok and PVP.UI and PVP.UI.UTILS then PVP.UI.UTILS.overlay_message(tostring(err):gsub('^.-:%d+: ','')) end
            end
        end
        G.FUNCS.draftout_lobby_draft=function()
            local l=lobby()
            if not M.active(l) or l:is_game_started() or B.pending_launch or B.started then return end
            if D.tournament and D.tournament.current_board(l) then G.FUNCS.draftout_mp_open();return end
            if l.is_host and not B.session then
                local ok,err=pcall(B.begin)
                if not ok then B.message=tostring(err):gsub('^.-:%d+: ','') end
            end
            G.FUNCS.draftout_mp_open()
        end
        G.FUNCS.draftout_lobby_draft_enabled=function(e)
            local l=lobby()
            e.config.button=M.active(l) and not l:is_game_started() and not B.started and not B.pending_launch
                and 'draftout_lobby_draft' or nil
        end
        local original=PVP.lobby.build_controls
        function PVP.lobby.build_controls(...)
            local node=original(...)
            if not M.active(lobby()) then return node end
            if M.native_picker then
                local function contains_deck(n)
                    if n.config and n.config.id=='mp_pvp_choose_deck' then return true end
                    for _,child in ipairs(n.nodes or {}) do if contains_deck(child) then return true end end
                    return false
                end
                local function compact(n)
                    local c=n.config or {}
                    if c.minh then c.minh=math.min(c.minh,0.70) end
                    if c.padding then c.padding=math.min(c.padding,0.02) end
                    if n.n==G.UIT.T and c.scale then c.scale=math.min(c.scale,0.28) end
                    for _,child in ipairs(n.nodes or {}) do compact(child) end
                end
                -- Replace only the deck's existing column, preserving the native
                -- callback, guest-disabled state, and metadata-driven labels.
                local controls=node.nodes and node.nodes[1]
                if not lobby():is_game_started() and not B.started then
                    for i,slot in ipairs(controls and controls.nodes or {}) do
                        if contains_deck(slot) then
                            compact(slot)
                            local button=D.ui.button(D.tournament and D.tournament.current_board(lobby()) and 'Bracket' or 'Open draft','draftout_lobby_draft',nil,2.65)
                            button.config.id='draftout_lobby_draft'
                            button.config.func='draftout_lobby_draft_enabled'
                            button.config.colour={0.40,0.27,0.34,1}
                            button.config.minh=0.54;button.config.padding=0.02
                            button.nodes[1].config.scale=0.32
                            controls.nodes[i]={n=G.UIT.C,config={align='cm',padding=0,minw=2.65,minh=1.35},nodes={
                                {n=G.UIT.R,config={align='cm',padding=0.015},nodes={button}},
                                {n=G.UIT.R,config={align='cm',padding=0.015},nodes={slot}},
                            }}
                            break
                        end
                    end
                end
                return node
            end
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
                    if not lobby():is_game_started() and not B.started then
                        -- Split the existing 2.65 x 1.35 deck slot. Both controls
                        -- stay inside its footprint; no extra lobby rows.
                        n.config.minh=0.70
                        n.config.padding=0.02
                        label.config.scale=0.28
                        if value then value.config.scale=0.28 end
                        local button=D.ui.button(D.tournament and D.tournament.current_board(lobby()) and 'Bracket' or 'Open draft','draftout_lobby_draft',nil,2.65)
                        button.config.id='draftout_lobby_draft'
                        button.config.func='draftout_lobby_draft_enabled'
                        button.config.colour={0.40,0.27,0.34,1}
                        button.config.minh=0.54
                        button.config.padding=0.02
                        button.nodes[1].config.scale=0.32
                        return {n=G.UIT.C,config={align='cm',padding=0,minw=2.65,minh=1.35},nodes={
                            {n=G.UIT.R,config={align='cm',padding=0.015},nodes={button}},
                            {n=G.UIT.R,config={align='cm',padding=0.015},nodes={n}},
                        }}
                    end
                    return n
                end
                for i,child in ipairs(rows) do rows[i]=decorate(child) end
                return n
            end
            return decorate(node)
        end
    end
    return M
end

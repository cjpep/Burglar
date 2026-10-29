-- A native-style entry on PvP's private-lobby picker. Keep the registered Royale
-- game key: Burglar's session, draft and referee hooks already target that key.
-- This is a lobby-creation shortcut, not a new server queue or rules engine.
return function(D)
    if not (MPAPI and MPAPI.on_loaded) then return end
    MPAPI.on_loaded(function()
        if D.burglar_entry_installed or not (PVP and D.mpbridge
            and type(PVP.build_game_select_ui)=='function'
            and type(G.FUNCS.mp_pvp_create_lobby_royale)=='function'
            and type(MPAPI.ui_pillar_row)=='function') then return end
        D.burglar_entry_installed=true
        G.FUNCS.draftout_create_burglar_lobby=function()
            -- Delegate at click time to preserve native queue guards, setup,
            -- connection callbacks and any later compatible wrappers.
            return G.FUNCS.mp_pvp_create_lobby_royale()
        end
        local original=PVP.build_game_select_ui
        PVP.build_game_select_ui=function(intent,...)
            local page=original(intent,...)
            if intent~='create_lobby' then return page end
            local row=page and page.definition and page.definition.nodes and page.definition.nodes[1]
            if not (row and row.nodes) then return page end
            for _,column in ipairs(row.nodes) do
                local root=column.nodes and column.nodes[1]
                if root and root.config and root.config.id=='draftout_burglar' then return page end
            end
            local colour={222/255,148/255,130/255,1}
            local icon
            if G.j_locked and G.j_locked.pos and G.ASSET_ATLAS.Joker then
                icon=Sprite(0,0,0.80,1.1,G.ASSET_ATLAS.Joker,G.j_locked.pos)
            else
                icon=Sprite(0,0,1.1,1.1,G.ANIMATION_ATLAS.mp_player_blind_chip,{x=0,y=0})
            end
            local added=MPAPI.ui_pillar_row({items={{
                id='draftout_burglar',icon=icon,
                select=MPAPI.ui_pillar_select_button({label='CREATE',button='draftout_create_burglar_lobby'}),
                name_plate=MPAPI.ui_pillar_name_plate({lines='Burglar',
                    bg_colour=mix_colours(colour,G.C.BLACK,0.3),outline_colour=colour}),
                description=MPAPI.ui_pillar_description_box({
                    lines={'Draft your Jokers','Build your shop pool'},minh=1.3}),
                stat_box=MPAPI.ui_pillar_stat_box({label='Players',value='2 or 4',value_colour=G.C.MONEY}),
            }}})
            table.insert(row.nodes,1,added.row_node.nodes[1])
            local dispose=page.dispose
            local disposed=false
            page.dispose=function(self,...)
                if disposed then return end
                disposed=true
                added:dispose()
                if dispose then return dispose(self,...) end
            end
            return page
        end
    end)
end

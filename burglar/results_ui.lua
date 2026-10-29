-- Theme only Burglar's native PvP results. Keep the upstream result body,
-- winner/loss handling, player selector, deck viewer and leave buttons intact.
return function(D)
    if not (MPAPI and MPAPI.on_loaded) then return end
    MPAPI.on_loaded(function()
        if not (MPAPI.end_screen_uibox and PVP and PVP.UI) then return end
        local original=MPAPI.end_screen_uibox
        MPAPI.end_screen_uibox=function(config)
            if not (G.GAME and G.GAME.draftout_pool and config.body==PVP.UI.end_game_body) then
                return original(config)
            end
            local styled={};for key,value in pairs(config) do styled[key]=value end
            styled.bg_colour={0.025,0.040,0.055,1};styled.bg_alpha=0.65
            styled.win_fill={0.27,0.40,0.41,1};styled.win_outline={0.48,0.70,0.72,1}
            styled.title_colour=config.won and {0.74,0.87,0.83,1} or {0.86,0.89,0.93,1}
            local definition=original(styled)
            local function soften(node)
                if type(node)~='table' then return end
                local c=node.config
                if c and not c.button and (c.colour==G.C.BLACK or c.colour==G.C.JOKER_GREY) then
                    c.colour={0.18,0.28,0.31,0.94};c.r=0.10
                end
                for _,child in ipairs(node.nodes or {}) do soften(child) end
            end
            soften(definition)
            local body=definition.nodes and definition.nodes[1]
            if body and body.config then
                body.config.colour={0.27,0.40,0.41,1};body.config.r=0.12;body.config.padding=0.10
            end
            return definition
        end
    end)
end

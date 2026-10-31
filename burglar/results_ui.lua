-- Compact Burglar-only results; native selectors, stats, callbacks and lifecycle.
return function(D)
    if not (MPAPI and MPAPI.on_loaded) then return end
    MPAPI.on_loaded(function()
        if not (MPAPI.end_screen_uibox and PVP and PVP.UI) then return end
        local scale=0.78
        local function active() return G.GAME and G.GAME.draftout_pool end
        local function size_cards(area)
            for _,card in ipairs(area.cards or {}) do
                card:hard_set_T(nil,nil,G.CARD_W*scale,G.CARD_H*scale)
            end
        end
        -- The selector rebuilds the cards later, so keep its previews at the same size.
        local rebuild=MPAPI.rebuild_jokers_area
        MPAPI.rebuild_jokers_area=function(area,...)
            local result=rebuild(area,...)
            if area and area.burglar_results then size_cards(area) end
            return result
        end
        local function compact(node)
            if type(node)~='table' then return end
            local c=node.config
            if c then
                for _,k in ipairs({'minw','maxw','minh','maxh','w','h','padding','scale'}) do
                    if type(c[k])=='number' then c[k]=c[k]*scale end
                end
                if not c.button and (c.colour==G.C.BLACK or c.colour==G.C.JOKER_GREY) then
                    c.colour={0.16,0.25,0.28,0.96};c.r=0.10
                end
                local o=c.object
                if o and o==PVP.end_game_jokers then
                    o.burglar_results=true;o.T.w=5*G.CARD_W*scale;o.T.h=G.CARD_H*scale
                    o.config.card_w=G.CARD_W*scale;size_cards(o)
                elseif o and o.config and o.config.string and DynaText then
                    local opts={};for k,v in pairs(o.config) do opts[k]=v end
                    opts.scale=(opts.scale or 1)*scale
                    if opts.maxw then opts.maxw=opts.maxw*scale end
                    c.object=DynaText(opts);if o.remove then o:remove() end
                end
            end
            for _,child in ipairs(node.nodes or {}) do compact(child) end
        end
        local original=MPAPI.end_screen_uibox
        MPAPI.end_screen_uibox=function(config)
            if not (active() and config.body==PVP.UI.end_game_body) then return original(config) end
            local body=config.body(config.won);compact(body)
            local title=config.title_key or (config.draw and 'k_draw_title' or config.won and 'ph_you_win' or 'ph_game_over')
            local colour=config.draw and G.C.BLUE or config.won and {0.75,0.88,0.83,1} or {0.96,0.55,0.49,1}
            local no_esc=config.no_esc;if no_esc==nil then no_esc=config.won or config.draw end
            local definition=create_UIBox_generic_options({padding=0.08,no_back=true,no_esc=no_esc,
                bg_colour={0.025,0.04,0.055,0.78},colour={0.23,0.35,0.37,1},outline_colour={0.48,0.70,0.72,1},
                contents={
                    {n=G.UIT.R,config={align='cm',padding=0.06},nodes={
                        {n=G.UIT.T,config={text=localize(title),scale=0.65,colour=colour,shadow=true}}}},
                    body,
                }})
            -- Native restorable overlay / View Deck relies on this exact ID.
            definition.config.id=config.id or 'mpapi_end_screen'
            return definition
        end
    end)
end

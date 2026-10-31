-- Host-selected, saved per run. Native create_card owns the rolls and compatibility.
return function(D)
    local S={};D.stake_stickers=S
    local fields={enable_eternals_in_shop='stake_black',enable_perishables_in_shop='stake_orange',enable_rentals_in_shop='stake_gold'}
    function S.enabled()
        local l=MPAPI and MPAPI.get_current_lobby()
        if l then return (l:get_metadata() or {}).burglar_stake_stickers==true end
        return D.mod.config.stake_stickers==true
    end
    function S.apply(game,enabled)
        game.burglar_stake_stickers=enabled==true
        game.modifiers=game.modifiers or {}
        local active={}
        local stakes=G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake or {}
        for _,i in ipairs(game.applied_stakes or {}) do if stakes[i] then active[stakes[i].key]=true end end
        -- The actual chain, not numerical >= thresholds: custom stakes may be reordered.
        if not next(active) and SMODS.build_stake_chain and stakes[game.stake] then
            for i in pairs(SMODS.build_stake_chain(stakes[game.stake]) or {}) do
                if stakes[i] then active[stakes[i].key]=true end
            end
        end
        for flag,key in pairs(fields) do
            -- Keep equivalent modifiers from custom stakes; restore vanilla sticker
            -- tiers even when PvP's balanced stakes replace their modifier functions.
            game.modifiers[flag]=enabled==true and (active[key]==true or game.modifiers[flag]==true) or false
        end
    end
    function S.button()
        return D.ui.button('Stake stickers: '..(S.enabled() and 'On' or 'Off'),'burglar_stickers_toggle',nil,7.4,
            {text={'Eternal / Perishable / Rental from the selected stake.','Off by default. Native chances and Joker compatibility apply.'}})
    end
    G.FUNCS.burglar_stickers_toggle=function()
        local l=MPAPI and MPAPI.get_current_lobby()
        if l then
            if not l.is_host or l:is_game_started() or (D.tournament and D.tournament.board(l)) then return end
            if not (D.mpbridge and D.mpbridge.is_target(l)) then return end
            l:set_metadata({burglar_stake_stickers=not S.enabled()})
        else
            D.mod.config.stake_stickers=not S.enabled();SMODS.save_mod_config(D.mod)
        end
        D.ui.show()
    end
    return S
end

-- Showman is a Rare Wraith option during Draftout, never part of the draft.
-- Keep both rarity registries in sync and restore their original entries/order
-- outside the run. Native Wraith selection still handles locks/bans/duplicates.
return function(D)
    local M={}
    D.showman=M
    local key='j_ring_master'
    local function matches(entry) return entry==key or type(entry)=='table' and entry.key==key end
    local function remove(pool)
        for i=#pool,1,-1 do if matches(pool[i]) then table.remove(pool,i) end end
    end
    function M.set(active)
        if not active then
            if not M.center then return end
            for _,pool in ipairs(M.pools) do remove(pool) end
            for _,slot in ipairs(M.slots) do table.insert(slot.pool,math.min(slot.index,#slot.pool+1),slot.entry) end
            M.center.rarity=M.rarity
            M.center,M.pools,M.slots=nil,nil,nil
            return
        end
        if M.center then return end
        local center=G.P_CENTERS and G.P_CENTERS[key]
        if not center then return end
        M.center,M.rarity,M.pools,M.slots=center,center.rarity,{},{}
        local seen,registries={},{G.P_JOKER_RARITY_POOLS or {}}
        local objects=SMODS.ObjectTypes and SMODS.ObjectTypes.Joker
        if objects and objects.rarity_pools then registries[#registries+1]=objects.rarity_pools end
        local rare_pools={}
        for _,registry in ipairs(registries) do
            local rare=registry[3] or registry.Rare
            if rare and not seen[rare] then rare_pools[#rare_pools+1]=rare end
            for _,pool in pairs(registry) do
                if type(pool)=='table' and not seen[pool] then
                    seen[pool]=true;M.pools[#M.pools+1]=pool
                    for i,entry in ipairs(pool) do
                        if matches(entry) then M.slots[#M.slots+1]={pool=pool,index=i,entry=entry} end
                    end
                    remove(pool)
                end
            end
        end
        center.rarity=3
        for _,pool in ipairs(rare_pools) do
            local at=#pool+1
            for i,entry in ipairs(pool) do
                if type(entry)=='table' and (entry.order or math.huge)>(center.order or math.huge) then at=i;break end
            end
            table.insert(pool,at,center)
        end
    end
    function M.sync()
        local in_run=not G.STAGES or G.STAGE==G.STAGES.RUN
        M.set(in_run and G.GAME and not not G.GAME.draftout_pool)
    end
    local updates=assert(SMODS.load_file('draftout/updates.lua',D.mod.id))()(D)
    updates.add('showman',M.sync)
    return M
end

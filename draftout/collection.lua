-- Build only the Joker Collection from the run's immutable availability pool.
-- Native collection pagination retains this local list; shop/global pools stay intact.
local M={sort=1,sorts={'Collection order','Draft order','Name','Rarity'}}
local function roster()
    if not (G and G.STAGES and G.STAGE==G.STAGES.RUN and G.GAME) then return end
    local pool=G.GAME.draftout_pool
    return pool and type(pool.keys)=='table' and pool.keys or nil
end
-- Locate the native card rows by object identity, without depending on the
-- generic options wrapper's nesting or replacing Steamodded's page callback.
local function attach_sort(node,area,control)
    if type(node)~='table' then return end
    local nodes=node.nodes or node.contents or {}
    for _,child in ipairs(nodes) do
        for _,leaf in ipairs(type(child)=='table' and child.nodes or {}) do
            if leaf.config and leaf.config.object==area then
                table.insert(nodes,1,control);return true
            end
        end
        if attach_sort(child,area,control) then return true end
    end
end
local function sort_list(list,keys)
    if M.sort==1 then return end
    local positions,names={},{}
    for i,key in ipairs(keys) do positions[key]=i end
    for _,center in ipairs(list) do
        names[center.key]=tostring(localize({type='name_text',set='Joker',key=center.key})):lower()
    end
    local function rarity(center)
        return ({Common=1,Uncommon=2,Rare=3,Legendary=4})[center.rarity] or tonumber(center.rarity) or 0
    end
    table.sort(list,function(a,b)
        if M.sort==2 then return positions[a.key]<positions[b.key] end
        if M.sort==4 and rarity(a)~=rarity(b) then return rarity(a)>rarity(b) end
        if names[a.key]~=names[b.key] then return names[a.key]<names[b.key] end
        return a.key<b.key
    end)
end
function M.install()
    if M.installed or not (SMODS and SMODS.card_collection_UIBox and create_UIBox_your_collection_jokers) then return false end
    M.installed=true
    local original=create_UIBox_your_collection_jokers
    create_UIBox_your_collection_jokers=function(...)
        local keys=roster()
        if not keys then return original(...) end
        if M.pool~=G.GAME.draftout_pool then M.pool,M.sort=G.GAME.draftout_pool,1 end
        local allowed,list={},{}
        for _,key in ipairs(keys) do allowed[key]=true end
        for _,center in ipairs(G.P_CENTER_POOLS.Joker) do
            if allowed[center.key] then list[#list+1]=center end
        end
        sort_list(list,keys)
        -- A mod's config menu can leave Collection filtering active. The team
        -- browser must show the complete roster, including base-game Jokers.
        local context=G.ACTIVE_MOD_UI
        G.ACTIVE_MOD_UI=nil
        local ok,result=pcall(SMODS.card_collection_UIBox,list,{5,5,5},{
            no_materialize=true,h_mod=0.95,
            modify_card=function(card,center)
                card.bypass_discovery_center,card.bypass_discovery_ui,card.bypass_lock=true,true,true
                card.params=card.params or {}
                card.params.bypass_discovery_center,card.params.bypass_discovery_ui,card.params.bypass_lock=true,true,true
                -- The Collection's empty base table is truthy. Passing it as a
                -- front would create a default playing-card sprite over the Joker.
                card:set_sprites(center)
                card.sticker=get_joker_win_sticker(center)
            end,
        })
        G.ACTIVE_MOD_UI=context
        if not ok then error(result,0) end
        M.areas=G.your_collection
        attach_sort(result,M.areas[1],{n=G.UIT.R,config={align='cm'},nodes={
            create_option_cycle({label='Sort roster',options=M.sorts,w=4.5,text_scale=0.28,
                opt_callback='draftout_collection_sort',current_option=M.sort,colour=G.C.PURPLE or G.C.RED,
                no_pips=true,focus_args={nav='wide'}}),
        }})
        return result
    end
    G.FUNCS.draftout_collection_sort=function(e)
        local choice=e and e.cycle_config and e.cycle_config.current_option
        if not roster() or M.pool~=G.GAME.draftout_pool or M.areas~=G.your_collection
            or type(choice)~='number' or not M.sorts[choice] or choice==M.sort then return end
        M.sort=choice
        -- Re-enter the native collection builder to start the new order on page 1.
        G.FUNCS.your_collection_jokers()
    end
    return true
end
return M

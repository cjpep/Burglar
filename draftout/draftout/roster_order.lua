-- UI-only order of this seat's already confirmed Joker keys.
-- Do not send this ordering over MPAPI or change the game's draft pools.
local M={}
M.sorts={'Draft order','Rarity','Name','Custom'}
local function copy(keys)
    local out={};for i,key in ipairs(keys) do out[i]=key end;return out
end
function M.new(identity)
    return {identity=identity,keys={},custom={},sort='Draft order',selected=nil}
end
function M.sync(state,source,details)
    local selected_key=state.selected and state.keys[state.selected]
    local present,seen={},{}
    for _,key in ipairs(source or {}) do present[key]=true end
    local next_keys={}
    for _,key in ipairs(state.custom) do
        if present[key] and not seen[key] then
            next_keys[#next_keys+1]=key;seen[key]=true
        end
    end
    for _,key in ipairs(source or {}) do
        if not seen[key] then next_keys[#next_keys+1]=key;seen[key]=true end
    end
    state.custom=next_keys
    local keys=state.sort=='Custom' and copy(next_keys) or copy(source or {})
    if state.sort=='Rarity' or state.sort=='Name' then
        local names,rarities={},{}
        for _,key in ipairs(keys) do
            names[key]=tostring(details and details.name and details.name(key) or key):lower()
            rarities[key]=details and details.rarity and details.rarity(key) or 0
        end
        table.sort(keys,function(a,b)
            if state.sort=='Rarity' and rarities[a]~=rarities[b] then return rarities[a]>rarities[b] end
            if names[a]~=names[b] then return names[a]<names[b] end
            return a<b
        end)
    end
    state.keys,state.selected=keys,nil
    for i,key in ipairs(keys) do if key==selected_key then state.selected=i end end
    return keys
end
function M.set_sort(state,mode)
    for _,value in ipairs(M.sorts) do
        if mode==value then
            state.sort,state.selected,state.page=mode,nil,1
            return true
        end
    end
    return false
end
function M.choose(state,index)
    if index<1 or index>#state.keys then return false end
    if state.selected==nil then state.selected=index;return true end
    if state.selected==index then state.selected=nil;return true end
    local a=state.selected
    state.keys[a],state.keys[index]=state.keys[index],state.keys[a]
    state.custom=copy(state.keys)
    state.sort='Custom'
    state.selected=nil
    return true
end
return M

-- Older/replaced animation atlases may lack metadata used by SMODS 26.x.
-- Match SMODS.Atlas injection's image/cell dimension formula.
local C = {}
local function positive(value)
    return type(value) == 'number' and value == value and value > 0 and value < math.huge
end

function C.repair(atlas)
    if type(atlas) ~= 'table' or not atlas.image then return atlas end
    if atlas.columns == nil and positive(atlas.px) and atlas.image.getWidth then
        local ok, width = pcall(atlas.image.getWidth, atlas.image)
        if ok and positive(width) then atlas.columns = width / atlas.px end
    end
    if atlas.rows == nil and positive(atlas.py) and atlas.image.getHeight then
        local ok, height = pcall(atlas.image.getHeight, atlas.image)
        if ok and positive(height) then atlas.rows = height / atlas.py end
    end
    return atlas
end

function C.install(mp)
    local api = mp and mp.PLATFORM and mp.PLATFORM.BALATRO
    if not api or type(api.get_animation_atlas) ~= 'function' then return false end
    local original = api.get_animation_atlas
    api.get_animation_atlas = function(key)
        return C.repair(original(key))
    end
    return true
end

return C

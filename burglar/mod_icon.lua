-- Reuse the game's locked-Joker sprite for Burglar's active Mods-page badge.
-- Keep native load-failure badges and every other mod's icon unchanged.
local M={}
function M.install()
    if M.installed or type(getModtagInfo)~='function' then return false end
    M.installed=true
    local original=getModtagInfo
    function getModtagInfo(mod)
        local atlas,pos,message,vars=original(mod)
        if mod.id=='Draftout' and message=='load_success' and G.j_locked
            and G.j_locked.pos and G.ASSET_ATLAS and G.ASSET_ATLAS.Joker then
            return 'Joker',G.j_locked.pos,message,vars
        end
        return atlas,pos,message,vars
    end
    return true
end
return M

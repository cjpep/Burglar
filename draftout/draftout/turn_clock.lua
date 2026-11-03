-- Real-time turn clock, independent of the game speed and rendering.
local M = {}
function M.seconds(value)
    value = tonumber(value) or 0
    if value ~= value or value < 0 or value > 300 or value ~= math.floor(value) then return 0 end
    return value
end
-- Keep the chosen policy separate from this turn's resolved duration.
function M.setting(value) return value == 'scaling' and 'scaling' or M.seconds(value) end
function M.duration(setting, cards)
    if setting ~= 'scaling' then return M.seconds(setting) end
    if type(cards) ~= 'number' or cards ~= math.floor(cards) or cards < 1 or cards > 30 then return 0 end
    return cards * 5
end
function M.cards(state)
    local count=0
    for _,pack in ipairs(state.current) do count=math.max(count,#pack.cards) end
    return count
end
function M.new(setting)
    return {setting = M.setting(setting), seconds = M.seconds(setting)}
end
function M.reset(c, wave, now, cards)
    c.seconds = M.duration(c.setting,cards)
    c.wave, c.paused, c.remaining = wave, false, nil
    c.deadline = c.seconds > 0 and now + c.seconds or nil
end
function M.left(c, now)
    if not c or c.seconds == 0 then return nil end
    if c.paused then return c.remaining end
    return c.deadline and math.max(0, c.deadline - now) or nil
end
function M.update(c, now, pause)
    if not c or c.seconds == 0 then return false, false end
    local changed = false
    if pause and not c.paused then
        c.remaining, c.deadline, c.paused, changed = M.left(c, now), nil, true, true
    elseif not pause and c.paused then
        c.deadline, c.remaining, c.paused, changed = now + (c.remaining or 0), nil, false, true
    end
    return changed, not c.paused and c.deadline ~= nil and now >= c.deadline
end
return M

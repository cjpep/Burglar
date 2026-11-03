-- Fresh draft identities. Only the host draws randomness for a network draft.
-- The persisted counter also distinguishes drafts if another mod reseeds LÖVE.
return function(config, random)
    local alphabet, chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789', {}
    for i = 1, 16 do
        local index = random(#alphabet)
        chars[i] = alphabet:sub(index, index)
    end
    config.draft_serial = math.floor(tonumber(config.draft_serial) or 0) + 1
    return table.concat(chars) .. '-' .. string.format('%.0f', config.draft_serial)
end

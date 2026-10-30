-- Pure Lua 5.1-compatible draft state; no game globals and no networking.
local M = {}
M.SCHEMA = 6
local MODULUS = 2147483647

-- Copy IDs are draft identities only; never register them as game centers.
function M.key(id) return type(id)=='string' and (id:match('^(j_[%w_]+)#%d+$') or id) or id end
function M.has_copies(keys)
    local seen={}
    for _,id in ipairs(keys or {}) do local key=M.key(id);if seen[key] then return true end;seen[key]=true end
    return false
end

local function integer(n, lo, hi)
    return type(n) == "number" and n == math.floor(n) and n >= lo and n <= hi
end

function M.copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = M.copy(v) end
    return out
end

local function rng(seed)
    local h = 1
    for i = 1, #seed do h = (h * 31 + seed:byte(i)) % MODULUS end
    if h == 0 then h = 1 end
    return function(limit)
        h = h * 16807 % MODULUS
        return math.floor((h - 1) / (MODULUS - 1) * limit) + 1
    end
end

-- A fourth round has eight cards per seat, preserving exclusive ownership.
function M.round_size(round, rounds, size)
    return (size or 9) - (rounds == 4 and round == 4 and 1 or 0)
end
function M.roster_size(rounds, size)
    return (size or 9) * rounds - (rounds == 4 and 1 or 0)
end

-- Reverse only when a new set of packs opens, never after an individual pick.
function M.direction(round)
    return round % 2 == 1 and 1 or -1
end
function M.player_count(state) return state.player_count or 4 end
function M.pack_origin(seat, round, pick, player_count)
    return ((seat - 1 - (pick - 1) * M.direction(round)) % (player_count or 4)) + 1
end

function M.new(keys, options)
    local o = options or {}
    local size, rounds = o.pack_size or 9, o.packs_per_player or 3
    local players = o.player_count or 4
    assert(players == 2 or players == 4, "Drafts require two or four players")
    local picks = o.picks_per_turn or 1
    assert(integer(picks, 1, 2), "picks_per_turn must be 1 or 2")
    assert(integer(size, 1, 30), "pack_size must be an integer from 1 to 30")
    assert(integer(rounds, 1, 4), "packs_per_player must be an integer from 1 to 4")
    assert(rounds ~= 4 or size > 1, "Fourth-round packs must be nonempty")
    local deck, seen = {}, {}
    for _, key in ipairs(keys) do
        assert(type(key) == "string" and not seen[key], "Joker keys must be unique strings")
        seen[key], deck[#deck + 1] = true, key
    end
    local minimum=players*M.roster_size(rounds,size)
    assert(#deck >= minimum,
        "Not enough distinct Jokers: need " .. minimum .. ", have " .. #deck)
    table.sort(deck) -- Stable across clients regardless of registry iteration order.
    local seed = tostring(o.seed or "DRAFTOUT1")
    local random = rng(seed)
    for i = #deck, 2, -1 do
        local j = random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    local s = {
        schema = M.SCHEMA, player_count = players, seed = seed, pack_size = size, rounds = rounds, picks_per_turn = picks, total = minimum,
        round = 1, pick = 1, revision = 0, done = false,
        catalog=M.copy(keys), copy_limits=M.has_copies(keys),
        packs = {}, current = {}, submitted = {}, pools = {}, history = {},
    }
    for seat=1,players do s.pools[seat],s.history[seat]={},{} end
    local cursor = 1
    for round = 1, rounds do
        s.packs[round] = {}
        for seat = 1, M.player_count(s) do
            local pack = {id = "r" .. round .. "s" .. seat, cards = {}}
            -- Only the shuffled prefix enters the draft; the rest is unavailable.
            local count = M.round_size(round,rounds,size)
            for _ = 1, count do
                pack.cards[#pack.cards + 1], cursor = deck[cursor], cursor + 1
            end
            s.packs[round][seat] = pack
        end
    end
    s.current = M.copy(s.packs[1])
    return s
end

function M.token(s, seat)
    assert(integer(seat, 1, M.player_count(s)), "Invalid seat")
    return {round = s.round, pick = s.pick, pack_id = s.current[seat].id}
end

function M.validate_selection(s, seat, keys, token, partial)
    if not integer(seat, 1, M.player_count(s)) then return nil, "Invalid seat" end
    if s.done then return nil, "Draft has finished" end
    if s.submitted[seat] then return nil, "Seat has already picked" end
    local pack = s.current[seat]
    if type(token) ~= "table" or token.round ~= s.round or token.pick ~= s.pick
        or token.pack_id ~= pack.id then return nil, "Stale pick token" end
    local needed = math.min(s.picks_per_turn, #pack.cards)
    if type(keys) ~= 'table' or (partial and #keys > needed)
        or (not partial and #keys ~= needed) or needed == 0 then
        return nil, 'Choose ' .. needed .. ' Jokers from this pack'
    end
    local selected = {}
    for _, key in ipairs(keys) do
        if type(key) ~= 'string' or selected[key] then return nil, 'Choose different Jokers' end
        local found = false
        for _, candidate in ipairs(pack.cards) do if candidate == key then found = true; break end end
        if not found then return nil, 'Joker is not in this pack' end
        selected[key] = true
    end
    return true
end

-- Keep valid tentative choices and randomly fill any unselected slots.
-- The host/server is the only random source for an online timeout.
function M.auto_keys(s, seat, preferred, random)
    local pack, chosen, seen, remaining = s.current[seat], {}, {}, {}
    for _, key in ipairs(preferred or {}) do
        for _, candidate in ipairs(pack.cards) do
            if candidate == key and not seen[key] and #chosen < math.min(s.picks_per_turn, #pack.cards) then
                chosen[#chosen+1], seen[key] = key, true
            end
        end
    end
    for _, key in ipairs(pack.cards) do if not seen[key] then remaining[#remaining+1] = key end end
    while #chosen < math.min(s.picks_per_turn, #pack.cards) do
        chosen[#chosen+1] = table.remove(remaining, random(#remaining))
    end
    return chosen
end

function M.submit(s, seat, keys, token)
    local ok, err = M.validate_selection(s, seat, keys, token)
    if not ok then return nil, err end
    local pack, selected = s.current[seat], {}
    for _, key in ipairs(keys) do selected[key] = true end
    -- Keep the private timeline on the authority; ordinary snapshots omit it.
    local history_keys={}
    for i,key in ipairs(keys) do history_keys[i]=key end
    table.insert(s.history[seat],{round=s.round,pick=s.pick,pack_id=pack.id,keys=history_keys})
    -- Validate the entire selection before mutating anything.
    for _, key in ipairs(keys) do table.insert(s.pools[seat], key) end
    for i = #pack.cards, 1, -1 do if selected[pack.cards[i]] then table.remove(pack.cards, i) end end
    s.submitted[seat], s.revision = true, s.revision + 1
    for i = 1, M.player_count(s) do if not s.submitted[i] then return true end end
    s.submitted = {}
    local empty = true
    for i = 1, M.player_count(s) do if #s.current[i].cards > 0 then empty = false end end
    if empty then
        if s.round == s.rounds then s.done = true; return true end
        s.round, s.pick = s.round + 1, 1
        s.current = M.copy(s.packs[s.round])
    else
        local passed, direction = {}, M.direction(s.round)
        for from = 1, M.player_count(s) do passed[((from - 1 + direction) % M.player_count(s)) + 1] = s.current[from] end
        s.current, s.pick = passed, s.pick + 1
    end
    -- Empty seats wait automatically.
    for i = 1, M.player_count(s) do if #s.current[i].cards == 0 then s.submitted[i] = true end end
    return true
end

function M.next_seat(s)
    if s.done then return nil end
    for seat = 1, M.player_count(s) do if not s.submitted[seat] then return seat end end
end

function M.export_pool(s, seat)
    assert(s.done, "Complete the draft before arming a pool")
    assert(integer(seat, 1, M.player_count(s)), "Invalid seat")
    return {schema = 1, copy_limits=s.copy_limits, draft_schema = s.schema, player_count = M.player_count(s), rounds = s.rounds, seed = s.seed, seat = seat, keys = M.copy(s.pools[seat])}
end

-- Returns a key or nil. Eligibility (bans/owned cards) is supplied by the game adapter.
-- Missing rarity buckets are omitted rather than allowing a vanilla fallback Joker.
function M.sample(keys, centers, eligible, roll, weights, preferred)
    local buckets = {{}, {}, {}}
    local ids = {Common = 1, Uncommon = 2, Rare = 3}
    for _, key in ipairs(keys) do
        local c = centers[key]
        local r = c and (ids[c.rarity] or c.rarity)
        if buckets[r] and eligible(key, c) then table.insert(buckets[r], key) end
    end
    if preferred and buckets[preferred] and #buckets[preferred] > 0 then
        local b = buckets[preferred]
        return b[math.min(#b, math.floor(roll() * #b) + 1)]
    end
    local total = 0
    weights = weights or {0.7, 0.25, 0.05}
    for r = 1, 3 do if #buckets[r] > 0 then total = total + math.max(0, weights[r] or 0) end end
    if total == 0 then return nil end
    local target, cumulative = roll() * total, 0
    for r = 1, 3 do
        if #buckets[r] > 0 then
            cumulative = cumulative + math.max(0, weights[r] or 0)
            if target < cumulative then
                local b = buckets[r]
                return b[math.min(#b, math.floor(roll() * #b) + 1)]
            end
        end
    end
    return nil
end

return M

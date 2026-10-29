local C = dofile('draftout/core.lua')
local checks = 0
local function check(ok, msg) checks = checks + 1; assert(ok, msg) end
local eligible=dofile('draftout/vanilla_keys.lua')
local omissions={}
for picks=1,2 do for rounds=1,4 do for seed=1,100 do
    local options={seed=tostring(seed),picks_per_turn=picks,packs_per_player=rounds}
    local s=C.new(eligible,options)
    local replica=C.new(eligible,options)
    check(s.total==4*(rounds==4 and 35 or 9*rounds) and s.schema==6)
    local dealt,seen={},{}
    for round=1,rounds do for seat=1,4 do
        local pack=s.packs[round][seat]
        check(#pack.cards==(round==4 and 8 or 9),'Fourth pack has eight, others nine')
        for i,key in ipairs(pack.cards) do
            check(key==replica.packs[round][seat].cards[i],'Deterministic shuffle')
            check(not dealt[key],'Every dealt type is unique'); dealt[key]=true
        end
    end end
    local missing={}
    for _,key in ipairs(eligible) do if not dealt[key] then missing[#missing+1]=key end end
    if rounds==3 then
        check(#missing==33,'33 eligible types sit out each standard draft')
        omissions[table.concat(missing,'|')]=true
    end
    if rounds==4 then check(#missing==1,'Four packs leave one eligible type out') end
    while not s.done do
        local seat=C.next_seat(s)
        local token=C.token(s,seat)
        local direction=s.round%2==1 and 1 or -1
        local origin=((seat-1-(s.pick-1)*direction)%4)+1
        check(token.pack_id=='r'..s.round..'s'..origin,'Every pick follows the round direction')
        local chosen={}
        for i=1,math.min(picks,#s.current[seat].cards) do chosen[i]=s.current[seat].cards[i] end
        local revision,before,history=s.revision,#s.pools[seat],#s.history[seat]
        check(not C.submit(s,seat,{'j_forged'},token),'Foreign pick rejected')
        check(not C.submit(s,seat,{chosen[1],chosen[1]},token),'Duplicate/oversized pick rejected')
        check(s.revision==revision and #s.pools[seat]==before and #s.history[seat]==history,'Invalid pick is atomic')
        check(C.submit(s,seat,chosen,token))
        local entry=s.history[seat][#s.history[seat]]
        check(entry.round==token.round and entry.pick==token.pick and entry.pack_id==token.pack_id,'History records the accepted token')
        check(table.concat(entry.keys,'|')==table.concat(chosen,'|'),'History records both manual and auto choices')
        for _,key in ipairs(chosen) do check(dealt[key] and not seen[key],'Exclusive drafted ownership');seen[key]=true end
        check(not C.submit(s,seat,chosen,token),'Replayed pick rejected')
    end
    for seat=1,4 do check(#C.export_pool(s,seat).keys==(rounds==4 and 35 or 9*rounds),'Exact equal rosters') end
    check(s.revision==4*(math.ceil(9/picks)*math.min(rounds,3)+(rounds==4 and math.ceil(8/picks) or 0)),'Exact submissions for configured picks')
    for _,key in ipairs(missing) do check(not seen[key],'Undealt Jokers never enter rosters') end
end end end
local varied=0;for _ in pairs(omissions) do varied=varied+1 end
check(varied==100,'Different seeds vary which Jokers sit out')
-- Nine single picks circle four players twice, leaving each original owner the last card.
local s=C.new(eligible,{seed='PASS'})
local original=s.current[1].id
local function wave(d)
    for seat=1,4 do
        local chosen={};for i=1,math.min(d.picks_per_turn,#d.current[seat].cards) do chosen[i]=d.current[seat].cards[i] end
        check(C.submit(d,seat,chosen,C.token(d,seat)))
    end
end
for turn=1,8 do
    check(s.current[((turn-1)%4)+1].id==original,'Leftward pass')
    wave(s)
end
check(s.current[1].id==original and #s.current[1].cards==1,'Original final card comes home')
wave(s);check(s.round==2 and s.pick==1,'Open next round only after packs empty')
original=s.current[1].id;wave(s)
check(s.current[4].id==original,'Round two passes right')
-- Track every original pack through wraps, both pick counts and all four rounds.
for picks=1,2 do
    local d=C.new(eligible,{seed='ALTERNATE',picks_per_turn=picks,packs_per_player=4})
    while not d.done do
        local round,pick=d.round,d.pick
        for seat=1,4 do
            local expected=((seat-1-(pick-1)*(round%2==1 and 1 or -1))%4)+1
            check(d.current[seat].id=='r'..round..'s'..expected,'Direction stays fixed within each pack')
            check(C.pack_origin(seat,round,pick)==expected,'Recap origin matches physical passing')
        end
        wave(d)
    end
end
check(not pcall(C.new,eligible,{pack_size=12,packs_per_player=3}),'Reject insufficient unique catalog')
check(not pcall(C.new,eligible,{picks_per_turn=3}),'Reject invalid picks')
check(not pcall(C.new,{'same','same'},{pack_size=1,packs_per_player=1}),'Reject duplicates')
check(not pcall(C.export_pool,s,1),'Cannot export unfinished draft')
local centers = {a = {rarity = 1}, b = {rarity = 2}, c = {rarity = 3}}
local eligible = function() return true end
local roll = function() return 0.999 end
check(C.sample({'a'}, centers, eligible, roll) == 'a', 'Missing rare bucket stays in pool')
check(C.sample({'b'}, centers, eligible, roll, nil, 3) == 'b', 'Missing forced rarity stays in pool')
check(C.sample({'a','b','c'}, centers, function(k) return k == 'b' end, roll) == 'b')
check(C.sample({'a'}, centers, function() return false end, roll) == nil, 'Empty pool')
check(C.sample({'missing'}, centers, eligible, roll) == nil, 'Missing centers')
check(C.sample({'a','b','c'}, centers, eligible, roll, nil, 1) == 'a', 'Requested rarity')

local counts, state = {a = 0, b = 0, c = 0}, 7
local function random()
    state = state * 16807 % 2147483647
    return (state - 1) / 2147483646
end
for _ = 1, 20000 do
    local key = C.sample({'a','b','c'}, centers, eligible, random)
    counts[key] = counts[key] + 1
end
check(math.abs(counts.a / 20000 - 0.7) < 0.02, 'Common weight')
check(math.abs(counts.b / 20000 - 0.25) < 0.02, 'Uncommon weight')
check(math.abs(counts.c / 20000 - 0.05) < 0.01, 'Rare weight')
print('core_spec: ' .. checks .. ' assertions passed')

-- Verify the actual draft engine passes packs to the same numbered seats that
-- the UI's arrows indicate. Never infer the mechanics from the arrow glyphs.
local core=assert(loadfile('draftout/core.lua'))()
local keys={}
for i=1,160 do keys[i]=('j_test_%03d'):format(i) end
local s=core.new(keys,{seed='VISUAL-ARROW-REGRESSION',packs_per_player=4,picks_per_turn=1})
assert(core.direction(1)==1 and core.direction(2)==-1 and core.direction(3)==1 and core.direction(4)==-1,
    'round directions alternate')
local passes=0
for round=1,4 do
    assert(s.round==round, 'should start correct round')
    local to_direction=core.direction(round)
    local initial_count=core.round_size(round,4,9)
    for pick=1,initial_count do
        local before={}
        for seat=1,4 do before[seat]=s.current[seat].id end
        for seat=1,4 do
            assert(core.submit(s,seat,{s.current[seat].cards[1]},core.token(s,seat)), 'pick must be accepted')
        end
        if pick<initial_count then
            for from=1,4 do
                local to=((from-1+to_direction)%4)+1
                assert(s.current[to].id==before[from], 'pack passed to wrong seat')
                passes=passes+1
            end
        end
    end
end
assert(s.done and passes==4*(8+8+8+7),'expected complete four-round draft and correct transfers')
print('Pack passing verified: '..passes..' transfers, alternating round direction')

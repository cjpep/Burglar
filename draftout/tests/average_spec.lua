local A=dofile('draftout/average.lua')
local checks=0
local function test(values,losing,average)
    local players={}
    for i,v in ipairs(values) do players[i]={id=tostring(i),score=v} end
    local rank=A.rank(players)
    local expected={}; for _,id in ipairs(losing) do expected[tostring(id)]=true end
    for _,p in ipairs(players) do
        checks=checks+1; assert(not not rank.is_loser[p.id]==not not expected[p.id])
    end
    if average then checks=checks+1; assert(rank.average==average,rank.average) end
end
test({400,400,400,100},{4},'325')
test({400,300,200,100},{3,4},'250')
test({1000,100,100,100},{2,3,4},'325')
test({0,100,100,200},{1},'100')
test({100,100,100,100},{},'100')
test({0,0,0,0},{},'0')
test({10,15,20},{1},'15')
test({100,101},{1},'100.5')
test({100,100},{},'100')
test({9007199254740992,9007199254740992,9007199254740992,9007199254740994},{1,2,3})
test({'1e300','1e300','1e300','4e300'},{1,2,3},'1.75e300')
test({'1e10000','1e10000','1e10000','2e10000'},{1,2,3},'1.25e10000')
test({1000,{coeffiocient=1,exponent=3,e_count=0},1000,1000},{},'1000')
-- Sparse exponents do not allocate a billion zero digits.
test({'1e1000000000',0,0,0},{2,3,4},'2.5e999999999')
print('average_spec: '..checks..' assertions passed')

-- Exact comparisons for nonnegative ordinary/scientific score components.
-- Sparse base-1e6 digits avoid floating overflow and do not round the mean
-- before comparing: a player is unsafe iff score * alive_count < total.
local A,BASE,WIDTH={},1000000,6
local function add_chunk(out,index,value)
    while value>0 do
        local sum=(out[index] or 0)+value
        out[index],value=sum%BASE,math.floor(sum/BASE)
        if out[index]==0 then out[index]=nil end
        index=index+1
    end
end
local function chunks(score)
    local c,e,layers
    if type(score)=='table' then c,e,layers=score.coeffiocient,score.exponent,score.e_count
    else c,e,layers=score,0,0 end
    assert((layers or 0)==0,'Burglar average requires ordinary/scientific scores')
    local raw=type(c)=='number' and string.format('%.17g',c) or tostring(c)
    local mantissa,power=raw:lower():match('^([^e]+)e([+-]?%d+)$')
    if mantissa then raw=mantissa; e=(tonumber(e) or 0)+tonumber(power) end
    e=tonumber(e) or 0
    assert(e==math.floor(e) and math.abs(e)<1e12,'Invalid score exponent')
    local whole,part=raw:match('^%+?(%d+)%.?(%d*)$')
    assert(whole,'Invalid or negative score')
    local digits=(whole..part):gsub('^0+','')
    if digits=='' then return {} end
    e=e-#part
    local index=math.floor(e/WIDTH)
    digits=digits..string.rep('0',e-index*WIDTH)
    local out={}
    for last=#digits,1,-WIDTH do
        local value=tonumber(digits:sub(math.max(1,last-WIDTH+1),last))
        if value>0 then out[index]=value end
        index=index+1
    end
    return out
end
local function compare(x,y)
    local highest
    for i,v in pairs(x) do if v~=(y[i] or 0) and (not highest or i>highest) then highest=i end end
    for i,v in pairs(y) do if v~=(x[i] or 0) and (not highest or i>highest) then highest=i end end
    if not highest then return 0 end
    return (x[highest] or 0)>(y[highest] or 0) and 1 or -1
end
local function times(x,n)
    local out={}
    for i,v in pairs(x) do add_chunk(out,i,v*n) end
    return out
end
local function display(total,n)
    local highest
    for i in pairs(total) do if not highest or i>highest then highest=i end end
    if not highest then return '0' end
    local mantissa=(total[highest] or 0)+(total[highest-1] or 0)/BASE+(total[highest-2] or 0)/(BASE*BASE)
    mantissa=mantissa/n
    local exponent=highest*WIDTH
    while mantissa>=10 do mantissa=mantissa/10; exponent=exponent+1 end
    while mantissa<1 do mantissa=mantissa*10; exponent=exponent-1 end
    if exponent>=-4 and exponent<9 then
        return string.format('%.6f',mantissa*math.pow(10,exponent)):gsub('0+$',''):gsub('%.$','')
    end
    return string.format('%.6g',mantissa)..'e'..exponent
end
function A.rank(players)
    local parsed,total,ranked={},{},{}
    for _,p in ipairs(players) do
        local value=chunks(p.score)
        parsed[p.id]=value; ranked[#ranked+1]=p
        for i,v in pairs(value) do add_chunk(total,i,v) end
    end
    table.sort(ranked,function(x,y)
        local cmp=compare(parsed[x.id],parsed[y.id])
        return cmp<0 or (cmp==0 and x.id<y.id)
    end)
    local losers,is_loser={},{}
    for _,p in ipairs(ranked) do
        if compare(times(parsed[p.id],#ranked),total)<0 then
            losers[#losers+1]=p; is_loser[p.id]=true
        end
    end
    return {ranked=ranked,losers=losers,is_loser=is_loser,cutoff_idx=#losers,
        average=#ranked>0 and display(total,#ranked) or '0'}
end
return A

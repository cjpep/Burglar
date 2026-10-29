-- Plain-data transport for the read-only spectator prototype. No game globals.
-- Every frame is complete: a lost frame never requires replaying a missed action.
local W={VERSION=2,DELAY=5,INTERVAL=0.25,LEASE=12,CHUNK=4000,PARTS=24,MAX_QUEUE=32}
W.GROUPS={'jokers','consumeables','hand','play','shop_jokers','shop_vouchers','shop_booster','pack_cards'}
local function integer(x,lo,hi)
    return type(x)=='number' and x==math.floor(x) and x>=lo and x<=hi
end
W.integer=integer
local function str(x,n) return type(x)=='string' and #x<=n end
local function array(t,max)
    if type(t)~='table' or #t>max then return false end
    local count=0
    for k in pairs(t) do
        if not integer(k,1,#t) then return false end
        count=count+1
    end
    return count==#t
end
-- Copy declared fields only. Untrusted tables never become engine objects.
function W.frame(value)
    if type(value)~='table' or value.version~=W.VERSION or not integer(value.ante,0,1000000)
        or not integer(value.deck,0,100000) or not integer(value.total,0,100000)
        or type(value.areas)~='table' then return end
    local out={version=W.VERSION,ante=value.ante,deck=value.deck,total=value.total,areas={}}
    for _,key in ipairs({'phase','score','target','dollars','hands','discards','lives','blind'}) do
        if not str(value[key],100) then return end
        out[key]=value[key]
    end
    for _,key in ipairs({'hand_chips','hand_mult','hand_name'}) do
        if value[key]~=nil and not str(value[key],100) then return end
        out[key]=value[key] or ''
    end
    for _,group in ipairs(W.GROUPS) do
        local a=value.areas[group]
        if not array(a,24) then return end
        out.areas[group]={}
        for i,card in ipairs(a) do
            if type(card)~='table' or not str(card.name,100) or not str(card.center,100)
                or not str(card.front,100) or not str(card.edition,80) or not str(card.seal,80)
                or not str(card.detail,240) or not str(card.price,40)
                or type(card.hidden)~='boolean' or type(card.debuff)~='boolean' then return end
            if card.uid~=nil and not str(card.uid,64) then return end
            out.areas[group][i]={name=card.name,center=card.center,front=card.front,
                edition=card.edition,seal=card.seal,detail=card.detail,price=card.price,
                hidden=card.hidden,debuff=card.debuff,uid=card.uid or (group..':'..i),selected=card.selected==true}
        end
    end
    return out
end
function W.split(text)
    if type(text)~='string' or #text>W.CHUNK*W.PARTS-100 then return end
    local parts,start={},1
    while start<=#text do
        local last=math.min(#text,start+W.CHUNK-1)
        -- Keep UTF-8 characters whole when each chunk is JSON encoded by MPAPI.
        while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<=191 do last=last-1 end
        if last<start then return end
        parts[#parts+1]=text:sub(start,last);start=last+1
    end
    if #parts==0 or #parts>W.PARTS then return end
    return parts
end
function W.receiver()
    return {assemblies={},queue={},last=0}
end
function W.expire(r,now)
    for seq,a in pairs(r.assemblies) do
        if now-a.at>4 then r.assemblies[seq]=nil end
    end
end
function W.accept(r,p,now,decode)
    if type(p)~='table' or not integer(p.seq,1,2147483647) or p.seq<=r.last
        or not integer(p.parts,1,W.PARTS) or not integer(p.part,1,p.parts)
        or not str(p.text,W.CHUNK) or #p.text==0 then return end
    W.expire(r,now)
    local a=r.assemblies[p.seq]
    if not a then
        local count=0;for _ in pairs(r.assemblies) do count=count+1 end
        if count>=4 then return end
        a={at=now,parts=p.parts,values={},count=0};r.assemblies[p.seq]=a
    end
    if a.parts~=p.parts then return end
    if a.values[p.part] then return end -- Identical and conflicting duplicates are ignored.
    a.values[p.part]=p.text;a.count=a.count+1
    if a.count~=a.parts then return end
    r.assemblies[p.seq]=nil
    local ok,decoded=pcall(decode,table.concat(a.values))
    local frame=ok and W.frame(decoded)
    if not frame then return end
    r.last=p.seq
    for seq in pairs(r.assemblies) do if seq<=r.last then r.assemblies[seq]=nil end end
    -- Delay starts at COMPLETE receipt, so no fragment can shorten the buffer.
    r.queue[#r.queue+1]={due=now+W.DELAY,frame=frame,seq=p.seq}
    while #r.queue>W.MAX_QUEUE do table.remove(r.queue,1) end
    r.received=now
    return true
end
function W.due(r,now)
    local next_frame
    while r.queue[1] and r.queue[1].due<=now do
        next_frame=table.remove(r.queue,1)
    end
    return next_frame and next_frame.frame
end
return W

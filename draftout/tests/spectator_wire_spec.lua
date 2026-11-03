local W=dofile('draftout/spectator_wire.lua')
local checks=0
local function check(v,msg) checks=checks+1;assert(v,msg) end
local function frame()
    local f={version=W.VERSION,ante=3,deck=44,total=52,phase='shop',score='100',target='1000',
        dollars='20',hands='4',discards='3',lives='2',blind='PvP',areas={}}
    for _,k in ipairs(W.GROUPS) do f.areas[k]={} end
    f.areas.jokers[1]={name='Joker',center='j_joker',front='',edition='',seal='',price='2',
        hidden=false,debuff=false,detail='mult: 4'}
    return f
end
local function accept(r,seq,part,parts,text,t,decode)
    return W.accept(r,{seq=seq,part=part,parts=parts,text=text},t,decode or function() return frame() end)
end
local r=W.receiver()
check(not accept(r,1,2,3,'two',0),'Incomplete frame waits')
check(not accept(r,1,2,3,'duplicate',0),'Duplicate cannot count twice')
check(not accept(r,1,1,3,'one',1),'Reordered chunks wait')
check(accept(r,1,3,3,'three',2),'All reordered parts assemble')
check(not W.due(r,6.99),'No early display')
check(W.due(r,7).dollars=='20','Delay from last fragment, not first')
check(not accept(r,1,1,1,'again',9),'Completed frame never replays')
check(not accept(r,2,1,1,'bad',9,function() error('bad JSON') end),'Malformed JSON rejected')
check(not accept(r,3,1,1,'bad',9,function() return {version=W.VERSION} end),'Invalid schema rejected')
check(not accept(r,4,1,10000,'x',9),'Oversize fragment count rejected')
check(not accept(r,4,1,1,string.rep('x',W.CHUNK+1),9),'Oversize fragment rejected')
check(not accept(r,0/0,1,1,'x',9),'NaN sequence rejected')
check(not accept(r,math.huge,1,1,'x',9),'Infinite sequence rejected')
for i=10,15 do accept(r,i,1,2,'partial',10) end
local count=0;for _ in pairs(r.assemblies) do count=count+1 end
check(count==4,'Incomplete frames have a fixed memory cap')
W.expire(r,15)
check(next(r.assemblies)==nil,'Incomplete frames expire')
for i=20,100 do accept(r,i,1,1,'full',i/100) end
check(#r.queue==W.MAX_QUEUE,'Delayed queue has a fixed memory cap')
check(W.due(r,100)~=nil and #r.queue==0,'Backlog skips to latest due complete frame')
check(accept(r,102,1,1,'new',101),'New frame accepted')
check(not accept(r,101,1,1,'late',101),'Late older frame cannot replace newer')
local f=frame();f.areas.jokers[1].ability=function() error('never run') end
check(W.frame(f).areas.jokers[1].ability==nil,'Unknown executable fields are discarded')
f.areas.hand=setmetatable({},{})
for i=1,25 do f.areas.hand[i]=f.areas.jokers[1] end
check(not W.frame(f),'Oversize card group rejected')
f=frame();f.areas.hand={[1000000]=f.areas.jokers[1]}
check(not W.frame(f),'Sparse arrays rejected')
local utf=string.rep('x',3999)..'\240\159\131\143'..string.rep('y',4100)
local parts=W.split(utf)
check(table.concat(parts)==utf,'UTF-8 survives fragmentation')
check(#parts[1]==3999,'Multibyte character stays in one fragment')
check(not W.split(string.rep('x',W.CHUNK*W.PARTS+1)),'Oversize encoded frame rejected')
print('spectator_wire_spec: '..checks..' checks passed')

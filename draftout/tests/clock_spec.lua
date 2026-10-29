local C=dofile('draftout/turn_clock.lua')
local core=dofile('draftout/core.lua')
local checks=0
local function check(x,msg) checks=checks+1; assert(x,msg) end
local c=C.new(30)
C.reset(c,'1:1',100)
check(C.left(c,110)==20)
local changed,expired=C.update(c,111,true)
check(changed and not expired and C.left(c,999)==19,'Disconnect pauses remaining time')
changed,expired=C.update(c,1000,false)
check(changed and not expired and C.left(c,1000)==19,'Reconnect resumes without consuming paused time')
check(select(2,C.update(c,1020,false)),'Expiration uses wall-clock time')
local off=C.new(0); C.reset(off,'1:1',0)
check(C.left(off,999)==nil and not select(2,C.update(off,999,false)),'Default off never picks')
check(C.seconds(0/0)==0 and C.seconds(301)==0 and C.seconds(-1)==0,'Invalid durations disabled')
local keys=dofile('draftout/vanilla_keys.lua')
local s=core.new(keys,{seed='AUTO',picks_per_turn=2})
local key=s.current[1].cards[4]
local token=core.token(s,1)
check(core.validate_selection(s,1,{key},token,true),'One tentative choice is valid')
check(not core.validate_selection(s,1,{s.current[2].cards[1]},token,true),'Foreign intent rejected')
local picked=core.auto_keys(s,1,{key},function(n) return n end)
check(#picked==2 and picked[1]==key and picked[1]~=picked[2],'Timeout keeps choice and fills missing slot')
check(core.submit(s,1,picked,token))
check(not core.validate_selection(s,1,{},token,true),'Cannot edit submitted intent')
while not s.done do
    local seat=core.next_seat(s)
    check(core.submit(s,seat,core.auto_keys(s,seat,{},function(n) return n end),core.token(s,seat)))
end
local seen,count={},0
for seat=1,4 do for _,v in ipairs(s.pools[seat]) do check(not seen[v]); seen[v]=true; count=count+1 end end
check(count==108,'Fully automatic draft deals only 108 selected cards')
-- Scaling follows available choices, not turn number, and resolves only on reset.
check(C.setting('scaling')=='scaling' and C.duration('scaling',9)==45)
check(C.duration('scaling',1)==5 and C.duration('scaling',8)==40)
check(C.duration('scaling',0)==0 and C.duration('scaling',0/0)==0)
for picks=1,2 do
    local draft=core.new(keys,{seed='SCALING',packs_per_player=4,picks_per_turn=picks})
    local timer=C.new('scaling')
    local now=100
    C.reset(timer,'1:1',now,C.cards(draft))
    while not draft.done do
        local round,pick=draft.round,draft.pick
        local count=#draft.current[1].cards
        check(timer.seconds==5*count and timer.deadline==now+5*count,'Exact scaling duration')
        check(C.left(timer,now+1)==5*count-1)
        local before=timer.deadline
        for seat=1,4 do
            check(core.submit(draft,seat,core.auto_keys(draft,seat,{},function(n) return n end),core.token(draft,seat)))
            check(timer.deadline==before,'Confirming cannot shorten the active countdown')
        end
        if not draft.done then
            now=now+1
            C.reset(timer,draft.round..':'..draft.pick,now,C.cards(draft))
            if draft.round~=round then check(timer.seconds==(draft.round==4 and 40 or 45),'New pack restores starting time') end
        end
    end
end
local paused=C.new('scaling'); C.reset(paused,'wave',100,1)
C.update(paused,102,true);check(C.left(paused,999)==3,'Scaling pause retains exact remaining time')
C.update(paused,1000,false);check(paused.deadline==1003 and paused.seconds==5)
print('clock_spec: '..checks..' assertions passed')

-- Bounded, opt-in, local-only diagnostics; no game or filesystem required.
local make=assert(loadfile('draftout/diagnostics.lua'))()
local files,writes,clock={},0,1
SMODS={version='1.0.0-beta-1814a',Mods={MultiplayerAPI={version='1.0.0'},MultiplayerPvP={version='1.0.0'}}}
love={filesystem={
 createDirectory=function() return true end,
 getInfo=function(p) return files[p] and {size=#files[p]} end,
 read=function(p) return files[p] end,
 write=function(p,s) writes=writes+1;files[p]=s;return true end,
 append=function(p,s) writes=writes+1;files[p]=(files[p] or '')..s;return true end,
},system={setClipboardText=function(s) clipboard=s end}}
local D={mod={version='0.19.0',config={}},now=function()return clock end,
 mpbridge={phase='draft',session='SECRET_SESSION',ids={'SECRET_ID','OTHER_ID'},
 lobby={player_id='SECRET_ID',host_id='OTHER_ID'}}}
local L=make(D)
D.diag('enabled');L.tick();assert(writes==0 and L.count==0,'Disabled diagnostics perform no I/O or recording')
L.set_enabled(true)
assert(writes>0 and L.count==1)
D.diag('packet_receive',{kind='view',seat=1,seq=7,chat='SECRET_CHAT',seed='SECRET_SEED',pool={'SECRET_JOKER'}})
D.diag('SECRET_EVENT',{kind='view'})
D.diag('packet_receive',{kind='SECRET_KIND',reason='SECRET_ERROR',seat='SECRET_NAME',seq=0/0,lives=math.huge})
local log=L.text()
assert(not log:find('SECRET') and not log:find('OTHER_ID'),'Diagnostic output must not disclose identifiers or arbitrary fields')
assert(log:find('kind=view') and log:find('self=1') and log:find('host=2') and log:find('session=1'))
for i=1,1000 do D.diag('report_accept',{seq=i,kind='pvp_play_hand'}) end
assert(L.count==256 and #L.pending<=256 and L.pending_bytes<128*1024)
log=L.text();assert(log:find('seq=1000') and not log:find('seq=100 '),'Ring retains most recent events')
-- Fill disk file repeatedly: each write batch rotates within the fixed budget.
for batch=1,20 do
 for i=1,256 do D.diag('report_accept',{seq=i,kind='pvp_play_hand'}) end
 L.flush()
end
assert(files['draftout-diagnostics/previous.log'],'Full log should rotate')
for _,s in pairs(files) do assert(#s<=L.max_bytes,'Files must stay bounded') end
local before=writes
L.tick();local after=writes
for i=1,600 do L.tick() end
assert(writes==after,'Repeated frames do not cause repeated writes')
assert(L.copy() and clipboard==L.text())
L.set_enabled(false);before=writes
for i=1,100 do D.diag('packet_receive');L.tick() end
assert(writes==before and #L.pending==0)
-- Write failure cannot crash play, leak unbounded buffers or lose copy access.
love.filesystem.append=function() error('disk unavailable') end
L.set_enabled(true)
for i=1,1000 do D.diag('packet_receive') end
L.flush();assert(L.status=='File unavailable; use Copy log' and #L.pending<=256)
assert(L.copy())
love.system.setClipboardText=function() error('clipboard unavailable') end
assert(not L.copy())
-- Epochs are anonymous, and enabling halfway through a run captures context.
D.average_pvp={session='SECRET_SESSION',run='SECRET_RUN'}
clock=2;L.tick();assert(L.text():find('run=1') and not L.text():find('SECRET'))
D.average_pvp.run='ANOTHER_SECRET_RUN';clock=3;L.tick()
assert(L.text():find('run=2'))
local nl={is_host=true,player_id='SECRET_ID',host_id='SECRET_ID',get_metadata=function()
 return {draftout_bracket={token='SECRET_TOKEN',players={{id='SECRET_ID'}}}} end}
D.roster_duel={enabled=true,lobby=nl,started={run='BRACKET_SECRET_RUN'},in_run=function()return true end}
PVP={REF={players={SECRET_ID={lives=3,hands_left=2,ante=4,is_ready=true}}}}
G={GAME={round_resets={ante=4}}}
clock=4;L.tick()
assert(L.text():find('ready=1') and L.text():find('lives=3') and not L.text():find('SECRET'))
print('Diagnostics privacy, disabled behavior, bounds, rotation and failure isolation passed')

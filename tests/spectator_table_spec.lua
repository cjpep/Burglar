local W=dofile('burglar/spectator_wire.lua')
local M=dofile('burglar/spectator_table.lua')
local checks=0
local function check(v,msg) checks=checks+1;assert(v,msg) end
local f={phase='selecting hand',areas={}}
for _,k in ipairs(W.GROUPS) do f.areas[k]={} end
local c={uid='card:1',name='Ace',center='c_base',front='H_A'}
f.areas.hand={c}
local s=M.new();M.apply(s,f,'one',0);M.step(s,1,true)
local card=s.cards['card:1'];local before=card.y
f.areas.hand={};f.areas.play={c};M.apply(s,f,'one',1)
check(s.cards['card:1']==card,'Same visual object follows a card between zones')
M.step(s,0.05,false)
check(card.y<before and card.y>card.target.y,'Card eases toward play area')
M.step(s,1,true);check(card.y==card.target.y,'Reduced motion snaps to latest position')
f.areas.play={};M.apply(s,f,'one',2);M.step(s,1,true)
check(s.cards['card:1']==nil,'Departed card is removed')
f.areas.hand={c};M.apply(s,f,'two',3)
check(s.cards['card:1']~=card,'Switching players cannot reuse prior scene')
local before_y=M.layout(f)[1].y;c.selected=true
check(M.layout(f)[1].y<before_y,'Selected cards are raised')
for _,phase in ipairs({'selecting hand','shop','buffoon pack'}) do
 f.phase=phase
 for _,group in ipairs(W.GROUPS) do
  f.areas[group]={}
  for i=1,24 do f.areas[group][i]={uid=group..i,name='Card'} end
 end
 for _,v in ipairs(M.layout(f)) do
  check(v.x>=3.8 and v.x+v.w<=15.61 and v.y>=0 and v.y+v.h<8,'Dense layouts stay inside the table')
 end
end
-- Capturing an object twice does not change the source or consume RNG.
math.random=function() error('RNG used') end
G={STATE=1,STATES={SHOP=2,BLIND_SELECT=3,SELECTING_HAND=1},GAME={round_resets={ante=3},
 current_round={},blind={}},hand={cards={}},play={cards={}}}
PVP={GAME={lives=2}}
local C=dofile('burglar/spectator_capture.lua')(W)
local native={config={center_key='c_base'},base={value='Ace',suit='Hearts'},ability={},highlighted=true}
G.hand.cards={native};local a=C.capture()
G.hand.cards={};G.play.cards={native};local b=C.capture()
check(a.areas.hand[1].uid==b.areas.play[1].uid,'Source identity survives movement')
check(a.areas.hand[1].selected and native.highlighted,'Highlight is copied without mutation')
native.facing='back';local hidden=C.capture().areas.play[1]
check(hidden.center=='' and hidden.front=='' and hidden.detail=='' and hidden.name=='Face down','Hidden cards do not expose identity/art values')
local status={target='p2',receiver={queue={{due=5}}}}
local badge,detail=M.feed_status(status,2)
check(badge=='BUFFERING' and detail:find('3s',1,true),'Buffer countdown uses local release deadline')
status.frame={};status.receiver.received=3
check(M.feed_status(status,10)=='5s+ DELAY','Fresh received frames show delayed status')
check(M.feed_status(status,16)=='FEED STALLED','Old board is labelled stalled without another packet')
status.target=nil;check(M.feed_status(status,16)=='NOT WATCHING','Disconnected view cannot claim live feed')
local function pf(phase,count,hand)
 local out={phase=phase,areas={}}
 for _,k in ipairs(W.GROUPS) do out.areas[k]={} end
 for i=1,count do out.areas.pack_cards[i]={uid='pack'..i} end
 if hand then out.areas.hand={{uid='hand1'}} end
 return out
end
local twelve=M.layout(pf('buffoon pack',12,false));local ys={}
for _,c in ipairs(twelve) do ys[c.y]=true end
local rows=0;for _ in pairs(ys) do rows=rows+1 end
check(#twelve==12 and rows==2,'Large packs without a hand use two rows')
local tarot=M.layout(pf('tarot pack',5,true))
check(#tarot==6 and tarot[6].group=='hand','Pack view preserves the hand for card-targeting effects')
local scene=M.new();M.apply(scene,pf('shop',0), 'a',0)
M.apply(scene,pf('buffoon pack',3),'a',1)
check(scene.notice and scene.notice.text=='Buffoon Pack','Phase transition notice uses displayed frames')
M.apply(scene,pf('shop',0),'b',2)
check(scene.notice==nil,'Switching targets clears the previous player activity notice')
print('spectator_table_spec: '..checks..' checks passed')

-- Offline UI layout and roster behavior checks; no game executable needed.
G={UIT={C=1,R=2,O=3,T=4,B=5},CARD_W=1.4,CARD_H=2.0,
 C={WHITE={1,1,1,1},BLACK={0,0,0,1},CLEAR={0,0,0,0},BLUE={0,0,1,1},PURPLE={1,0,1,1},GREEN={0,1,0,1},RED={1,0,0,1},UI={BACKGROUND_INACTIVE={0,0,0,1},TEXT_LIGHT={1,1,1,1}}},
 P_CENTERS={a={key='a'},b={key='b'},c={key='c'},d={key='d'}},ROOM={T={x=0,y=0}},FUNCS={}}
-- allow G.CARD_W instead of G.C.CARD_W
function CardArea(x,y,w,h,opts)
 return {T={x=x,y=y,w=w,h=h},cards={},emplace=function(self,c) c.area=self;table.insert(self.cards,c) end}
end
function Card(x,y,w,h,front,center,opts)
 return {T={x=x,y=y,w=w,h=h},states={drag={},hover={}},
 juice_up=function() end}
end
local root='draftout/'
SMODS={load_file=function(path)
 if path=='draftout/pack_opening.lua' then return function()
     return function() return {rounds={},get=function() return {} end,running=function() return false end} end
 end end
 if path=='draftout/updates.lua' then return function()
     return function() return {add=function() end} end
 end end
 return assert(loadfile(path))
end}
local D={ui={},mod={id='Draftout',config={pack_effects=false}},core={copy=function(v)return v end}, now=function() return 2 end,mode='mp',updates={add=function()end}}
D.ui.row=function(nodes) return {n=G.UIT.R,config={align='cm'},nodes=nodes} end
D.ui.line=function(t,scale)return {n=G.UIT.R,config={},nodes={{n=G.UIT.T,config={text=t,scale=scale or .3}}}} end
D.ui.button=function(label,action,data,w)return {n=G.UIT.C,config={button=action,ref_table=data,minw=w or 1},nodes={{n=G.UIT.T,config={text=label,scale=.28}}}} end
local redraw=0
D.ui.show=function() redraw=redraw+1 end
D.core.direction=function()return 1 end
assert(loadfile(root..'pack_ui.lua'))()(D)
assert(loadfile(root..'draft_views.lua'))()(D)
local function collect(node,predicate,found)
 found=found or {}
 if type(node)=='table' then
  if predicate(node) then table.insert(found,node) end
  for _,child in ipairs(node.nodes or {}) do collect(child,predicate,found) end
 end
 return found
end
-- Fixed 2x5 grids regardless of how many cards remain.
local nine=D.pack_ui.grid({'a','b','c','d'}, {scale=.74,per_row=5,slots=10})
local one=D.pack_ui.grid({'a'},{scale=.74,per_row=5,slots=10})
local function boxes(grid) return #collect(grid,function(n)return n.n==G.UIT.B end) end
assert(boxes(nine)==6 and boxes(one)==9,'empty slots not stable')
local keys={'a','b','c'}
local sidebar=D.views.roster_sidebar(function()return keys end,'session/seat',{total=27})
assert(sidebar.config.id=='draftout_roster_sidebar')
assert(sidebar.config.colour==G.C.CLEAR and sidebar.nodes[1].config.colour~=G.C.CLEAR,
    'roster backdrop should hug its contents inside a transparent wrapper')
for _,child in ipairs(sidebar.nodes[1].nodes) do
 assert(child.n==G.UIT.R,'Every roster section needs its own row; a bare button column stretches beside the grid')
end
assert(#collect(sidebar,function(n) return n.n==G.UIT.B end)==12)
assert(#D.views.roster.keys==3)
local sort_controls=collect(sidebar,function(n)return n.config and n.config.button=='draftout_roster_sort' end)
assert(#sort_controls==1 and sort_controls[1].config.ref_table==D.views.roster)
local saved_source=table.concat(keys,',')
G.FUNCS.draftout_roster_sort(sort_controls[1])
assert(D.views.roster.sort=='Rarity')
G.FUNCS.draftout_roster_sort(sort_controls[1]);assert(D.views.roster.sort=='Name')
G.FUNCS.draftout_roster_sort(sort_controls[1]);assert(D.views.roster.sort=='Custom')
G.FUNCS.draftout_roster_sort(sort_controls[1]);assert(D.views.roster.sort=='Draft order')
assert(table.concat(keys,',')==saved_source)
assert(#collect(sidebar,function(n)return n.config and n.config.button=='draftout_roster_move_left' end)==0,
    'Redundant move controls are removed')
local sleeves=collect(sidebar,function(n)return n.config and n.config.outline_colour end)
assert(#sleeves==12 and sleeves[1].config.colour==G.C.CLEAR,'Empty slots are outline-only')
assert(D.views.roster.page==1 or D.views.roster.page==nil)
G.FUNCS.draftout_roster_page_next({config={ref_table=D.views.roster}})
sidebar=D.views.roster_sidebar(function()return keys end,'session/seat',{total=27})
assert(D.views.roster.page==2)
assert(#collect(sidebar,function(n) return n.n==G.UIT.B end)==12,'page 2 should reserve 12 sleeves')
G.FUNCS.draftout_roster_page_prev({config={ref_table=D.views.roster}})
sidebar=D.views.roster_sidebar(function()return keys end,'session/seat',{total=27})
-- Click first Joker and then third to swap, without editing game-owned list.
local area=collect(sidebar,function(n)return n.n==G.UIT.O and n.config.object and n.config.object.cards end)[1].config.object
area.cards[1]:click()
assert(D.views.roster.selected==1)
sidebar=D.views.roster_sidebar(function()return keys end,'session/seat',{total=27})
local occupied=collect(sidebar,function(n)return n.n==G.UIT.O and n.config.object and n.config.object.cards end)
occupied[3].config.object.cards[1]:click()
assert(D.views.roster.keys[1]=='c' and D.views.roster.keys[3]=='a')
assert(keys[1]=='a' and keys[3]=='c','source roster must stay immutable')
keys[4]='d'
D.views.roster_sidebar(function()return keys end,'session/seat',{total=27})
assert(D.views.roster.keys[1]=='c' and D.views.roster.keys[4]=='d','new picks should append after reordering')
D.views.roster_sidebar(function() return {} end,'next/session',{total=35})
assert(#D.views.roster.keys==0 and D.views.roster.identity=='next/session')
G.FUNCS.draftout_roster_sort(sort_controls[1])
assert(D.views.roster.sort=='Draft order','Old-session sort buttons cannot affect new roster')
local wait=D.views.waiting(function()return {} end,'next/session',{total=35})
assert(#collect(wait,function(n)return n.n==G.UIT.B end)==10,'waiting phase must retain fixed grid footprint')
assert(D.roster_context.identity=='next/session')
-- Do not render directional passing narration in the seat-status panel.
local status=D.views.readiness({{name='Seat 1'},{name='Seat 2'},{name='Seat 3'},{name='Seat 4'}},1,1)
assert(#collect(status,function(n)
 return n.n==G.UIT.T and n.config and n.config.ref_value=='flow'
end)==0, 'directional pack-passing language must not appear in status UI')
assert(#collect(status,function(n)
 return n.n==G.UIT.T and n.config and n.config.ref_value=='label'
end)==1, 'confirmation tally should remain visible')

-- Countdown must be part of the visible header, not just an updated string.
local remaining=function()return 20 end
local header=D.views.header('BURGLAR | Pack 1/3 - Pick 1/9',remaining)
local timers=collect(header,function(n)
 return n.n==G.UIT.T and n.config.ref_table==D.pack_ui.ui and n.config.ref_value=='timer'
end)
assert(#timers==1 and D.pack_ui.header_time==remaining,'active header needs its live countdown')
assert(timers[1].config.func=='draftout_timer_colour','countdown retains warning colours')
local untimed=D.views.header('BURGLAR | Pack 1/3 - Pick 1/9',function()return nil end)
assert(#collect(untimed,function(n)return n.config and n.config.ref_value=='timer' end)==0,
    'Timer Off must not leave an empty row')
assert(not untimed.nodes[1].config.minw and not untimed.nodes[1].config.minh,
    'Title frame should fit its text rather than a fixed empty box')
local paused=D.views.header('BURGLAR',function()return 8,true end)
assert(D.pack_ui.ui.timer=='Timer paused: 8s','Paused countdown stays visible')
assert(#collect(paused,function(n)return n.config and n.config.ref_value=='timer' end)==1)
local expired=D.views.header('BURGLAR',function()return 0 end)
assert(#collect(expired,function(n)return n.config and n.config.ref_value=='timer' end)==1,
    'Zero seconds is still a timed draft')
assert(status.config.colour and not status.nodes[1].config.minw,
    'Status backdrop belongs to the shared-width row')

-- One through four pack drafts reserve only their actual roster capacity.
-- Exercise navigation and clicking the final slot on every page.
for _,case in ipairs({{9,{9}},{18,{15,3}},{27,{15,12}},{35,{15,12,8}}}) do
 local capacity,pages=case[1],case[2]
 local roster_keys={}
 for i=1,capacity do
  local key='test_roster_'..i
  G.P_CENTERS[key]={key=key};roster_keys[i]=key
 end
 local function build()
  return D.views.roster_sidebar(function()return roster_keys end,'capacity/'..capacity,{total=capacity})
 end
 local panel=build()
 G.FUNCS.draftout_roster_page_prev({config={ref_table=D.views.roster}})
 assert(D.views.roster.page==1,'cannot go before first page')
 local last=0
 for page,count in ipairs(pages) do
  panel=build()
  local cards=collect(panel,function(n)return n.n==G.UIT.O end)
  assert(#cards==count,'page must contain exactly its remaining capacity')
  last=last+count
  cards[#cards].config.object.cards[1]:click()
  assert(D.views.roster.selected==last,'page-local click must select the correct roster index')
  cards[#cards].config.object.cards[1]:click()
  G.FUNCS.draftout_roster_page_next({config={ref_table=D.views.roster}})
  assert(D.views.roster.page==math.min(page+1,#pages),'cannot create an empty extra page')
 end
 assert(last==capacity,'every roster slot appears exactly once')
end
print('UI redesign offline tests passed')

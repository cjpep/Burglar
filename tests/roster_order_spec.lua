local order=assert(loadfile('burglar/roster_order.lua'))()
local state=order.new('seat1')
local source={'z','b','a'}
local info={name=function(k)return ({z='Zebra',b='apple',a='Apple',c='Apricot'})[k] end,
    rarity=function(k)return ({z=1,b=3,a=2,c=3})[k] end}
local function shown()return table.concat(order.sync(state,source,info),',') end
assert(shown()=='z,b,a' and state.sort=='Draft order')
assert(order.set_sort(state,'Rarity') and shown()=='b,a,z')
assert(order.set_sort(state,'Name') and shown()=='a,b,z','Names tie-break by key')
assert(not order.set_sort(state,'Unknown'))
assert(order.choose(state,2) and state.sort=='Name','Selection alone does not change sorting')
source[4]='c'
assert(shown()=='a,b,c,z' and state.selected==2,'New picks sort while selection follows its key')
assert(order.choose(state,4))
assert(state.sort=='Custom' and shown()=='a,z,c,b','Swap starts custom order from current display')
assert(table.concat(source,',')=='z,b,a,c','Authoritative draft order must stay untouched')
assert(order.set_sort(state,'Draft order') and shown()=='z,b,a,c')
assert(order.set_sort(state,'Rarity') and shown()=='b,c,a,z')
assert(order.set_sort(state,'Custom') and shown()=='a,z,c,b','Custom survives other sort modes')
source[5]='d';info.name=function(k)return k end;info.rarity=function()return 1 end
assert(shown()=='a,z,c,b,d','New picks append to custom order')
order.choose(state,2);source={'b','a','c','d'}
assert(shown()=='a,c,b,d' and state.selected==nil,'Removed selected key is cleared')
state.page=3;order.set_sort(state,'Name')
assert(state.page==1 and state.selected==nil and shown()=='a,b,c,d')
assert(not order.choose(state,0) and not order.choose(state,5))
local fresh=order.new('seat2')
assert(fresh.sort=='Draft order' and #fresh.custom==0,'Custom order is private to its seat/session')
print('Roster sorting: modes, stable selection, custom retention and immutable pools passed')

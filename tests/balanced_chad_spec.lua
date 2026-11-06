-- Run from a Burglar source tree. Set API_ROOT/PVP_ROOT to the unpacked 1.0.5 mod directories.
dofile('tests/adapter_spec.lua')
local D=DRAFTOUT
local ch,bc,mpch,mpbc='j_hanging_chad','j_bloodstone','j_mp_hanging_chad','j_mp_bloodstone'
local rules,balanced=nil,nil
MPAPI={BanCategory={'jokers'},Layer=function(_,def) balanced=def end,
    get_active_ruleset=function() return 'test' end,get_active_gamemode=function() end,
    current_ruleset=function() return rules end,_api_drives_ruleset=function() return true end,
    sendDebugMessage=function() end,is_any_layer_active=function() return rules==balanced end}
PVP={current_ruleset=MPAPI.current_ruleset}
dofile(PVP_ROOT..'/layers/balanced.lua')
dofile(API_ROOT..'/api/ruleset/bans.lua')
for _,s in ipairs({'Joker','Consumable','Tag','Voucher','Enhancement','Blind'}) do
    SMODS[s]={register=function(self) G.P_CENTERS[self.key]=self end}
end
dofile(API_ROOT..'/api/layers/pool_gating.lua')
setmetatable(SMODS.Joker,{__call=function(self,c)
    c.key='j_mp_'..c.key; c.set='Joker';self.register(c)
end})
for _,k in ipairs(balanced.reworked_jokers) do MPAPI._JOKER_LAYERS[k]={'balanced'} end
for _,name in ipairs({'hanging_chad','bloodstone'}) do dofile(PVP_ROOT..'/objects/jokers/standard/'..name..'.lua') end
local roster={keys={ch,bc,'j_banner'}}
G.P_CENTERS[ch].rarity=1;G.P_CENTERS[bc].rarity=2;G.P_CENTERS.j_banner.rarity=1
local vanilla={banned_jokers={},banned_silent={},reworked_jokers={}}
balanced.banned_jokers={}
local function reset(r,p)
    rules=r; G.GAME={draftout_pool=p or roster,banned_keys={},used_jokers={}}
    G.jokers={cards={}};G.shop_jokers={cards={}};G.pack_cards={cards={}}
    MPAPI.ApplyBanKeys()
end
local function offer(area,marker,forced)
    local c=create_card('Joker',area,nil,nil,nil,nil,forced,marker)
    c.config={center={key=c.key}};return c
end
local function sim(r,a,b)
    reset(r)
    local seed=12345
    function pseudorandom() seed=seed*16807%2147483647;return seed/2147483647 end
    local hits={}
    for i=1,1000 do
        local c=offer(G.shop_jokers,'sho');hits[c.key]=(hits[c.key] or 0)+1;c.removed=true
    end
    print(string.format('%s / 1000 shop Joker slots: Chad %d, Bloodstone %d, Banner %d',
        r==balanced and 'Balanced' or 'Vanilla',hits[a] or 0,hits[b] or 0,hits.j_banner or 0))
    assert((hits[a] or 0)+(hits[b] or 0)+(hits.j_banner or 0)==1000)
    return hits[a] or 0,hits[b] or 0
end
local v,w=sim(vanilla,ch,bc);assert(v>0 and w>0)
local x,y=sim(balanced,mpch,mpbc)
if EXPECT_OLD then assert(x==0 and y==0);return end
assert(x==v and y==w)
local copies={keys={ch..'#1',ch..'#2'},copy_limits=true}
reset(balanced,copies)
local owned=offer(G.shop_jokers,'sho')
owned.area=G.jokers;G.jokers.cards={owned}
local pending=offer(G.pack_cards,'buf')
assert(owned.key==mpch and pending.key==mpch and offer(G.jokers,'rif').key=='j_joker')
G.pack_cards.cards={pending}
assert(offer(G.shop_jokers,'sho').key=='j_joker')
owned.removed=true;G.jokers.cards={}
assert(offer(G.jokers,'jud',ch).key==mpch)
assert(copies.keys[1]==ch..'#1')
reset(balanced,{keys={ch}})
assert(offer(G.jokers,'rif').key==mpch)
assert(offer(G.shop_jokers,'rta').key=='j_joker')
G.GAME.used_jokers[mpch]=true;assert(offer(G.shop_jokers,'sho').key=='j_joker')
G.GAME.used_jokers={};G.GAME.banned_keys[mpch]=true;assert(offer(G.shop_jokers,'sho').key=='j_joker')
reset(balanced,{keys={bc}});assert(offer(G.shop_jokers,'uta').key==mpbc)
balanced.banned_jokers={ch};reset(balanced,{keys={ch}});assert(offer(G.shop_jokers,'sho').key=='j_joker')
balanced.banned_jokers={};reset(balanced,{keys={ch}})
G.P_CENTERS[mpch].mp_include=function() return false end;assert(offer(G.shop_jokers,'sho').key=='j_joker')
G.P_CENTERS[mpch]=nil;assert(offer(G.shop_jokers,'sho').key=='j_joker')
print('Balanced reworks: generation, bans, rarity, reservation and copy-limit checks passed')

-- Real main.lua shop adapter with a minimal native Tag dispatcher.
dofile('tests/adapter_spec.lua')
local D=DRAFTOUT
local calls=0
Tag={apply_to_run=function(self,context)
    calls=calls+1
    if context.type~='store_joker_create' or self.triggered then return end
    local rarity=self.key=='tag_rare' and 1 or 0.9
    local result=create_card('Joker',context.area,nil,rarity,nil,nil,nil,self.key=='tag_rare' and 'rta' or 'uta')
    self.triggered=true
    return result
end}
local function tag(key) return setmetatable({key=key},{__index=Tag}) end
local function reset(keys,copy_limits)
    G.GAME={draftout_pool={keys=keys,copy_limits=copy_limits},used_jokers={}}
    G.jokers={cards={}};G.shop_jokers={cards={}};G.pack_cards={cards={}}
end
local function card(key) return {config={center=G.P_CENTERS[key]}} end
local function offer(t) return t:apply_to_run({type='store_joker_create',area=G.shop_jokers}) end
G.P_CENTERS.j_hanging_chad={key='j_hanging_chad',rarity=1,set='Joker'}
G.P_CENTERS.j_blueprint={key='j_blueprint',rarity=3,set='Joker'}
G.P_CENTERS.j_shortcut={key='j_shortcut',rarity=2,set='Joker'}
reset({'j_hanging_chad'})
local rare=tag('tag_rare');local before=calls
assert(offer(rare).key=='j_joker' and rare.triggered and calls==before+1,'No Rare: use Jimbo instead of Chad')
assert(D.shop_key(G.GAME.draftout_pool,nil,1,true)=='j_joker')
assert(create_card('Joker',G.shop_jokers,nil,1,nil,nil,nil,'rta').key=='j_joker','Direct exhausted calls use the explicit Jimbo exception')
reset({'j_hanging_chad','j_blueprint','j_shortcut'})
rare=tag('tag_rare')
assert(offer(rare).key=='j_blueprint' and rare.triggered)
local uncommon=tag('tag_uncommon')
assert(offer(uncommon).key=='j_shortcut' and uncommon.triggered)
assert(D.shop_key(G.GAME.draftout_pool,'j_hanging_chad',1,true)=='j_blueprint','Forced wrong-rarity IDs cannot bypass filtering')
G.GAME.used_jokers.j_blueprint=true
rare=tag('tag_rare');assert(offer(rare).key=='j_joker' and rare.triggered,'Owned Rare falls back to Jimbo')
G.GAME.used_jokers.j_blueprint=nil
rare=tag('tag_rare');assert(offer(rare).key=='j_blueprint' and rare.triggered,'Selling makes another Rare offer eligible')
G.GAME.banned_keys={j_blueprint=true}
rare=tag('tag_rare');assert(offer(rare).key=='j_joker' and rare.triggered)
reset({'j_blueprint','j_blueprint#2','j_hanging_chad'},true)
G.jokers.cards={card('j_blueprint')};G.GAME.used_jokers.j_blueprint=true
rare=tag('tag_rare');assert(offer(rare).key=='j_blueprint','A drafted second copy remains eligible')
local reserved=card('j_blueprint');D.copy_pool.track(reserved,G.shop_jokers)
rare=tag('tag_rare');assert(offer(rare).key=='j_joker' and rare.triggered,'Pending shop offers reserve the remaining Rare copy')
reserved.removed=true
G.pack_cards.cards={card('j_blueprint')}
rare=tag('tag_rare');assert(offer(rare).key=='j_joker' and rare.triggered,'Pack offers also reserve copies')
G.pack_cards.cards={}
rare=tag('tag_rare');assert(offer(rare).key=='j_blueprint')
G.jokers.cards[2]=card('j_blueprint')
SMODS.showman=function() return true end
rare=tag('tag_rare');assert(offer(rare).key=='j_joker' and rare.triggered,'Showman cannot override explicit copy limits')
reset({'j_hanging_chad'})
uncommon=tag('tag_uncommon');assert(offer(uncommon).key=='j_joker' and uncommon.triggered)
local wraith=create_card('Joker',G.jokers,nil,1,nil,nil,'j_blueprint','wra')
assert(wraith.key=='j_blueprint','Wraith stays an exception')
G.GAME.draftout_pool=nil
rare=tag('tag_rare');before=calls;offer(rare)
assert(rare.triggered and calls==before+1,'Ordinary runs keep native Tag behavior')
print('Rare/Uncommon Tag rarity, Jimbo fallback, copy caps and ordinary-run isolation passed')

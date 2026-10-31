-- Use the real adapter in its existing mocked game environment.
dofile('tests/adapter_spec.lua')
local D=DRAFTOUT
local core=D.core
local cube=D.cubes.validate({'j_blueprint','j_blueprint','j_blueprint'})
assert(cube[1]=='j_blueprint' and cube[2]=='j_blueprint#2' and cube[3]=='j_blueprint#3')
local raw={};for i=1,36 do raw[i]='j_blueprint' end
local ids=D.cubes.validate(raw)
local s=core.new(ids,{pack_size=9,packs_per_player=1,picks_per_turn=2,player_count=4,seed='copies'})
assert(s.copy_limits)
while not s.done do
 local seat=core.next_seat(s);local pack=s.current[seat].cards
 local chosen={pack[1]};if #pack>1 then chosen[2]=pack[2] end
 assert(core.submit(s,seat,chosen,core.token(s,seat)))
end
local seen={}
for seat=1,4 do
 local pool=core.export_pool(s,seat);assert(pool.copy_limits and #pool.keys==9)
 for _,id in ipairs(pool.keys) do assert(not seen[id]);seen[id]=true;assert(core.key(id)=='j_blueprint') end
end
local function card(k) return {config={center={key=k}},ability={set='Joker'}} end
G.jokers={cards={},config={card_limit=10}}
G.shop_jokers={cards={}}
G.pack_cards={cards={}}
G.GAME={draftout_pool={copy_limits=true,keys={'j_blueprint','j_blueprint#2'}},used_jokers={j_blueprint=true}}
local pool=G.GAME.draftout_pool
G.P_CENTERS.j_blueprint={key='j_blueprint',set='Joker',rarity=3}
G.jokers.cards={card('j_blueprint')}
assert(D.shop_key(pool)=='j_blueprint','One owned copy must not block the drafted second copy')
local second=card('j_blueprint');G.jokers.cards[2]=second
assert(D.shop_key(pool)=='j_joker','Two owned copies block a third')
SMODS.showman=function() return true end
assert(D.shop_key(pool)=='j_joker','Showman does not bypass explicit copy limits')
local offered=create_card('Joker',G.shop_jokers)
assert(offered.set=='Joker' and offered.key=='j_joker','Exhaustion gives Jimbo, never another copy of Blueprint')
second.removed=true;table.remove(G.jokers.cards,2)
assert(D.shop_key(pool)=='j_blueprint','Selling frees one copy')
local reserved=card('j_blueprint');D.copy_pool.track(reserved,G.shop_jokers)
assert(D.shop_key(pool)=='j_joker','Pending offer reserves its copy before emplacement')
reserved.removed=true
assert(D.shop_key(pool)=='j_blueprint')
G.shop_jokers.cards={card('j_blueprint')}
assert(D.shop_key(pool)=='j_joker','Existing shop offers count toward the limit')
G.shop_jokers.cards={};G.pack_cards.cards={card('j_blueprint')}
assert(D.shop_key(pool)=='j_joker','Existing pack offers count toward the limit')
G.pack_cards.cards={};pool.keys[3]='j_blueprint#3';G.jokers.cards[2]=card('j_blueprint')
assert(D.shop_key(pool)=='j_blueprint','Three drafted copies permit a third')
G.jokers.cards[3]=card('j_blueprint');assert(D.shop_key(pool)=='j_joker')
local out=create_card('Joker',G.jokers,nil,0.99,nil,nil,'j_unowned','wra')
assert(out.key=='j_unowned','Wraith exception stays native')
-- Render three visually identical cards with distinct selection identities.
local rendered=D.pack_ui.grid(cube,{selected={},choose=function()return true end})
assert(rendered)
print('Duplicate draft identity and copy-cap tests passed')
-- Delayed generators retain ordinary capacity rules but use Jimbo on exhaustion.
local queue={}
Event=function(e)return e end
G.E_MANAGER={add_event=function(_,e)queue[#queue+1]=e end}
card_eval_status_text=function()end
play_sound=function()end;delay=function()end;stop_use=function()end
local uses=0;set_consumeable_usage=function()uses=uses+1 end
local native_uses=0
Card.can_use_consumeable=function()return #G.jokers.cards<G.jokers.config.card_limit end
Card.use_consumeable=function()native_uses=native_uses+1 end
D.copy_pool.install()
local create=create_card
create_card=function(...)
 local c=create(...)
 c.config={center={key=c.key}}
 c.add_to_deck=function()end;c.start_materialize=function()end
 return c
end
G.jokers={cards={card('j_joker')},config={card_limit=3},emplace=function(self,c)c.area=self;self.cards[#self.cards+1]=c end}
G.shop_jokers={cards={}};G.pack_cards={cards={}}
G.P_CENTERS.j_joker={key='j_joker',rarity=1,set='Joker'}
G.GAME={draftout_pool={copy_limits=true,keys={'j_joker','j_joker#2'}},used_jokers={},joker_buffer=0}
local riff=setmetatable({ability={name='Riff-raff'}},{__index=Card})
riff:calculate_joker({setting_blind=true});assert(#queue==1)
queue[1].func();queue={};assert(#G.jokers.cards==3 and G.GAME.joker_buffer==0)
assert(G.jokers.cards[3].config.center.key=='j_joker','Exhausted Riff-Raff uses Jimbo')
riff:calculate_joker({setting_blind=true});assert(#queue==0,'A full Joker area still prevents creation')
local judgment=setmetatable({ability={name='Judgement'},juice_up=function()end},{__index=Card})
assert(not judgment:can_use_consumeable(),'Native capacity check still applies')
G.jokers.config.card_limit=10
assert(judgment:can_use_consumeable(),'Exhausted copy pool does not disable Judgment')
judgment:use_consumeable();assert(uses==1 and #queue==1)
queue[1].func();queue={};assert(#G.jokers.cards==4 and G.jokers.cards[4].config.center.key=='j_joker')
-- Judgment rechecks availability when its delayed event executes.
G.GAME.draftout_pool={copy_limits=true,keys={'j_blueprint','j_blueprint#2'}}
G.jokers.cards={card('j_blueprint')}
judgment:use_consumeable()
G.jokers.cards[2]=card('j_blueprint')
queue[1].func();queue={}
assert(#G.jokers.cards==3 and G.jokers.cards[3].config.center.key=='j_joker')
assert(#G.GAME.draftout_pool.keys==2,'Fallback does not change the drafted roster')
judgment.ability.name='Wraith';judgment:use_consumeable();assert(native_uses==1)
print('Riff-Raff/Judgment Jimbo fallback, capacity and delayed-generation checks passed')

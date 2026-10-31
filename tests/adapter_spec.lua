-- Mocked adapter tests, NOT an in-game compatibility test.
local checks = 0
local function check(ok, msg) checks = checks + 1; assert(ok, msg) end
local function has_action(node, action)
    if node.config and node.config.button == action then return true end
    for _, child in ipairs(node.nodes or {}) do if has_action(child,action) then return true end end
    return false
end
-- Burglar's split layout uses a transparent ROOT; ordinary option menus
-- retain generic-option `contents`. Both expose the same rendered screen.
local function shown_overlay_screen()
    local definition=G.last_overlay.definition
    return (definition.contents or definition.nodes)[1]
end
local saved_config = 0
local shop, jokers = {}, {}
G = {
    P_CENTERS = {}, GAME = {}, shop_jokers = shop, jokers = jokers, FUNCS = {},
    UIT = {ROOT = 1, R = 2, C = 3, T = 4, O = 5},
    ROOM = {T = {x = 0, y = 0}}, CARD_W = 1.4, CARD_H = 1.9,
    C = {BLUE = {}, GREEN = {}, RED = {}, WHITE = {}, BLACK = {}, UI = {TEXT_LIGHT = {}}},
}
local real_keys = dofile('burglar/vanilla_keys.lua')
for i, key in ipairs(real_keys) do G.P_CENTERS[key] = {set = 'Joker', rarity = i % 3 + 1} end
G.P_CENTERS.j_legendary = {set = 'Joker', rarity = 4}
G.P_CENTERS.j_modded = {set = 'Joker', rarity = 1, mod = {}}
SMODS = {
    current_mod = {id = 'Draftout', config = dofile('config.lua')},
    Atlas=function() end,
    load_file = function(path) return loadfile(path) end,
    save_mod_config = function() saved_config = saved_config + 1 end,
    showman = function() return false end,
}
function localize(t) return t.key end
function pseudorandom() return 0.42 end
function create_card(set, area, legendary, rarity, skip, soulable, key, append)
    return {set = set, area = area, legendary = legendary, rarity = rarity,
        skip = skip, soulable = soulable, key = key or 'j_not_drafted', append = append}
end
Game = {}
function Game:update(dt) return dt end
function Game:start_run(args)
    self.GAME = args.savetext and args.savetext.GAME or {banned_keys = {}, used_jokers = {}}
    return 'original result'
end
Card = {}
function Card:calculate_joker(context) return 'original calculation' end
setmetatable(Card, {__call = function(_, x,y,w,h,front,center,params)
    return setmetatable({T={x=x,y=y,w=w,h=h}, states={drag={can=true},hover={can=true}},
        config={center=center}, params=params, children={}}, {__index=Card})
end})
function Card:juice_up() end
function CardArea(x,y,w,h,config)
    return {T={x=x,y=y,w=w,h=h}, config=config, cards={}, emplace=function(self,card)
        self.cards[#self.cards+1]=card; card.area=self
    end}
end
function create_UIBox_generic_options(options) return options end
function create_text_input(options) return {n = G.UIT.T, config = options} end
G.FUNCS.overlay_menu = function(options) G.last_overlay = options; G.OVERLAY_MENU = {} end
G.FUNCS.exit_overlay_menu = function() G.OVERLAY_MENU = nil end
SMODS.current_mod.config.pack_effects=false
SMODS.current_mod.config.session={schema=4,total=108}
SMODS.current_mod.config.armed_seat=1
SMODS.current_mod.config.online_pool={keys={'j_matador'}}
SMODS.current_mod.config.armed_online=true
dofile('main.lua')
check(not SMODS.current_mod.config.session and not SMODS.current_mod.config.armed_seat,'Old local drafts are invalidated when the pool changes')
check(SMODS.current_mod.config.armed_online==nil and SMODS.current_mod.config.online_pool==nil,'Retired standalone settings are removed')
local D = DRAFTOUT
check(D.draft_options().picks_per_turn==1 and D.draft_options().packs_per_player==3,'Default is three packs, one pick')
local standard=D.start('STANDARD')
check(standard.total==108 and standard.pack_size==9 and standard.picks_per_turn==1)
D.local_launcher=true
G.FUNCS.draftout_picks_cycle()
check(D.draft_options().picks_per_turn==2,'Pick setting cycles to two')
G.FUNCS.draftout_packs_cycle()
check(D.draft_options().packs_per_player==4,'Pack setting cycles to four')
check(D.settings_ui.packs=='4 packs each (35 Jokers)','Four-pack label shows 35, not 36')
local four=D.start('FOUR')
check(four.total==140 and #four.packs[4][1].cards==8,'Four-pack UI creates 140-card draft')
D.local_launcher=true
G.FUNCS.draftout_packs_cycle()
check(D.draft_options().packs_per_player==1,'Pack setting wraps from four to one')
local small=D.start('SMALL')
check(small.total==36 and small.rounds==1)
G.FUNCS.draftout_packs_cycle()
check(D.draft_options().packs_per_player==1,'Cannot change settings during active draft')
D.local_launcher=true
G.FUNCS.draftout_packs_cycle();G.FUNCS.draftout_packs_cycle()
check(D.draft_options().packs_per_player==3)
D.local_launcher=false
for _,key in ipairs({'j_matador','j_mr_bones','j_luchador','j_ring_master'}) do
    G.P_CENTERS[key]={set='Joker',rarity=2,unlocked=true,discovered=true}
end
check(#D.catalog() == 141, 'Eligible nonlegendary vanilla Jokers')
for _,key in ipairs(D.catalog()) do
    check(key~='j_matador' and key~='j_mr_bones' and key~='j_luchador' and key~='j_ring_master','Removed Jokers never enter the catalog')
end
-- Even an old saved fixed seed or externally reset random generator must not
-- cause repeated default drafts. Explicit developer seeds remain reproducible.
love = {math = {random = function() return 1 end}}
SMODS.current_mod.config.draft_seed = 'DRAFTOUT1'
local seen_seeds, seen_packs = {}, {}
for _ = 1, 25 do
    local fresh = D.start()
    check(not seen_seeds[fresh.seed], 'Fresh default draft seed')
    seen_seeds[fresh.seed] = true
    for round=1,3 do for seat=1,4 do
        local pack = round .. ':' .. seat .. ':' .. table.concat(fresh.packs[round][seat].cards, '|')
        check(not seen_packs[pack], 'Every pack reshuffled despite a reset random source')
        seen_packs[pack] = true
    end end
end
local explicit_a, explicit_b = D.start('REPRO'), D.start('REPRO')
check(table.concat(explicit_a.current[1].cards, '|') == table.concat(explicit_b.current[1].cards, '|'), 'Explicit test seed reproducible')
-- Exercise the user's actual new/resume menu flow, including a saved 0.4.0 draft.
local previous = D.start('DRAFTOUT1')
G.FUNCS.draftout_open()
check(D.local_launcher and SMODS.current_mod.config.session == previous, 'Opening shows choices without silently replacing saved progress')
check(has_action(D.screen(),'draftout_new') and has_action(D.screen(),'draftout_resume'), 'Both new and resume are reachable with an unfinished draft')
G.FUNCS.draftout_new()
local current = SMODS.current_mod.config.session
check(not D.local_launcher and current ~= previous and current.seed ~= previous.seed, 'Start fresh replaces saved draft')
for round=1,3 do for seat=1,4 do
    check(table.concat(current.packs[round][seat].cards,'|') ~= table.concat(previous.packs[round][seat].cards,'|'), 'Every saved pack replaced by a newly shuffled pack')
end end
D.ui.show()
check(not has_action(D.screen(),'draftout_new'), 'New draft is moved out of the pack content')
G.FUNCS.draftout_more()
check(has_action(shown_overlay_screen(),'draftout_new'),'New draft remains reachable under More')
G.FUNCS.draftout_more()
local old_token = D.core.token(current,1)
check(D.core.submit(current,1,{current.current[1].cards[1],current.current[1].cards[2]},old_token))
local remaining = table.concat(current.current[1].cards,'|')
G.FUNCS.draftout_open(); G.FUNCS.draftout_resume()
check(SMODS.current_mod.config.session == current and current.revision == 1, 'Resume preserves confirmed picks')
check(table.concat(current.current[1].cards,'|') == remaining, 'Resume preserves existing pack contents')
G.FUNCS.draftout_new()
check(SMODS.current_mod.config.session.seed ~= current.seed and SMODS.current_mod.config.session.revision == 0, 'Restart reachable midway and creates a clean shuffled draft')
local s = D.start('SMOKE')
while not s.done do
    local seat = D.core.next_seat(s)
    check(D.core.submit(s, seat, {s.current[seat].cards[1],s.current[seat].cards[2]}, D.core.token(s, seat)))
end
D.arm(1)
setmetatable(G, {__index = Game})
check(G:start_run({}) == 'original result')
local pool = G.GAME.draftout_pool
check(#pool.keys == 27 and pool.seat == 1)
local members = {}
for _, k in ipairs(pool.keys) do members[k] = true end
for _ = 1, 1000 do
    local card = create_card('Joker', shop, nil, nil, true, true, nil, 'sho')
    check(members[card.key], 'Shop remains in drafted pool')
    check(card.skip and card.append == 'sho' and card.soulable == false, 'Forward arguments')
end
local forced = create_card('Joker', shop, nil, nil, nil, nil, 'j_not_drafted')
check(members[forced.key], 'Replace off-pool forced shop key')
check(create_card('Joker', shop, nil, nil, nil, nil, pool.keys[1]).key == pool.keys[1])
check(create_card('Tarot', shop, nil, nil, nil, nil, 'c_test').key == 'c_test', 'Other sets pass through')
check(create_card('Joker', jokers, nil, nil, nil, true, 'j_outside').key == 'j_outside', 'Outside shop unchanged')
check(create_card('Joker', nil, nil, nil, nil, true, 'j_outside').soulable, 'Nil area safe')
local judgement = create_card('Joker', jokers, nil, nil, nil, nil, nil, 'jud')
check(members[judgement.key], 'Judgment uses drafted types')
local riff = create_card('Joker', jokers, nil, 0, nil, nil, nil, 'rif')
check(members[riff.key] and G.P_CENTERS[riff.key].rarity == 1, 'Riff-Raff uses drafted Commons')
check(create_card('Joker', jokers, true, nil, nil, nil, 'j_legendary', 'sou').key == 'j_legendary', 'Soul remains outside scope')
local riff_card = setmetatable({ability = {name = 'Riff-raff'}}, {__index = Card})
local old_pool = G.GAME.draftout_pool
local rare_key, common_key
for _, key in ipairs(old_pool.keys) do
    if G.P_CENTERS[key].rarity == 3 then rare_key = key end
    if G.P_CENTERS[key].rarity == 1 then common_key = key end
end
G.GAME.draftout_pool = {keys = {rare_key}}
check(riff_card:calculate_joker({setting_blind = true}) == 'original calculation', 'No Commons: native Riff-Raff trigger creates fallback Jimbos')
check(riff_card:calculate_joker({joker_main = true}) == 'original calculation', 'Other contexts unchanged')
check(create_card('Joker', jokers, nil, nil, nil, nil, nil, 'jud').key == rare_key, 'Judgment allows drafted Rare')
G.GAME.draftout_pool = {keys = {common_key}}
G.GAME.used_jokers[common_key] = true
check(create_card('Joker', jokers, nil, 0, nil, nil, nil, 'rif').key == 'j_joker', 'Exhausted Commons use Jimbo')
check(riff_card:calculate_joker({setting_blind = true}) == 'original calculation')
G.GAME.draftout_pool, G.GAME.used_jokers = old_pool, {}
for _, k in ipairs(pool.keys) do G.GAME.used_jokers[k] = true end
check(create_card('Joker', shop).key=='j_joker', 'Exhaustion uses Jimbo')
for _, k in ipairs(pool.keys) do G.GAME.banned_keys[k] = true end
check(create_card('Joker', shop).key=='j_joker', 'All banned still permits the Jimbo fallback')
G.GAME.banned_keys, G.GAME.used_jokers = {}, {}
local snapshot = D.core.copy(G.GAME)
D.arm(2)
check(pool.seat == 1, 'Arming cannot mutate a live run')
G:start_run({savetext = {GAME = snapshot}})
check(G.GAME.draftout_pool.seat == 1, 'Continue retains saved pool')
G:start_run({})
check(G.GAME.draftout_pool.seat == 2, 'Next new run uses new armed seat')
SMODS.current_mod.config.armed_seat = false
G:start_run({})
check(not G.GAME.draftout_pool, 'Unarmed runs are normal')
check(create_card('Joker', shop).key == 'j_not_drafted', 'Normal shop pass-through')
check(saved_config > 0)

-- Smoke all UI phases and a callback-based pick, with immutable click token.
D.start('UI')
check(D.screen().n == G.UIT.C)
D.ui.show()
check(G.last_overlay ~= nil)
local state = SMODS.current_mod.config.session
local screen = D.screen()
local function cards_in(node, out)
    out = out or {}
    if node.n == G.UIT.O then
        for _, card in ipairs(node.config.object.cards) do if not card.draftout_tray then out[#out+1] = card end end
    end
    for _, child in ipairs(node.nodes or {}) do cards_in(child, out) end
    return out
end
-- The real local screen receives one-pick rules, including its preview limit.
SMODS.current_mod.config.picks_per_turn=1
local one=D.start('ONE_PICK'); local one_cards=cards_in(D.screen())
one_cards[1]:click();one_cards[2]:click()
check(#D.pack_ui.choices()==1 and not one_cards[1].draftout_selected and one_cards[2].draftout_selected,'One-pick UI replaces the previous selection')
G.FUNCS.draftout_pack_confirm()
check(#one.pools[1]==1,'One-pick confirmation matches core rule')
SMODS.current_mod.config.picks_per_turn=2
SMODS.current_mod.config.session=state
local previews = cards_in(D.screen())
check(#previews == 9, 'Pack shows all real card previews')
check(G.FUNCS.draftout_reveal==nil and not has_action(screen,'draftout_reveal'),
    'Draft opens directly with no reveal callback or button')
local first_deadline=D.local_clock.deadline
D.screen()
check(D.local_clock.deadline==first_deadline,'Menu refresh does not reset the local pick clock')
local pack_node = D.pack_ui.build(state.current[1].cards,D.core.token(state,1),'layout',function() end)
check(pack_node.n == G.UIT.R, 'Pack occupies its own menu row')
local body = pack_node.nodes[1]
local back_index, first_cards_index
for i, child in ipairs(body.nodes) do
    if #cards_in(child) > 0 and not first_cards_index then first_cards_index = i end
    if has_action(child,'draftout_close') then back_index = i end
end
check(back_index==nil and first_cards_index==1,'Pack content begins with cards and keeps navigation in the footer')
check(not has_action(pack_node,'draftout_pack_confirm'), 'Confirm is no longer in the top controls')
D.ui.show()
local selection_overlay=G.last_overlay.definition
local shown_screen=(selection_overlay.contents or selection_overlay.nodes)[1]
check((selection_overlay.no_back or selection_overlay.n==G.UIT.ROOT) and has_action(shown_screen.nodes[#shown_screen.nodes],'draftout_pack_confirm'),
    'Confirm is in the footer below all pack content')
-- Restore the local pack's commit handler after the isolated layout inspection.
previews = cards_in(D.screen())
for _, card in ipairs(previews) do
    check(card.params.bypass_discovery_ui and card.params.bypass_lock, 'Locked effects visible')
    check(not card.states.drag.can, 'Cannot drag previews into another area')
    check(not card.highlighted, 'Preview selection does not activate native Use/Sell buttons')
end
previews[1]:click(); previews[2]:click(); previews[3]:click()
check(not previews[1].draftout_selected and previews[2].draftout_selected and previews[3].draftout_selected, 'Full pair replaces oldest selection')
previews[2]:click(); previews[4]:click()
check(not previews[1].draftout_selected and previews[3].draftout_selected, 'Can change choices')
G.FUNCS.draftout_pack_confirm()
check(#state.pools[1] == 2 and D.pack_ui.active and #D.pack_ui.choices()==0, 'Confirm automatically advances to the next seat')
G.FUNCS.draftout_pack_confirm()
check(#state.pools[1] == 2, 'Double confirm cannot duplicate picks')
previews[1]:click()
check(not previews[1].draftout_selected, 'Stale overlay cannot change current selection')
while not state.done do
    local seat = D.core.next_seat(state)
    D.core.submit(state, seat, {state.current[seat].cards[1],state.current[seat].cards[2]}, D.core.token(state, seat))
end
check(D.screen().n == G.UIT.C)
-- Persist choices across an unrelated online refresh, but lock a submitted pair.
local keys = D.catalog()
local thirteen = {}; for i=1,13 do thirteen[i]=keys[i] end
local tok = {round=3,pick=1,pack_id='odd-pack'}
local sends, submitted = 0, nil
local function submit_pair(chosen, token)
    sends = sends + 1; submitted = {keys=chosen,token=token}
end
local preview_nodes = D.pack_ui.build(thirteen,tok,'preview-test',submit_pair,nil,{picks_per_turn=2})
previews = cards_in(preview_nodes)
check(#previews == 13, 'Final larger pack renders all thirteen cards')
previews[1]:click()
local refreshed = cards_in(D.pack_ui.build(thirteen,tok,'preview-test',submit_pair,nil,{picks_per_turn=2}))
check(refreshed[1].draftout_selected and refreshed[1].draftout_label == '', 'Selection survives unrelated refresh')
check(refreshed[1].T.y < refreshed[1].area.T.y + (refreshed[1].area.T.h-refreshed[1].T.h)/2,
    'Refresh restores the raised selection')
local confirm = {config={}}
G.FUNCS.draftout_pack_can_confirm(confirm)
check(confirm.config.button == nil, 'Confirm disabled with one of two selected')
refreshed[2]:click()
G.FUNCS.draftout_pack_can_confirm(confirm)
check(confirm.config.button == 'draftout_pack_confirm', 'Confirm enabled with two selected')
G.FUNCS.draftout_pack_confirm(); G.FUNCS.draftout_pack_confirm()
check(sends == 1 and #submitted.keys == 2, 'Outstanding online confirmation is sent once')
check(submitted.token.pack_id == 'odd-pack', 'Pair keeps original pack token')
refreshed[1]:click()
check(refreshed[1].draftout_selected, 'Pending selection cannot change')
D.pack_ui.unlock(); refreshed[1]:click()
check(not refreshed[1].draftout_selected, 'Rejected submission can be corrected')
local single = cards_in(D.pack_ui.build({keys[14]}, {round=3,pick=7,pack_id='last'}, 'preview-test',submit_pair,nil,{picks_per_turn=2}))
check(not D.pack_ui.active.selected[keys[1]], 'Passing clears previous choices')
refreshed[2]:click()
check(not D.pack_ui.active.selected[keys[2]], 'Old pack clicks cannot affect new pack')
single[1]:click(); G.FUNCS.draftout_pack_confirm()
check(sends == 2 and #submitted.keys == 1, 'Final singleton can be confirmed')
D.pack_ui.clear()
-- Old completed drafts still display and arm; unfinished old rules restart cleanly.
local old = D.core.copy(state)
old.schema, old.total = 1, nil
SMODS.current_mod.config.session = old
check(D.screen().n == G.UIT.C, 'Old completed draft remains accessible')
old.done = false
check(D.screen().n == G.UIT.C and not SMODS.current_mod.config.session, 'Old unfinished draft resets')
SMODS.current_mod.config.session = state
-- Native multiplayer pools preserve the server-selected run seed.
local personal=D.core.copy(state.pools[3])
check(D.network==nil and G.FUNCS.draftout_online_open==nil,'Standalone tool is not loaded')
check(not has_action(SMODS.current_mod.config_tab(),'draftout_online_open'),'Standalone button is absent')
local mp_args = {seed='MP_SERVER_SEED'}
D.mpbridge = {prepare_run=function()
    return {source='mpapi_pvp',keys=D.core.copy(personal),seat=3}
end}
MP = {LOBBY={code='FFA_LOBBY'}}
G:start_run(mp_args)
check(G.GAME.draftout_pool.source=='mpapi_pvp')
check(mp_args.seed=='MP_SERVER_SEED')
D.mpbridge, MP = nil,nil
-- A locally armed test pool must not alter a Speedrunning/unrelated API run.
D.arm(1)
MPAPI={get_current_lobby=function() return {mod_id='MultiplayerSPDRN'} end}
G:start_run({seed='SPEEDRUN'})
check(G.GAME.draftout_pool==nil, 'Local pool stays out of Speedrunning')
MPAPI.get_current_lobby=function() return {mod_id='MultiplayerPvP'} end
G:start_run({seed='OTHER_PVP'})
check(G.GAME.draftout_pool==nil, 'Local pool stays out of unrelated PvP')
MPAPI=nil
G:start_run({})
check(G.GAME.draftout_pool.seat==1, 'Local armed pool still works outside API lobbies')
-- Buffoon packs are restricted; Wraith and Soul explicitly remain exceptions.
G.pack_cards={}
local active_pool=G.GAME.draftout_pool
local allowed={}; for _,key in ipairs(active_pool.keys) do allowed[key]=true end
for i=1,50 do
    local card=create_card('Joker',G.pack_cards,true,0.99,true,true,'j_legendary','buf')
    check(allowed[card.key] and not card.soulable and not card.legendary,'Buffoon art/picks stay in drafted pool')
end
local outside
for key,c in pairs(G.P_CENTERS) do if c.rarity==3 and not allowed[key] then outside=key; break end end
check(outside~=nil)
check(create_card('Joker',G.jokers,nil,0.99,nil,nil,outside,'wra').key==outside,'Wraith can grant undrafted Rares')
check(create_card('Joker',G.jokers,true,nil,nil,true,'j_legendary','sou').key=='j_legendary','Soul still grants undrafted Legendaries')
G.GAME.draftout_pool=nil
check(create_card('Joker',G.pack_cards,nil,nil,nil,true,'j_outside','buf').key=='j_outside','Normal Buffoon packs unchanged without a drafted run')
G.GAME.draftout_pool=active_pool
do
    local saved_game=G.GAME
    local pool={keys={'j_ring_master','j_joker'}} -- Even an old run cannot offer Showman in drafted shops.
    G.GAME={draftout_pool=pool,banned_keys={},used_jokers={}}
    for _,append in ipairs({'shop','buf','jud','rif'}) do
        local area=append=='shop' and G.shop_jokers or append=='buf' and G.pack_cards or G.jokers
        -- Supply a known drafted Common to Riff-Raff, independent of mock rarities.
        local rarity=G.P_CENTERS.j_joker.rarity;G.P_CENTERS.j_joker.rarity=1
        check(create_card('Joker',area,nil,nil,nil,nil,'j_ring_master',append).key=='j_joker','Showman cannot enter drafted generation')
        G.P_CENTERS.j_joker.rarity=rarity
    end
    check(create_card('Joker',G.jokers,nil,0.99,nil,nil,'j_ring_master','wra').key=='j_ring_master','Wraith remains an undrafted exception')
    check(G.P_CENTERS.j_ring_master.rarity==3,'Wraith Showman displays as Rare in Burglar')
    check(#pool.keys==2,'Wraith does not add to or rewrite the roster')
    G.GAME=saved_game
end
-- Extinction is local saved-run state, and must survive forced keys, Showman
-- and the duplicate fallback without changing the immutable drafted roster.
do
    local saved_game,saved_showman=G.GAME,SMODS.showman
    local gros_rarity,joker_rarity=G.P_CENTERS.j_gros_michel.rarity,G.P_CENTERS.j_joker.rarity
    G.P_CENTERS.j_gros_michel.rarity,G.P_CENTERS.j_joker.rarity=1,1
    local roster={keys={'j_gros_michel','j_joker'}}
    G.GAME={draftout_pool=roster,pool_flags={},used_jokers={},banned_keys={}}
    check(D.shop_key(roster,'j_gros_michel')=='j_gros_michel','Gros Michel is available before extinction')
    G.GAME.used_jokers.j_gros_michel=nil
    check(D.shop_key(roster,'j_gros_michel')=='j_gros_michel','Selling Gros Michel does not cause extinction')
    G.GAME.pool_flags.gros_michel_extinct=true
    for _,append in ipairs({'shop','buf','jud','rif'}) do
        for i=1,20 do
            local area=append=='shop' and G.shop_jokers or append=='buf' and G.pack_cards or G.jokers
            check(create_card('Joker',area,nil,nil,nil,nil,'j_gros_michel',append).key=='j_joker',
                'Extinct Gros Michel cannot return through drafted generation')
        end
    end
    G.GAME.used_jokers.j_joker=true
    check(D.shop_key(roster)== 'j_joker','Duplicate fallback still excludes extinct Gros Michel')
    SMODS.showman=function() return true end
    check(D.shop_key(roster)== 'j_joker','Showman cannot bypass extinction')
    check(D.shop_key({keys={'j_gros_michel'}})=='j_joker','Exhaustion uses Jimbo without reviving Gros Michel')
    check(#roster.keys==2 and roster.keys[1]=='j_gros_michel','Drafted roster and recap are not rewritten')
    local saved=G.GAME
    G:start_run({savetext={GAME=saved}})
    check(D.shop_key(roster,'j_gros_michel')=='j_joker','Continuing an extinct run keeps Gros Michel unavailable')
    G.GAME.draftout_pool={keys={'j_gros_michel'}}
    check(#D.common_keys(G.GAME.draftout_pool)==0,'Extinct Gros Michel is not an available drafted Common')
    local riff=setmetatable({ability={name='Riff-raff'}},{__index=Card})
    check(riff:calculate_joker({setting_blind=true})=='original calculation','Riff-Raff can create Jimbo with an extinct-only Common pool')
    G:start_run({})
    check(D.shop_key(roster,'j_gros_michel')=='j_gros_michel','New runs do not inherit another run\'s extinction')
    G.GAME,SMODS.showman=saved_game,saved_showman
    G.P_CENTERS.j_gros_michel.rarity,G.P_CENTERS.j_joker.rarity=gros_rarity,joker_rarity
end
-- Readiness updates retain references and never contain card selections.
D.views.readiness({{name='Player One',ready=true,connected=true},{name='Friend',ready=false,connected=true},
    {name='Other',ready=true,connected=true},{name='Away',ready=false,connected=false}})
local entry=D.views.entries[4]
check(D.views.summary.label=='2/4 confirmed' and entry.label:find('Disconnected'))
D.views.update({{name='Player One',ready=true,connected=true},{name='Friend',ready=true,connected=true},
    {name='Other',ready=true,connected=true},{name='Away',ready=false,connected=true}})
check(entry==D.views.entries[4] and entry.label:find('Choosing') and D.views.summary.label=='3/4 confirmed')
-- Team pages are read-only; inspecting them keeps tentative choices and the timer.
local test_time=100
love.timer={getTime=function() return test_time end}
love.math={random=function(n) return n end}
SMODS.current_mod.config.pick_seconds=5
D.mode='local'
local timed=D.start('LOCAL_TIMER')
D.ui.show()
local previews=cards_in(D.screen())
previews[1]:click()
local selected_key=timed.current[1].cards[1]
local selection=D.pack_ui.active
G.FUNCS.draftout_team_open({config={ref_table={get_keys=function() return personal end,time_left=D.local_time_left}}})
local gallery=cards_in(D.screen())
check(#gallery==14,'Team view paginates real card art')
gallery[1]:click()
check(D.pack_ui.active==selection and #D.pack_ui.choices()==1,'Read-only team does not change pack selection')
G.FUNCS.draftout_team_next(); check(#cards_in(D.screen())==13)
G.FUNCS.draftout_team_next(); check(#cards_in(D.screen())==#personal-14)
D.views.team.get_keys=function() return timed.pools[1] end
check(#cards_in(D.screen())==0,'Unpicked pack cards do not appear in team')
test_time=103; G:update(0.02)
check(D.pack_ui.ui.timer=='Time left: 2s','Timer continues while viewing team')
test_time=106; G:update(0.02)
check(#timed.pools[1]==2 and (timed.pools[1][1]==selected_key or timed.pools[1][2]==selected_key),'Timeout keeps tentative selection')
check(#cards_in(D.screen())==2,'Team view updates when a timed pick is confirmed')
G.FUNCS.draftout_team_close()
check(not D.views.team and #cards_in(D.screen())==9,'Return automatically opens the next seat without a reveal step')
-- Effects keep fronts visible without needing card updates or native flips.
local sounds={}
play_sound=function(key) sounds[#sounds+1]=key end
function Card:update() end
function Card:flip() error('Draft previews must never enter the flip state machine') end
function Card:juice_up() self.motion_count=(self.motion_count or 0)+1 end
SMODS.current_mod.config.pack_effects=true
SMODS.current_mod.config.pick_seconds=0
test_time=200
G.P_CENTERS.p_buffoon_normal_1={set='Booster',key='p_buffoon_normal_1'}
function Card:open() error('Pregame draft must not enter in-run booster state') end
function Card:explode() error('Pregame draft must not use a frozen TOTAL timer') end
local prior_game,prior_state,prior_pack_cards=G.GAME,G.STATE,G.pack_cards
local prior_size,prior_choices=G.GAME.pack_size,G.GAME.pack_choices
local animated=D.start('ANIM')
D.ui.show()
previews=cards_in(shown_overlay_screen())
check(#previews==1 and previews[1].config.center.set=='Booster','Fresh draft automatically displays real Buffoon wrapper art')
local opening=D.pack_ui.active.opening
check(D.pack_ui.active.showing_opening and sounds[#sounds]=='explosion_buildup1','Opening starts automatically with native buildup sound')
local pack_confirm={config={}}
G.FUNCS.draftout_pack_can_confirm(pack_confirm)
check(pack_confirm.config.button==nil,'Cannot confirm while wrapper is opening')
previews[1]:click(); check(#D.pack_ui.choices()==0,'Wrapper cannot be drafted')
test_time=200.4; G:update(0)
check(D.pack_ui.active.opening==opening and D.pack_ui.active.showing_opening,'Animation progresses with a zero game dt')
D.ui.show()
check(D.pack_ui.active.opening==opening and opening.started==200,'Refresh does not restart the opening')
test_time=200.7; G:update(0)
check(opening.released and opening.card.dissolve>0,'Wrapper dissolves using wall-clock time')
test_time=201; G:update(0)
check(not D.pack_ui.active.showing_opening,'Opening finishes automatically without a reveal click')
check(G.GAME==prior_game and G.STATE==prior_state,'Opening never replaces run or game state')
check(G.pack_cards==prior_pack_cards and G.GAME.pack_size==prior_size and G.GAME.pack_choices==prior_choices,
    'Opening does not claim the native pack area or change its choices')
previews=cards_in(shown_overlay_screen())
check(#previews==9,'All nine drafted Jokers appear after opening')
for _,card in ipairs(previews) do
    check(card.facing=='front' and card.sprite_facing=='front','Joker art visible immediately with effects enabled')
    check(card.flipping==nil,'Reveal uses fronts without a flip state')
    check(card.motion_count==1,'Pack effect uses a face-up pop')
end
check(previews[1].states.visible and not previews[9].states.visible,'Cards reveal in a stagger')
previews[9]:click(); check(#D.pack_ui.choices()==0,'Unrevealed cards cannot be selected')
previews[1]:click(); check(#D.pack_ui.choices()==1,'Revealed cards are immediately selectable')
previews[1]:click()
test_time=201.5; G:update(0)
for _,card in ipairs(previews) do check(card.states.visible and card.states.hover.can,'All cards reveal within half a second') end
local before_sounds=#sounds
previews=cards_in(D.screen())
check(#sounds==before_sounds,'Refresh does not replay pack opening sound')
for _,card in ipairs(previews) do check(card.facing=='front' and card.sprite_facing=='front','Refresh keeps fronts visible') end
previews[1]:click(); previews[2]:click()
local raised,resting=previews[1],previews[3]
local function rest_y(card) return card.area.T.y+(card.area.T.h-card.T.h)/2 end
check(math.abs(rest_y(raised)-raised.T.y-raised.T.h*0.14)<0.00001,
    'Selected preview lifts above its resting position')
check(resting.T.y==rest_y(resting),'Unselected preview remains at rest')
for i=1,20 do raised.area:align_cards() end
check(math.abs(rest_y(raised)-raised.T.y-raised.T.h*0.14)<0.00001,
    'Repeated alignment does not accumulate lift')
raised.area.T.x,raised.area.T.y=5,9; raised.area:align_cards()
check(math.abs(rest_y(raised)-raised.T.y-raised.T.h*0.14)<0.00001 and raised.T.y>=9,
    'Raised card follows menu movement and fits inside reserved headroom')
raised:click(); check(raised.T.y==rest_y(raised),'Deselect lowers the preview')
raised:click()
G.FUNCS.draftout_pack_confirm()
check(#animated.pools[1]==2 and D.core.next_seat(animated)==2,'Confirm immediately advances to the next seat')
check(D.pack_ui.active and D.pack_ui.active.opening.count==9,'Next seat opens its pack without a pick recap')
check(D.pack_ui.confirmation==nil and D.pack_ui.feedback_until==nil,'After-pick recap and its delay are removed')
check(has_action(shown_overlay_screen(),'draftout_close'),'Next pack keeps its Back control')
test_time=202.4; G:update(0.02)
check(D.pack_ui.active and D.pack_ui.active.token.pack_id=='r1s2','Next pack remains active without waiting for a recap timer')
-- Reopening, passing, and new rounds have different presentation lifecycles.
local before_pass=#sounds
local pass_cards={}; for i=1,10 do pass_cards[i]=keys[i] end
local pass=D.pack_ui.build(pass_cards,{round=1,pick=2,pack_id='passed'},'lifecycle',function() end)
check(#cards_in(pass)==10 and not D.pack_ui.active.showing_opening,'Passed pack immediately shows its remaining Jokers')
check(#sounds==before_pass,'Passing does not replay opening sounds')
for _,card in ipairs(cards_in(pass)) do check(not card.motion_count,'Passing does not replay the new-pack pop') end
local next_round=D.pack_ui.build(thirteen,{round=2,pick=1,pack_id='new'},'lifecycle',function() end)
local next_opening=D.pack_ui.active.opening
check(#cards_in(next_round)==1 and next_opening.count==13,'A new round opens again and supports the extra Joker')
test_time=203.5
local next_cards=cards_in(D.pack_ui.build(thirteen,{round=2,pick=1,pack_id='new'},'lifecycle',function() end))
check(#next_cards==13,'Larger final pack reveals every assigned Joker')
D.pack_ui.clear()
before_pass=#sounds
check(#cards_in(D.pack_ui.build(thirteen,{round=2,pick=1,pack_id='new'},'lifecycle',function() end))==13,
    'Reopening the same pack never repeats the wrapper')
check(#sounds==before_pass,'Reopening never repeats the pack sound')
G.SETTINGS={reduced_motion=true}
check(#cards_in(D.pack_ui.build(thirteen,{round=3,pick=1,pack_id='new'},'lifecycle',function() end))==13,
    'Reduced motion bypasses the wrapper opening')
G.SETTINGS=nil
-- Settings update in place, without closing the menu or changing a live clock.
local overlay=G.OVERLAY_MENU
SMODS.current_mod.config.pick_seconds=0
local timer_button=D.timer_button()
G.FUNCS.draftout_timer_cycle()
check(SMODS.current_mod.config.pick_seconds=='scaling' and D.settings_ui.timer=='Scaling: 5s per Joker')
G.FUNCS.draftout_timer_cycle()
check(SMODS.current_mod.config.pick_seconds==30 and D.settings_ui.timer=='Pick timer: 30s')
check(timer_button.nodes[1].config.ref_table==D.settings_ui and G.OVERLAY_MENU==overlay)
G.FUNCS.draftout_effects_toggle()
check(SMODS.current_mod.config.pack_effects==false and G.OVERLAY_MENU==overlay)
check(#cards_in(D.pack_ui.build(thirteen,{round=1,pick=1,pack_id='new'},'effects-off',function() end))==13,
    'Effects Off shows fresh pack choices immediately')
D.views.readiness({{name='朋友朋友朋友朋友朋友朋友',ready=false,connected=true}})
check(D.views.entries[1].label=='朋友朋友朋友朋友朋友: Choosing','Player name truncation preserves UTF-8 characters')


-- Local scaling is captured for the draft, including refresh and team viewing.
SMODS.current_mod.config.pick_seconds='scaling'
SMODS.current_mod.config.picks_per_turn=1
SMODS.current_mod.config.packs_per_player=4
SMODS.current_mod.config.pack_effects=false
D.mode='local';test_time=1000
local scaled=D.start('SCALED_LOCAL')
D.screen();check(D.local_clock.seconds==45 and D.local_clock.deadline==1045)
SMODS.current_mod.config.pick_seconds=90
test_time=1005;D.screen()
check(D.local_clock.deadline==1045,'Refreshing does not restart scaling')
G.FUNCS.draftout_team_open({config={ref_table={get_keys=function() return scaled.pools[1] end,time_left=D.local_time_left}}})
G:update(0.02)
check(D.local_time_left()==40,'My Team keeps the same countdown')
G.FUNCS.draftout_team_close()
check(D.local_clock.deadline==1045)
for seat=1,4 do D.core.submit(scaled,seat,{scaled.current[seat].cards[1]},D.core.token(scaled,seat)) end
D.local_clock=nil;D.screen()
check(D.local_clock.seconds==40,'New local pick scales down despite changed config')
-- Restore the unrelated tests' run pool and mode; no draft state owns the run.
SMODS.current_mod.config.pick_seconds=0

-- Burglar must forward Soul-eligible generation unchanged; no odds multiplier.
for _,set in ipairs({'Tarot','Spectral','Planet'}) do
    for _,append in ipairs({'ar1','ar2','spe','pl1'}) do
        local c=create_card(set,G.pack_cards,nil,nil,true,true,nil,append)
        check(c.set==set and c.soulable==true and c.append==append and c.key=='j_not_drafted',
            'Soul-eligible requests reach upstream unchanged')
    end
end

-- Locked picks retain their private art while the shared count updates live.
D.pack_ui.confirmed({keys[1],keys[2]})
D.views.update({{name='One',ready=true},{name='Two',ready=true},{name='Three',ready=false},{name='Four',ready=false}})
local waiting=D.views.waiting()
check(#cards_in(waiting)==0 and D.views.summary.waiting=='Picks locked - waiting for 2 players','Waiting no longer repeats picked cards')
D.views.update({{ready=true},{ready=true},{ready=true},{ready=false}})
check(D.views.summary.waiting=='Picks locked - waiting for 1 player')
local old_rarity=G.P_CENTERS[keys[1]].rarity
G.P_CENTERS[keys[1]].rarity=1
local completed=D.views.completed({keys[1]},'Ready up in the lobby')
check(has_action(completed,'draftout_team_open'),'Complete screen opens final roster')
local function has_text(node,text)
    if node.config and node.config.text==text then return true end
    for _,child in ipairs(node.nodes or {}) do if has_text(child,text) then return true end end
    return false
end
check(has_text(completed,'1 Common / 0 Uncommon / 0 Rare'),'Summary counts drafted types by rarity')
check(has_text(completed,'Ready up in the lobby'),'Summary explains the next step')
G.P_CENTERS[keys[1]].rarity=old_rarity
local roster={}; for i=1,37 do roster[i]=keys[i] end
local full_summary=D.views.completed(roster,'Ready up')
check(#cards_in(full_summary)==14,'Final roster starts with fourteen cards')
D.views.final.page=3
check(#cards_in(D.views.completed(roster,'Ready up'))==9,'Final roster last page includes every remaining type')

-- A fresh session releases presentation state from old sessions.
D.pack_ui.opening.rounds.old={card={}}
D.pack_ui.deals={{}}
D.start('CLEANUP')
check(next(D.pack_ui.opening.rounds)==nil and #D.pack_ui.deals==0,'Fresh draft releases prior presentation state')

-- Compact seating, balanced card rows and a read-only paged team tray.
D.views.readiness({{name='A',connected=true},{name='B',connected=true},{name='C',connected=true},{name='D',connected=true}},2)
check(D.views.summary.flow=='From A | Passing left to C','Pack one passes left')
local seats={{name='A',connected=true},{name='B',connected=true},{name='C',connected=true},{name='D',connected=true}}
for round=1,4 do
    local strip=D.views.readiness(seats,2,round)
    local expected=round%2==1 and 'From A | Passing left to C'
        or 'From C | Passing right to A'
    check(D.views.summary.flow==expected,'Receiving and passing neighbors reverse each pack')
    local cells=strip.nodes[1].nodes[1].nodes
    check(cells[2].nodes[1].config.text==(round%2==1 and '>' or '<'),'Seating arrows match direction')
    D.views.update(seats)
    check(D.views.summary.flow==expected,'Readiness refresh preserves current direction')
end
check(D.views.entries[2].title=='YOU','The current local seat is marked')
local function find_id(node,id)
    if node.config and node.config.id==id then return node end
    for _,child in ipairs(node.nodes or {}) do local found=find_id(child,id);if found then return found end end
end
local nine={};for i=1,9 do nine[i]=keys[i] end
local balanced=D.pack_ui.build(nine,{round=1,pick=2,pack_id='layout9'},'balanced',function() end)
-- Pack previews are now wrapped in a separate visual frame.
local grid=balanced.nodes[1].nodes[#balanced.nodes[1].nodes].nodes[1]
local rows=grid.nodes[1].nodes
-- Pack previews always occupy two full-width rows. Actual cards are
-- individually centered in both rows as the number of remaining picks falls.
local function check_centered_pack(row_nodes,count)
    local expected_top=math.ceil(count/2)
    local expected_bottom=count-expected_top
    check(#row_nodes==2,'Pack retains two rows')
    local slot_width=G.CARD_W*0.74*1.08+0.05
    for r,expected in ipairs({expected_top,expected_bottom}) do
        local row=row_nodes[r]
        local actual,spacers,total=0,{}
        for _,node in ipairs(row.nodes) do
            if node.n==G.UIT.C then actual=actual+1;total=(total or 0)+slot_width
            elseif node.n==G.UIT.B then spacers[#spacers+1]=node.config.w;total=(total or 0)+node.config.w end
        end
        check(actual==expected,'Row holds the expected number of Jokers')
        check(math.abs((total or 0)-5*slot_width)<0.000001,'Row width remains fixed')
        if expected<5 then
            check(#spacers==2 and math.abs(spacers[1]-spacers[2])<0.000001,
                'Partial row uses symmetric side spacers')
        end
    end
end
check_centered_pack(rows,9)
for _,amount in ipairs({8,7,6,5,4,3,2,1}) do
    local partial={};for i=1,amount do partial[i]=keys[i] end
    balanced=D.pack_ui.build(partial,{round=4,pick=2,pack_id='layout'..amount},'balanced',function() end)
    grid=balanced.nodes[1].nodes[#balanced.nodes[1].nodes].nodes[1]
    rows=grid.nodes[1].nodes
    check_centered_pack(rows,amount)
end
local source={};for i=1,13 do source[i]=keys[i] end
local before=table.concat(source,'|')
local function tray_cards(node,out)
    out=out or {}
    if node.n==G.UIT.O then for _,card in ipairs(node.config.object.cards) do if card.draftout_tray then out[#out+1]=card end end end
    for _,child in ipairs(node.nodes or {}) do tray_cards(child,out) end
    return out
end
local tray=D.views.team_tray(function() return source end,'own-pool')
local previews=tray_cards(tray)
check(#previews==6 and previews[1].config.center==G.P_CENTERS[keys[13]],'Tray starts with six most recent picks')
local active=D.pack_ui.active
previews[1]:click();check(D.pack_ui.active==active and #D.pack_ui.choices()==0,'Tray previews cannot change selections')
local ref={config={ref_table=D.views.tray}}
-- Isolate the navigation callback from the active main screen's tray identity.
local show_ref=D.ui.show;D.ui.show=function() end
G.FUNCS.draftout_tray_next(ref)
check(#tray_cards(D.views.team_tray(function() return source end,'own-pool'))==6)
G.FUNCS.draftout_tray_next(ref)
check(#tray_cards(D.views.team_tray(function() return source end,'own-pool'))==1,'Last tray page contains remaining pick')
G.FUNCS.draftout_tray_sort(ref)
local rarity_cards=tray_cards(D.views.team_tray(function() return source end,'own-pool'))
check(D.views.tray.sort=='Rarity' and D.views.tray.page==1)
for i=2,#rarity_cards do check(rarity_cards[i-1].config.center.rarity>=rarity_cards[i].config.center.rarity) end
G.FUNCS.draftout_tray_sort(ref)
check(D.views.tray.sort=='Draft order')
local ordered=tray_cards(D.views.team_tray(function() return source end,'own-pool'))
check(ordered[1].config.center==G.P_CENTERS[keys[1]] and table.concat(source,'|')==before,'Sorting never mutates the roster')
D.ui.show=show_ref
-- Timer colour and one optional cue per pick survive refresh/team viewing.
G.C.ORANGE={};SMODS.current_mod.config.timer_alerts=true
local seconds,paused=11,false
local token={round=1,pick=8,pack_id='warning'}
local function left() return seconds,paused end
D.local_clock=nil;D.local_launcher=true;D.mode='local'
D.pack_ui.build(nine,token,'warning',function() end,nil,{time_left=left})
local count=#sounds
G:update(0.02);check(D.pack_ui.ui.timer_colour==G.C.WHITE)
seconds=10;G:update(0.02);check(D.pack_ui.ui.timer_colour==G.C.ORANGE and #sounds==count,'Amber at ten without sound')
seconds=5;G:update(0.02);check(D.pack_ui.ui.timer_colour==G.C.RED and #sounds==count+1,'Red and one sound at five')
D.pack_ui.build(nine,token,'warning',function() end,nil,{time_left=left});G:update(0.02)
check(#sounds==count+1,'Refreshing cannot replay the cue')
D.views.team={get_keys=function() return {} end,time_left=left,page=1};G:update(0.02)
check(#sounds==count+1,'My Team cannot replay the cue');D.views.team=nil
SMODS.current_mod.config.timer_alerts=false
D.pack_ui.build(nine,{round=1,pick=9,pack_id='muted'},'warning',function() end,nil,{time_left=left})
G:update(0.02);check(#sounds==count+1 and D.pack_ui.ui.timer_colour==G.C.RED,'Muting sound retains visual warning')
SMODS.current_mod.config.timer_alerts=true;paused=true
D.pack_ui.build(nine,{round=2,pick=9,pack_id='paused'},'warning',function() end,nil,{time_left=left});G:update(0.02)
check(#sounds==count+1 and D.pack_ui.ui.timer_colour==G.C.WHITE,'Paused timers do not sound')
paused=false;G:update(0.02);check(#sounds==count+2,'Resumed low timer sounds once')
local colour={config={}};G.FUNCS.draftout_timer_colour(colour);check(colour.config.colour==G.C.RED)
-- The solo preview makes all recap pages reviewable without exposing online pools.
SMODS.current_mod.config.pick_seconds=0;SMODS.current_mod.config.picks_per_turn=2
SMODS.current_mod.config.packs_per_player=3
local complete=D.start('RECAP_PREVIEW')
while not complete.done do
    local seat=D.core.next_seat(complete)
    D.core.submit(complete,seat,D.core.auto_keys(complete,seat,{},function(n) return n end),D.core.token(complete,seat))
end
local recap=D.recap.make(complete,D.catalog(),{})
check(D.recap.validate(recap,{rounds=3,picks=2,catalog=D.catalog()}),'Recap validates against draft history')
local broken=D.core.copy(recap);broken.players[1].keys[1]=broken.players[2].keys[1]
check(not D.recap.validate(broken,{rounds=3,picks=2,catalog=D.catalog()}),'Duplicate cross-seat ownership rejected')
broken=D.core.copy(recap);broken.omitted={}
check(not D.recap.validate(broken,{rounds=3,picks=2,catalog=D.catalog()}),'Missing omitted types rejected')
G.FUNCS.draftout_recap_local()
check(D.recap.open and D.recap.preview and #cards_in(D.screen())==12,'Solo recap paginates a full roster')
check(not D.recap.available(),'Solo preview does not replace saved online recap')
local recap_cards=cards_in(D.screen());check(recap_cards[1].draftout_label:find('P1.1'),'Pick order labels include pack and turn')
G.FUNCS.draftout_recap_tab({config={ref_table=5}})
check(#D.recap.view.omitted==33 and #cards_in(D.screen())==12,'Undrafted tab shows omitted types')
G.FUNCS.draftout_recap_next();G.FUNCS.draftout_recap_next()
check(#cards_in(D.screen())==9,'Undrafted last page includes all remaining types')
G.FUNCS.draftout_recap_close();check(not D.recap.open)

-- Shared online waiting presentation still shows only the own-team tray.
local own={keys[1],keys[2]}
D.views.readiness({{name='A',ready=true},{name='B'},{name='C'},{name='D'}},1,1)
local waiting_screen=D.views.waiting(function() return own end,'WAIT42')
check(#cards_in(waiting_screen)==0,'Waiting contains no enlarged selected-card recap')
local own_tray=tray_cards(waiting_screen)
check(#own_tray==0 and D.roster_context.identity=='WAIT42','Waiting uses the separate own-team roster panel')
check(D.views.summary.waiting=='Picks locked - waiting for 3 players')

-- Two-seat hotseat draft, including settings lock, pools and recap navigation.
D.mode='local';D.local_launcher=true
SMODS.current_mod.config.local_players=4
G.FUNCS.draftout_players_cycle()
check(D.draft_options().player_count==2 and D.settings_ui.players=='Local draft: 2 players')
SMODS.current_mod.config.packs_per_player=3
SMODS.current_mod.config.picks_per_turn=1
SMODS.current_mod.config.pack_effects=false
local duo=D.start('LOCAL-DUO')
G.FUNCS.draftout_players_cycle()
check(D.draft_options().player_count==2,'Player count is locked during a local draft')
D.ui.show()
check(D.views.summary.label=='0/2 confirmed','Readiness uses the active seat count')
check(not pcall(D.core.token,duo,3),'No phantom third seat')
local turns=0
while not duo.done do
    local seat=D.core.next_seat(duo)
    check(D.core.submit(duo,seat,{duo.current[seat].cards[1]},D.core.token(duo,seat)))
    turns=turns+1;check(turns<=54,'Two-seat draft must finish')
end
check(duo.total==54 and #duo.pools==2 and #duo.pools[1]==27 and #duo.pools[2]==27)
D.ui.show()
local completed=D.screen()
check(#duo.history==2 and D.core.export_pool(duo,2).player_count==2)
G.FUNCS.draftout_recap_local()
check(#D.recap.view.players==2 and #D.recap.view.omitted==#D.catalog()-54)
G.FUNCS.draftout_recap_tab({config={ref_table=3}})
check(D.recap.tab==3,'Third recap tab shows undrafted Jokers')
check(D.recap.screen()~=nil,'Two-seat recap renders')
G.FUNCS.draftout_recap_tab({config={ref_table=4}})
check(D.recap.tab==3,'No phantom fourth recap tab')
G.FUNCS.draftout_recap_close()
D.local_launcher=true;G.FUNCS.draftout_players_cycle()
check(D.draft_options().player_count==4,'Local testing can switch back to four seats')
local legacy=D.start('LEGACY-FOUR');legacy.player_count=nil
check(D.core.player_count(legacy)==4 and D.core.token(legacy,4).pack_id=='r1s4',
    'Existing saved four-player drafts keep their seat count')

print('adapter_spec: ' .. checks .. ' assertions passed (mocked game API)')

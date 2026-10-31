local mod = SMODS.current_mod
-- Burglar logo, displayed only on Burglar's private Royale lobby page.
SMODS.Atlas({
    key = 'burglar_lobby',
    path = 'burglar_lobby.png',
    px = 1024,
    py = 384,
    disable_mipmap = true,
})
-- Native pixel-sprite selection caret. The sprite is attached to the Joker
-- itself, so no extra UI nodes can affect the pack grid's sizing or spacing.
SMODS.Atlas({
    key = 'selection_caret',
    path = 'selection_caret.png',
    px = 13,
    py = 9,
    disable_mipmap = true,
})
local live_overlay = assert(SMODS.load_file('burglar/overlay.lua',mod.id))()
local mod_icon = assert(SMODS.load_file('burglar/mod_icon.lua',mod.id))()
if MPAPI and MPAPI.on_loaded then MPAPI.on_loaded(mod_icon.install) else mod_icon.install() end
local core = assert(SMODS.load_file("burglar/core.lua", mod.id))()
local vanilla_keys = assert(SMODS.load_file("burglar/vanilla_keys.lua", mod.id))()
local atlas_compat = assert(SMODS.load_file("burglar/atlas_compat.lua", mod.id))()
local fresh_seed = assert(SMODS.load_file("burglar/seed.lua", mod.id))()
local deck_cycle = assert(SMODS.load_file('burglar/deck_cycle_compat.lua', mod.id))()
if MPAPI and MPAPI.on_loaded then MPAPI.on_loaded(deck_cycle.install) else deck_cycle.install() end
local collection = assert(SMODS.load_file('burglar/collection.lua', mod.id))()
if MPAPI and MPAPI.on_loaded then MPAPI.on_loaded(collection.install) else collection.install() end
-- Repair existing animation atlas metadata after loader/texture-mod startup.
local function repair_atlases()
    for _, atlas in pairs(G.ANIMATION_ATLAS or {}) do atlas_compat.repair(atlas) end
end
if MPAPI and MPAPI.on_loaded then MPAPI.on_loaded(repair_atlases) end
local D = {core = core, mod = mod, message = "", page = 1}
D.now = function() return love and love.timer and love.timer.getTime() or os.clock() end
local diagnostics=assert(SMODS.load_file('burglar/diagnostics.lua',mod.id))()(D)
D.clock = assert(SMODS.load_file('burglar/turn_clock.lua',mod.id))()
local showman=assert(SMODS.load_file('burglar/showman.lua',mod.id))()(D)
DRAFTOUT = D -- Developer access; no multiplayer or trust boundary is implied.
-- Migrate pre-9-card settings once; saved runs own their original pool.
if mod.config.draft_rules ~= 6 then
    mod.config.draft_rules,mod.config.pack_size=6,9
    mod.config.packs_per_player,mod.config.picks_per_turn=3,1
end
function D.draft_options()
    local rounds,picks=mod.config.packs_per_player,mod.config.picks_per_turn
    if type(rounds)~='number' or rounds~=math.floor(rounds) or rounds<1 or rounds>4 then rounds=3 end
    if picks~=1 and picks~=2 then picks=1 end
    return {pack_size=9,packs_per_player=rounds,picks_per_turn=picks,player_count=mod.config.local_players==2 and 2 or 4,open_deck_lists=mod.config.open_deck_lists==true}
end
-- A rules update invalidates old draft configurations, not existing run saves.
local allowed_keys={}
for _,key in ipairs(vanilla_keys) do allowed_keys[key]=true end
local function current_pool(pool)
    if not pool or pool.draft_schema~=core.SCHEMA or type(pool.keys)~='table' then return false end
    for _,key in ipairs(pool.keys) do if not allowed_keys[core.key(key)] then return false end end
    return true
end
if mod.config.session and mod.config.session.schema~=core.SCHEMA then
    mod.config.session,mod.config.armed_seat=false,false
    D.message='Draft rules updated. Start a fresh draft.'
end
-- Retire settings from the removed standalone draft tool. Saved runs own their pool.
for _,key in ipairs({'armed_online','online_pool','server_host','server_port','join_room','reconnect'}) do
    mod.config[key]=nil
end


local function save()
    SMODS.save_mod_config(mod)
end

local function name(key)
    return localize({type = "name_text", set = "Joker", key = core.key(key)})
end
D.joker_name = name

function D.catalog()
    local keys = {}
    for _, key in ipairs(vanilla_keys) do
        local c = G.P_CENTERS[key]
        -- Use vanilla identity, even if another mod has taken ownership of it.
        if c and c.set == "Joker" and not c.hidden
            and (c.rarity == 1 or c.rarity == 2 or c.rarity == 3) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    return keys
end

assert(SMODS.load_file('burglar/cubes.lua',mod.id))()(D)

function D.fresh_seed()
    local seed = fresh_seed(mod.config, love.math.random)
    save()
    return seed
end

function D.start(seed)
    if D.open_lists then D.open_lists.open=false end
    local options=D.draft_options()
    options.seed=seed or D.fresh_seed()
    local keys,cube_name=D.cubes.selected()
    D.cubes.capacity(keys,options)
    local s = core.new(keys, options)
    s.cube_name=cube_name
    mod.config.session, mod.config.armed_seat = s, false
    if D.pack_ui then D.pack_ui.reset_session() end
    s.timer_setting = D.clock.setting(mod.config.pick_seconds)
    s.timer_seconds = D.clock.seconds(mod.config.pick_seconds) -- Legacy fixed-timer save fallback.
    D.local_clock = nil
    D.more_open=false
    if D.views then D.views.team,D.views.tray,D.views.roster = nil,nil,nil end
    D.local_launcher = false
    D.page, D.message = 1, ""
    save()
    return s
end

function D.arm(seat)
    local pool = core.export_pool(assert(mod.config.session, "No draft"), seat)
    assert(current_pool(pool),'Saved roster uses an older Joker pool. Start a fresh draft.')
    for _, key in ipairs(pool.keys) do assert(G.P_CENTERS[core.key(key)], "Missing Joker: " .. key) end
    mod.config.armed_seat = seat
    save()
    D.message = "Seat " .. seat .. " armed for future new runs."
    return pool
end

-- A copy belongs to the run, so config edits/redrafting cannot change a live run.
-- G.GAME is saved by Balatro; continuing a saved run keeps its original pool.
local start_run_ref = Game.start_run
function Game:start_run(args)
    if D.open_lists then D.open_lists.open=false end
    args = args or {}
    local pending
    if not args.savetext then
        if D.mpbridge then pending = D.mpbridge.prepare_run() end
        if pending then
            -- Multiplayer PvP supplies the actual shared match seed in args.
        elseif MPAPI and MPAPI.get_current_lobby and MPAPI.get_current_lobby() then
            -- Local testing pools apply only outside an API lobby.
        elseif mod.config.armed_seat then
            pending = core.export_pool(assert(mod.config.session, "No draft"), mod.config.armed_seat)
        end
    end
    showman.set(not not (pending or (args.savetext and args.savetext.GAME and args.savetext.GAME.draftout_pool)))
    local result = start_run_ref(self, args)
    if not args.savetext then self.GAME.draftout_pool = pending end
    return result
end

local function has_key(keys, key)
    for _, v in ipairs(keys) do if v == key then return true end end
    return false
end

local function drafted_joker_available(game,key)
    return not (game.banned_keys or {})[key]
        and key~='j_ring_master'
        and not (key=='j_gros_michel' and (game.pool_flags or {}).gros_michel_extinct)
end

local copies=assert(SMODS.load_file('burglar/copy_pool.lua',mod.id))()(D)
D.copy_pool=copies
local function pool_candidates(pool)
    local keys,seen={},{}
    for _,id in ipairs(pool.keys) do
        local key=core.key(id)
        if not seen[key] then keys[#keys+1]=key;seen[key]=true end
    end
    local limits,used
    if pool.copy_limits then limits,used=copies.counts(G.GAME.draftout_pool or pool) end
    local function available(key)
        return drafted_joker_available(G.GAME,key)
            and (not limits or (used[key] or 0)<(limits[key] or 0))
    end
    return keys,available
end
function D.shop_key(pool, forced_key, rarity, strict_rarity)
    local game=G.GAME
    local keys,available=pool_candidates(pool)
    local function eligible(key)
        return available(key) and (pool.copy_limits or not (game.used_jokers or {})[key] or SMODS.showman(key))
    end
    local preferred
    if type(rarity)=='number' then preferred=rarity>0.95 and 3 or rarity>0.7 and 2 or 1
    else preferred=({Common=1,Uncommon=2,Rare=3})[rarity] end
    if strict_rarity then
        local source=keys;keys={}
        for _,key in ipairs(source) do
            local center=G.P_CENTERS[key]
            local r=center and (({Common=1,Uncommon=2,Rare=3})[center.rarity] or center.rarity)
            if r==preferred then keys[#keys+1]=key end
        end
    end
    if forced_key and has_key(keys,forced_key) and available(forced_key)
        and (not strict_rarity or eligible(forced_key)) then return forced_key end
    local weights={0.7*(game.common_mod or 1),0.25*(game.uncommon_mod or 1),0.05*(game.rare_mod or 1)}
    local function roll() return pseudorandom('draftout_shop') end
    local key=core.sample(keys,G.P_CENTERS,eligible,roll,weights,preferred)
    -- Jimbo is the sole exhaustion exception: it need not be drafted and may
    -- exceed its copy cap. Never rewrite the player's roster to add it.
    return key or 'j_joker'
end

function D.common_keys(pool)
    local keys = {}
    for _, key in ipairs(pool.keys) do
        local c = G.P_CENTERS[core.key(key)]
        if c and (c.rarity == 1 or c.rarity == "Common")
            and drafted_joker_available(G.GAME,core.key(key)) then keys[#keys + 1] = key end
    end
    return keys
end

-- Shop slots and the 'jud'/'rif'/'buf' markers verified in supplied game/SMODS code.
-- Selecting before construction preserves edition/sticker/materialization handling.
local create_card_ref = create_card
function create_card(set, area, legendary, rarity, skip_materialize, soulable, forced_key, append)
    local pool = G.GAME and G.GAME.draftout_pool
    if pool and set=='Joker' and append=='wra' then showman.set(true) end
    local generated = (append == "jud" or append == "rif") and (not area or area == G.jokers)
    local rarity_tag=append=='rta' and 1 or append=='uta' and 0.9
    if pool and set=='Joker' and rarity_tag then
        forced_key=D.shop_key(pool,forced_key,rarity_tag,true)
        legendary,soulable=nil,false
    elseif pool and set == "Joker" and generated then
        local source_pool = pool
        if append == "rif" then
            source_pool = {keys = D.common_keys(pool),copy_limits=pool.copy_limits}
        end
        forced_key = D.shop_key(source_pool, forced_key, append == "rif" and 0 or nil)
        legendary, soulable = nil, false
    elseif pool and set == "Joker" and append == "buf" then
        forced_key = D.shop_key(pool, forced_key, rarity)
        legendary, soulable = nil, false
    elseif pool and set == "Joker" and area and area == G.shop_jokers then
        forced_key = D.shop_key(pool, forced_key, rarity)
        legendary, soulable = nil, false
    end
    return copies.track(create_card_ref(set, area, legendary, rarity, skip_materialize, soulable, forced_key, append),area)
end
copies.install()

local function line(text, scale)
    return {n = G.UIT.R, config = {align = "cm", padding = 0.03}, nodes = {
        {n = G.UIT.T, config = {text = text, scale = scale or 0.32, colour = G.C.UI.TEXT_LIGHT}},
    }}
end

local function button(label, action, data, width, tooltip)
    return {n = G.UIT.C, config = {
        align = "cm", minw = width or 3.5, minh = 0.43, padding = 0.06,
        r = 0.08, colour = G.C.BLUE, hover = true, shadow = true,
        button = action, ref_table = data, tooltip = tooltip,
    }, nodes = {{n = G.UIT.T, config = {
        text = label, scale = 0.28, colour = G.C.WHITE,
    }}}}
end

local function row(nodes)
    return {n = G.UIT.R, config = {align = "cm", padding = 0.05}, nodes = nodes}
end

local function has_pack(node)
    if node.config and node.config.id == 'draftout_pack_selection' then return true end
    for _, child in ipairs(node.nodes or {}) do if has_pack(child) then return true end end
    return false
end

local function show()
    local screen = D.screen()
    local selecting = has_pack(screen)
    local drafting=selecting or (D.mode=='mp' and D.mpbridge and D.mpbridge.view and not D.mpbridge.view.done
        and not (D.views and D.views.team) and not (D.recap and D.recap.open))
    if selecting then
        screen.nodes[#screen.nodes+1] = D.pack_ui.footer()
    elseif drafting then
        screen.nodes[#screen.nodes+1] = row(D.views.navigation())
    end
    if drafting and D.more_open then screen.nodes[#screen.nodes+1]=D.views.utilities() end
    if not drafting and not (D.recap and D.recap.open) and not (D.open_lists and D.open_lists.open) then
        screen.nodes[#screen.nodes+1]=row({button(D.mode=='mp' and 'Return to lobby' or 'Back','draftout_close',nil,3.3)})
    end
    -- A split surface prevents the owned-roster sidebar from shifting the
    -- pack's 2x5 selection grid. Both sides live in the SAME overlay lifecycle.
    if drafting and D.roster_context and not (D.views and D.views.team) then
        local ctx=D.roster_context
        local roster=D.views.roster_sidebar(ctx.get_keys,ctx.identity,{total=ctx.total})
        local panel={n=G.UIT.C,config={align='cm',padding=0.10,
            r=0.12,colour={0.27,0.40,0.41,1},
            id='draftout_border_surface'},nodes={screen}}
        -- A native Balatro row stretches its direct column children to the
        -- tallest column.  Never place coloured panels directly in that row:
        -- it paints a giant shared rectangle above/below their real content.
        -- Instead stretch two CLEAR layout holders and top-align the compact
        -- coloured panels in inner rows. Their top edges share an anchor;
        -- reserved invisible height keeps them steady while pack art opens.
        local roster_holder={n=G.UIT.C,config={align='tm',padding=0,
            colour=G.C.CLEAR},nodes={{n=G.UIT.R,config={align='tm',
            padding=0,colour=G.C.CLEAR},nodes={roster}}}}
        local draft_holder={n=G.UIT.C,config={align='tm',padding=0,
            colour=G.C.CLEAR,minh=10.45},nodes={{n=G.UIT.R,
            config={align='tm',padding=0,colour=G.C.CLEAR},nodes={panel}}}}
        screen={n=G.UIT.R,config={align='cm',padding=0.08,
            colour=G.C.CLEAR,draftout_split=true},nodes={roster_holder,draft_holder}}
    end
    live_overlay(D,screen)
end

function D.screen()
    if D.open_lists and D.open_lists.open then return D.open_lists.screen() end
    if D.recap and D.recap.open then return D.recap.screen() end
    if D.mode=='bracket' and D.roster_duel then return D.roster_duel.screen() end
    if D.views and D.views.team then return D.views.team_screen() end
    if D.mode == 'mp' and D.multiplayer_screen then return D.multiplayer_screen() end
    local s = mod.config.session
    if s and not s.done and s.schema ~= core.SCHEMA then
        mod.config.session = false; s = nil
        D.message = "Old unfinished draft cleared. Start a fresh draft."
    end
    local active=s and not s.done and not D.local_launcher
    local nodes = {}
    if not active then
        nodes[#nodes+1]=line("BURGLAR / LOCAL DEVELOPMENT DRAFT", 0.36)
        nodes[#nodes+1]=line("Solo test: control each seat on this computer.", 0.25)
    end
    if D.local_launcher then
        nodes[#nodes+1] = line("Start fresh to randomize every pack, or resume your saved draft.", 0.26)
        nodes[#nodes+1] = row({button("Start fresh draft", "draftout_new", nil, 5)})
        nodes[#nodes+1] = D.draft_settings()
        nodes[#nodes+1] = row({D.player_button()})
        nodes[#nodes+1] = row({D.timer_button()})
        if s then
            nodes[#nodes+1] = row({button("Resume saved draft", "draftout_resume", nil, 5)})
            nodes[#nodes+1] = line(s.done and "Saved draft: complete."
                or ("Saved draft: pack " .. s.round .. "/" .. s.rounds .. ", turn " .. s.pick), 0.25)
        end
    elseif not s then
        nodes[#nodes + 1] = line("Random 9-Joker packs. Pass left, then right on the next pack.")
        nodes[#nodes+1] = D.draft_settings()
        nodes[#nodes+1] = row({D.player_button()})
        nodes[#nodes + 1] = row({button("Start draft", "draftout_new")})
    elseif not s.done then
        local seat = core.next_seat(s)
        local rows = {}
        for i=1,core.player_count(s) do rows[i]={name='Seat '..i,connected=true,ready=not not s.submitted[i]} end
        D.ensure_local_clock(s,seat)
        nodes[#nodes+1] = D.views.header('BURGLAR  |  Pack '..s.round..'/'..s.rounds..'  -  Pick '..s.pick..'/'..math.ceil(core.round_size(s.round,s.rounds,s.pack_size)/s.picks_per_turn),D.local_time_left)
        nodes[#nodes+1] = D.views.readiness(rows,seat,s.round)
        nodes[#nodes+1] = D.pack_ui.build(s.current[seat].cards, core.token(s, seat),
            'local:' .. s.seed .. ':' .. seat, function(keys, token)
                D.local_submit(s,seat,keys,token)
            end, nil,
            {time_left=D.local_time_left,picks_per_turn=s.picks_per_turn,get_team=function() return s.pools[seat] end,
                total=core.roster_size(s.rounds)})
    else
        local count = 0
        for seat = 1, core.player_count(s) do count = count + #s.pools[seat] end
        nodes[#nodes + 1] = line("Draft complete. " .. count .. " Jokers drafted.")
        if D.open_lists.available() then nodes[#nodes+1]=row({D.open_lists.button()}) end
        nodes[#nodes+1]=row({button('Preview draft recap','draftout_recap_local',nil,4)})
        if mod.config.armed_seat then
            nodes[#nodes+1]=D.views.completed(s.pools[mod.config.armed_seat],
                'Seat '..mod.config.armed_seat..' selected. Close this screen and start a new normal run.',true)
        end
        for seat = 1, core.player_count(s) do
            nodes[#nodes + 1] = row({button("Use seat " .. seat .. " (" .. #s.pools[seat] .. " Jokers)", "draftout_arm", {seat = seat}, 5),
                D.views.team_button(function() return s.pools[seat] end,nil,'View team')})
        end
        nodes[#nodes + 1] = line("Close this menu, then start a NEW run. Continue preserves its old pool.", 0.26)
        nodes[#nodes + 1] = row({button("Start another draft", "draftout_new")})
    end
    if mod.config.armed_seat then
        nodes[#nodes + 1] = line("Future new runs: seat " .. mod.config.armed_seat)
        nodes[#nodes + 1] = row({button("Disarm future runs", "draftout_disarm")})
    end
    if D.message ~= "" then nodes[#nodes + 1] = line(D.message:sub(1, 95), 0.25) end
    return {n = G.UIT.C, config = {align = "cm", padding = 0.08}, nodes = nodes}
end

G.FUNCS.draftout_open = function()
    D.mode = 'local'
    if D.open_lists then D.open_lists.open=false end
    D.more_open=false
    D.local_launcher = true; D.local_clock = nil; D.views.team = nil
    if D.pack_ui then D.pack_ui.clear() end
    D.page = 1; show()
end
G.FUNCS.draftout_resume = function()
    D.local_launcher, D.message = false, "Resumed saved draft. Its packs are unchanged."
    D.pack_ui.clear(); show()
end
G.FUNCS.draftout_close = function()
    D.local_clock = nil; D.views.team = nil
    G.FUNCS.exit_overlay_menu()
end
G.FUNCS.draftout_new = function()
    local ok, err = pcall(D.start)
    if not ok then D.message = tostring(err) end
    show()
end
G.FUNCS.draftout_arm = function(e)
    local ok, err = pcall(D.arm, e.config.ref_table.seat)
    if not ok then D.message = tostring(err) end
    show()
end
G.FUNCS.draftout_disarm = function()
    mod.config.armed_seat = false
    D.message = "Future new runs use normal shops."; save(); show()
end

D.ui = {line = line, row = row, button = button, show = show, overlay = live_overlay}
assert(SMODS.load_file('burglar/pack_ui.lua', mod.id))()(D)
assert(SMODS.load_file('burglar/draft_views.lua', mod.id))()(D)
assert(SMODS.load_file('burglar/recap.lua', mod.id))()(D)
assert(SMODS.load_file('burglar/roster_duel.lua', mod.id))()(D)
assert(SMODS.load_file('burglar/open_lists.lua', mod.id))()(D)
assert(SMODS.load_file('burglar/mpapi.lua', mod.id))()(D)
assert(SMODS.load_file('burglar/lobby_entry.lua', mod.id))()(D)
assert(SMODS.load_file('burglar/lobby_logo.lua', mod.id))()(D)
assert(SMODS.load_file('burglar/results_ui.lua', mod.id))()(D)
assert(SMODS.load_file('burglar/spectator.lua', mod.id))()(D)
D.updates.add('diagnostics',function()
    -- Diagnostic/storage failures must never interrupt gameplay.
    if not pcall(diagnostics.tick) then diagnostics.status='Diagnostic update skipped' end
end)
if mod.config.diagnostics then diagnostics.set_enabled(true) end

D.settings_ui={timer='',effects='',picks='',packs='',alerts='',players='',diagnostics=''}
local function settings_labels()
    local options=D.draft_options()
    D.settings_ui.cube='Draft pool: '..D.cubes.label()
    D.settings_ui.open_lists='Open deck lists: '..(mod.config.open_deck_lists==true and 'On' or 'Off')
    D.settings_ui.players='Local draft: '..options.player_count..' players'
    D.settings_ui.picks='Pick '..options.picks_per_turn..' per turn'
    D.settings_ui.packs=options.packs_per_player..' packs each ('..core.roster_size(options.packs_per_player)..' Jokers)'
    local seconds=D.clock.seconds(mod.config.pick_seconds)
    D.settings_ui.timer=mod.config.pick_seconds=='scaling' and 'Scaling: 5s per Joker'
        or ('Pick timer: '..(seconds==0 and 'Off' or seconds..'s'))
    D.settings_ui.alerts='Timer sound: '..(mod.config.timer_alerts==false and 'Off' or 'On')
    D.settings_ui.effects='Pack effects: '..(mod.config.pack_effects==false and 'Off' or 'On')
    D.settings_ui.diagnostics='Diagnostics: '..(mod.config.diagnostics==true and 'On' or 'Off')
end
local function settings_button(field,action,width)
    settings_labels()
    local b=button('',action,nil,width)
    b.nodes[1].config.text=nil
    b.nodes[1].config.ref_table,b.nodes[1].config.ref_value=D.settings_ui,field
    return b
end
function D.draft_settings()
    -- Keep one row in the parent menu's vertical stack. A bare column here
    -- makes Balatro place the following controls beside the settings block.
    return row({{n=G.UIT.C,config={align='cm',padding=0.03},nodes={
        row({settings_button('cube','draftout_cube_cycle',7.4)}),
        row({settings_button('picks','draftout_picks_cycle',3.2),settings_button('packs','draftout_packs_cycle',4.2)}),
        row({settings_button('open_lists','draftout_open_lists_toggle',7.4)})}}})
end
local function can_change_draft_settings()
    local b=D.mpbridge
    if D.mode=='mp' then
        local l=MPAPI and MPAPI.get_current_lobby()
        return l and l.is_host and not l:is_game_started() and b and (b.phase=='checking' or b.phase=='idle' or b.phase=='error')
    end
    return not mod.config.session or D.local_launcher or mod.config.session.done
end
G.FUNCS.draftout_open_lists_toggle=function()
    if not can_change_draft_settings() then return end
    mod.config.open_deck_lists=not mod.config.open_deck_lists
    settings_labels();save()
end
G.FUNCS.draftout_cube_cycle=function()
    if not can_change_draft_settings() then return end
    local choices=D.cubes.choices()
    local current=mod.config.draft_cube or 'default'
    local next_id=choices[1]
    for i,id in ipairs(choices) do if id==current then next_id=choices[i%#choices+1];break end end
    mod.config.draft_cube=next_id
    local ok,keys=pcall(D.cubes.selected)
    D.message=ok and (D.cubes.label()..': '..#keys..' eligible Jokers. Use fewer packs for smaller pools.') or tostring(keys)
    settings_labels();save()
    if D.mode=='mp' and D.mpbridge then D.mpbridge.message=D.message end
    if D.mode=='mp' and D.mpbridge and D.mpbridge.phase=='checking' then
        local checked,err=pcall(D.mpbridge.begin)
        if not checked then D.mpbridge.reset();D.message=tostring(err);D.mpbridge.message=D.message end
    end
    show()
end
function D.player_button()
    return settings_button('players','draftout_players_cycle',4)
end
G.FUNCS.draftout_players_cycle=function()
    if D.mode=='mp' or not can_change_draft_settings() then return end
    mod.config.local_players=D.draft_options().player_count==2 and 4 or 2
    settings_labels();save()
end
G.FUNCS.draftout_picks_cycle=function()
    if not can_change_draft_settings() then return end
    mod.config.picks_per_turn=D.draft_options().picks_per_turn%2+1
    settings_labels();save()
end
G.FUNCS.draftout_packs_cycle=function()
    if not can_change_draft_settings() then return end
    mod.config.packs_per_player=D.draft_options().packs_per_player%4+1
    settings_labels();save()
end
function D.timer_button()
    return settings_button('timer','draftout_timer_cycle',4)
end
G.FUNCS.draftout_timer_cycle=function()
    local values={0,'scaling',30,45,60,90}; local next_value=0
    for i,v in ipairs(values) do if v==D.clock.setting(mod.config.pick_seconds) then next_value=values[i%#values+1] end end
    mod.config.pick_seconds=next_value; settings_labels(); save()
end
G.FUNCS.draftout_alerts_toggle=function()
    mod.config.timer_alerts=mod.config.timer_alerts==false; settings_labels();save()
end
G.FUNCS.draftout_effects_toggle=function()
    mod.config.pack_effects=mod.config.pack_effects==false; settings_labels(); save()
end
G.FUNCS.draftout_diagnostics_toggle=function()
    diagnostics.set_enabled(mod.config.diagnostics~=true);settings_labels();save()
end
G.FUNCS.draftout_diagnostics_copy=function() diagnostics.copy() end
function D.local_time_left() return D.clock.left(D.local_clock,D.now()) end
function D.ensure_local_clock(s,seat)
    local c,token=D.local_clock,core.token(s,seat)
    if c and c.seed==s.seed and c.seat==seat and c.token.round==token.round
        and c.token.pick==token.pick and c.token.pack_id==token.pack_id then return end
    D.local_clock=D.clock.new(s.timer_setting or s.timer_seconds or 0)
    c=D.local_clock; c.seed,c.seat,c.token=s.seed,seat,token
    D.clock.reset(c,s.round..':'..s.pick,D.now(),#s.current[seat].cards)
end
function D.local_submit(s,seat,keys,token)
    local ok,err=core.submit(s,seat,keys,token); assert(ok,err)
    save(); D.local_clock=nil
    D.pack_ui.clear(); D.pack_ui.confirmed()
    D.message='Seat '..seat..' picks saved.'
end
function D.local_tick()
    local c,s=D.local_clock,mod.config.session
    if D.mode~='local' or D.local_launcher or not c or not s or s.done then return end
    if s.submitted[c.seat] or c.token.round~=s.round or c.token.pick~=s.pick then D.local_clock=nil; return end
    local _,expired=D.clock.update(c,D.now(),false)
    if expired then
        local preferred=D.pack_ui.choices()
        D.local_submit(s,c.seat,core.auto_keys(s,c.seat,preferred,love.math.random),c.token)
        show()
    end
end

mod.config_tab = function()
    local nodes = {
        line("Burglar settings"),
        row({D.timer_button(),settings_button('effects','draftout_effects_toggle',3.7)}),
        row({settings_button('alerts','draftout_alerts_toggle',4)}),
        row({settings_button('diagnostics','draftout_diagnostics_toggle',3.7),
            button('Copy diagnostic log','draftout_diagnostics_copy',nil,3.7)}),
        {n=G.UIT.R,config={align='cm'},nodes={{n=G.UIT.T,config={ref_table=diagnostics,
            ref_value='status',scale=0.23,colour=G.C.WHITE}}}},
        row({button("Local development draft", "draftout_open", nil, 5)}),
        row({button('Local spectator preview','draftout_spectate_demo',nil,5)}),
        row({button('Saved-roster 1v1 / bracket','draftout_bracket_open',nil,5)}),
        row({button("Disarm future runs", "draftout_disarm", nil, 5)}),
        line("Solo test pools apply to new normal runs.", 0.26),
    }
    if D.recap.available() then nodes[#nodes+1]=row({D.recap.button()}) end
    if D.mpbridge then table.insert(nodes, 2, row({button("Multiplayer PvP lobby draft", "draftout_mp_open", nil, 5)})) end
    return {n = G.UIT.ROOT, config = {align = "cm", padding = 0.2, colour = G.C.BLACK, r = 0.1}, nodes = nodes}
end

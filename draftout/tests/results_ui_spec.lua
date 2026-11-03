local config_seen
G={C={BLACK={},JOKER_GREY={}},GAME={}}
PVP={UI={end_game_body=function()end}}
MPAPI={on_loaded=function(f)f()end,end_screen_uibox=function(c)
 config_seen=c
 return {nodes={{config={},nodes={{config={colour=G.C.BLACK}},
  {config={button='leave',colour=G.C.BLACK}}}}}}
end}
assert(loadfile('draftout/results_ui.lua'))()({})
local options={body=PVP.UI.end_game_body,won=false,no_esc=true}
MPAPI.end_screen_uibox(options);assert(config_seen==options,'Ordinary PvP remains untouched')
G.GAME.draftout_pool={keys={}}
local def=MPAPI.end_screen_uibox(options)
assert(config_seen~=options and config_seen.body==options.body and config_seen.no_esc==true)
assert(options.bg_colour==nil,'Do not mutate caller options')
assert(def.nodes[1].nodes[1].config.colour~=G.C.BLACK,'Draftout result panels use the teal theme')
assert(def.nodes[1].nodes[2].config.button=='leave' and def.nodes[1].nodes[2].config.colour==G.C.BLACK,
 'Native action controls are preserved')
local other={body=function()end};MPAPI.end_screen_uibox(other)
assert(config_seen==other,'Other mod result builders remain untouched')
print('Draftout-only results theme and native control preservation passed')

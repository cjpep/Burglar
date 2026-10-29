-- Build the actual upstream picker and pillar helpers; no live server/rendering.
local base=os.getenv('DRAFTOUT_REFERENCE_ROOT') or '../../reference_mp_100/'
local created,removed,clicked=0,0,0
G={FUNCS={},UIT={R='R',C='C',T='T',O='O',ROOT='ROOT'},C={
 BLACK={},L_BLACK={},BLUE={},PURPLE={},RED={},GREEN={},ORANGE={},CLEAR={},WHITE={},MONEY={},
 UI={BACKGROUND_INACTIVE={},TEXT_INACTIVE={},TEXT_LIGHT={}}},
 ASSET_ATLAS={Joker={}},ANIMATION_ATLAS={mp_player_blind_chip={}},j_locked={pos={x=4,y=2}}}
mix_colours=function() return {} end
Sprite=function(x,y,w,h,atlas,pos)
 created=created+1
 local gone=false
 return {remove=function() assert(not gone,'double icon disposal');gone=true;removed=removed+1 end}
end
MPAPI={on_loaded=function(f)f()end,GameModes={},LobbyType={PRIVATE='private'}}
PVP={}
dofile(base..'BalatroMultiplayer-MultiplayerAPI-1.0.0/api/ui_pillar_row.lua')
dofile(base..'BalatroMultiplayer-MultiplayerPvP-1.0.0/ui/main_menu/game_select.lua')
G.FUNCS.mp_pvp_create_lobby_royale=function() clicked=clicked+1;return 'native guarded create' end
local install=dofile('burglar/lobby_entry.lua')
local D={mpbridge={}}
install(D);install(D)
local page=PVP.build_game_select_ui('create_lobby')
local columns=page.definition.nodes[1].nodes
assert(#columns==5 and created==5,'Exactly one added pillar plus four upstream modes')
assert(columns[1].nodes[1].config.id=='draftout_burglar')
assert(columns[2].nodes[1].config.id=='pvp_nemesis')
assert(columns[3].nodes[1].config.id=='pvp_royale')
assert(G.FUNCS.draftout_create_burglar_lobby()=='native guarded create' and clicked==1)
G.FUNCS.mp_pvp_create_lobby_royale=function() clicked=clicked+10 end
G.FUNCS.draftout_create_burglar_lobby();assert(clicked==11,'Delegates to current handler')
page:dispose();page:dispose();assert(removed==5,'All added and native sprites disposed once')
local practice=PVP.build_game_select_ui('practice')
assert(#practice.definition.nodes[1].nodes==5,'Practice retains its five original rulesets')
assert(practice.definition.nodes[1].nodes[1].nodes[1].config.id=='ruleset_mp_balanced')
practice:dispose();assert(removed==created)
G.j_locked=nil
local fallback=PVP.build_game_select_ui('create_lobby');fallback:dispose()
assert(removed==created,'Fallback icon also has page-owned cleanup')
print('lobby_entry_spec: native picker, matching helpers, routing, practice isolation and disposal passed')

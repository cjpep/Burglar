local make=assert(loadfile('draftout/lobby_logo.lua'))()
local reads,removed,created=0,0,0
local metadata={queue_mode='pvp_royale'}
local lobby={mod_id='MultiplayerPvP',_nakama=true,type='private',
 get_metadata=function() reads=reads+1;return metadata end,is_game_started=function()return false end}
MPAPI={on_loaded=function(f)f()end,get_current_lobby=function()return lobby end}
PVP={build_in_lobby_ui=function()return {nodes={}}end}
G={STAGES={MAIN_MENU=1},STAGE=1,UIT={ROOT=1,O=2,B=3},ROOM_ATTACH={},C={CLEAR={}},
 MAIN_MENU_UI={get_UIE_by_ID=function()return {}end}}
SMODS={create_sprite=function()return {states={drag={},hover={},collide={}}}end}
UIBox=function()created=created+1;return {remove=function()removed=removed+1 end}end
local D={updates={add=function(_,f)tick=f end}}
make(D);PVP.build_in_lobby_ui();tick()
assert(created==1 and reads==1,'Visible lobby queries metadata once and creates one logo')
tick();assert(created==1 and reads==2,'Stable lobby retains its existing logo')
G.STAGE=2
for i=1,600 do tick() end
assert(reads==2 and removed==1,'Gameplay does not poll lobby metadata; logo is released once')
G.STAGE=1;tick();assert(created==2,'Menu return restores the logo')
metadata.queue_mode='pvp_nemesis';tick();assert(removed==2,'Other modes clear the logo')
print('Lobby logo idle polling and ownership checks passed')

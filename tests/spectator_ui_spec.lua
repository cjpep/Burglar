-- Headless draw/lifecycle smoke test. LÖVE calls are stubs, not live rendering.
local W=dofile('burglar/spectator_wire.lua')
local clock,created,removed,depth,draws=0,0,0,0,0
local function forbidden() error('Viewer touched a gameplay API') end
Card,Sprite,save_run,pseudorandom=forbidden,forbidden,forbidden,forbidden
math.random=forbidden;Game={start_run=forbidden}
local image={getDimensions=function() return 710,950 end}
local atlas={image=image,px=71,py=95}
local font={getHeight=function() return 100 end,getWidth=function(_,s) return #s*50 end}
local lg={getDimensions=function() return 1920,1080 end,getFont=function() return font end,
    push=function() depth=depth+1 end,pop=function() depth=depth-1;assert(depth>=0) end,
    origin=function() end,setShader=function() end,setColor=function() end,setFont=function() end,
    scale=function() end,translate=function() end,rotate=function() end,setLineWidth=function() end,
    newQuad=function(...) return {...} end,draw=function() draws=draws+1 end,
    rectangle=function() end,print=function() end,line=function() end,
    inverseTransformPoint=function(x,y) return x,y end}
love={graphics=lg,mouse={getPosition=function() return 6,2 end}}
prep_draw=function() lg.push() end
G={FUNCS={},GAME={identity='original'},P_CENTERS={},P_CARDS={},
    ASSET_ATLAS={Joker=atlas,centers=atlas,cards=atlas,Tarot=atlas},C={WHITE={},CLEAR={}},
    ROOM={T={w=20,h=11}},UIT={ROOT='ROOT',R='R',C='C',T='T',O='O'},SETTINGS={paused=true}}
for _,key in ipairs({'j_joker','j_burglar','j_blueprint','j_gros_michel','j_abstract','j_droll',
    'j_zany','j_greedy_joker','j_lusty_joker','j_wrathful_joker',
    'p_buffoon_normal_1','p_arcana_normal_1'}) do
 G.P_CENTERS[key]={name=key,set='Joker',pos={x=0,y=0}}
end
G.P_CENTERS.c_base={name='Base',set='Default',pos={x=1,y=0}}
G.P_CENTERS.b_red={name='Red',set='Back',pos={x=0,y=0}}
for _,key in ipairs({'H_A','H_K','H_Q','H_J','H_T','S_A','D_7','C_2'}) do G.P_CARDS[key]={pos={x=0,y=0}} end
PVP={GAME={identity='pvp'},REF={identity='referee'}}
MPAPI={get_current_lobby=function() return nil end}
SMODS={load_file=function(path) return loadfile(path) end}
get_front_spriteinfo=function(front) return atlas,front.pos end
Moveable=function(x,y,w,h)
 created=created+1
 return {VT={x=x,y=y,w=w,h=h},states={hover={},click={},drag={},collide={}},remove=function() removed=removed+1 end}
end
local U={row=function(nodes) return {n='R',nodes=nodes} end,
 button=function(text,action,data) return {n='C',config={button=action,ref_table=data}} end}
G.FUNCS.overlay_menu=function(args)
 if G.OVERLAY_MENU then G.OVERLAY_MENU:remove() end
 local stage=args.definition.nodes[1].nodes[1].config.object
 G.OVERLAY_MENU={remove=function() stage:remove() end}
end
G.FUNCS.exit_overlay_menu=function() G.OVERLAY_MENU:remove();G.OVERLAY_MENU=nil end
local C=dofile('burglar/spectator_capture.lua')(W)
local S={wire=W,capture=C,stop_view=function() end,players=function() return {} end}
local D={mod={id='Draftout'},ui=U,now=function() return clock end}
dofile('burglar/spectator_ui.lua')(D,S)
local oldgame,oldpvp,oldref=G.GAME,PVP.GAME,PVP.REF
G.FUNCS.draftout_spectate_demo()
assert(S.demo and S.frame and #S.frame.areas.hand==0,'Demo begins before draw')
local stage=S.stage
for step=0,31 do
 clock=step*1.2+0.001;S.demo_tick();stage:draw()
 assert(S.stage==stage and created==1,'Frames keep the same table object')
 assert(depth==0,'Every draw restores the graphics stack')
end
assert(draws>0,'Table draws atlas artwork')
clock=2.5;S.demo_tick();assert(S.frame.areas.hand[1].selected,'Demo raises selected cards')
clock=3.7;S.demo_tick();assert(#S.frame.areas.hand==3 and #S.frame.areas.play==5,'Played cards leave the hand')
G.FUNCS.draftout_spectate_restart();assert(#S.frame.areas.hand==0)
G.FUNCS.draftout_spectate_pause();clock=clock+100;S.demo_tick()
assert(S.demo_step==0 and #S.frame.areas.hand==0,'Pause holds the demo across elapsed time')
G.FUNCS.draftout_spectate_step()
assert(S.demo_step==1 and #S.frame.areas.hand==8 and S.demo_paused,'Step advances once and stays paused')
G.FUNCS.draftout_spectate_pause();clock=clock+1.21;S.demo_tick()
assert(S.demo_step==2,'Resume continues from paused step')
for i=3,8 do G.FUNCS.draftout_spectate_step() end
assert(S.frame.phase=='shop' and #S.frame.areas.shop_booster==2,'Demo displays both shop packs')
local oldoffer=S.frame.areas.shop_jokers[2].uid
G.FUNCS.draftout_spectate_step()
assert(S.frame.areas.shop_jokers[2].uid~=oldoffer and S.frame.reroll_cost=='6','Demo changes offers and reroll cost')
S.players=function() return {{id='survivor',name='Last player'}} end
local selections=0
S.select=function(id) selections=selections+1;S.target=id;return true end
S.target=nil
G.FUNCS.draftout_spectate_next()
assert(S.target=='survivor' and selections==1,'Can select the sole survivor after the previous target leaves')
G.FUNCS.draftout_spectate_previous()
assert(selections==1,'Cycling the sole current target does not restart its buffer')
assert(G.GAME==oldgame and PVP.GAME==oldpvp and PVP.REF==oldref)
assert(G.SETTINGS.paused==true,'Viewer did not change pause state')
G.FUNCS.draftout_spectate_close();assert(not S.open and not G.OVERLAY_MENU)
assert(created==removed,'Persistent table removed exactly once')
print('spectator_ui_spec: demo controls, two packs, offer changes, sole-survivor selection, drawing and isolation passed')

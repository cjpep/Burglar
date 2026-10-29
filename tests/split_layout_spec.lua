-- UI-only regression: the roster has its own compact border and a stable
-- transparent parent, independent of the pack-opening panel's content height.
G={UIT={ROOT=1,R=2,C=3,O=4},C={CLEAR={0,0,0,0}},FUNCS={}}
local function boxes()
    return {remove=function()end}
end
G.FUNCS.overlay_menu=function(args)
    G.last_overlay=args
    G.OVERLAY_MENU=boxes()
end
function create_UIBox_generic_options(o) return {n=G.UIT.ROOT,config={colour=o.colour},nodes=o.contents} end
local show=assert(loadfile('burglar/overlay.lua'))()
local roster={n=G.UIT.C,config={id='draftout_roster_sidebar',colour={0.2,0.3,0.3,1}},nodes={}}
local panel={n=G.UIT.C,config={id='draftout_border_surface',colour={0.2,0.3,0.3,1}},nodes={}}
local split={n=G.UIT.R,config={align='cm',minh=10.45,draftout_split=true},nodes={roster,panel}}
local owner={}
show(owner,split)
local root=G.last_overlay.definition
assert(root.n==G.UIT.ROOT and root.config.colour==G.C.CLEAR,'shared outer frame must be transparent')
assert(root.nodes[1]==split,'split layout must remain direct child of overlay')
assert(split.config.minh==10.45,'transparent layout reserves constant height')
assert(split.nodes[1]==roster and split.nodes[2]==panel,'two independent panel surfaces retained')
assert(roster.config.colour~=G.C.CLEAR and panel.config.colour~=G.C.CLEAR,'each panel retains its own border')
-- No other screens are affected by split-only styling.
show({}, {n=G.UIT.R,config={},nodes={}})
assert(G.last_overlay.definition.n==G.UIT.ROOT)
print('Stable split-frame layout regression passed')

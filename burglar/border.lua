-- Decorative instance-only outline. No update hooks, timers or game-state writes.
local B={}
local function path(w,h)
    local c=math.min(0.10,w/8,h/8);local k=c/2
    local points={{c,0},{w-c,0},{w-c,k},{w-k,k},{w-k,c},{w,c},
        {w,h-c},{w-k,h-c},{w-k,h-k},{w-c,h-k},{w-c,h},
        {c,h},{c,h-k},{k,h-k},{k,h-c},{0,h-c},{0,c},{k,c},{k,k},{c,k},{c,0}}
    local total=0
    for i=1,#points-1 do
        local a,b=points[i],points[i+1]
        a.length=math.abs(b[1]-a[1])+math.abs(b[2]-a[2]);a.start=total
        total=total+a.length
    end
    return {w=w,h=h,points=points,total=total}
end
function B.point(p,d)
    d=d%p.total
    for i=1,#p.points-1 do
        local a,b=p.points[i],p.points[i+1]
        if d<=a.start+a.length then
            local t=(d-a.start)/a.length
            return a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t
        end
    end
end
B.path=path
function B.attach(box,owner)
    local node=box:get_UIE_by_ID('draftout_border_surface')
    if not node or node.draftout_border then return end
    node.draftout_border=true
    local draw=node.draw
    owner.border_started=owner.border_started or love.timer.getTime()
    node.draw=function(self,...)
        local result=draw(self,...)
        if G.OVERLAY_MENU~=owner.overlay or not self.states.visible then return result end
        local w,h=self.VT.w,self.VT.h
        if w<=0 or h<=0 then return result end
        if not self.draftout_border_path or self.draftout_border_path.w~=w or self.draftout_border_path.h~=h then
            self.draftout_border_path=path(w,h)
        end
        local p=self.draftout_border_path
        local lg=love.graphics
        lg.push('all')
        prep_draw(self,1)
        lg.setShader();lg.setLineStyle('smooth');lg.setLineWidth(0.018)
        lg.setColor(0.48,0.70,0.72,0.8)
        for i=1,#p.points-1 do
            local a,b=p.points[i],p.points[i+1];lg.line(a[1],a[2],b[1],b[2])
        end
        if not (G.SETTINGS and G.SETTINGS.reduced_motion) and owner.mod.config.pack_effects~=false then
            local head=((love.timer.getTime()-owner.border_started)/7)%1*p.total
            local step=p.total*0.14/32
            for i=1,32 do
                local fade=(i/32)^2
                local x,y=B.point(p,head-(33-i)*step)
                local xx,yy=B.point(p,head-(32-i)*step)
                lg.setLineWidth(0.055);lg.setColor(0.72,0.64,1,0.12*fade);lg.line(x,y,xx,yy)
                lg.setLineWidth(0.022);lg.setColor(0.88,0.84,1,0.85*fade);lg.line(x,y,xx,yy)
            end
        end
        lg.pop();lg.pop()
        return result
    end
end
return B

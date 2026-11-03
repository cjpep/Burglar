-- Pure table layout and motion model. Coordinates are in a 16 x 8 viewport.
-- Stable display IDs let a card travel from hand to play or shop to jokers.
-- These are visual transitions between received states, not simulated actions.
local M={WIDTH=16,HEIGHT=8}
function M.new() return {cards={},order={},epoch=nil} end
function M.layout(frame)
    local out={};if not frame then return out end
    local a=frame.areas
    local function row(cards,group,x,y,width,cw,fan)
        local n=#cards
        local step=n>1 and math.min(cw+0.14,(width-cw)/(n-1)) or 0
        local start=x+(width-cw-step*math.max(0,n-1))/2
        for i,c in ipairs(cards) do
            local u=n>1 and (i-1)/(n-1)*2-1 or 0
            local h=cw*1.38
            out[#out+1]={id=c.uid or (group..':'..i),card=c,group=group,
                x=start+(i-1)*step,y=y+(fan and 0.12*u*u or 0)-(c.selected and 0.20 or 0),
                w=cw,h=h,r=fan and u*0.045 or 0}
        end
    end
    row(a.jokers,'jokers',3.9,1.0,7.6,1.05)
    row(a.consumeables,'consumeables',12.0,1.0,3.6,0.95)
    if frame.phase=='shop' then
        row(a.shop_jokers,'shop_jokers',4.15,3.51,7.15,1.05)
        row(a.shop_vouchers,'shop_vouchers',11.85,3.51,3.35,1.05)
        row(a.shop_booster,'shop_booster',4.25,5.77,10.85,0.94)
    elseif frame.phase:find('pack',1,true) and #a.pack_cards>0 then
        row(a.pack_cards,'pack_cards',4.25,3.6,10.8,1.18)
    else
        row(a.play,'play',4.3,3.15,9.6,1.08)
        row(a.hand,'hand',3.9,5.65,9.9,1.03,true)
    end
    return out
end
function M.apply(scene,frame,epoch,now)
    if scene.epoch~=epoch then scene.cards={};scene.order={};scene.epoch=epoch end
    scene.frame=frame
    if not frame then scene.cards={};scene.order={};return end
    local seen,order={},{}
    for _,target in ipairs(M.layout(frame)) do
        -- Malformed duplicate IDs may not create two instances of one card.
        if not seen[target.id] then
            seen[target.id]=true
            local card=scene.cards[target.id]
            if not card then
                card={x=target.x,y=target.group=='hand' and 7.5 or target.y+0.22,
                    w=target.w,h=target.h,r=target.r,alpha=0}
                scene.cards[target.id]=card
            end
            card.target=target;card.card=target.card;card.removing=nil
            order[#order+1]=card
        end
    end
    for id,card in pairs(scene.cards) do
        if not seen[id] then
            card.removing=true;card.target.y=math.min(7.5,card.target.y+0.08)
            order[#order+1]=card
        end
    end
    scene.order=order;scene.updated=now
end
function M.step(scene,dt,reduced)
    local blend=reduced and 1 or 1-math.exp(-math.min(math.max(dt,0),0.1)*14)
    local keep={}
    for _,c in ipairs(scene.order) do
        for _,k in ipairs({'x','y','w','h','r'}) do c[k]=c[k]+(c.target[k]-c[k])*blend end
        c.alpha=c.alpha+((c.removing and 0 or 1)-c.alpha)*blend
        if c.removing and (reduced or c.alpha<0.015) then scene.cards[c.target.id]=nil
        else keep[#keep+1]=c end
    end
    scene.order=keep
end
return M

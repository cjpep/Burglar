-- Pure table layout and motion model. Coordinates are in a 16 x 8 viewport.
-- Stable display IDs let a card travel from hand to play or shop to jokers.
-- These are visual transitions between received states, not simulated actions.
local M={WIDTH=16,HEIGHT=8}
function M.new() return {cards={},order={},epoch=nil} end
function M.phase_name(phase)
    return ({['shop']='Shopping',['blind select']='Choosing the next blind',
        ['draw to hand']='Drawing cards',['selecting hand']='Choosing cards',
        ['hand played']='Scoring hand',['round eval']='Round results',
        ['game over']='Run ended',['buffoon pack']='Buffoon Pack',
        ['tarot pack']='Arcana Pack',['planet pack']='Celestial Pack',
        ['spectral pack']='Spectral Pack',['standard pack']='Standard Pack'})[phase] or 'In round'
end
-- Connection labels are derived at draw time, so a stalled frame never keeps
-- an apparently-live badge and countdowns do not require new packets.
function M.feed_status(s,now)
    if s.demo then return s.demo_paused and 'DEMO PAUSED' or 'LOCAL DEMO','Scripted gameplay preview' end
    if not s.target then return 'NOT WATCHING',s.status or 'Choose a remaining player.' end
    local r=s.receiver or {}
    if r.received and now-r.received>12 then return 'FEED STALLED','Last board shown; waiting for updates.' end
    if not s.frame then
        local first=r.queue and r.queue[1]
        if first then return 'BUFFERING','Delayed view starts in '..math.max(0,math.ceil(first.due-now))..'s' end
        return 'WAITING',s.status or 'Waiting for their next shop or blind selection.'
    end
    return '5s+ DELAY',s.status or 'Delayed live board'
end
local function signature(cards)
    local out={}
    for _,c in ipairs(cards) do out[#out+1]=(c.uid or '')..':'..(c.center or '')..':'..(c.price or '') end
    return table.concat(out,'|')
end
function M.change_notice(old,new)
    if not old or not new then return end
    if old.phase~=new.phase then return M.phase_name(new.phase) end
    if new.phase=='shop' and signature(old.areas.shop_jokers)~=signature(new.areas.shop_jokers) then
        -- A snapshot cannot distinguish every reroll, purchase and shop effect.
        return 'Shop offers updated'
    end
end
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
        if #a.pack_cards>6 and #a.hand==0 then
            local upper,lower={},{}
            for i,c in ipairs(a.pack_cards) do
                local list=i<=math.ceil(#a.pack_cards/2) and upper or lower
                list[#list+1]=c
            end
            row(upper,'pack_cards',4.25,3.60,10.8,1.0)
            row(lower,'pack_cards',4.25,5.25,10.8,1.0)
        else
            row(a.pack_cards,'pack_cards',4.25,3.75,10.8,1.12)
            -- Tarot/Spectral packs can act on the player's hand.
            row(a.hand,'hand',3.9,5.90,9.9,0.85,true)
        end
    else
        row(a.play,'play',4.3,3.15,9.6,1.08)
        row(a.hand,'hand',3.9,5.65,9.9,1.03,true)
    end
    return out
end
function M.apply(scene,frame,epoch,now)
    if scene.epoch~=epoch then scene.cards={};scene.order={};scene.epoch=epoch;scene.frame=nil;scene.notice=nil end
    local notice=M.change_notice(scene.frame,frame)
    if notice then scene.notice={text=notice,until_time=now+2.5} end
    scene.frame=frame
    if not frame then scene.cards={};scene.order={};scene.notice=nil;return end
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

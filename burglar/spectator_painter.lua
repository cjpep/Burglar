-- Draw a watch-only table directly from atlas images. No gameplay Card objects,
-- scoring callbacks, shader state on native cards, or changes to the live HUD.
return function(D,S,M)
    local P={};local C=S.capture
    local colours={felt={0.15,0.10,0.23,1},dark={0.10,0.13,0.16,1},panel={0.19,0.22,0.25,1},
        white={0.94,0.95,0.91,1},muted={0.64,0.76,0.71,1},gold={0.93,0.76,0.36,1},
        red={0.76,0.25,0.25,1},blue={0.14,0.49,0.72,1}}
    -- Use the game's own background shader on a private decorative Sprite.
    -- Do not ease G.C.BACKGROUND or replace G.SPLASH_BACK: the eliminated host's
    -- real run and referee remain active underneath this overlay.
    local function background()
        if not (Sprite and G.SHADERS and G.SHADERS.background and G.ASSET_ATLAS.ui_1) then return end
        local room=G.ROOM.T
        local sprite=Sprite(-30,-6,room.w+60,room.h+12,G.ASSET_ATLAS.ui_1,{x=2,y=0})
        for _,state in ipairs({'hover','click','drag','collide'}) do sprite.states[state].can=false end
        local params={time=0,spin_time=0,spin_amount=0.25,contrast=2,
            colour_1={0.45,0.28,0.66,1},colour_2={0.25,0.20,0.33,1},colour_3={0.08,0.06,0.10,1}}
        local sends={}
        for _,key in ipairs({'time','spin_time','spin_amount','contrast','colour_1','colour_2','colour_3'}) do
            sends[#sends+1]={name=key,ref_table=params,ref_value=key}
        end
        sprite:define_draw_steps({{shader='background',send=sends}})
        return {sprite=sprite,params=params}
    end
    local function draw_background(bg,frame,dt)
        local p=bg.params
        local name=frame and frame.blind or ''
        if bg.blind~=name then
            bg.blind=name
            local boss=G.P_BLINDS and G.P_BLINDS.bl_eye
            for _,v in pairs(G.P_BLINDS or {}) do
                if v.name==name and v.boss then boss=v;break end
            end
            local colour=boss and boss.boss_colour or {0.45,0.28,0.66,1}
            local base=lighten(mix_colours(colour,G.C.BLACK,0.3),0.1)
            p.colour_1={colour[1],colour[2],colour[3],1}
            p.colour_2={base[1]*1.3,base[2]*1.3,base[3]*1.3,1}
            p.colour_3={base[1]*0.4,base[2]*0.4,base[3]*0.4,1}
        end
        if not (G.SETTINGS and G.SETTINGS.reduced_motion) then
            p.time=p.time+dt;p.spin_time=p.spin_time+dt*p.spin_amount
        end
        bg.sprite:draw()
    end
    function P.new(width,height)
        local o=Moveable(0,0,width,height)
        o.scene=M.new();o.quads={};o.last_draw=D.now();o.background=background()
        o.states.hover.can=false;o.states.click.can=false;o.states.drag.can=false
        o.states.collide.can=false
        function o:draw()
            if G.OVERLAY_MENU~=S.overlay then return end
            local lg=love.graphics
            lg.push('all')
            local time=D.now();local dt=math.max(0,math.min(0.1,time-self.last_draw))
            -- Opaque fallback, then the native boss swirl and a readability veil.
            lg.origin();lg.setShader();lg.setColor(colours.felt)
            local sw,sh=lg.getDimensions();lg.rectangle('fill',0,0,sw,sh)
            lg.pop()
            if self.background then
                lg.push('all');draw_background(self.background,self.scene.frame,dt);lg.pop()
                lg.push('all');lg.origin();lg.setShader();lg.setColor(0,0,0,0.18)
                lg.rectangle('fill',0,0,sw,sh);lg.pop()
            end
            lg.push('all');prep_draw(self,1);lg.scale(self.VT.w/16,self.VT.h/8);lg.setShader()
            local font=(G.LANG and G.LANG.font and G.LANG.font.FONT) or lg.getFont()
            lg.setFont(font)
            local function box(x,y,w,h,colour,r)
                lg.setColor(colour);lg.rectangle('fill',x,y,w,h,r or 0.08,r or 0.08)
            end
            local function text(value,x,y,w,h,colour,align)
                local str=C.text(value,120);local scale=math.min(h/font:getHeight(),w/math.max(1,font:getWidth(str)))
                local dx=align=='left' and 0 or (w-font:getWidth(str)*scale)/2
                lg.setColor(0,0,0,0.3);lg.print(str,x+dx+0.015,y+0.025,0,scale,scale)
                lg.setColor(colour or colours.white);lg.print(str,x+dx,y,0,scale,scale)
            end
            local function art(atlas,pos,x,y,w,h,alpha)
                if not atlas or not atlas.image or not pos or not atlas.px or not atlas.py then return false end
                local cache=self.quads[atlas.image]
                if not cache then cache={};self.quads[atlas.image]=cache end
                local key=tostring(pos.x)..':'..tostring(pos.y)..':'..atlas.px..':'..atlas.py
                local q=cache[key]
                if not q then
                    q=lg.newQuad(pos.x*atlas.px,pos.y*atlas.py,atlas.px,atlas.py,atlas.image:getDimensions());cache[key]=q
                end
                lg.setColor(1,1,1,alpha or 1);lg.draw(atlas.image,q,x,y,0,w/atlas.px,h/atlas.py)
                return true
            end
            local f=self.scene.frame
            local phase=f and f.phase or ''
            local is_pack=phase:find('pack',1,true)~=nil
            local badge,feed_detail=M.feed_status(S,time)
            local watching=S.watching_name or 'Waiting for a board'
            text('SPECTATING  '..watching,3.95,0.10,8.0,0.33,colours.white,'left')
            text(badge,12.0,0.13,3.4,0.24,badge=='FEED STALLED' and colours.red or colours.gold)
            -- Familiar side panel: blind/target, score, chips x mult, resources.
            box(0.2,0.25,3.25,7.2,colours.dark,0.16)
            if phase=='shop' or is_pack then
                box(0.36,0.44,2.93,1.35,{0.30,0.22,0.14,1})
                text(is_pack and 'PACK OPEN' or 'SHOP',0.5,0.66,2.65,0.44,colours.gold)
                text(is_pack and M.phase_name(phase) or 'Between blinds',0.5,1.26,2.65,0.22,colours.white)
                box(0.36,1.96,2.93,1.48,colours.panel)
                text('Available money',0.5,2.12,2.65,0.24,colours.muted)
                text('$'..f.dollars,0.5,2.62,2.65,0.53,colours.gold)
                text('Inventory',0.5,3.84,2.65,0.25,colours.muted)
                text(#f.areas.jokers..' Jokers',0.5,4.30,2.65,0.30)
                text(#f.areas.consumeables..' Consumables',0.5,4.80,2.65,0.27)
                if phase=='shop' and f.reroll_cost and f.reroll_cost~='' then
                    text('Reroll cost: $'..f.reroll_cost,0.5,5.51,2.65,0.25,colours.gold)
                elseif is_pack and f.pack_choices and f.pack_choices~='' then
                    text('Choices left: '..f.pack_choices,0.5,5.51,2.65,0.25,colours.gold)
                end
                text('Ante '..f.ante..'     Lives '..f.lives,0.45,6.38,2.75,0.29)
            else
                box(0.36,0.44,2.93,1.35,colours.panel)
                text(f and (f.blind~='' and f.blind or 'Current blind') or 'Waiting',0.5,0.56,2.65,0.32)
                text('Score to beat',0.5,1.00,2.65,0.22,colours.muted)
                text(f and f.target or '-',0.5,1.25,2.65,0.38,colours.gold)
                box(0.36,1.96,2.93,1.05,{0.13,0.16,0.20,1})
                text('Round score',0.5,2.06,2.65,0.23,colours.muted)
                text(f and f.score or '0',0.5,2.40,2.65,0.44)
                text(f and f.hand_name or '',0.45,3.17,2.8,0.29)
                box(0.40,3.60,1.25,0.70,colours.blue)
                box(2.00,3.60,1.25,0.70,colours.red)
                text(f and f.hand_chips or '-',0.44,3.77,1.17,0.34)
                text('X',1.65,3.82,0.35,0.24)
                text(f and f.hand_mult or '-',2.04,3.77,1.17,0.34)
                text('Hands',0.45,4.57,1.25,0.23,colours.muted)
                text('Discards',1.90,4.57,1.25,0.23,colours.muted)
                text(f and f.hands or '-',0.45,4.91,1.25,0.48,colours.blue)
                text(f and f.discards or '-',1.90,4.91,1.25,0.48,colours.red)
                text('$'..(f and f.dollars or '-'),0.5,5.65,2.65,0.52,colours.gold)
                text('Ante '..(f and f.ante or '-')..'     Lives '..(f and f.lives or '-'),0.45,6.38,2.75,0.29)
            end
            text('WATCH ONLY',0.45,6.94,2.75,0.20,colours.muted)
            -- Native-style card zones, with no enclosing collection panel.
            box(3.85,0.83,7.85,1.77,{0.03,0.15,0.13,0.28})
            box(11.90,0.83,3.7,1.77,{0.03,0.15,0.13,0.28})
            text('Jokers '..(f and #f.areas.jokers or 0),4,0.58,7.5,0.20,colours.muted)
            text('Consumables',12,0.58,3.5,0.20,colours.muted)
            if not f then
                box(4.0,3.15,11.3,2.1,{0.10,0.13,0.16,0.94},0.15)
                text(badge,4.4,3.55,10.5,0.38,colours.gold)
                text(feed_detail,4.4,4.28,10.5,0.27,colours.white)
            elseif phase=='shop' then
                -- Dedicated shop cabinet: offers and vouchers above, packs below.
                -- These are display shelves, never purchase/reroll controls.
                box(3.85,2.82,11.75,4.61,{0.38,0.30,0.20,0.9},0.15)
                box(3.90,2.87,11.65,4.51,{0.12,0.14,0.17,0.96},0.12)
                box(4.02,3.02,7.42,2.32,{0.21,0.23,0.27,0.88})
                box(11.62,3.02,3.79,2.32,{0.28,0.23,0.17,0.88})
                box(4.02,5.45,11.39,1.80,{0.21,0.23,0.27,0.88})
                text('FOR SALE',4.15,3.15,7.15,0.23,colours.white)
                text('VOUCHERS',11.85,3.15,3.35,0.23,colours.gold)
                text('BOOSTER PACKS',4.25,5.51,10.85,0.20,colours.white)
                if #f.areas.shop_jokers==0 then text('No offers',4.15,4.10,7.15,0.25,colours.muted) end
                if #f.areas.shop_vouchers==0 then text('None available',11.85,4.10,3.35,0.23,colours.muted) end
                if #f.areas.shop_booster==0 then text('No packs remaining',4.25,6.26,10.85,0.25,colours.muted) end
            elseif is_pack then
                box(3.9,2.82,11.7,4.55,{0.10,0.13,0.16,0.60},0.15)
                text(M.phase_name(phase),4.3,3.0,10.8,0.35,colours.gold)
                if #f.areas.pack_cards==0 then text('Opening pack...',4.3,4.3,10.8,0.28,colours.muted) end
            elseif phase=='blind select' then
                text('Choosing the next blind',4.3,3.65,9.5,0.42,colours.muted)
            else
                text(M.phase_name(phase),4.3,2.83,9.5,0.24,colours.muted)
                box(3.9,5.48,9.9,1.80,{0.03,0.15,0.13,0.18})
            end
            local back=phase~='shop' and not is_pack and G.P_CENTERS.b_red
            if back then
                for i=3,0,-1 do art(G.ASSET_ATLAS[back.atlas or 'centers'],back.pos,14.22+i*0.035,5.75-i*0.035,1.02,1.42) end
            end
            if phase~='shop' and not is_pack then text(f and (f.deck..' / '..f.total) or '',14.0,7.26,1.7,0.23,colours.muted) end
            M.step(self.scene,dt,G.SETTINGS and G.SETTINGS.reduced_motion)
            self.last_draw=time
            local mx,my=-100,-100
            if love.mouse and lg.inverseTransformPoint then mx,my=lg.inverseTransformPoint(love.mouse.getPosition()) end
            local hover
            for _,c in ipairs(self.scene.order) do
                if not c.removing and mx>=c.x and mx<=c.x+c.w and my>=c.y and my<=c.y+c.h then hover=c end
            end
            local function draw_card(c,lift)
                local data=c.card;local x,y,w,h=c.x,c.y-(lift and 0.18 or 0),c.w,c.h
                local center=G.P_CENTERS[data.hidden and 'b_red' or data.center]
                if center then
                    if center.name=='Half Joker' then h=h/1.7
                    elseif center.name=='Photograph' then h=h/1.2
                    elseif center.name=='Wee Joker' then w=w*0.7;h=h*0.7
                    elseif center.name=='Square Joker' then h=w end
                end
                lg.push();lg.translate(x+w/2,y+h/2);lg.rotate(c.r);lg.translate(-w/2,-h/2)
                box(0.045,0.08,w,h,{0,0,0,0.28*c.alpha},0.04)
                local atlas=center and G.ASSET_ATLAS[center.atlas or
                    ((center.set=='Joker' or center.consumeable or center.set=='Voucher') and center.set) or 'centers']
                if not (center and art(atlas,center.pos,0,0,w,h,c.alpha)) then
                    box(0,0,w,h,{0.83,0.84,0.76,c.alpha},0.04)
                    text(data.name,0.03,h/3,w-0.06,h/3,colours.dark)
                end
                local front=not data.hidden and G.P_CARDS and G.P_CARDS[data.front]
                if front and center and center.name~='Stone Card' and get_front_spriteinfo then
                    local a,p=get_front_spriteinfo(front);art(a,p,0,0,w,h,c.alpha)
                end
                if center and center.soul_pos and not data.hidden then art(atlas,center.soul_pos,0,0,w,h,c.alpha) end
                if data.edition~='' and not data.hidden then
                    lg.setColor(0.75,0.64,0.92,c.alpha*0.85);lg.setLineWidth(0.026);lg.rectangle('line',0,0,w,h,0.04)
                end
                if data.seal~='' and not data.hidden then
                    box(w-0.22,h-0.25,0.17,0.17,{0.88,0.52,0.29,c.alpha},0.07)
                end
                if data.debuff then
                    lg.setColor(0.7,0.12,0.12,c.alpha*0.8);lg.setLineWidth(0.035)
                    lg.line(0.05,0.05,w-0.05,h-0.05);lg.line(w-0.05,0.05,0.05,h-0.05)
                end
                if c.target.group:find('shop',1,true) then
                    box(-0.03,h+0.03,w+0.06,0.29,{0.09,0.10,0.12,c.alpha},0.04)
                    text('$'..data.price,0,h+0.055,w,0.22,colours.gold)
                end
                lg.pop()
            end
            for _,c in ipairs(self.scene.order) do if c~=hover then draw_card(c,false) end end
            if hover then draw_card(hover,true) end
            if hover then
                local c=hover.card
                box(3.9,7.48,11.7,0.48,colours.dark,0.05)
                text(c.name..'   '..c.edition..' '..c.seal..'   '..c.detail,4.05,7.57,11.35,0.22,colours.white,'left')
            else
                local notice=self.scene.notice
                text(notice and time<notice.until_time and notice.text or feed_detail,
                    3.95,7.60,11.5,0.22,colours.muted,'left')
            end
            lg.pop();lg.pop()
        end
        local remove=o.remove
        function o:remove(...)
            if self.background then self.background.sprite:remove();self.background=nil end
            self.scene=M.new();self.quads={};return remove(self,...)
        end
        return o
    end
    return P
end

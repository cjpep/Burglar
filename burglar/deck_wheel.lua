-- Shared lobby roll. The server echoes one host-selected result; clients only
-- animate it. No client-side rerolls and no changes to drafted Joker ownership.
return function(D,M,B)
    local W={seen={},serial=0};D.deck_wheel=W
    local updates=assert(SMODS.load_file('burglar/updates.lua',D.mod.id))()(D)
    local ENTER,SPIN=1.1,7.2
    local FINISH=ENTER+SPIN
    local function lobby() return MPAPI.get_current_lobby() end
    local function clock() return love.timer.getTime() end
    local function sound(name,pitch,volume) if play_sound then play_sound(name,pitch,volume) end end
    function W.available()
        return M.can_select() and M.synced() and not W.active
            and (not B.session or B.phase=='idle' or B.phase=='checking' or B.phase=='complete')
    end
    G.FUNCS.burglar_random_deck=function()
        if not lobby() or not lobby().is_host or not W.available() then return end
        local l=lobby();local choices=M.choices();if #choices<2 then return end
        local keys={};for _,c in ipairs(choices) do keys[#keys+1]=c.key end
        -- Shuffle once on the host; transmit the exact arrangement to everyone.
        for i=#keys,2,-1 do
            local j=love.math.random(i);keys[i],keys[j]=keys[j],keys[i]
        end
        W.serial=W.serial+1
        local selected=love.math.random(#keys)
        local chosen=G.P_CENTERS[keys[selected]]
        local id=tostring(l.player_id)..':'..tostring(os.time())..':'..W.serial
        -- Publish the deck and presentation together; native PvP mirrors deck.
        -- Shared-deck flags prevent a prior random-loadout setting overriding it.
        -- A repeated deck name is not an acknowledgement of this new spin.
        M.pending={lobby=l,name=chosen.name,roll_id=id}
        l:set_metadata({deck=chosen.name,different_decks=false,random_loadout=false,
            burglar_deck_roll={id=id,host=l.player_id,keys=keys,winner=selected,created=os.time()}})
    end
    local function dispose()
        if W.active and W.active.background then W.active.background.sprite:remove() end
        W.active=nil
    end
    local function close()
        dispose()
        if MPAPI.refresh_current_view then MPAPI.refresh_current_view() end
    end
    local function receive()
        local l=lobby();local a=W.active
        if a and (a.lobby~=l or l:is_game_started()) then dispose() end
        if not l or not M.active(l) or l:is_game_started() then return end
        local r=(l:get_metadata() or {}).burglar_deck_roll
        if W.room~=l then
            W.room=l
            if type(r)=='table' and type(r.id)=='string' then W.seen[r.id]=true end
            return
        end
        if type(r)~='table' or type(r.id)~='string' or W.seen[r.id] or r.host~=l.host_id then return end
        W.seen[r.id]=true
        -- The initial room snapshot is ignored above, so reconnects do not
        -- replay old rolls. Animation timing never depends on client wall clocks.
        if type(r.keys)~='table' or #r.keys<2 or #r.keys>15 or type(r.winner)~='number'
            or r.winner~=math.floor(r.winner) or not r.keys[r.winner] then return end
        local allowed={};for _,c in ipairs(M.choices()) do allowed[c.key]=true end
        local seen={}
        for _,key in ipairs(r.keys) do if not allowed[key] or seen[key] then return end;seen[key]=true end
        W.active={lobby=l,keys=r.keys,winner=r.winner,start=clock(),last=-1,art={}}
        sound('card1',0.7,0.5)
    end
    updates.add('deck_wheel',function()
        receive()
        local a=W.active;if not a then return end
        local t=clock()-a.start
        local p=math.min(1,math.max(0,(t-ENTER)/SPIN))
        local distance=#a.keys*5+a.winner-1
        a.done=p>=1
        a.position=a.done and distance or distance*(1-(1-p)^3)
        -- Each deck owns the half-segment on either side of its light socket.
        -- Flooring kept the previous deck highlighted almost to the next socket,
        -- causing a misleading final switch. Round to the nearest deck instead.
        a.step=math.floor(a.position+0.5)
        a.index=a.done and a.winner or (a.step%#a.keys+1)
        if a.step~=a.last then
            a.last=a.step;sound('card1',1.1-0.35*p,0.26)
        end
        if a.done and not a.celebrated then a.celebrated=true;sound('timpani',1,0.65) end
        -- A forgotten reveal never permanently traps the lobby.
        if t>FINISH+10 then close() end
    end)
    -- Preserve releases for presses delivered before the overlay opened.
    -- Suppress both halves of overlay-only inputs, including a dismissal press
    -- whose release arrives after close(), so it cannot click through the lobby.
    local held,blocked={},{}
    local function input_id(name,...)
        if name=='mousepressed' or name=='mousereleased' then
            return 'mouse:'..tostring(select(3,...) or 'unknown')
        elseif name=='keypressed' or name=='keyreleased' then
            return 'key:'..tostring(select(1,...) or 'unknown')
        elseif name=='gamepadpressed' or name=='gamepadreleased' then
            return 'pad:'..tostring(select(1,...) or 'unknown')..':'..tostring(select(2,...) or 'unknown')
        end
    end
    for _,name in ipairs({'mousepressed','mousereleased','keypressed','keyreleased','wheelmoved','gamepadpressed','gamepadreleased','textinput'}) do
        local original=love[name]
        local press=name=='mousepressed' or name=='keypressed' or name=='gamepadpressed'
        local release=name=='mousereleased' or name=='keyreleased' or name=='gamepadreleased'
        love[name]=function(...)
            local a=W.active
            local id=input_id(name,...)
            if release then
                if blocked[id] then blocked[id]=nil;return end
                local delivered=held[id];held[id]=nil
                if a and not delivered then return end
                if original then return original(...) end
                return
            end
            if a then
                if press and not held[id] then blocked[id]=true end
                if a.done and clock()-a.start>FINISH+0.8 and press then close() end
                return
            end
            if press then held[id]=true;blocked[id]=nil end
            if original then return original(...) end
        end
    end
    local old_synced=M.synced
    M.synced=function() return old_synced() and not W.active end
    local old_can=M.can_select
    M.can_select=function() return not W.active and old_can() end
    -- Private native background sprite: The Water's exact boss palette and
    -- contrast, without changing the lobby background, blind, or event queue.
    local function water_background(a)
        if a.background_attempted then return a.background end
        a.background_attempted=true
        if not (Sprite and G.ROOM and G.SHADERS.background and G.ASSET_ATLAS.ui_1) then return end
        local boss=G.P_BLINDS and G.P_BLINDS.bl_water
        local c=boss and boss.boss_colour or {198/255,224/255,235/255,1}
        local base=lighten(mix_colours(c,G.C.BLACK,0.3),0.1)
        local params={time=0,spin_time=0,spin_amount=0.25,contrast=2,
            colour_1={c[1],c[2],c[3],1},
            colour_2={base[1]*1.3,base[2]*1.3,base[3]*1.3,1},
            colour_3={base[1]*0.4,base[2]*0.4,base[3]*0.4,1}}
        local sprite=Sprite(-30,-6,G.ROOM.T.w+60,G.ROOM.T.h+12,G.ASSET_ATLAS.ui_1,{x=2,y=0})
        for _,state in ipairs({'hover','click','drag','collide'}) do sprite.states[state].can=false end
        local sends={}
        for _,key in ipairs({'time','spin_time','spin_amount','contrast','colour_1','colour_2','colour_3'}) do
            sends[#sends+1]={name=key,ref_table=params,ref_value=key}
        end
        sprite:define_draw_steps({{shader='background',send=sends}})
        a.background={sprite=sprite,params=params}
        return a.background
    end
    -- Keep native description rows and semantic colours after resolving vars.
    local function deck_description(key)
        local ok,result=pcall(function()
            local tree=Back(G.P_CENTERS[key]):generate_UI(G.P_CENTERS[key])
            local rows,line={},{}
            local function flush()
                if #line>0 then rows[#rows+1]=line;line={} end
            end
            local function visit(node)
                if type(node)~='table' then return end
                local cfg=node.config or {}
                if node.n==G.UIT.R then flush() end
                if node.n==G.UIT.T and type(cfg.text)=='string' then
                    local c=cfg.colour or G.C.WHITE
                    -- Native descriptions sit on pale panels; neutral dark text
                    -- becomes light here, while coloured keywords keep their hue.
                    if math.max(c[1],c[2],c[3])-math.min(c[1],c[2],c[3])<0.12
                        or math.max(c[1],c[2],c[3])<0.25 then c={0.92,0.95,0.97,1} end
                    line[#line+1]={text=cfg.text,colour={c[1],c[2],c[3],1}}
                end
                for _,child in ipairs(node.nodes or {}) do visit(child) end
                if node.n==G.UIT.R then flush() end
                if node.n==G.UIT.O and cfg.object and cfg.object.remove then cfg.object:remove() end
            end
            visit(tree);flush();return rows
        end)
        return ok and result or {}
    end
    local function draw(a)
        local g=love.graphics;local sw,sh=g.getDimensions()
        local scale=math.min(sw/1440,sh/1000)
        g.push('all');g.origin();g.setShader();g.setScissor();g.setStencilTest()
        g.setColor(0.025,0.07,0.10,1);g.rectangle('fill',0,0,sw,sh)
        local bg=water_background(a)
        if bg then
            local elapsed=G.SETTINGS.reduced_motion and 0 or clock()-a.start
            bg.params.time=elapsed;bg.params.spin_time=elapsed*0.25
            g.push('all');bg.sprite:draw();g.pop()
        end
        g.setShader();g.setColor(0.015,0.035,0.055,0.30);g.rectangle('fill',0,0,sw,sh)
        g.translate(sw/2,sh/2);g.scale(scale)
        local t=clock()-a.start
        local reduced=G.SETTINGS.reduced_motion
        local settled=a.done and math.min(1,(t-FINISH)/0.5) or 0
        local teal={0.38,0.82,0.79};local gold={1,0.77,0.38};local white={0.92,0.95,0.97}
        local function colour(c,alpha) g.setColor(c[1],c[2],c[3],alpha or 1) end
        local font=G.LANG and G.LANG.font and G.LANG.font.FONT or g.getFont()
        g.setFont(font)
        local function text(s,x,y,size,c,width)
            local z=size/font:getHeight();if width then z=math.min(z,width/math.max(1,font:getWidth(s))) end
            colour(c);g.print(s,x-font:getWidth(s)*z/2,y,0,z,z)
        end
        -- Clean cabinet face, double pinstripe, and a subtle radial halo.
        for r=460,350,-8 do g.setColor(0.08,0.35,0.36,0.012);g.circle('fill',0,0,r) end
        g.setColor(0.025,0.055,0.075,0.67);g.rectangle('fill',-660,-475,1320,950,28)
        g.setLineWidth(2);colour(teal,0.32);g.rectangle('line',-650,-465,1300,930,23)
        g.setLineWidth(1);colour(teal,0.12);g.rectangle('line',-643,-458,1286,916,19)
        -- Quiet pixel ornaments occupy the rectangular corners around the oval.
        -- One soft reveal pulse; no continuous blinking or gameplay RNG.
        local pulse=0
        if a.done and not reduced then
            local phase=(t-FINISH)/1.4
            if phase>=0 and phase<=1 then pulse=math.sin(phase*math.pi) end
        end
        local corner_gold={0.86,0.73,0.46}
        for _,sx in ipairs({-1,1}) do
            for _,sy in ipairs({-1,1}) do
                g.push();g.translate(sx*617,sy*426);g.scale(-sx,-sy)
                colour(corner_gold,0.32+0.25*pulse);g.setLineWidth(2)
                g.line(0,86,0,18,18,18,18,0,99,0)
                colour(corner_gold,0.16+0.16*pulse);g.setLineWidth(1)
                g.line(9,72,9,27,27,27,27,9,85,9)
                colour(corner_gold,0.35+0.28*pulse)
                g.rectangle('fill',33,33,5,5)
                g.pop()
            end
        end
        local suits={
            {x=-548,y=-335,rows={'011000110','111101111','111111111','111111111','011111110','001111100','000111000','000010000'}},
            {x=548,y=-335,rows={'000010000','000111000','001111100','011111110','111111111','011111110','001111100','000111000','000010000'}},
            {x=-548,y=335,rows={'000111000','001111100','000111000','011111110','111111111','111111111','011111110','000111000','001111100'}},
            {x=548,y=335,rows={'000010000','000111000','001111100','011111110','111111111','111111111','011010110','000111000','001111100'}},
        }
        colour(corner_gold,0.075+0.035*pulse)
        for _,suit in ipairs(suits) do
            local cell=8
            for row,bits in ipairs(suit.rows) do
                for col=1,#bits do
                    if bits:sub(col,col)=='1' then
                        g.rectangle('fill',suit.x+(col-1-#bits/2)*cell,
                            suit.y+(row-1-#suit.rows/2)*cell,cell,cell)
                    end
                end
            end
        end
        -- Match the draft's Bungee title and muted gold exactly.
        local native_font=font
        local brand=SMODS.Fonts and SMODS.Fonts.draftout_burglar_title
        if not brand then
            for key,value in pairs(SMODS.Fonts or {}) do
                if tostring(key):match('burglar_title$') then brand=value;break end
            end
        end
        font=brand and brand.FONT or native_font;g.setFont(font)
        text('BURGLAR',0,-421,57,{0.86,0.73,0.46},650)
        font=native_font;g.setFont(font)
        local cy=32;local rx,ry=462,287
        -- Light raceway inside the deck ring. Four lamps per deck.
        local n=#a.keys;local lamps=n*4
        -- Layered solid raceway: cast shadow, raised outer lip, inset channel,
        -- inner bevel, and a quiet felt-like center. Bulbs sit in dark sockets.
        g.setColor(0,0,0,0.45);g.ellipse('fill',0,cy+8,rx-42,ry-33)
        g.setColor(0.20,0.30,0.32,1);g.ellipse('fill',0,cy,rx-42,ry-33)
        g.setColor(0.065,0.105,0.12,1);g.ellipse('fill',0,cy+2,rx-46,ry-37)
        g.setColor(0.025,0.045,0.055,1);g.ellipse('fill',0,cy,rx-51,ry-42)
        g.setLineWidth(2);colour(teal,0.26*(1-settled*0.55));g.ellipse('line',0,cy-1,rx-44,ry-35)
        g.setColor(0.16,0.23,0.25,1);g.ellipse('fill',0,cy,rx-78,ry-69)
        g.setColor(0.045,0.105,0.12,0.98);g.ellipse('fill',0,cy+2,rx-81,ry-72)
        g.setLineWidth(1);colour(teal,0.12);g.ellipse('line',0,cy+2,rx-83,ry-74)
        for j=0,lamps-1 do
            local angle=-math.pi/2+j*math.pi*2/lamps
            local head=(a.position*4)%lamps
            local behind=(head-j)%lamps
            local glow=behind<12 and (1-behind/12) or 0
            if a.done then glow= j==(a.winner-1)*4 and 1 or 0 end
            if t<ENTER then glow=0 end
            local x,y=math.cos(angle)*(rx-64),cy+math.sin(angle)*(ry-55)
            g.setColor(0.005,0.012,0.018,1);g.circle('fill',x,y+1,7)
            colour(teal,0.12);g.setLineWidth(1);g.circle('line',x,y,7)
            if glow>0.1 then
                for radius=21,9,-4 do colour(gold,glow*0.10);g.circle('fill',x,y,radius) end
            end
            colour(glow>0 and gold or teal,(0.24*(1-settled*0.7))+glow*0.76);g.circle('fill',x,y,4.5)
            if glow>0.6 then g.setColor(1,0.97,0.82,glow);g.circle('fill',x,y,1.8) end
        end
        local function card(key,x,y,w,hot,brightness,spill,shimmer)
            local c=G.P_CENTERS[key];local atlas=G.ASSET_ATLAS[c.atlas or 'centers']
            local h=w*95/71
            brightness=brightness or 1;spill=spill or 0
            if spill>0.01 then
                for pad=22,6,-4 do colour(gold,spill*0.035);g.rectangle('fill',x-w/2-pad,y-h/2-pad,w+pad*2,h+pad*2,12) end
            end
            g.setColor(0,0,0,0.45);g.rectangle('fill',x-w/2+4,y-h/2+7,w,h,7)
            if hot then
                for pad=12,3,-3 do colour(gold,0.055);g.rectangle('fill',x-w/2-pad,y-h/2-pad,w+pad*2,h+pad*2,9) end
                colour(gold);g.setLineWidth(2);g.rectangle('line',x-w/2-3,y-h/2-3,w+6,h+6,7)
            end
            if atlas and atlas.image and c.pos then
                local art=a.art[key]
                if not art then
                    local iw,ih=atlas.image:getDimensions()
                    local px,py=atlas.px,atlas.py
                    art={quad=g.newQuad(c.pos.x*px,c.pos.y*py,px,py,iw,ih),atlas=atlas};a.art[key]=art
                end
                g.setColor(brightness,brightness,brightness,1)
                g.draw(art.atlas.image,art.quad,x-w/2,y-h/2,0,w/art.atlas.px,h/art.atlas.py)
                if spill>0.01 then
                    colour(gold,spill*0.13);g.rectangle('fill',x-w/2+2,y-h/2+2,w-4,h-4,4)
                end
                if shimmer and shimmer>0 and shimmer<1 and not reduced then
                    -- Screen-space scissor contains the one-shot diagonal gleam.
                    g.setScissor(sw/2+(x-w/2+3)*scale,sh/2+(y-h/2+3)*scale,(w-6)*scale,(h-6)*scale)
                    local sx=x-w*2+shimmer*w*4
                    for j=3,1,-1 do
                        g.setColor(0.8,0.94,1,0.055)
                        local band=j*w*0.12
                        g.polygon('fill',sx-band,y-h/2,sx+band,y-h/2,sx+band-w*0.7,y+h/2,sx-band-w*0.7,y+h/2)
                    end
                    g.setScissor()
                end
            end
        end
        for i,key in ipairs(a.keys) do
            local angle=-math.pi/2+(i-1)*math.pi*2/n
            local hot=i==a.index and t>=ENTER
            local progress=reduced and 1 or math.min(1,math.max(0,(t-(i-1)*0.018)/0.70))
            local fan=1-(1-progress)^3
            local x,y=math.cos(angle)*rx*fan,cy+math.sin(angle)*ry*fan
            local distance=math.abs((a.position-(i-1)+n/2)%n-n/2)
            local spill=t>=ENTER and not a.done and math.max(0,1-distance/1.8) or 0
            local brightness=hot and 1 or (0.88-settled*0.56)
            g.push();g.translate(x,y)
            g.rotate((1-fan)*(i-(n+1)/2)*0.055)
            card(key,0,0,(hot and 85 or 76)*(0.75+fan*0.25),hot,brightness,spill)
            g.pop()
        end
        local key=a.keys[a.index];local name=localize({type='name_text',set='Back',key=key})
        -- Soft oval shadow grounds the preview while leaving the swirl visible.
        for i=8,1,-1 do
            g.setColor(0.005,0.015,0.025,0.045)
            g.ellipse('fill',0,cy+35,95+i*12,32+i*7)
        end
        if a.done then
            local palette={b_red={0.96,0.30,0.28},b_blue={0.22,0.56,1},b_yellow={1,0.74,0.22},
                b_green={0.25,0.78,0.53},b_black={0.52,0.60,0.74},b_magic={0.63,0.39,0.93},
                b_nebula={0.36,0.65,0.86},b_ghost={0.64,0.89,0.84},b_abandoned={0.84,0.58,0.39},
                b_checkered={0.91,0.36,0.39},b_zodiac={0.65,0.48,0.87},b_painted={0.46,0.76,0.85},
                b_anaglyph={0.94,0.35,0.42},b_plasma={0.82,0.54,0.79},b_erratic={0.95,0.68,0.34}}
            local tint=palette[key] or gold
            for r=200,40,-10 do colour(tint,0.012*settled);g.ellipse('fill',0,cy-62,r,r*0.72) end
            text('YOUR DECK',0,cy-180,18,gold)
        end
        if a.done then
            local reveal=math.min(1,math.max(0,(t-FINISH)/0.45))
            local ease=1-(1-reveal)^3
            card(key,0,cy-64+(1-ease)*12,126+12*ease,true,1,0,(t-FINISH-0.55)/0.9)
            -- Restrained, deterministic gold sparks: no gameplay RNG consumed.
            local elapsed=t-FINISH
            if elapsed<2 and not reduced then
                for i=1,28 do
                    local angle=i*2.39996;local radius=75+elapsed*(65+i%7*11)
                    colour(i%2==0 and gold or teal,math.max(0,1-elapsed/2))
                    g.circle('fill',math.cos(angle)*radius,cy-64+math.sin(angle)*radius,2+i%3)
                end
            end
        elseif t>=ENTER then
            card(key,0,cy-49,126,false)
        end
        if t>=ENTER then text(name,0,cy+55,32,a.done and gold or white,520) end
        if a.done then
            if a.description==nil then a.description=deck_description(key) end
            local size=math.min(23,115/math.max(1,#a.description)-3)
            local z=size/font:getHeight()
            for _,row in ipairs(a.description) do
                local width=0
                for _,chunk in ipairs(row) do width=width+font:getWidth(chunk.text) end
                if width>0 then z=math.min(z,530/width) end
            end
            local line_height=font:getHeight()*z+3
            for i,row in ipairs(a.description) do
                local width=0
                for _,chunk in ipairs(row) do width=width+font:getWidth(chunk.text)*z end
                local x=-width/2
                for _,chunk in ipairs(row) do
                    colour(chunk.colour)
                    g.print(chunk.text,x,cy+94+(i-1)*line_height,0,z,z)
                    x=x+font:getWidth(chunk.text)*z
                end
            end
        end
        text(a.done and 'Click or press a key to continue' or 'The host is drawing a deck for the table',0,410,20,a.done and white or teal,1050)
        g.pop()
    end
    local original=Game.draw
    function Game:draw(...)
        original(self,...)
        if W.active then draw(W.active) end
    end
    return W
end

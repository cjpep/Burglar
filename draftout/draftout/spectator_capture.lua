-- Capture only visible board information. Never save/load a run, enumerate the
-- draw pile, execute card callbacks, or serialize objects/functions/metatables.
return function(W)
    local C={ids=setmetatable({},{__mode='k'}),serial=0}
    function C.text(value,limit)
        local text=tostring(value or ''):gsub('[%z\1-\31\127]',' ')
        local last=math.min(#text,limit or 100)
        while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<=191 do last=last-1 end
        return text:sub(1,last)
    end
    local function number(value)
        if value==nil then return '-' end
        if number_format then
            local ok,result=pcall(number_format,value)
            if ok then return C.text(result) end
        end
        return C.text(value)
    end
    local function detail(ability)
        local values={}
        for _,key in ipairs({'mult','t_mult','t_chips','bonus','perma_bonus','x_mult','extra'}) do
            local v=ability[key]
            if type(v)=='number' and v~=0 and not (key=='x_mult' and v==1) then
                values[#values+1]=key..': '..number(v)
            elseif key=='extra' and type(v)=='table' then
                local keys={}
                for k,n in pairs(v) do
                    if type(k)=='string' and type(n)=='number' then keys[#keys+1]=k end
                end
                table.sort(keys)
                for i=1,math.min(5,#keys) do values[#values+1]=keys[i]..': '..number(v[keys[i]]) end
            end
        end
        return C.text(table.concat(values,' / '),240)
    end
    local function card_data(card)
        if not C.ids[card] then C.serial=C.serial+1;C.ids[card]='c'..C.serial end
        local hidden=card.facing=='back'
        local cfg,ability=card.config or {},card.ability or {}
        local center=cfg.center or {}
        local key=cfg.center_key or center.key or ''
        local name=ability.name or center.name or key
        if not hidden and localize and center.set and key~='' then
            local ok,value=pcall(localize,{type='name_text',set=center.set,key=key})
            if ok and type(value)=='string' then name=value end
        end
        if not hidden and card.base and card.base.value and card.base.suit then
            name=tostring(card.base.value)..' of '..tostring(card.base.suit)
        end
        local editions={}
        if not hidden then
            for k,v in pairs(card.edition or {}) do
                if v==true and type(k)=='string' then editions[#editions+1]=k end
            end
            for _,k in ipairs({'eternal','perishable','rental'}) do
                if ability[k] then editions[#editions+1]=k end
            end
        end
        table.sort(editions)
        return {name=hidden and 'Face down' or C.text(name),center=hidden and '' or C.text(key),
            front=hidden and '' or C.text(cfg.card_key),hidden=hidden,
            edition=C.text(table.concat(editions,', '),80),seal=hidden and '' or C.text(card.seal,80),
            debuff=not hidden and not not card.debuff,detail=hidden and '' or detail(ability),
            price=hidden and '' or C.text(card.cost,40),uid=C.ids[card],selected=card.highlighted==true}
    end
    function C.checkpoint()
        return G.STATE==G.STATES.SHOP or G.STATE==G.STATES.BLIND_SELECT
    end
    function C.capture()
        local game=G.GAME or {};local round=game.current_round or {};local blind=game.blind or {}
        local hand=round.current_hand or {}
        local phase='In round'
        for _,k in ipairs({'SHOP','BLIND_SELECT','SELECTING_HAND','HAND_PLAYED','DRAW_TO_HAND',
            'ROUND_EVAL','TAROT_PACK','PLANET_PACK','SPECTRAL_PACK','STANDARD_PACK','BUFFOON_PACK','GAME_OVER'}) do
            if G.STATES[k] and G.STATE==G.STATES[k] then phase=k:gsub('_',' '):lower();break end
        end
        local f={version=W.VERSION,ante=(game.round_resets or {}).ante or 0,
            deck=G.deck and G.deck.cards and #G.deck.cards or 0,total=G.playing_cards and #G.playing_cards or 0,
            phase=phase,score=number(game.chips),target=number(blind.chips),blind=C.text(blind.name),
            dollars=number(game.dollars),hands=number(round.hands_left),discards=number(round.discards_left),
            lives=number(PVP and PVP.GAME and PVP.GAME.lives),areas={}}
        f.hand_chips=number(hand.chips);f.hand_mult=number(hand.mult);f.hand_name=C.text(hand.handname)
        for _,group in ipairs(W.GROUPS) do
            local cards=G[group] and G[group].cards or {}
            local a={};f.areas[group]=a
            for i=1,math.min(#cards,24) do a[i]=card_data(cards[i]) end
        end
        return W.frame(f)
    end
    return C
end

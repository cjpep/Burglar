-- Count physical cards and un-emplaced creations, not the native boolean
-- used_jokers flag. Copying effects remain native; these limits govern new offers.
return function(D)
    local C={pending=setmetatable({}, {__mode='k'})}
    local function key(card) return card.config and card.config.center and card.config.center.key end
    function C.counts(pool)
        local limits,used,seen={},{},{}
        for _,id in ipairs(pool.keys) do local k=D.core.key(id);limits[k]=(limits[k] or 0)+1 end
        local function take(card)
            if not seen[card] and not card.removed and not card.REMOVED then
                seen[card]=true;local k=key(card)
                if k then used[k]=(used[k] or 0)+1 end
            end
        end
        for _,name in ipairs({'jokers','shop_jokers','pack_cards'}) do
            for _,card in ipairs(G[name] and G[name].cards or {}) do take(card) end
        end
        for card,reservation in pairs(C.pending) do
            if reservation.game==G.GAME and (reservation.area==G.jokers or reservation.area==G.shop_jokers or reservation.area==G.pack_cards)
                and (not card.area or card.area==reservation.area) then take(card) end
        end
        return limits,used
    end
    function C.track(card,area)
        if card and area and (area==G.jokers or area==G.shop_jokers or area==G.pack_cards) then
            C.pending[card]={area=area,game=G.GAME}
        end
        return card
    end
    function C.install()
        local calc=Card.calculate_joker
        Card.calculate_joker=function(self,context)
            local pool=G.GAME and G.GAME.draftout_pool
            if not (pool and pool.copy_limits and context and context.setting_blind
                and self.ability and self.ability.name=='Riff-raff') then return calc(self,context) end
            if (context.blueprint_card or self).getting_sliced then return end
            local count=math.min(2,G.jokers.config.card_limit-#G.jokers.cards-(G.GAME.joker_buffer or 0))
            if count<=0 then return end
            G.GAME.joker_buffer=(G.GAME.joker_buffer or 0)+count
            G.E_MANAGER:add_event(Event({func=function()
                for _=1,count do
                    local source={keys=D.common_keys(pool),copy_limits=true}
                    local k=D.shop_key(source,nil,0)
                    local card=create_card('Joker',G.jokers,nil,0,nil,false,k,'rif')
                    card:add_to_deck();G.jokers:emplace(card);card:start_materialize()
                end
                G.GAME.joker_buffer=math.max(0,(G.GAME.joker_buffer or 0)-count)
                return true
            end}))
            card_eval_status_text(context.blueprint_card or self,'extra',nil,nil,nil,
                {message=localize('k_plus_joker'),colour=G.C.BLUE})
        end
        if Card.use_consumeable then
            local use=Card.use_consumeable
            Card.use_consumeable=function(self,area,copier)
                local pool=G.GAME and G.GAME.draftout_pool
                if not (pool and pool.copy_limits and self.ability.name=='Judgement') then return use(self,area,copier) end
                stop_use();if not copier then set_consumeable_usage(self) end
                if self.debuff then return end
                local used=copier or self
                G.E_MANAGER:add_event(Event({trigger='after',delay=0.4,func=function()
                    local k=D.shop_key(pool)
                    if k then
                        play_sound('timpani')
                        local card=create_card('Joker',G.jokers,nil,nil,nil,false,k,'jud')
                        card:add_to_deck();G.jokers:emplace(card)
                    end
                    used:juice_up(0.3,0.5)
                    return true
                end}))
                delay(0.6)
            end
        end
    end
    return C
end

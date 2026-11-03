-- Instance-only drawing for raised draft previews. Gameplay cards stay native.
local S={}
function S.attach(card)
    if card.draftout_shadow_attached or type(card.draw)~='function' then return end
    card.draftout_shadow_attached=true
    local draw=card.draw
    card.draw=function(self,layer)
        layer=layer or 'both'
        if not self.draftout_selected or not self.states.visible then return draw(self,layer) end
        local no_shadow=self.no_shadow
        local settings=G.SETTINGS and G.SETTINGS.GRAPHICS
        if (layer=='card' or layer=='both') and not no_shadow and not self.greyed
            and settings and settings.shadows=='On'
            and not (self.ability and self.ability.effect=='Glass Card')
            and (not self.should_draw_shadow or self:should_draw_shadow()) then
            local sprite=self.sprite_facing=='front' and self.children.center or self.children.back
            if sprite then
                sprite.VT.scale=self.VT.scale
                self.shadow_height=0.28
                sprite:draw_shader('dissolve',self.shadow_height)
            end
        end
        -- Draw once immediately behind the raised card, including when native
        -- focus rendering requests only the card layer. Suppress its flat shadow.
        self.no_shadow=true
        local result=draw(self,layer)
        self.no_shadow=no_shadow
        return result
    end
end
return S

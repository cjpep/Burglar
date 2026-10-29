-- Retain the outer panel/cursor layer; replace only its content using the same
-- embedded-UIBox mechanism as Balatro's native tab switcher.
return function(owner,screen)
    -- One automatically sized surface contains every card, label and control.
    -- The roster tray shares this background instead of drawing a separate box.
    screen.config=screen.config or {}
    local split=screen.config.draftout_split
    if split then
        screen.config.colour=G.C and G.C.CLEAR or {0,0,0,0}
        screen.config.padding=0.02
    else
        screen.config.colour={0.27,0.40,0.41,1}
        screen.config.padding=0.12
        screen.config.r=0.12
        screen.config.id='draftout_border_surface'
    end
    -- Dim the background scene while Burglar's two-panel draft is open.
    -- Paint directly behind THIS overlay instance, never inside the UI layout:
    -- a background UI node would force an oversized panel back onto the screen.
    local function attach_focus_scrim(box)
        if not (split and box and type(box.draw)=='function'
            and love and love.graphics) then return end
        local native_draw=box.draw
        box.draw=function(self,...)
            if G.OVERLAY_MENU==self then
                local lg=love.graphics
                lg.push('all')
                lg.origin()
                lg.setShader()
                lg.setScissor()
                if lg.setStencilTest then lg.setStencilTest() end
                lg.setColor(0.025,0.040,0.055,0.52)
                local w,h=lg.getDimensions()
                lg.rectangle('fill',0,0,w,h)
                lg.pop()
            end
            return native_draw(self,...)
        end
    end
    local function decorate(content)
        if not owner.mod then return end -- Minimal offline overlay harness.
        owner.border=owner.border or assert(SMODS.load_file('burglar/border.lua',owner.mod.id))()
        owner.border.attach(content,owner)
    end
    local function options(contents)
        if split then return {no_back=true,padding=0.02,colour=G.C.CLEAR,
            outline_colour=G.C.CLEAR,contents=contents} end
        return {no_back=true,padding=0.03,colour={0.32,0.45,0.47,1},outline_colour={0.27,0.40,0.41,1},contents=contents}
    end
    local function frame(contents)
        if split then
            -- Generic options draw a shared surrounding surface sized to the
            -- active pack. That visually joins the independent roster and
            -- pack borders, and expands when a pack finishes opening.
            -- Use a truly transparent root, leaving ONLY the two individual
            -- panel surfaces visible. Preserve the same overlay lifecycle.
            return {n=G.UIT.ROOT,config={align='cm',padding=0,
                colour=G.C and G.C.CLEAR or {0,0,0,0}},nodes=contents}
        end
        local result=create_UIBox_generic_options(options(contents))
        -- Our own native options frame: reduce its two nested frame paddings.
        local edge=result.nodes and result.nodes[1]
        local panel=edge and edge.nodes and edge.nodes[1]
        if edge and panel then
            edge.config.padding,edge.config.emboss=0.025,0.025
            panel.config.padding=0.06
        end
        return result
    end
    if not UIBox then -- Offline adapters without the rendering engine.
        G.FUNCS.overlay_menu({config={offset={x=0,y=0}},definition=
            frame({screen})})
        owner.overlay=G.OVERLAY_MENU
        owner.overlay_split=not not split
        return
    end
    local definition={n=G.UIT.ROOT,config={align='cm',padding=0,colour=G.C and G.C.CLEAR},nodes={screen}}
    local old=owner.overlay
    -- The embedded UIBox only replaces the INSIDE of an existing overlay.
    -- The overlay's original generic-options frame survives that replacement.
    -- When a draft starts (or ends), its frame style must change too: rebuild
    -- the OUTER overlay exactly once on the split/non-split transition.
    local same_overlay=old and G.OVERLAY_MENU==old
    local same_frame=same_overlay and owner.overlay_split == (not not split)
    local slot=same_frame and old:get_UIE_by_ID('draftout_live_content')
    if slot then
        local content=UIBox{definition=definition,config={offset={x=0,y=0},parent=slot,type='cm'}}
        decorate(content)
        slot.config.object:remove()
        slot.config.object=content
        slot.UIBox:recalculate()
        return
    end
    local content=UIBox{definition=definition,config={offset={x=0,y=0}}}
    decorate(content)
    G.FUNCS.overlay_menu({config={offset={x=0,y=0}},definition=frame({
        {n=G.UIT.O,config={id='draftout_live_content',object=content}},
    })})
    owner.overlay=G.OVERLAY_MENU
    owner.overlay_split=not not split
    attach_focus_scrim(owner.overlay)
end

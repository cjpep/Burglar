-- Optional artwork for Burglar's private PvP Royale waiting room.
-- Keep this separate from the F8 draft overlay and from PvP's other menus.
return function(D)
    if not (MPAPI and MPAPI.on_loaded and D.updates) then return end

    local MARKER = 'draftout_burglar_lobby_marker'
    -- Independent UIBox anchored to the viewport. Does not participate in the
    -- lobby's normal row/column layout, so player cards/buttons stay put.
    local LOGO_WIDTH = 8.5
    local LOGO_X = 0
    local LOGO_Y = 1.15
    local logo_box
    local lobby_screen_built = false

    local function target_lobby()
        if not MPAPI.get_current_lobby then return false end
        local l = MPAPI.get_current_lobby()
        if not l or l._destroyed or l.mod_id ~= 'MultiplayerPvP'
            or l._local_mode or not l._nakama or l.type ~= 'private' then return false end
        local meta = l.get_metadata and l:get_metadata() or {}
        return meta.queue_mode == 'pvp_royale'
            and not (l.is_game_started and l:is_game_started())
    end

    local function clear_logo()
        if logo_box then
            logo_box:remove()
            logo_box = nil
        end
    end

    local function on_lobby_page()
        -- The marker is inserted into the *actual* PvP lobby page definition.
        -- Testing it avoids drawing onto other MPAPI pages in the same lobby.
        local menu = G and G.MAIN_MENU_UI
        if not (menu and menu.get_UIE_by_ID) then return false end
        return menu:get_UIE_by_ID(MARKER) ~= nil
    end

    local function should_show(target)
        return lobby_screen_built and target
            and G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU
            and not G.OVERLAY_MENU and on_lobby_page()
    end

    local function make_logo()
        if not (G and G.UIT and G.ROOM_ATTACH and UIBox and SMODS.create_sprite) then return end
        local sprite = SMODS.create_sprite(0, 0, LOGO_WIDTH,
            LOGO_WIDTH * (384 / 1024), 'draftout_burglar_lobby', {x = 0, y = 0})
        sprite.states.drag.can = false
        sprite.states.hover.can = false
        sprite.states.collide.can = false
        logo_box = UIBox({
            definition = {
                n = G.UIT.ROOT,
                config = {align = 'cm', padding = 0, colour = G.C.CLEAR},
                nodes = {{n = G.UIT.O, config = {object = sprite}}}
            },
            config = {
                align = 'tmi',
                offset = {x = LOGO_X, y = LOGO_Y},
                major = G.ROOM_ATTACH,
                bond = 'Weak'
            }
        })
    end

    -- PvP 1.0.0 registers this builder with MPAPI.Page('pvp_lobby').
    -- Wrapping it is much safer than modifying PvP's files or a generic root.
    MPAPI.on_loaded(function()
        if not (PVP and type(PVP.build_in_lobby_ui) == 'function') then return end
        local original = PVP.build_in_lobby_ui
        PVP.build_in_lobby_ui = function(...)
            local definition = original(...)
            if type(definition) == 'table' then
                -- Zero-size id marker: detects precisely this lobby page without
                -- inserting visible content or changing its layout dimensions.
                definition.nodes = definition.nodes or {}
                definition.nodes[#definition.nodes + 1] = {
                    n = G.UIT.B,
                    config = {id = MARKER, w = 0, h = 0}
                }
                lobby_screen_built = true
            end
            return definition
        end
    end)

    D.updates.add('lobby_logo', function()
        -- No lobby metadata/UI-tree polling is needed during a run. Preserve
        -- the page marker until the next actual menu build or lobby exit.
        if not (G and G.STAGES and G.STAGE==G.STAGES.MAIN_MENU) then clear_logo();return end
        local target=target_lobby()
        if should_show(target) then
            if not logo_box then make_logo() end
        else
            clear_logo()
        end
        if not target then lobby_screen_built = false end
    end)
end

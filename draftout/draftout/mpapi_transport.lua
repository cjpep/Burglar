-- Compatibility adapter for the uploaded MPAPI/PvP 1.0.0 builds.
-- MPAPI has no public add-on action registration for an existing mod's lobby.
-- Bind only our own ActionType into each PvP lobby, retaining its Draftout owner.
return function(D, callbacks)
    local T = {ready = false}
    local function notify(text) if callbacks.error then callbacks.error(text) end end
    function T.current() return MPAPI.get_current_lobby() end
    function T.attach(lobby)
        if not T.action or not lobby or lobby.mod_id ~= 'MultiplayerPvP'
            or not lobby._nakama or lobby._local_mode or lobby._draftout_bound then return end
        assert(type(lobby.on)=='function' and type(lobby.action)=='function', 'MPAPI 1.0.0 lobby contract changed')
        assert(type(lobby._action_types) == 'table', 'MPAPI 1.0.0 lobby action table is missing')
        assert(not lobby._action_types[T.action.key], 'Draftout action key collision')
        lobby._action_types[T.action.key] = T.action
        lobby._draftout_bound = true
        for _, event in ipairs({'player_reconnected', 'snapshot_applied', 'host_changed',
            'player_left', 'player_joined', 'player_disconnected', 'metadata_changed', 'lobby_closed', 'disconnected', 'game_ended'}) do
            local kind = event
            lobby:on(kind, function(...)
                if callbacks.event then callbacks.event(lobby, kind, ...) end
            end)
        end
    end
    function T.send(packet, recipient)
        local lobby = T.current()
        T.attach(lobby)
        assert(T.ready and lobby and lobby._draftout_bound, 'Join a connected PvP lobby first')
        if D.diag then D.diag('packet_send',{kind=packet.kind}) end
        if recipient == lobby.player_id then
            callbacks.packet(lobby.player_id, packet)
            return true
        end
        local sent_session=packet.session
        return lobby:action(T.action):callback(function(_, _, err)
            -- A delayed rejection belongs to the original lobby/draft. It must
            -- not unlock a new selection or replace a new lobby's status.
            if lobby~=T.current() or lobby._destroyed
                or (D.mpbridge and sent_session~=D.mpbridge.session) then return end
            if err then
                if D.diag then D.diag('send_error',{kind=packet.kind}) end
                notify('Draft message failed: ' .. tostring(err.message or err.kind or err))
            end
        end):send(recipient, {packet = packet})
    end
    MPAPI.on_loaded(function()
        if T.ready then return end
        T.action = MPAPI.ActionType({
            key = 'draftout_pack_v4', prefix_config = {key = false},
            parameters = {{key = 'packet', type = 'table', required = true}},
            on_receive = function(_, from, params)
                callbacks.packet(from, params.packet)
                return {ack = true}
            end,
        })
        assert(T.action and T.action.mod and T.action.mod.id == D.mod.id,
            'Draftout action registered with the wrong owner')
        local L = assert(MPAPI._internal and MPAPI._internal.lobby, 'MPAPI 1.0.0 lobby API missing')
        assert(type(L.create_object)=='function', 'MPAPI 1.0.0 lobby factory missing or changed')
        local original=L.create_object
        L.create_object = function(opts)
            local lobby = original(opts)
            T.attach(lobby)
            return lobby
        end
        T.ready = true
        T.attach(T.current())
    end)
    return T
end

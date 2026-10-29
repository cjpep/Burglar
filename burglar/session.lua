-- Owns ephemeral draft-session teardown and display-only polling. Commands must
-- still use a fresh context check; cached results never authorize picks/starts.
return function(state,dependencies)
    local session={retired={},order={}}
    local phases={idle=true,checking=true,draft=true,complete=true,playing=true,error=true}
    local transient={'ids','owner','room','session','lobby','profile','host_state','view','pool',
        'hello','completed','released','release_ack','clock','intents','expiring','pending_launch',
        'refresh_due','last_offer','deadline','last_marker','last_finish_retry','catalog_keys',
        'catalog_set','catalog_signature','catalog_count','handled_run','notice'}
    function session.transition(phase,text)
        assert(phases[phase],'Unknown Burglar session phase: '..tostring(phase))
        state.phase=phase
        if text then dependencies.message(text) end
    end
    function session.invalidate() session.next_check=nil end
    function session.reset(text)
        local old=state.session
        if old and not session.retired[old] then
            session.retired[old]=true
            session.order[#session.order+1]=old
            if #session.order>8 then session.retired[table.remove(session.order,1)]=nil end
        end
        dependencies.stop()
        dependencies.clear_ui()
        for _,key in ipairs(transient) do state[key]=nil end
        state.started=false
        state.failed_sessions={}
        session.cached=false
        session.invalidate()
        session.transition('idle',text)
    end
    function session.poll(now)
        if not state.session then return false end
        if dependencies.lobby()~=state.lobby then
            session.reset('Left the draft lobby. Join a private Royale lobby to draft again.')
            return false
        end
        if state.phase=='idle' or state.phase=='error' or state.started then return false end
        if not session.next_check or now>=session.next_check then
            session.next_check=now+0.25
            session.cached=dependencies.matches() and true or false
            if not session.cached then
                session.transition('error','Lobby changed; host must check / reset the draft')
            end
        end
        return session.cached
    end
    return session
end

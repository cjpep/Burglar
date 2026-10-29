-- Opt-in local diagnostics. Fixed event/field vocabulary; never serialize packets,
-- names, account IDs, lobby codes, seeds, card pools or arbitrary error messages.
return function(D)
    local L={limit=256,max_bytes=128*1024,lines={},head=1,count=0,pending={},pending_bytes=0,
        session_no=0,run_no=0,status='Off'}
    D.diagnostics=L
    local events={enabled=true,disabled=true,context=true,state=true,lobby=true,
        packet_send=true,packet_receive=true,send_error=true,packet_error=true,
        report_accept=true,report_reject=true,outcome_accept=true,outcome_reject=true,blind_start=true}
    local kinds={offer=true,hello=true,fault=true,view=true,pick=true,intent=true,refresh=true,
        complete_ack=true,release=true,release_ack=true,notice=true,combat_average=true,combat_duel=true,
        player_reconnected=true,snapshot_applied=true,host_changed=true,player_left=true,
        player_joined=true,player_disconnected=true,lobby_closed=true,disconnected=true,game_ended=true,
        pvp_ready_blind=true,pvp_unready_blind=true,pvp_play_hand=true,pvp_set_ante=true,
        pvp_new_round=true,pvp_fail_round=true,pvp_fail_timer=true,pvp_fail_pvp_timer=true,pvp_forfeit=true,
        pvp_start_blind=true,pvp_end_pvp=true,pvp_win=true,pvp_eliminated=true,pvp_player_lives=true,pvp_timer_hand_lost=true}
    local phases={idle=true,checking=true,draft=true,complete=true,playing=true,error=true}
    local reasons={invalid=true,duplicate=true,stale=true,blocked=true,closed=true,dispatch_error=true}
    local numeric={'seat','peer','ante','round','seq','event','authority','lives','hands','ready','players'}
    local dir='draftout-diagnostics'
    local path=dir..'/current.log'
    local function enabled() return D.mod.config.diagnostics==true end
    local function now() return D.now and D.now() or os.clock() end
    local function version(v)
        return type(v)=='string' and #v<=40 and v:match('^[%w%.%+~_-]+$') and v or 'unknown'
    end
    local function header()
        local mods=SMODS and SMODS.Mods or {}
        return 'Burglar diagnostics v1 | mod='..version(D.mod.version)
            ..' | smods='..version(SMODS and SMODS.version)
            ..' | api='..version((mods.MultiplayerAPI or {}).version)
            ..' | pvp='..version((mods.MultiplayerPvP or {}).version)..'\n'
    end
    local function context()
        local k=D.roster_duel
        if k and k.enabled and k.lobby then
            local m=(k.lobby:get_metadata() or {}).draftout_bracket or {}
            local ids={};for _,entry in ipairs(m.players or {}) do ids[#ids+1]=entry.id end
            return {lobby=k.lobby,ids=ids,session=m.token,phase=k.started and 'playing' or 'checking'},
                k.started and k.started.run
        end
        local m=D.average_pvp or {}
        return D.mpbridge or {},m.session and m.run
    end
    function L.seat(id)
        local b=context()
        for i,value in ipairs(b.ids or {}) do if id==value then return i end end
        return 0
    end
    local function record(event,data)
        if not events[event] then return end
        local b,run=context()
        if b.session~=L.session then L.session=b.session;if b.session then L.session_no=L.session_no+1 end end
        if run~=L.run then L.run=run;if run then L.run_no=L.run_no+1 end end
        local parts={string.format('t=%.3f',now()),event,'session='..L.session_no,'run='..L.run_no}
        if phases[b.phase] then parts[#parts+1]='phase='..b.phase end
        if b.lobby then
            parts[#parts+1]='self='..L.seat(b.lobby.player_id)
            parts[#parts+1]='host='..L.seat(b.lobby.host_id)
        end
        data=type(data)=='table' and data or {}
        if kinds[data.kind] then parts[#parts+1]='kind='..data.kind end
        if reasons[data.reason] then parts[#parts+1]='reason='..data.reason end
        for _,key in ipairs(numeric) do
            local n=data[key]
            if type(n)=='number' and n==math.floor(n) and math.abs(n)<=9007199254740991 then
                parts[#parts+1]=key..'='..string.format('%.0f',n)
            end
        end
        local line=table.concat(parts,' ')..'\n'
        local index=(L.head+L.count-1)%L.limit+1
        L.lines[index]=line
        if L.count<L.limit then L.count=L.count+1 else L.head=L.head%L.limit+1 end
        -- Bound the write buffer even if storage is unavailable or events flood.
        if #L.pending<L.limit then L.pending[#L.pending+1]=line;L.pending_bytes=L.pending_bytes+#line end
    end
    function D.diag(event,data)
        if not enabled() then return end
        local ok=pcall(record,event,data)
        if not ok then L.status='Diagnostic event skipped' end
    end
    function L.text()
        local out={header()}
        for i=0,L.count-1 do out[#out+1]=L.lines[(L.head+i-1)%L.limit+1] end
        return table.concat(out)
    end
    local function write()
        local fs=love and love.filesystem
        if not (fs and fs.createDirectory and fs.write and fs.append and fs.getInfo) then return false end
        if not fs.createDirectory(dir) then return false end
        local info=fs.getInfo(path)
        if info and info.size+L.pending_bytes>L.max_bytes then
            -- Do not read a pre-existing oversized file into memory.
            if info.size<=L.max_bytes then
                local old=fs.read(path)
                if not old or not fs.write(dir..'/previous.log',old) then return false end
            end
            if not fs.write(path,header()) then return false end
        elseif not info then
            if not fs.write(path,header()) then return false end
        end
        return fs.append(path,table.concat(L.pending))
    end
    function L.flush()
        if #L.pending==0 then return end
        local ok,result=pcall(write)
        if ok and result then
            L.pending={};L.pending_bytes=0;L.status='Log saved locally'
        else L.status='File unavailable; use Copy log' end
    end
    function L.set_enabled(value)
        if value then
            D.mod.config.diagnostics=true
            L.status='Recording';L.next_tick=nil;L.last_context=nil;L.states={}
            D.diag('enabled');L.flush()
        else
            D.diag('disabled');L.flush();D.mod.config.diagnostics=false
            L.pending={};L.pending_bytes=0;L.status='Off'
        end
    end
    function L.copy()
        local ok,result=pcall(function()
            if not (love and love.system and love.system.setClipboardText) then return false end
            love.system.setClipboardText(L.text());return true
        end)
        L.status=ok and result and 'Copied recent log' or 'Clipboard unavailable'
        return ok and result or false
    end
    function L.tick()
        if not enabled() then return end
        local t=now();if L.next_tick and t<L.next_tick then return end
        L.next_tick=t+1
        local b,run=context();local m=D.average_pvp or {};local r=m.rounds or {}
        local native=D.roster_duel and D.roster_duel.in_run()
        if native then r={ante=G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante} end
        local l=b.lobby
        local context=table.concat({b.phase or '',tostring(b.session),tostring(run),
            tostring(l and l.host_id),tostring(r.ante),tostring(r.open),tostring(r.finished)},'|')
        if context~=L.last_context then
            D.diag('context',{ante=r.ante,players=#(b.ids or {})})
            L.last_context=context;L.states={}
        end
        if l and l.is_host and ((m.active and m.active()) or native) then
            for i,id in ipairs(b.ids or {}) do
                local p=PVP.REF and PVP.REF.players and PVP.REF.players[id]
                if p then
                    local ready=(native and p.is_ready or (not native and r.ready and r.ready[id])) and 1 or 0
                    local marker=table.concat({tostring(p.lives),tostring(p.hands_left),tostring(p.ante),ready},':')
                    if (L.states or {})[i]~=marker then
                        D.diag('state',{seat=i,lives=p.lives,hands=p.hands_left,ante=p.ante,ready=ready})
                        L.states=L.states or {};L.states[i]=marker
                    end
                end
            end
        end
        L.flush()
    end
    return L
end

-- Keep full rosters private until the local API reports that the match ended.
-- Small, retryable seat packets avoid one large post-match action payload.
return function(D)
    local R,core,U,C={open=false},D.core,D.ui,D.mod.config
    D.recap=R
    local function now() return D.now and D.now() or love.timer.getTime() end
    local function name(value,limit)
        local chars={}
        for char in tostring(value):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
            chars[#chars+1]=char;if #chars==limit then break end
        end
        return table.concat(chars)
    end
    function R.make(state,catalog,names)
        assert(state.done and state.schema==core.SCHEMA,'Complete a current draft first')
        local data={schema=1,rounds=state.rounds,picks=state.picks_per_turn,players={},omitted={}}
        local used={}
        for seat=1,core.player_count(state) do
            data.players[seat]={name=name(names[seat] or ('Seat '..seat),24),
                keys=core.copy(state.pools[seat]),history=core.copy(state.history[seat])}
            for _,key in ipairs(state.pools[seat]) do used[key]=true end
        end
        for _,key in ipairs(catalog) do if not used[key] then data.omitted[#data.omitted+1]=key end end
        return data
    end
    local function list(t,max)
        if type(t)~='table' or #t>max then return false end
        local count=0
        for key in pairs(t) do
            if type(key)~='number' or key~=math.floor(key) or key<1 or key>#t then return false end
            count=count+1
        end
        return count==#t
    end
    function R.validate(data,ctx)
        local count_players=core.player_count(ctx)
        if type(data)~='table' or data.schema~=1 or data.rounds~=ctx.rounds or data.picks~=ctx.picks
            or not list(data.players,count_players) or #data.players~=count_players or not list(data.omitted,#ctx.catalog) then return false end
        local allowed,seen={},{}
        for _,key in ipairs(ctx.catalog) do allowed[key]=true end
        local function take(key)
            if type(key)~='string' or not allowed[key] or seen[key] then return false end
            seen[key]=true;return true
        end
        local count=core.roster_size(ctx.rounds)
        for seat,player in ipairs(data.players) do
            if type(player)~='table' or type(player.name)~='string' or #player.name>128
                or not list(player.keys,35) or #player.keys~=count or not list(player.history,35) then return false end
            for _,key in ipairs(player.keys) do if not take(key) then return false end end
            local cursor,index=1,1
            for round=1,ctx.rounds do
                local size=core.round_size(round,ctx.rounds)
                for pick=1,math.ceil(size/ctx.picks) do
                    local entry=player.history[index];index=index+1
                    local origin=core.pack_origin(seat,round,pick,core.player_count(ctx))
                    local needed=math.min(ctx.picks,size-(pick-1)*ctx.picks)
                    if type(entry)~='table' or entry.round~=round or entry.pick~=pick
                        or entry.pack_id~='r'..round..'s'..origin or not list(entry.keys,2) or #entry.keys~=needed then return false end
                    for _,key in ipairs(entry.keys) do
                        if player.keys[cursor]~=key then return false end
                        cursor=cursor+1
                    end
                end
            end
            if index-1~=#player.history or cursor-1~=#player.keys then return false end
        end
        for _,key in ipairs(data.omitted) do if not take(key) then return false end end
        for _,key in ipairs(ctx.catalog) do if not seen[key] then return false end end
        return true
    end
    -- Compact host-recovery backup: catalog indices and pick-order rosters.
    -- History tokens and the undrafted complement are deterministic from these.
    function R.pack(data,catalog)
        local index={};for i,key in ipairs(catalog) do index[key]=i end
        local out={names={},pools={}}
        for seat,p in ipairs(data.players) do
            out.names[seat]=p.name;out.pools[seat]={}
            for i,key in ipairs(p.keys) do out.pools[seat][i]=assert(index[key]) end
        end
        return out
    end
    function R.unpack(packed,ctx)
        local count_players=core.player_count(ctx)
        assert(type(packed)=='table' and list(packed.names,count_players) and #packed.names==count_players
            and list(packed.pools,count_players) and #packed.pools==count_players,'Invalid recovery rosters')
        local data={schema=1,rounds=ctx.rounds,picks=ctx.picks,players={},omitted={}}
        local used={}
        for seat=1,count_players do
            local indices=packed.pools[seat]
            assert(list(indices,35) and #indices==core.roster_size(ctx.rounds),'Invalid recovery roster size')
            local p={name=packed.names[seat],keys={},history={}};data.players[seat]=p
            for i,index in ipairs(indices) do
                assert(type(index)=='number' and index==math.floor(index) and ctx.catalog[index],'Invalid recovery Joker')
                p.keys[i]=ctx.catalog[index];used[p.keys[i]]=true
            end
            local cursor=1
            for round=1,ctx.rounds do
                local size=core.round_size(round,ctx.rounds)
                for pick=1,math.ceil(size/ctx.picks) do
                    local entry={round=round,pick=pick,pack_id='r'..round..'s'..core.pack_origin(seat,round,pick,core.player_count(ctx)),keys={}}
                    for _=1,math.min(ctx.picks,size-(pick-1)*ctx.picks) do
                        entry.keys[#entry.keys+1]=p.keys[cursor];cursor=cursor+1
                    end
                    p.history[#p.history+1]=entry
                end
            end
        end
        for _,key in ipairs(ctx.catalog) do if not used[key] then data.omitted[#data.omitted+1]=key end end
        assert(R.validate(data,ctx),'Invalid recovery recap')
        return data
    end
    local function finish(ctx)
        if ctx.saved or not ctx.ended then return end
        for i=1,core.player_count(ctx)+1 do if not ctx.parts[i] then return end end
        local data={schema=1,rounds=ctx.rounds,picks=ctx.picks,players={},omitted=ctx.parts[core.player_count(ctx)+1].omitted}
        for i=1,core.player_count(ctx) do data.players[i]=ctx.parts[i].player end
        if not R.validate(data,ctx) then return end
        C.last_recap=core.copy(data)
        ctx.saved=true
        SMODS.save_mod_config(D.mod)
    end
    function R.arm(lobby,bridge,identity,run_id,send)
        if not identity or not bridge.pool then return end
        local ctx={lobby=lobby,owner=bridge.owner,ids=core.copy(bridge.ids),session=bridge.session,
            room=bridge.room,player_count=#bridge.ids,identity=identity,run_id=run_id,send=send,parts={},requests={},
            rounds=bridge.pool.rounds,picks=bridge.view.picks_per_turn,catalog=core.copy(bridge.catalog_keys)}
        local names={}
        for i,row in ipairs(bridge.view.roster or {}) do names[i]=row.name end
        if lobby.is_host and bridge.host_state and bridge.host_state.done then
            ctx.payload=R.make(bridge.host_state,ctx.catalog,names)
        end
        R.context=ctx
    end
    local function send_packet(ctx,id,kind,data)
        pcall(ctx.send,{protocol=4,kind=kind,session=ctx.session,room=ctx.room,recipient=id,data=data},id)
    end
    local function send_to(ctx,id)
        if not ctx.ended or not ctx.payload then return end
        for slot=1,core.player_count(ctx)+1 do
            send_packet(ctx,id,'recap_part',{run=ctx.identity,slot=slot,
                player=slot<=core.player_count(ctx) and core.copy(ctx.payload.players[slot]) or nil,
                omitted=slot==core.player_count(ctx)+1 and core.copy(ctx.payload.omitted) or nil})
        end
    end
    function R.event(lobby,kind,ended)
        local ctx=R.context
        if not ctx or ctx.lobby~=lobby then return end
        if kind=='lobby_closed' then R.context=nil;return end
        if kind~='game_ended' or lobby:is_game_started()
            or (type(ended)=='table' and ended.run_id and ctx.run_id and ended.run_id~=ctx.run_id) then return end
        ctx.ended=true
        if ctx.payload and not ctx.sent then
            ctx.sent=true
            for i=1,core.player_count(ctx) do ctx.parts[i]={player=core.copy(ctx.payload.players[i])} end
            ctx.parts[core.player_count(ctx)+1]={omitted=core.copy(ctx.payload.omitted)}
            finish(ctx)
            local present={}
            for _,p in ipairs(lobby:get_players()) do if not p.is_away then present[p.id]=true end end
            for _,id in ipairs(ctx.ids) do if id~=lobby.player_id and present[id] then send_to(ctx,id) end end
        else finish(ctx) end
    end
    function R.receive(sender,packet)
        if type(packet)~='table' or (packet.kind~='recap_part' and packet.kind~='recap_request') then return false end
        local ctx=R.context
        if not ctx or MPAPI.get_current_lobby()~=ctx.lobby or packet.protocol~=4
            or packet.session~=ctx.session or packet.room~=ctx.room or packet.recipient~=ctx.lobby.player_id then return true end
        local data=packet.data
        if type(data)~='table' or data.run~=ctx.identity then return true end
        if packet.kind=='recap_request' then
            local member=false;for _,id in ipairs(ctx.ids) do if id==sender then member=true end end
            if not member or not ctx.payload or not ctx.ended or (ctx.requests[sender] and now()-ctx.requests[sender]<1.5) then return true end
            ctx.requests[sender]=now();send_to(ctx,sender)
        elseif sender==ctx.owner and not ctx.saved then
            local slot=data.slot
            if type(slot)~='number' or slot~=math.floor(slot) or slot<1 or slot>core.player_count(ctx)+1 then return true end
            -- Bound parts before copying; validate cross-seat uniqueness at assembly.
            if slot<=core.player_count(ctx) then
                local p=data.player
                if type(p)~='table' or type(p.name)~='string' or #p.name>128 or not list(p.keys,35) or not list(p.history,35) then return true end
                for _,entry in ipairs(p.history) do
                    if type(entry)~='table' or not list(entry.keys,2) then return true end
                    for _,key in ipairs(entry.keys) do if type(key)~='string' or #key>100 then return true end end
                end
                for _,key in ipairs(p.keys) do if type(key)~='string' or #key>100 then return true end end
                -- Copy only declared fields, including bounded history tokens.
                local player={name=p.name,keys=core.copy(p.keys),history={}}
                for _,entry in ipairs(p.history) do
                    if type(entry.round)~='number' or type(entry.pick)~='number' or type(entry.pack_id)~='string' or #entry.pack_id>10 then return true end
                    player.history[#player.history+1]={round=entry.round,pick=entry.pick,pack_id=entry.pack_id,keys=core.copy(entry.keys)}
                end
                ctx.parts[slot]={player=player}
            else
                if not list(data.omitted,#ctx.catalog) then return true end
                for _,key in ipairs(data.omitted) do if type(key)~='string' or #key>100 then return true end end
                ctx.parts[slot]={omitted=core.copy(data.omitted)}
            end
            finish(ctx)
        end
        return true
    end
    function R.tick()
        local ctx=R.context
        if not ctx or MPAPI.get_current_lobby()~=ctx.lobby or not ctx.ended or ctx.saved or ctx.payload then return end
        if not ctx.retry or now()-ctx.retry>=2 then
            ctx.retry=now();send_packet(ctx,ctx.owner,'recap_request',{run=ctx.identity})
        end
    end
    function R.available() return type(C.last_recap)=='table' and C.last_recap.schema==1 end
    function R.button() return U.button('Last match recap','draftout_recap_open',nil,4) end
    local function open(data,preview)
        R.view,R.preview,R.open,R.tab,R.page,R.order=data,preview,true,1,1,true
        U.show()
    end
    G.FUNCS.draftout_recap_open=function() if R.available() then open(C.last_recap,false) end end
    G.FUNCS.draftout_recap_local=function()
        local s=C.session
        if s and s.done and s.schema==core.SCHEMA then open(R.make(s,s.catalog or D.catalog(),{}),true) end
    end
    G.FUNCS.draftout_recap_close=function() R.open=false;R.view=nil;U.show() end
    G.FUNCS.draftout_recap_tab=function(e)
        local tab=e.config.ref_table
        if type(tab)=='number' and tab==math.floor(tab) and R.view and tab>=1 and tab<=#R.view.players+1 then R.tab,R.page=tab,1;U.show() end
    end
    G.FUNCS.draftout_recap_order=function() R.order=not R.order;R.page=1;U.show() end
    G.FUNCS.draftout_recap_prev=function() R.page=math.max(1,R.page-1);U.show() end
    G.FUNCS.draftout_recap_next=function() R.page=R.page+1;U.show() end
    function R.screen()
        local data=R.view
        local title=R.preview and 'LOCAL DEVELOPMENT RECAP PREVIEW' or 'POST-MATCH DRAFT RECAP'
        local nodes={D.views and D.views.header(title) or U.line(title,0.35)}
        local tabs={}
        for i=1,#data.players+1 do
            local label=i==#data.players+1 and 'Undrafted' or name(data.players[i].name,10)
            local b=U.button(label,'draftout_recap_tab',i,1.6);b.nodes[1].config.scale=0.2
            b.config.colour=R.tab==i and {0.35,0.52,0.53,1} or {0.22,0.29,0.32,1};tabs[#tabs+1]=b
        end
        nodes[#nodes+1]=U.row(tabs)
        local player=R.tab<=#data.players and data.players[R.tab]
        local keys=player and player.keys or data.omitted
        nodes[#nodes+1]=U.line((player and player.name or 'Not drafted')..' - '..#keys..' Jokers',0.28)
        local pages=math.max(1,math.ceil(#keys/12));R.page=math.max(1,math.min(R.page,pages))
        local shown,labels,all_labels={},{},{}
        if player and R.order then
            local index=1
            for _,entry in ipairs(player.history) do for _ in ipairs(entry.keys) do
                all_labels[index]=index..' | P'..entry.round..'.'..entry.pick;index=index+1
            end end
        end
        for i=(R.page-1)*12+1,math.min(#keys,R.page*12) do shown[#shown+1]=keys[i];labels[#shown]=all_labels[i] or ' ' end
        if #shown>0 then
            local grid=D.pack_ui.grid(shown,{scale=0.50,per_row=6,labels=labels})
            grid.config.colour={0.18,0.28,0.31,0.92};grid.config.r=0.10;grid.config.padding=0.06
            nodes[#nodes+1]=grid
        end
        nodes[#nodes+1]=U.line('Page '..R.page..'/'..pages..(player and R.order and ' - pick number | pack.turn' or ''),0.22)
        local controls={U.button('Previous','draftout_recap_prev',nil,2),U.button('Next','draftout_recap_next',nil,2)}
        if player then controls[#controls+1]=U.button(R.order and 'Hide pick labels' or 'Show pick order','draftout_recap_order',nil,3) end
        nodes[#nodes+1]=U.row(controls)
        nodes[#nodes+1]=U.row({U.button('Back','draftout_recap_close',nil,3)})
        return {n=G.UIT.C,config={align='cm',padding=0.04},nodes=nodes}
    end
    return R
end

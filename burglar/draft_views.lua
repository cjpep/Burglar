-- Read-only team gallery and public readiness labels; never expose peer picks.
return function(D)
    local U, V = D.ui, {entries = {},summary={label='0/4 confirmed',waiting=''}}
    D.views = V
    local order = assert(SMODS.load_file('burglar/roster_order.lua', D.mod.id))()
    local MINT={0.69,0.87,0.79,1}
    local ARROW_COLOUR={222/255,148/255,130/255,1} -- Muted coral #DE9482
    local ARROW_PULSE={1,204/255,185/255,1}
    local NAME_COLOUR={0.93,0.95,1,1}
    local CHOOSING_COLOUR={0.65,0.74,0.79,1}
    local DISCONNECTED_COLOUR={0.91,0.58,0.57,1}
    -- Register once during mod loading, not whenever the draft screen refreshes.
    -- Only the BURGLAR heading uses this font; game and progress text stay native.
    local title_font=SMODS.Font and SMODS.Font{
        key='burglar_title',path='Bungee-Regular.ttf',
    }
    function V.header(progress,time_left)
        D.pack_ui.header_time=time_left
        local title=U.line(progress,0.36)
        title.nodes[1].config.colour={0.86,0.89,0.93,1}
        title.nodes[1].config.shadow=true
        -- Give the brand its own centered row; progress and the live timer
        -- share a quieter second row so the header stays compact.
        local brand,rest=progress:match('^(BURGLAR)(.*)$')
        local details={}
        if brand and (rest=='' or rest:match('^%s')) then
            title.nodes[1].config.text=brand
            title.nodes[1].config.colour={0.86,0.73,0.46,1}
            title.nodes[1].config.font=title_font
            title.nodes[1].config.scale=0.40
            rest=rest:gsub('^%s*|%s*',''):gsub('^%s+',''):gsub('%s+$','')
            if rest~='' then
                details[#details+1]={n=G.UIT.C,config={align='cm',padding=0},nodes={
                    {n=G.UIT.T,config={text=rest,scale=0.26,
                        colour={0.86,0.89,0.93,1},shadow=true}}}}
            end
        end
        title.config.padding=0.02
        local nodes={title}
        local left,paused
        if time_left then left,paused=time_left() end
        if left~=nil then
            D.pack_ui.ui.timer=(paused and 'Timer paused: ' or 'Time left: ')..math.ceil(left)..'s'
            if #details>0 then
                details[#details+1]={n=G.UIT.B,config={w=0.22,h=0.01,colour=G.C.CLEAR}}
            end
            details[#details+1]={n=G.UIT.C,config={align='cm',padding=0},
                nodes={D.pack_ui.timer_node()}}
        end
        if #details>0 then
            local detail_row=U.row(details);detail_row.config.padding=0.02
            nodes[#nodes+1]=detail_row
        end
        -- Paint the shared-width row, like the readiness strip below it.
        -- The inner column only centers content; a coloured column here
        -- would shrink to the text and leave an isolated badge in empty space.
        local header=U.row({{n=G.UIT.C,config={align='cm',padding=0.03,
            colour=G.C.CLEAR},nodes=nodes}})
        header.config.padding=0.07
        header.config.r=0.10
        header.config.colour={0.19,0.29,0.33,0.94}
        return header
    end
    local function quiet(label,action,width,data)
        local b=U.button(label,action,data,width)
        b.config.colour=G.C.UI.BACKGROUND_INACTIVE or G.C.BLACK
        b.config.minh=0.35;b.nodes[1].config.scale=0.21
        return b
    end
    -- Expand utilities inside the existing panel; opening them never pauses or
    -- restarts the pick clock, or replaces a player's tentative selections.
    function V.navigation()
        return {quiet('Back','draftout_close',1.1),quiet(D.more_open and 'Less' or 'More','draftout_more',1.1)}
    end
    function V.utilities()
        local controls={}
        if D.mode=='mp' then
            local B=D.mpbridge
            if B and B.owner then controls[#controls+1]=quiet('Resync pack','draftout_mp_refresh',2.2) end
            local l=MPAPI and MPAPI.get_current_lobby()
            if l and l.is_host then controls[#controls+1]=quiet('Reset draft','draftout_mp_check',2.2) end
        else controls[#controls+1]=quiet('New draft','draftout_new',2.2) end
        return U.row(controls)
    end
    G.FUNCS.draftout_more=function() D.more_open=not D.more_open;U.show() end
    local function short_name(value)
        local out={}
        for char in tostring(value):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
            out[#out+1]=char
            if #out==10 then break end
        end
        return table.concat(out)
    end
    function V.update(rows,round)
        V.round=round or V.round or 1
        local direction=D.core.direction(V.round)
        local side=direction==1 and 'left' or 'right'
        local ready=0
        for i, row in ipairs(rows or {}) do
            local entry = V.entries[i] or {}; V.entries[i] = entry
            local state = row.connected == false and 'Disconnected' or row.ready and 'Confirmed' or 'Choosing'
            entry.label = short_name(row.name or ('Seat ' .. i)) .. ': ' .. state
            local mine=i==V.seat
            entry.title=D.mode=='mp' and short_name(row.name or ('Seat '..i))
                or (mine and 'YOU' or ('Seat '..i))
            entry.marker=D.mode=='mp' and mine and ' (YOU)' or ''
            entry.title_colour=mine and MINT or NAME_COLOUR
            entry.state=state
            entry.colour = row.connected == false and DISCONNECTED_COLOUR
                or row.ready and MINT or CHOOSING_COLOUR
            if row.ready then ready=ready+1 end
        end
        local count=#(rows or {})
        if V.seat and count>0 then
            local next_seat=((V.seat-1+direction)%count)+1
            local previous=((V.seat-1-direction)%count)+1
            V.summary.flow='From '..short_name(rows[previous].name or ('Seat '..previous))
                ..' | Passing '..side..' to '..short_name(rows[next_seat].name or ('Seat '..next_seat))
        else V.summary.flow='Packs pass '..side end
        V.summary.label=ready..'/'..count..' confirmed'
        local left=#(rows or {})-ready
        V.summary.waiting=left==0 and 'Picks locked - passing the pack...' or ('Picks locked - waiting for '..left..' player'..(left==1 and '' or 's'))
    end
    -- Observe draft progress only: redraws, readiness changes and local seat
    -- switches are not passes. A new round opens fresh packs instead.
    local function observe_pass()
        local online=D.mode=='mp'
        local bridge=online and D.mpbridge
        local draft=online and bridge and bridge.view or (not online and D.mod.config.session)
        local source=online and bridge and bridge.session or draft
        if not draft or not source then V.pass_progress,V.pass_started=nil,nil;return end
        local previous=V.pass_progress
        if previous and previous.source==source and previous.online==online
            and previous.round==draft.round then
            if type(draft.pick)=='number' and type(previous.pick)=='number'
                and draft.pick==previous.pick+1 then
                V.pass_started=D.now()
            end
        else V.pass_started=nil end
        V.pass_progress={source=source,online=online,round=draft.round,pick=draft.pick}
    end
    G.FUNCS.draftout_pass_arrow_colour=function(e)
        local elapsed=V.pass_started and (D.now()-V.pass_started)
        if not elapsed or elapsed>0.8 or D.mod.config.pack_effects==false
            or (G.SETTINGS and G.SETTINGS.reduced_motion) then
            e.config.colour=ARROW_COLOUR;return
        end
        local step=D.core.direction(V.round)==1 and e.config.arrow_index-1
            or e.config.arrow_count-e.config.arrow_index
        local t=(elapsed-step*0.09)/0.6
        local glow=t>0 and t<1 and math.sin(math.pi*t) or 0
        local colour=e.config.pulse_colour or {};e.config.pulse_colour=colour
        colour[1]=ARROW_COLOUR[1]+(ARROW_PULSE[1]-ARROW_COLOUR[1])*glow
        colour[2]=ARROW_COLOUR[2]+(ARROW_PULSE[2]-ARROW_COLOUR[2])*glow
        colour[3]=ARROW_COLOUR[3]+(ARROW_PULSE[3]-ARROW_COLOUR[3])*glow
        colour[4]=1
        e.config.colour=colour
    end
    function V.readiness(rows,seat,round)
        observe_pass()
        V.seat=seat
        V.update(rows,round or 1)
        local arrow=D.core.direction(V.round)==1 and '>' or '<'
        local cells = {}
        local function compact_row(nodes)
            local r=U.row(nodes);r.config.padding=0.01;return r
        end
        for i in ipairs(rows or {}) do
            local entry=V.entries[i]
            cells[#cells+1] = {n = G.UIT.C, config = {align = 'cm', minw = 1.90,maxw=1.90,padding=0.025}, nodes = {
                compact_row({
                    {n=G.UIT.T,config={ref_table=entry,ref_value='title',scale=0.27,
                        colour=entry.title_colour,func='draftout_seat_name_colour'}},
                    {n=G.UIT.T,config={ref_table=entry,ref_value='marker',scale=0.14,colour=MINT}},
                }),
                compact_row({{n=G.UIT.T,config={ref_table=entry,ref_value='state',scale=0.18,
                    colour=entry.colour,func='draftout_ready_colour'}}}),
            }}
            if i<#rows then
                cells[#cells+1]={n=G.UIT.C,config={align='cm',minw=0.24,padding=0},nodes={
                    {n=G.UIT.T,config={text=arrow,scale=0.27,colour=ARROW_COLOUR,
                        arrow_index=i,arrow_count=#rows-1,func='draftout_pass_arrow_colour'}}}}
            end
        end
        -- Only show readiness totals here. Passing neighbors/direction are
        -- tracked by the draft engine but do not need textual narration.
        local status=U.row({{n=G.UIT.C,config={align='cm',padding=0.025},nodes={compact_row(cells),
            {n=G.UIT.R,config={align='cm',padding=0},nodes={
                {n=G.UIT.B,config={w=0.01,h=0.025,colour=G.C.CLEAR}}}},
            compact_row({{n=G.UIT.T,config={ref_table=V.summary,ref_value='label',
                scale=0.20,colour={0.72,0.90,0.95,1}}}})}}})
        status.config.padding=0.045
        status.config.r=0.10
        status.config.colour={0.19,0.29,0.33,0.94}
        return status
    end
    G.FUNCS.draftout_ready_colour = function(e) e.config.colour = e.config.ref_table.colour end
    G.FUNCS.draftout_seat_name_colour = function(e) e.config.colour = e.config.ref_table.title_colour end
    function V.waiting(get_keys,identity,options)
        local nodes={{n=G.UIT.R,config={align='cm'},nodes={{n=G.UIT.T,config={
            ref_table=V.summary,ref_value='waiting',scale=0.24,colour=G.C.WHITE}}}}}
        if get_keys then
            D.roster_context={get_keys=get_keys,identity=identity,total=options and options.total}
        end
        -- Same 2x5 slot footprint as the active pack, so the draft panel does
        -- not collapse when a player locks picks before the other seats.
        nodes[#nodes+1]=D.pack_ui.grid({}, {scale=0.74,per_row=5,slots=10})
        return U.row({{n=G.UIT.C,config={align='cm'},nodes=nodes}})
    end
    -- Legacy tray retained for compatibility with any external caller.
    -- Active Burglar pack pages now use the dedicated left-hand roster.
    function V.team_tray(get_keys,identity,options)
        local o=options or {}
        if not V.tray or V.tray.identity~=identity then
            V.tray={identity=identity,page=1,sort='Recent'}
        end
        local tray=V.tray
        local source=get_keys() or {}
        local keys={};for i,key in ipairs(source) do keys[i]=key end
        if tray.sort=='Recent' then
            local reversed={};for i=#keys,1,-1 do reversed[#reversed+1]=keys[i] end;keys=reversed
        elseif tray.sort=='Rarity' then
            local rarity={Common=1,Uncommon=2,Rare=3}
            table.sort(keys,function(a,b)
                local ca,cb=G.P_CENTERS[a],G.P_CENTERS[b]
                local ra,rb=ca and ca.rarity or 0,cb and cb.rarity or 0
                ra,rb=rarity[ra] or ra,rarity[rb] or rb
                if ra~=rb then return ra>rb end
                return a<b
            end)
        end
        local pages=math.max(1,math.ceil(#keys/6))
        tray.page=math.max(1,math.min(tray.page,pages))
        local shown={};for i=(tray.page-1)*6+1,math.min(#keys,tray.page*6) do shown[#shown+1]=keys[i] end
        local function small(label,action,width)
            return quiet(label,action,width or 0.7,tray)
        end
        local nodes={U.line('YOUR TEAM  '..#keys..(o.total and ('/'..o.total) or ''),0.23),
            U.row({small(tray.sort,'draftout_tray_sort',1.9)})}
        if #shown>0 then nodes[#nodes+1]=D.pack_ui.grid(shown,{scale=0.32,per_row=3,tray=true})
        else nodes[#nodes+1]=U.line('No picks yet',0.2) end
        nodes[#nodes+1]=U.row({small('<','draftout_tray_prev'),
            {n=G.UIT.C,config={align='cm',minw=0.6},nodes={U.line(tray.page..'/'..pages,0.18)}},
            small('>','draftout_tray_next')})
        local full=V.team_button(get_keys,o.time_left,'Full roster')
        full.config.minw=2;full.config.minh=0.35;full.nodes[1].config.scale=0.21
        full.config.colour=G.C.UI.BACKGROUND_INACTIVE or G.C.BLACK
        nodes[#nodes+1]=U.row({full})
        return {n=G.UIT.C,config={align='cm',minw=2.15,padding=0.10,r=0.08},nodes=nodes}
    end
    local function tray_action(fn)
        return function(e)
            if e.config.ref_table~=V.tray then return end
            fn(V.tray);U.show()
        end
    end
    G.FUNCS.draftout_tray_prev=tray_action(function(t) t.page=math.max(1,t.page-1) end)
    G.FUNCS.draftout_tray_next=tray_action(function(t) t.page=t.page+1 end)
    G.FUNCS.draftout_tray_sort=tray_action(function(t)
        t.sort=t.sort=='Recent' and 'Rarity' or t.sort=='Rarity' and 'Draft order' or 'Recent';t.page=1
    end)


    -- A paged roster is displayed next to the draft panel,
    -- never embedded in the active Joker grid. Its order is purely visual.
    local function roster_pages(capacity)
        local pages={math.min(15,capacity)}
        local remaining=capacity-pages[1]
        if remaining>0 then
            pages[2]=math.min(12,remaining)
            remaining=remaining-pages[2]
        end
        if remaining>0 then pages[3]=remaining end
        return pages
    end
    function V.roster_sidebar(get_keys,identity,options)
        local o=options or {}
        if not V.roster or V.roster.identity~=identity then V.roster=order.new(identity) end
        local state=V.roster
        local keys=order.sync(state,get_keys() or {},{
            name=function(key) return D.joker_name and D.joker_name(key) or key end,
            rarity=function(key)
                local value=(G.P_CENTERS[D.core.key(key)] or {}).rarity
                return ({Common=1,Uncommon=2,Rare=3,Legendary=4})[value] or tonumber(value) or 0
            end,
        })
        local capacity=math.max(#keys, tonumber(o.total) or 27)
        state.total=capacity
        local pages=roster_pages(capacity)
        state.page=math.max(1,math.min(state.page or 1,#pages))
        local page_slots=pages[state.page]
        local start=1
        for i=1,state.page-1 do start=start+pages[i] end
        local finish=math.min(capacity,start+page_slots-1)
        local visible={}
        for idx=start,finish do visible[#visible+1]=keys[idx] end
        local body=D.pack_ui.grid(visible,{scale=0.30,
            per_row=3,slots=page_slots,roster=true,
            selected_slot=state.selected,slot_offset=start-1,
            on_slot_click=function(index)
                if order.choose(state,index) then U.show() end
            end})
        local sort=quiet('Sort: '..state.sort..' >','draftout_roster_sort',3.0,state)
        sort.nodes[1].config.scale=0.20
        local prev=quiet('<','draftout_roster_page_prev',0.68)
        local next=quiet('>','draftout_roster_page_next',0.68)
        prev.config.ref_table=state;next.config.ref_table=state
        local roster_title=U.line('JOKER ROSTER',0.30)
        roster_title.nodes[1].config.colour={0.74,0.87,0.83,1}
        local contents={
            roster_title,
            U.line(#keys..' / '..capacity..' confirmed',0.21),
            -- Buttons are C nodes. Give the sort control its own R so native
            -- layout cannot place/stretch it beside the following card grid.
            U.row({sort}),
            body,
            U.row({prev,{n=G.UIT.C,config={align='cm',minw=1.3},nodes={U.line('Page '..state.page..'/'..#pages,0.20)}},next}),
            U.line('Select two to swap',0.19),
        }
        -- Keep the panel background at content height instead of stretching
        -- with the taller draft panel in the adjacent column.
        local compact={n=G.UIT.C,config={align='cm',minw=3.4,
            padding=0.10,r=0.11,colour={0.20,0.31,0.34,0.98}},nodes=contents}
        return {n=G.UIT.C,config={align='tm',minw=3.4,padding=0,
            colour=G.C.CLEAR,id='draftout_roster_sidebar'},nodes={compact}}
    end
    G.FUNCS.draftout_roster_sort=function(e)
        if not (V.roster and e and e.config and e.config.ref_table==V.roster) then return end
        for i,value in ipairs(order.sorts) do
            if value==V.roster.sort then
                order.set_sort(V.roster,order.sorts[i%#order.sorts+1]);U.show();return
            end
        end
    end

    local function page_roster(e,delta)
        if not (V.roster and e and e.config and e.config.ref_table==V.roster) then return end
        local capacity=math.max(#(V.roster.keys or {}), tonumber(V.roster.total) or 27)
        local pages=roster_pages(capacity)
        V.roster.page=math.max(1,math.min((V.roster.page or 1)+delta,#pages))
        U.show()
    end
    G.FUNCS.draftout_roster_page_prev=function(e) page_roster(e,-1) end
    G.FUNCS.draftout_roster_page_next=function(e) page_roster(e,1) end

    function V.completed(keys,instruction,compact)
        local counts={0,0,0}
        for _,key in ipairs(keys) do
            local rarity=G.P_CENTERS[D.core.key(key)] and G.P_CENTERS[D.core.key(key)].rarity
            rarity=({Common=1,Uncommon=2,Rare=3})[rarity] or rarity
            if counts[rarity] then counts[rarity]=counts[rarity]+1 end
        end
        local nodes={V.header('DRAFT COMPLETE - '..#keys..' JOKERS'),
            U.line(counts[1]..' Common / '..counts[2]..' Uncommon / '..counts[3]..' Rare',0.28)}
        if not compact then
            local signature=table.concat(keys,'|')
            if not V.final or V.final.signature~=signature then V.final={signature=signature,page=1} end
            local pages=math.max(1,math.ceil(#keys/14))
            V.final.page=math.max(1,math.min(V.final.page,pages))
            local shown={}
            for i=(V.final.page-1)*14+1,math.min(#keys,V.final.page*14) do shown[#shown+1]=keys[i] end
            if #shown>0 then nodes[#nodes+1]=D.pack_ui.grid(shown,{scale=0.48}) end
            nodes[#nodes+1]=U.line('Roster page '..V.final.page..'/'..pages,0.23)
            nodes[#nodes+1]=U.row({U.button('Previous','draftout_final_prev',nil,2),U.button('Next','draftout_final_next',nil,2)})
        end
        nodes[#nodes+1]=U.row({V.team_button(function() return keys end,nil,'Review final roster')})
        nodes[#nodes+1]=U.line(instruction,0.26)
        return U.row({{n=G.UIT.C,config={align='cm'},nodes=nodes}})
    end
    G.FUNCS.draftout_final_prev=function() if V.final then V.final.page=V.final.page-1; U.show() end end
    G.FUNCS.draftout_final_next=function() if V.final then V.final.page=V.final.page+1; U.show() end end

    function V.team_button(get_keys, time_left, label)
        return U.button(label or 'My Team', 'draftout_team_open', {get_keys = get_keys, time_left = time_left}, 2.3)
    end
    function V.team_screen()
        local team = V.team
        local keys = team.get_keys() or {}
        local pages = math.max(1, math.ceil(#keys / 14))
        team.page = math.max(1, math.min(team.page, pages))
        local shown = {}
        for i = (team.page-1)*14+1, math.min(#keys, team.page*14) do shown[#shown+1] = keys[i] end
        local nodes = {U.line('MY DRAFTED TEAM - ' .. #keys .. ' JOKERS', 0.36),
            U.line('Hover a Joker to read its effect. These are your available types.', 0.24)}
        if #shown > 0 then nodes[#nodes+1] = D.pack_ui.grid(shown, {scale = 0.6})
        else nodes[#nodes+1] = U.line('Your first confirmed picks will appear here.') end
        nodes[#nodes+1] = U.line('Page ' .. team.page .. '/' .. pages, 0.25)
        nodes[#nodes+1] = U.row({U.button('Previous', 'draftout_team_prev', nil, 2),
            U.button('Next', 'draftout_team_next', nil, 2), U.button('Back to draft', 'draftout_team_close', nil, 3)})
        nodes[#nodes+1] = D.pack_ui.timer_node()
        return {n = G.UIT.C, config = {align = 'cm', padding = 0.03}, nodes = nodes}
    end
    G.FUNCS.draftout_team_open = function(e)
        V.team = {get_keys = e.config.ref_table.get_keys, time_left = e.config.ref_table.time_left, page = 1}
        U.show()
    end
    G.FUNCS.draftout_team_close = function() V.team = nil; U.show() end
    G.FUNCS.draftout_team_prev = function() V.team.page = math.max(1,V.team.page-1); U.show() end
    G.FUNCS.draftout_team_next = function() V.team.page = V.team.page+1; U.show() end
end

-- Optional post-draft review. Opponent rosters are never sent during drafting,
-- and this viewer is unavailable once a match starts or the lobby changes.
return function(D)
    local M={open=false,seat=1,page=1}
    local core,U=D.core,D.ui
    D.open_lists=M
    local function screen(nodes)
        return {n=G.UIT.C,config={align='cm',padding=0.04},nodes=nodes}
    end
    local function short_name(value)
        local chars={}
        for char in value:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
            chars[#chars+1]=char
            if #chars==24 then break end
        end
        return table.concat(chars)
    end

    local function array(value,size)
        if type(value)~='table' or #value~=size then return false end
        local count=0
        for key in pairs(value) do
            if type(key)~='number' or key~=math.floor(key) or key<1 or key>size then return false end
            count=count+1
        end
        return count==size
    end

    function M.validate(data,B)
        if data.open_deck_lists~=nil and type(data.open_deck_lists)~='boolean' then return false end
        local enabled=data.open_deck_lists==true
        if B.view and (B.view.open_deck_lists==true)~=enabled then return false end
        if not enabled or not data.done then return data.open_rosters==nil end
        if not array(data.open_rosters,#B.ids) then return false end
        local seen={}
        for seat,roster in ipairs(data.open_rosters) do
            if not array(roster,core.roster_size(data.rounds)) then return false end
            for index,id in ipairs(roster) do
                if type(id)~='string' or not B.catalog_set[id] or seen[id] then return false end
                if seat==data.seat and id~=data.drafted[index] then return false end
                seen[id]=true
            end
        end
        return true
    end

    local function lists()
        if D.mode=='mp' then
            local B=D.mpbridge
            local l=MPAPI and MPAPI.get_current_lobby and MPAPI.get_current_lobby()
            if not B or B.phase~='complete' or B.started or not l or l~=B.lobby
                or l:is_game_started() or not B.matches() then return end
            local v=B.view
            if v and v.done and v.open_deck_lists==true then return v.open_rosters,v.roster,v.seat end
        elseif not D.local_launcher and not (G.STAGES and G.STAGE==G.STAGES.RUN) then
            local s=D.mod.config.session
            if s and s.done and s.open_deck_lists==true then return s.pools,nil,D.mod.config.armed_seat or 1 end
        end
    end
    function M.available() return lists()~=nil end
    function M.button() return U.button('Review all rosters','draftout_open_lists',nil,4.0) end
    local function close() M.open=false; U.show() end
    function M.screen()
        local rosters,players=lists()
        if not rosters then
            return screen({U.line('Roster review is no longer available.'),U.row({U.button('Back','draftout_close_lists')})})
        end
        M.seat=math.max(1,math.min(M.seat,#rosters))
        local keys=rosters[M.seat]
        local pages=math.max(1,math.ceil(#keys/14))
        M.page=math.max(1,math.min(M.page,pages))
        local visible={}
        for i=(M.page-1)*14+1,math.min(M.page*14,#keys) do visible[#visible+1]=keys[i] end
        local player=players and players[M.seat]
        local label='Seat '..M.seat
        if player and type(player.name)=='string' then label=label..' - '..short_name(player.name) end
        local nodes={U.line('OPEN DECK LISTS',0.45),U.line(label,0.36),
            U.line(#keys..' drafted Jokers',0.26),
            U.row({U.button('Previous player','draftout_lists_prev_seat',nil,3),
                U.button('Next player','draftout_lists_next_seat',nil,3)})}
        local grid=D.pack_ui.grid(visible,{scale=0.60,per_row=7,roster=true})
        nodes[#nodes+1]=grid
        nodes[#nodes+1]=U.line('Page '..M.page..' / '..pages,0.26)
        if pages>1 then nodes[#nodes+1]=U.row({U.button('Previous page','draftout_lists_prev_page',nil,3),
            U.button('Next page','draftout_lists_next_page',nil,3)}) end
        nodes[#nodes+1]=U.row({U.button('Back to draft','draftout_close_lists',nil,4)})
        return screen(nodes)
    end
    G.FUNCS.draftout_open_lists=function()
        local rosters,_,own=lists()
        if not rosters then return end
        M.open,M.seat,M.page=true,own or 1,1
        U.show()
    end
    G.FUNCS.draftout_close_lists=close
    local function change(seat_delta,page_delta)
        local rosters=lists()
        if not rosters then return close() end
        if seat_delta then M.seat=(M.seat-1+seat_delta)%#rosters+1;M.page=1 end
        if page_delta then M.page=(M.page-1+page_delta)%math.max(1,math.ceil(#rosters[M.seat]/14))+1 end
        U.show()
    end
    G.FUNCS.draftout_lists_prev_seat=function() change(-1) end
    G.FUNCS.draftout_lists_next_seat=function() change(1) end
    G.FUNCS.draftout_lists_prev_page=function() change(nil,-1) end
    G.FUNCS.draftout_lists_next_page=function() change(nil,1) end
    return M
end

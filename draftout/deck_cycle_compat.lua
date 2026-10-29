-- SMODS' shared deck callback applies the active mod's Collection filter even
-- in run setup. A leftover mod-menu context can empty that pool; Back:change_to
-- then receives nil and falls back to Red Deck. Only run-setup cycles should
-- ignore the Collection context. Actual mod Collections must keep their filter.
local M={}
local tag='draftout_run_setup_cycle'
local function pack(...) return {n=select('#',...),...} end
local function without_collection(fn,...)
    local context=G.ACTIVE_MOD_UI
    G.ACTIVE_MOD_UI=nil
    local result=pack(pcall(fn,...))
    G.ACTIVE_MOD_UI=context
    if not result[1] then error(result[2],0) end
    return unpack(result,2,result.n)
end
function M.install()
    if M.installed or not (G and G.UIDEF and G.UIDEF.run_setup_option
        and G.FUNCS and G.FUNCS.change_viewed_back and create_option_cycle) then return false end
    M.installed=true
    local build=G.UIDEF.run_setup_option
    G.UIDEF.run_setup_option=function(...)
        local cycle=create_option_cycle
        create_option_cycle=function(args,...)
            if args and args.opt_callback=='change_viewed_back' then args[tag]=true end
            return cycle(args,...)
        end
        local result=pack(pcall(without_collection,build,...))
        create_option_cycle=cycle
        if not result[1] then error(result[2],0) end
        return unpack(result,2,result.n)
    end
    local change=G.FUNCS.change_viewed_back
    G.FUNCS.change_viewed_back=function(args,...)
        if args and args.cycle_config and args.cycle_config[tag] then
            return without_collection(change,args,...)
        end
        return change(args,...)
    end
    return true
end
return M

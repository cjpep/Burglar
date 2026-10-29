-- One ordered frame hook for Burglar. Module callbacks run after native update.
return function(D)
    if D.updates then return D.updates end
    local updates={callbacks={},names={}}
    D.updates=updates
    function updates.add(name,callback)
        assert(not updates.names[name],'Duplicate Burglar update callback: '..name)
        updates.names[name]=true
        updates.callbacks[#updates.callbacks+1]=callback
    end
    local original=Game.update
    local function after_native(self,dt,...)
        for _,callback in ipairs(updates.callbacks) do callback(self,dt) end
        return ...
    end
    function Game:update(dt,...)
        return after_native(self,dt,original(self,dt,...))
    end
    return updates
end

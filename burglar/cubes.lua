-- Data-only pools; repeated JSON keys receive stable, distinct draft copy IDs.
return function(D)
    if D.cubes then return D.cubes end
    -- Retire the former preset without breaking a saved selection.
    if D.mod.config.draft_cube=='commons' then D.mod.config.draft_cube='default' end
    local C={}
    D.cubes=C
    local function filename(value)
        return type(value)=='string' and value:match('^[%w_-]+%.json$')
    end
    function C.validate(keys,encoded)
        assert(type(keys)=='table' and #keys>0 and #keys<=512,'Draft pool must contain a nonempty jokers array')
        local allowed,seen,out={},{},{}
        for _,key in ipairs(D.catalog()) do allowed[key]=true end
        local count=0
        for index,key in pairs(keys) do
            count=count+1
            assert(type(index)=='number' and index==math.floor(index) and index>=1 and index<=#keys,
                'Jokers must be a JSON array')
            local base=encoded and D.core.key(key) or key
            assert(type(key)=='string' and allowed[base],'Unavailable or excluded Joker: '..tostring(key):sub(1,70))
            seen[base]=(seen[base] or 0)+1
            out[#out+1]=base
        end
        assert(count==#keys,'Jokers must be a contiguous array')
        table.sort(out)
        local counts={}
        for i,key in ipairs(out) do
            counts[key]=(counts[key] or 0)+1
            if counts[key]>1 then out[i]=key..'#'..counts[key] end
        end
        table.sort(out)
        return out
    end
    function C.capacity(keys,options)
        local need=options.player_count*D.core.roster_size(options.packs_per_player,options.pack_size)
        assert(#keys>=need,'Draft pool has '..#keys..' Jokers; these settings need '..need..'. Choose fewer packs or a larger pool.')
    end
    function C.choices()
        local out={'default'}
        if NFS and NFS.getDirectoryItems and D.mod.path then
            local ok,files=pcall(NFS.getDirectoryItems,D.mod.path..'cubes')
            if ok and type(files)=='table' then
                table.sort(files)
                for _,file in ipairs(files) do if filename(file) then out[#out+1]=file end end
            end
        end
        return out
    end
    function C.label(id)
        id=id or D.mod.config.draft_cube or 'default'
        if id=='default' then return 'Default' end
        return tostring(id):sub(1,40)
    end
    function C.selected()
        local id=D.mod.config.draft_cube or 'default'
        if id=='default' then return C.validate(D.catalog()),'Default' end
        assert(filename(id),'Invalid cube filename; use letters, numbers, underscores or hyphens')
        assert(NFS and NFS.read and D.mod.path,'Cannot read the cubes folder')
        local text=NFS.read(D.mod.path..'cubes/'..id)
        assert(type(text)=='string','Cube file missing: '..id)
        assert(#text<=65536,'Cube JSON must be under 64 KiB')
        assert(MPAPI and MPAPI.json_decode,'Multiplayer API JSON reader is not ready')
        local ok,data=pcall(MPAPI.json_decode,text)
        assert(ok and type(data)=='table','Invalid JSON in '..id)
        assert(data.version==1,'Cube JSON requires version: 1')
        local name=data.name or id
        assert(type(name)=='string' and #name>0 and #name<=40 and not name:find('%c'),
            'Cube name must be 1-40 characters without line breaks')
        return C.validate(data.jokers),name
    end
    return C
end

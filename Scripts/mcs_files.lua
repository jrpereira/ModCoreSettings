-- Optional UE4SSLuaFileBridge access for MCS's own Lua state: Unicode-safe stat, listing,
-- reads and atomic writes. The bridge's safe set already allows writing inside this mod's
-- folder. open() returns nil when the bridge is absent or speaks another API; every caller
-- then falls back to io.
local M={}

local function check(value,code,message)
    if value==nil then error(tostring(message or code),0) end
    return value
end

-- report(what,why) receives the reason the bridge is unusable, when it is installed.
function M.open(report,bridge)
    bridge=bridge or rawget(_G,'UE4SSLuaFileBridge')
    if bridge==nil then return nil end
    local ok,result=pcall(function()
        local capabilities=bridge.GetCapabilities()
        assert(type(capabilities)=='table' and capabilities.api==1,'unsupported UE4SSLuaFileBridge API')
        local env=bridge()
        local files={}
        -- A path's Stat record, or nil when it cannot be read.
        function files.stat(path) return (env.Stat(path)) end
        -- A folder's entries by name ({type=,size=,created=,...}), or nil when it cannot be
        -- listed. Its sizes come from the folder's own copy of each file's details, which
        -- Windows may update late for linked files: use it for creation times only.
        function files.list(path)
            local entries=env.List(path)
            if type(entries)~='table' then return nil end
            local byName={}
            for _,entry in ipairs(entries) do byName[entry.name]=entry end
            return byName
        end
        function files.size(path)
            local stat=env.Stat(path)
            return stat and stat.type=='file' and stat.size or nil
        end
        -- Contents, or nil for a missing file; any other failure raises.
        function files.read(path)
            local text,code,message=env.ReadText(path)
            if text==nil and code=='not_found' then return nil end
            return check(text,code,message)
        end
        function files.write(path,text) check(env.WriteText(path,text)) end
        function files.mkdir(path) check(env.MakeDir(path)) end
        return files
    end)
    if not ok then
        if report then report('UE4SSLuaFileBridge',tostring(result)) end
        return nil
    end
    return result
end

return M

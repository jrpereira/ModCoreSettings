-- The latest error lines of UE4SS.log, which every mod writes to: the ModCore page's Errors
-- tab shows them. Each mod runs in its own Lua state, so the shared log is the one place
-- all their errors meet. Reading is incremental and never fails its caller.
-- window: how much of a large log the first look reads, from its end; enough for
-- the last limit error lines without stalling the menu tick that opens the tab.
local M={version=1,limit=100,width=300,window=262144}

-- UE4SS prints its engine offsets at startup (FArchiveState::ArIsCriticalError = 0x29);
-- those name errors without being any.
local function offset(line) return line:find('::[%w_]+ = 0x%x+%s*$')~=nil end

-- An error line: a ModCore ERROR or CRITICAL message, a failed Lua call, or one that
-- mentions an error, exception or stack traceback.
function M.isError(line)
    if offset(line) then return false end
    if line:find('%] ERROR ') or line:find('%] CRITICAL ') then return true end
    local lower=line:lower()
    return lower:find('%f[%a]errors?%f[%A]')~=nil or lower:find('%f[%a]exception%f[%A]')~=nil
        or lower:find('traceback',1,true)~=nil or line:find('lua_pcall returned',1,true)~=nil
end

-- A line UE4SS wrote without its [timestamp] prefix continues the message before it, as a
-- Lua stack trace does.
local function continuation(line) return not line:find('^%[%d%d%d%d%-') end

-- reader(path, open): poll() returns the latest error lines, oldest first, and whether
-- they changed since the last poll. open defaults to io.open.
function M.reader(path,open)
    open=open or io.open
    local position,partial,lines,following=0,'',{},false
    local reader={}
    local function keep(line)
        if #line>M.width then line=line:sub(1,M.width-3)..'...' end
        lines[#lines+1]=line
        if #lines>M.limit then table.remove(lines,1) end
    end
    local function consume(chunk)
        local changed=false
        partial=partial..chunk
        for line in partial:gmatch('([^\n]*)\n') do
            line=line:gsub('\r$','')
            if continuation(line) then
                if following and line:find('%S') then keep(line);changed=true end
            else
                following=M.isError(line)
                if following then keep(line);changed=true end
            end
        end
        partial=partial:match('([^\n]*)$')
        return changed
    end
    function reader.poll()
        local ok,changed=pcall(function()
            local file=open(path,'rb')
            if not file then return false end
            local size=file:seek('end')
            local reset=false
            -- A smaller log is a new session: start over.
            if size<position then position,partial,lines,following,reset=0,'',{},false,true end
            -- A first look at a large log reads only its end.
            if position==0 and size>M.window then position=size-M.window end
            file:seek('set',position)
            local chunk=file:read(size-position) or ''
            file:close()
            position=position+#chunk
            return consume(chunk) or reset
        end)
        return lines,ok and changed or false
    end
    return reader
end

-- The text an Errors view shows for the lines poll() returns.
function M.text(lines)
    if #lines==0 then return 'No errors logged this session.' end
    return table.concat(lines,'\n')
end

return M

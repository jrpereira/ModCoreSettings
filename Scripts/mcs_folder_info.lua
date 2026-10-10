-- cache/folder_info.json: what MCS last saw at the top of each active mod folder, when the
-- folder was added and when it was last updated. A folder is added when it first appears,
-- and updated whenever its top-level files or folders change. A folder that disappears is
-- forgotten, so reinstalling it counts as new.
--
-- With file dates (UE4SSLuaFileBridge), a folder seen for the first time was added at the
-- newest creation time of its top-level files: Vortex's linked files keep the time they
-- were installed through a purge and redeploy, and a copied file is created when copied.
-- An update in place keeps the old creation times (and copies keep the archive's
-- modification times), so an update is dated by the boot that noticed it. Losing this file only loses those update dates. Without file dates, the
-- folders present when the file is first made are the baseline: they were already there,
-- so they are listed as added earlier rather than all at once.
local Json=require('mcs_module_json')
local M={schema=2}

-- Top-level files a mod or its player writes while playing; they never mark an update.
local function generated(name)
    local lower=name:lower()
    return lower=='log_level.txt' or lower:match('%.log$') or lower:match('%.tmp$') or lower:match('%.bak$')
        or (lower:match('%.ini$') and lower~='mod_settings.ini')
end
local RUNTIME={cache=true,logs=true}

-- A file's size in bytes, or nil when it cannot be opened.
function M.size(path)
    local file=io.open(path,'rb')
    if not file then return nil end
    local size=file:seek('end')
    file:close()
    return size
end

local function created(record)
    return type(record)=='table' and tonumber(record.created) or nil
end
local function modified(record)
    return type(record)=='table' and tonumber(record.modified) or nil
end

-- What a folder's top level holds, sorted by name: {name=,size=,created=,modified=} for a
-- file (dates only with file dates), {name=,directory=true} for a folder. folder is a
-- registry folder: {name=,path=,files={relative paths}}. size(path) gives sizes;
-- list(path) (a folder's entries by name, each with created and modified) and stat(path)
-- ({created=,modified=}) give dates, and are optional.
function M.facts(folder,size,stat,list)
    local listed=list and list(folder.path)
    local entries,seen={},{}
    for _,relative in ipairs(folder.files or {}) do
        local top=relative:match('^([^/]+)/')
        if top then
            if not RUNTIME[top:lower()] and not seen[top] then
                seen[top]=true;entries[#entries+1]={name=top,directory=true}
            end
        elseif not generated(relative) then
            local path=folder.path..'/'..relative
            local record=listed and listed[relative]
            if stat and not (created(record) and modified(record)) then record=stat(path) end
            entries[#entries+1]={name=relative,size=size(path),created=created(record),modified=modified(record)}
        end
    end
    table.sort(entries,function(a,b) return a.name<b.name end)
    return entries
end

-- Whether two fact lists hold the same files and folders, with the same sizes.
local function same(a,b)
    if type(a)~='table' or type(b)~='table' or #a~=#b then return false end
    for n,entry in ipairs(a) do
        local other=b[n]
        if type(other)~='table' or other.name~=entry.name or (other.directory==true)~=(entry.directory==true)
            or tonumber(other.size)~=tonumber(entry.size) then return false end
    end
    return true
end

-- When a folder was installed: its newest top-level file's creation time, else the
-- folder's own (stat), else nil.
local function installed(folder,facts,stat)
    local newest
    for _,entry in ipairs(facts) do
        if entry.created and (not newest or entry.created>newest) then newest=entry.created end
    end
    return newest or stat and created(stat(folder.path)) or nil
end

-- options: path (this file), folders (registry folders), now (os.time), read(path),
-- write(path,text), size(path) (optional; Lua's io by default), stat(path) and list(path)
-- (optional file dates), report(what,why) (optional). Returns the folders:
-- name -> {added=<time>, updated=<time>|nil, baseline=true|nil, files={facts}}. baseline
-- means added is only when MCS first looked, not when the folder was installed.
function M.update(options)
    local report=options.report or function() end
    local size,stat,list=options.size or M.size,options.stat,options.list
    local previous,known={},false
    local ok,text=pcall(options.read,options.path)
    if ok and text then
        local decoded,data=pcall(Json.decode,text)
        if decoded and type(data)=='table' and data.schema==M.schema and type(data.folders)=='table' then
            previous,known=data.folders,true
        else report('folder_info.json','unreadable; every folder is read again') end
    elseif not ok then report('folder_info.json',tostring(text)) end
    local folders={}
    for _,folder in ipairs(options.folders) do
        local read,facts=pcall(M.facts,folder,size,stat,list)
        if not read then
            report(folder.name,'file details unavailable: '..tostring(facts))
            facts=M.facts(folder,M.size)
        end
        local dated,time=pcall(installed,folder,facts,stat)
        if not dated then report(folder.name,'file dates unavailable: '..tostring(time));time=nil end
        local before=previous[folder.name]
        local entry={files=facts}
        if type(before)=='table' and type(before.added)=='number' then
            entry.added,entry.baseline=before.added,before.baseline==true or nil
            entry.updated=tonumber(before.updated)
            if not same(before.files,facts) then entry.updated=options.now end
            -- A baseline folder takes its real install date once file dates are available.
            if entry.baseline and time then entry.added,entry.baseline=time,nil end
        else
            entry.added=time or options.now
            entry.baseline=not time and not known or nil
        end
        folders[folder.name]=entry
    end
    local encoded=Json.encode({schema=M.schema,folders=folders})..'\n'
    if encoded~=text then options.write(options.path,encoded) end
    return folders
end

return M

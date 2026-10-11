-- DMM opens a page only when its config file exists and holds every key. Each time a
-- page with stored settings opens, this adds the missing keys with their defaults in one
-- file transaction, then lets DMM open it. DMM still owns pending
-- values, Apply, Reset and Restore.
local M={}
local LIMIT=1048576
local function trim(s) return s:match('^%s*(.-)%s*$') end

M.fs={}
function M.fs.read(path)
    local f,err,code=io.open(path,'rb')
    if not f then
        -- Do not mistake denied access or an I/O error for a missing file.
        if code==2 then return nil end
        error(err or ('cannot read '..path))
    end
    local text,why=f:read(LIMIT+1)
    local closed,closeError=f:close()
    assert(closed,closeError or 'close failed')
    if not text then
        assert(not why,why)
        text=''
    end
    assert(#text<=LIMIT,'config exceeds 1 MiB')
    return text
end
function M.fs.write(path,text)
    local f,err=io.open(path,'wb'); assert(f,err)
    local wrote,why=f:write(text)
    local closed,closeError=f:close()
    assert(wrote and closed,why or closeError or 'write failed')
end
function M.fs.rename(a,b) local ok,err=os.rename(a,b); assert(ok,err) end
function M.fs.remove(path) local ok,err=os.remove(path); assert(ok,err) end

local function configPath(manifest,setting)
    local f=setting.file
    assert(type(f)=='string' and #f>0 and #f<=240,'choice requires ConfigFile')
    f=f:gsub('\\','/')
    assert(not f:find('[:%c<>"|?*]') and not f:match('^/') and not f:match('/$'),'invalid ConfigFile')
    for part in (f..'/'):gmatch('(.-)/') do
        assert(part~='' and part~='.' and part~='..' and not part:match('[ .]$'),'invalid ConfigFile component')
        local stem=part:match('^[^.]+'):upper()
        assert(stem~='CON' and stem~='PRN' and stem~='AUX' and stem~='NUL'
            and not stem:match('^COM[1-9]$') and not stem:match('^LPT[1-9]$'),'reserved ConfigFile component')
    end
    -- Automatic creation is deliberately restricted to INI data, never code.
    assert(f:lower():match('%.ini$') and not f:lower():match('mod_settings%.ini$'),'ConfigFile must name a configuration INI')
    local base=assert(manifest:match('^(.*)[/\\][^/\\]+$'),'provider directory unavailable')
    return base..'/'..f
end

local function validateName(value,label)
    assert(type(value)=='string' and value~='' and value==trim(value)
        and not value:find('[%c%[%]=;#]'), 'invalid '..label)
end
function M.overlay(defaults,existing)
    local merged={}
    for key,value in pairs(defaults) do merged[key]=value end
    for key,value in pairs(existing) do merged[key]=value end
    return merged
end

-- Preserve all original bytes. Insert only absent declared assignments into
-- their section (or the global section for an unqualified missing key).
function M.merge(original,settings,choices)
    local text=original or ''
    assert(not text:find('[%z\1-\8\11\12\14-\31\127]'),'invalid config control character')
    assert(not text:match('^\239\187\191'),'DMM does not support a config BOM')
    local entries,sections={}, {['']={finish=#text+1}}
    local section,offset='',1
    for full in (text..'\n'):gmatch('([^\n]*\n)') do
        local line=full:gsub('\r?\n$','')
        local clean=trim(line)
        if clean~='' and not clean:match('^[;#]') then
            local header=clean:match('^%[([^%]]+)%]$')
            if header then
                header=trim(header);validateName(header,'config section')
                assert(not sections[header],'duplicate config section '..header)
                sections[section].finish=offset
                sections[header]={finish=#text+1};section=header
            else
                local key,value=line:match('^%s*([^=]+)=(.*)$')
                assert(key,'malformed config line')
                key=trim(key);validateName(key,'config key')
                entries[#entries+1]={key=key,section=section,value=trim(value:match('^[^;#]*'))}
            end
        end
        offset=offset+#full
    end
    local defaults,existing,targets,addresses={},{},{},{}
    for _,entry in ipairs(entries) do
        local target=entry.section..'\0'..entry.key
        assert(existing[target]==nil,'duplicate config key '..entry.key)
        existing[target]=entry.value
    end
    for _,setting in ipairs(settings) do
        validateName(setting.key,'ConfigKey')
        if setting.section~=nil then validateName(setting.section,'ConfigSection') end
        assert(choices.index(setting,setting.default),'invalid schema default')
        local found
        for i,entry in ipairs(entries) do
            if entry.key==setting.key and (setting.section==nil or setting.section==entry.section) then
                assert(not found,'duplicate or ambiguous config key '..setting.key)
                found=i
            end
        end
        local targetSection=found and entries[found].section or setting.section or ''
        local target=targetSection..'\0'..setting.key
        assert(not targets[target],'multiple settings target one config key')
        targets[target]=true
        local default=setting.default
        defaults[target]=string.format('%.17g',default)
        addresses[#addresses+1]={target=target,section=targetSection,key=setting.key}
    end
    -- Merge precedence is unconditional. Schema validity is checked separately
    -- by DMM in plan(), never by substituting defaults for user values.
    local merged=M.overlay(defaults,existing)
    local additions,order={},{}
    for _,address in ipairs(addresses) do
        -- Serialization only: existing assignments retain their original bytes.
        if existing[address.target]==nil then
            local targetSection=address.section
            if not additions[targetSection] then additions[targetSection]={};order[#order+1]=targetSection end
            additions[targetSection][#additions[targetSection]+1]=address.key..'='..merged[address.target]
        end
    end
    local newline=text:find('\r\n',1,true) and '\r\n' or '\n'
    local inserts={}
    local tail=''
    for _,name in ipairs(order) do
        local body=table.concat(additions[name],newline)..newline
        if sections[name] then
            local at=sections[name].finish
            if at>1 and text:sub(at-1,at-1)~='\n' then body=newline..body end
            inserts[#inserts+1]={at=at,text=body}
        else
            tail=tail..'['..name..']'..newline..body
        end
    end
    table.sort(inserts,function(a,b) return a.at>b.at end)
    for _,insert in ipairs(inserts) do text=text:sub(1,insert.at-1)..insert.text..text:sub(insert.at) end
    if tail~='' then
        if text~='' and text:sub(-1)~='\n' then text=text..newline end
        text=text..tail
    end
    assert(#text<=LIMIT,'merged config exceeds 1 MiB')
    return text
end

-- A crash during commit can leave this module's transaction files. Each is cleaned
-- up only when it is provably redundant; anything else still blocks for review.
-- output(original) is what this run writes for a given original (nil: no file).
function M.recover(path,fs,output)
    local tmp,backup=path..'.mc-init.tmp',path..'.mc-init.bak'
    local function expected(original)
        local ok,text=pcall(output,original)
        return ok and text or nil
    end
    local current,saved=fs.read(path),fs.read(backup)
    if saved~=nil then
        if current==nil then
            -- Interrupted between moving the original aside and installing the new
            -- file: put the original back, as the transaction's rollback would.
            fs.rename(backup,path);current=saved
        elseif current==saved or current==expected(saved) then
            -- The config is the original, or exactly what merging the original gives.
            fs.remove(backup)
        end
    end
    local staged=fs.read(tmp)
    if staged~=nil and (staged==current or staged==expected(current)) then
        -- Staged but never installed: the same bytes are written again if needed.
        fs.remove(tmp)
    end
end

-- Windows rename refuses an existing destination. Preserve recovery files if
-- rollback cannot safely restore the original; never overwrite a new file.
function M.commit(plan,fs)
    if plan.original==plan.content then return false end
    local path=plan.path
    local tmp,backup=path..'.mc-init.tmp',path..'.mc-init.bak'
    for _,suffix in ipairs({'.mc-init.tmp','.mc-init.bak','.dmm-toggle.tmp','.dmm-toggle.bak'}) do
        assert(fs.read(path..suffix)==nil,'an interrupted config write left '..path..suffix
            ..' and it needs review: compare it with '..path..', keep what you need, then delete it')
    end
    assert(fs.read(path)==plan.original,'config changed before initialization')
    local staged,stageError=pcall(function()
        fs.write(tmp,plan.content)
        assert(fs.read(tmp)==plan.content,'temporary write verification failed')
        assert(fs.read(path)==plan.original,'config changed during initialization')
    end)
    if not staged then
        pcall(fs.remove,tmp)
        error(stageError)
    end
    local moved=false
    local installed,installError=pcall(function()
        if plan.original~=nil then
            fs.rename(path,backup);moved=true
            assert(fs.read(backup)==plan.original,'config changed during replacement')
        end
        assert(fs.read(path)==nil,'config appeared during initialization')
        fs.rename(tmp,path)
    end)
    if not installed then
        if moved then
            local restored,restoreError=pcall(function()
                assert(fs.read(path)==nil,'destination occupied')
                fs.rename(backup,path)
            end)
            if not restored then error(tostring(installError)..'; rollback failed: '..tostring(restoreError)..'; original backup: '..backup) end
        end
        pcall(fs.remove,tmp)
        error(installError)
    end
    if moved then fs.remove(backup) end
    return true
end

function M.plan(provider,manifest,choices,fs,settings)
    settings=settings or choices.parse(manifest:gsub('^\239\187\191',''))
    local persistent={}
    for _,setting in ipairs(settings) do
        if not setting.mcNavigation and not setting.mcReadOnly then persistent[#persistent+1]=setting end
    end
    settings=persistent
    if #settings==0 then return nil end
    local path
    for _,setting in ipairs(settings) do
        local target=configPath(provider.path,setting)
        assert(not path or target==path,'DMM requires one config file per provider')
        path=target
    end
    local function output(original) return M.merge(original,settings,choices) end
    M.recover(path,fs,output)
    local original=fs.read(path)
    local content=output(original)
    -- Validate the result through DMM itself before any filesystem mutation. This is
    -- DMM's live module: its reader is swapped only for this synchronous open.
    local saved=choices.fs
    choices.fs={read=function(requested) assert(requested==path,'unexpected DMM config path');return content end}
    local ok,model=pcall(choices.open,{id=provider.id,path=provider.path,choices=settings})
    choices.fs=saved
    assert(ok,model)
    assert(not model.error,model.error)
    return {path=path,original=original,content=content}
end

-- Runs in DMM's own Lua state. Keep initialization failures on DMM's existing error
-- path, where set/reset/apply are disabled, instead of opening writable defaults.
function M.install(choices,fs)
    if choices.mcConfigVersion then return false end
    fs=fs or M.fs
    local open=choices.open
    local planning=false
    choices.open=function(provider)
        if planning or provider.testOnly or not (provider.choices and provider.choices[1]) then
            return open(provider)
        end
        local ok,err=pcall(function()
            -- Contributed pages carry their manifest in memory; there is no file at provider.path.
            local manifest=assert(provider.mcManifest or fs.read(provider.path),'configuration metadata unavailable')
            planning=true
            local planned,plan=pcall(M.plan,provider,manifest,choices,fs,provider.choices)
            planning=false
            assert(planned,plan)
            if plan then M.commit(plan,fs) end
        end)
        planning=false
        local model=open(provider)
        if not ok then model.error='Configuration initialization failed; settings unavailable: '..tostring(err) end
        return model
    end
    choices.mcConfigVersion=1
    return true
end
return M

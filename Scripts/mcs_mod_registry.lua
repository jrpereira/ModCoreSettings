-- MCS-owned module index: each installed folder's categories come from its mod.json,
-- else data/folder_categories.lua by folder name, else the purpose heuristic. Inspected files are data
-- only and never executed. Nothing is cached between boots; the index is rebuilt.
local Text=require('mcs_text_normalize')
local Json=require('mcs_module_json')
local Io=require('safe_file')
local source=assert(debug.getinfo(1,'S').source,'registry source unavailable'):gsub('^@','')
local scripts=assert(source:match('^(.*)[/\\][^/\\]+$'),'registry directory unavailable')
local Taxonomy=require('mcs_taxonomy').loadLua(scripts..'/../data/module_categories.lua')
local M={OTHER='other',taxonomy=Taxonomy}

function M.normalizeFolderName(name)
    return Text.anchor(assert(name,'module folder unavailable'))
end

function M.loadFolderCategories(path)
    local data=dofile(path or (scripts..'/../data/folder_categories.lua'))
    assert(type(data)=='table' and data.version==Taxonomy.data.version
        and type(data.revision)=='number' and type(data.folders)=='table',
        'invalid folder-category data')
    local folders={}
    for name,categories in pairs(data.folders) do
        assert(type(name)=='string' and name~='' and not name:find('[/\\]'),
            'invalid normalized folder name')
        local normalized=M.normalizeFolderName(name)
        assert(normalized==name,'folder category key is not normalized')
        assert(not folders[normalized],'duplicate normalized folder name')
        assert(type(categories)=='table','invalid folder categories')
        -- Rows are resolved on lookup, so one row the taxonomy rejects affects only its folder.
        folders[normalized]=categories
    end
    data.folders=folders
    return data
end

-- A relative path that stays inside its folder; .bak copies are skipped. Folder names are
-- otherwise never judged by their words: any mod may be called anything.
local function safe(path)
    if type(path)~='string' or path=='' or path:find('[%z\r\n]') then return false end
    path=path:gsub('\\','/')
    if path:match('^/') or path:find(':',1,true) then return false end
    for part in (path..'/'):gmatch('(.-)/') do
        local lower=part:lower()
        if part=='' or part=='.' or part=='..' or lower:match('%.bak$') or lower:find('%.bak%.') then return false end
    end
    return true
end
M.safePath=safe

M.read,M.write=Io.read,Io.write

function M.encode(index)
    return Json.encode(Taxonomy:index(index))..'\n'
end

local function text(value,limit)
    if type(value)=='string' and value~='' and #value<=limit and utf8.len(value)
        and not value:find('%c') then return value end
end

local function manifestOf(folder,read)
    local content=read(folder..'/mod.json')
    if not content then return nil end
    local manifest=Json.decode((content:gsub('^\239\187\191','')))
    assert(type(manifest)=='table','invalid mod.json')
    return manifest
end

-- One folder's entry: its mod.json categories, else folder_categories, else the heuristic.
local function classify(folder,database,read,report)
    local ok,manifest=pcall(manifestOf,folder.path,read)
    if not ok then report(folder.name,tostring(manifest));manifest=nil end
    local function note(message) report(folder.name,message) end
    manifest=manifest or {}
    -- Tags, preferred group and icon are the module's own, whichever step supplies categories.
    local tags,seen={},{}
    for _,id in ipairs(type(manifest.tags)=='table' and manifest.tags or {}) do
        if Taxonomy.tagDefinitions[id] and not seen[id] then seen[id]=true;tags[#tags+1]=id end
    end
    local preferred=manifest.preferred
    if preferred=='author' then preferred=manifest.author end
    local entry={tags=Taxonomy:tags(tags),preferred=text(preferred,120),icon=text(manifest.icon,16)}
    -- The module id other modules key settings with: a plain identifier.
    if manifest.id~=nil then
        if type(manifest.id)=='string' and #manifest.id<=64 and manifest.id:match('^%a[%w_]*$') then entry.id=manifest.id
        else note('mod.json id is not an identifier of at most 64 letters, digits and underscores') end
    end
    if manifest.categories~=nil then
        local declared=Taxonomy:usable(manifest.categories,{author=true,report=note})
        if declared then
            entry.categories,entry.source,entry.confidence=declared,'module','declared'
            entry.reason=declared[1]=='other' and 'specialized' or nil
            return Taxonomy:entry(entry)
        end
        report(folder.name,'mod.json declares no valid categories')
    end
    local listed=database.folders[M.normalizeFolderName(folder.name)]
    if listed then
        local categories=Taxonomy:usable(listed,{report=note})
        if categories then
            entry.categories,entry.source,entry.confidence=categories,'data','reviewed'
            entry.reason=categories[1]=='other' and 'specialized' or nil
            return Taxonomy:entry(entry)
        end
        report(folder.name,'folder_categories entry is not valid in this taxonomy')
    end
    entry.source='auto'
    local scanned,prediction=pcall(require('mcs_module_patterns').scan,folder.path,folder.files,read)
    if not scanned then report(folder.name,tostring(prediction));prediction={} end
    entry.evidence=prediction.evidence
    local guessed=Taxonomy:usable(prediction.categories,{report=note})
    if guessed and guessed[1]~='other' then entry.categories,entry.confidence=guessed,'tentative'
    else
        entry.categories,entry.confidence={'other'},'abstained'
        entry.reason=prediction.reason=='ambiguous' and 'ambiguous' or 'insufficient_evidence'
    end
    return Taxonomy:entry(entry)
end

-- Rebuilds the index on every boot and rewrites the browser handoff only when it changed.
function M.update(options)
    local read,write=options.read or M.read,options.write or M.write
    local database=assert(options.database,'folder-category data is required')
    local report=options.report or function() end
    local index={schema_version=2,taxonomy_version=Taxonomy.data.version,modules={}}
    for _,folder in ipairs(options.folders) do
        if safe(folder.name) and not folder.name:find('[/\\]') then
            local ok,entry=pcall(classify,folder,database,read,report)
            if not ok then
                report(folder.name,tostring(entry))
                entry=Taxonomy:entry({categories={'other'},tags={},source='auto',
                    confidence='abstained',reason='insufficient_evidence'})
            end
            index.modules[folder.name]=entry
        end
    end
    local encoded=M.encode(index)
    local ok,previous=pcall(read,options.path)
    if not ok or previous~=encoded then write(options.path,encoded) end
    return index
end

local function canonical(path) return path:gsub('\\','/'):gsub('/+$',''):lower() end
-- UE4SS supplies a directory snapshot; entries are identified by their immediate folder name.
function M.folders(snapshot,mods)
    local wanted=canonical(mods);local found,visited=nil,0
    local function locate(node,depth)
        if type(node)~='table' or depth>64 then return end
        visited=visited+1;assert(visited<=32768,'directory snapshot traversal limit')
        if type(node.__absolute_path)=='string' then
            local absolute=canonical(node.__absolute_path)
            if absolute==wanted then found=node;return end
            if wanted:sub(1,#absolute+1)~=absolute..'/' then return end
        end
        for name,child in pairs(node) do
            if not found and type(name)=='string' and name:sub(1,2)~='__' and safe(name) then locate(child,depth+1) end
        end
    end
    locate(snapshot,0);assert(found,'active Mods directory missing from snapshot')
    local folders={}
    for name,node in pairs(found) do
        if type(name)=='string' and name:sub(1,2)~='__' and safe(name) and type(node)=='table' then
            local root=mods..'/'..name
            -- Only active modules: UE4SS starts a folder that holds enabled.txt.
            local enabled=false
            for _,file in pairs(node.__files or {}) do
                if type(file)=='table' and type(file.__name)=='string' and file.__name:lower()=='enabled.txt' then
                    enabled=true
                end
            end
            local files={};local count=0
            local function collect(current,prefix,depth)
                assert(depth<=64,'module directory depth limit')
                for _,file in pairs(current.__files or {}) do
                    if type(file)=='table' and type(file.__name)=='string' then
                        local relative=prefix..file.__name
                        if safe(relative) then files[#files+1]=relative end
                    end
                end
                for key,child in pairs(current) do
                    if type(key)=='string' and key:sub(1,2)~='__' and safe(key) and type(child)=='table' then
                        count=count+1;assert(count<=32768,'module directory traversal limit')
                        collect(child,prefix..key..'/',depth+1)
                    end
                end
            end
            if enabled then collect(node,'',0) end
            if #files>0 and (node.Scripts or node.scripts or node.dlls) then
                table.sort(files);folders[#folders+1]={name=name,path=root,files=files}
            else
                for _,file in ipairs(files) do
                    if file:lower()=='mod.json' then
                        folders[#folders+1]={name=name,path=root,files=files};break
                    end
                end
            end
        end
    end
    table.sort(folders,function(a,b) return a.name<b.name end)
    return folders
end

M.mkdir=Io.mkdir
-- Module ids are shared with other Lua states as SetSharedVariable(MODULE_ID..folder, id),
-- folder as installed, then MODULE_ID..'ready' set to '1' once all are published.
M.MODULE_ID='MCS_ModuleId_v1.'
-- Each folder's module id from an index; an id two folders declare goes to neither.
function M.moduleIds(index,report)
    local byId,ids={},{}
    for folder,entry in pairs(index.modules) do
        if entry.id then byId[entry.id]=byId[entry.id] or {};table.insert(byId[entry.id],folder) end
    end
    for id,folders in pairs(byId) do
        if #folders==1 then ids[folders[1]]=id
        elseif report then
            table.sort(folders)
            for _,folder in ipairs(folders) do report(folder,'module id '..id..' is declared by '..table.concat(folders,', ')) end
        end
    end
    return ids
end
-- Publishes every folder's module id, then the ready flag.
function M.publishModuleIds(index,set,report)
    for folder,id in pairs(M.moduleIds(index,report)) do set(M.MODULE_ID..folder,id) end
    set(M.MODULE_ID..'ready','1')
end

function M.boot(root,mods,iterator,options)
    options=options or {}
    assert(type(root)=='string' and root~='','MCS root unavailable')
    assert(type(iterator)=='function','IterateGameDirectories unavailable')
    local cache=root:gsub('[/\\]+$','')..'/cache'
    -- options.files (mcs_files, optional): the file bridge, for atomic writes and file dates.
    local files=options.files
    ;(options.mkdir or files and files.mkdir or Io.mkdir)(cache)
    local folders=M.folders(iterator(),mods)
    local read,write=options.read or M.read,options.write or files and files.write or M.write
    local index=M.update({path=cache..'/modules_register.json',folders=folders,read=read,write=write,
        database=options.database or M.loadFolderCategories(),report=options.report})
    -- Each folder's top level and when it was added, for the browser's Recently added list.
    -- Never blocks the index.
    local seen,why=pcall(require('mcs_folder_info').update,{path=cache..'/folder_info.json',
        folders=folders,now=options.now or os.time(),read=files and files.read or read,write=write,
        size=options.size or files and files.size,stat=files and files.stat,list=files and files.list,
        report=options.report})
    if not seen and options.report then options.report('folder_info.json',tostring(why)) end
    return index
end

return M

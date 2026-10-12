-- DMM's state reads the MCS-owned file index; no category shared variables.
local M={}
function M.preferences(text)
    local result={groupModules=true,preferredMinimum=2,arrangement=1}
    local Ini=require('mc_ini')
    for _,entry in ipairs(Ini.entries(Ini.parse(text or ''),'Modules')) do
        local key,value=entry.key,tonumber(entry.value:match('^%d+$'))
        -- 1 by category, 0 alphabetically, 2 by when each mod was added, 3 in load order.
        if key=='SortBy' and (value==0 or value==1 or value==2 or value==3) then
            result.arrangement=value;result.groupModules=value==1
            result.recentlyAdded=value==2 or nil;result.loadOrder=value==3 or nil
        end
        if key=='SingleCategory' and (value==0 or value==1) then result.singleCategory=value==1 or nil end
        if key=='PreferredCategoryMinimum' and (value==0 or value==2 or value==3) then result.preferredMinimum=value end
        if key=='ModulesPerRow' and (value==1 or value==2 or value==3) then result.columns=value end
    end
    return result
end
function M.reader(indexPath,configPath,read,dependencies)
    dependencies=dependencies or {}
    local json=dependencies.json or require('mcs_module_json')
    read=read or require('safe_file').read
    local taxonomy=dependencies.taxonomy
    if not taxonomy then
        local source=assert(debug.getinfo(1,'S').source,'module category source unavailable'):gsub('^@','')
        local scripts=assert(source:match('^(.*)[/\\][^/\\]+$'),'module category directory unavailable')
        taxonomy=require('mcs_taxonomy').loadLua(scripts..'/../data/module_categories.lua')
    end
    local previous,index,lastError
    return function()
        local options=M.preferences(read(configPath))
        local ok,text=pcall(read,indexPath)
        if ok and text and text~=previous then
            local decoded,value=pcall(function() return taxonomy:index(json.decode(text)) end)
            if decoded then index=value;previous=text;lastError=nil
            else ok=false;text=value end
        end
        if not ok and text~=lastError then
            lastError=text
            if dependencies.report then dependencies.report('MODULE_INDEX_UNAVAILABLE',tostring(text)) end
        end
        -- Keep the last valid snapshot while a replacement is missing or invalid.
        options.categoryRegister=index and index.modules or {}
        options.categoryDescriptions=taxonomy.descriptions
        options.taxonomy=taxonomy
        -- When each folder was added (cache/folder_info.json), only for the Recently added list.
        if options.recentlyAdded then
            options.recentlyAdded=nil
            local found,seen=pcall(read,dependencies.seenPath)
            local decoded,data=pcall(json.decode,found and seen or '')
            options.recent=decoded and type(data)=='table' and type(data.folders)=='table' and data.folders or {}
        end
        return options
    end
end
return M

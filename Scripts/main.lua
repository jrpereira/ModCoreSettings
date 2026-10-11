local VERSION='1.1.0'
local source=debug.getinfo(1,'S').source:gsub('^@','')
-- Files shared with other modules, unchanged, keep their own module names. Searched first,
-- so a copy left in Scripts by an earlier release is never loaded instead.
local scripts=source:match('^(.*)[/\\][^/\\]+$')
if scripts then package.path=scripts..'/vendor/?.lua;'..scripts..'/?.lua;'..package.path end
local Bootstrap=require('dmm_bootstrap')
-- The level comes from log_level.txt in the mod folder; WARN without it.
local root=source:match('^(.*)[/\\]Scripts[/\\][^/\\]+$')
local logger=require('mc_log').new({name='ModCoreSettings',path=root and root..'/log_level.txt'})
local log=require('log_events').reporter(logger)
local initialized=false
local function initialize()
    if initialized then return true end
    local Binding=require('dmm_binding')
    local ok,err=Binding.install(log)
    if not ok then log('DMM_BINDING_UNAVAILABLE',tostring(err));return false end
    initialized=true
    logger.info(VERSION,' ready')
    return true
end
-- UE4SSLuaFileBridge, when installed: atomic writes, file dates and a record outside the
-- mod folder. Without it MCS uses Lua's io, as before.
local files=require('mcs_files').open(function(_,why) log('FILE_BRIDGE_UNAVAILABLE',why) end)
-- Identify installed folders in MCS's state before DMM builds its module browser.
local mods=root and root:match('^(.*)[/\\][^/\\]+$')
local scanned,scanError=pcall(function()
    require('mcs_mod_registry').boot(root,mods,IterateGameDirectories,{files=files,
        report=function(folder,why) log('MODULE_IDENTIFICATION_SKIPPED',folder..': '..why) end,
    })
end)
if not scanned then log('MODULE_IDENTIFICATION_FAILED',tostring(scanError)) end
-- MCS's own page is contributed like any module's. Attached to this folder, the browser
-- names it from mod.json; the name here shows only if mod.json is unreadable.
local published,publishError=pcall(function()
    local cache=assert(root,'MCS root unavailable')..'/cache'
    ;(files and files.mkdir or require('mcs_mod_registry').mkdir)(cache)
    require('menu_contributions').publisher(assert(rawget(_G,'ModRef'),'ModRef unavailable'),
        {id='ModCoreSettings',directory=cache}):publish({pages={{id='ModCoreSettings',
        name='ModCore Settings',version=VERSION,attach=root:match('([^/\\]+)$'),configDirectory=root,
        menu=require('mcs_page')}}})
end)
if not published then log('SETTINGS_PAGE_UNAVAILABLE',tostring(publishError)) end
Bootstrap.run(log,initialize)

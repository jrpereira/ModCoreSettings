local source=debug.getinfo(1,'S').source:gsub('^@','')
-- Files shared with other modules, unchanged, keep their own module names. Searched first,
-- so a copy left in Scripts by an earlier release is never loaded instead.
local scripts=source:match('^(.*)[/\\][^/\\]+$')
if scripts then package.path=scripts..'/vendor/?.lua;'..scripts..'/?.lua;'..package.path end
-- The release version is the VERSION file at the mod root, as in every ModCore module.
local VERSION=(function()
    local file=io.open((scripts or '.')..'/../VERSION','rb')
    local value=file and file:read('a'):match('^%s*(%d+%.%d+%.%d+[%w.-]*)%s*$')
    if file then file:close() end
    return value
end)()
local Bootstrap=require('dmm_bootstrap')
-- The level comes from log_level.txt in the mod folder; WARN without it.
local root=source:match('^(.*)[/\\]Scripts[/\\][^/\\]+$')
local logger=require('mc_log').new({name='ModCoreSettings',path=root and root..'/log_level.txt'})
local log=require('log_events').reporter(logger)
local initialized=false
local function initialize()
    if initialized then return true end
    initialized=true
    logger.info(VERSION or 'unversioned',' ready')
    return true
end
-- UE4SSLuaFileBridge, when installed: atomic writes, file dates and a record outside the
-- mod folder. Without it MCS uses Lua's io, as before.
local files=require('mcs_files').open(function(_,why) log('FILE_BRIDGE_UNAVAILABLE',why) end)
-- Identify installed folders in MCS's state before DMM builds its module browser.
local mods=root and root:match('^(.*)[/\\][^/\\]+$')
-- Each folder's module id is shared for other modules' states (ModCoreTemplates reads them
-- when the bridge loop starts); a failed scan leaves the ready flag unset.
local scanned,scanError=pcall(function()
    local Registry=require('mcs_mod_registry')
    local function report(folder,why) log('MODULE_IDENTIFICATION_SKIPPED',folder..': '..why) end
    local index=Registry.boot(root,mods,IterateGameDirectories,{files=files,report=report})
    Registry.publishModuleIds(index,function(key,value)
        assert(rawget(_G,'ModRef'),'ModRef unavailable'):SetSharedVariable(key,value)
    end,report)
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
-- Config reload: MC_ConfigReload_v1 from any state is fanned out here to every module that
-- subscribed (settings_api onReload). A trigger at the main menu waits for a player.
local reloading,reloadError=pcall(function()
    local Reload=require('config_reload')
    local ref=assert(rawget(_G,'ModRef'),'ModRef unavailable')
    local controller
    local function viewport()
        if not (controller and controller:IsValid()) then controller=FindFirstOf('PlayerController') end
        local pc=controller and controller:IsValid() and controller or nil
        local client=pc and pc.Player and pc.Player:IsValid() and pc.Player.ViewportClient
        return client and client:IsValid() and client or nil,pc
    end
    local hub=Reload.hub({shared=ref,report=log,
        ready=function() return viewport()~=nil end,
        exec=function(command)
            local client,pc=viewport()
            return client~=nil and client:ProcessConsoleExec(command,nil,pc)==true
        end})
    Reload.listen(hub,RegisterConsoleCommandHandler,ref,log)
    -- A trigger kept at the main menu goes out once a player's pawn is set up.
    pcall(RegisterHook,'/Script/Engine.PlayerController:ClientRestart',function()
        local ok,why=pcall(hub.flush,hub)
        if not ok then log('RELOAD_FAILED',tostring(why)) end
    end)
    -- The game window regaining focus: the Event Bridge's event, when it is installed.
    local subscribed,why=pcall(require('config_reload_focus').subscribe,function()
        local ok,err=pcall(hub.trigger,hub,'focus')
        if not ok then log('RELOAD_FAILED',tostring(err)) end
    end)
    if not subscribed then log('RELOAD_FOCUS_UNAVAILABLE',tostring(why)) end
end)
if not reloading then log('RELOAD_UNAVAILABLE',tostring(reloadError)) end
Bootstrap.run(log,initialize)

-- DawnwalkerModMenu integration bootstrap.
-- DMM is never edited. Its own main.lua is kept as main.dmm.lua and replaced by a
-- small launcher that lets ModCoreSettings hook DMM's modules from inside DMM's
-- Lua state, then always runs DMM's own main. This file installs and maintains
-- that launcher and waits for the hooks' readiness handshake.
local M={version=2}

local READY='MC_DMM_Extension_v1.ready'
-- The launcher stores why DMM's hooks failed, so the failure is reported as itself.
local FAILURE='MC_DMM_Extension_v1.error'
local CLAIM='MC_DMM_Bootstrap_v1.initialized'
local MARK='-- ModCoreSettings DMM launcher'
local FORMAT=3
local ORIGINAL='main.dmm.lua'
local STAGE='main.lua.mcs-new'
local MAX_FILE=262144

-- Splits a path into its folder names.
local function components(path)
    local parts={}
    for part in path:gmatch('[^/\\]+') do parts[#parts+1]=part end
    return parts
end

-- Path of `to` as seen from the directory `from`, or nil when they share no root
-- (another drive). Both end in a separator.
local function relative(from,to)
    local a,b=components(from),components(to)
    local shared=0
    while shared<#a and shared<#b and a[shared+1]:lower()==b[shared+1]:lower() do shared=shared+1 end
    if shared==0 then return nil end
    local out={}
    for _=shared+1,#a do out[#out+1]='..' end
    for i=shared+1,#b do out[#out+1]=b[i] end
    return table.concat(out,'/')..(#out>0 and '/' or '')
end

-- The launcher holds no logic of its own: updating ModCoreSettings never needs to
-- touch DMM's folder unless the folder layout or this format changes. Paths are
-- relative to the launcher's own folder, so moving the game or Mods folder keeps
-- it valid; a layout on another drive falls back to absolute paths.
local function launcher(dmmScripts,mcsScripts)
    local root=assert(mcsScripts:match('^(.*[/\\])[^/\\]+[/\\]$'),'ModCoreSettings folder unavailable')
    local toScripts,toRoot=relative(dmmScripts,mcsScripts),relative(dmmScripts,root)
    local lines={
        '-- Shoutout to DMM\'s author, this launcher allows us to extend DMM with additional',
        '-- types (like key editor), while establishing it as a required module, thus preserving',
        '-- and respecting the integrity of DMM as an independent module.',
        '--',
        '-- Thanks for all the hard work! :D',
        '--',
        MARK..' '..FORMAT,
        "-- Written by ModCoreSettings. DawnwalkerModMenu's own main.lua is "..ORIGINAL..'. It always',
        '-- runs below; ModCoreSettings only hooks in first while it is installed and enabled.',
    }
    local function add(text) lines[#lines+1]=text end
    local function path(relativePath,absolutePath,name)
        if relativePath then return 'here..'..string.format('%q',relativePath..name) end
        return string.format('%q',absolutePath..name)
    end
    add("local here=debug.getinfo(1,'S').source:match('^@?(.*[/\\\\])[^/\\\\]+$') or ''")
    add('local enabled=io.open('..path(toRoot,root,'enabled.txt')..",'rb')")
    add('if enabled then')
    add('    enabled:close()')
    add('    local ok,err=pcall(function()')
    add('        local chunk=assert(loadfile('..path(toScripts,mcsScripts,'dmm_extension.lua')..'))')
    add('        chunk().launch()')
    add('    end)')
    add('    if not ok then')
    add("        print('[ModCoreSettings] DMM hooks failed: '..tostring(err)..'\\n')")
    add("        pcall(function() ModRef:SetSharedVariable("..string.format('%q',FAILURE)..',tostring(err)) end)')
    add('    end')
    add('end')
    add('dofile(here..'..string.format('%q',ORIGINAL)..')')
    add('')
    return table.concat(lines,'\n')
end

-- DMM's Scripts folder sits beside this mod's under Mods: derived from this mod's own
-- Scripts path, so no directory snapshot is needed. Present when its main.lua, or its own
-- main kept aside by an interrupted install, can be read.
local function locate(env)
    local mods,sep=env.scripts:match('^(.*[/\\])[^/\\]+[/\\][^/\\]+([/\\])$')
    if not mods then return nil,'ModCoreSettings is not in a Mods folder' end
    local directory=mods..'DawnwalkerModMenu'..sep..'Scripts'..sep
    if env.read(directory..'main.lua')==nil and env.read(directory..ORIGINAL)==nil then
        return nil,'DawnwalkerModMenu is not installed'
    end
    return directory
end

-- Returns 'current', 'updated' or 'installed'. Any other outcome raises, leaving
-- DMM's own main.lua runnable as main.lua.
local function install(env,dmmScripts,mcsScripts)
    local main,original,stage=dmmScripts..'main.lua',dmmScripts..ORIGINAL,dmmScripts..STAGE
    local desired=launcher(dmmScripts,mcsScripts)
    if env.read(stage)~=nil then env.remove(stage) end
    local current=env.read(main)
    if current==nil then
        -- An interrupted install moved DMM's main aside; put it back first.
        assert(env.read(original)~=nil,'DawnwalkerModMenu main.lua is missing; reinstall DawnwalkerModMenu')
        assert(env.rename(original,main),'could not restore DawnwalkerModMenu main.lua')
        current=assert(env.read(main),'DawnwalkerModMenu main.lua unreadable')
    end
    local function staged()
        assert(env.write(stage,desired),'could not write the launcher')
        assert(env.read(stage)==desired,'launcher verification failed')
    end
    if current:find(MARK,1,true) and current:find(MARK,1,true)<=512 then
        assert(env.read(original)~=nil,"DawnwalkerModMenu's own main ("..ORIGINAL..') is missing; reinstall DawnwalkerModMenu')
        if current==desired then return 'current' end
        staged()
        assert(env.remove(main),'could not replace the launcher')
        assert(env.rename(stage,main),'could not install the launcher')
        assert(env.read(main)==desired,'launcher verification failed')
        return 'updated'
    end
    -- main.lua is DMM's own, freshly installed or put back by a DMM update.
    staged()
    if env.read(original)~=nil then assert(env.remove(original),'could not replace the previous '..ORIGINAL) end
    assert(env.rename(main,original),'could not keep DawnwalkerModMenu main.lua as '..ORIGINAL)
    local promoted,why=pcall(function()
        assert(env.rename(stage,main),'could not install the launcher')
        assert(env.read(main)==desired,'launcher verification failed')
    end)
    if not promoted then
        env.remove(main)
        local restored=env.rename(original,main)
        env.remove(stage)
        error(tostring(why)..(restored and '; DawnwalkerModMenu main.lua restored'
            or '; restoring DawnwalkerModMenu main.lua failed, rename '..ORIGINAL..' to main.lua'))
    end
    return 'installed'
end

function M.run(log,initialize,overrides)
    assert(type(log)=='function' and type(initialize)=='function','bootstrap callbacks unavailable')
    local env=overrides or runtime()
    local finished=false
    local owner=tostring({}):gsub('%W','')
    local function ready()
        if finished or env.get(READY)~='1' then return false end
        if env.get(CLAIM) then log('DMM_DUPLICATE_INIT','another ModCoreSettings instance already initialized');finished=true;return false end
        env.set(CLAIM,owner)
        local ok,result=pcall(initialize)
        if not ok or result==false then
            if env.get(CLAIM)==owner then env.set(CLAIM,nil) end
            log('DMM_INITIALIZATION_FAILED',tostring(ok and 'initializer rejected readiness' or result))
            finished=true;return false
        end
        finished=true;return true
    end

    if not env.scripts then log('DMM_LAUNCHER_FAILED','ModCoreSettings Scripts directory unavailable');return false end
    local located,directory,locateError=pcall(locate,env)
    if not located or not directory then log('DMM_REQUIRED',tostring(located and locateError or directory));return false end
    local installed,state=pcall(install,env,directory,env.scripts)
    if not installed then log('DMM_LAUNCHER_FAILED',tostring(state));return false end
    local changed=state~='current'
    if changed then log('DMM_LAUNCHER_INSTALLED','DawnwalkerModMenu launcher '..state) end
    if type(env.defer)~='function' then
        log(changed and 'DMM_RESTART_REQUIRED' or 'DMM_HANDSHAKE_FAILED','restart the game to load the DMM hooks')
        return false
    end
    -- DMM may start before or after ModCoreSettings. Its hooks announce readiness
    -- synchronously, so by the first game-thread callback they have run or will not.
    local scheduled,why=pcall(env.defer,function()
        if finished or ready() then return end
        finished=true
        -- Hooks that ran and failed need a fix, not a restart.
        local failure=env.get(FAILURE)
        if failure~=nil then log('DMM_HOOKS_FAILED',tostring(failure));return end
        log(changed and 'DMM_RESTART_REQUIRED' or 'DMM_HANDSHAKE_FAILED','restart the game to load the DMM hooks')
    end)
    if not scheduled or why==false then
        log('DMM_HANDSHAKE_FAILED',tostring(scheduled and 'game-thread dispatch rejected' or why))
        return false
    end
    return 'waiting'
end

M._test={launcher=launcher,install=install,original=ORIGINAL,stage=STAGE,mark=MARK,readyKey=READY,claimKey=CLAIM,failureKey=FAILURE}
return M

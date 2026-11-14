local Bootstrap=assert(loadfile('Scripts/dmm_bootstrap.lua'))()
local test=Bootstrap._test
local DMM='C:/Mods/DawnwalkerModMenu/Scripts/'
local MCS='C:/Mods/1_ModCore_Settings/Scripts/'
local MAIN,ORIGINAL,STAGE=DMM..'main.lua',DMM..test.original,DMM..test.stage

local function environment(seed,options)
    options=options or {}
    local files,shared,scheduled,writes={},{},{},0
    for path,value in pairs(seed or {}) do files[path]=value end
    local env={scripts=options.scripts or MCS}
    -- No directory snapshot: DMM's folder is derived from this mod's Scripts path.
    env.directories=function() error('no game directory scan') end
    env.read=function(path) return files[path] end
    env.write=function(path,value) writes=writes+1;files[path]=value;return true end
    env.remove=function(path) files[path]=nil;return true end
    env.rename=function(source,target)
        if options.failRename==source..'>'..target then return nil,'injected rename failure' end
        if files[source]==nil or files[target]~=nil then return nil,'rename rejected' end
        files[target]=files[source];files[source]=nil;return true
    end
    env.get=function(key) return shared[key] end
    env.set=function(key,value) shared[key]=value end
    env.defer=function(callback) scheduled[#scheduled+1]=callback end
    return env,files,shared,scheduled,function() return writes end
end
local function recorder()
    local events={}
    return events,function(event,detail) events[#events+1]=event..':'..tostring(detail) end
end
local function has(events,prefix)
    for _,entry in ipairs(events) do if entry:sub(1,#prefix)==prefix then return entry end end
end

-- A fresh DMM: its main is kept as main.dmm.lua and the launcher takes main.lua.
local env,files,shared,scheduled=environment({[MAIN]='dmm main'})
local events,log=recorder()
local initialized=0
assert(Bootstrap.run(log,function() initialized=initialized+1 end,env)=='waiting')
assert(files[ORIGINAL]=='dmm main' and files[MAIN]==test.launcher(DMM,MCS) and files[STAGE]==nil)
assert(has(events,'DMM_LAUNCHER_INSTALLED:DawnwalkerModMenu launcher installed'))
-- DMM already started this boot with its own main, so the hooks are not there yet.
scheduled[1]()
assert(initialized==0 and has(events,'DMM_RESTART_REQUIRED'))
print('PASS a fresh DMM gets the launcher and asks for a restart when DMM already started')

-- Next boot: the launcher is current, nothing is written, and the hooks report ready.
local writes
env,files,shared,scheduled,writes=environment({[MAIN]=test.launcher(DMM,MCS),[ORIGINAL]='dmm main'})
events,log=recorder()
assert(Bootstrap.run(log,function() initialized=initialized+1 end,env)=='waiting')
assert(writes()==0 and not has(events,'DMM_LAUNCHER_INSTALLED'))
shared[test.readyKey]='1'
scheduled[1]()
assert(initialized==1 and shared[test.claimKey] and #events==0)
print('PASS a current launcher is left alone and the hooks complete the handshake')

-- When ModCoreSettings starts first, DMM loads the new launcher in the same boot.
env,files,shared,scheduled=environment({[MAIN]='dmm main'})
events,log=recorder()
assert(Bootstrap.run(log,function() initialized=initialized+1 end,env)=='waiting')
shared[test.readyKey]='1'
scheduled[1]()
assert(initialized==2 and not has(events,'DMM_RESTART_REQUIRED'))
print('PASS installing before DMM starts needs no restart')

-- Hooks that ran and failed are reported as that failure, not as a restart.
env,files,shared,scheduled=environment({[MAIN]=test.launcher(DMM,MCS),[ORIGINAL]='dmm main'})
events,log=recorder()
assert(Bootstrap.run(log,function() initialized=initialized+1 end,env)=='waiting')
shared[test.failureKey]='broken hooks'
scheduled[1]()
assert(initialized==2 and has(events,'DMM_HOOKS_FAILED:broken hooks')
    and not has(events,'DMM_RESTART_REQUIRED') and not has(events,'DMM_HANDSHAKE_FAILED'))
print('PASS failed hooks are reported with their cause instead of asking for a restart')

-- A DMM update puts its new main back; the previous copy of its main is replaced.
env,files=environment({[MAIN]='dmm main 2',[ORIGINAL]='dmm main'})
assert(test.install(env,DMM,MCS)=='installed' and files[ORIGINAL]=='dmm main 2' and files[MAIN]==test.launcher(DMM,MCS))
print('PASS a DMM update is picked up and its new main is kept')

-- A moved ModCoreSettings rewrites only the launcher.
env,files=environment({[MAIN]=test.launcher(DMM,MCS),[ORIGINAL]='dmm main'})
local moved='D:/Other/1_ModCore_Settings/Scripts/'
assert(test.install(env,DMM,moved)=='updated' and files[MAIN]==test.launcher(DMM,moved) and files[ORIGINAL]=='dmm main')
print('PASS a changed path rewrites the launcher and keeps DMM main')

-- An interrupted install that left main.lua missing restores DMM's main first.
env,files=environment({[ORIGINAL]='dmm main',[STAGE]='partial'})
assert(test.install(env,DMM,MCS)=='installed' and files[ORIGINAL]=='dmm main' and files[MAIN]==test.launcher(DMM,MCS)
    and files[STAGE]==nil)
print('PASS an interrupted install is recovered')

-- Failing to promote the launcher puts DMM's own main back as main.lua.
env,files=environment({[MAIN]='dmm main'},{failRename=STAGE..'>'..MAIN})
local ok,err=pcall(test.install,env,DMM,MCS)
assert(not ok and tostring(err):find('restored',1,true) and files[MAIN]=='dmm main' and files[ORIGINAL]==nil and files[STAGE]==nil)
print('PASS a failed install leaves DMM runnable')

-- A launcher without DMM's main is reported and nothing is changed.
env,files=environment({[MAIN]=test.launcher(DMM,MCS)})
events,log=recorder()
assert(Bootstrap.run(log,function() end,env)==false and has(events,'DMM_LAUNCHER_FAILED') and files[MAIN]==test.launcher(DMM,MCS))
-- Without DMM there is nothing to do.
env,files=environment({['C:/Mods/Other/Scripts/main.lua']='x'})
events,log=recorder()
assert(Bootstrap.run(log,function() end,env)==false and has(events,'DMM_REQUIRED:DawnwalkerModMenu is not installed'))
assert(next(files)=='C:/Mods/Other/Scripts/main.lua' and next(files,next(files))==nil,'nothing is written')
-- DMM's folder sits beside this mod's, whatever separator the path uses.
env,files=environment({['C:\\Mods\\DawnwalkerModMenu\\Scripts\\main.lua']='dmm main'},{scripts='C:\\Mods\\1_ModCore_Settings\\Scripts\\'})
events,log=recorder()
assert(Bootstrap.run(log,function() end,env)=='waiting'
    and files['C:\\Mods\\DawnwalkerModMenu\\Scripts\\main.dmm.lua']=='dmm main','a backslash path finds DMM too')
print('PASS missing DMM files are reported without changes')

-- The launcher itself: hooks run only while ModCoreSettings is enabled, and
-- DMM's own main always runs, even when the hooks fail.
local function launch(enabled,hooks)
    local calls,printed={},{}
    local sandbox={
        io={open=function(path) calls[#calls+1]='open '..path;return enabled and {close=function() end} or nil end},
        loadfile=function(path) calls[#calls+1]='load '..path;return function() return hooks end end,
        dofile=function(path) calls[#calls+1]='run '..path end,
        pcall=pcall,assert=assert,tostring=tostring,debug=debug,
        print=function(text) printed[#printed+1]=text end,
        ModRef={SetSharedVariable=function(_,key,value) shared[key]=value end},
    }
    assert(load(test.launcher(DMM,MCS),'@'..DMM..'main.lua','t',sandbox))()
    return calls,printed
end
local launched=0
local calls=launch(true,{launch=function() launched=launched+1 end})
-- Paths are relative to the launcher's own folder, so the Mods folder can move.
assert(launched==1 and calls[1]=='open '..DMM..'../../1_ModCore_Settings/enabled.txt'
    and calls[2]=='load '..DMM..'../../1_ModCore_Settings/Scripts/dmm_extension.lua' and calls[3]=='run '..ORIGINAL)
calls=launch(false,{launch=function() launched=launched+1 end})
assert(launched==1 and #calls==2 and calls[2]=='run '..ORIGINAL)
local printed
calls,printed=launch(true,{launch=function() error('broken hooks') end})
assert(calls[#calls]=='run '..ORIGINAL and printed[1]:find('DMM hooks failed',1,true))
assert(tostring(shared[test.failureKey]):find('broken hooks',1,true),'the launcher hands its failure to the bootstrap')
local text=test.launcher(DMM,MCS)
assert(text:find('Shoutout to DMM',1,true)==4 and text:find(test.mark,1,true)<512 and not text:find('C:/Mods',1,true))
assert(test.launcher('C:/Mods/DawnwalkerModMenu/Scripts/','D:/Other/1_ModCore_Settings/Scripts/'):find('"D:/Other/1_ModCore_Settings/enabled.txt"',1,true))
print('PASS the launcher hooks in only while enabled and always runs DMM main')

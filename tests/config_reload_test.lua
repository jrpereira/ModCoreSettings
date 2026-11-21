package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- Config reload: one trigger fans out to every subscriber; button presses are never merged,
-- automatic triggers within a second are; no player is needed, only the game's viewport.
local Reload=require('config_reload')
local vars,ran={},{}
local shared={GetSharedVariable=function(_,k) return vars[k] end,SetSharedVariable=function(_,k,v) vars[k]=v end}
local clock,viewport=1000,false
local reports={}
local hub=Reload.hub({shared=shared,now=function() return clock end,ready=function() return viewport end,
    exec=function(command) ran[#ran+1]=command..' '..vars[command..'.data'];return true end,
    report=function(e,d) reports[#reports+1]=e..' '..d end})
assert(vars[Reload.LAST]=='1000','the start counts as the last load')

-- Subscribers through the vendored settings_api, as other modules call it.
local handlers={}
_G.ModRef=shared
_G.RegisterConsoleCommandHandler=function(name,callback) handlers[name]=callback;return true end
local Api=require('settings_api')
local got={}
local stopLogs=Api.onReload('UE4SSLuaEXtensions.Logs',function(event) got[#got+1]='logs '..event.reason..' '..event.revision end)
Api.onReload('ModCoreControls',function(event) got[#got+1]='controls '..event.reason end)
assert(#Reload.subscribers(vars[Reload.INDEX])==2,'dotted ids subscribe')
assert(not Api.reloadReady(),'not ready before ModCoreSettings listens')
-- Fan-out runs each subscriber's command; this test's exec calls the handler directly.
local function deliver()
    for _,line in ipairs(ran) do handlers[line:match('^(%S+)')]() end
    ran={}
end

-- Before the game's viewport exists (very early startup) a trigger is dropped, logged once.
assert(hub:trigger('focus')=='dropped' and hub:trigger('button')=='dropped' and #ran==0)
assert(#reports==1 and reports[1]:find('RELOAD_DROPPED',1,true),reports[1])
reports={}
-- With it, at the main menu or in game, every subscriber reloads.
viewport=true
assert(hub:trigger('button')=='sent' and #ran==2);deliver()
assert(got[1]=='logs button 1' and got[2]=='controls button','one fan-out to each subscriber')
-- Automatic triggers within a second of the last fan-out merge; presses never do.
clock=1000.5
assert(hub:trigger('focus')=='merged' and #ran==0)
assert(hub:trigger('button')=='sent' and #ran==2);deliver()
clock=1002
assert(hub:trigger('focus','UE4SSLuaEXtensions.Logs')=='sent' and #ran==1,'the source is skipped')
deliver()
assert(got[#got]=='controls focus' and vars[Reload.LAST]=='1002')
-- A subscriber that left gets nothing; a stale or repeated payload is ignored.
stopLogs()
assert(#Reload.subscribers(vars[Reload.INDEX])==1)
clock=1010;hub:trigger('button');assert(#ran==1);deliver()
local count=#got
handlers[Reload.command('ModCoreControls')]()
assert(#got==count,'a repeated revision is not delivered twice')
-- A subscriber whose command is not handled is reported once.
local failing=Reload.hub({shared=shared,now=function() return 5000 end,exec=function() return false end,
    report=function(e,d) reports[#reports+1]=e..' '..d end})
failing:trigger('button');failing:trigger('button')
assert(#reports==1 and reports[1]:find('RELOAD_FAILED',1,true),reports[1])
-- The trigger command: reason and source from its parameters; ready once listening.
local listened={}
Reload.listen(hub,function(name,callback) listened[name]=callback end,shared)
assert(vars[Reload.READY]=='1' and Api.reloadReady())
clock=2000
listened.MC_ConfigReload_v1('MC_ConfigReload_v1 button',{'button'})
assert(#ran==1);deliver()
assert(vars[Reload.LAST]=='2000')
-- Through the viewport, which is its own executor: UE4SS refuses a nil one.
local execCalls={}
local view={ProcessConsoleExec=function(self,command,reserved,executor)
    execCalls[#execCalls+1]={command,reserved,executor,self};return true end}
local exec=Reload.viewportExec(function() return view end)
assert(exec('X')==true and execCalls[1][1]=='X' and execCalls[1][2]==nil and execCalls[1][3]==view,
    'the viewport executes as its own executor')
assert(Reload.viewportExec(function() return nil end)('X')==false,'no viewport: not handled')
-- The Event Bridge's focus event, when installed, on the game thread.
local Focus=require('config_reload_focus')
assert(Focus.subscribe(function() end,{})==false,'no Event Bridge: no focus trigger')
local registered,onThread
local globals={UE4SSLuaEventBridge={onFocusRegained=function(cb) registered=cb;return function() return true end end},
    ExecuteInGameThread=function(fn) onThread=true;fn() end}
local focused=0
assert(Focus.subscribe(function() focused=focused+1 end,globals)==true)
registered({away_ms=5000})
assert(focused==1 and onThread,'a regain runs the trigger on the game thread')
globals.UE4SSLuaEventBridge.onFocusRegained=function() return nil,'limit' end
assert(not pcall(Focus.subscribe,function() end,globals),'a refusal is an error the caller logs')
print('PASS config reload fans out once per trigger and merges automatic ones, with or without a player')

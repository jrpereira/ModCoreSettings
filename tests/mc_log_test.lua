package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Log=require('mc_log')
local function capture(options)
    local lines={}
    options.write=function(line) lines[#lines+1]=line end
    options.name=options.name or 'Test'
    return Log.new(options),lines
end

-- Without the bridge the default is WARN; a path option is ignored.
UE4SSLuaLogBridge=nil
local log,lines=capture({path='does/not/matter/log_level.txt'})
assert(log.level=='WARN')
log.trace('t');log.debug('d');log.info('i');log.warn('w');log.error('e');log.critical('c')
assert(#lines==3 and lines[1]=='[Test] WARN w' and lines[2]=='[Test] ERROR e'
    and lines[3]=='[Test] CRITICAL c',table.concat(lines,'|'))

-- Without a writer, lines go to print with the same format.
local printed={}
local originalPrint=print
print=function(text) printed[#printed+1]=text end
log=Log.new({name='Plain'})
log.info('hidden');log.warn('shown ',1)
print=originalPrint
assert(#printed==1 and printed[1]=='[Plain] WARN shown 1\n',printed[1])

-- A level option sets it in any case; arguments are joined with tostring.
log,lines=capture({level=' debug '})
assert(log.level=='DEBUG' and log.enabled('debug') and not log.enabled('TRACE'))
log.trace('hidden');log.debug('count ',3,' ',nil,' ',true)
assert(#lines==1 and lines[1]=='[Test] DEBUG count 3 nil true',lines[1])
-- Method-call syntax works too.
log:info('method');assert(lines[2]=='[Test] INFO method' and log:enabled('info'))

-- An unknown level is WARN, silently; arguments are not converted when filtered.
log,lines=capture({level='chatty'})
assert(log.level=='WARN' and #lines==0)
log,lines=capture({level='error'})
local converted=false
log.warn(setmetatable({},{__tostring=function() converted=true;return 'x' end}))
assert(log.level=='ERROR' and #lines==0 and not converted)

-- A failing writer never breaks the caller.
log=Log.new({name='Test',level='INFO',write=function() error('disk full') end})
log.info('safe')

-- With the bridge, new returns its logger for the name, passing level and categories.
local registered={}
local bridgeLogger={level='WARN',warn=function() end}
local environment={Register=function(name,options)
    registered[#registered+1]={name=name,options=options}
    return bridgeLogger
end}
UE4SSLuaLogBridge=setmetatable({},{__call=function() return environment end})
log=Log.new({name='Bridged',path='ignored.txt',level='info',categories={'combat'}})
assert(log==bridgeLogger and #registered==1 and registered[1].name=='Bridged')
assert(registered[1].options.level=='INFO' and registered[1].options.categories[1]=='combat'
    and registered[1].options.path==nil)
log=Log.new()
assert(log==bridgeLogger and registered[2].name=='ModCore' and registered[2].options.level==nil)
-- Loggers from the bridge pass through wrap unchanged.
assert(Log.wrap(log)==bridgeLogger)
-- An explicit writer keeps the plain logger, so callers can capture lines.
log,lines=capture({})
assert(log~=bridgeLogger and #registered==2)

-- A bridge that refuses or fails falls back to the plain logger, which says why once.
printed={}
print=function(text) printed[#printed+1]=text end
environment.Register=function() return nil,'invalid','Register: name must be a string' end
log=Log.new({name='Refused'})
environment.Register=function() error('native call failed') end
local failing=Log.new({name='Failing'})
UE4SSLuaLogBridge=setmetatable({},{__call=function() error('no environment') end})
local broken=Log.new({name='Broken'})
print=originalPrint
assert(log.level=='WARN' and failing.level=='WARN' and broken.level=='WARN')
assert(#printed==3,table.concat(printed,'|'))
assert(printed[1]:find('^%[Refused%] WARN UE4SS Lua Log Bridge unavailable %(Register: name must be a string%)'),printed[1])
assert(printed[2]:find('^%[Failing%] WARN UE4SS Lua Log Bridge unavailable %(.*native call failed%)'),printed[2])
assert(printed[3]:find('^%[Broken%] WARN UE4SS Lua Log Bridge unavailable %(.*no environment%)'),printed[3])
UE4SSLuaLogBridge=nil

-- wrap turns a plain function into a logger that forwards every level, and keeps loggers.
local seen={}
local wrapped=Log.wrap(function(message) seen[#seen+1]=message end)
wrapped.trace('a ',1);wrapped.critical('b');wrapped:warn('c')
assert(seen[1]=='a 1' and seen[2]=='b' and seen[3]=='c')
log=Log.new({name='Test',write=function() end})
assert(Log.wrap(log)==log)
Log.wrap(nil).error('silent')
print('PASS leveled logging hands off to the Log Bridge, else writes WARN and above through print')

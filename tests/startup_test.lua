package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local captured={}
local installed=false
local scans=0
package.loaded.mcs_mod_registry={boot=function() scans=scans+1 end,mkdir=function() end}
local originalPrint=print
print=function(value) captured[#captured+1]=value end
package.loaded.dmm_binding={install=function() installed=true;return true end}
package.loaded.dmm_bootstrap={run=function(log) assert(scans==1,'scan precedes DMM bootstrap');log('DMM_REQUIRED','missing DMM') end}
dofile('Scripts/main.lua')
print=originalPrint
assert(#captured==2 and captured[1]:find('SETTINGS_PAGE_UNAVAILABLE',1,true)
    and captured[2]:find('DMM_REQUIRED',1,true),'without a mod folder the page is not published')
assert(not installed,'DMM readiness must gate MCS initialization')
print('PASS startup explains missing DMM and remains inactive')
package.loaded.dmm_binding={install=function() installed=true;return true end}
package.loaded.dmm_bootstrap={run=function(_,start) assert(scans==2,'one scan per startup');return start() end}
dofile('Scripts/main.lua')
assert(installed,'ready DMM handshake must initialize presentation')
print('PASS ready DMM handshake initializes presentation')

installed=false
package.loaded.mcs_mod_registry={boot=function() error('malformed register') end,mkdir=function() end}
package.loaded.dmm_bootstrap={run=function(_,start) return start() end}
print=function(value) captured[#captured+1]=value end
dofile('Scripts/main.lua')
print=originalPrint
assert(installed,'identification failure must not block presentation')
assert(table.concat(captured,'\n'):find('MODULE_IDENTIFICATION_FAILED',1,true))
print('PASS identification failure is logged without blocking DMM integration')

-- From its mod folder, MCS publishes its own page, attached to that folder.
local getinfo=debug.getinfo
debug.getinfo=function() return {source='@C:/Mods/1_ModCore_Settings/Scripts/main.lua'} end
local made,published
package.loaded.mcs_mod_registry={boot=function() end,mkdir=function(path) made=path end}
package.loaded.menu_contributions={publisher=function(shared,options)
    assert(shared==ModRef and options.id=='ModCoreSettings' and options.directory=='C:/Mods/1_ModCore_Settings/cache')
    return {publish=function(_,contribution) published=contribution end}
end}
ModRef={}
captured={}
print=function(value) captured[#captured+1]=value end
dofile('Scripts/main.lua')
print=originalPrint
debug.getinfo=getinfo
local page=published and published.pages[1]
assert(made=='C:/Mods/1_ModCore_Settings/cache' and #published.pages==1 and page.id=='ModCoreSettings'
    and page.attach=='1_ModCore_Settings' and page.configDirectory=='C:/Mods/1_ModCore_Settings'
    and page.menu==require('mcs_page') and page.version=='1.1.0' and #captured==0,
    'MCS publishes its own page as menu data attached to its folder')
print('PASS MCS publishes its own page')

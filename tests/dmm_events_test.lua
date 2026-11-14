package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Events=require('dmm_events')
local reports={}
local function report(event,detail) reports[#reports+1]=event..':'..tostring(detail) end
local bus=Events.bus(report)
local seen={}
bus:on('hostClosing',function(context) seen[#seen+1]={name='hostClosing',context=context} end)
assert(not pcall(bus.on,bus,'providerRefreshed',function() end),'only hostClosing is offered')

-- A stand-in for DMM's controls.build.
local tree,pc={name='tree'},{name='pc'}
local providers={{id='A'},{id='B'}}
local controls={build=function(_,list,_)
    local ui={panels={}}
    function ui:show(index) self.active=index;return 'shown',index end
    function ui:hide() self.active=nil;return 'hidden' end
    return ui
end}
local native={opened=0,closed=0}
function native.new(owner,widgets) native.opened=native.opened+1;return {owner=owner,tree=widgets} end
function native.close() native.closed=native.closed+1 end
Events.attach({controls=controls,nativeactions=native},bus,report)

local ui=controls.build(tree,providers,{pc=pc})
local shown,index=ui:show(2)
assert(shown=='shown' and index==2 and #seen==0,'other calls pass through untouched')
assert(ui:hide()=='hidden','wrapped calls return what DMM returns')
assert(seen[1].name=='hostClosing' and seen[1].context.tree==tree)
local opened=native.new(pc,tree)
assert(opened.owner==pc and opened.tree==tree and native.opened==1)
native.close()
assert(native.closed==1 and seen[2].name=='hostClosing' and seen[2].context.tree==tree and seen[2].context.pc==pc)
native.close()
assert(native.closed==2 and #seen==2,'only a menu that was opened reports closing')
print('PASS leaving a page and closing the menu report hostClosing')

-- A failing listener is reported and never breaks DMM's own call.
bus:on('hostClosing',function() error('listener failure') end)
assert(ui:hide()=='hidden')
assert(reports[#reports]:find('LIFECYCLE_CALLBACK_FAILED:hostClosing',1,true))
print('PASS listener failures are isolated from DMM')

package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local shared,handlers={},{}
local rejected
ModRef={
 GetSharedVariable=function(_,key) return shared[key] end,
 SetSharedVariable=function(_,key,value) shared[key]=value end,
}
RegisterConsoleCommandHandler=function(command,callback)
 if command==rejected then return false end
 assert(not handlers[command],'duplicate native handler')
 handlers[command]=callback;return true
end
local api=require('settings_api')
assert(api.version==2)
local rejectedCommand='MC_SettingsApplied_v2_'..('Rejected'):gsub('.',function(c) return string.format('%02x',c:byte()) end)
rejected=rejectedCommand
assert(not pcall(api.subscribe,'Rejected',function() end))
assert(shared[rejectedCommand..'.owner']==nil,'failed registration retained ownership')
rejected=nil
assert(type(api.subscribe('Rejected',function() end))=='function','registration could not recover')
local command='MC_SettingsApplied_v2_'..('Provider'):gsub('.',function(c) return string.format('%02x',c:byte()) end)
local received={}
local unsubscribe=api.subscribe('Provider',function(event) received[#received+1]=event end)
shared[command..'.data']='1\n4b6579 n1 n2\n53616d65 n4 n4\n'
assert(handlers[command]())
assert(#received==1 and received[1].providerId=='Provider' and received[1].revision==1)
assert(received[1].values.Key==2 and received[1].values.Same==4)
assert(received[1].changes.Key.old==1 and received[1].changes.Key.new==2 and received[1].changes.Same==nil)
handlers[command]();assert(#received==1,'duplicate revision delivered twice')
local replacement
api.subscribe('Provider',function(event) replacement=event end)
shared[command..'.data']='2\n4b6579 n2 n3\n'
handlers[command]();assert(#received==1 and replacement.revision==2 and replacement.values.Key==3)
unsubscribe();shared[command..'.data']='3\n4b6579 n3 n4\n';handlers[command]()
assert(replacement.revision==3,'obsolete unsubscribe removed the replacement callback')
local stop=api.subscribe('Provider',function(event) replacement=event end)
stop();shared[command..'.data']='4\n4b6579 n4 n5\n';handlers[command]()
assert(replacement.revision==3,'unsubscribe did not stop delivery')
-- Text values: a keyed picker's key and a range arrive as the stored text, beside numbers.
local Notify=require('settings_notify')
local textCommand='MC_SettingsApplied_v2_'..('Text'):gsub('.',function(c) return string.format('%02x',c:byte()) end)
local got
api.subscribe('Text',function(event) got=event end)
shared[textCommand..'.data']=Notify.payload(0,{values={Template='Fangdango_SingleUnderbar',Range='2|7',Size=3},
    changes={Template={old='None',new='Fangdango_SingleUnderbar'}}})
assert(handlers[textCommand]())
assert(got and got.revision==1 and got.values.Template=='Fangdango_SingleUnderbar' and got.values.Range=='2|7'
    and got.values.Size==3)
assert(got.changes.Template.old=='None' and got.changes.Template.new=='Fangdango_SingleUnderbar'
    and got.changes.Range==nil and got.changes.Size==nil)
-- Empty text survives; malformed rows are not delivered.
shared[textCommand..'.data']=Notify.payload(1,{values={Name=''}})
handlers[textCommand]();assert(got.revision==2 and got.values.Name=='')
for _,bad in ipairs({'3\n4b6579 x1 n2\n','3\n4b6579 s4 n2\n','3\n4b6579 sZZ n2\n','3\n4b6579 ninf n2\n'}) do
    shared[textCommand..'.data']=bad;handlers[textCommand]()
    assert(got.revision==2,'malformed '..bad..' delivered')
end
assert(Notify.payload(0,{values={}})==nil,'nothing to send')
assert(not pcall(Notify.encode,0/0) and not pcall(Notify.encode,{}) and not pcall(Notify.encode,('x'):rep(1025)))
-- The publisher: wraps DMM's publish, notifies a v2 subscriber, and never fails the Apply.
do
    local executed={}
    local viewport={IsValid=function() return true end,IsA=function() return true end,
        ProcessConsoleExec=function(_,command) executed[#executed+1]=command;return handlers[command]() end}
    local pc={IsValid=function() return true end,Player={IsValid=function() return true end,ViewportClient=viewport}}
    local inner={}
    local dmm={publish=function(id,event) inner[#inner+1]={id=id,event=event};return true end}
    local reports={}
    assert(Notify.install(dmm,function(event,detail) reports[#reports+1]=event..' '..detail end))
    assert(Notify.install(dmm,function() end)==false,'installs once')
    assert(dmm.publish('Text',{values={Template='Mod_B'},changes={}},pc)==true)
    assert(#executed==1 and got.revision==4 and got.values.Template=='Mod_B','v2 subscriber notified')
    assert(#inner==1 and inner[1].event.values.Template=='Mod_B','DMM\'s own publish still runs')
    -- No subscriber: nothing is sent.
    dmm.publish('Nobody',{values={A=1},changes={}},pc)
    assert(#executed==1 and shared['MC_SettingsApplied_v2_4e6f626f6479.data']==nil)
    -- A failure is reported; DMM's publish still runs.
    dmm.publish('Text',{values={A={}},changes={}},pc)
    assert(#reports==1 and reports[1]:find('NOTIFY_FAILED Text',1,true) and #inner==3)
end
print('PASS versioned Apply event, duplicate suppression, callback replacement and unsubscribe')

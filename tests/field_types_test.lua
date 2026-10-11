package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local FieldTypes=require('field_types')
local Keybind=require('keybind_editor')

-- Keybind values: one text value, normalized from what a manifest or file holds.
local s=Keybind.declare({Triggers='Hold|Tap',Optional='1',DefaultControl='IA_Combat_ToggleQuickslots'})
assert(s.optional and s.defaultControl=='IA_Combat_ToggleQuickslots' and s.defaultTrigger=='Hold'
    and s.triggers[1]=='Hold','the first listed trigger is the default')
for raw,expected in pairs({['']='none',['0']='none',none='none',NONE='none',LeftAlt='LeftAlt|Hold',
    ['LeftAlt|hold']='LeftAlt|Hold',[' F | Tap ']='F|Tap',One='1|Hold',['1|Hold']='1|Hold',['zero|tap']='0|Tap'}) do
    assert(Keybind.normalize(s,raw)==expected,raw)
end
for _,raw in ipairs({'LeftAlt|Push','Escape','None|Tap','Gamepad_FaceButton_Bottom','Left Alt','|Tap'}) do
    assert(Keybind.normalize(s,raw)==nil,raw)
end
assert(Keybind.valid(s,'LeftAlt|Hold') and not Keybind.valid(s,'LeftAlt') and not Keybind.valid(s,3))
local fixed=Keybind.declare({Triggers='Hold'})
assert(fixed.defaultTrigger=='Hold' and not fixed.optional and Keybind.normalize(fixed,'J')=='J|Hold')
assert(not pcall(Keybind.declare,{Triggers='Tap|tap'}) and not pcall(Keybind.declare,{Optional='yes'}))
print('PASS keybind values are none or <FKey>|<trigger>, normalized from manifests and files')

-- The panel loop with a stand-in editor: refresh sets, tick gets.
local reports={}
local registry=FieldTypes.new(function(event,detail) reports[#reports+1]=event..':'..tostring(detail) end)
local built,set={},{}
local editor={
    declare=function() return {} end,
    normalize=function(_,raw) return raw or 'a' end,
    valid=function(_,value) return value=='a' or value=='b' end,
    format=function() return '' end,
    build=function(row,setting)
        built[#built+1]=setting.id
        local instance={}
        function instance:set(value,committed) set[#set+1]=value..'/'..committed end
        function instance:tick() local value=row.next;row.next=nil;return value end
        return instance
    end,
}
registry:register('letter',editor)
assert(not pcall(registry.register,registry,'picker',editor),'DMM types cannot be replaced')
local refreshes=0
local choices
choices={parse=function() return {} end,index=function() return 1 end,format=function() return 'dmm' end,
    open=function(provider)
        local model={items=provider.choices,pending={'a'},committed={'a'}}
        function model:set(i,value) if choices.index(self.items[i],value) then self.pending[i]=value end end
        return model
    end}
local controls={build=function(_,providers)
    local ui={panels={{rows={{}}}}}
    function ui:prepare(index) self.panels[index].built=true end
    function ui:show(index) self.panels[index].built=true;self.active=index;self.model=choices.open(providers[index]) end
    function ui:refresh() refreshes=refreshes+1 end
    function ui:tick() return 'dmm tick' end
    return ui
end}
local published={}
local settingsApi={publish=function(id,event) published[#published+1]=event;return true end}
registry:install({choices=choices,controls=controls,settingsApi=settingsApi})
local setting={id='L',kind='extension',editor='letter',label='Letter'}
local keybind={id='K',kind='extension',editor='keybind',triggers={'Tap','Hold'},defaultTrigger='Tap'}
registry:register('keybind',Keybind)
assert(choices.mcNormalize(setting,'b')=='b' and choices.mcNormalize(keybind,' One | hold ')=='1|Hold'
    and choices.mcNormalize(keybind,'Escape')==nil and choices.mcNormalize(keybind,42)==nil
    and choices.mcNormalize({kind='picker',values={0}},0)==nil,
    'stored values of this module\'s types normalize through their editor; DMM types and invalid values do not')
-- DMM gets the manifest without categories only this module's settings use.
local mixed=table.concat({'[Setting.A]','Id=A','Type=picker','Group=Shared','[Setting.K]','Id=K','Type=keybind',
    'Group=Keys','[Category.Keys]','VisibleWhen=A','VisibleValues=1','[Category.Shared]','mcHelp=Shared rows'},'\n')
assert(registry:forDMM(mixed)==table.concat({'[Setting.A]','Id=A','Type=picker','Group=Shared','[Setting.K]','Id=K',
    'Type=keybind','Group=Keys','[Category.Shared]','mcHelp=Shared rows'},'\n'),'a keybind-only category is left out for DMM')
local plain='[Setting.A]\nId=A\nType=picker\n[Category.Unused]\nmcHelp=x\n'
assert(registry:forDMM(plain)==plain,'a manifest without this module\'s types is passed unchanged')
local ui=controls.build({},{{id='P',testOnly=true,choices={setting}}},{})
ui:show(1)
assert(built[1]=='L' and #built==1 and set[#set]=='a/a','show builds the editor once and sets its value')
ui:prepare(1)
assert(#built==1)
local row=ui.panels[1].rows[1]
row.next='b'
local before=refreshes
assert(ui:tick()=='dmm tick','DMM tick results pass through')
assert(ui.model.pending[1]=='b' and refreshes==before+1 and set[#set]=='b/a','a finished edit goes through model:set')
row.next='zzz'
ui:tick()
assert(ui.model.pending[1]=='b','DMM model validation still applies')
-- A row hidden by its page's navigation is not read on each frame.
row.visible=false
row.next='a'
ui:tick()
assert(ui.model.pending[1]=='b','a hidden row is not ticked')
row.visible=true
ui:tick()
assert(ui.model.pending[1]=='a','it is ticked again once shown')
print('PASS refresh sets each editor and tick hands finished edits to the model')

-- A failing editor is reported; the page keeps working.
editor.build=function() error('editor failure') end
ui=controls.build({},{{id='P',testOnly=true,choices={setting}}},{})
ui:show(1)
assert(reports[#reports]:find('FIELD_EDITOR_FAILED:L: ',1,true))
assert(ui:tick()=='dmm tick')
print('PASS a failing editor is reported and DMM keeps running')

-- Applied notifications carry only numbers.
assert(settingsApi.publish('P',{values={Mode=2,Jump='LeftAlt|Hold'},changes={Jump={old='none',new='LeftAlt|Hold'}}}))
assert(published[1].values.Mode==2 and published[1].values.Jump==nil and published[1].changes.Jump==nil)
assert(settingsApi.publish('P',{values={Jump='F|Tap'},changes={}})==true and #published==1,
    'a notification with only text values is skipped')
print('PASS applied notifications drop text values')

-- Collisions: keybind rows sharing a conflict scope must not share a key and trigger;
-- the navigation picker separating a colliding pair is reported too.
do
    local function key(id,rules)
        local s=Keybind.declare({Triggers='Tap|Hold',mcConflictScope='controls'})
        s.id,s.kind,s.editor,s.visibility=id,'extension','keybind',rules or {}
        return s
    end
    local function picker(id,rules) return {id=id,kind='picker',values={0,1},mcNavigation=true,visibility=rules or {}} end
    local function on(target,value) return {target=target,values={[value]=true}} end
    -- 1 Section picker; 2 and 3 map pickers of sections 0 and 1; keys 4,5 on maps of section 0, 6 in section 1.
    local items={picker('Section'),picker('MapA',{on(1,0)}),picker('MapB',{on(1,1)}),
        key('A1',{on(2,0)}),key('A2',{on(2,1)}),key('B1',{on(3,0)}),key('Same',{on(2,0)})}
    local function check(values,rows,pickers,why)
        local model={items=items,pending=values}
        local gotRows,gotPickers=registry.conflicts(model)
        for i=1,#items do
            assert((gotRows[i]==true)==(rows[i]==true),why..': row '..i)
            assert((gotPickers[i]==true)==(pickers[i]==true),why..': picker '..i)
        end
    end
    local none='none'
    check({0,0,0,'J|Tap',none,none,'j|tap'},{[4]=true,[7]=true},{},'same map collides without a picker')
    check({0,0,0,'J|Tap','J|Tap',none,none},{[4]=true,[5]=true},{[2]=true},'different maps light the map picker')
    check({0,0,0,'J|Tap',none,'J|Tap',none},{[4]=true,[6]=true},{[1]=true},'different sections light only the Section picker')
    check({0,0,0,'J|Tap','J|Hold',none,none},{},{},'Tap and Hold do not collide')
    check({0,0,0,none,none,none,none},{},{},'unbound rows never collide')
    items[5].conflictScope='other'
    check({0,0,0,'J|Tap','J|Tap',none,none},{},{},'rows in different scopes do not collide')
    items[5].conflictScope='controls'
    assert(next((registry.conflicts({items=items,pending={},error='broken'})))==nil,'a page error shows no collisions')
end
print('PASS colliding keybinds and the picker that separates them are found')

-- Every refresh marks colliding editors and hands the separating pickers to presentation.
do
    local wired=FieldTypes.new(function() end)
    local marks={}
    wired:register('clash',{declare=function() return {} end,normalize=function(_,raw) return raw or 'x' end,
        valid=function() return true end,format=function() return '' end,
        conflictKey=function(_,value) return value~='none' and value or nil end,
        build=function(_,s)
            local instance={}
            function instance:set() end
            function instance:tick() end
            function instance:conflict(on) marks[s.id]=on end
            return instance
        end})
    local items={{id='Map',kind='picker',values={0,1},mcNavigation=true,visibility={}},
        {id='C1',kind='extension',editor='clash',conflictScope='s',visibility={{target=1,values={[0]=true}}}},
        {id='C2',kind='extension',editor='clash',conflictScope='s',visibility={{target=1,values={[1]=true}}}}}
    local wiredChoices={parse=function() return {} end,index=function() return 1 end,format=function() return '' end,
        open=function(provider) return {items=provider.choices,pending={0,'J','J'},committed={0,'J','J'}} end}
    local wiredControls={build=function(_,providers)
        local ui={panels={{rows={{},{},{}}}}}
        function ui:prepare(index) self.panels[index].built=true end
        function ui:show(index) self.panels[index].built=true;self.active=index;self.model=wiredChoices.open(providers[index]) end
        function ui:refresh() end
        function ui:tick() end
        return ui
    end}
    wired:install({choices=wiredChoices,controls=wiredControls})
    local page=wiredControls.build({},{{id='W',testOnly=true,choices=items}},{})
    page:show(1)
    assert(marks.C1==true and marks.C2==true and page.model.mcConflictPickers[1]==true,
        'refresh marks both rows and the map picker')
    page.model.pending[3]='K';page:refresh()
    assert(marks.C1==false and marks.C2==false and next(page.model.mcConflictPickers)==nil,
        'resolving the collision clears both rows and the picker')
end
print('PASS refresh marks colliding editors and separating pickers')

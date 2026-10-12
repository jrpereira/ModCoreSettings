package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- Needs the real DMM parser, which CI does not have; skip without it.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP menu slots: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
local Navigation=require('navigation')
local Mapped=require('mapped_presets')
local Slots=require('menu_slots')
local Menu=require('menu_contributions')
assert(Navigation.install(Choices))
assert(Mapped.install(Choices,{build=function() end}))
local logs={}
local function report(event,detail) logs[#logs+1]=event..' '..tostring(detail) end
local controller=assert(Slots.install(Choices,report,Menu))
assert(Slots.install(Choices,report,Menu)==nil,'installs once')

local files={}
Choices.fs={read=function(path) return files[path] end,
    write=function(path,content) files[path]=content end,
    rename=function(a,b) files[b]=assert(files[a]);files[a]=nil end,
    remove=function(path) files[path]=nil end}
local function read(path) return files[path] end

local host=[[
[Mod]
Id=ModCoreControls
Name=Controls
[Setting.MCC_Page]
Id=MCC_Page
Type=picker
Label=Page
Group=Pages
PresetValues=0|1
PresetLabels=Options|Visuals
Default=0
mcNavigation=1
[Category.Visuals]
VisibleWhen=MCC_Page
VisibleValues=1
[Setting.MCC_Visuals_Pending]
Id=MCC_Visuals_Pending
Type=picker
Label=Quickslot templates
Group=Visuals
PresetValues=0|1
PresetLabels=Coming|Coming
Default=0
mcReadOnly=1
mcSlot=visuals
[Setting.Speed]
Id=Speed
Type=picker
Label=Speed
Group=Options
PresetValues=0|1
PresetLabels=Slow|Fast
Default=0
VisibleWhen=MCC_Page
VisibleValues=0
ConfigFile=config.ini
ConfigSection=Main
ConfigKey=Speed
]]
local source=[[
[Mod]
Id=ModCoreTemplates
Name=ModCore Templates
[Setting.MCT_Template]
Id=MCT_Template
Type=picker
Label=Quickslots
Description=Choose a template
Group=Player
PresetValues=0|5|7
PresetLabels=None|Ring|Bar
Default=0
mcHeading=true
ConfigFile=templates.ini
ConfigSection=Templates
ConfigKey=MCT_Template
[Setting.MCT_Other]
Id=MCT_Other
Type=toggle
Label=Other
Group=Player
PresetValues=0|1
Default=0
VisibleWhen=MCT_Template
VisibleValues=5|7
ConfigFile=templates.ini
ConfigSection=Templates
ConfigKey=MCT_Other
]]
files['/mcc/mod_settings.ini']=host
files['/mcc/config.ini']='[Main]\nSpeed=0\n'
files['/mct/templates.ini']='[Templates]\nMCT_Template=5\nMCT_Other=1\n'
local function provider(id,path,content,contributed)
    return {id=id,name=id,path=path,choices=Choices.parse(content),settingsCount=select(2,content:gsub('%[Setting%.',''))
        ,mcManifest=contributed and content or nil,testOnly=false}
end
local mcc=provider('ModCoreControls','/mcc/mod_settings.ini',host)
local mct=provider('ModCoreTemplates','/mct/mod_settings.ini',source,true)
local function ids(list)
    local out={}
    for n,setting in ipairs(list) do out[n]=setting.id end
    return table.concat(out,',')
end
local base=mcc.choices
assert(base[2].mcSlot=='visuals' and base[2].mcReadOnly)

-- Without inserts the page is unchanged and keeps its placeholder.
assert(controller:load(mcc,read)==false and mcc.choices==base)

-- An insert replaces the placeholder in place, takes the slot's group and gating, drops
-- source presentation keys, and later index-based rules still point at the right rows.
local applied={}
controller.applied=function(p,event) applied[#applied+1]={id=p.id,event=event} end
local entry={contributor='ModCoreTemplates',source=mct,settings={'MCT_Template'}}
controller.inserts={controls={visuals={entry}}}
assert(controller:load(mcc,read))
assert(ids(mcc.choices)=='MCC_Page,MCT_Template,Speed',ids(mcc.choices))
local template=mcc.choices[2]
assert(template.group=='Visuals' and template.label=='Quickslots' and template.description=='Choose a template')
assert(template.mcSlotSource==mct and template.mcSlotName=='visuals' and not template.mcHeading and not template.file)
assert(Slots.declares(mcc,'visuals',read) and not Slots.declares(mcc,'other',read))
assert(not Slots.declares(mcc,'visuals',function() error('gone') end) and Slots.declares(mct,'x',read)==false)
assert(controller:declares(mcc,'visuals')==false,'the controller reads with the reader it was installed with')
assert(mcc.settingsCount==3 and mcc.mcSlotBase.choices==base)
assert(controller:load(mcc,read) and ids(mcc.choices)=='MCC_Page,MCT_Template,Speed','reload is idempotent')

local model=Choices.open(mcc)
assert(not model.error,model.error)
assert(model.items==mcc.choices and model.pending[2]==5 and model.committed[2]==5 and model.pending[3]==0)
local visible=model:visibility()
assert(not visible[2] and visible[3],'Options page shows Speed, hides Visuals')
model:set(1,1)
visible=model:visibility()
assert(visible[2] and not visible[3] and not model:dirty(),'navigation gates the inserted row')

-- Inserted rows edit the source model only; Apply writes the source config and publishes
-- the source's own event. The host config never sees them.
model:change(2,2)
assert(model.pending[2]==7 and model.committed[2]==5 and model:dirty())
local ok,err,event=model:apply()
assert(ok and err==nil and event==nil,tostring(err))
assert(files['/mct/templates.ini']=='[Templates]\nMCT_Template=7\nMCT_Other=1\n')
assert(files['/mcc/config.ini']=='[Main]\nSpeed=0\n')
assert(#applied==1 and applied[1].id=='ModCoreTemplates' and applied[1].event.values.MCT_Template==7
    and applied[1].event.values.MCT_Other==1 and applied[1].event.changes.MCT_Template.old==5)
assert(not model:dirty() and model.committed[2]==7)

-- Host rows keep their own Apply event; inserted values never appear in it.
applied={}
model:set(1,0);model:set(3,1);model:set(2,0)
ok,err,event=model:apply()
assert(ok and event.values.Speed==1 and event.values.MCT_Template==nil,tostring(err))
assert(event.values.MCC_Page==nil and event.values.MCC_Visuals_Pending==nil)
assert(files['/mcc/config.ini']=='[Main]\nSpeed=1\n' and files['/mct/templates.ini']:find('MCT_Template=0',1,true))
assert(#applied==1 and applied[1].id=='ModCoreTemplates','DMM publishes the host event; the slot publishes the source')

-- Restore, row reset and page reset reach both models.
model:set(3,0);model:set(2,5)
model:restore()
assert(model.pending[3]==1 and model.pending[2]==0 and not model:dirty())
model:set(2,7);model:reset(2)
assert(model.pending[2]==0)
model:set(2,7);model:set(3,0);model:reset()
assert(model.pending[2]==0 and model.pending[3]==0 and model:dirty())
model:restore()

-- A source failure after a successful host Apply still publishes the host event.
applied={}
model:set(3,0);model:set(2,5)
files['/mct/templates.ini']='[Templates]\nMCT_Template=0\nMCT_Other=0\n'
ok,err=model:apply()
assert(not ok and err:find('ModCoreTemplates',1,true) and err:find('changed externally',1,true),tostring(err))
assert(#applied==1 and applied[1].id=='ModCoreControls' and applied[1].event.values.Speed==0)
assert(files['/mcc/config.ini']=='[Main]\nSpeed=0\n' and model.committed[3]==0 and model:dirty())
model:restore()

-- An unavailable source leaves its rows inert; the host page still works.
local saved=files['/mct/templates.ini']
files['/mct/templates.ini']=nil
logs={}
model=Choices.open(mcc)
assert(not model.error and model.pending[2]==0 and logs[1]:find('SLOT_SOURCE_UNAVAILABLE',1,true))
model:set(2,7)
assert(model.pending[2]==0 and not model:dirty())
model:set(3,1)
assert(model:dirty() and model:apply())
files['/mct/templates.ini']=saved

-- Invalid rows are skipped one by one with a log; the placeholder returns when none remain.
local function rejected(settings,pattern)
    logs={}
    controller.inserts={controls={visuals={{contributor='ModCoreTemplates',source=mct,settings=settings}}}}
    assert(controller:load(mcc,read)==false and mcc.choices==base,pattern)
    assert(logs[1] and logs[1]:find('SLOT_ROW_SKIPPED',1,true) and logs[1]:find(pattern,1,true),tostring(logs[1]))
end
rejected({'Missing'},'not found')
rejected({'MCT_Other'},'inserted earlier')
rejected({'MCT_Other','MCT_Template'},'inserted earlier')
logs={}
controller.inserts={controls={visuals={{contributor='Someone',source=mct,settings={'MCT_Template'}},
    {contributor='ModCoreTemplates',source=mct,settings={'MCT_Other'}}}}}
assert(controller:load(mcc,read) and ids(mcc.choices)=='MCC_Page,MCT_Template,Speed'
    and logs[1]:find('inserted earlier',1,true),'another contributor\'s row is not a visibility source')

-- A row may gate on a row its contributor inserted earlier; DMM ANDs that with the slot Category.
logs={}
controller.inserts={controls={visuals={{contributor='ModCoreTemplates',source=mct,settings={'MCT_Template'}},
    {contributor='ModCoreTemplates',source=mct,settings={'MCT_Other'}}}}}
assert(controller:load(mcc,read) and ids(mcc.choices)=='MCC_Page,MCT_Template,MCT_Other,Speed' and #logs==0,logs[1])
files['/mct/templates.ini']='[Templates]\nMCT_Template=5\nMCT_Other=1\n'
model=Choices.open(mcc)
assert(model.pending[2]==5 and model.pending[3]==1)
visible=model:visibility()
assert(not visible[3],'hidden on the Options page')
model:set(1,1)
assert(model:visibility()[3],'Visuals page with a template selected')
model:set(2,0)
assert(not model:visibility()[3] and model:visibility()[2],'no template selected')
model:restore()
local gated=host:gsub('mcSlot=visuals\n','mcSlot=visuals\nVisibleWhen=MCC_Page\nVisibleValues=1\n')
files['/gated/mod_settings.ini']=gated
local other=provider('Gated','/gated/mod_settings.ini',gated)
logs={}
assert(Slots.load(other,{visuals={{contributor='ModCoreTemplates',source=mct,settings={'MCT_Template','MCT_Other'}}}},
    read,Choices.parse,report)==false and logs[1]:find('own VisibleWhen',1,true),tostring(logs[1]))
rejected({'Speed'},'already on this page')
logs={}
controller.inserts={controls={visuals={{contributor='Bad',source=mct,settings={'Missing'}},entry}}}
assert(controller:load(mcc,read) and ids(mcc.choices)=='MCC_Page,MCT_Template,Speed' and #logs==1)

-- Unknown slots and unreadable manifests leave the page untouched.
controller.inserts={controls={Other={entry}}}
assert(controller:load(mcc,read)==false and mcc.choices==base)
controller.inserts={controls={visuals={entry}}}
logs={}
assert(controller:load(mcc,function() return nil end)==false and mcc.choices==base)
assert(logs[1]:find('SLOT_ROWS_SKIPPED',1,true))

-- A deferred page reloaded by DMM gets a fresh base.
assert(controller:load(mcc,read))
mcc.choices=Choices.parse(host)
assert(controller:load(mcc,read) and mcc.mcSlotBase.choices~=base and #mcc.mcSlotBase.choices==3)

-- A provider storage wrapper installed later (as ModCoreControls does) ends up inside the
-- slot model once outermost() runs, so it only ever sees the host's own settings.
do
    controller.inserts={controls={visuals={entry}}}
    files['/mct/templates.ini']='[Templates]\nMCT_Template=5\nMCT_Other=1\n'
    assert(controller:load(mcc,read))
    local storage,seen={},nil
    local before=Choices.open
    Choices.open=function(p)
        if p.id~='ModCoreControls' then return before(p) end
        local model=before(p)
        seen=p.choices
        function model:apply()
            for i,item in ipairs(self.items) do storage[item.id]=self.pending[i] end
            for i,value in ipairs(self.pending) do self.committed[i]=value end
            return true,nil,{values=storage,changes={}}
        end
        return model
    end
    assert(controller:outermost() and not controller:outermost(),'re-wraps once')
    applied={}
    local composite=Choices.open(mcc)
    assert(seen==mcc.mcSlotBase.choices,'storage sees the unspliced host')
    composite:set(1,1);composite:set(2,7);composite:set(3,1)
    assert(composite:apply())
    assert(storage.Speed==1 and storage.MCT_Template==nil,'inserted rows never reach host storage')
    assert(files['/mct/templates.ini']:find('MCT_Template=7',1,true) and #applied==1)
end

-- mcSlotLabel=1: the first inserted row takes the slot row's Label and mcLevel; later rows
-- keep their own. Without inserts the placeholder shows unchanged.
do
    local labelled=host:gsub('Label=Quickslot templates\n','Label=Quickslots Visuals\nmcLevel=3\n')
        :gsub('mcSlot=visuals\n','mcSlot=visuals\nmcSlotLabel=1\n')
    files['/lab/mod_settings.ini']=labelled
    local page=provider('Labelled','/lab/mod_settings.ini',labelled)
    assert(page.choices[2].label=='Quickslots Visuals','empty slot: the placeholder keeps the host label')
    local text
    local function spy(content) text=content;return Choices.parse(content) end
    local one={contributor='ModCoreTemplates',source=mct,settings={'MCT_Template'}}
    local two={contributor='ModCoreTemplates',source=mct,settings={'MCT_Other'}}
    logs={}
    assert(Slots.load(page,{visuals={{contributor='Bad',source=mct,settings={'Missing'}},one,two}},read,spy,report),logs[1])
    assert(ids(page.choices)=='MCC_Page,MCT_Template,MCT_Other,Speed')
    assert(page.choices[2].label=='Quickslots Visuals' and page.choices[3].label=='Other',
        'first inserted row named by the host, after a skipped entry too')
    local first=text:match('%[Setting%.mcSlot%.%d+%]\n(.-)\n\n')
    assert(first:find('mcLevel=3',1,true) and first:find('Label=Quickslots Visuals',1,true),first)
    assert(select(2,text:gsub('mcLevel=3',''))==1,'only the first inserted row takes the level')
    assert(page.choices[2].values[3]==7 and page.choices[2].mcSlotSource==mct,'still the source picker')
    -- mcCategory passes to the named row the same way.
    local category=labelled:gsub('mcLevel=3\n','mcCategory=1\n')
    files['/cat/mod_settings.ini']=category
    local catPage=provider('Category','/cat/mod_settings.ini',category)
    assert(Slots.load(catPage,{visuals={one,two}},read,spy,report))
    first=text:match('%[Setting%.mcSlot%.%d+%]\n(.-)\n\n')
    assert(first:find('mcCategory=1',1,true) and select(2,text:gsub('mcCategory=1',''))==1,
        'only the named row stands in for the heading')
end
-- A label rule naming a row the contributor inserted earlier is carried into the slot.
do
    local relabelled=source:gsub('VisibleValues=5|7\n','VisibleValues=5|7\nmcLabelWhen=MCT_Template\nmcLabels=7:Bar Other\n')
    local mctLabel=provider('ModCoreTemplates','/mct/mod_settings.ini',relabelled,true)
    local page=provider('ModCoreControls','/mcc/mod_settings.ini',host)
    local text
    local function spy(content) text=content;return Choices.parse(content) end
    logs={}
    assert(Slots.load(page,{visuals={{contributor='ModCoreTemplates',source=mctLabel,
        settings={'MCT_Template','MCT_Other'}}}},read,spy,report),logs[1])
    assert(text:find('mcLabelWhen=MCT_Template\nmcLabels=7:Bar Other',1,true),text)
    local items=require('presentation').parse(text,Choices.parse(text))
    local rule=items[3].mcLabelRule
    assert(items[3].id=='MCT_Other' and rule and rule.source.id=='MCT_Template' and rule.values[7]=='Bar Other')
    logs={}
    assert(Slots.load(page,{visuals={{contributor='ModCoreTemplates',source=mctLabel,settings={'MCT_Other'}}}},
        read,Choices.parse,report)==false and logs[1]:find('mcLabelWhen must name',1,true),tostring(logs[1]))
end
-- A picker's choice notes are carried into the slot, so its second line shows there too.
do
    local noted=source:gsub('mcHeading=true\n','mcHeading=true\nmcChoiceNotes=5:Ringer;7:Barista\n')
    local mctNotes=provider('ModCoreTemplates','/mct/mod_settings.ini',noted,true)
    local page=provider('ModCoreControls','/mcc/mod_settings.ini',host)
    local text
    local function spy(content) text=content;return Choices.parse(content) end
    logs={}
    assert(Slots.load(page,{visuals={{contributor='ModCoreTemplates',source=mctNotes,
        settings={'MCT_Template','MCT_Other'}}}},read,spy,report),logs[1])
    assert(text:find('mcChoiceNotes=5:Ringer;7:Barista',1,true),text)
    assert(not text:find('mcHeading=true',1,true),'other presentation keys stay behind')
    local items=require('presentation').parse(text,Choices.parse(text))
    assert(items[2].id=='MCT_Template' and items[2].mcChoiceNotes[7]=='Barista')
end
assert(not pcall(Choices.parse,host:gsub('mcSlot=visuals\n','mcSlotLabel=1\n')),'mcSlotLabel requires mcSlot')
assert(not pcall(Choices.parse,host:gsub('mcSlot=visuals\n','mcSlot=visuals\nmcSlotLabel=yes\n')),'mcSlotLabel is 1')

-- Slot declarations are validated with the manifest.
assert(not pcall(Choices.parse,host:gsub('mcReadOnly=1\n','')),'mcSlot requires read-only')
assert(not pcall(Choices.parse,host:gsub('mcSlot=visuals','mcSlot=a-b')),'slot names are words')
-- A read-only row can be mirrored: it stays a shown value, with no storage, never dirty.
-- Navigation rows still cannot.
local shown=[[
[Mod]
Id=Extras
Name=Extras
[Setting.Installed]
Id=Installed
Type=picker
Label=Installed extensions
Group=Extras
PresetValues=0|1
PresetLabels=2|2
Default=0
mcReadOnly=1
[Setting.Go]
Id=Go
Type=picker
Label=Go
Group=Extras
PresetValues=0|1
PresetLabels=Go|Go
Default=0
mcNavigation=1
]]
files['/extras/mod_settings.ini']=shown
local extras=provider('Extras','/extras/mod_settings.ini',shown,true)
logs={}
controller.inserts={controls={visuals={{contributor='Extras',source=extras,settings={'Installed'}}}}}
assert(controller:load(mcc,read) and #logs==0,logs[1])
local mirrored
for _,setting in ipairs(mcc.choices) do if setting.id=='Installed' then mirrored=setting end end
assert(mirrored and mirrored.mcReadOnly and mirrored.mcSlotSource==extras and not mirrored.file,
    'a mirrored read-only row stays read-only and stores nothing')
model=Choices.open(mcc)
assert(not model.error and not model:dirty(),'a mirrored read-only row never dirties the page')
logs={}
controller.inserts={controls={visuals={{contributor='Extras',source=extras,settings={'Go'}}}}}
assert(controller:load(mcc,read)==false and logs[1]:find('navigation and link rows cannot be inserted',1,true),logs[1])
-- Under mcSlotGroups=1 inserted rows keep their source groups as the host's own groups,
-- headed as any group and shown under the slot group's rule. A host group left empty
-- loses its Category; a source group with a rule of its own is rejected.
do
    local tabs=[[
[Category.Pages]
mcHeading=0
[Category.Listed]
mcHeading=0
VisibleWhen=Page
VisibleValues=1
[Setting.Page]
Id=Page
Type=picker
Label=Page
Group=Pages
PresetValues=0|1
PresetLabels=A|B
Default=0
[Setting.Slot]
Id=Slot
Type=picker
Label=Listed
Group=Listed
PresetValues=0|1
PresetLabels=None|None
Default=0
mcReadOnly=1
mcSlot=listed
mcSlotGroups=1
]]
    local listing=[[
[Category.First]
mcLabel=First Things
mcLevel=3
[Category.Second]
mcSilent=1
[Category.Gated]
VisibleWhen=One
VisibleValues=0
[Setting.One]
Id=One
Type=picker
Label=One
Group=First
PresetValues=0|1
PresetLabels=Yes|Yes
Default=0
mcReadOnly=1
[Setting.Two]
Id=Two
Type=picker
Label=Two
Group=Second
PresetValues=0|1
PresetLabels=Yes|Yes
Default=0
mcReadOnly=1
[Setting.Three]
Id=Three
Type=picker
Label=Three
Group=Second
PresetValues=0|1
PresetLabels=Yes|Yes
Default=0
mcReadOnly=1
[Setting.Four]
Id=Four
Type=picker
Label=Four
Group=Gated
PresetValues=0|1
PresetLabels=Yes|Yes
Default=0
mcReadOnly=1
]]
    files['/tabs/mod_settings.ini']=tabs
    local page=provider('Tabs','/tabs/mod_settings.ini',tabs)
    Slots.parse(tabs,page.choices)
    local list=provider('Lister','/list/mod_settings.ini',listing,true)
    local text
    local function spy(content) text=content;return Choices.parse(content) end
    logs={}
    -- Two entries from one page share its groups: Second gets one heading.
    assert(Slots.load(page,{listed={{contributor='Lister',source=list,settings={'One','Two'}},
        {contributor='Lister',source=list,settings={'Three'}}}},read,spy,report),logs[1])
    assert(ids(page.choices)=='Page,One,Two,Three',ids(page.choices))
    assert(page.choices[2].group=='mcSlot.listed.1' and page.choices[3].group=='mcSlot.listed.2'
        and page.choices[4].group=='mcSlot.listed.2','rows keep their groups under slot names')
    assert(text:find('[Category.mcSlot.listed.1]\nmcLabel=First Things\nmcLevel=3\nVisibleWhen=Page\nVisibleValues=1\n',1,true)
        and text:find('[Category.mcSlot.listed.2]\nmcLabel=Second\nmcSilent=1\nVisibleWhen=Page\nVisibleValues=1\n',1,true),
        text)
    assert(not text:find('[Category.Listed]',1,true),'the emptied slot group loses its Category')
    assert(page.settingsCount==4,'counts the slot row once')
    -- A group with its own rule cannot keep its group; that entry alone is skipped.
    logs={}
    assert(Slots.load(page,{listed={{contributor='Lister',source=list,settings={'Four'}},
        {contributor='Lister',source=list,settings={'One'}}}},read,spy,report))
    assert(ids(page.choices)=='Page,One' and logs[1]:find('has its own rule',1,true),logs[1])
    assert(page.choices[2].group=='mcSlot.listed.1','a skipped entry does not use up a group name')
    assert(not pcall(Slots.parse,tabs:gsub('mcSlotGroups=1','mcSlotGroups=2'),page.choices))
end
-- Subgroups keep their category under its slot name, and its drawn heading's label.
do
    local tabs=[[
[Setting.Slot]
Id=Slot
Type=picker
Label=Listed
Group=Listed
PresetValues=0|1
PresetLabels=None|None
Default=0
mcReadOnly=1
mcSlot=listed
mcSlotGroups=1
]]
    local listing=[[
[Category.Inner]
mcLabel=Module
mcWithin=Outer
mcWithinLabel=Category
[Setting.One]
Id=One
Type=picker
Label=One
Group=Inner
PresetValues=0|1
PresetLabels=Yes|Yes
Default=0
mcReadOnly=1
]]
    files['/nest/mod_settings.ini']=tabs
    local page=provider('Nest','/nest/mod_settings.ini',tabs)
    Slots.parse(tabs,page.choices)
    local list=provider('Nester','/nested/mod_settings.ini',listing,true)
    local text
    local function spy(content) text=content;return Choices.parse(content) end
    logs={}
    assert(Slots.load(page,{listed={{contributor='Nester',source=list,settings={'One'}}}},read,spy,report),logs[1])
    assert(page.choices[1].group=='mcSlot.listed.1',text)
    assert(text:find('[Category.mcSlot.listed.1]\nmcLabel=Module\nmcWithinLabel=Category\nmcWithin=mcSlot.listed.2\n',1,true),text)
end
print('PASS menu slots splice contributed rows and route them to their source model')

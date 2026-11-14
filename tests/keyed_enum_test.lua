package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- Keyed enums end to end: menu data, DMM's parser and model, hooks storage, Apply events and
-- slot rows. Needs the real DMM parser, which CI does not have; skip without it.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP keyed enums: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
local MenuData=require('menu_data')
local Hooks=require('page_hooks')
local Menu=require('menu_contributions')
local Slots=require('menu_slots')
assert(require('navigation').install(Choices))
local logs={}
local function report(event,detail) logs[#logs+1]=event..' '..tostring(detail) end
assert(Hooks.install(Choices,report))
local controller=assert(Slots.install(Choices,report,Menu))

local function fails(f,pattern)
    local ok,err=pcall(f)
    assert(not ok and tostring(err):find(pattern,1,true),pattern..': '..tostring(err))
end

-- Compiling: DMM sees positions; the keys travel as mcKeys; rules, notes and sounds use
-- positions too.
local function menu(values,default,extra)
    local fields={
        {id='MCT_Template',group='Player',label='Template',values=values,default=default,
            conditions=extra and extra.conditions},
        {id='MCT_Size',group='Player',label='Size',values={{value=0,label='Small'},{value=1,label='Large'}},default=0,
            conditions={visible={field='MCT_Template',values={'Fangdango_SingleUnderbar','Preymonition_Ring'}},
                label={field='MCT_Template',values={[{'Fangdango_SingleUnderbar'}]='Bar size',Preymonition_Ring='Ring size'}}}},
    }
    return {storage={file='templates.ini',section='Templates'},groups={{id='Player',
        conditions={order={field='MCT_Template',values={None=1}}}}},fields=fields}
end
local CHOICES={
    {key='None',label='None'},
    {key='Fangdango_SingleUnderbar',label='Single Underbar',note='Fangdango',sound='none'},
    {key='Preymonition_Ring',label='Ring',sound='/Game/Audio/Click.Click'},
}
local manifest=MenuData.manifest(menu(CHOICES,'Fangdango_SingleUnderbar',{conditions={dim={'None'}}}))
for _,expected in ipairs({'PresetValues=1|2|3\n','PresetLabels=None|Single Underbar|Ring\n',
        'mcKeys=None|Fangdango_SingleUnderbar|Preymonition_Ring\n','mcChoiceNotes=2:Fangdango\n',
        'mcChoiceSounds=2:none;3:/Game/Audio/Click.Click\n','mcDimValues=1\n','Default=2\n',
        'VisibleWhen=MCT_Template\nVisibleValues=2|3\n','mcLabels=2:Bar size;3:Ring size\n',
        'mcOrderWhen=MCT_Template\nmcOrders=1:1\n'}) do
    assert(manifest:find(expected,1,true),'compiled '..expected..'\n'..manifest)
end
assert(not manifest:find('Fangdango_SingleUnderbar|',1,true) or manifest:find('mcKeys=',1,true))

-- Invalid keyed enums name the problem.
local function rejects(values,default,pattern,patch)
    local data=menu(values,default)
    if patch then patch(data) end
    fails(function() MenuData.manifest(data) end,pattern)
end
rejects({{key='A',label='A'},{value=1,label='B'}},'A','unknown field value')
rejects({{value=0,label='A'},{key='B',label='B'}},0,'unknown field key')
rejects({{key='A b',label='A'},{key='B',label='B'}},'B','invalid MCT_Template value key')
rejects({{key='14',label='A'},{key='B',label='B'}},'B','invalid MCT_Template value key')
rejects({{key=('x'):rep(129),label='A'},{key='B',label='B'}},'B','invalid MCT_Template value key')
rejects({{key='A',label='A'},{key='A',label='B'}},'A','duplicate value')
rejects({{key='A',label='A'},{key='B',label='B'}},'C','default is not a value')
rejects({{key='A',label='A'},{key='B',label='B'}},1,'invalid MCT_Template default')
rejects({{key='A',label='A'}},'A','needs two choices')
rejects({{key='A',label='A'},{key='B',label='B'}},'A','stored picker',function(data) data.storage=nil end)
rejects({{key='A',label='A'},{key='B',label='B'}},'A','stored picker',function(data) data.fields[1].widget='text' end)
rejects({{key='A',label='A'},{key='B',label='B'}},'A','stored picker',function(data) data.fields[1].action=true end)
rejects({{key='A',label='A'},{key='B',label='B'}},'A','a switch takes',function(data) data.fields[1].widget='switch' end)
rejects(CHOICES,'None','value outside the source choices',function(data)
    data.fields[2].conditions.visible.values={'Missing'} end)
-- Tabs and cyclers take keys too.
for _,widget in ipairs({'tabs','cycler'}) do
    local data=menu(CHOICES,'None');data.fields[1].widget=widget
    assert(MenuData.manifest(data):find('mcKeys=',1,true))
end

-- The parser keeps the keys by position, and rejects a manifest that breaks them.
local items=Choices.parse(manifest)
assert(items[1].mcKeys[2]=='Fangdango_SingleUnderbar' and items[1].mcKeyIndex.Preymonition_Ring==3)
local function broken(from,to,pattern)
    local text=manifest:gsub(from:gsub('%p','%%%0'),to,1)
    fails(function() Choices.parse(text) end,pattern)
end
broken('mcKeys=None|Fangdango_SingleUnderbar|Preymonition_Ring','mcKeys=None|Fangdango_SingleUnderbar','one key per choice')
broken('mcKeys=None|','mcKeys=7|','invalid mcKeys key')
broken('mcKeys=None|Fangdango_SingleUnderbar|','mcKeys=None|None|','invalid mcKeys key')
broken('PresetValues=1|2|3','PresetValues=0|2|3','values are 1 to n')

-- Storage: the file holds keys; loading gives them back as choices; Apply saves and notifies
-- keys; an unknown or numeric stored value keeps the default and is reported.
local files={}
local store={read=function(path) return files[path] end,write=function(path,content) files[path]=content end}
local function page(id,data,directory)
    local text=MenuData.manifest(data)
    return {id=id,name=id,choices=Choices.parse(text),settingsCount=2,mcManifest=text,testOnly=false,
        mcHooks=Hooks.stored(data,store),mcHookContext={page=id,directory=directory}}
end
files['/mct/templates.ini']='[Templates]\nMCT_Template=Preymonition_Ring\nMCT_Size=1\n'
local mct=page('MCT',menu(CHOICES,'Fangdango_SingleUnderbar'),'/mct')
local model=Choices.open(mct)
assert(not model.error,model.error)
assert(model.pending[1]==3 and model.committed[1]==3 and model.pending[2]==1,'the stored key loads as its choice')
model:set(1,2)
local ok,warning,event=model:apply()
assert(ok and not warning,warning)
assert(files['/mct/templates.ini']:find('MCT_Template=Fangdango_SingleUnderbar\n',1,true),files['/mct/templates.ini'])
assert(event.values.MCT_Template=='Fangdango_SingleUnderbar' and event.values.MCT_Size==1)
assert(event.changes.MCT_Template.old=='Preymonition_Ring' and event.changes.MCT_Template.new=='Fangdango_SingleUnderbar')
-- Reordered, added and removed choices: a saved key that still exists keeps its choice.
local reordered={CHOICES[2],{key='Mod_New',label='New'},CHOICES[3],CHOICES[1]}
model=Choices.open(page('MCT2',menu(reordered,'None'),'/mct'))
assert(model.pending[1]==1 and model.items[1].mcKeys[1]=='Fangdango_SingleUnderbar','kept across a reorder')
-- A key no longer offered, or a number, keeps the default without blocking the page.
for _,stored in ipairs({'Preymonition_Gone','2'}) do
    logs={}
    files['/mct/templates.ini']='[Templates]\nMCT_Template='..stored..'\nMCT_Size=0\n'
    model=Choices.open(page('MCT3',menu(CHOICES,'Fangdango_SingleUnderbar'),'/mct'))
    assert(not model.error and model.pending[1]==2 and not model:dirty(),'default kept for '..stored)
    assert(logs[1] and logs[1]:find('HOOK_VALUES_SKIPPED MCT3: MCT_Template='..stored,1,true),table.concat(logs,'\n'))
end
-- Saving replaces it with the key.
model:set(2,1);assert(model:apply())
assert(files['/mct/templates.ini']:find('MCT_Template=Fangdango_SingleUnderbar\n',1,true))
-- Custom hooks see keys both ways; a saved key they do not offer keeps the value given.
local seen
local custom={id='Custom',name='Custom',choices=Choices.parse(manifest),settingsCount=2,testOnly=false,
    mcHookContext={page='Custom',directory='/c'},mcHooks={contract=1,
        load=function() return {MCT_Template='None'} end,
        apply=function(_,values,changes) seen={values=values,changes=changes}
            return {MCT_Template=values.MCT_Template=='None' and 'Preymonition_Ring' or 'Bogus'} end}}
model=Choices.open(custom)
assert(model.pending[1]==1)
model:set(2,1)
ok,warning,event=model:apply()
assert(ok and seen.values.MCT_Template=='None' and seen.changes.MCT_Size.new==1)
assert(model.pending[1]==3 and model.committed[1]==3 and event.values.MCT_Template=='Preymonition_Ring','saved key committed')
model:set(2,0);assert(model:apply())
assert(model.pending[1]==3 and seen.values.MCT_Template=='Preymonition_Ring','an unknown saved key keeps the value given')
-- Without storage hooks a keyed picker would be saved as a position: the page shows an error.
model=Choices.open({id='Plain',name='Plain',choices=Choices.parse(manifest),settingsCount=2,testOnly=true})
assert(model.error and model.error:find('"Template" needs a page that stores its own settings',1,true),tostring(model.error))
-- The same when DMM itself reads a stored key and rejects it: the cause is named, not DMM's error.
Choices.fs={read=function() return '[Templates]\nMCT_Template=None\n' end}
model=Choices.open({id='PlainFile',name='Plain',choices=Choices.parse(manifest),settingsCount=2,testOnly=false,
    path='/plain/mod_settings.ini'})
assert(model.error and model.error:find('needs a page that stores its own settings',1,true),tostring(model.error))
print('PASS keyed enums: compiling, parsing, storage, reorders, fallbacks, custom hooks and Apply events')

-- Slots: a keyed picker inserted into another page edits its own page's model and is saved
-- as its key there.
files['/mct/templates.ini']='[Templates]\nMCT_Template=None\nMCT_Size=0\n'
local source=page('MCT4',menu(CHOICES,'None'),'/mct')
local host=[[
[Mod]
Id=Host
[Setting.Host_Slot]
Id=Host_Slot
Type=picker
Label=Templates
Group=Visuals
PresetValues=0|1
PresetLabels=Soon|Soon
Default=0
mcReadOnly=1
mcSlot=visuals
]]
local hostPage={id='Host',name='Host',choices=Choices.parse(host),settingsCount=1,mcManifest=host,testOnly=true}
controller.inserts={[Menu.provider('Host')]={visuals={{contributor='MCT',source=source,settings={'MCT_Template'}}}}}
assert(controller:load(hostPage,function() error('no file reads') end))
assert(hostPage.choices[1].id=='MCT_Template' and hostPage.choices[1].mcSlotSource==source)
local applied={}
controller.applied=function(provider,sourceEvent) applied[#applied+1]={id=provider.id,event=sourceEvent} end
model=Choices.open(hostPage)
assert(not model.error,model.error)
assert(model.pending[1]==1)
model:change(1,2)
assert(model.pending[1]==2 and model:dirty())
ok,warning=model:apply()
assert(ok,warning)
assert(files['/mct/templates.ini']:find('MCT_Template=Fangdango_SingleUnderbar\n',1,true),files['/mct/templates.ini'])
assert(#applied==1 and applied[1].id=='MCT4' and applied[1].event.values.MCT_Template=='Fangdango_SingleUnderbar')
print('PASS keyed enums: slot rows store and publish their key through the source page')

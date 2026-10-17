package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Data=require('menu_data')
local Presentation=require('presentation')

local function fails(pattern,menu,options)
    local ok,err=pcall(Data.manifest,menu,options)
    assert(not ok,'expected failure: '..pattern)
    assert(tostring(err):find(pattern,1,true),'expected '..pattern..', got '..tostring(err))
end
local function menu()
    return {storage={file='config.ini',section='Settings'},
        groups={{id='MCT_1',label='Layout',level=3},{id='Notes',heading=false,conditions={visible={field='Style',values={1}}}}},
        fields={
            {id='Style',group='MCT_1',label='Style',default=0,tabs=true,heading=true,
                choices={{value=0,label='Swap'},{value=1,label='Stack',note='Two rows'},
                    {value=2,label='Ring',module='9_ModCore_Example'}}},
            {id='Size',group='MCT_1',label='Size',default=100,range={min=10,max=200,step=5,suffix='%'},
                description='How large; really.',conditions={label={field='Style',values={[1]='Stack size',[2]='Ring size'}}}},
            {id='Open',group='Notes',label='Open the slot',default=0,link='controls:visuals',
                choices={{value=0,label='Open'}},tabs=true,level=5},
            {id='Info',group='Notes',label='Info',default=0,readOnly=true,choices={{value=0,label='Ready'}}},
        }}
end
local text=Data.manifest(menu(),{moduleName=function(folder) return folder=='9_ModCore_Example' and 'Example Mod' end})
local function section(name)
    return assert((text..'\n'):match('%['..name:gsub('%.','%%.')..'%]\n(.-)\n\n'),'missing section '..name)
end
-- Groups keep their order and only used ones are written; a label differs from the id.
assert(text:find('[Category.MCT_1]',1,true)<text:find('[Category.Notes]',1,true))
assert(section('Category.MCT_1'):find('mcLabel=Layout',1,true) and section('Category.MCT_1'):find('mcLevel=3',1,true))
local notes=section('Category.Notes')
assert(notes:find('mcHeading=0',1,true) and notes:find('VisibleWhen=Style',1,true)
    and notes:find('VisibleValues=1',1,true) and not notes:find('mcLabel',1,true))
local style=section('Setting.Style')
assert(style:find('Type=picker',1,true) and style:find('PresetValues=0|1|2',1,true)
    and style:find('PresetLabels=Swap|Stack|Ring',1,true) and style:find('mcType=tab',1,true)
    and style:find('mcHeading=1',1,true) and style:find('mcChoiceNotes=1:Two rows;2:Example Mod',1,true)
    and style:find('ConfigFile=config.ini',1,true) and style:find('ConfigSection=Settings',1,true)
    and style:find('ConfigKey=Style',1,true))
local size=section('Setting.Size')
assert(size:find('Type=integer',1,true) and size:find('Minimum=10',1,true) and size:find('Maximum=200',1,true)
    and size:find('Step=5',1,true) and size:find('Suffix=%',1,true) and size:find('Default=100',1,true)
    and size:find('mcLabelWhen=Style',1,true) and size:find('mcLabels=1:Stack size;2:Ring size',1,true))
-- Action and read-only rows are never stored.
local open=section('Setting.Open')
assert(open:find('mcNavigation=1',1,true) and open:find('mcLinkPage=controls:visuals',1,true)
    and open:find('mcLevel=5',1,true) and not open:find('ConfigFile',1,true))
local info=section('Setting.Info')
assert(info:find('mcReadOnly=1',1,true) and not info:find('ConfigFile',1,true))
-- DMM needs two choices, so a single one repeats.
assert(open:find('PresetValues=0|1',1,true) and open:find('PresetLabels=Open|Open',1,true)
    and info:find('PresetLabels=Ready|Ready',1,true))
-- Without moduleName a module note names the folder; without storage nothing is stored.
local plain=menu();plain.storage=nil
local other=Data.manifest(plain)
assert(other:find('2:9_ModCore_Example',1,true) and not other:find('ConfigFile',1,true))

-- The manifest is what DMM and ModCoreSettings presentation read.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if choicesPath then
    local Choices=dofile(choicesPath)
    local items=Choices.parse(text)
    assert(#items==4 and items[1].id=='Style' and items[2].kind=='slider' and items[2].minimum==10,
        'DMM parses the compiled manifest')
    Presentation.parse(text,items)
    assert(items[1].mcHeader and items[1].mcTabs and items[1].mcChoiceNotes[2]=='Example Mod')
    assert(items[1].mcGroup.label=='Layout' and items[3].mcGroup.heading==false)
else
    print('SKIP DMM parse: DMM_CHOICES_PATH is not set')
end

-- Rejected menu data names its problem.
local function with(change) local m=menu();change(m);return m end
fails('unknown field',with(function(m) m.fields[1].Type='picker' end))
fails('needs choices or range',with(function(m) m.fields[2].range=nil end))
fails('default is not a choice',with(function(m) m.fields[1].default=7 end))
fails('default outside range',with(function(m) m.fields[2].default=500 end))
fails('unknown group',with(function(m) m.fields[1].group='Missing' end))
fails('duplicate field',with(function(m) m.fields[2].id='Style' end))
fails('duplicate group',with(function(m) m.groups[2].id='MCT_1' end))
fails('tabs take at most eight',with(function(m)
    for n=3,9 do m.fields[1].choices[#m.fields[1].choices+1]={value=n,label='C'..n} end end))
fails('only one heading',with(function(m) m.fields[4].heading=true end))
fails('invalid level',with(function(m) m.fields[3].level=1 end))
fails('source must be a picker',with(function(m) m.fields[2].conditions.label.field='Size' end))
fails('value outside the source choices',with(function(m) m.groups[2].conditions.visible.values={9} end))
fails('invalid Style label',with(function(m) m.fields[1].label='A|B' end))
fails('storage file must be relative',with(function(m) m.storage.file='../x.ini' end))
fails('a choice has a note or a module',with(function(m) m.fields[1].choices[2].module='X' end))
-- A choice's sound becomes the picker's mcChoiceSounds; 'none' silences that choice.
local voiced=menu()
voiced.fields[1].choices[1].sound='/Game/Audio/Swoosh'
voiced.fields[1].choices[3].sound='none'
local voicedText=Data.manifest(voiced)
assert(voicedText:find('mcChoiceSounds=0:/Game/Audio/Swoosh;2:none',1,true),'choice sounds are written')
assert(not text:find('mcChoiceSounds',1,true),'no sounds, no key')
if choicesPath then
    local items=dofile(choicesPath).parse(voicedText)
    Presentation.parse(voicedText,items)
    assert(items[1].mcChoiceSounds[0]=='/Game/Audio/Swoosh.Swoosh' and items[1].mcChoiceSounds[2]==false
        and items[1].mcChoiceSounds[1]==nil,'presentation reads the choice sounds')
end
fails('invalid choice sound',with(function(m) m.fields[1].choices[1].sound='Audio/Swoosh' end))
fails('invalid choice sound',with(function(m) m.fields[1].choices[1].sound=1 end))
-- Every presentation key a row or group takes is a menu-data property too.
local shown=menu()
shown.groups[1].help='What these do.';shown.groups[1].silent=true
shown.groups[1].conditions={visible={playerExists=false},order={field='Style',values={[{0,2}]=20,[1]=10}}}
shown.groups[1].parent={label='Display',level=3}
shown.fields[1].silent=true;shown.fields[1].conditions={dim={2}}
shown.fields[2].conditions.visible={field='Style',values={1,2},playerExists=true}
shown.fields[3].tabsWidth=200
shown.fields[4].table={entries={{code='2192',text='→'},{code='25CF',text='●'}},columns=2}
shown.fields[#shown.fields+1]={id='List',group='Notes',label='List',default=0,readOnly=true,wrap=true,
    choices={{value=0,label='a, b, c'}}}
shown.fields[#shown.fields+1]={id='Mode',group='Notes',label='Mode',default=0,cycle=true,category=true,
    choices={{value=0,label='A'},{value=1,label='B'}}}
shown.fields[#shown.fields+1]={id='Switch',group='Notes',label='Switch',default=0,onOff=true,
    choices={{value=0,label='Off'},{value=1,label='On'}}}
shown.fields[#shown.fields+1]={id='Ref',group='Notes',label='Ref',default=0,readOnly=true,tabs=true,
    referenceLabel='Key',choices={{value=0,label='Q'}}}
local shownText=Data.manifest(shown)
local function shownSection(name)
    return assert((shownText..'\n'):match('%['..name:gsub('%.','%%.')..'%]\n(.-)\n\n'),'missing section '..name)
end
local function has(name,...)
    local body=shownSection(name)
    for _,line in ipairs({...}) do assert(body:find(line,1,true),name..' lacks '..line) end
end
has('Category.MCT_1','mcHelp=What these do.','mcSilent=1','mcPlayerExists=0','mcParent=Display',
    'mcParentLevel=3','mcOrderWhen=Style','mcOrders=0:20;1:10;2:20')
has('Setting.Style','mcSilent=1','mcDimValues=2')
has('Setting.Size','VisibleWhen=Style','VisibleValues=1|2','mcPlayerExists=1')
has('Setting.Open','mcTabsWidth=200')
has('Setting.Info','mcTable=2192:→|25CF:●','mcColumns=2')
has('Setting.List','mcWrap=1')
has('Setting.Mode','mcType=cycle','mcCategory=1')
has('Setting.Switch','mcType=onoff')
has('Setting.Ref','mcType=tab','mcReferenceLabel=Key')
local entries,columns=require('menu_contributions').textTable('2192:→|25CF:●',2)
assert(#entries==2 and columns==2,'the table decodes as ModCoreSettings decodes it')
if choicesPath then
    local items=dofile(choicesPath).parse(shownText)
    Presentation.parse(shownText,items)
    local byId={}
    for _,item in ipairs(items) do byId[item.id]=item end
    assert(byId.Style.mcSilent and byId.Style.mcDimValues[2] and byId.Size.mcPlayerExists==true
        and byId.Open.mcTabsWidth==200 and byId.Info.mcTable and byId.List.mcWrap and byId.Mode.mcCycle
        and byId.Mode.mcCategory and byId.Switch.mcOnOff and byId.Ref.mcReferenceLabel=='Key','presentation reads the row properties')
    local group=byId.Style.mcGroup
    assert(group.help=='What these do.' and group.silent and group.playerExists==false
        and group.parent.label=='Display' and group.order.values[0]==20,'presentation reads the group properties')
end
fails('cycle needs choices and no tabs',with(function(m) m.fields[1].cycle=true end))
fails('onOff takes the choices 0 and 1',with(function(m) m.fields[1].onOff=true end))
fails('tabsWidth is 160 through 440',with(function(m) m.fields[3].tabsWidth=100 end))
fails('a category row takes no level',with(function(m) m.fields[3].category=true end))
fails('wrap needs a read-only row',with(function(m) m.fields[1].wrap=true end))
fails('dim value outside the choices',with(function(m) m.fields[1].conditions={dim={7}} end))
fails('a table is a read-only row',with(function(m) m.fields[1].table={entries={{code='a',text='b'}}} end))
fails('invalid table entry 1',with(function(m) m.fields[4].table={entries={{code='a:b',text='c'}}} end))
fails('table columns are 1 through 6',with(function(m) m.fields[4].table={entries={{code='a',text='b'}},columns=7} end))
fails('referenceLabel needs read-only tabs',with(function(m) m.fields[4].referenceLabel='K' end))
fails('invalid MCT_1 silent',with(function(m) m.groups[1].silent=1 end))
fails('value outside the source choices',with(function(m) m.groups[1].conditions={order={field='Style',values={[9]=1}}} end))
-- A label or order key may list values sharing one entry; a value appears once.
local folded=Data.manifest(with(function(m)
    m.fields[2].conditions.label.values={[{1,2}]='Shaped size'} end))
assert(folded:find('mcLabels=1:Shaped size;2:Shaped size',1,true),'a value list unfolds')
fails('value 1 appears twice',with(function(m)
    m.fields[2].conditions.label.values={[1]='A',[{1,2}]='B'} end))
fails('empty value list',with(function(m) m.fields[2].conditions.label.values={[{}]='A'} end))
fails('needs a field or playerExists',with(function(m) m.groups[2].conditions.visible={} end))
fails('field and values go together',with(function(m) m.groups[2].conditions.visible={field='Style'} end))
fails('unknown field visible',with(function(m) m.fields[1].visible={field='Style',values={1}} end))
fails('unknown field order',with(function(m) m.fields[1].conditions={order={field='Style',values={[0]=1}}} end))
fails('unknown field parent',with(function(m) m.groups[1].groups={{id='Sub',parent={label='X'}}} end))
fails('a read-only row needs choices and no action',with(function(m) m.fields[4].action=true end))
-- A read-only field can be the page's slot for other contributors' rows.
local slotted=menu();slotted.fields[4].slot='extras';slotted.fields[4].slotLabel=true
local slotText=Data.manifest(slotted)
local slotSection=slotText:match('%[Setting%.Info%](.-)\n\n') or slotText:match('%[Setting%.Info%](.*)$')
assert(slotSection:find('mcSlot=extras',1,true) and slotSection:find('mcSlotLabel=1',1,true)
    and slotSection:find('mcReadOnly=1',1,true) and not slotSection:find('ConfigFile',1,true))
fails('a slot is a read-only field',with(function(m) m.fields[1].slot='x' end))
fails('invalid slot',with(function(m) m.fields[4].slot='bad name' end))
fails('slotLabel needs a slot',with(function(m) m.fields[4].slotLabel=true end))
fails('slotGroups needs a slot',with(function(m) m.fields[4].slotGroups=true end))
local grouped=menu();grouped.fields[4].slot='extras';grouped.fields[4].slotGroups=true
assert(Data.manifest(grouped):find('mcSlot=extras\nmcSlotGroups=1',1,true),'slotGroups compiles to mcSlotGroups')
-- A group's groups are its subgroups: they follow its own rows, each row stays with its
-- group in declared order, and a group without rows of its own still heads its subgroups.
local nested={groups={
    {id='Outer',label='Outer',groups={{id='Inner',label='Inner'},{id='Other',label='Other'}}},
    {id='Bare',label='Bare',groups={{id='Only',label='Only'}}},
    {id='Empty',groups={{id='Unused'}}},
},fields={
    {id='A',group='Inner',label='A',default=0,readOnly=true,choices={{value=0,label='Active'}}},
    {id='B',group='Outer',label='B',default=0,readOnly=true,choices={{value=0,label='Active'}}},
    {id='C',group='Only',label='C',default=0,readOnly=true,choices={{value=0,label='Active'}}},
    {id='D',group='Inner',label='D',default=0,readOnly=true,choices={{value=0,label='Active'}}},
    {id='E',group='Other',label='E',default=0,readOnly=true,choices={{value=0,label='Active'}}},
}}
local nestedText=Data.manifest(nested)
local seen={}
for name in nestedText:gmatch('%[(%a+%.%a+)%]') do seen[#seen+1]=name end
assert(table.concat(seen,',')=='Category.Outer,Category.Inner,Category.Other,Category.Only,'
    ..'Setting.B,Setting.A,Setting.D,Setting.E,Setting.C',table.concat(seen,','))
assert(nestedText:find('[Category.Inner]\nmcWithin=Outer\n',1,true)
    and nestedText:find('[Category.Only]\nmcWithin=Bare\nmcWithinLabel=Bare\n',1,true)
    and nestedText:find('[Category.Outer]\n\n',1,true))
fails('unknown field groups',{groups={{id='X',groups={{id='Y',groups={}}}}},fields={}})
fails('duplicate group X',{groups={{id='X',groups={{id='X'}}}},fields={}})
fails('Bare: a group without rows takes no rules or presentation',{groups={{id='Bare',
    conditions={visible={field='C',values={0}}},groups={{id='Only'}}}},
    fields={{id='C',group='Only',label='C',default=0,choices={{value=0,label='A'},{value=1,label='B'}}}}})
-- Presentation reads the subgroups: subgroups of a category without rows (which DMM would
-- refuse as a section) share a heading drawn from mcWithinLabel.
local nestedItems={}
for _,id in ipairs({'B','A','D','E','C'}) do
    local group=({A='Inner',B='Outer',C='Only',D='Inner',E='Other'})[id]
    nestedItems[#nestedItems+1]={id=id,kind='picker',group=group,label=id,values={0,1},labels={'Active','Active'}}
end
Presentation.parse(nestedText,nestedItems)
assert(nestedItems[1].mcGroup.within==nil and nestedItems[2].mcGroup.within=='Outer'
    and nestedItems[2].mcGroup.parent==nil,'a subgroup of a category with rows uses its heading')
local bare=nestedItems[5].mcGroup.parent
assert(nestedItems[5].mcGroup.within=='Bare' and bare and bare.category and bare.label=='Bare',
    'a subgroup of a row-less category gets that category\'s heading as its parent')
assert(not pcall(Presentation.parse,'[Category.A]\nmcWithin=B\n[Category.B]\nmcWithin=C\n[Category.C]\n',
    {{id='X',kind='picker',group='A',label='X',values={0,1},labels={'a','b'}}}),'one level only')
assert(not pcall(Presentation.parse,'[Category.A]\nmcWithin=B\nmcWithinLabel=B\n',
    {{id='X',kind='picker',group='A',label='X',values={0,1},labels={'a','b'}},
     {id='Y',kind='picker',group='B',label='Y',values={0,1},labels={'a','b'}}}),'mcWithinLabel is for a category without rows')
print('PASS menu data compiles to the manifest DMM and presentation read, and rejects invalid data')

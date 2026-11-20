package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Data=require('menu_data')
local Hooks=require('page_hooks')
local function fails(fn,pattern)
    local ok,err=pcall(fn)
    assert(not ok and tostring(err):find(pattern,1,true),tostring(err))
end
-- A field may store under its own section and key in the menu's storage file.
local function menu(fields,storage)
    return {storage=storage==nil and {file='config.ini',section='npc.attacks'} or storage or nil,
        groups={{id='G'}},fields=fields}
end
local function enum(id,storage)
    return {id=id,group='G',label=id,values={{value=0,label='Off'},{value=1,label='On'}},default=0,storage=storage}
end
local function setting(manifest,id)
    return (manifest..'\n\n'):match('%[Setting%.'..id..'%]\n(.-)\n\n')
end
local manifest=Data.manifest(menu({
    enum('MCT_Preymonition_Omens_Enabled',{section='Preymonition.Omens',key='Enabled'}),
    enum('MCT_Preymonition_Omens_Size',{section='Preymonition.Omens'}),
    enum('Priority10Template',{key='Priority10'}),
    enum('Plain')}))
local function stores(id,section,key)
    local text=setting(manifest,id)
    assert(text:find('ConfigFile=config.ini\n',1,true) and text:find('ConfigSection='..section..'\n',1,true)
        and text:find('ConfigKey='..key,1,true),text)
end
stores('MCT_Preymonition_Omens_Enabled','Preymonition.Omens','Enabled')
stores('MCT_Preymonition_Omens_Size','Preymonition.Omens','MCT_Preymonition_Omens_Size')
stores('Priority10Template','npc.attacks','Priority10')
stores('Plain','npc.attacks','Plain')
assert(Data.address({section='S'},{id='F'})=='S' and select(2,Data.address({section='S'},{id='F',storage={key='K'}}))=='K')

-- Two fields at one section and key, field storage without the menu's, and storage on a
-- field that is never stored are rejected.
fails(function() Data.manifest(menu({enum('A',{key='Same'}),enum('B',{key='Same'})})) end,'stores at [npc.attacks] Same as A does')
fails(function() Data.manifest(menu({enum('A'),enum('B',{key='A'})})) end,'stores at [npc.attacks] A as A does')
assert(Data.manifest(menu({enum('A',{section='X',key='K'}),enum('B',{section='Y',key='K'})})),'other sections do not collide')
fails(function() Data.manifest(menu({enum('A',{key='K'})},false)) end,"field storage needs the menu's storage")
local button=enum('Go',{key='K'});button.action=true
fails(function() Data.manifest(menu({button})) end,'only stored fields take storage')
fails(function() Data.manifest(menu({enum('A',{key='a=b'})})) end,'invalid A storage key')
fails(function() Data.manifest(menu({enum('A',{other=1})})) end,'unknown field other')

-- Storage MCS keeps (ranges, keybinds, keyed pickers): each field at its own address.
local disk={['/mods/p/config.ini']='; kept\n[Preymonition.Omens]\nSpan=20|60\nOther=1\n[npc.attacks]\nSpan=bad\n'}
local files={read=function(path) return disk[path] end,write=function(path,text) disk[path]=text end}
local storedMenu=menu({
    {id='MCT_Span',group='G',label='Span',type='range',default={10,50},values={min=0,max=100,step=10},
        storage={section='Preymonition.Omens',key='Span'}},
    {id='Mode',group='G',label='Mode',values={{key='low',label='Low'},{key='high',label='High'}},default='low',
        storage={section='Preymonition.Omens'}},
    {id='Level',group='G',label='Level',values={min=0,max=10},default=5}})
assert(Data.manifest(storedMenu))
local hooks=Hooks.stored(storedMenu,files)
local context={page='P',directory='/mods/p'}
local loaded=hooks.load(context)
assert(loaded.MCT_Span=='20|60' and loaded.Mode==nil and loaded.Level==nil,'each field loads from its own address')
hooks.apply(context,{MCT_Span='30|70',Mode='high',Level=7})
assert(disk['/mods/p/config.ini']=='; kept\n[Preymonition.Omens]\nSpan=30|70\nOther=1\nMode=high\n[npc.attacks]\nSpan=bad\nLevel=7\n',
    disk['/mods/p/config.ini'])

-- Through DMM: numbers stored by DMM land at their fields' addresses, missing keys are added
-- under their sections, and a stored value is read back from its own section only.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP field storage (DMM): DMM_CHOICES_PATH is not set')
else
    local Choices=dofile(choicesPath)
    local Config=require('init_config')
    local mem={['/mods/q/config.ini']='[Preymonition.Omens]\nEnabled=1\n[npc.attacks]\nEnabled=0\n'}
    local fs={read=function(p) return mem[p] end,write=function(p,v) mem[p]=v end,
        rename=function(a,b) assert(mem[a] and not mem[b]);mem[b]=mem[a];mem[a]=nil end,
        remove=function(p) mem[p]=nil end}
    Choices.fs,Choices.sessions=fs,Choices.sessions or {}
    assert(Config.install(Choices,fs))
    local text=Data.manifest(menu({enum('MCT_Enabled',{section='Preymonition.Omens',key='Enabled'}),
        enum('Priority10Template',{key='Priority10'})}))
    local provider={id='Q',path='/mods/q/mod_settings.ini',choices=Choices.parse(text)}
    local model=Choices.open(provider)
    assert(not model.error,tostring(model.error))
    assert(model.pending[1]==1,'read from its own section, not npc.attacks')
    assert(mem['/mods/q/config.ini']=='[Preymonition.Omens]\nEnabled=1\n[npc.attacks]\nEnabled=0\nPriority10=0\n',
        mem['/mods/q/config.ini'])
    model.fs=fs
    model:set(2,1);assert(model:apply())
    assert(mem['/mods/q/config.ini']:find('Priority10=1',1,true) and mem['/mods/q/config.ini']:find('%[npc%.attacks%]\nEnabled=0'))
end
print('PASS fields store at their own section and key in the page storage file')

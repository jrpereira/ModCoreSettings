package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- Needs the real DMM parser, which CI does not have; skip without it.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP stored menu pages: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
local Data=require('menu_data')
local FieldTypes=require('field_types')
local Hooks=require('page_hooks')
local Pages=require('menu_pages')

local reports={}
local function report(event,detail) reports[#reports+1]=event..' '..tostring(detail) end
local registry=FieldTypes.new(report)
registry:register('range',require('range_editor'))
registry:install({choices=Choices,controls={build=function() return {} end}})
assert(Hooks.install(Choices,report))

-- In-memory files: the config a menu-data page stores in.
local disk={['/mods/p/config.ini']='; kept\n[Other]\nGrow=1|2\n[Templates]\nSize=40\nGrow=20|60\nUnknown=x\n'}
local writes=0
local files={read=function(path) return disk[path] end,
    write=function(path,text) writes=writes+1;disk[path]=text end}
local function menu(withSpan)
    local fields={{id='Size',group='G',label='Size',default=50,values={min=0,max=100,step=10}}}
    if withSpan then
        fields[2]={id='Grow',group='G',label='Grow',type='range',default={10,50},values={min=0,max=100,step=10,delta={10},suffix='%'}}
        fields[3]={id='Info',group='G',label='Info',default=0,widget='text',values={{value=0,label='Ready'}}}
    end
    return {storage={file='config.ini',section='Templates'},groups={{id='G'}},fields=fields}
end
local function build(withSpan)
    local providers={}
    local contribution={id='P',pages={{id='P',name='P',configDirectory='/mods/p',menu=menu(withSpan)}}}
    Pages.apply(providers,{contribution},function(content) return Choices.parse(content) end,{},report,nil,nil,
        function(data) return Data.manifest(data) end,
        function(page) return Hooks.stored(page.menu,files),Hooks.context(page) end)
    return assert(providers[1])
end

-- Numbers only: DMM keeps the page's storage.
assert(build(false).mcHooks==nil,'A page DMM can store keeps DMM storage')

-- A range: ModCoreSettings loads and saves every stored row itself.
local provider=build(true)
assert(provider.mcHooks and provider.mcHookContext.directory=='/mods/p','A page with a range gets storage hooks')
local model=Choices.open(provider)
assert(not model.error,tostring(model.error))
local index={}
for i,item in ipairs(model.items) do index[item.id]=i end
assert(model.pending[index.Size]==40 and model.pending[index.Grow]=='20|60','Stored values load: '
    ..tostring(model.pending[index.Size])..' '..tostring(model.pending[index.Grow]))
model:set(index.Grow,'30|70')
assert(model.pending[index.Grow]=='30|70','A range takes a new value')
local ok,warning,event=model:apply()
assert(ok,tostring(warning))
assert(disk['/mods/p/config.ini']=='; kept\n[Other]\nGrow=1|2\n[Templates]\nSize=40\nGrow=30|70\nUnknown=x\n',
    'Apply rewrites only its keys in its section: '..disk['/mods/p/config.ini'])
assert(event.values.Grow=='30|70' and event.values.Size==40
    and event.changes.Grow.new=='30|70' and event.changes.Size==nil,'Apply reports the stored values')
-- Missing keys keep their defaults and are added on Apply.
disk['/mods/p/config.ini']=nil
model=Choices.open(build(true))
assert(model.pending[index.Size]==50 and model.pending[index.Grow]=='10|50','Missing values keep defaults')
model:set(index.Size,60)
assert(model:apply())
assert(disk['/mods/p/config.ini']=='[Templates]\nSize=60\nGrow=10|50\n','Apply writes missing keys: '
    ..tostring(disk['/mods/p/config.ini']))
-- A stored value the range cannot hold keeps its default and is reported.
disk['/mods/p/config.ini']='[Templates]\nSize=60\nGrow=10|15\n'
model=Choices.open(build(true))
assert(model.pending[index.Grow]=='10|50' and reports[#reports]:find('HOOK_VALUES_SKIPPED',1,true),
    'An invalid range keeps its default')
print('PASS menu-data pages with a range store their values through ModCoreSettings')

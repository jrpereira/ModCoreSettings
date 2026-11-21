package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- MCS's own page as it runs in game: its keyed settings are stored by page_hooks.stored, and
-- what Apply writes is what compact_style and preview_panel read back.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP MCS page storage: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
local Data=require('menu_data')
local Hooks=require('page_hooks')
local Pages=require('menu_pages')
local Preview=require('preview_panel')
local Compact=require('compact_style')
local reports={}
local function report(event,detail) reports[#reports+1]=event..' '..tostring(detail) end
assert(Hooks.install(Choices,report))
local disk={}
local files={read=function(path) return disk[path] end,write=function(path,text) disk[path]=text end}
local providers={}
Pages.apply(providers,{{id='ModCoreSettings',pages={{id='ModCoreSettings',name='ModCore Settings',
    configDirectory='/mods/mcs',menu=require('mcs_page')}}}},
    function(content) return Choices.parse(content) end,{},report,nil,nil,
    function(menu) return Data.manifest(menu) end,
    function(page) return Hooks.stored(page.menu,files),Hooks.context(page) end)
local provider=assert(providers[1],reports[1])
assert(provider.mcHooks,'keyed settings give the page MCS storage')
local model=Choices.open(provider)
assert(not model.error,tostring(model.error))
local index={}
for i,item in ipairs(model.items) do index[item.id]=i end
local function choose(id,key)
    local item=model.items[index[id]]
    assert(item.mcKeyIndex and item.mcKeyIndex[key],id..' offers '..key)
    model:set(index[id],item.mcKeyIndex[key])
end
-- Every key each reader accepts round-trips.
for _,case in ipairs({{'everywhere','blurred','off'},{'index','dimmed','on'},{'off','off','auto'}}) do
    choose('CompactStyle',case[1]);choose('PreviewBackground',case[2]);choose('PreviewSound',case[3])
    assert(model:apply())
    local text=disk['/mods/mcs/config.ini']
    assert(Compact.style(text)==case[1],'CompactStyle '..case[1]..' reads back: '..text)
    local saved=Preview.saved(text)
    assert(saved.backdrop==case[2] and saved.sound==case[3],'preview states read back: '..text)
end
assert(#reports==0,table.concat(reports,'; '))
print('PASS MCS page keyed settings round-trip to compact_style and preview_panel')

package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- Needs the real DMM parser, which CI does not have; skip without it.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP navigation: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
local Navigation=require('navigation')
local InitConfig=require('init_config')
assert(Navigation.install(Choices))
local manifest=[[
[Mod]
Id=NavigationTest
[Category.Options]
mcHeading=0
[Setting.View]
Id=View
Type=picker
Label=View
Group=Options
PresetValues=0|1|2
PresetLabels=More|Primary|Secondary
Default=0
mcNavigation=1
mcType=tab
[Setting.Real]
Id=Real
Type=integer
Label=Real
Group=Options
Minimum=0
Maximum=10
Step=1
Default=4
ConfigFile=config.ini
ConfigSection=Settings
ConfigKey=Real
VisibleWhen=View
VisibleValues=1
]]
local items=Choices.parse(manifest)
assert(#items==2 and items[1].mcNavigation and not items[2].mcNavigation)
local path='/tmp/mc-navigation-test/config.ini'
local files={[path]='[Settings]\nReal=4\n'}
Choices.fs={
    read=function(p) return files[p] end,
    write=function(p,value) files[p]=value end,
    rename=function(a,b) assert(files[a]);files[b],files[a]=files[a],nil end,
    remove=function(p) files[p]=nil end,
}
local provider={id='NavigationTest',path='/tmp/mc-navigation-test/mod_settings.ini',choices=items}
local model=Choices.open(provider)
assert(not model.error,model.error)
assert(not model:dirty() and not model:visibility()[2])
model:set(1,1)
assert(not model:dirty() and model.pending[1]==1 and model:visibility()[2])
assert(model:apply() and files[path]=='[Settings]\nReal=4\n')
model:set(2,5)
assert(model:dirty())
local ok,why,event=model:apply()
assert(ok,why)
assert(files[path]=='[Settings]\nReal=5\n')
assert(event.values.Real==5 and event.values.View==nil and event.changes.View==nil)
assert(not model:dirty())
model:restore()
assert(model.pending[1]==1,'Restore must retain the navigation view')
model:reset()
assert(model.pending[1]==1 and model.committed[1]==1,
    'Reset must retain the current navigation view')
assert(model.pending[2]==4 and model:dirty(),
    'Reset must still reset persistent settings')
model:restore()
assert(model.pending[1]==1 and model.pending[2]==5 and not model:dirty())
local unsupported=manifest:gsub('%[Setting.View%]',
    '[Setting.Ignored]\nType=unsupported\nId=Ignored\n[Setting.View]')
local withIgnored=Choices.parse(unsupported)
assert(#withIgnored==2 and withIgnored[1].mcNavigation,
    'Unsupported settings ignored by DMM must not break navigation parsing')
local plan=assert(InitConfig.plan(provider,manifest,Choices,Choices.fs,items))
assert(not plan.content:find('View=',1,true),'config initialization must omit navigation')
local references=manifest
for slot=1,4 do
    references=references..('\n[Setting.Reference%d]\nId=Reference%d\nType=picker\nLabel=Slot %d\nGroup=References\nDefault=0\nPresetValues=0|1\nPresetLabels=Slot %d|Slot %d\nmcReadOnly=1\n'):format(slot,slot,slot+4,slot,slot)
end
local displayItems=Choices.parse(references)
local displayProvider={id=provider.id,path=provider.path,choices=displayItems}
local displayModel=Choices.open(displayProvider)
assert(not displayModel.error,displayModel.error)
for i=3,6 do
    displayModel:set(i,1)
    assert(displayModel.pending[i]==0 and not displayModel:dirty())
end
displayModel:set(2,7)
assert(displayModel:apply())
assert(files[path]=='[Settings]\nReal=7\n' and #displayModel.items==6,
    'Apply must omit every reference and restore model indices')
displayModel:reset();displayModel:restore()
assert(displayModel.pending[2]==7 and displayModel.pending[6]==0)
local displayPlan=assert(InitConfig.plan(displayProvider,references,Choices,Choices.fs,displayItems))
assert(not displayPlan.content:find('Reference',1,true),'references never receive persistent keys')

-- MCS's own page, compiled from its menu data as menu_pages compiles it.
local visuals=require('menu_data').manifest(require('mcs_page'))
local visualItems=Choices.parse(visuals)
assert(#visualItems==8)
local byId={}
for index,item in ipairs(visualItems) do
    byId[item.id]=index
    if item.id=='SortBy' or item.id=='PreferredCategoryMinimum' or item.id=='SingleCategory'
        or item.id=='ModulesPerRow' then
        assert(not item.mcNavigation and item.file=='config.ini' and item.section=='Modules')
    elseif item.id=='MCS_Extensions' or item.id=='MCS_Verifications' or item.id=='MCS_Templates' then
        -- Slots for UE4SS Lua Extensions and ModCore Templates: shown values that store nothing.
        assert(not item.mcNavigation and not item.file)
    else assert(item.mcNavigation and not item.file) end
end
local mcsPath='/mods/1_ModCore_Settings/config.ini'
-- As init_config leaves it: every key the page stores (it adds missing ones on open).
files[mcsPath]='[Modules]\nSortBy=1\nPreferredCategoryMinimum=2\nSingleCategory=0\nModulesPerRow=2\n'
local visualProvider={id='ModCoreSettings',path='/mods/1_ModCore_Settings/mod_settings.ini',choices=visualItems}
local visualModel=Choices.open(visualProvider)
assert(not visualModel.error and not visualModel:dirty())
visualModel:set(byId.MCS_Page,3)
assert(not visualModel:dirty(),'page selection remains transient')
visualModel:set(byId.SortBy,0)
assert(visualModel:dirty() and visualModel:apply(),'grouping preference is applied durably')
local reopened=Choices.open(visualProvider)
assert(not reopened.error and reopened.pending[byId.MCS_Page]==0
    and reopened.pending[byId.SortBy]==0 and reopened.pending[byId.PreferredCategoryMinimum]==2
    and reopened.pending[byId.ModulesPerRow]==2)
assert(not files[mcsPath]:find('MCS_Page',1,true),
    'navigation keys are not written beside module preferences')
print('PASS navigation remains transient and module grouping preferences persist after Apply')

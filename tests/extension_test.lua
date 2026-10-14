local loaded={}
local installs={}
local fieldTypes={registered={}}
local shared={}
ModRef={SetSharedVariable=function(_,key,value) shared[key]=value end,
    GetSharedVariable=function(_,key) return shared[key] end}
local originalLoadfile=loadfile
debug.getinfo=function() return {source='@C:/Mods/1_ModCore_Settings/Scripts/dmm_extension.lua'} end
loadfile=function(path)
    local name=assert(path:match('([^/\\]+)%.lua$'))
    -- Logging is real: it is loaded from the extension's folder before any module.
    if name=='mc_log' or name=='log_events' then return originalLoadfile(assert(path:match('Scripts/.+$'))) end
    loaded[#loaded+1]=path
    return function()
        if name=='menu_pages' then
            return {reader=function() return 'reader' end,install=function(...)
                installs[#installs+1]={name=name,args={...}}
            end}
        end
        if name=='menu_slots' then
            return {install=function(...)
                installs[#installs+1]={name=name,args={...}}
                return 'slots'
            end}
        end
        if name=='page_hooks' then
            return {loader=function() return function() return 'hooks' end end,
                context=function(page) return {page=page.id} end,
                manifest=function(_,context) return 'manifest for '..context.page end,
                install=function(...) installs[#installs+1]={name=name,args={...}} end}
        end
        if name=='field_types' then
            return {new=function()
                return {register=function(_,typeName,editor) fieldTypes.registered[typeName]=editor end,
                    install=function(_,modules) fieldTypes.modules=modules;fieldTypes.order=#installs end}
            end}
        end
        if name=='browser_groups' then
            return {folderVersion=function(mods) return 'versions in '..tostring(mods) end,
                folderManifest=function(mods) return 'manifests in '..tostring(mods) end,
                install=function(...) installs[#installs+1]={name=name,args={...}} end}
        end
        if name=='module_categories' then
            return {reader=function(index,path,read,deps)
                assert(index=='C:/Mods/1_ModCore_Settings/Scripts/../cache/modules_register.json'
                    and path=='C:/Mods/1_ModCore_Settings/Scripts/../config.ini' and deps.taxonomy and deps.json)
                return function() return {categoryRegister={}} end
            end}
        end
        if name=='mcs_taxonomy' then return {loadLua=function(path)
            assert(path=='C:/Mods/1_ModCore_Settings/Scripts/../data/module_categories.lua')
            return {version=3,data={version=3}}
        end} end
        if name=='mcs_module_json' then return {decode=function() return {} end} end
        if name=='sort_button' then return {install=function(native,path)
            assert(native==package.loaded.nativeactions and path=='C:/Mods/1_ModCore_Settings/Scripts/../config.ini')
            return 'sort button'
        end} end
        if name=='menu_contributions' then return {textTable='table decoder'} end
        if name=='dmm_lifecycle' then
            return {publisher=function() return {publish=function(_,event) installs[#installs+1]={name='publish',event=event} end} end}
        end
        return {install=function(...)
            installs[#installs+1]={name=name,args={...}}
        end}
    end
end
package.loaded.nativeactions={new=function() end}
local extension=assert(originalLoadfile('Scripts/dmm_extension.lua'))()
assert(extension.id=='ModCoreSettings' and extension.apiVersion==1 and type(extension.install)=='function')
local choices,controls,pages={},{},{}
local callbacks={}
local events={on=function(_,name,callback) callbacks[name]=callback end}
local settingsApi={}
extension.install({version=1,choices=choices,controls=controls,pages=pages,events=events,settingsApi=settingsApi})
local order={'mc_ini','mcs_manifest','safe_file','mcs_protocols','mcs_choice_sound','navigation','mapped_presets','menu_contributions','presentation','browser_groups','module_categories','mcs_taxonomy','mcs_module_json',
 'init_config','dmm_lifecycle','menu_pages','page_links','menu_slots','page_hooks','field_types','keybind_editor','standard_keys','standard_controls',
 'sort_button','menu_data','index_refresh'}
assert(#loaded==#order)
for n,name in ipairs(order) do assert(loaded[n]:match(name..'%.lua$'),'load '..n) end
-- Copied files load from Scripts/vendor; the extension's own modules from Scripts.
for n,name in ipairs(order) do
    assert((loaded[n]:find('/Scripts/vendor/',1,true)~=nil)==(name=='menu_contributions' or name=='standard_keys' or name=='safe_file' or name=='mc_ini'),'folder of '..name)
end
-- Field types install innermost, before any other wrapper.
assert(fieldTypes.order==0 and fieldTypes.registered.keybind and fieldTypes.modules.choices==choices
 and fieldTypes.modules.controls==controls and fieldTypes.modules.settingsApi==settingsApi
 and fieldTypes.modules.standardControls,'keybind registered and installed on DMM modules first')
assert(installs[1].args[1]==choices)
assert(installs[2].args[1]==choices and installs[2].args[2]==controls)
assert(installs[3].args[1]==choices and installs[3].args[2]==controls and installs[3].args[3]==pages)
assert(installs[3].args[4].textTable=='table decoder','presentation gets the mcTable decoder')
local playerExists=installs[3].args[4].playerExists
local function object(fields) fields.IsValid=function() return true end;return fields end
local pawn
-- The answer is kept for a moment: each step moves the clock past it.
local clock,seconds=os.time,0
os.time=function() return seconds end
local finds=0
FindFirstOf=function(class) assert(class=='PlayerController');finds=finds+1
    return object({K2_GetPawn=function() return pawn end}) end
assert(playerExists()==false,'a controller without a pawn is no player')
pawn=object({})
assert(playerExists()==false and finds==1,'within the moment the kept answer is used')
seconds=2
assert(playerExists()==true,'a controller with a pawn is a player')
FindFirstOf=function() return nil end
seconds=4
assert(playerExists()==false,'no controller is no player')
FindFirstOf=nil;os.time=clock
assert(installs[4].args[1]==pages and type(installs[4].args[3])=='function'
    and installs[4].args[4]=='versions in C:/Mods/' and installs[4].args[5]=='manifests in C:/Mods/','browser groups get the parser and the Mods folder')
assert(type(installs[4].args[6])=='function','browser groups read category and grouping preferences')
assert(installs[4].args[8]=='sort button','the filter button sorts')
assert(installs[5].args[1]==choices)
assert(installs[6].name=='page_hooks' and installs[6].args[1]==choices,
 'hooks storage wraps open before the slot model')
assert(installs[7].name=='menu_slots' and installs[7].args[1]==choices and type(installs[7].args[3])=='table',
 'slot open wraps outermost so inner wrappers see the host page unspliced')
assert(installs[8].name=='menu_pages' and installs[8].args[1]==pages and installs[8].args[3]=='reader',
 'menu pages wrap after browser groups so contributions exist before grouping')
assert(installs[8].args[5]=='slots' and type(installs[8].args[6])=='function','menu pages drive slot splicing')
local hooks,manifest,context=installs[8].args[7]({id='MCC',hooks='/m/hooks.lua'})
assert(hooks=='hooks' and manifest=='manifest for MCC' and context.page=='MCC',
 'menu pages receive a hooks resolver for hooks pages')
assert(installs[9].name=='page_links' and installs[9].args[1]==pages)
assert(installs[10].name=='index_refresh' and installs[10].args[1]==pages
 and type(installs[10].args[2])=='function','the index refresh wraps outermost')
for _,name in ipairs({'providerPrepared','providerRefreshed','hostClosing'}) do
 assert(type(callbacks[name])=='function');callbacks[name]({});assert(installs[#installs].event==name)
end
assert(shared['MC_DMM_Extension_v1.ready']=='1')
assert(not pcall(extension.install,{version=2,choices=choices,controls=controls,pages=pages,events=events}))
assert(not pcall(extension.install,{version=1,choices=choices,controls=controls,events=events}))
print('PASS pure-Lua DMM extension loads owned modules in order and rejects incompatible APIs')

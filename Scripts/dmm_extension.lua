-- Runs inside DMM's Lua state. The launcher that replaces DMM's main.lua calls
-- launch() before running DMM's own main, so every hook is on DMM's module tables
-- before DMM uses them. Keep this file self-contained: the ordinary
-- ModCoreSettings mod runs in a different state.
local source=assert(debug.getinfo(1,'S').source,'extension source unavailable')
local directory=assert(source:match('^@(.+[\\/])[^\\/]+$'),'extension directory unavailable')

local function module(name)
    local chunk,err=loadfile(directory..name..'.lua')
    assert(chunk,err)
    local value=chunk()
    assert(type(value)=='table',name..' did not return a module')
    return value
end

-- Events are written at their level; log_level.txt in the mod folder sets it (WARN without it).
local report=(function()
    local root=directory:match('^(.*)[/\\]Scripts[/\\]$')
    local logger=module('vendor/mc_log').new({name='ModCoreSettings',path=root and root..'/log_level.txt'})
    return module('log_events').reporter(logger)
end)()

-- Whether a player is in the world: a player controller possessing a pawn. The main menu
-- has none. DMM asks on every visibility check of a gated page; FindFirstOf searches the
-- object array, so the answer is kept for a moment, far shorter than any menu visit. The
-- clock is os.time, whole wall-clock seconds (os.clock is CPU time, which runs ahead of
-- real time in a threaded game), so two seconds keep the answer between one and two.
local PLAYER_CHECK_SECONDS=2
local playerChecked,playerFound
local function playerExists()
    local now=os.time()
    if playerChecked and now-playerChecked<PLAYER_CHECK_SECONDS then return playerFound end
    local controller=FindFirstOf('PlayerController')
    local pawn=controller and controller:IsValid() and controller:K2_GetPawn()
    playerChecked,playerFound=now,pawn~=nil and pawn~=false and pawn:IsValid()==true
    return playerFound
end

local extension
extension={
    id='ModCoreSettings',
    apiVersion=1,
    -- Loads DMM's modules ahead of DMM's main, recreates its lifecycle events,
    -- then installs exactly as before.
    launch=function()
        local events=module('dmm_events')
        local controls=require('controls')
        local bus=events.bus(report)
        events.attach({controls=controls,nativeactions=require('nativeactions')},bus,report)
        extension.install({version=1,choices=require('choices'),controls=controls,
            pages=require('pages'),events=bus,settingsApi=require('dmm_api')})
    end,
    install=function(dmm)
        assert(type(dmm)=='table' and dmm.version==1,'unsupported DMM extension API')
        assert(type(dmm.choices)=='table' and type(dmm.controls)=='table' and type(dmm.pages)=='table',
            'DMM extension modules unavailable')
        -- The manifest reader the modules below share; DMM's require resolves in DMM's
        -- folder, so it is placed in package.loaded under a name only this mod uses.
        package.loaded.mc_ini=module('vendor/mc_ini')
        package.loaded.mcs_manifest=module('mcs_manifest')
        -- The crash-safe file reader and replacer shared by the modules below.
        local io_=module('vendor/safe_file')
        package.loaded.safe_file=io_
        -- The hidden-widget text formats MCS's two states share.
        package.loaded.mcs_protocols=module('mcs_protocols')
        -- A picker choice's own sound (mcChoiceSounds), for the presentation below.
        package.loaded.mcs_choice_sound=module('mcs_choice_sound')
        local navigation=module('navigation')
        local mapped=module('mapped_presets')
        local contributions=module('vendor/menu_contributions')
        -- Menu data unfolds value lists with the contributors' own client.
        package.loaded.menu_contributions=contributions
        local presentation=module('presentation')
        local browserGroups=module('browser_groups')
        local moduleCategories=module('module_categories')
        local taxonomyModule=module('mcs_taxonomy')
        local indexJson=module('mcs_module_json')
        -- The browser decodes each mod.json with the same reader as the boot index.
        package.loaded.mcs_module_json=indexJson
        local taxonomy=taxonomyModule.loadLua(directory..'../data/module_categories.lua')
        local config=module('init_config')
        local lifecycle=module('dmm_lifecycle')
        local menuPages=module('menu_pages')
        local pageLinks=module('page_links')
        local menuSlots=module('menu_slots')
        local pageHooks=module('page_hooks')
        assert(type(mapped.install)=='function','mapped preset installer unavailable')
        assert(type(presentation.install)=='function','presentation installer unavailable')
        assert(type(config.install)=='function','configuration installer unavailable')
        assert(type(dmm.events)=='table' and type(dmm.events.on)=='function','DMM lifecycle events unavailable')
        assert(type(lifecycle.publisher)=='function','lifecycle publisher unavailable')
        -- Innermost: every other wrapper sees this module's settings among DMM's own.
        local fieldTypes=module('field_types').new(report)
        local keybind=module('keybind_editor')
        fieldTypes:register('keybind',keybind)
        fieldTypes:install({choices=dmm.choices,controls=dmm.controls,settingsApi=dmm.settingsApi,
            standardControls=(function()
                -- The shared key rule, vendored like menu_contributions; DMM's require
                -- resolves in DMM's folder, so standard_controls finds it here.
                package.loaded.standard_keys=module('vendor/standard_keys')
                return module('standard_controls')
            end)()})
        navigation.install(dmm.choices)
        mapped.install(dmm.choices,dmm.controls)
        presentation.install(dmm.choices,dmm.controls,dmm.pages,{keyColumn=keybind.layout,
            textTable=contributions.textTable,playerExists=playerExists,events=dmm.events})
        local mods=directory:match('^(.*[/\\])[^/\\]+[/\\]Scripts[/\\]$')
        local folderManifest=browserGroups.folderManifest(mods)
        -- DMM's mod-list filter button becomes Sort by, saved in this mod's config.ini.
        local sortButton=module('sort_button').install(require('nativeactions'),directory..'../config.ini',
            io_.read,io_.write,report)
        local function read(path)
            return assert(io_.read(path),'unreadable '..path)
        end
        browserGroups.install(dmm.pages,report,function(content) return dmm.choices.parse(content) end,
            browserGroups.folderVersion(mods),folderManifest,
            moduleCategories.reader(directory..'../cache/modules_register.json',directory..'../config.ini',nil,
                {taxonomy=taxonomy,json=indexJson,report=report,
                    seenPath=directory..'../cache/folder_info.json'}),read,sortButton)
        config.install(dmm.choices)
        assert(ModRef and type(ModRef.GetSharedVariable)=='function','DMM shared variables unavailable')
        -- Hooks storage sits inside the slot model, which must stay outermost.
        pageHooks.install(dmm.choices,report)
        local loadHooks=pageHooks.loader()
        -- A mod folder's name as the browser shows it: its mod.json name, else the folder.
        local function moduleName(folder)
            local ok,fields=pcall(folderManifest or error,folder)
            return ok and type(fields)=='table' and fields.name or folder
        end
        local menuData=module('menu_data')
        local function compile(menu)
            return menuData.manifest(menu,{moduleName=moduleName})
        end
        local function hooked(page)
            local hooks=loadHooks(page.hooks)
            local context=pageHooks.context(page)
            context.moduleName=moduleName
            return hooks,pageHooks.manifest(hooks,context,compile),context
        end
        -- Outermost open: inner wrappers only ever see the host's own unspliced settings.
        local slots=menuSlots.install(dmm.choices,report,contributions,read)
        -- Wrapped after browser groups so contributed pages exist before ModCore grouping runs.
        menuPages.install(dmm.pages,function(content) return dmm.choices.parse(content) end,
            menuPages.reader(contributions,ModRef,read,report),report,slots,read,hooked,compile)
        pageLinks.install(dmm.pages,slots)
        -- Outermost: a rebuild after Apply runs every wrapper above with DMM's arguments.
        module('index_refresh').install(dmm.pages,report)
        local publisher=lifecycle.publisher(report)
        for _,name in ipairs({'providerPrepared','providerRefreshed','hostClosing'}) do
            dmm.events:on(name,function(context) publisher:publish(name,context) end)
        end
        assert(ModRef and type(ModRef.SetSharedVariable)=='function','DMM extension handshake unavailable')
        ModRef:SetSharedVariable('MC_DMM_Extension_v1.ready','1')
    end,
}
return extension

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
    -- Loads DMM's modules ahead of DMM's main and hooks them.
    launch=function()
        return extension.install(require('choices'),require('controls'),require('pages'),
            require('nativeactions'),require('dmm_api'))
    end,
    -- DMM's choices, controls, pages, nativeactions and dmm_api modules.
    install=function(choices,controls,pages,native,settingsApi)
        -- First load every module and check every precondition; DMM's modules are only
        -- wrapped once all of them hold, so a broken install wraps nothing.
        assert(type(choices)=='table' and type(controls)=='table' and type(pages)=='table',
            'DMM extension modules unavailable')
        assert(type(native)=='table' and type(native.new)=='function','DMM native actions unavailable')
        assert(ModRef and type(ModRef.GetSharedVariable)=='function','DMM shared variables unavailable')
        assert(type(ModRef.SetSharedVariable)=='function','DMM extension handshake unavailable')
        -- DMM's menu-closing event, recreated on its modules.
        local events=module('dmm_events')
        -- The manifest reader the modules below share; DMM's require resolves in DMM's
        -- folder, so it is placed in package.loaded under a name only this mod uses.
        package.loaded.mc_ini=module('vendor/mc_ini')
        package.loaded.mcs_manifest=module('mcs_manifest')
        -- The crash-safe file reader and replacer shared by the modules below.
        local io_=module('vendor/safe_file')
        package.loaded.safe_file=io_
        -- A picker choice's own sound (mcChoiceSounds), for the presentation below.
        package.loaded.mcs_choice_sound=module('mcs_choice_sound')
        local navigation=module('navigation')
        local mapped=module('mapped_presets')
        local contributions=module('vendor/menu_contributions')
        -- Menu data unfolds value lists with the contributors' own client.
        package.loaded.menu_contributions=contributions
        local presentation=module('presentation')
        -- Whether each module's dependencies are loaded, for the browser's requirement marks.
        package.loaded.mod_requirements=module('mod_requirements')
        local browserGroups=module('browser_groups')
        local moduleCategories=module('module_categories')
        local taxonomyModule=module('mcs_taxonomy')
        local indexJson=module('mcs_module_json')
        -- The browser decodes each mod.json with the same reader as the boot index.
        package.loaded.mcs_module_json=indexJson
        local taxonomy=taxonomyModule.loadLua(directory..'../data/module_categories.lua')
        local config=module('init_config')
        local menuPages=module('menu_pages')
        local pageLinks=module('page_links')
        local menuSlots=module('menu_slots')
        local pageHooks=module('page_hooks')
        local fieldTypesModule=module('field_types')
        local keybind=module('keybind_editor')
        -- Menu data checks span fields with the same editor.
        package.loaded.range_editor=module('range_editor')
        local editorInputModule=module('editor_input')
        local editorHint=module('editor_hint')
        -- The shared key rule, vendored like menu_contributions; DMM's require resolves in
        -- DMM's folder, so standard_controls finds it here.
        package.loaded.standard_keys=module('vendor/standard_keys')
        local standardControls=module('standard_controls')
        local settingsNotify=module('settings_notify')
        local sortButtonModule=module('sort_button')
        local menuData=module('menu_data')
        local indexRefresh=module('index_refresh')
        assert(type(mapped.install)=='function','mapped preset installer unavailable')
        assert(type(presentation.install)=='function','presentation installer unavailable')
        assert(type(config.install)=='function','configuration installer unavailable')

        local bus=events.bus(report)
        events.attach({controls=controls,nativeactions=native},bus,report)
        -- Innermost: every other wrapper sees this module's settings among DMM's own.
        local fieldTypes=fieldTypesModule.new(report)
        fieldTypes:register('keybind',keybind)
        fieldTypes:register('range',package.loaded.range_editor)
        -- Enter and A for editors that take the row's keys, and their footer hint. UE4SS's
        -- FName is callable userdata, not a function.
        local editorInput=editorInputModule.new({register=RegisterKeyBind,keys=Key,
            key=FName~=nil and function(name) return {KeyName=FName(name)} end or nil})
        fieldTypes:install({choices=choices,controls=controls,settingsApi=settingsApi,
            confirm=editorInput,pointer=editorInput.pointer,
            hint=editorHint.install(native,pages,FName~=nil and FName or nil),
            standardControls=standardControls})
        -- Outside field types' numbers-only filter: v2 subscribers also get text values.
        settingsNotify.install(settingsApi,report)
        navigation.install(choices)
        mapped.install(choices,controls)
        presentation.install(choices,controls,pages,{keyColumn=keybind.layout,
            textTable=contributions.textTable,playerExists=playerExists,events=bus})
        local mods=directory:match('^(.*[/\\])[^/\\]+[/\\]Scripts[/\\]$')
        local folderManifest=browserGroups.folderManifest(mods)
        -- DMM's mod-list filter button becomes Sort by, saved in this mod's config.ini.
        local sortButton=sortButtonModule.install(native,directory..'../config.ini',
            io_.read,io_.write,report)
        local function read(path)
            return assert(io_.read(path),'unreadable '..path)
        end
        browserGroups.install(pages,report,function(content) return choices.parse(content) end,
            browserGroups.folderVersion(mods),folderManifest,
            moduleCategories.reader(directory..'../cache/modules_register.json',directory..'../config.ini',nil,
                {taxonomy=taxonomy,json=indexJson,report=report,
                    seenPath=directory..'../cache/folder_info.json'}),read,sortButton)
        config.install(choices)
        -- Hooks storage sits inside the slot model, which must stay outermost.
        pageHooks.install(choices,report)
        local loadHooks=pageHooks.loader()
        -- A mod folder's name as the browser shows it: its mod.json name, else the folder.
        local function moduleName(folder)
            local ok,fields=pcall(folderManifest or error,folder)
            return ok and type(fields)=='table' and fields.name or folder
        end
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
        local slots=menuSlots.install(choices,report,contributions,read)
        -- Wrapped after browser groups so contributed pages exist before ModCore grouping runs.
        local function stored(page)
            return pageHooks.stored(page.menu),pageHooks.context(page)
        end
        menuPages.install(pages,function(content) return choices.parse(content) end,
            menuPages.reader(contributions,ModRef,read,report),report,slots,read,hooked,compile,stored)
        pageLinks.install(pages,slots)
        -- Outermost: a rebuild after Apply runs every wrapper above with DMM's arguments.
        indexRefresh.install(pages,report)
        ModRef:SetSharedVariable('MC_DMM_Extension_v1.ready','1')
    end,
}
return extension

-- Page hooks: a contributed page may name a Lua file that ModCoreSettings loads in DMM's
-- state. The file generates the page's manifest on each menu build and may own the page's
-- storage. It sees only setting ids and values, never DMM's providers or models.
--
-- A hooks file returns:
--   {contract=1,
--    manifest=function(context) return '<settings manifest text>' end,
--    -- or menu=function(context) return <menu data, see menu_data.lua> end,
--    load=function(context) return {[settingId]=value,...} end,                 -- optional
--    apply=function(context,values,changes) return savedValues,warning end,   -- with load
--    action=function(context,id,value,values) end}                            -- optional
-- context={page=<page id>,directory=<configDirectory>}; manifest() and menu() also get
-- moduleName(folder), a mod folder's name as the mod browser shows it. values holds every stored setting
-- by id (mcNavigation and mcReadOnly rows are left out);
-- changes holds {old=,new=} for edited settings. apply raises to reject the Apply. The
-- values it returns become the committed values; ids it omits keep the values it was given.
-- action runs when a navigation row (not a page link) is set, even to its current value,
-- as a click on a single-button row does: id and value are that row's, and values holds
-- every row's current value by id. An error is logged and the page carries on.
local M={contract=1}

local function directoryOf(path) return assert(path:match('^(.*)[/\\][^/\\]+$'),'invalid hooks path') end

-- Returns load(path) -> hooks table. Each path is loaded once per session; a failure is
-- remembered too, so a broken file is reported once and not re-run on every build.
function M.loader(loadfile)
    loadfile=loadfile or _G.loadfile
    local cache,paths={},{}
    return function(path)
        local entry=cache[path]
        if not entry then
            local ok,result=pcall(function()
                local directory=directoryOf(path)
                -- Hooks files require modules beside them, as they would in their own mod.
                if not paths[directory] then
                    package.path=directory..'/?.lua;'..package.path
                    paths[directory]=true
                end
                local chunk=assert(loadfile(path))
                local hooks=chunk()
                assert(type(hooks)=='table','hooks file must return a table')
                assert(hooks.contract==M.contract,'unsupported hooks contract '..tostring(hooks.contract))
                assert((hooks.manifest==nil)~=(hooks.menu==nil),'hooks need manifest() or menu()')
                assert(type(hooks.manifest or hooks.menu)=='function','hooks manifest() or menu() must be a function')
                assert((hooks.load==nil)==(hooks.apply==nil),'hooks need both load() and apply(), or neither')
                assert(hooks.load==nil or (type(hooks.load)=='function' and type(hooks.apply)=='function'),
                    'hooks load() and apply() must be functions')
                assert(hooks.action==nil or type(hooks.action)=='function','hooks action() must be a function')
                return hooks
            end)
            entry={ok=ok,result=result};cache[path]=entry
        end
        if not entry.ok then error(entry.result,0) end
        return entry.result
    end
end

function M.context(page)
    return {page=page.id,directory=page.configDirectory}
end

-- Runs a page's manifest or menu hook; compile(menu) turns menu data into manifest text.
-- Errors propagate so the contributor is skipped.
function M.manifest(hooks,context,compile)
    local copy={page=context.page,directory=context.directory,moduleName=context.moduleName}
    if hooks.menu then
        assert(compile,'menu data unavailable')
        local menu=hooks.menu(copy)
        assert(type(menu)=='table','menu() must return menu data')
        return compile(menu)
    end
    local text=hooks.manifest(copy)
    assert(type(text)=='string' and not text:find('%z'),'manifest() must return text')
    return text
end

-- Storage hooks for a menu-data page whose storage DMM cannot keep: every stored field's
-- value under menu.storage.section in menu.storage.file, relative to the page's
-- configDirectory. A range's value is its text; every other value is a number. A missing
-- file or key keeps the default; Apply adds missing keys and keeps every other byte.
-- files (optional) is {read=,write=}, safe_file's by default.
function M.stored(menu,files)
    local Ini=require('mc_ini')
    files=files or require('safe_file')
    local storage=menu.storage
    local fields={}
    for _,field in ipairs(menu.fields or {}) do
        local shown=field.widget=='text' or field.widget=='table'
        if not (field.action or field.link or shown) then fields[#fields+1]=field end
    end
    local function path(context)
        assert(type(context.directory)=='string' and context.directory~='','storage needs a configDirectory')
        return context.directory:gsub('[/\\]+$','')..'/'..storage.file
    end
    local function text(value)
        if type(value)=='string' then return value end
        return math.type(value)=='integer' and tostring(value)
            or value%1==0 and string.format('%d',value) or string.format('%.17g',value)
    end
    return {contract=M.contract,
        load=function(context)
            local content=files.read(path(context))
            if not content then return {} end
            local found,values={},{}
            for _,entry in ipairs(Ini.entries(Ini.parse(content),storage.section)) do
                if not found[entry.key] then found[entry.key]=entry.value end
            end
            for _,field in ipairs(fields) do
                local value=found[field.id]
                if value~=nil then values[field.id]=field.type=='range' and value or tonumber(value) or value end
            end
            return values
        end,
        apply=function(context,values)
            local file=path(context)
            local original=files.read(file) or ''
            local content=original
            for _,field in ipairs(fields) do
                if values[field.id]~=nil then content=Ini.set(content,storage.section,field.id,text(values[field.id])) end
            end
            if content~=original then files.write(file,content) end
            return values
        end}
end

-- A loaded value the setting accepts, in canonical form; nil when it accepts none.
local function accepted(choices,item,value)
    local ok,index=pcall(choices.index,item,value)
    if ok and index then return value end
    local normalized=choices.mcNormalize and choices.mcNormalize(item,value)
    if normalized==nil then return nil end
    ok,index=pcall(choices.index,item,normalized)
    if ok and index then return normalized end
end

-- Wraps choices.open so a page with storage hooks keeps its values out of DMM's config IO.
-- DMM still provides editing, navigation and the Apply flow.
-- report(event,detail) (optional) receives stored values that fall back to defaults.
function M.install(choices,report)
    if choices.mcHooksVersion then return false end
    report=report or function() end
    local open=choices.open
    -- Setting a navigation row runs the page's action hook.
    local function actions(model,hooks,context)
        if not hooks.action or model.error then return model end
        local set=model.set
        function model:set(i,value,...)
            local results=table.pack(set(self,i,value,...))
            local item=self.items[i]
            if item and item.mcNavigation and not item.mcLinkPage then
                local values={}
                for n,other in ipairs(self.items) do values[other.id]=self.pending[n] end
                local ok,why=pcall(hooks.action,{page=context.page,directory=context.directory},
                    item.id,self.pending[i],values)
                if not ok then report('HOOK_ACTION_FAILED',context.page..' '..item.id..': '..tostring(why)) end
            end
            return table.unpack(results,1,results.n)
        end
        return model
    end
    choices.open=function(provider)
        local hooks=provider.mcHooks
        if not hooks then return open(provider) end
        if not hooks.apply then return actions(open(provider),hooks,provider.mcHookContext) end
        local context=provider.mcHookContext
        local copy={}
        for key,value in pairs(provider) do copy[key]=value end
        -- testOnly keeps DMM's model in session memory; the hooks own the file.
        copy.testOnly=true
        local model=open(copy)
        model.provider=provider
        if not model.error then
            local ok,why=pcall(function()
                local values=hooks.load({page=context.page,directory=context.directory})
                assert(type(values)=='table','load() must return a table')
                -- An invalid stored value keeps the default; saving the page replaces it.
                local skipped={}
                for i,item in ipairs(model.items) do
                    local value=values[item.id]
                    if value~=nil then
                        local usable=accepted(choices,item,value)
                        if usable~=nil then model.pending[i],model.committed[i]=usable,usable
                        else skipped[#skipped+1]=item.id..'='..tostring(value) end
                    end
                end
                if #skipped>0 then
                    report('HOOK_VALUES_SKIPPED',context.page..': '..table.concat(skipped,', ')..'; defaults kept')
                end
            end)
            if not ok then model.error=tostring(why) end
        end
        function model:apply()
            if self.error then return false,self.error end
            -- Navigation and read-only rows are never stored, as in navigation.lua.
            local function stored(item) return not item.mcNavigation and not item.mcReadOnly end
            local values,changes={},{}
            for i,item in ipairs(self.items) do
                if stored(item) then
                    values[item.id]=self.pending[i]
                    if self.pending[i]~=self.committed[i] then
                        changes[item.id]={old=self.committed[i],new=self.pending[i]}
                    end
                end
            end
            local ok,saved,warning=pcall(hooks.apply,{page=context.page,directory=context.directory},values,changes)
            if not ok then return false,tostring(saved) end
            if type(saved)~='table' then return false,'apply() must return the saved values' end
            local event={values={},changes=changes}
            for i,item in ipairs(self.items) do
                if stored(item) then
                    local value=saved[item.id]
                    if value~=nil then self.pending[i]=value end
                    event.values[item.id]=self.pending[i]
                end
                self.committed[i]=self.pending[i]
            end
            return true,warning~=nil and tostring(warning) or nil,event
        end
        return actions(model,hooks,context)
    end
    choices.mcHooksVersion=1
    return true
end

return M

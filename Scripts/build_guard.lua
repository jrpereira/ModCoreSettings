-- Runs in DMM's Lua state. DMM runs its tick under pcall and stops for the whole session on
-- any error, so an error raised by a ModCoreSettings wrapper while a page is built, or by a
-- settings panel method, would take the menu down with it. The guard catches the first such
-- error, reports it once and from then on lets DMM build its own page from its own list of
-- mods, for the rest of the session. It writes nothing: config stays as it is.
--
-- new() goes on DMM's modules before any other wrapper and keeps DMM's own builds and
-- panel methods; install() goes on after every wrapper it guards.
local M={version=1}

-- DMM's order for its list of mods (providers.lua, sort).
local function before(a,b)
    if a.testOnly~=b.testOnly then return not a.testOnly end
    local an,bn=tostring(a.name or ''):lower(),tostring(b.name or ''):lower()
    if an~=bn then return an<bn end
    return tostring(a.id)<tostring(b.id)
end

local function traced(err) return debug.traceback(tostring(err),2) end

-- pages, controls: DMM's modules, still unwrapped. report(event,detail) (optional).
function M.new(pages,controls,report)
    assert(type(pages)=='table' and type(pages.build)=='function','DMM pages API unavailable')
    assert(type(controls)=='table' and type(controls.build)=='function','DMM controls API unavailable')
    report=report or function() end
    local guard={failed=false,panelsFailed=false}
    local dmmPages,dmmControls=pages.build,controls.build
    -- DMM's own methods of each settings panel, and how often each has run: a method that
    -- fails after DMM's own already ran is not run a second time.
    local own=setmetatable({},{__mode='k'})
    controls.build=function(tree,providers,api)
        local ui=dmmControls(tree,providers,api)
        if type(ui)~='table' then return ui end
        local record={methods={},counted={},calls={}}
        for key,method in pairs(ui) do
            if type(method)=='function' then
                record.methods[key],record.calls[key]=method,0
                local counted=function(...) record.calls[key]=record.calls[key]+1;return method(...) end
                record.counted[key]=counted
                ui[key]=counted
            end
        end
        own[ui]=record
        return ui
    end

    function guard:fail(where,err)
        if self.failed then return end
        self.failed=true
        report('MCS_BUILD_FAILED',where..': '..tostring(err))
    end

    function guard:install()
        local chain,panels=pages.build,controls.build
        -- DMM's list as it first reached the guard, before any wrapper changed it.
        local lists=setmetatable({},{__mode='k'})
        local function fallback(tree,providers,status,api)
            local saved=type(providers)=='table' and lists[providers]
            if saved then
                for index=#providers,1,-1 do providers[index]=nil end
                for index,provider in ipairs(saved) do providers[index]=provider end
                providers.mcModuleCount,providers.mcFolded,providers.mcFoldedAt=nil,nil,nil
                table.sort(providers,before)
            end
            return dmmPages(tree,providers,status,api)
        end
        pages.build=function(tree,providers,status,api)
            if guard.failed then return fallback(tree,providers,status,api) end
            if type(providers)=='table' and not lists[providers] then
                local saved={}
                for index,provider in ipairs(providers) do saved[index]=provider end
                lists[providers]=saved
            end
            local ok,page=xpcall(chain,traced,tree,providers,status,api)
            if ok and not guard.failed then return page end
            if not ok then guard:fail('page build',page) end
            return fallback(tree,providers,status,api)
        end
        controls.build=function(tree,providers,api)
            if guard.panelsFailed then return dmmControls(tree,providers,api) end
            local ok,ui=xpcall(panels,traced,tree,providers,api)
            if not ok then
                guard.panelsFailed=true
                guard:fail('settings panel build',ui)
                return dmmControls(tree,providers,api)
            end
            local record=type(ui)=='table' and own[ui]
            if not record then return ui end
            for key,dmm in pairs(record.methods) do
                local current=ui[key]
                if type(current)=='function' and current~=record.counted[key] then
                    ui[key]=function(...)
                        if guard.panelsFailed then return dmm(...) end
                        local calls=record.calls[key]
                        local results=table.pack(xpcall(current,traced,...))
                        if results[1] then return table.unpack(results,2,results.n) end
                        guard.panelsFailed=true
                        guard:fail('settings panel '..tostring(key),results[2])
                        if record.calls[key]==calls then return dmm(...) end
                    end
                end
            end
            return ui
        end
        return true
    end
    return guard
end

return M

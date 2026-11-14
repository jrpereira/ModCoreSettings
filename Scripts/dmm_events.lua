-- Runs in DMM's Lua state. Recreates DMM's menu-closing boundary without editing DMM: it
-- wraps the settings panel that controls.build returns (its hide) and DMM's native-actions
-- owner, whose close() is the first step of closing the menu host. Every emission is
-- guarded so a failing listener never breaks DMM.
local M={version=1}
local names={hostClosing=true}

function M.bus(report)
    report=report or function() end
    local bus={handlers={}}
    function bus:on(name,callback)
        assert(names[name],'unsupported lifecycle event')
        assert(type(callback)=='function','lifecycle callback must be a function')
        local handlers=self.handlers[name] or {}
        self.handlers[name]=handlers
        handlers[#handlers+1]=callback
    end
    function bus:emit(name,context)
        for _,callback in ipairs(self.handlers[name] or {}) do
            local ok,err=pcall(callback,context)
            if not ok then report('LIFECYCLE_CALLBACK_FAILED',name..': '..tostring(err)) end
        end
    end
    return bus
end

-- Returns every value of a call, so wrappers stay transparent.
local function pass(...) return select('#',...),{...} end

function M.attach(modules,bus,report)
    report=report or function() end
    local function emit(name,context)
        local ok,err=pcall(bus.emit,bus,name,context)
        if not ok then report('LIFECYCLE_EMIT_FAILED',name..': '..tostring(err)) end
    end
    local controls=assert(modules.controls,'DMM controls unavailable')
    local build=assert(controls.build,'DMM controls.build unavailable')
    controls.build=function(tree,providers,api)
        local ui=build(tree,providers,api)
        local pc=api and api.pc
        local hide=ui.hide
        function ui:hide(...)
            local n,results=pass(hide(self,...))
            emit('hostClosing',{tree=tree,pc=pc})
            return table.unpack(results,1,n)
        end
        return ui
    end
    local native=modules.nativeactions
    if native and type(native.new)=='function' and type(native.close)=='function' then
        local new,close=native.new,native.close
        local host
        native.new=function(pc,tree,...)
            host={pc=pc,tree=tree}
            return new(pc,tree,...)
        end
        native.close=function(...)
            local n,results=pass(close(...))
            if host then emit('hostClosing',{tree=host.tree,pc=host.pc});host=nil end
            return table.unpack(results,1,n)
        end
    else
        report('LIFECYCLE_PARTIAL','DMM native actions unavailable; menu close is not reported')
    end
end

return M

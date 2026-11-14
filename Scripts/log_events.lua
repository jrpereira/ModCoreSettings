-- ModCoreSettings reports named events, as report(EVENT, detail). This maps each event to a
-- log level and writes it through a leveled mc_log logger. Used in both Lua states: the
-- mod's own and DMM's.
local M={}
local levels={
    -- Each of these leaves ModCoreSettings without its DMM integration.
    DMM_REQUIRED='error',DMM_LAUNCHER_FAILED='error',DMM_HOOKS_FAILED='error',
    DMM_INITIALIZATION_FAILED='error',DMM_BINDING_UNAVAILABLE='error',
    DMM_RESTART_REQUIRED='warn',DMM_DUPLICATE_INIT='warn',DMM_HANDSHAKE_FAILED='warn',
    DMM_LAUNCHER_INSTALLED='info',
    LIFECYCLE_PARTIAL='warn',
    -- A wrapper failed while a page was built or used: DMM shows its own page until restart.
    MCS_BUILD_FAILED='error',
    -- A page's action hook failed: what was clicked did nothing.
    HOOK_ACTION_FAILED='error',
}

-- The level for an event: listed events first, then by name; anything else is DEBUG.
function M.level(event)
    event=tostring(event)
    if levels[event] then return levels[event] end
    if event:find('EXCEPTION',1,true) then return 'error' end
    if event:find('FAILED',1,true) or event:find('UNAVAILABLE',1,true)
        or event:find('SKIPPED',1,true) or event:find('ERROR',1,true) then return 'warn' end
    return 'debug'
end

-- A report(event,detail) function writing through logger.
function M.reporter(logger)
    return function(event,detail)
        logger[M.level(event)](event,detail~=nil and ' '..tostring(detail) or '')
    end
end

return M

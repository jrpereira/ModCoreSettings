-- The game window regaining focus, from the UE4SS Lua Event Bridge when it is installed
-- (1.4.0 and later): the automatic config reload trigger (config_reload.lua).
-- subscribe(callback) registers callback with UE4SSLuaEventBridge.onFocusRegained and returns
-- true, or returns false when the Event Bridge or that event is unavailable. The bridge may
-- deliver on its event-loop thread, so the callback always runs on the game thread.
local M={}

function M.subscribe(callback,globals)
    globals=globals or _G
    local bridge=rawget(globals,'UE4SSLuaEventBridge')
    if type(bridge)~='table' or type(bridge.onFocusRegained)~='function' then return false end
    local onGameThread=rawget(globals,'ExecuteInGameThread')
    local cancel,why=bridge.onFocusRegained(function()
        if type(onGameThread)=='function' then onGameThread(callback) else callback() end
    end)
    if cancel==nil then error('focus event refused: '..tostring(why),0) end
    return true
end

return M

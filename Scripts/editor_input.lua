-- Runs in DMM's Lua state: Enter and the controller's A for field-type editors (see
-- field_types), and the left mouse button. Enter is a UE4SS key bind, like DMM's own keys;
-- its callback only counts presses. A and the mouse button are read from the player
-- controller, as DMM reads the gamepad: UE4SS binds keyboard keys only.
local M={version=1}

-- options: register (RegisterKeyBind), keys (UE4SS Key), key(name) -> an FKey struct.
function M.new(options)
    options=options or {}
    local presses=0
    if type(options.register)=='function' and options.keys and options.keys.RETURN then
        options.register(options.keys.RETURN,function() presses=presses+1 end)
    end
    local cache={}
    local function down(api,name)
        local pc=api and api.pc
        if not pc or not options.key then return false end
        cache[name]=cache[name] or options.key(name)
        local ok,value=pcall(function() return pc:IsInputKeyDown(cache[name]) end)
        return ok and value==true
    end
    local input={}
    local padDown
    -- Whether Enter or A was pressed since the last call. A is read only while wants is
    -- true; an A already held when reading starts is not a press.
    function input.take(wants,api)
        local pressed=presses>0
        presses=0
        if not wants then padDown=nil;return pressed end
        local pad=down(api,'Gamepad_FaceButton_Bottom')
        if padDown==false and pad then pressed=true end
        padDown=pad
        return pressed
    end
    function input.pointer(api) return down(api,'LeftMouseButton') end
    return input
end

return M

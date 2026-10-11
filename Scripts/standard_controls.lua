-- Resolve the keyboard keys the player assigned to a standard Enhanced Input action.
local Keys=require('standard_keys')
local M={}

local function unwrap(value)
    if value==nil then return nil end
    local ok,result=pcall(function() return value:get() end)
    return ok and result or value
end
local function valid(value)
    local ok,result=pcall(function() return value~=nil and value:IsValid() end)
    return ok and result==true
end
local function full(value)
    local ok,result=pcall(function() return value:GetFullName() end)
    return ok and tostring(result) or nil
end
local function path(value)
    local name=full(value)
    return name and (name:match('^%S+%s+(.+)$') or name) or nil
end
local function property(object,name)
    if object==nil then return nil end
    local ok,value=pcall(function() return object[name] end)
    return ok and unwrap(value) or nil
end
local function each(values,callback)
    if type(values)=='table' then
        for key,value in pairs(values) do
            if type(key)=='number' then callback(unwrap(value),key)
            else callback(unwrap(key),unwrap(value)) end
        end
        return true
    end
    return pcall(function()
        values:ForEach(function(key,value)
            key,value=unwrap(key),unwrap(value)
            if type(key)=='number' then callback(value,key) else callback(key,value) end
        end)
    end)
end
local function name(value)
    value=unwrap(value)
    if value==nil then return nil end
    if type(value)=='string' then return value end
    local ok,result=pcall(function() return value:ToString() end)
    return ok and tostring(result) or tostring(value)
end

-- The global object scans behind a lookup, shared by every row that asks within the same
-- second: a page of keybind rows costs one scan, not one per row.
local shared={}
local function sharedScan(name,scan)
    local now=os.time()
    if shared.time~=now then shared={time=now} end
    if shared[name]==nil then shared[name]=scan() end
    return shared[name]
end

-- Returns the sorted keyboard keys the player bound to the action in the Settings key
-- profile, by the rule ModCore Controls binds them with (vendor/standard_keys.lua). Without
-- keys it returns nil and why: 'key profile unavailable' (worth asking again later) or
-- 'standard control unavailable' (the profile is there and does not map the action).
function M.resolve(actionId,environment)
    assert(type(actionId)=='string' and actionId:match('%S'),'standard control ID required')
    local e=environment or {unwrap=unwrap,valid=valid,full=full,path=path,property=property,
        each=each,name=name,
        subsystems=function()
            return sharedScan('subsystems',function()
                local ok,items=pcall(FindAllOf,'EnhancedInputLocalPlayerSubsystem')
                return ok and type(items)=='table' and items or {}
            end)
        end,
        actions=function()
            return sharedScan('actions',function()
                local ok,items=pcall(FindAllOf,'InputAction')
                return ok and type(items)=='table' and items or {}
            end)
        end,
        call=function(object,method) return object[method](object) end}
    -- The first player subsystem with a loaded key profile.
    local function profile()
        for _,subsystem in ipairs(e.subsystems()) do
            if e.valid(subsystem) then
                local ok,candidate=pcall(function()
                    local settings=e.unwrap(e.call(subsystem,'GetUserSettings'))
                    return e.valid(settings) and e.unwrap(e.call(settings,'GetCurrentKeyProfile')) or nil
                end)
                if ok and e.valid(candidate) then return candidate end
            end
        end
    end
    local keys,why=Keys.resolve(setmetatable({profile=e.profile or profile},{__index=e}),actionId)
    return keys,why
end

return M

-- Publishes Apply notifications for settings_api v2, beside DMM's own numeric ones: every
-- stored value, numbers as numbers and text (keyed picker keys, ranges, keybinds) as text.
-- Runs in DMM's state; a page's Apply is never failed by a notification.
local M={version=2}
local prefix='MC_SettingsApplied_v2_'

local function hex(value)
    return (value:gsub('.',function(c) return string.format('%02x',c:byte()) end))
end
local function finite(value)
    return type(value)=='number' and value==value and math.abs(value)<=1000000000
end
local function revision(payload)
    return type(payload)=='string' and tonumber(payload:match('^(%d+)\n')) or 0
end

function M.encode(value)
    if type(value)=='number' then
        assert(finite(value),'invalid settings notification value')
        return 'n'..string.format('%.17g',value)
    end
    assert(type(value)=='string' and #value<=1024,'invalid settings notification value')
    return 's'..hex(value)
end

-- The notification text after revision previous, or nil when the event has no values.
function M.payload(previous,event)
    local lines={string.format('%.0f',previous+1)}
    local count=0
    for key,value in pairs(event.values) do
        assert(type(key)=='string' and #key>0 and #key<=128,'invalid settings notification key')
        local change=event.changes and event.changes[key]
        local old=change and change.old
        if old==nil then old=value end
        count=count+1;assert(count<=256,'too many notification values')
        lines[#lines+1]=hex(key)..' '..M.encode(old)..' '..M.encode(value)
    end
    if count==0 then return nil end
    local payload=table.concat(lines,'\n')..'\n'
    assert(#payload<=98304,'settings notification exceeds bounds')
    return payload
end

-- Sends one page's event to its settings_api v2 subscriber, if it has one.
function M.publish(id,event,pc)
    local ref=rawget(_G,'ModRef')
    if not ref or type(event)~='table' or type(event.values)~='table' then return end
    local command=prefix..hex(id)
    if not ref:GetSharedVariable(command..'.owner') then return end
    local previous=revision(ref:GetSharedVariable(command..'.data'))
    assert(previous>=0 and previous<9007199254740991,'notification revision exhausted')
    local payload=M.payload(previous,event)
    if not payload then return end
    assert(pc and pc:IsValid(),'settings player unavailable')
    local player=pc.Player
    assert(player and player:IsValid(),'local player unavailable')
    local viewport=player.ViewportClient
    assert(viewport and viewport:IsValid() and viewport:IsA('/Script/Engine.GameViewportClient'),'game viewport unavailable')
    ref:SetSharedVariable(command..'.data',payload)
    assert(viewport:ProcessConsoleExec(command,nil,pc)==true,'settings notification was not handled')
end

-- Wraps DMM's settings API so each Apply also notifies v2 subscribers. report(event,detail).
function M.install(api,report)
    if type(api)~='table' or type(api.publish)~='function' or api.mcNotifyVersion then return false end
    local publish=api.publish
    api.publish=function(id,event,pc,...)
        local ok,err=pcall(M.publish,id,event,pc)
        if not ok then report('NOTIFY_FAILED',tostring(id)..': '..tostring(err)) end
        return publish(id,event,pc,...)
    end
    api.mcNotifyVersion=M.version
    return true
end

return M

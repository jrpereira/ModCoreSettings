-- Config reload: one trigger reloads every module that subscribed, so no module polls its
-- files. Any Lua state runs the console command
--   MC_ConfigReload_v1 <reason> [<source id>]
-- (reason: button, focus or a module id; source: a subscriber that already reloaded). This
-- module handles it in ModCoreSettings' own state and fans it out to each subscriber that the
-- vendored settings_api registered with onReload(id, callback):
--   MC_ConfigReload_v1.index        space-separated hex ids of the subscribers
--   MC_ConfigReload_v1_<hex id>     a subscriber's console command; <command>.owner is set
--                                   while it is subscribed and <command>.data holds
--                                   '<revision>\n<reason>\n<unix time>'
--   MC_ConfigReload_v1.ready        '1' once the trigger is handled here
--   MC_ConfigReload_v1.last         unix time of the last fan-out (else this module's start)
-- A button press is always fanned out. An automatic trigger (focus, a module) within MERGE
-- seconds of the last fan-out is merged into it and dropped. Without a player (the main menu)
-- a trigger is kept, several kept ones become one, and it is fanned out once a player exists.
local M={TRIGGER='MC_ConfigReload_v1',MERGE=1}
M.INDEX,M.READY,M.LAST=M.TRIGGER..'.index',M.TRIGGER..'.ready',M.TRIGGER..'.last'

local function hex(value)
    assert(type(value)=='string' and #value>0 and #value<=128 and not value:find('%c'),'invalid subscriber id')
    return (value:gsub('.',function(c) return string.format('%02x',c:byte()) end))
end
M.hex=hex
function M.command(id) return M.TRIGGER..'_'..hex(id) end

-- The subscribers' hex ids, in order, without repeats.
function M.subscribers(text)
    local out,seen={},{}
    for word in tostring(text or ''):gmatch('%S+') do
        if word:match('^%x+$') and #word%2==0 and #word<=256 and not seen[word] then
            seen[word]=true;out[#out+1]=word
        end
    end
    return out
end

-- options: shared (ModRef), exec(command) -> true when run (false or error: no player yet),
-- ready() -> whether a player can receive commands, now() -> unix time, report(event,detail).
function M.hub(options)
    local shared,report=options.shared,options.report or function() end
    local now=options.now or os.time
    local hub={revision=0,pending=nil}
    local reported={}
    local function once(event,detail)
        local key=event..'\0'..detail
        if not reported[key] then reported[key]=true;report(event,detail) end
    end
    if shared:GetSharedVariable(M.LAST)==nil then shared:SetSharedVariable(M.LAST,tostring(now())) end
    local lastFanOut
    -- Fans the kept trigger out, when a player can receive it.
    function hub:flush()
        local pending=self.pending
        if not pending then return false end
        if options.ready and not options.ready() then return false end
        self.pending=nil
        self.revision=self.revision+1
        local time=now()
        local data=self.revision..'\n'..pending.reason..'\n'..time
        local skip=pending.source and hex(pending.source)
        for _,id in ipairs(M.subscribers(shared:GetSharedVariable(M.INDEX))) do
            local command=M.TRIGGER..'_'..id
            if id~=skip and shared:GetSharedVariable(command..'.owner') then
                shared:SetSharedVariable(command..'.data',data)
                local ok,err=pcall(options.exec,command)
                if not ok or err==false then once('RELOAD_FAILED',command..': '..tostring(ok and 'not handled' or err)) end
            end
        end
        lastFanOut=time
        shared:SetSharedVariable(M.LAST,tostring(time))
        return true
    end
    -- reason: 'button' (never merged), 'focus' or a module id. source (optional): a
    -- subscriber that already reloaded. Returns 'merged', 'kept' or 'sent'.
    function hub:trigger(reason,source)
        assert(type(reason)=='string' and reason:match('^[%w_.:-]+$') and #reason<=128,'invalid reload reason')
        if source~=nil then hex(source) end
        local manual=reason=='button'
        if not manual and not self.pending and lastFanOut and now()-lastFanOut<M.MERGE then return 'merged' end
        -- Kept triggers become one: a press wins over an automatic reason, and a source is
        -- skipped only when every kept trigger came from it.
        local pending=self.pending
        if pending then
            if manual or pending.reason~='button' then pending.reason=reason end
            if pending.source~=source then pending.source=nil end
        else
            self.pending={reason=reason,source=source}
        end
        return self:flush() and 'sent' or 'kept'
    end
    return hub
end

-- Registers the trigger command in this state. register is UE4SS'
-- RegisterConsoleCommandHandler; its callback gets (command, parameters).
function M.listen(hub,register,shared,report)
    register(M.TRIGGER,function(_,parameters)
        local ok,why=pcall(function()
            parameters=type(parameters)=='table' and parameters or {}
            hub:trigger(parameters[1] or 'button',parameters[2])
        end)
        if not ok then (report or function() end)('RELOAD_FAILED',tostring(why)) end
        return true
    end)
    shared:SetSharedVariable(M.READY,'1')
end

-- 'HH:MM:SS' of the last fan-out (or the start), for the Mod Index's button; nil when unknown.
function M.lastLoaded(shared,date)
    local time=tonumber(shared:GetSharedVariable(M.LAST) or '')
    return time and (date or os.date)('%H:%M:%S',time) or nil
end

return M

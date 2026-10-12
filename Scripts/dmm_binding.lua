local Discovery=require('widget_discovery')
local Lifecycle=require('dmm_lifecycle')
local DirtyLabels=require('dirty_labels')
local RowError=require('row_error')
local M={}
-- Dirty labels are observed every UPDATE_MS while rows change. After QUIET_TICKS ticks
-- without a change the page is observed every QUIET_MS instead, until the next change.
local UPDATE_MS,QUIET_MS,QUIET_TICKS=50,250,10

function M.install(log)
    log=log or function() end
    for _,api in ipairs({'StaticFindObject','ExecuteWithDelay','ExecuteInGameThread'}) do
        if type(_G[api])~='function' then return false,api..' unavailable' end
    end
    local dirty=DirtyLabels.new(log)
    local scope,schedule
    local active=nil
    local pending={}
    local eventTicket=nil
    local quiet=0
    -- An entry is fully functional or shows only its label and an error; never partly working.
    local function fail(row,message)
        local ok,err=pcall(RowError.mark,row,message)
        if not ok then log('ROW_ERROR_FAILED',tostring(row.settingId)..': '..tostring(err)) end
    end
    -- Splits a scroll's rows into usable rows and rows with an error message.
    -- The page's provider is the one most rows name; ties go to the earliest row.
    local function classify(rows)
        local counts,providerId,best={},nil,0
        for _,row in ipairs(rows) do
            local id=row.identityProviderId
            if id then
                counts[id]=(counts[id] or 0)+1
                if counts[id]>best then providerId,best=id,counts[id] end
            end
        end
        if not providerId then return nil end
        local reasons,seen={},{}
        for _,row in ipairs(rows) do
            local id=row.settingId
            -- Field types draw their own editor inside DMM's Lua state; nothing to bind here.
            if row.dmmSetting and row.dmmSetting.kind=='extension' and row.dmmSetting.id==id then
            elseif not id or not row.dmmSetting or row.dmmSetting.id~=id then reasons[row]='Error: no identity'
            elseif row.dmmSetting.kind~=row.kind then reasons[row]='Error: type mismatch'
            elseif row.identityProviderId~=providerId then reasons[row]='Error: other page'
            elseif seen[id] then reasons[row]='Error: duplicate id';reasons[seen[id]]='Error: duplicate id'
            else seen[id]=row end
        end
        local good={}
        for _,row in ipairs(rows) do if not reasons[row] then good[#good+1]=row end end
        return providerId,good,reasons
    end

    local function tick(path,epoch,selections)
        local function allowed() return scope:matches(path,epoch) end
        if not allowed() then return end
        if not scope:ownerLive() then return end
        local host=StaticFindObject(path)
        if not allowed() then return end
        if not Discovery.valid(host) or not host:IsInViewport() or not host:IsActivated()
            or host:IsVisible()~=true or host:GetIsEnabled()~=true then
            scope:invalidate();return
        end
        if not active then
            active=true;quiet=0
            -- One event-driven discovery, after DMM finishes its synchronous row build.
            local snapshots={}
            if selections and #selections>0 then
                -- Lifecycle events give us the exact selected children. In
                -- the usual DMM flow one is the provider ScrollBox and the other
                -- is the surrounding detail page. Try only those objects.
                for _,selection in ipairs(selections) do
                    local candidate=StaticFindObject(selection.path)
                    if Discovery.valid(candidate) and Discovery.address(candidate)==selection.address then
                        local rows=Discovery.rowsFromScroll(candidate)
                        if rows and #rows>0 then snapshots[1]={scrolls={candidate},directRows=rows};break end
                    end
                end
            end
            if not snapshots[1] then
                -- Activation can arrive without a switcher event (for example,
                -- recovery after a load). An unrelated switcher can also fire
                -- inside the same host. Keep one bounded traversal as fallback.
                local snapshot=Discovery.activeTrees(host,allowed)[1]
                if snapshot then snapshots[1]=snapshot end
            end
            if not allowed() then return end
            local allRows={}
            local snapshot=snapshots[1]
            if snapshot then
                for _,scroll in ipairs(snapshot.scrolls) do
                    if not allowed() then return end
                    local rows=snapshot.directRows or Discovery.rowsFromScroll(scroll) or {}
                    local providerId,good,reasons=classify(rows)
                    if providerId then
                        for index,row in ipairs(rows) do
                            local reason=reasons[row]
                            if reason then
                                log('ROW_ERROR',providerId..' row '..index..' '..tostring(row.settingId)..': '..reason
                                    ..' (kind '..tostring(row.kind)..'/'..tostring(row.dmmSetting and row.dmmSetting.kind)
                                    ..', provider '..tostring(row.identityProviderId)..')')
                                fail(row,reason)
                            end
                        end
                        for _,row in ipairs(good) do allRows[#allRows+1]=row end
                    end
                end
                local routes
                if allowed() then
                    local objects={}
                    local function add(value) if Discovery.valid(value) then objects[#objects+1]=value end end
                    for _,row in ipairs(allRows) do
                        for _,key in ipairs({'slider','nav','surface','surfaceBox','line','labelBox','labelButton','labelWidget',
                            'valueBox','valueWidget','overlay','wrapper','scroll','shell','content','lane','leftBox','centerBox',
                            'rightBox','leftButton','centerButton','rightButton','button'}) do add(row[key]) end
                    end
                    routes=Discovery.routesFor(host,objects,allowed)
                    if not routes then
                        local rebuilt=Discovery.activeTrees(host,allowed)[1]
                        routes=rebuilt and rebuilt.routes or snapshot.routes or {}
                    end
                end
                dirty:bind(allRows,routes or {})
            end
        end
        if dirty:refresh(host)==0 then return end
        quiet=(dirty.changed or 0)>0 and 0 or quiet+1
        if allowed() then schedule(path,epoch,quiet>=QUIET_TICKS and QUIET_MS or UPDATE_MS) end
    end
    local function abandon(path,epoch,event,err)
        pending[epoch]=nil
        if scope:matches(path,epoch) then
            log(event,tostring(err))
            scope:invalidate()
        end
    end
    schedule=function(path,epoch,delay,selections)
        if not scope or not scope:matches(path,epoch) or pending[epoch] then return end
        pending[epoch]=true
        local queued,queueError=pcall(ExecuteWithDelay,delay,function()
            if not scope:matches(path,epoch) then pending[epoch]=nil;return end
            local dispatched,dispatchError=pcall(function()
                local function work()
                    pending[epoch]=nil
                    if not scope:matches(path,epoch) then return end
                    if EngineTickAvailable==false then scope:invalidate();return end
                    local ok,err=pcall(tick,path,epoch,selections)
                    if not ok then abandon(path,epoch,'DISCOVERY_FAILED',err) end
                end
                if EGameThreadMethod and EGameThreadMethod.EngineTick then ExecuteInGameThread(work,EGameThreadMethod.EngineTick)
                else ExecuteInGameThread(work) end
            end)
            if not dispatched then abandon(path,epoch,'GAME_THREAD_DISPATCH_FAILED',dispatchError) end
        end)
        if not queued then abandon(path,epoch,'SCHEDULING_FAILED',queueError) end
    end
    local err
    scope,err=Lifecycle.install(log,function(path,epoch,selection)
        if not path then
            eventTicket=nil;active=nil;dirty:close();return
        end
        dirty:open(path,function() return scope:matches(path,epoch) end,function() return scope:ownerLive() end)
        -- Multiple DMM switcher calls in the same stack share one deferred refresh.
        -- Each event has already revoked the previous epoch synchronously.
        if eventTicket then
            eventTicket.path=path;eventTicket.epoch=epoch
            if selection then eventTicket.selections[#eventTicket.selections+1]=selection end
            return
        end
        local ticket={path=path,epoch=epoch,selections={}}
        if selection then ticket.selections[1]=selection end
        eventTicket=ticket
        local queued,queueError=pcall(ExecuteWithDelay,0,function()
            if eventTicket~=ticket then return end
            eventTicket=nil
            local currentPath,currentEpoch=ticket.path,ticket.epoch
            if not scope:matches(currentPath,currentEpoch) then return end
            active=nil
            schedule(currentPath,currentEpoch,0,#ticket.selections>0 and ticket.selections or nil)
        end)
        if not queued then eventTicket=nil;abandon(path,epoch,'SCHEDULING_FAILED',queueError) end
    end)
    if not scope then return false,err end
    return true
end
return M

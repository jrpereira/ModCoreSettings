-- A navigation picker with mcLinkPage=<page id> opens that page instead of saving a value.
-- mcLinkPage=<provider>:<slot> opens the page hosting that slot with the slot showing.
-- Back on a page a link opened returns to the page the link was on, with the link's row
-- showing and selected; Back there goes on as before, so a chain of links unwinds in order.
-- A page listed nowhere whose rows another page's slot shows (ModCore Controls' page in
-- ModCore Settings' Controls tab) opens there, at those rows; a slot on it opens at the
-- first of its rows.
local M={version=3}
local showSlot,reveal

-- Where a page listed nowhere is shown: the slot address parts (provider, slot) of the slot
-- its rows fill, or nil.
local function placed(slots,provider)
    if not (slots and type(slots.inserts)=='table' and provider.mcBrowserHidden) then return nil end
    for target,named in pairs(slots.inserts) do
        for slot,entries in pairs(named) do
            for _,entry in ipairs(entries) do
                if entry.source==provider then return target,slot end
            end
        end
    end
end
-- The sources of the rows a slot of provider holds, as a set, or nil.
local function sourcesOf(slots,provider,slot)
    local named=slots.inserts[slots.provider(provider.id)]
    local entries=named and slot and named[slot]
    if not entries then return nil end
    local set={}
    for _,entry in ipairs(entries) do set[entry.source]=true end
    return set
end
M.placed=placed

-- slots (optional): the menu_slots controller, which resolves slot addresses.
-- report(event,detail) (optional) hears a link that failed to open.
function M.wrap(page,providers,api,slots,report)
    if type(page)~='table' or type(page.controls)~='table' then return page end
    local controls,pending=page.controls,nil
    local show,tick=controls.show,controls.tick
    if type(show)~='function' or type(tick)~='function' then return page end
    -- trail: where each followed link was, {provider=,row=}, the latest last. following is set
    -- while a link or a return opens a page; reselect is the row to select on the next tick.
    local trail,following,reselect={},false,nil
    function controls:show(index)
        local result=show(self,index)
        local model=self.model
        if model and not model.mcPageLinks then
            local set=model.set
            -- A link opens when its row is clicked or confirmed with Enter (controller: A),
            -- which mark the model mcActivateLink first; Left and Right do nothing on it.
            function model:set(settingIndex,value)
                local choice=providers[index].choices[settingIndex]
                if choice and choice.mcLinkPage then
                    if self.mcActivateLink then
                        pending={target=choice.mcLinkPage,provider=index,row=settingIndex}
                    end
                    self.mcActivateLink=nil
                    return
                end
                return set(self,settingIndex,value)
            end
            model.mcPageLinks=true
        end
        return result
    end
    local function status(message)
        if api.setText and page.controlStatus then api.setText(page.controlStatus,message) end
    end
    -- Opens target's page; false when no listed page has it.
    local navigate
    function controls:tick(...)
        local result=tick(self,...)
        local link=pending
        pending=nil
        -- A return selects the link's row once DMM has finished its Back.
        local row=reselect
        reselect=nil
        if row and self.model and not self.model.error and self.model.items and self.model.items[row] then
            local ok,err=pcall(function()
                reveal(self.model,row)
                if type(self.refresh)=='function' then self:refresh() end
                if type(self.select)=='function' then self:select(row,true) end
            end)
            if not ok and report then report('PAGE_LINK_FAILED','return: '..tostring(err)) end
        end
        if not link then return result end
        local target=link.target
        if self.model:dirty() then
            status('Apply or discard changes before leaving this page.')
            return true
        end
        -- This wrapper runs outside build_guard: a failure must never reach DMM's tick.
        following=true
        local ok,opened=pcall(navigate,target)
        following=false
        if not ok and report then report('PAGE_LINK_FAILED',target..': '..tostring(opened)) end
        if ok and opened then trail[#trail+1]={provider=link.provider,row=link.row}
        else status(target..' page is unavailable.') end
        return true
    end
    -- Opens the page of providers[index]; false when DMM lists no row for it.
    local function open(index)
        for rowIndex,row in ipairs(page.rows) do
            if row.providerIndex==index then
                -- Go through the browser as DMM does. Hiding the source detail restores
                -- its transient model and clears input state; a direct detail-to-detail
                -- replacement can leave the activating picker alive and reactivate it.
                if type(page.showBrowser)=='function' then page:showBrowser() end
                page:showDetail(rowIndex)
                return true
            end
        end
        -- A page left out of the browser list (mcBrowserHidden) opens through its row
        -- in DMM's full list, offered to showDetail as the only listed row.
        for _,row in ipairs(providers[index].mcBrowserHidden and page.allRows or {}) do
            if row.providerIndex==index then
                if type(page.showBrowser)=='function' then page:showBrowser() end
                local listed=page.rows
                page.rows={row}
                local ok,err=pcall(page.showDetail,page,1)
                page.rows=listed
                if not ok then error(err,0) end
                return true
            end
        end
        return false
    end
    navigate=function(target,prefer)
        local host,slot
        if slots then host,slot=slots.address(target) end
        for index,provider in ipairs(providers) do
            local matched
            if host then
                matched=not provider.mcLinkSlot and slots.provider(provider.id)==host
            else matched=provider.id==target end
            if matched and not provider.noSettings then
                local outerHost,outerSlot=placed(slots,provider)
                if outerHost then
                    return navigate(outerHost..':'..outerSlot,slot and sourcesOf(slots,provider,slot) or {[provider]=true})
                end
                if open(index) then
                    if slot then showSlot(page,slot,prefer) end
                    return true
                end
            end
        end
        return false
    end
    if type(page.showDetail)=='function' then M.slotLinks(page,providers,slots) end
    -- Back leaves a page through showBrowser. On a page a link opened, it returns to the
    -- link's page instead; a page opened from the browser forgets the trail.
    local showBrowser,showDetail=page.showBrowser,page.showDetail
    if type(showBrowser)=='function' and type(showDetail)=='function' then
        function page:showDetail(...)
            if not following then trail={} end
            return showDetail(self,...)
        end
        function page:showBrowser(...)
            local results=table.pack(showBrowser(self,...))
            local origin=not following and table.remove(trail)
            if origin then
                following=true
                local ok,opened=pcall(open,origin.provider)
                following=false
                if ok and opened then reselect=origin.row
                else
                    trail={}
                    if report then report('PAGE_LINK_FAILED','return to '..tostring(providers[origin.provider]
                        and providers[origin.provider].id)..': '..tostring(opened)) end
                end
            end
            return table.unpack(results,1,results.n)
        end
    end
    return page
end

-- Set the navigation pickers that gate a row so it shows. Navigation never marks the page dirty.
function reveal(model,index,seen)
    seen=seen or {}
    if seen[index] then return end
    seen[index]=true
    for _,rule in ipairs(model.items[index].visibility or {}) do
        local target=model.items[rule.target]
        reveal(model,rule.target,seen)
        if target.mcNavigation and not rule.values[model.pending[rule.target]] then
            for _,value in ipairs(target.values) do
                if rule.values[value] then model:set(rule.target,value);break end
            end
        end
    end
end
M.reveal=reveal

-- A link page (mcLinkSlot) opens its host page with the slot's rows showing. A host listed
-- nowhere opens where its rows are shown (placed). slots (optional): the menu_slots controller.
function M.slotLinks(page,providers,slots)
    local showDetail=page.showDetail
    function page:showDetail(rowIndex)
        local row=self.rows and self.rows[rowIndex]
        local link=row and providers[row.providerIndex] and providers[row.providerIndex].mcLinkSlot
        if not link or not link.host then return showDetail(self,rowIndex) end
        local hostId,slot,prefer=link.host,link.slot,nil
        for _,provider in ipairs(providers) do
            if provider.id==hostId and not provider.mcLinkSlot then
                local outerHost,outerSlot=placed(slots,provider)
                if outerHost then
                    prefer=sourcesOf(slots,provider,slot)
                    for _,candidate in ipairs(providers) do
                        if not candidate.mcLinkSlot and slots.provider(candidate.id)==outerHost then hostId=candidate.id end
                    end
                    slot=outerSlot
                end
                break
            end
        end
        for hostRow,candidate in ipairs(self.rows) do
            if providers[candidate.providerIndex].id==hostId then
                local result=showDetail(self,hostRow)
                showSlot(self,slot,prefer)
                return result
            end
        end
        return showDetail(self,rowIndex)
    end
end

-- On the page just shown, reveal and select the slot's first row: with prefer (a set of
-- source pages), the first of its rows from one of them, if any.
function showSlot(page,slot,prefer)
    local controls=page.controls
    local model=controls and controls.model
    if not model or model.error then return end
    local first
    for index,setting in ipairs(model.items) do
        if setting.mcSlotName==slot or setting.mcSlot==slot then
            first=first or index
            if not prefer or prefer[setting.mcSlotSource] then first=index;break end
        end
    end
    if first then
        reveal(model,first)
        controls:refresh()
        controls:select(first,true)
    end
end

function M.install(pages,slots,report)
    assert(type(pages)=='table' and type(pages.build)=='function','DMM pages API unavailable')
    if pages.mcPageLinksVersion then return false end
    local build=pages.build
    pages.build=function(tree,providers,status,api)
        return M.wrap(build(tree,providers,status,api),providers,api,slots,report)
    end
    pages.mcPageLinksVersion=M.version
    return true
end

return M

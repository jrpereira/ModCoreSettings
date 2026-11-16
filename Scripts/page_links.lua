-- A navigation picker with mcLinkPage=<page id> opens that page instead of saving a value.
-- mcLinkPage=<provider>:<slot> opens the page hosting that slot with the slot showing.
local M={version=1}
local showSlot

-- slots (optional): the menu_slots controller, which resolves slot addresses.
function M.wrap(page,providers,api,slots)
    if type(page)~='table' or type(page.controls)~='table' then return page end
    local controls,pending=page.controls,nil
    local show,tick=controls.show,controls.tick
    if type(show)~='function' or type(tick)~='function' then return page end
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
                    if self.mcActivateLink then pending=choice.mcLinkPage end
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
    function controls:tick(...)
        local result=tick(self,...)
        local target=pending
        pending=nil
        if not target then return result end
        if self.model:dirty() then
            status('Apply or discard changes before leaving this page.')
            return true
        end
        local host,slot
        if slots then host,slot=slots.address(target) end
        for index,provider in ipairs(providers) do
            local matched
            if host then
                matched=not provider.mcLinkSlot and slots.provider(provider.id)==host
            else matched=provider.id==target end
            if matched and not provider.noSettings then
                for rowIndex,row in ipairs(page.rows) do
                    if row.providerIndex==index then
                        -- Go through the browser as DMM does. Hiding the source detail restores
                        -- its transient model and clears input state; a direct detail-to-detail
                        -- replacement can leave the activating picker alive and reactivate it.
                        if type(page.showBrowser)=='function' then page:showBrowser() end
                        page:showDetail(rowIndex)
                        if slot then showSlot(page,slot) end
                        return true
                    end
                end
                -- A page left out of the browser list (mcBrowserHidden) opens through its row
                -- in DMM's full list, offered to showDetail as the only listed row.
                for _,row in ipairs(provider.mcBrowserHidden and page.allRows or {}) do
                    if row.providerIndex==index then
                        if type(page.showBrowser)=='function' then page:showBrowser() end
                        local listed=page.rows
                        page.rows={row}
                        local ok,err=pcall(page.showDetail,page,1)
                        page.rows=listed
                        assert(ok,err)
                        if slot then showSlot(page,slot) end
                        return true
                    end
                end
            end
        end
        status(target..' page is unavailable.')
        return true
    end
    if type(page.showDetail)=='function' then M.slotLinks(page,providers) end
    return page
end

-- Set the navigation pickers that gate a row so it shows. Navigation never marks the page dirty.
local function reveal(model,index,seen)
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

-- A link page (mcLinkSlot) opens its host page with the slot's rows showing.
function M.slotLinks(page,providers)
    local showDetail=page.showDetail
    function page:showDetail(rowIndex)
        local row=self.rows and self.rows[rowIndex]
        local link=row and providers[row.providerIndex] and providers[row.providerIndex].mcLinkSlot
        if not link or not link.host then return showDetail(self,rowIndex) end
        for hostRow,candidate in ipairs(self.rows) do
            if providers[candidate.providerIndex].id==link.host then
                local result=showDetail(self,hostRow)
                showSlot(self,link.slot)
                return result
            end
        end
        return showDetail(self,rowIndex)
    end
end

-- On the page just shown, reveal and select the slot's first row.
function showSlot(page,slot)
    local controls=page.controls
    local model=controls and controls.model
    if not model or model.error then return end
    for index,setting in ipairs(model.items) do
        if setting.mcSlotName==slot or setting.mcSlot==slot then
            reveal(model,index)
            controls:refresh()
            controls:select(index,true)
            return
        end
    end
end

function M.install(pages,slots)
    assert(type(pages)=='table' and type(pages.build)=='function','DMM pages API unavailable')
    if pages.mcPageLinksVersion then return false end
    local build=pages.build
    pages.build=function(tree,providers,status,api)
        return M.wrap(build(tree,providers,status,api),providers,api,slots)
    end
    pages.mcPageLinksVersion=M.version
    return true
end

return M

-- After any page's changes are applied, the mod browser is rebuilt the next time it shows,
-- as if the menu had been closed and opened again: grouping, the index tabs and
-- contributed pages are all read on each build. Installed outermost, so the rebuild runs
-- every wrapper with DMM's own arguments.
--
-- DMM keeps the page it was given for the whole menu, so it gets a stand-in that forwards
-- to the current build. A rebuilt page's switcher takes the old one's place; the old one
-- stays parented, collapsed, until the next rebuild, so no widget input queued for it this
-- tick is collected. Older pages are released.
local M={version=1}

local COLLAPSED,FILL=1,0

function M.install(pages,report)
    assert(type(pages)=='table' and type(pages.build)=='function','DMM pages API unavailable')
    if pages.mcIndexRefreshVersion then return false end
    report=report or function() end
    local build=pages.build
    pages.build=function(tree,providers,status,api)
        local state={stale=false}
        local wrap
        local function make(compatibleOnly)
            local adapted={}
            for key,value in pairs(api) do adapted[key]=value end
            if compatibleOnly~=nil then adapted.compatibleOnly=compatibleOnly end
            adapted.applied=function(...)
                state.stale=true
                if api.applied then return api.applied(...) end
            end
            return wrap(build(tree,providers,status,adapted))
        end
        local function place(holder,switcher,what)
            local slot=api.need(holder:AddChild(switcher),what)
            slot:SetHorizontalAlignment(FILL);slot:SetVerticalAlignment(FILL)
        end
        local function rebuild()
            local old=state.page
            local fresh=make(old.compatibleOnly)
            assert(fresh~=old and fresh.switcher,'rebuilt page has no switcher')
            if not state.holder then
                local box=assert(old.switcher:GetParent(),'mod browser switcher parent')
                local holder=api.construct('/Script/UMG.Overlay',tree)
                api.need(box:SetContent(holder),'mod browser holder')
                place(holder,old.switcher,'previous mod browser')
                state.holder,state.root=holder,old.root
            end
            fresh.switcher:RemoveFromParent()
            place(state.holder,fresh.switcher,'rebuilt mod browser')
            old.switcher:SetVisibility(COLLAPSED)
            -- Only the page just replaced can still be reached, by input queued this tick;
            -- any older one is released, so repeated rebuilds keep at most two pages.
            if state.parked then state.parked:RemoveFromParent() end
            state.parked=old.switcher
            fresh.root=state.root
            -- Input queued for the old rows is dropped, and DMM re-selects a row.
            fresh.revision=math.max(fresh.revision or 0,(old.revision or 0)+1)
            state.page=fresh
        end
        wrap=function(page)
            if type(page)~='table' or type(page.setInputMode)~='function' then return page end
            local setInputMode=page.setInputMode
            -- Asks for the rebuild an Apply would: the browser's sort button uses it.
            function page:mcRefreshIndex() state.stale=true end
            -- DMM sets the input mode first on every tick of an open menu. Waiting for the
            -- browser to be shown on a tick skips a link that passes through it to a page.
            function page:setInputMode(...)
                if state.stale and state.page==page and page.mode=='browser' then
                    state.stale=false
                    local ok,err=pcall(rebuild)
                    if not ok then report('INDEX_REFRESH_FAILED',tostring(err)) end
                    if state.page~=page then return state.page.setInputMode(self,...) end
                end
                return setInputMode(self,...)
            end
            return page
        end
        local page=make()
        if type(page)~='table' or type(page.setInputMode)~='function' then return page end
        state.page=page
        return setmetatable({},{
            __index=function(_,key) return state.page[key] end,
            __newindex=function(_,key,value) state.page[key]=value end,
        })
    end
    pages.mcIndexRefreshVersion=M.version
    return true
end

return M

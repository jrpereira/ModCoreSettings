-- Turn published menu contributions into DMM pages before DMM builds its rows.
-- Contributors publish data through menu_contributions.lua. The only contributor code run
-- here is a page's hooks file, through the hooked(page) function the extension supplies.
local M={}

local function before(a,b)
    if a.testOnly~=b.testOnly then return not a.testOnly end
    local an,bn=a.name:lower(),b.name:lower()
    if an~=bn then return an<bn end
    return a.id<b.id
end
local function indexOf(providers,provider)
    for index,candidate in ipairs(providers) do if candidate==provider then return index end end
end
local function insertSorted(providers,provider)
    for index,candidate in ipairs(providers) do
        if before(provider,candidate) then table.insert(providers,index,provider);return end
    end
    providers[#providers+1]=provider
end

function M.reader(Contributions,shared,read,report)
    local cache={}
    local function load(path)
        local directory=assert(path:match('^(.*)[/\\][^/\\]+$'),'invalid descriptor path')
        return Contributions.decode(read(path),function(name) return read(directory..'/'..name) end)
    end
    return function()
        local list={}
        local index=shared:GetSharedVariable(Contributions.index)
        if type(index)~='string' then return list end
        for word in index:gmatch('%S+') do
            local key=Contributions.prefix..word
            local value=shared:GetSharedVariable(key)
            local generation,path=Contributions.slot(value)
            local entry=cache[word]
            if generation and path~='' and (not entry or entry.generation~=generation) then
                local ok,result=pcall(load,path)
                if ok and (result.generation~=generation or Contributions.hex(result.id)~=word) then
                    ok,result=false,'descriptor does not match its channel'
                end
                -- A publish may have started while the files were read. Never mix generations.
                if shared:GetSharedVariable(key)==value then
                    if not ok then report('CONTRIBUTION_SKIPPED',word..' generation '..generation..': '..tostring(result)) end
                    entry={generation=generation,result=ok and result or false}
                    cache[word]=entry
                end
            elseif generation and path=='' then
                entry=nil;cache[word]=nil
            end
            if entry and entry.result then list[#list+1]=entry.result end
        end
        return list
    end
end

local function generated(contribution,page,parse,hooked,compile)
    local choices={}
    local manifest,hooks,context=page.manifest,nil,nil
    if page.hooks then
        assert(hooked,'page hooks unavailable')
        hooks,manifest,context=hooked(page)
    elseif page.menu then
        assert(compile,'menu data unavailable')
        manifest=compile(page.menu,page)
    end
    if manifest then choices=parse(manifest) end
    local provider={id=page.id,name=page.name,author=page.author or contribution.id,
        version=page.version or '',description=page.description or '',
        authorURL='',modURL='',logoFile='',logoAsset='',testOnly=false,
        choices=choices,settingsCount=#choices,choicesLoaded=true,deferred=false,
        path=page.configDirectory and (page.configDirectory:gsub('[/\\]+$','')..'/mod_settings.ini') or nil,
        mcContribution=contribution.id,mcBrowserGroup=page.group,mcBrowserIcon=page.icon,mcFolder=page.attach,mcManifest=manifest,
        mcHooks=hooks,mcHookContext=context}
    if page.link then
        -- Opens another page; it is selectable although it has no settings of its own.
        provider.mcLinkSlot={address=page.link}
    elseif #choices==0 then provider.noSettings,provider.mcBrowserHeading=true,manifest==nil end
    return provider
end

-- The page that hosts a slot address, when it is listed and declares the slot.
local function slotHost(providers,slots,value)
    if not slots then return nil end
    local target,slot=slots.address(value)
    if not target then return nil end
    for _,candidate in ipairs(providers) do
        if not candidate.mcLinkSlot and not candidate.noSettings and slots.provider(candidate.id)==target
            and slots:declares(candidate,slot) then return candidate,target,slot end
    end
end

local function attached(providers,folder)
    local wanted,match=folder:lower(),nil
    for _,provider in ipairs(providers) do
        if not provider.mcContribution then
            local id,name=tostring(provider.id or ''):lower(),tostring(provider.name or ''):lower()
            if name==wanted or id==wanted or id=='detected:ue4ss:'..wanted then
                if match then error('attach '..folder..' matches more than one mod') end
                match=provider
            end
        end
    end
    return match
end

-- Rebuild contributed pages in DMM's persistent provider list. state keeps the
-- placeholder entries hidden by the previous build so they return when unused.
-- state.inserts is keyed by provider address and slot name. slots (the menu_slots controller)
-- parses addresses and checks slot declarations; without it rows are ignored and link pages hidden.
-- A hidden page whose rows have no available slot is shown instead, so its settings stay reachable.
-- hooked(page) (optional) returns a hooks page's hooks, manifest text and context.
-- compile(menu,page) (optional) turns a page's menu data into manifest text.
function M.apply(providers,contributions,parse,state,report,slots,hooked,compile)
    local address=slots and slots.address
    for index=#providers,1,-1 do
        if providers[index].mcContribution then table.remove(providers,index) end
    end
    for _,placeholder in ipairs(state.hidden or {}) do insertSorted(providers,placeholder) end
    state.hidden={}
    -- Slot rows by target provider id and slot name, rebuilt with the pages.
    state.inserts={}
    local ids={}
    for _,provider in ipairs(providers) do ids[provider.id]=true end
    -- Contributors without rows go first, in publish order: a slot's host may be a contributed
    -- page, and a contributor whose rows fill it can publish before it (its folder starts first).
    -- Rows keep their publish order.
    local ordered={}
    for _,contribution in ipairs(contributions) do
        if not contribution.rows or #contribution.rows==0 then ordered[#ordered+1]=contribution end
    end
    for _,contribution in ipairs(contributions) do
        if contribution.rows and #contribution.rows>0 then ordered[#ordered+1]=contribution end
    end
    for _,contribution in ipairs(ordered) do
        local hidden,inserts={},{}
        local ok,err=pcall(function()
            local built,shown,landed={},{},{}
            for _,row in ipairs(contribution.rows or {}) do
                landed[row.page]=landed[row.page] or slotHost(providers,slots,row.slot)~=nil
            end
            for _,page in ipairs(contribution.pages) do
                shown[page.id]=page.visible~=false or landed[page.id]==false
            end
            for _,page in ipairs(contribution.pages) do
                assert(not ids[page.id],'page id '..page.id..' is already in the menu')
                local parent=page.under and built[page.under]
                if shown[page.id] and (not page.under or parent) then
                    built[page.id]={provider=generated(contribution,page,parse,hooked,compile),page=page}
                end
            end
            -- Validate all attachments before changing the list; a contributor is all or nothing.
            -- A hidden page still claims its folder: that mod's own entry stays hidden too, whether
            -- it is a detected placeholder or a mod with settings of its own.
            local claimed={}
            for _,page in ipairs(contribution.pages) do
                local entry=built[page.id]
                if entry and page.attach then entry.match=attached(providers,page.attach)
                elseif not shown[page.id] and page.attach then
                    local match=attached(providers,page.attach)
                    if match and (match.detectedKind or not match.noSettings) then claimed[#claimed+1]=match end
                end
            end
            for _,match in ipairs(claimed) do
                table.remove(providers,indexOf(providers,match))
                hidden[#hidden+1]=match
            end
            local tails={}
            for _,page in ipairs(contribution.pages) do
                local entry=built[page.id]
                if entry then
                    local provider,match=entry.provider,entry.match
                    if page.under then
                        local parent=built[page.under]
                        local tail=tails[page.under] or parent.provider
                        table.insert(providers,indexOf(providers,tail)+1,provider)
                        provider.mcBrowserLevel,provider.mcBrowserIndent=4,20
                        local ancestor=page.under
                        while ancestor do tails[ancestor]=provider;ancestor=built[ancestor].page.under end
                    elseif match and match.noSettings and match.detectedKind then
                        -- The page becomes that mod's entry; the browser names it from the
                        -- mod's folder, as it would the placeholder.
                        table.remove(providers,indexOf(providers,match))
                        hidden[#hidden+1]=match
                        provider.mcModuleEntry=true
                        insertSorted(providers,provider)
                    elseif match and page.group==nil then
                        local tail=tails[match] or match
                        table.insert(providers,indexOf(providers,tail)+1,provider)
                        provider.mcBrowserLevel,provider.mcBrowserIndent=4,20
                        tails[match]=provider
                    else
                        insertSorted(providers,provider)
                    end
                    ids[page.id]=true
                end
            end
            -- A row's source page may be hidden; its model still needs a provider.
            for _,row in ipairs(address and contribution.rows or {}) do
                local source
                for _,page in ipairs(contribution.pages) do
                    if page.id==row.page then
                        source=built[page.id] and built[page.id].provider
                            or generated(contribution,page,parse,hooked,compile)
                    end
                end
                local target,slot=address(row.slot)
                inserts[#inserts+1]={target=target,slot=slot,
                    entry={contributor=contribution.id,source=source,settings=row.settings}}
            end
        end)
        if ok then
            for _,placeholder in ipairs(hidden) do state.hidden[#state.hidden+1]=placeholder end
            for _,insert in ipairs(inserts) do
                local slots=state.inserts[insert.target] or {}
                state.inserts[insert.target]=slots
                slots[insert.slot]=slots[insert.slot] or {}
                table.insert(slots[insert.slot],insert.entry)
            end
        else
            for index=#providers,1,-1 do
                if providers[index].mcContribution==contribution.id then
                    ids[providers[index].id]=nil;table.remove(providers,index)
                end
            end
            for _,placeholder in ipairs(hidden) do insertSorted(providers,placeholder) end
            report('CONTRIBUTION_SKIPPED',contribution.id..': '..tostring(err))
        end
    end
    -- A link page shows only while its slot exists and has rows; like visible=false, a
    -- hidden link page keeps any detected placeholder it claimed hidden.
    for index=#providers,1,-1 do
        local link=providers[index].mcLinkSlot
        if link then
            local host,target,slot=slotHost(providers,slots,link.address)
            local filled=host and state.inserts[target] and state.inserts[target][slot]
            if filled and #filled>0 then
                link.host,link.slot=host.id,slot
            else table.remove(providers,index) end
        end
    end
    return providers
end

-- slots (optional): the menu_slots controller; read loads a disk manifest for splicing.
-- hooked and compile (optional): see M.apply.
function M.install(pages,parse,contributions,report,slots,read,hooked,compile)
    assert(type(pages)=='table' and type(pages.build)=='function','DMM pages API unavailable')
    if pages.mcMenuPagesVersion then return false end
    local state,build,reported={}, pages.build, {}
    local function once(event,detail)
        if reported[detail] then return end
        reported[detail]=true
        report(event,detail)
    end
    pages.build=function(tree,providers,status,api)
        -- Contributions must never take the menu down with them.
        local ok,list=pcall(contributions)
        if not ok then once('CONTRIBUTIONS_UNAVAILABLE',tostring(list));list={} end
        M.apply(providers,list,parse,state,once,slots,hooked,compile)
        -- Every contributed page's version by id, hidden pages included, for the ModCore page.
        local versions={}
        for _,contribution in ipairs(list) do
            for _,page in ipairs(contribution.pages or {}) do
                if type(page.version)=='string' and page.version~='' then versions[page.id]=page.version end
            end
        end
        local versioned={}
        for key,value in pairs(api) do versioned[key]=value end
        versioned.mcPageVersions=versions
        api=versioned
        if slots then
            slots:outermost()
            slots.inserts,slots.applied=state.inserts,api.applied
            local loadProvider=api.loadProvider
            local wrapped={}
            for key,value in pairs(api) do wrapped[key]=value end
            -- Splice after DMM loads the page and before its rows are built.
            wrapped.loadProvider=function(provider)
                if loadProvider then loadProvider(provider) end
                slots:outermost()
                local ok,err=pcall(slots.load,slots,provider,read)
                if not ok then once('SLOT_ROWS_SKIPPED',tostring(provider.id)..': '..tostring(err)) end
            end
            api=wrapped
        end
        return build(tree,providers,status,api)
    end
    pages.mcMenuPagesVersion=1
    return true
end

return M

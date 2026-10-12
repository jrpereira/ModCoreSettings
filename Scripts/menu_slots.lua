-- Rows another contributor publishes into a slot of this page. A read-only row with
-- mcSlot=<name> marks the slot; inserted rows replace it in the manifest text and DMM parses
-- the result, so every index-based feature sees one ordinary page. The page model routes
-- inserted rows to their source page's own model: storage, Apply events and config stay theirs.
local M={version=1}
local Manifest=require('mcs_manifest')
-- Inserted rows render as plain DMM controls; source presentation keys are not copied,
-- except a label rule naming an earlier inserted row and a picker's choice notes.
local COPIED={'Id','Type','Label','Description','PresetValues','PresetLabels','Presets','Default',
    'Minimum','Maximum','Step','Decimals','Prefix','Suffix','mcChoiceNotes','mcReadOnly'}

-- Raw [Setting] sections with their line span, as DMM's parser reads them, and the lines.
local function sections(content)
    local list,lines=Manifest.sections(content)
    local settings={}
    for _,section in ipairs(list) do if section.setting then settings[#settings+1]=section end end
    return settings,lines
end
M.sections=sections

function M.parse(content,items)
    local list=sections(content)
    local byId,seen={},{}
    for _,item in ipairs(items) do byId[item.id]=item end
    for _,section in ipairs(list) do
        local name=section.fields.mcSlot
        if name~=nil then
            assert(#name<=64 and name:match('^[%w_]+$'),'invalid mcSlot')
            assert(not seen[name],'duplicate mcSlot '..name)
            seen[name]=true
            local item=assert(byId[section.id],'mcSlot setting unavailable')
            assert(item.mcReadOnly,'mcSlot requires mcReadOnly=1')
            item.mcSlot=name
        end
        local label=section.fields.mcSlotLabel
        if label~=nil then
            assert(name~=nil,'mcSlotLabel requires mcSlot')
            assert(label=='1','mcSlotLabel must be 1')
        end
        local grouped=section.fields.mcSlotGroups
        if grouped~=nil then
            assert(name~=nil,'mcSlotGroups requires mcSlot')
            assert(grouped=='1','mcSlotGroups must be 1')
        end
    end
    return items
end

local function eligible(setting)
    assert(setting,'setting not found')
    assert(setting.kind=='picker' or setting.kind=='toggle' or setting.kind=='slider','unsupported kind')
    assert(not setting.targets and not setting.mcMapping,'presets cannot be inserted')
    -- A read-only row is copied with its mcReadOnly, so it stays a shown value: it has no
    -- storage and is never dirty. Navigation and link rows act on their own page.
    assert(not setting.mcNavigation and not setting.mcLinkPage,'navigation and link rows cannot be inserted')
end

-- Section text for one inserted setting, placed in the slot's group. Its own VisibleWhen may
-- name a row the same contributor inserted earlier in this slot; otherwise it takes the slot
-- row's rule. DMM ANDs either with the slot group's Category rule. Source Category rules are
-- not carried: contributors express that gating per row. With mcSlotLabel=1 on the slot
-- row, the first inserted row takes the slot row's Label, mcLevel and mcCategory: the host
-- names it.
local function insertion(source,id,slot,number,earlier,first,grouping)
    local found
    for _,section in ipairs(sections(source.mcManifest or '')) do
        if section.fields.Id==id then found=section.fields end
    end
    assert(found,'setting not found in source manifest')
    local byId
    for _,setting in ipairs(source.choices or {}) do if setting.id==id then byId=setting end end
    eligible(byId)
    local out={'[Setting.mcSlot.'..number..']'}
    local fields=slot.fields
    local named=first and fields.mcSlotLabel=='1'
    for _,key in ipairs(COPIED) do
        local value=found[key]
        if named and key=='Label' then value=fields.Label end
        if value~=nil then out[#out+1]=key..'='..value end
    end
    if named and fields.mcLevel then out[#out+1]='mcLevel='..fields.mcLevel end
    if named and fields.mcCategory then out[#out+1]='mcCategory='..fields.mcCategory end
    -- The host names the first row under mcSlotLabel=1, so it keeps no label rule.
    if not named and (found.mcLabelWhen or found.mcLabels) then
        assert(found.mcLabelWhen and found.mcLabels and earlier[found.mcLabelWhen],
            'mcLabelWhen must name a row this contributor inserted earlier in the slot')
        out[#out+1]='mcLabelWhen='..found.mcLabelWhen
        out[#out+1]='mcLabels='..found.mcLabels
    end
    out[#out+1]='Group='..(grouping and grouping(found) or fields.Group or fields.Section or fields.Category or 'Settings')
    local rule=fields
    if found.VisibleWhen or found.VisibleValues then
        assert(found.VisibleWhen and earlier[found.VisibleWhen],
            'VisibleWhen must name a row this contributor inserted earlier in the slot')
        assert(not fields.VisibleWhen,'the slot row has its own VisibleWhen; gate the slot by its Category')
        rule=found
    end
    if rule.VisibleWhen then out[#out+1]='VisibleWhen='..rule.VisibleWhen end
    if rule.VisibleValues then out[#out+1]='VisibleValues='..rule.VisibleValues end
    return out
end

-- Under mcSlotGroups=1 inserted rows keep their source groups, each a group of the host
-- named mcSlot.<slot>.<n>, so DMM heads them as any group. A group keeps its heading's
-- presentation keys and takes the visibility of the slot's own group; a source group with
-- a rule of its own is rejected, as its rows would be. A subgroup's mcWithin follows its
-- category's host name.
local GROUP_COPIED={'mcLabel','mcHeading','mcLevel','mcHelp','mcSilent','mcWithinLabel'}
local function groupOf(fields) return fields.Group or fields.Section or fields.Category or 'Settings' end

local function categories(content)
    local byName={}
    for _,section in ipairs((Manifest.sections(content))) do
        local name=section.name:match('^Category%.(.+)$')
        if name then byName[name]=section end
    end
    return byName
end

-- Returns grouping(found) for one entry, which names (and records) the host group of each
-- source group, and the Category sections those groups need.
local function regroup(source,slotName,hostRule,counter,known)
    local own=categories(source.mcManifest or '')
    local added={}
    local function grouping(found)
        local group=groupOf(found)
        local name=known[group]
        if name then return name end
        local category=own[group] and own[group].fields or {}
        assert(category.VisibleWhen==nil and category.mcLabelWhen==nil,
            'group '..group..' has its own rule; it cannot keep its group in the slot')
        counter.n=counter.n+1
        name='mcSlot.'..slotName..'.'..counter.n
        known[group]=name
        local out={'[Category.'..name..']','mcLabel='..(category.mcLabel or group)}
        for _,key in ipairs(GROUP_COPIED) do
            if key~='mcLabel' and category[key]~=nil then out[#out+1]=key..'='..category[key] end
        end
        if category.mcWithin~=nil then
            local outer=category.mcWithin
            if not known[outer] then counter.n=counter.n+1;known[outer]='mcSlot.'..slotName..'.'..counter.n end
            out[#out+1]='mcWithin='..known[outer]
        end
        if hostRule.VisibleWhen then out[#out+1]='VisibleWhen='..hostRule.VisibleWhen end
        if hostRule.VisibleValues then out[#out+1]='VisibleValues='..hostRule.VisibleValues end
        for _,line in ipairs(out) do added[#added+1]=line end
        added[#added+1]=''
        return name
    end
    return grouping,added
end

-- Rebuild provider.choices from its unspliced base with the current inserts.
-- inserts: slot name -> list of {contributor=id,source=provider,settings={ids}}.
function M.load(provider,inserts,read,parse,report)
    if provider.choices~=provider.mcSlotChoices then
        provider.mcSlotBase={choices=provider.choices,count=provider.settingsCount}
    end
    local base=provider.mcSlotBase
    provider.choices,provider.settingsCount,provider.mcSlotChoices=base.choices,base.count,nil
    if provider.choiceError or not inserts then return false end
    local slots={}
    for _,setting in ipairs(base.choices or {}) do
        if setting.mcSlot and inserts[setting.mcSlot] then slots[setting.mcSlot]=true end
    end
    if not next(slots) then return false end
    local ok,err=pcall(function()
        local text=provider.mcManifest or assert(read(provider.path),'manifest unreadable')
        text=text:gsub('^\239\187\191','')
        local list,lines=sections(text)
        -- Splicing shifts positions, so implicit setting_<n> ids would change meaning.
        for _,section in ipairs(list) do assert(section.fields.Id,'host settings need explicit Id') end
        local replaced,added,sources,used,serial,slotOf={},0,{},{},0,{}
        for _,setting in ipairs(base.choices) do used[setting.id]=true end
        local hostCategories,emptied=categories(text),{}
        for _,section in ipairs(list) do
            local name=section.fields.mcSlot
            if name and slots[name] then
                local generated,earlier={},{}
                local grouped=section.fields.mcSlotGroups=='1'
                local hostGroup=groupOf(section.fields)
                local hostRule=hostCategories[hostGroup] and hostCategories[hostGroup].fields or {}
                local counter,known={n=0},{}
                for _,entry in ipairs(inserts[name]) do
                    local rows,ids={},{}
                    local mine=earlier[entry.contributor] or {}
                    local seen=setmetatable({},{__index=mine})
                    -- Groups are named per source page, so one page's chunks share them.
                    known[entry.source]=known[entry.source] or {}
                    local before,groupNames=counter.n,{}
                    for group,named in pairs(known[entry.source]) do groupNames[group]=named end
                    local grouping,headings
                    if grouped then grouping,headings=regroup(entry.source,name,hostRule,counter,known[entry.source]) end
                    local fine,why=pcall(function()
                        for _,id in ipairs(entry.settings) do
                            assert(not used[id] and not ids[id],'setting id '..id..' is already on this page')
                            serial=serial+1
                            local first=#generated==0 and #rows==0
                            for _,row in ipairs(insertion(entry.source,id,section,serial,seen,first,grouping)) do rows[#rows+1]=row end
                            ids[id]=true;seen[id]=true
                            rows[#rows+1]=''
                        end
                    end)
                    if not fine and grouped then counter.n,known[entry.source]=before,groupNames end
                    if fine then
                        for id in pairs(ids) do
                            used[id]=true;sources[id]=entry.source;mine[id]=true;slotOf[id]=name
                        end
                        earlier[entry.contributor]=mine
                        for _,row in ipairs(headings or {}) do generated[#generated+1]=row end
                        for _,row in ipairs(rows) do generated[#generated+1]=row end
                        added=added+#entry.settings
                    else
                        report('SLOT_ROW_SKIPPED',entry.contributor..' -> '..provider.id..'/'..name..': '..tostring(why))
                    end
                end
                if #generated>0 then
                    replaced[section.first]={last=section.last,rows=generated}
                    if grouped then emptied[hostGroup]=true end
                end
            end
        end
        if added==0 then return end
        -- A host group left without settings of its own loses its Category section: DMM
        -- rejects a Category with no settings.
        for _,section in ipairs(list) do
            if not replaced[section.first] then emptied[groupOf(section.fields)]=nil end
        end
        for group in pairs(emptied) do
            local category=hostCategories[group]
            if category then replaced[category.first]={last=category.last,rows={}} end
        end
        local out,n={},1
        while n<=#lines do
            local swap=replaced[n]
            if swap then
                for _,row in ipairs(swap.rows) do out[#out+1]=row end
                n=swap.last+1
            else out[#out+1]=lines[n];n=n+1 end
        end
        local choices=parse(table.concat(out,'\n'))
        for _,setting in ipairs(choices) do
            local source=sources[setting.id]
            if source then
                setting.mcSlotSource,setting.mcSlotName=source,slotOf[setting.id];sources[setting.id]=nil
            end
        end
        assert(next(sources)==nil,'inserted setting missing after parse')
        local removed=0
        for _,section in ipairs(list) do if replaced[section.first] then removed=removed+1 end end
        provider.choices,provider.mcSlotChoices=choices,choices
        provider.settingsCount=base.count-removed+added
    end)
    if not ok then report('SLOT_ROWS_SKIPPED',provider.id..': '..tostring(err)) end
    return ok and provider.mcSlotChoices~=nil
end

-- One page model over the host's own model and each source page's model.
function M.open(provider,open,publish,report)
    if not provider.mcSlotChoices or provider.choices~=provider.mcSlotChoices then return open(provider) end
    local host={}
    for key,value in pairs(provider) do host[key]=value end
    host.choices,host.settingsCount=provider.mcSlotBase.choices,provider.mcSlotBase.count
    host.mcSlotChoices,host.mcSlotBase=nil,nil
    local inner=open(host)
    local model={provider=provider,items=provider.choices,pending={},committed={},fs=inner.fs}
    local innerIndex,routes,sources,bySource={},{},{},{}
    for i,setting in ipairs(inner.items or {}) do innerIndex[setting.id]=i end
    for i,setting in ipairs(model.items) do
        local source=setting.mcSlotSource
        if source then
            local entry=bySource[source]
            if not entry then
                local ok,result=pcall(open,source)
                if ok and result.error then ok,result=false,result.error end
                if not ok then report('SLOT_SOURCE_UNAVAILABLE',source.id..': '..tostring(result)) end
                entry={source=source,model=ok and result or nil,index={}}
                if entry.model then
                    for n,item in ipairs(entry.model.items) do entry.index[item.id]=n end
                end
                bySource[source]=entry;sources[#sources+1]=entry
            end
            local index=entry.model and entry.index[setting.id]
            routes[i]=index and {model=entry.model,index=index} or false
        else
            routes[i]=innerIndex[setting.id] and {model=inner,index=innerIndex[setting.id]} or false
        end
    end
    local function sync()
        model.error=inner.error
        for i,setting in ipairs(model.items) do
            local route=routes[i]
            if route then
                model.pending[i],model.committed[i]=route.model.pending[route.index],route.model.committed[route.index]
            else model.pending[i],model.committed[i]=setting.default,setting.default end
        end
        -- Mapped-preset presentation state is indexed by row.
        local outer={}
        for i,route in ipairs(routes) do if route and route.model==inner then outer[route.index]=i end end
        for _,field in ipairs({'mcHiddenDirty','mcVisualDirty'}) do
            if inner[field] then
                local mapped={}
                for index,value in pairs(inner[field]) do if outer[index] then mapped[outer[index]]=value end end
                model[field]=mapped
            end
        end
        if inner.mcRejectedIndex then
            model.mcRejectedIndex=outer[inner.mcRejectedIndex];inner.mcRejectedIndex=nil
        end
    end
    local function routed(name)
        return function(self,i,...)
            local route=routes[i]
            if route then route.model[name](route.model,route.index,...) end
            sync()
        end
    end
    model.set,model.change,model.slide=routed('set'),routed('change'),routed('slide')
    local resetRow=routed('reset')
    function model:reset(i)
        if i then return resetRow(self,i) end
        inner:reset()
        for n,route in ipairs(routes) do
            if route and route.model~=inner then route.model:reset(route.index) end
        end
        sync()
    end
    function model:restore()
        inner:restore()
        for _,entry in ipairs(sources) do if entry.model then entry.model:restore() end end
        sync()
    end
    function model:dirty()
        if inner:dirty() then return true end
        for _,entry in ipairs(sources) do if entry.model and entry.model:dirty() then return true end end
        return false
    end
    function model:visibility() return inner.visibility(self) end
    -- The host applies first; a source is only written after the host succeeded. A host
    -- event is published here when a later source fails, because DMM skips failed Applies.
    function model:apply()
        if inner.error then return false,inner.error end
        local ok,err,event=inner:apply()
        if not ok then sync();return false,err end
        local failure
        for _,entry in ipairs(sources) do
            local source=entry.source
            if entry.model and entry.model:dirty() then
                local applied,why,sourceEvent=entry.model:apply()
                if applied and sourceEvent then publish(source,sourceEvent)
                elseif not applied then failure=failure or (source.id..': '..tostring(why)) end
            end
        end
        sync()
        if failure then
            if event then publish(provider,event) end
            return false,failure
        end
        return true,nil,event
    end
    sync()
    return model
end

-- Whether a page's manifest declares a slot, without loading its settings.
function M.declares(provider,name,read)
    local ok,text=pcall(function() return provider.mcManifest or read(provider.path) end)
    if not ok or type(text)~='string' then return false end
    for _,section in ipairs(sections(text)) do if section.fields.mcSlot==name then return true end end
    return false
end

-- contributions: the menu_contributions module, which owns slot address syntax.
-- read: loads a page manifest from disk.
function M.install(choices,report,contributions,read)
    if choices.mcSlotsVersion then return nil end
    local parse=choices.parse
    local controller={inserts={},applied=nil,address=contributions.address,provider=contributions.provider}
    function controller:declares(provider,name) return M.declares(provider,name,read) end
    local function publish(provider,event)
        if not controller.applied then return end
        local ok,err=pcall(controller.applied,provider,event)
        if not ok then report('SLOT_APPLY_EVENT_FAILED',provider.id..': '..tostring(err)) end
    end
    choices.parse=function(content) return M.parse(content,parse(content)) end
    -- Providers may install their own storage wrapper later (ModCoreControls does on first
    -- build). The slot model must stay outermost so inserted rows never reach that storage.
    local outermost
    function controller:outermost()
        if choices.open==outermost then return false end
        local inner=choices.open
        outermost=function(provider) return M.open(provider,inner,publish,report) end
        choices.open=outermost
        return true
    end
    controller:outermost()
    function controller:load(provider,read)
        return M.load(provider,self.inserts[contributions.provider(provider.id)],read,choices.parse,report)
    end
    choices.mcSlotsVersion=M.version
    return controller
end

return M

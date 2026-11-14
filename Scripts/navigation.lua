-- A presentation-only picker can drive DMM visibility without owning a config key.
local M={version=1}
local Manifest=require('mcs_manifest')

function M.parse(content,items)
    local byId={}
    for _,item in ipairs(items) do byId[item.id]=item end
    local function finish(section)
        local current=section.fields
        if current.mcNavigation==nil and current.mcReadOnly==nil
            and current.mcLinkPage==nil then return end
        assert(current.mcLinkPage==nil or current.mcNavigation=='1','mcLinkPage requires mcNavigation=1')
        if current.mcReadOnly~=nil then
            assert(current.mcReadOnly=='1','mcReadOnly must be 1')
        else assert(current.mcNavigation=='1','mcNavigation must be 1') end
        local item=assert(byId[section.id],'navigation picker setting unavailable')
        assert(item.kind=='picker','mcNavigation requires a picker')
        assert(not item.targets and not current.MappedPresetTargets,
            'navigation picker cannot own preset targets')
        if current.mcReadOnly then
            for _,label in ipairs(item.labels) do
                assert(label==item.labels[1],'read-only display labels must match')
            end
            item.values,item.labels={item.default},{item.labels[1]}
            item.mcReadOnly=true
        else
            item.mcNavigation=true
            if current.mcLinkPage then
                local target=current.mcLinkPage
                assert(target~='' and #target<=128 and not target:find('%c'),'invalid mcLinkPage')
                item.mcLinkPage=target
            end
        end
    end
    for _,section in ipairs(Manifest.settings(content)) do finish(section) end
    return items
end

function M.open(provider,open)
    local transient,indices,items={}, {}, {}
    for i,setting in ipairs(provider.choices or {}) do
        if setting.mcNavigation or setting.mcReadOnly then
            transient[i]=true
        else
            indices[i]=#items+1
            local copy={}
            for key,value in pairs(setting) do copy[key]=value end
            items[#items+1]=copy
        end
    end
    if not next(transient) then return open(provider) end
    for _,copy in ipairs(items) do
        if copy.targets then
            local targets={}
            for n,target in ipairs(copy.targets) do
                targets[n]=assert(indices[target],'transient picker cannot be a preset target')
            end
            copy.targets=targets
        end
    end
    local filtered={}
    for key,value in pairs(provider) do filtered[key]=value end
    filtered.choices=items
    local model=open(filtered)
    if model.error then return model end
    for i,setting in ipairs(provider.choices) do
        if transient[i] then
            table.insert(model.items,i,setting)
            table.insert(model.pending,i,setting.default)
            table.insert(model.committed,i,setting.default)
        end
    end
    for i,setting in ipairs(provider.choices) do model.items[i]=setting end
    model.provider=provider
    local set,reset,apply=model.set,model.reset,model.apply
    function model:set(i,value)
        if self.items[i].mcReadOnly then return end
        set(self,i,value)
        if transient[i] then self.committed[i]=self.pending[i] end
    end
    function model:reset(i)
        -- A navigation or read-only row has nothing to reset; resetting it through set would
        -- run its action or open its link.
        if i and transient[i] then return end
        local views={}
        for n in pairs(transient) do views[n]=self.pending[n] end
        reset(self,i)
        for n,value in pairs(views) do
            self.pending[n],self.committed[n]=value,value
        end
    end
    function model:apply()
        local removed={}
        for i=#self.items,1,-1 do
            if transient[i] then
                removed[i]={table.remove(self.items,i),table.remove(self.pending,i),table.remove(self.committed,i)}
            end
        end
        local ok,success,why,event=pcall(apply,self)
        for i=1,#provider.choices do
            local item=removed[i]
            if item then
                table.insert(self.items,i,item[1])
                table.insert(self.pending,i,item[2])
                table.insert(self.committed,i,item[3])
            end
        end
        if not ok then error(success) end
        return success,why,event
    end
    return model
end

function M.install(choices)
    if choices.mcNavigationVersion then return false end
    local parse,open=choices.parse,choices.open
    choices.parse=function(content) return M.parse(content,parse(content)) end
    choices.open=function(provider) return M.open(provider,open) end
    choices.mcNavigationVersion=M.version
    return true
end
return M

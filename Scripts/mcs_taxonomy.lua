-- Validate taxonomy selections and the file index in both Lua states.
local M={}
local MAX_CATEGORY_BRANCHES=3
local function array(values)
    assert(type(values)=='table','expected a category/tag list')
    local n=0
    for key in pairs(values) do
        assert(type(key)=='number' and key%1==0 and key>=1,'expected a list')
        n=n+1
    end
    assert(n==#values,'sparse list')
    return values
end
local function plain(value,limit)
    assert(type(value)=='string' and #value>0 and #value<=limit
        and utf8.len(value) and not value:find('%c'),'invalid browser text')
    return value
end
function M.new(data)
    assert(type(data)=='table' and type(data.version)=='number'
        and type(data.sections)=='table' and type(data.categories)=='table'
        and type(data.tags)=='table','invalid taxonomy')
    local T={data=data,definitions={},tagDefinitions={},descriptions={},sections={}}
    for _,section in ipairs(data.sections) do T.sections[section.id]=true end
    for _,definition in ipairs(data.categories) do
        assert(not T.definitions[definition.id],'duplicate category')
        T.definitions[definition.id]=definition
        T.descriptions[definition.id]=definition.description
    end
    for _,definition in ipairs(data.tags) do T.tagDefinitions[definition.id]=definition end
    assert(data.remap==nil or type(data.remap)=='function','invalid category remap')
    -- Usable categories from a list that may hold invalid ones: the data's optional
    -- remap(C) fixes it first, then unknown and duplicate ids are dropped. Returns
    -- the canonical selection, or nil when nothing valid remains.
    function T:usable(values)
        if type(values)~='table' then return nil end
        local list={}
        for _,id in ipairs(values) do list[#list+1]=id end
        local invalid=false
        for _,id in ipairs(list) do if type(id)~='string' or not self.definitions[id] then invalid=true end end
        if invalid and data.remap then
            local ok,remapped=pcall(data.remap,list)
            if ok and type(remapped)=='table' then list=remapped end
        end
        local seen,valid={},{}
        for _,id in ipairs(list) do
            if type(id)=='string' and self.definitions[id] and not seen[id] then seen[id]=true;valid[#valid+1]=id end
        end
        if seen.other and #valid>1 then
            local substantive={};for _,id in ipairs(valid) do if id~='other' then substantive[#substantive+1]=id end end
            valid=substantive
        end
        if #valid==0 then return nil end
        local ok,canonical=pcall(self.categories,self,valid)
        return ok and canonical or nil
    end
    function T:categories(values)
        local seen,result={},{}
        for _,id in ipairs(array(values==nil and {} or values)) do
            assert(type(id)=='string' and self.definitions[id],'unknown category: '..tostring(id))
            assert(not seen[id],'duplicate category: '..id)
            seen[id]=true
        end
        -- A selected child already grants its parent.
        for id in pairs(seen) do
            local parent=self.definitions[id].parent
            if parent then seen[parent]=nil end
        end
        for _,definition in ipairs(data.categories) do
            if seen[definition.id] then result[#result+1]=definition.id end
        end
        local branches={}
        for id in pairs(seen) do
            local current=id
            while self.definitions[current] and self.definitions[current].parent
                and not self.sections[self.definitions[current].parent] do
                current=self.definitions[current].parent
            end
            branches[self.definitions[current] and self.definitions[current].parent or current]=true
        end
        local branchCount=0;for _ in pairs(branches) do branchCount=branchCount+1 end
        assert(branchCount<=MAX_CATEGORY_BRANCHES,'too many category branches')
        assert(not seen.other or #result==1,'other cannot accompany a substantive category')
        if #result==0 then result={'other'} end
        return result
    end
    function T:parents(values)
        local seen,result={},{}
        for _,id in ipairs(self:categories(values)) do
            local node=id
            while self.definitions[node] and self.definitions[node].parent
                and not self.sections[self.definitions[node].parent] do
                node=self.definitions[node].parent
            end
            seen[self.definitions[node] and self.definitions[node].parent or node]=true
        end
        for _,section in ipairs(data.sections) do
            if seen[section.id] then result[#result+1]=section.id end
        end
        return result
    end
    function T:tags(values)
        local seen,result={},{}
        for _,id in ipairs(array(values==nil and {} or values)) do
            assert(self.tagDefinitions[id],'unknown tag: '..tostring(id))
            assert(not seen[id],'duplicate tag: '..id);seen[id]=true
        end
        for _,definition in ipairs(data.tags) do
            if seen[definition.id] then result[#result+1]=definition.id end
        end
        return result
    end
    function T:entry(entry)
        assert(type(entry)=='table','invalid index entry')
        entry.categories=self:categories(entry.categories)
        entry.parents=self:parents(entry.categories)
        entry.tags=self:tags(entry.tags)
        if entry.preferred~=nil then plain(entry.preferred,120) end
        if entry.icon~=nil then plain(entry.icon,16) end
        if entry.categories[1]=='other' then
            assert(entry.reason=='specialized' or entry.reason=='insufficient_evidence'
                or entry.reason=='ambiguous','other requires a classification reason')
        end
        return entry
    end
    function T:index(index)
        assert(index.schema_version==2 and index.taxonomy_version==data.version
            and type(index.modules)=='table','unsupported module index')
        for folder,entry in pairs(index.modules) do
            plain(folder,255)
            assert(not folder:find('[/\\]') and folder~='.' and folder~='..','invalid index folder')
            self:entry(entry)
        end
        return index
    end
    function T:matches(entry,filter,isTag)
        if not filter or not filter.values or #filter.values==0 then return true end
        assert(filter.mode==nil or filter.mode=='any' or filter.mode=='all','invalid filter mode')
        local requested
        if isTag then requested=self:tags(filter.values) else
            requested={}
            for _,id in ipairs(array(filter.values)) do
                if self.sections[id] then requested[#requested+1]=id
                else requested[#requested+1]=self:categories({id})[1] end
            end
        end
        local present={}
        for _,id in ipairs(entry.categories or {}) do present[id]=true end
        for _,id in ipairs(entry.parents or {}) do present[id]=true end
        if isTag then present={};for _,id in ipairs(entry.tags or {}) do present[id]=true end end
        for _,id in ipairs(requested) do
            if filter.mode=='all' and not present[id] then return false end
            if filter.mode~='all' and present[id] then return true end
        end
        return filter.mode=='all'
    end
    return T
end

function M.load(path,read,json)
    read=read or function(filePath)
        local file,err=io.open(filePath,'rb')
        assert(file,err or ('cannot read taxonomy: '..filePath))
        local content=file:read(1048577)
        local closed,closeErr=file:close()
        assert(closed,closeErr);assert(content and #content<=1048576,'taxonomy exceeds 1 MiB')
        return content
    end
    json=json or require('mcs_module_json')
    return M.new(json.decode(read(path)))
end
function M.loadLua(path,loader)
    local data
    if loader then data=loader(path) else
        local chunk,err=loadfile(path)
        assert(chunk,err or ('cannot load category data: '..path))
        data=chunk()
    end
    assert(type(data)=='table' and type(data.version)=='number','invalid category data version')
    if type(data.category_order)=='table' then
        local sections,categories,tags={}, {}, {}
        local parentById,nodeById={},{}
        for _,sectionId in ipairs(data.section_order or {}) do
            local section=assert(data.categories[sectionId],'missing category section: '..tostring(sectionId))
            local row={id=sectionId}
            for key,value in pairs(assert(section.definition,'missing section definition: '..sectionId)) do
                row[key]=value
            end
            sections[#sections+1]=row
            local function visit(children,parent)
                for id,node in pairs(children or {}) do
                    if id~='definition' and type(node)=='table' then
                        nodeById[id]=node;parentById[id]=parent
                        visit(node,id)
                    end
                end
            end
            visit(section,sectionId)
        end
        for _,id in ipairs(data.category_order) do
            local node=assert(nodeById[id],'missing category definition: '..tostring(id))
            local row={id=id,parent=parentById[id]}
            for key,value in pairs(assert(node.definition,'missing category definition data: '..id)) do
                row[key]=value
            end
            categories[#categories+1]=row
        end
        for _,id in ipairs(data.tag_order or {}) do
            local row={id=id}
            for key,value in pairs(assert(data.tags[id],'missing taxonomy tag: '..tostring(id))) do row[key]=value end
            tags[#tags+1]=row
        end
        data={version=data.version,remap=data.remap,
            sections=sections,categories=categories,tags=tags}
    end
    return M.new(data)
end
return M

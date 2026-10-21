-- Runs in DMM's Lua state. Adds setting types DMM does not know. DMM still
-- builds each row as its toggle shell (label, row, navigation, description);
-- the type's editor supplies the controls and owns the value, which stays text in
-- DMM's model. Settings of DMM's own types pass through untouched.
--
-- An editor is a table:
--   declare(fields) -> extra fields for the setting (fields: the raw section)
--   normalize(setting,raw) -> canonical value, or nil when raw is invalid
--   valid(setting,value) -> true for a canonical value
--   format(setting,value) -> text DMM shows in the row's value caption
--   build(row,setting,context) -> instance with set(value,committed) and
--       tick() -> new value or nil; context has tree, api and modules
-- Optional, for settings that declare conflictScope:
--   conflictKey(setting,value) -> what two rows in one scope must not share, or nil
--   instance:conflict(on) -> shows whether the row collides
-- Optional, for editors that take the row's keys (navigation=true on the editor):
--   instance:step(direction) -> new value or nil; Left/Right (-1/1) on the row
--   instance:confirm() -> new value or nil; Enter (controller: A) on the selected row
--   instance:focus(on) -> the row is selected or not
--   instance:hint() -> the footer hint's label while the row is selected, or nil
-- tick(pointer) gets pointer() -> whether the left mouse button is down.
local M={version=1}
local Manifest=require('mcs_manifest')
local MAX_SETTINGS=256
local dmmKinds={slider=true,integer=true,percent=true,stepped=true,toggle=true,picker=true,preset=true}
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end
local function split(s)
    local out={};for part in ((s or '')..'|'):gmatch('(.-)|') do out[#out+1]=trim(part) end
    return out
end

-- The raw [Setting] fields and [Category.*] fields by group, in DMM's own reading order.
local function sections(content)
    local raw,categories={},{}
    for _,section in ipairs((Manifest.sections(content))) do
        if section.setting then raw[#raw+1]=section.fields
        elseif section.name:match('^Category%.') then categories[section.name:sub(10)]=section.fields end
    end
    return raw,categories
end

function M.new(report)
    report=report or function() end
    local registry={editors={}}

    function registry:register(name,editor)
        assert(type(name)=='string' and name:match('^%l[%w_]*$') and not dmmKinds[name],'invalid setting type name')
        for _,method in ipairs({'declare','normalize','valid','format','build'}) do
            assert(type(editor[method])=='function','setting type '..name..' needs '..method..'()')
        end
        self.editors[name]=editor
    end
    local function editorOf(setting)
        return setting and setting.kind=='extension' and registry.editors[setting.editor] or nil
    end
    registry.editorOf=editorOf

    local function item(index,r,editor,name)
        local id=r.Id or ('setting_'..index)
        local s={id=id,kind='extension',editor=name,label=r.Label or id,description=r.Description or '',
            group=r.Group or r.Section or r.Category or 'Settings',
            -- DMM's toggle shell sizes its navigation from two values; they are never stored.
            -- A navigation editor's shell has three, and rests on the middle one: a move to
            -- either side is a step that way.
            values=editor.navigation and {0,1,2} or {0,1},labels=editor.navigation and {'','',''} or {'',''},
            file=r.ConfigFile,key=r.ConfigKey or id,section=r.ConfigSection,visibility={}}
        for key,value in pairs(editor.declare(r) or {}) do
            assert(s[key]==nil,'setting type '..name..' cannot redefine '..key)
            s[key]=value
        end
        s.default=assert(editor.normalize(s,r.Default),'invalid '..name..' default: '..id)
        return s
    end

    -- DMM rejects a category without settings of its own types, so it gets the
    -- manifest without categories only this module's settings use.
    function registry:forDMM(content)
        local raw,categories=sections(content)
        local used,typed={},false
        for _,r in ipairs(raw) do
            local group=r.Group or r.Section or r.Category or 'Settings'
            if self.editors[trim(r.Type):lower()] then typed=true else used[group]=true end
        end
        if not typed then return content end
        local drop={}
        for group in pairs(categories) do if not used[group] then drop[group]=true end end
        if next(drop)==nil then return content end
        local list,lines=Manifest.sections(content)
        local skipped={}
        for _,section in ipairs(list) do
            if section.name:match('^Category%.') and drop[section.name:sub(10)] then
                for n=section.first,section.last do skipped[n]=true end
            end
        end
        local out={}
        for n,line in ipairs(lines) do if not skipped[n] then out[#out+1]=line end end
        return table.concat(out,'\n')
    end

    -- Puts this module's settings back at their manifest positions among DMM's.
    function registry:merge(content,items)
        local raw,categories=sections(content)
        local any=false
        for _,r in ipairs(raw) do if self.editors[trim(r.Type):lower()] then any=true;break end end
        if not any then return items end
        local merged,remap,from,mine={},{},0,{}
        for index,r in ipairs(raw) do
            local kind=trim(r.Type):lower()
            local editor=self.editors[kind]
            if editor then
                merged[#merged+1]=item(index,r,editor,kind)
                mine[#merged]=r
            elseif dmmKinds[kind] then
                from=from+1
                remap[from]=#merged+1
                merged[#merged+1]=assert(items[from],'DMM settings out of step with the manifest')
            end
        end
        assert(from==#items,'DMM settings out of step with the manifest')
        assert(#merged<=MAX_SETTINGS,'more than '..MAX_SETTINGS..' settings')
        local byId={}
        for index,s in ipairs(merged) do
            assert(not byId[s.id],'duplicate setting Id '..s.id)
            byId[s.id]=index
        end
        for index,s in ipairs(merged) do
            if not mine[index] then
                for _,rule in ipairs(s.visibility or {}) do rule.target=remap[rule.target] end
                for n,target in ipairs(s.targets or {}) do s.targets[n]=remap[target] end
            end
        end
        -- The same row and category visibility DMM applies to its own settings.
        local function condition(r)
            if not r or (r.VisibleWhen==nil and r.VisibleValues==nil) then return nil end
            local target=byId[r.VisibleWhen]
            assert(target and r.VisibleValues,'visibility requires a setting Id and VisibleValues')
            local source=merged[target]
            assert(source.kind=='toggle' or source.kind=='picker','visibility source must be a toggle or picker')
            local values={}
            for _,rawValue in ipairs(split(r.VisibleValues)) do
                local value=tonumber(rawValue)
                local known=false
                for _,v in ipairs(source.values) do if v==value then known=true end end
                assert(value and known and not values[value],'invalid/duplicate visibility value')
                values[value]=true
            end
            return {target=target,values=values}
        end
        for index,r in pairs(mine) do
            local s=merged[index]
            local rowRule,groupRule=condition(r),condition(categories[s.group])
            if rowRule then s.visibility[#s.visibility+1]=rowRule end
            if groupRule then s.visibility[#s.visibility+1]=groupRule end
        end
        return merged
    end

    -- Colliding rows, and the navigation pickers that separate a colliding pair.
    -- Rows collide when they share a conflict scope and a conflict key. A picker
    -- separates two rows when both depend on it, directly or through the pickers
    -- gating them, but on different choices of it.
    function registry.conflicts(model)
        local rows,pickers={},{}
        if not model or model.error then return rows,pickers end
        local items=model.items or {}
        local groups={}
        for i,setting in ipairs(items) do
            local editor=editorOf(setting)
            if editor and editor.conflictKey and setting.conflictScope then
                local ok,key=pcall(editor.conflictKey,setting,model.pending[i])
                if ok and key~=nil then
                    local id=setting.conflictScope..'\0'..tostring(key)
                    groups[id]=groups[id] or {}
                    table.insert(groups[id],i)
                end
            end
        end
        local gating={}
        local function gates(index)
            if gating[index] then return gating[index] end
            local out,seen={},{}
            local function walk(n)
                if seen[n] or not items[n] then return end
                seen[n]=true
                for _,rule in ipairs(items[n].visibility or {}) do
                    local known=out[rule.target]
                    if known then
                        local both={}
                        for value in pairs(known) do if rule.values[value] then both[value]=true end end
                        out[rule.target]=both
                    else
                        local copy={}
                        for value in pairs(rule.values) do copy[value]=true end
                        out[rule.target]=copy
                    end
                    walk(rule.target)
                end
            end
            walk(index)
            gating[index]=out
            return out
        end
        local function same(a,b)
            for value in pairs(a) do if not b[value] then return false end end
            for value in pairs(b) do if not a[value] then return false end end
            return true
        end
        for _,list in pairs(groups) do
            if #list>1 then
                for _,index in ipairs(list) do rows[index]=true end
                for a=1,#list-1 do
                    for b=a+1,#list do
                        local first,second=gates(list[a]),gates(list[b])
                        for picker,values in pairs(first) do
                            if second[picker] and items[picker].mcNavigation and not same(values,second[picker]) then
                                pickers[picker]=true
                            end
                        end
                    end
                end
            end
        end
        return rows,pickers
    end

    -- Wraps DMM's modules. Every editor call is guarded: a failing editor reports
    -- and leaves DMM's own behavior in place.
    function registry:install(modules)
        local choices,controls=modules.choices,modules.controls
        local parse,index,format,open=choices.parse,choices.index,choices.format,choices.open
        choices.parse=function(content)
            return registry:merge(content,parse(registry:forDMM(content)))
        end
        choices.index=function(setting,value)
            local editor=editorOf(setting)
            if not editor then return index(setting,value) end
            local ok,valid=pcall(editor.valid,setting,value)
            return ok and valid and (editor.navigation and 2 or 1) or nil
        end
        -- Canonical form of a stored value of this module's types; nil for DMM's own
        -- types and for values the editor rejects.
        choices.mcNormalize=function(setting,value)
            local editor=editorOf(setting)
            if not editor then return nil end
            local ok,normalized=pcall(editor.normalize,setting,value)
            return ok and normalized or nil
        end
        choices.format=function(setting,value)
            local editor=editorOf(setting)
            if not editor then return format(setting,value) end
            local ok,text=pcall(editor.format,setting,value)
            return ok and text or ''
        end
        -- Left/Right on a navigation editor's row are steps for the editor, kept until the
        -- page's next tick: DMM's keys arrive as change(i,1|2), its shell's native moves as
        -- set(i,0|2). Steps are kept by setting, as the panel's model may route rows.
        local steps={}
        registry.steps=steps
        local function navigating(setting)
            local editor=editorOf(setting)
            return editor and editor.navigation
        end
        choices.open=function(provider)
            local model=open(provider)
            if not model.error and not provider.testOnly then
                for _,s in ipairs(model.items or {}) do
                    if editorOf(s) then
                        model.error='"'..s.label..'" needs a page that stores its own settings'
                        break
                    end
                end
            end
            local set,change=model.set,model.change
            function model:set(i,value,...)
                local setting=self.items and self.items[i]
                if navigating(setting) and type(value)=='number' then
                    if value~=1 and not self.error then steps[#steps+1]={setting=setting,direction=value<1 and -1 or 1} end
                    return
                end
                return set(self,i,value,...)
            end
            function model:change(i,direction,...)
                local setting=self.items and self.items[i]
                if navigating(setting) then
                    if direction and not self.error then steps[#steps+1]={setting=setting,direction=direction==1 and -1 or 1} end
                    return
                end
                return change(self,i,direction,...)
            end
            return model
        end
        -- Applied notifications carry numbers only; text values stay with the page's storage.
        local api=modules.settingsApi
        if api and type(api.publish)=='function' then
            local publish=api.publish
            api.publish=function(id,event,...)
                if type(event)=='table' and type(event.values)=='table' then
                    local values,changes={},{}
                    for key,value in pairs(event.values) do
                        if type(value)=='number' then values[key]=value;changes[key]=event.changes and event.changes[key] end
                    end
                    if next(values)==nil then return true end
                    event={values=values,changes=changes}
                end
                return publish(id,event,...)
            end
        end
        local build=controls.build
        controls.build=function(tree,providers,uiApi)
            local ui=build(tree,providers,uiApi)
            local instances={}
            local function attach(index)
                local panel=ui.panels[index]
                if not panel or not panel.built or instances[index] then return end
                local list={}
                instances[index]=list
                for i,setting in ipairs(providers[index].choices or {}) do
                    local editor=editorOf(setting)
                    local row=panel.rows[i]
                    if editor and row then
                        local ok,instance=pcall(editor.build,row,setting,{tree=tree,api=uiApi,modules=modules})
                        if ok and instance then list[i]=instance
                        else report('FIELD_EDITOR_FAILED',setting.id..': '..tostring(ok and 'no editor' or instance)) end
                    end
                end
            end
            -- shown: only rows on screen, as the per-frame tick needs; a row hidden by
            -- its page's navigation has nothing to read until it shows again.
            local function each(callback,shown)
                local list=ui.active and instances[ui.active]
                if not list or not ui.model then return end
                local panel=ui.panels[ui.active]
                for i,instance in pairs(list) do
                    local row=shown and panel and panel.rows[i]
                    if not (row and row.visible==false) then
                        local ok,err=pcall(callback,i,instance)
                        if not ok then report('FIELD_EDITOR_FAILED',tostring(err)) end
                    end
                end
            end
            -- The footer hint follows the selected row's editor; Enter and A reach it.
            -- confirm.take(wants,api) -> whether Enter or A was pressed since the last call;
            -- it reads the controller only when wants is true. pointer(api) -> whether the
            -- left mouse button is down. hint.show(text or nil,api) shows or hides the hint.
            local confirm,hint,pointer=modules.confirm,modules.hint,modules.pointer
            local pointerDown=pointer and function() return pointer(uiApi)==true end
            local shownHint
            local function showHint(text)
                if text==shownHint or not hint then return end
                shownHint=text
                local ok,err=pcall(hint.show,text,uiApi)
                if not ok then report('FIELD_EDITOR_FAILED','hint: '..tostring(err)) end
            end
            local function selected()
                local list=ui.active and instances[ui.active]
                return list and ui.current and list[ui.current]
            end
            local prepare,show,refresh,tick,hide=ui.prepare,ui.show,ui.refresh,ui.tick,ui.hide
            function ui:prepare(index,...)
                local results=table.pack(prepare(self,index,...))
                attach(index)
                return table.unpack(results,1,results.n)
            end
            function ui:show(index,...)
                local results=table.pack(show(self,index,...))
                attach(index)
                for n in pairs(steps) do steps[n]=nil end
                -- Presses from before the page opened are dropped.
                if confirm then pcall(confirm.take,false,uiApi) end
                self:refresh()
                return table.unpack(results,1,results.n)
            end
            if hide then
                function ui:hide(...)
                    each(function(_,instance) if instance.focus then instance:focus(false) end end)
                    showHint(nil)
                    return hide(self,...)
                end
            end
            -- The setter: every refresh puts the model's value into the editor, and
            -- marks collisions; presentation colors the pickers in mcConflictPickers.
            function ui:refresh(...)
                local results=table.pack(refresh(self,...))
                local model=self.model
                local colliding,pickers=registry.conflicts(model)
                if model then model.mcConflictPickers=pickers end
                each(function(i,instance)
                    if not model.error then instance:set(model.pending[i],model.committed[i]) end
                    if instance.conflict then instance:conflict(colliding[i]==true) end
                end)
                return table.unpack(results,1,results.n)
            end
            -- The getter: an editor's change goes into DMM's model like any other edit.
            function ui:tick(...)
                local results=table.pack(tick(self,...))
                local changed=false
                local model=self.model
                local function edit(i,value)
                    if value~=nil and model and not model.error and value~=model.pending[i] then
                        model:set(i,value)
                        changed=true
                    end
                end
                local list=self.active and instances[self.active]
                local panel=self.active and self.panels[self.active]
                -- Steps go to their rows' editors; a navigation shell returns to its middle.
                local queued={}
                for n,entry in ipairs(steps) do queued[n]=entry;steps[n]=nil end
                if list and model and model.items then
                    for _,entry in ipairs(queued) do
                        for i,setting in ipairs(model.items) do
                            local instance=list[i]
                            if setting==entry.setting and instance and instance.step then
                                local ok,value=pcall(instance.step,instance,entry.direction)
                                if ok then edit(i,value) else report('FIELD_EDITOR_FAILED',setting.id..': '..tostring(value)) end
                            end
                        end
                    end
                    for i,setting in ipairs(model.items) do
                        local row=panel and panel.rows[i]
                        if navigating(setting) and row and row.visible~=false and row.nav then
                            pcall(function()
                                if row.nav:GetValue()~=1 then row.nav:SetValue(1);row.lastNavigation=row.nav:GetValue() end
                            end)
                        end
                    end
                end
                each(function(i,instance)
                    if instance.focus then instance:focus(self.current==i) end
                    edit(i,instance:tick(pointerDown))
                end,true)
                local current=selected()
                if confirm then
                    local wants=current and current.confirm~=nil
                    local ok,pressed=pcall(confirm.take,wants,uiApi)
                    if ok and pressed and wants then
                        local done,value=pcall(current.confirm,current)
                        if done then edit(self.current,value) else report('FIELD_EDITOR_FAILED',tostring(value)) end
                    end
                end
                local text
                if current and current.hint then
                    local ok,label=pcall(current.hint,current)
                    text=ok and label or nil
                end
                showHint(text)
                if changed then self:refresh() end
                return table.unpack(results,1,results.n)
            end
            return ui
        end
    end
    return registry
end

M._test={sections=sections}
return M

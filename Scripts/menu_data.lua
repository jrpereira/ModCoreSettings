-- Compiles a contributed page's menu data into the settings manifest DMM parses. Menu data
-- describes a page without DMM's vocabulary, so contributors never write manifests:
--
-- {storage={file='config.ini',section='Settings'},    -- optional; file is relative to the
--                                                      -- page's configDirectory
--  groups={{id=,label=,style=,conditions=,help=,silent=true,parent={label=},
--      groups={<subgroup>,...}},...},
--  fields={{id=,group=,label=,description=,type=,values=,default=,widget=,style=,silent=true,
--      conditions=,action=true,link=,slot=,slotLabel=true,slotGroups=true,tabsWidth=,wrap=true,
--      table={entries={{code=,text=},...},columns=}},...}}
--
-- A field's type is what it holds (the model) and its widget how it shows (the view):
--   type='enum'    values={{value=,label=,note=,module=,sound=},...}; default=<a value>
--                  widget='picker' (default) | 'tabs' (up to 8) | 'cycler' | 'switch'
--                  (values 0 and 1) | 'text' (a shown value) | 'table' (with table=)
--   type='integer' values={min=,max=,step=,suffix=}; default=<number>; widget='slider'
--   type='range'   values={min=,max=,step=,suffix=,delta=}; default={low,high}; widget='range'
--                  min and max are an edge, or {low marker's, high marker's}; delta is the
--                  smallest and largest high-low, {min,max}, or one number for both.
-- type may be left out when values says it: a list is an enum, {min=,max=} an integer. A
-- range is always declared. text and table rows are shown, never stored.
--
-- style sets how a row stands out; sizes otherwise follow its place on the page:
--   fields: 'title' (an enum in the page title row, one per page), 'category' (the row
--           stands in for its group's heading), 'notice' (small, muted text)
--   groups: 'category' (default: headed by its label, else its id), 'none' (no heading)
--
-- conditions holds everything that changes with state while the menu is open:
--   visible={field=,values={...},playerExists=}  shown while all of these hold
--   label={field=,values={[value]='text'}}       named after that enum's value
--   dim={value,...}                              (enum fields) faded while its own value is one
--   order={field=,values={[value]=rank}}         (groups) ordered by that enum's value
-- A label or order key may be a list of values sharing the entry ([{1,2}]='text'). A rule's
-- field is an enum on the page.
--
-- Groups keep their declared order, and fields theirs within their group. A group's groups
-- are its subgroups (one level): smaller headings after its own rows, whose rows indent
-- further (mcWithin). A choice's note is shown under it; module=<mod folder> notes that mod's
-- name. sound=<Wwise event path under /Game/> or 'none' plays on a change to that choice
-- (mcChoiceSounds). action rows are navigation and are never stored; link=<page id or
-- provider:slot> opens that page. A single choice makes a button or, as text, a shown value.
-- slot=<name> makes a text field the page's slot <name>: other contributors' rows replace it
-- (slotLabel=true: the first takes its label; slotGroups=true: rows keep their own groups as
-- headings). Errors raise with the offending id.
local ChoiceSound=require('mcs_choice_sound')
local Contributions=require('menu_contributions')
local Range=require('range_editor')
local M={version=1}

local MAX_FIELDS,MAX_GROUPS,MAX_CHOICES,MAX_TABLE=256,256,64,256

local function text(value,where,limit)
    assert(type(value)=='string' and value~='' and #value<=(limit or 4096)
        and not value:find('[%c|;%[%]]') and not value:match('^%s') and not value:match('%s$'),
        'invalid '..where)
    return value
end
local function identifier(value,where)
    assert(type(value)=='string' and #value<=128 and value:match('^[%w_.:-]+$'),'invalid '..where)
    return value
end
local function number(value,where)
    assert(type(value)=='number' and value==value and math.abs(value)<=1000000000,'invalid '..where)
    return value
end
local function flag(value,where)
    assert(value==nil or type(value)=='boolean','invalid '..where)
    return value
end
local function format(value)
    return math.type(value)=='integer' and tostring(value)
        or value%1==0 and string.format('%d',value) or string.format('%.17g',value)
end
local function allowed(value,keys,where)
    assert(type(value)=='table','invalid '..where)
    for key in pairs(value) do assert(keys[key],where..': unknown field '..tostring(key)) end
end
local function list(value,where,limit)
    assert(type(value)=='table' and #value<=limit,'invalid '..where)
    for key in pairs(value) do
        assert(math.type(key)=='integer' and key>=1 and key<=#value,where..' must be a list')
    end
    return value
end

-- options.moduleName(folder) (optional) names a mod folder for choice notes.
function M.manifest(menu,options)
    options=options or {}
    allowed(menu,{storage=true,groups=true,fields=true},'menu')
    local storage=menu.storage
    if storage~=nil then
        allowed(storage,{file=true,section=true},'menu storage')
        text(storage.file,'storage file',1024)
        assert(not storage.file:match('^[/\\]') and not storage.file:match('^%a:')
            and not storage.file:find('%.%.'),'storage file must be relative to configDirectory')
        identifier(storage.section,'storage section')
    end
    -- A group's groups are its subgroups, one level deep; they follow its own rows.
    local groups,byGroup={},{}
    local function addGroup(group,where,within)
        allowed(group,{id=true,label=true,style=true,conditions=true,groups=not within,
            help=true,silent=true,parent=not within},where)
        text(group.id,where..' id',128)
        assert(not byGroup[group.id],'duplicate group '..group.id)
        if group.label~=nil then text(group.label,group.id..' label') end
        assert(group.style==nil or group.style=='category' or group.style=='none',
            group.id..': a group style is category or none')
        if group.help~=nil then text(group.help,group.id..' help') end
        flag(group.silent,group.id..' silent')
        if group.conditions~=nil then allowed(group.conditions,{visible=true,label=true,order=true},group.id..' conditions') end
        if group.parent~=nil then
            allowed(group.parent,{label=true},group.id..' parent')
            text(group.parent.label,group.id..' parent label')
        end
        groups[#groups+1]=group
        byGroup[group.id]={used=false,rank=#groups,within=within}
        assert(#groups<=MAX_GROUPS,'invalid menu groups')
    end
    for n,group in ipairs(list(menu.groups or {},'menu groups',MAX_GROUPS)) do
        addGroup(group,'group '..n)
        for c,child in ipairs(list(group.groups or {},group.id..' groups',MAX_GROUPS)) do
            addGroup(child,group.id..' group '..c,group.id)
        end
    end
    local WIDGETS={enum={picker=true,tabs=true,cycler=true,switch=true,text=true,table=true},
        integer={slider=true},range={range=true}}
    local DEFAULT_WIDGET={enum='picker',integer='slider',range='range'}
    -- A range's min, max or delta: one number for both, or a pair.
    local function pair(value,where)
        if type(value)=='number' then return value,value end
        list(value,where,2)
        assert(#value==2 or #value==1,'invalid '..where)
        return value[1],value[2]
    end
    local function whole(value,where)
        assert(number(value,where)%1==0,where..' must be whole')
        return value
    end
    local fields,byField,titles,slots={},{},0,{}
    for n,field in ipairs(list(menu.fields or {},'menu fields',MAX_FIELDS)) do
        local where='field '..n
        allowed(field,{id=true,group=true,label=true,description=true,type=true,values=true,default=true,
            widget=true,style=true,silent=true,conditions=true,action=true,link=true,slot=true,slotLabel=true,
            slotGroups=true,tabsWidth=true,wrap=true,table=true},where)
        identifier(field.id,where..' id')
        assert(not byField[field.id],'duplicate field '..field.id)
        where=field.id
        assert(byGroup[field.group],where..': unknown group '..tostring(field.group))
        byGroup[field.group].used=true
        text(field.label,where..' label')
        if field.description~=nil then
            assert(type(field.description)=='string' and #field.description<=4096
                and not field.description:find('%c'),where..': invalid description')
        end
        assert(type(field.values)=='table',where..': needs values')
        local kind=field.type
        if kind==nil then
            kind=field.values[1]~=nil and 'enum' or field.values.min~=nil and 'integer' or nil
            assert(kind,where..': needs a type')
        end
        assert(WIDGETS[kind],where..': type is enum, integer or range')
        local widget=field.widget or DEFAULT_WIDGET[kind]
        assert(WIDGETS[kind][widget],where..': '..kind..' takes no '..tostring(widget)..' widget')
        if field.conditions~=nil then allowed(field.conditions,{visible=true,label=true,dim=true},where..' conditions') end
        for _,name in ipairs({'action','silent','wrap','slotLabel','slotGroups'}) do
            flag(field[name],where..' '..name)
        end
        local shown=widget=='text' or widget=='table'
        local record={field=field,kind=kind,widget=widget,shown=shown}
        local values={}
        if kind=='enum' then
            local choices=list(field.values,where..' values',MAX_CHOICES)
            assert(#choices>=1,where..': needs a value')
            assert(widget~='tabs' or #choices<=8,where..': tabs take at most eight values')
            for c,choice in ipairs(choices) do
                allowed(choice,{value=true,label=true,note=true,module=true,sound=true},where..' value '..c)
                number(choice.value,where..' value')
                assert(not values[choice.value],where..': duplicate value')
                text(choice.label,where..' value label')
                assert(choice.note==nil or choice.module==nil,where..': a value has a note or a module')
                if choice.note~=nil then text(choice.note,where..' value note',64) end
                if choice.module~=nil then text(choice.module,where..' value module',255) end
                if choice.sound~=nil then
                    assert(type(choice.sound)=='string' and (choice.sound=='none' or ChoiceSound.path(choice.sound)),
                        where..': invalid value sound')
                end
                values[choice.value]=true
            end
            assert(widget~='switch' or #choices==2 and choices[1].value==0 and choices[2].value==1,
                where..': a switch takes the values 0 and 1')
            number(field.default,where..' default')
            assert(values[field.default],where..': default is not a value')
        elseif kind=='integer' then
            allowed(field.values,{min=true,max=true,step=true,suffix=true},where..' values')
            local range=field.values
            whole(range.min,where..' min');whole(range.max,where..' max')
            if range.step~=nil then whole(range.step,where..' step') end
            assert(range.min<range.max and (range.step==nil or range.step>=1 and range.step<=range.max-range.min),
                where..': invalid integer values')
            if range.suffix~=nil then text(range.suffix,where..' suffix',8) end
            assert(whole(field.default,where..' default')>=range.min and field.default<=range.max,
                where..': default outside the values')
        else
            allowed(field.values,{min=true,max=true,step=true,suffix=true,delta=true},where..' values')
            local range=field.values
            local lowMin,highMin=pair(range.min,where..' min')
            local lowMax,highMax=pair(range.max,where..' max')
            lowMin,highMax=whole(lowMin,where..' min'),whole(highMax,where..' max')
            highMin,lowMax=whole(highMin or lowMin,where..' min'),whole(lowMax or highMax,where..' max')
            assert(lowMin<=highMin and lowMax<=highMax and lowMin<=lowMax and highMin<=highMax,
                where..': each marker needs min <= max, and the low marker\'s bounds <= the high marker\'s')
            local deltaMin,deltaMax
            if range.delta~=nil then
                deltaMin,deltaMax=pair(range.delta,where..' delta')
                whole(deltaMin,where..' delta')
                if deltaMax~=nil then whole(deltaMax,where..' delta') end
            end
            if range.step~=nil then whole(range.step,where..' step') end
            if range.suffix~=nil then text(range.suffix,where..' suffix',8) end
            local function raw(value) return value~=nil and format(value) or nil end
            local ok,setting=pcall(Range.declare,{Min=raw(lowMin),Max=raw(highMax),Step=raw(range.step),
                LowMax=raw(lowMax),HighMin=raw(highMin),DeltaMin=raw(deltaMin),DeltaMax=raw(deltaMax),Suffix=range.suffix})
            assert(ok,where..': invalid range: '..tostring(setting))
            local d=field.default
            local default=type(d)=='table' and type(d[1])=='number' and type(d[2])=='number' and next(d,2)==nil
                and format(d[1])..'|'..format(d[2])
            assert(default and Range.normalize(setting,default)==default,where..': default outside the range')
            record.range={lowMin=lowMin,highMax=highMax,lowMax=lowMax~=highMax and lowMax or nil,
                highMin=highMin~=lowMin and highMin or nil,deltaMin=deltaMin,deltaMax=deltaMax,default=default}
        end
        if field.style~=nil then
            assert(field.style=='title' or field.style=='category' or field.style=='notice',
                where..': a field style is title, category or notice')
            assert(field.style~='title' or kind=='enum',where..': a title row is an enum')
            if field.style=='title' then titles=titles+1 end
        end
        if field.link~=nil then text(field.link,where..' link',256) end
        assert(not (field.action or field.link) or kind=='enum' and not shown,
            where..': action and link rows are enums that are not text or table')
        if field.slot~=nil then
            assert(type(field.slot)=='string' and #field.slot<=64 and field.slot:match('^[%w_]+$'),where..': invalid slot')
            assert(widget=='text',where..': a slot is a text field')
            assert(not slots[field.slot],where..': duplicate slot '..field.slot)
            slots[field.slot]=true
        end
        assert(field.slotLabel==nil or field.slotLabel==true and field.slot~=nil,where..': slotLabel needs a slot')
        assert(field.slotGroups==nil or field.slotGroups==true and field.slot~=nil,where..': slotGroups needs a slot')
        if field.tabsWidth~=nil then
            assert(widget=='tabs' and math.type(field.tabsWidth)=='integer' and field.tabsWidth>=160
                and field.tabsWidth<=440,where..': tabsWidth is 160 through 440 on tabs')
        end
        assert(not field.wrap or widget=='text',where..': wrap needs a text widget')
        local dim=field.conditions and field.conditions.dim
        if dim~=nil then
            assert(kind=='enum',where..': dim needs an enum')
            for _,value in ipairs(list(dim,where..' dim',MAX_CHOICES)) do
                assert(values[value],where..': dim value outside the values')
            end
        end
        assert((field.table~=nil)==(widget=='table'),where..': a table widget needs table=, and table= a table widget')
        if field.table~=nil then
            allowed(field.table,{entries=true,columns=true},where..' table')
            local entries=list(field.table.entries,where..' table entries',MAX_TABLE)
            assert(#entries>0,where..': a table needs entries')
            for e,entry in ipairs(entries) do
                allowed(entry,{code=true,text=true},where..' table entry '..e)
                for _,part in ipairs({'code','text'}) do
                    local value=entry[part]
                    assert(type(value)=='string' and value~='' and utf8.len(value) and utf8.len(value)<=8
                        and not value:find('[%c|]') and not value:match('^%s') and not value:match('%s$')
                        and (part=='text' or not value:find(':',1,true)),where..': invalid table entry '..e)
                end
            end
            local columns=field.table.columns
            assert(columns==nil or math.type(columns)=='integer' and columns>=1 and columns<=6,
                where..': table columns are 1 through 6')
        end
        fields[n],byField[field.id]=record,values
    end
    assert(titles<=1,'only one title field per page')
    -- A group's rows stay together, in their declared order, and groups keep theirs.
    for _,group in ipairs(groups) do
        local within=byGroup[group.id].within
        if byGroup[group.id].used and within then byGroup[within].shown=true end
    end
    local order={}
    for n,record in ipairs(fields) do order[record]=n end
    table.sort(fields,function(a,b)
        local ra,rb=byGroup[a.field.group].rank,byGroup[b.field.group].rank
        if ra~=rb then return ra<rb end
        return order[a]<order[b]
    end)
    -- A rule's source is a picker on this page; its values must be that picker's choices.
    local function rule(value,where,map)
        allowed(value,{field=true,values=true},where)
        local source=byField[value.field]
        assert(source and next(source),where..': source must be a picker on this page')
        local out={}
        if map then
            for choice,label in pairs(Contributions.unfold(value.values,where..' values')) do
                assert(source[choice],where..': value outside the source choices')
                out[#out+1]={choice,text(label,where..' text')}
            end
            table.sort(out,function(a,b) return a[1]<b[1] end)
            assert(#out>0,where..': needs a value')
        else
            for _,choice in ipairs(list(value.values,where..' values',MAX_CHOICES)) do
                assert(source[choice],where..': value outside the source choices')
                out[#out+1]=format(choice)
            end
            assert(#out>0,where..': needs a value')
        end
        return value.field,out
    end
    local lines={}
    local function section(name,keys)
        lines[#lines+1]='['..name..']'
        for _,pair in ipairs(keys) do
            if pair[2]~=nil then lines[#lines+1]=pair[1]..'='..tostring(pair[2]) end
        end
        lines[#lines+1]=''
    end
    local function bit(value) if value==nil then return nil end return value and 1 or 0 end
    -- visible: a picker rule, the player, or both; all must hold.
    local function visible(value,where)
        if value==nil then return nil,nil,nil end
        where=where..' visible'
        allowed(value,{field=true,values=true,playerExists=true},where)
        flag(value.playerExists,where..' playerExists')
        assert((value.field==nil)==(value.values==nil),where..': field and values go together')
        assert(value.field~=nil or value.playerExists~=nil,where..': needs a field or playerExists')
        if value.field==nil then return nil,nil,bit(value.playerExists) end
        local source,values=rule({field=value.field,values=value.values},where)
        return source,table.concat(values,'|'),bit(value.playerExists)
    end
    local function relabel(value,where)
        if value==nil then return nil,nil end
        local source,pairs=rule(value,where..' label',true)
        local out={}
        for n,pair in ipairs(pairs) do out[n]=format(pair[1])..':'..pair[2] end
        return source,table.concat(out,';')
    end
    -- order={field=,values={[value]=rank}} moves the group among the other ordered groups.
    local function ordering(value,where)
        if value==nil then return nil,nil end
        allowed(value,{field=true,values=true},where)
        local source=byField[value.field]
        assert(source and next(source),where..': source must be a picker on this page')
        local out={}
        for choice,rank in pairs(Contributions.unfold(value.values,where..' values')) do
            assert(source[choice],where..': value outside the source choices')
            number(rank,where..' rank')
            assert(math.abs(rank)<=1000000,where..': rank too large')
            out[#out+1]={choice,rank}
        end
        assert(#out>0,where..': needs a value')
        table.sort(out,function(a,b) return a[1]<b[1] end)
        for n,pair in ipairs(out) do out[n]=format(pair[1])..':'..format(pair[2]) end
        return value.field,table.concat(out,';')
    end
    -- DMM takes no category without rows, so a group without rows of its own heads its
    -- subgroups through them (mcWithinLabel), and has no rules of its own.
    local byId={}
    for _,group in ipairs(groups) do byId[group.id]=group end
    for _,group in ipairs(groups) do
        local entry=byGroup[group.id]
        if entry.shown and not entry.used then
            assert(group.conditions==nil and group.help==nil and group.silent==nil and group.parent==nil,
                group.id..': a group without rows takes no rules or presentation of its own')
        end
        if entry.used then
            local outer=entry.within and byId[entry.within]
            local outerLabel=outer and not byGroup[outer.id].used and outer.style~='none' and (outer.label or outer.id) or nil
            local conditions=group.conditions or {}
            local when,values,player=visible(conditions.visible,group.id)
            local labelWhen,labels=relabel(conditions.label,group.id)
            local orderWhen,orders=ordering(conditions.order,group.id..' order')
            section('Category.'..group.id,{{'mcLabel',group.label~=nil and group.label~=group.id and group.label or nil},
                {'mcHeading',group.style=='none' and 0 or nil},
                {'mcWithin',entry.within},{'mcWithinLabel',outerLabel},
                {'VisibleWhen',when},{'VisibleValues',values},{'mcLabelWhen',labelWhen},{'mcLabels',labels},
                {'mcHelp',group.help},{'mcSilent',group.silent and 1 or nil},{'mcPlayerExists',player},
                {'mcParent',group.parent and group.parent.label},
                {'mcOrderWhen',orderWhen},{'mcOrders',orders}})
        end
    end
    local MC_TYPES={tabs='tab',cycler='cycle',switch='onoff'}
    local MC_STYLES={title={'mcHeading',1},category={'mcCategory',1},notice={'mcLevel',5}}
    for _,record in ipairs(fields) do
        local field,widget=record.field,record.widget
        local keys={{'Id',field.id},{'Label',field.label},{'Group',field.group},
            {'Description',field.description}}
        local function add(key,value) keys[#keys+1]={key,value} end
        if record.kind=='enum' then
            local values,labels,notes,sounds={},{},{},{}
            for n,choice in ipairs(field.values) do
                values[n],labels[n]=format(choice.value),choice.label
                local note=choice.note
                if choice.module then
                    note=options.moduleName and options.moduleName(choice.module) or choice.module
                    note=type(note)=='string' and note:gsub('[%c|;%[%]]',' '):sub(1,64):match('^%s*(.-)%s*$') or ''
                    if note=='' then note=nil end
                end
                if note then notes[#notes+1]=values[n]..':'..note end
                if choice.sound then sounds[#sounds+1]=values[n]..':'..choice.sound end
            end
            -- DMM needs two choices; a single one (a button or shown value) repeats.
            if #values==1 then
                values[2],labels[2]=format(field.values[1].value+1),labels[1]
            end
            add('Type','picker');add('PresetValues',table.concat(values,'|'))
            add('PresetLabels',table.concat(labels,'|'))
            add('mcChoiceNotes',#notes>0 and table.concat(notes,';') or nil)
            add('mcChoiceSounds',#sounds>0 and table.concat(sounds,';') or nil)
            add('mcType',MC_TYPES[widget]);add('mcTabsWidth',field.tabsWidth)
            local dimmed=field.conditions and field.conditions.dim
            if dimmed then
                local dim={}
                for n,value in ipairs(dimmed) do dim[n]=format(value) end
                add('mcDimValues',table.concat(dim,'|'))
            end
            if field.table then
                local entries={}
                for n,entry in ipairs(field.table.entries) do entries[n]=entry.code..':'..entry.text end
                add('mcTable',table.concat(entries,'|'));add('mcColumns',field.table.columns)
            end
            add('mcWrap',field.wrap and 1 or nil)
            add('Default',format(field.default))
        elseif record.kind=='integer' then
            local range=field.values
            add('Type','integer');add('Minimum',format(range.min));add('Maximum',format(range.max))
            add('Step',range.step and format(range.step) or nil);add('Suffix',range.suffix)
            add('Default',format(field.default))
        else
            local range,bounds=field.values,record.range
            local function opt(value) return value~=nil and format(value) or nil end
            add('Type','range');add('Min',format(bounds.lowMin));add('Max',format(bounds.highMax))
            add('Step',opt(range.step));add('LowMax',opt(bounds.lowMax));add('HighMin',opt(bounds.highMin))
            add('DeltaMin',opt(bounds.deltaMin));add('DeltaMax',opt(bounds.deltaMax));add('Suffix',range.suffix)
            add('Default',bounds.default)
        end
        local style=field.style and MC_STYLES[field.style]
        if style then add(style[1],style[2]) end
        local conditions=field.conditions or {}
        local when,values,player=visible(conditions.visible,field.id)
        add('VisibleWhen',when);add('VisibleValues',values);add('mcPlayerExists',player)
        local labelWhen,labels=relabel(conditions.label,field.id)
        add('mcLabelWhen',labelWhen);add('mcLabels',labels)
        if field.action or field.link then add('mcNavigation',1) end
        add('mcLinkPage',field.link)
        add('mcReadOnly',record.shown and 1 or nil)
        add('mcSlot',field.slot);add('mcSlotLabel',field.slotLabel and 1 or nil)
        add('mcSlotGroups',field.slotGroups and 1 or nil)
        add('mcSilent',field.silent and 1 or nil)
        if storage and not (field.action or field.link or record.shown) then
            add('ConfigFile',storage.file);add('ConfigSection',storage.section);add('ConfigKey',field.id)
        end
        section('Setting.'..field.id,keys)
    end
    local manifest=table.concat(lines,'\n')
    assert(#manifest<=256*1024,'menu exceeds 256 KiB')
    return manifest
end

return M

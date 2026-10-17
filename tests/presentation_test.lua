package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local M=require('presentation')
local items={
    {id='Primary',kind='picker',group='General',label='Primary',values={0,1},labels={'Consumables','Abilities'}},
    {id='Ability',kind='picker',group='Abilities',label='Ability',values={0,1},labels={'Tap','Hold'}},
    {id='Consumable',kind='picker',group='Consumables',label='Consumable',values={0,1},labels={'Tap','Hold'}},
    {id='Enabled',kind='toggle',group='General',label='Enabled',values={0,1},labels={'Off','On'}},
    {id='Key',kind='slider',group='Keys',label='Key'},
    {id='KeyMode',kind='picker',group='Keys',label='Mode',values={0,3,-1},labels={'Tap','Hold','Default'}},
}
local schema=[[
[Setting.Primary]
Id=Primary
mcType=tab
mcLevel=2
mcTabsWidth=440
[Setting.Ability]
Id=Ability
mcLabelWhen=Primary
mcLabels=0:Slot 5;1:Slot 1
[Category.Abilities]
mcHelp=Ability explanation
mcHeading=0
mcParent=Interaction: Independent
mcParentLevel=2
mcLevel=3
mcLabelWhen=Primary
mcLabels=0:Secondary Wheel;1:Primary Wheel
mcOrderWhen=Primary
mcOrders=0:20;1:10
[Category.Consumables]
mcParent=Interaction: Independent
mcParentLevel=2
mcLabelWhen=Primary
mcLabels=0:Primary Wheel;1:Secondary Wheel
mcOrderWhen=Primary
mcOrders=0:10;1:20
[Category.Keys]
mcParent=Interaction: Selective
mcParentLevel=2
mcLevel=3
mcLabel=Key Bindings
[Setting.Enabled]
Id=Enabled
mcHeading=true
[Setting.Key]
Id=Key
[Setting.KeyMode]
Id=KeyMode
]]
M.parse(schema,items)
assert(items[1].mcTabs and items[1].mcFont==2 and items[1].mcTabsWidth==440)
assert(items[2].mcLabelRule.values[0]=='Slot 5')
assert(items[2].mcGroup.parent==items[3].mcGroup.parent,'Shared parent labels must share one descriptor')
assert(items[2].mcGroup.parent.label=='Interaction: Independent' and items[2].mcGroup.parent.font==2)
assert(not items[2].mcGroup.heading and items[3].mcGroup.heading)
assert(items[5].mcGroup.parent.label=='Interaction: Selective')
M.parse(schema:gsub('mcType=tab','DecoType=tab'):gsub('mcLevel=2','DecoLevel=2')
    :gsub('mcTabsWidth=440','DecoTabsWidth=440'),items)
assert(not items[1].mcTabs and items[1].mcFont==nil,'noncanonical metadata must be ignored')
M.parse(schema:gsub('mc','amm'),items)
assert(not items[1].mcTabs and items[1].mcFont==nil,'old amm metadata must not be read')
assert(not pcall(M.parse,schema:gsub('mcType=tab','mcType=tabs'),items))
assert(not pcall(M.parse,schema:gsub('mcTabsWidth=440','mcTabsWidth=441'),items))
assert(not pcall(M.parse,schema:gsub('mcType=tab','mcType=keybind'),items))
assert(not pcall(M.parse,schema:gsub('mcHeading=true','mcHeading=invalid'),items))
M.parse(schema,items)
assert(not pcall(M.parse,schema:gsub('mcLevel=2','mcLevel=9'),items))
assert(not pcall(M.parse,schema:gsub('mcHeading=0','mcHeading=invalid'),items))
assert(not pcall(M.parse,schema:gsub('mcLabelWhen=Primary','mcLabelWhen=Missing'),items))
local parentItems={{id='One',kind='toggle',group='One',values={0,1}},{id='Two',kind='toggle',group='Two',values={0,1}}}
assert(not pcall(M.parse,'[Category.One]\nmcParent=\n',parentItems))
assert(not pcall(M.parse,'[Category.One]\nmcLabel= \n',parentItems),'mcLabel needs text')
assert(not pcall(M.parse,'[Category.One]\nmcParentLevel=2\n',parentItems))
assert(not pcall(M.parse,'[Category.One]\nmcParent=Shared\nmcParentLevel=2\n[Category.Two]\nmcParent=Shared\nmcParentLevel=3\n',parentItems))
M.parse(schema,items)
-- UE4SS gives a fresh Lua wrapper for every lookup, so two wrappers of one widget are
-- never equal and never the same table key. GetChildAt answers with such a wrapper: it
-- reads and writes through to the widget, but only its full name identifies it.
local widgets,originals=0,setmetatable({},{__mode='k'})
local function original(child) return originals[child] or child end
local function widget()
    widgets=widgets+1
    local w={children={},Font={SkewAmount=0},enabled=true,position=0,visible=0,id=widgets,
        WidgetStyle={NormalPadding={Left=16,Top=0,Right=0,Bottom=0},
            PressedPadding={Left=16,Top=0,Right=0,Bottom=0}}}
    function w:GetFullName() return 'Widget '..self.id end
    function w:IsValid() return true end
    function w:GetParent() return self.parent end
    function w:GetChildrenCount() return #self.children end
    function w:GetChildAt(n)
        local child=self.children[n+1]
        if child==nil then return nil end
        local wrapper=setmetatable({},{__index=child,__newindex=child})
        originals[wrapper]=child
        return wrapper
    end
    function w:GetContent() return self.children[1] end
    function w:AddChild(child)
        child=original(child)
        child.parent=self;self.children[#self.children+1]=child
        child.Slot={Padding={Left=0,Top=0,Right=0,Bottom=0}}
        setmetatable(child.Slot,{__index=function(_,key)
            return function(slot,value) slot[key:sub(4)]=value end
        end})
        return child.Slot
    end
    function w:RemoveChild(child)
        child=original(child)
        for n,v in ipairs(self.children) do if v==child then table.remove(self.children,n);child.parent=nil;return true end end
        return false
    end
    function w:RemoveFromParent() if self.parent then self.parent:RemoveChild(original(self)) end end
    function w:ClearChildren() for _,child in ipairs(self.children) do child.parent=nil end;self.children={} end
    function w:SetContent(child) self:ClearChildren();return self:AddChild(child) end
    function w:SetVisibility(v) self.visible=v end
    function w:GetVisibility() return self.visible end
    function w:SetValue(v) self.position=v end
    function w:GetValue() return self.position end
    function w:SetIsEnabled(v) self.enabled=v end
    function w:GetIsEnabled() return self.enabled end
    function w:IsPressed() return self.pressed or false end
    function w:IsHovered() return self.hovered or false end
    function w:HasUserFocus() return false end
    function w:SetRenderOpacity(v) assert(type(v)=='number');self.opacity=v end
    function w:SetFont(v) self.Font=v end
    function w:SetJustification(v) self.Justification=v end
    function w:SetWidthOverride(v) self.WidthOverride=v end
    function w:ClearWidthOverride() self.WidthOverride=nil end
    function w:SetHeightOverride(v) self.HeightOverride=v end
    function w:ClearHeightOverride() self.HeightOverride=nil;self.heightCleared=true end
    function w:SetMinDesiredHeight(v) self.MinDesiredHeight=v end
    function w:SetMinDesiredWidth(v) self.MinDesiredWidth=v end
    function w:SetAutoWrapText(v) self.AutoWrapText=v end
    function w:SetBrushColor(v) self.BrushColor=v end
    function w:SetColorAndOpacity(v) self.colorAndOpacity=v;self.color=nil end
    function w:SetRenderTranslation(v) self.RenderTranslation=v end
    return setmetatable(w,{__index=function(_,key)
        if key:match('^Set') or key=='ForceVolatile' or key=='ScrollToStart' or key=='ScrollWidgetIntoView' then return function() end end
    end})
end
local noop=function() end
local theme={font=function(label,_,size) label.Font.Size=size end,textColor=function(label,color) label.color=color end,
    selectionState=function() return 0 end,image=widget,sliderTrack=function() return widget(),widget() end}
setmetatable(theme,{__index=function() return noop end})
local api={construct=widget,need=assert,Theme=theme,theme={assets={}},caption=function(_,text) local w=widget();w.text=text;return w end,
    setText=function(w,text) w.text=text end,describe=noop,actions=noop,status=noop,log=noop}
api.events={emit=function(_,name,context)
    assert(name=="providerRefreshed")
    context.panel.readyEvents=(context.panel.readyEvents or 0)+1
end}
api.button=function(tree,text) local b=widget();local l=api.caption(tree,text);b:SetContent(l);return b,l end
local choices={parse=function() return items end,format=function(setting,value)
    for i,candidate in ipairs(setting.values or {}) do
        if candidate==value then return setting.labels[i] end
    end
    return tostring(value)
end}
function choices.snap(setting,value)
    local steps=math.floor((value-setting.minimum)/setting.step+0.5)
    return math.max(setting.minimum,math.min(setting.maximum,setting.minimum+steps*setting.step))
end
local pages={build=function(tree,providers,status,a)
    local filterButton,filterLabel=a.button(tree,'Compatible Mods')
    local browserList=widget()
    local filterWrapper=widget();filterWrapper:SetContent(filterButton);browserList:AddChild(filterWrapper)
    filterWrapper:SetWidthOverride(590);filterWrapper:SetHeightOverride(40)
    local parent=widget()
    local title=a.caption(tree,'Mod Settings');parent:AddChild(title)
    local divider=widget();parent:AddChild(divider)
    local status=a.caption(tree,'');parent:AddChild(status)
    status.Slot:SetPadding({Left=0,Top=4,Right=0,Bottom=0})
    -- UE4SS may return another Lua wrapper for the same UMG widget.
    local titleWrapper={Slot=title.Slot,GetFullName=function() return title:GetFullName() end}
    local getChildAt,addChild=parent.GetChildAt,parent.AddChild
    function parent:GetChildAt(n)
        local child=getChildAt(self,n)
        return child and child:GetFullName()==title:GetFullName() and titleWrapper or child
    end
    function parent:AddChild(child)
        return addChild(self,child==titleWrapper and title or child)
    end
    local allRows={}
    local browserRows=widget()
    for index,provider in ipairs(providers) do
        local button,label=a.button(tree,provider.name)
        label.Slot:SetPadding({Left=20,Top=4,Right=12,Bottom=4})
        local wrapper=widget();wrapper:SetWidthOverride(584);wrapper:SetContent(button)
        browserRows:AddChild(wrapper)
        wrapper.Slot:SetPadding({Left=0,Top=0,Right=8,Bottom=0})
        allRows[#allRows+1]={widget=button,wrapper=wrapper,providerIndex=index}
    end
    local page={filterButton=filterButton,filterLabel=filterLabel,browserList=browserList,allRows=allRows,
        controls={},modTitle=title,controlStatus=status,mcTestControlArea=parent,mcTestDivider=divider,mcTestApi=a}
    function page:refresh(compatibleOnly)
        a.setText(self.filterLabel,compatibleOnly and 'Compatible Mods' or 'All Mods')
    end
    return page
end}
local controls={build=function(tree,providers,a)
    local ui={root=widget(),panels={{rows={},headings={},scroll=widget()}},model={items=items,pending={0,0,0,1,49,-1},committed={0,0,0,1,49,-1}}}
    ui.mcTestSetText,ui.mcTestFeedback,ui.mcTestHighlight=a.setText,a.feedback,a.highlight
    function ui.model:visibility() return {true,true,true,true,self.pending[1]==1,true} end
    function ui.root:SetActiveWidgetIndex() self.readyEvents=(self.readyEvents or 0)+1 end
    function ui.model:set(i,v) self.pending[i]=v end
    function ui.model:change(i) self.pending[i]=1-self.pending[i] end
    function ui:prepare()
        if self.mcTestFail then local message=self.mcTestFail;self.mcTestFail=nil;error(message,0) end
        local p=self.panels[1];if p.built then return end
        for i,s in ipairs(items) do
            local heading=a.caption(tree,s.group);p.scroll:AddChild(heading)
            p.headings[i]={widget=heading,first=i,last=i,visible=true}
            local b,l=a.button(tree,s.label)
            if s.kind=='toggle' or s.kind=='extension' then
                -- DMM's toggle row: the label sits in a size box in the content, whose
                -- slot carries the 20-pixel inset.
                local content,labelBox=widget(),widget()
                b:SetContent(content);labelBox:SetContent(l);content:AddChild(labelBox)
                content.Slot:SetPadding({Left=20,Top=0,Right=0,Bottom=0})
                labelBox:SetWidthOverride(350)
            else l.Slot:SetPadding({Left=20,Top=0,Right=8,Bottom=0}) end
            local box=widget();box:SetContent(b)
            local bg=widget();local overlay=widget();overlay:AddChild(bg);overlay:AddChild(box)
            local value=a.caption(tree,'')
            local slider
            if s.kind=='slider' then
                -- DMM's slider row: a 134-wide surface holding the track and the native
                -- slider, then a 90-wide value column.
                local surface,track=widget(),widget();slider=widget()
                surface:AddChild(track);surface:AddChild(slider)
                local surfaceBox,valueBox=widget(),widget()
                surfaceBox:SetWidthOverride(134);surfaceBox:SetContent(surface);overlay:AddChild(surfaceBox)
                valueBox:SetWidthOverride(90);valueBox:SetContent(value);overlay:AddChild(valueBox)
            elseif s.kind=='toggle' then
                -- DMM's toggle row: the value's 200-wide box follows the label's in the content.
                local valueBox=widget();valueBox:SetWidthOverride(200);valueBox:SetContent(value)
                b:GetContent():AddChild(valueBox)
            elseif s.kind~='picker' then overlay:AddChild(value) end
            local parts={}
            -- Like DMM, only a picker adds its left, value and right buttons after the label;
            -- its value text is the middle button's content.
            if s.kind=='picker' then
                for n=1,3 do
                    local b2=a.button(tree,n==1 and '<' or n==3 and '>' or '')
                    if n==2 then b2:SetContent(value);value.Slot:SetPadding({Left=4,Top=0,Right=4,Bottom=0}) end
                    local size=widget();size:SetContent(b2);overlay:AddChild(size);parts[n]={widget=b2}
                end
            end
            local wrapper=widget();wrapper:SetContent(overlay);p.scroll:AddChild(wrapper)
            p.rows[i]={widget=b,value=value,background=bg,parts=parts,wrapper=wrapper,nav=widget(),visible=true,slider=slider}
            -- mcTestRowHeight gives the row and its buttons' boxes DMM's fixed height.
            if self.mcTestRowHeight then
                wrapper:SetHeightOverride(self.mcTestRowHeight);box:SetHeightOverride(self.mcTestRowHeight)
                for _,part in ipairs(parts) do part.widget:GetParent():SetHeightOverride(self.mcTestRowHeight) end
            end
        end
        p.built=true
    end
    function ui:show(i) self.active=i;self:prepare(i);self:refresh() end
    function ui:hide() self.active=nil end
    function ui:refresh()
        local visible=self.model:visibility()
        for i,row in ipairs(self.panels[self.active].rows) do
            row.visible=visible[i]
            row.pressed,row.pointer=false,false
            for _,part in ipairs(row.parts or {}) do part.pressed,part.pointer=false,false end
        end
    end
    function ui:tick() self.ticks=(self.ticks or 0)+1;return false end
    function ui:clearPresses() end
    function ui:isPressed() return false end
    function ui:select(i) self.current=i end
    return ui
end}
-- DMM's lifecycle bus; the presentation listens for the menu closing.
local lifecycle={}
local lifecycleEvents={on=function(_,name,callback) lifecycle[name]=callback end}
assert(M.install(choices,controls,pages,{keyColumn={key=96,keyOffset=408},
    textTable=require('menu_contributions').textTable,events=lifecycleEvents}))
assert(type(lifecycle.hostClosing)=='function','the presentation listens for the menu closing')
assert(not M.install(choices,controls,pages))
local browserProviders={
    {name='Templates',choices=items},
    {name='Menu Controls',choices=items,mcBrowserLevel=4,mcBrowserIndent=20},
}
local page=pages.build(widget(),browserProviders,nil,api)
assert(#page.browserList.children==2 and page.browserList.children[2]:GetContent(),
    'Mod-browser title must have a themed divider immediately beneath it')
assert(page.filterLabel.Font.Size==page.controls.mcHeaderTitle.Font.Size and
    page.filterLabel.color==page.controls.mcHeaderTitle.color,'Compatible Mods must use the mod-title style')
local filterWrapper,filterStyle=page.filterButton:GetParent(),page.filterButton.WidgetStyle
assert(filterStyle.NormalPadding.Left==0 and filterStyle.NormalPadding.Top==0
    and filterStyle.PressedPadding.Left==0 and filterStyle.PressedPadding.Top==0
    and page.filterLabel.Slot.VerticalAlignment==1
    and filterWrapper.WidthOverride==572 and filterWrapper.heightCleared and filterWrapper.HeightOverride==nil,
    'The mod-browser title must sit like a page title: no button inset, top-aligned, divider width')
assert(page.mcTestControlArea.children[1]==page.controls.mcHeaderHost
    and page.mcTestControlArea.children[2]==page.mcTestDivider
    and page.controls.mcHeaderHost.children[1]==page.modTitle
    and page.modTitle.visible==4,
    'Mod title must share the first row with the picker above the divider')
assert(page.controls.mcHeaderHost.Slot.Padding.Bottom==0,'The title row must not add space above the divider')
assert(page.mcTestControlArea.children[3]:GetContent()==page.controls.mcHeaderTabs
    and #page.mcTestControlArea.children==3,
    'The header tab strip must sit directly beneath the divider')
local statusBox=page.controls.mcHeaderStatus.box
assert(#page.controls.mcHeaderTabs.children==1 and page.controls.mcHeaderTabs.children[1]==statusBox
    and statusBox:GetContent()==page.controlStatus and statusBox.WidthOverride==572
    and statusBox.Slot.HorizontalAlignment==1 and statusBox.Slot.VerticalAlignment==1
    and statusBox.Slot.Padding.Top==4,
    'The page status must start the header row beneath the divider, keeping its padding')
-- Unapplied changes show as a * after the page title, not as status text; every other
-- status stays text, and the * follows the model's dirty state.
local dirty,failed=true,nil
page.controls.model={dirty=function() return dirty end}
page.mcTestApi.setText(page.modTitle,'Controls')
page.mcTestApi.setText(page.controlStatus,'Unapplied changes')
assert(page.modTitle.text=='Controls *' and page.controlStatus.text=='','dirty: the title gains a * and the status is empty')
page.mcTestApi.setText(page.controlStatus,'Apply failed: disk full')
assert(page.controlStatus.text=='Apply failed: disk full' and page.modTitle.text=='Controls *',
    'a failed Apply still reads as text, and the page is still dirty')
dirty=false
page.mcTestApi.setText(page.controlStatus,'')
assert(page.modTitle.text=='Controls' and page.controlStatus.text=='','Apply or Restore clears the *')
page.controls.model={dirty=function() return true end,error='config unreadable'}
page.mcTestApi.setText(page.controlStatus,'config unreadable')
assert(page.controlStatus.text=='config unreadable' and page.modTitle.text=='Controls','an error reads as text, without a *')
page.controls.model=nil
page:refresh(false)
assert(page.filterLabel.text=='All Mods' and page.filterLabel.Font.Size==22 and page.filterLabel.color=='title',
    'Filter text changes must retain the mod-title style')
local modLabel=page.allRows[1].widget:GetContent()
assert(modLabel.text=='Templates' and modLabel.Font.Size==16 and modLabel.color=='muted',
    'Mod-list labels must use level-two styling')
assert(page.filterLabel.Slot.Padding.Left==0 and modLabel.Slot.Padding.Left==0,
    'Regular Mod Menu entries must use normal left alignment')
local categoryLabel=page.allRows[2].widget:GetContent()
assert(categoryLabel.text=='Menu Controls' and categoryLabel.Font.Size==14 and categoryLabel.color=='body',
    'Category modules must accept level-four browser styling')
assert(categoryLabel.Slot.Padding.Left==0
    and page.allRows[2].wrapper.Slot.Padding.Left==20
    and page.allRows[2].wrapper.WidthOverride==544,
    'Submodule button and highlight must both start at the browser indentation')
-- A group: a header with a horizontal line, then lines of its pages; hidden and
-- ungrouped rows keep their place.
local lineProviders={
    {name='Before',choices=items},
    {name='ModCore',choices=items,mcBrowserLine='head',mcBrowserIcon='⁂',mcBrowserKind='Collection'},
    {name='Templates',choices=items,mcBrowserLine='cell',mcBrowserLabel='T  Templates',mcBrowserLevel=4,mcBrowserIndent=20},
    {name='Visuals',choices=items,mcBrowserLine='cell',mcBrowserHidden=true,mcBrowserLevel=4,mcBrowserIndent=20},
    {name='Controls',choices=items,mcBrowserLine='cell',mcBrowserLevel=4,mcBrowserIndent=20},
    {name='Fangdango',choices=items,mcBrowserLine='cell',mcBrowserLevel=4,mcBrowserIndent=20},
    {name='After',choices=items},
}
local linePage=pages.build(widget(),lineProviders,nil,api)
local lineRows=linePage.allRows
local list=lineRows[1].wrapper:GetParent()
assert(#list.children==4 and list.children[1]==lineRows[1].wrapper and list.children[3]==lineRows[4].wrapper
    and list.children[4]==lineRows[7].wrapper,'the group box replaces the head row; hidden and other rows keep their place')
local group=list.children[2]
local park,header,grid=group.children[1],group.children[2],group.children[3]
assert(#group.children==3 and group.visible==0 and park.visible==1 and #park.children==0,
    'a group box holds its collapsed park, its header and its lines')
-- Widgets without a parent are not rooted and garbage collection frees them, so every
-- grouped page and header must stay in the list whatever the filter shows.
local function rooted(widget)
    while widget do
        if widget==list then return true end
        widget=widget.parent
    end
    return false
end
local function allRooted()
    for _,index in ipairs({2,3,5,6}) do
        if not rooted(lineRows[index].wrapper) then return false end
    end
    return true
end
assert(allRooted(),'every grouped page starts in the list')
-- The header: the icon in a box of its own, then the kind of group above the title,
-- then a rule filling the rest of the width.
assert(header.WidthOverride==584,'the header spans the list')
assert(header.Slot.Padding.Top==-4 and header.Slot.Padding.Bottom==8,'the header sits raised with a gap below')
local headerRow=header:GetContent()
local iconBox,text,headerRule=headerRow.children[1],headerRow.children[2],headerRow.children[3]
assert(#headerRow.children==3 and iconBox.WidthOverride==20 and iconBox:GetContent().text=='⁂'
    and iconBox:GetContent().Slot.HorizontalAlignment==2 and iconBox:GetContent().Slot.VerticalAlignment==2,
    'the icon sits centred in a box as wide as the left margin, over it')
assert(iconBox.Slot.Padding.Right==8,'the title follows the icon closely')
assert(iconBox:GetContent().Slot.Padding.Top==10,'the icon sits level with the title')
assert(type(text.Slot.Size)~='table' or text.Slot.Size.SizeRule~=1,'the text column is as wide as its widest line')
assert(headerRule.HeightOverride==2 and headerRule:GetContent() and headerRule.Slot.Size.SizeRule==1
    and headerRule.Slot.VerticalAlignment==1 and headerRule.Slot.Padding.Top==35 and headerRule.Slot.Padding.Left==8
    and headerRule.Slot.Padding.Right==6,'the rule sits 35 down, 8 right of the wider of title and kind, filling the rest but 6')
-- The title row (the highlight box) comes first; the kind line follows so it draws
-- over the box, pulled up into it.
local title,kind=text.children[1],text.children[2]
assert(title==lineRows[2].wrapper and title.Slot.Padding.Top==20 and title.HeightOverride==34,'the highlight box starts 20 down, 34 tall')
assert(title.WidthOverride==nil and title.Slot.HorizontalAlignment==1,'the title keeps its own width, left-aligned')
local titlePadding=title:GetContent():GetContent().Slot.Padding
assert(titlePadding.Left==-2 and titlePadding.Top==6 and titlePadding.Bottom==-1,'the title sits in its box')
assert(kind.text=='Collection' and kind.Font.Size==10 and kind.color=='muted' and kind.visible==4
    and kind.Slot.Padding.Top==-35 and kind.Slot.Padding.Left==10 and kind.opacity==0.6,
    'a small faint line names the kind of group, drawn over the box')
assert(math.abs(kind.Slot.Padding.Bottom-15.6)<0.01,'the kind line keeps the column as tall as the box')
assert(#grid.children==4 and grid.children[1].HeightOverride==34 and grid.children[1].WidthOverride==20+18
    and grid.children[1]:GetContent()==nil,'a grid row starts with a blank margin 18 wider than the icon column, no vertical line')
for n,index in ipairs({3,5,6}) do
    local frame=grid.children[n+1]
    assert(frame:GetContent()==lineRows[index].wrapper and frame.BrushColor and frame.BrushColor.A<0.2
        and lineRows[index].wrapper.WidthOverride==math.floor((584-38)/3)-9 and lineRows[index].wrapper.HeightOverride==34
        and frame.Slot.Padding.Right==9 and frame.Slot.Padding.Bottom==6,
        'pages fill three columns in order, each on a faint background, columns 9 and rows 6 px apart')
    local label=lineRows[index].widget:GetContent()
    assert(label.AutoWrapText==true,'a grid name wraps to a second line before it is cut off')
end
-- A filter that hides a page closes its gap; one that hides the heading hides the group.
linePage:mcLayoutGroups(function(row) return row~=lineRows[3] end)
grid=group.children[3]
assert(#group.children==3 and #grid.children==3 and grid.children[2]:GetContent()==lineRows[5].wrapper
    and grid.children[3]:GetContent()==lineRows[6].wrapper,'the next pages move up into the hidden page\'s place')
assert(allRooted() and #park.children==1 and park.children[1]:GetContent()==lineRows[3].wrapper,
    'a hidden page waits in the collapsed park')
linePage:mcLayoutGroups(function(row) return row~=lineRows[2] end)
assert(group.visible==1 and allRooted() and #group.children==1 and #park.children==4,
    'a hidden heading hides its whole group, its header and pages parked')
linePage:mcLayoutGroups()
assert(group.visible==0 and #group.children==3 and #group.children[3].children==4 and #park.children==0
    and allRooted(),'showing every page restores the grid')
local fourProviders={{name='ModCore',choices=items,mcBrowserLine='head'}}
for n=1,4 do fourProviders[#fourProviders+1]={name='Module '..n,choices=items,mcBrowserLine='cell'} end
-- A heading's row sits in the header text, row and width box, in its group.
local function groupBox(row) local w=row.wrapper;for _=1,4 do w=w:GetParent() end;return w end
local fourGroup=groupBox(pages.build(widget(),fourProviders,nil,api).allRows[1])
assert(#fourGroup.children==4 and #fourGroup.children[3].children==4 and #fourGroup.children[4].children==2,
    'a fourth page starts the next grid row')
assert(lineRows[3].widget:GetContent().text=='T  Templates','a short browser label replaces the page name')
local cellLabel=lineRows[3].widget:GetContent()
assert(cellLabel.LineHeightPercentage==0.8 and cellLabel.Slot.VerticalAlignment==2,
    'a wrapped cell name sits tight and centred')
-- The "and N more" entry has no background and a smaller font than its mods.
local moreProviders={
    {name='Group',choices=items,mcBrowserLine='head',mcBrowserIcon='▶',mcBrowserKind='Gameplay'},
    {name='Mod',choices=items,mcBrowserLine='row',mcBrowserLevel=4,mcBrowserIndent=20},
    {name='and 1 more with no settings',choices=items,mcBrowserLine='row',mcBrowserMore='g',
        mcBrowserLevel=4,mcBrowserIndent=20},
}
local morePage=pages.build(widget(),moreProviders,nil,api)
local modRow,moreRow=morePage.allRows[2],morePage.allRows[3]
assert(moreRow.mcFrame.BrushColor.A==0 and modRow.mcFrame.BrushColor.A>0,'the folded entry has no background')
assert(moreRow.widget:GetContent().Font.Size==11 and modRow.widget:GetContent().Font.Size==13,
    'grouped mod names are 12 points, the folded entry two sizes smaller')
assert(modRow.mcFrame:GetContent().HeightOverride==34 and modRow.widget:GetContent().Slot.Padding.Top==1
    and modRow.widget:GetContent().Slot.Padding.Bottom==1,'a grouped mod row is 3 shorter above and below')
assert(modRow.mcFrame.Slot.Padding.Left==2 and modRow.mcFrame.Slot.Padding.Right==7
    and modRow.mcFrame.Slot.Padding.Bottom==10 and modRow.widget:GetContent().Slot.Padding.Left==6,
    'a mod row box sits 2 right of its margin, its text 6 in, 10 above the next line')
assert(modRow.mcFrame.BrushColor.R==0.62 and modRow.mcFrame.BrushColor.A==0.14,'a module has a faint warm backdrop')
-- Ungrouped, each mod line has the same backdrop with a gap under it; the folded entry none.
do
    local flat=pages.build(widget(),{
        {name='A',choices=items,mcBrowserLine='row',mcBrowserLevel=4,mcBrowserIndent=20},
        {name='B',choices=items,mcBrowserLine='row',mcBrowserLevel=4,mcBrowserIndent=20},
        {name='and 1 more with no settings',choices=items,mcBrowserLine='row',mcBrowserMore='g',
            mcBrowserLevel=4,mcBrowserIndent=20},
    },nil,api).allRows
    assert(flat[1].mcFrame and flat[1].mcFrame.BrushColor.A==0.14 and flat[1].mcFrame:GetContent()==flat[1].wrapper
        and flat[1].mcLooseFrame==flat[1].mcFrame and flat[1].mcFrame.Slot.Padding.Left==20
        and flat[1].mcFrame.Slot.Padding.Bottom==4 and flat[2].mcFrame and flat[3].mcFrame==nil
        and flat[3].wrapper:GetParent()==flat[1].mcFrame:GetParent(),
        'an ungrouped mod line sits on the backdrop, the folded entry stays bare in the list')
end
-- An ungrouped list is a grid under a heading that is never shown, with no line bar.
do
    local barePage=pages.build(widget(),{
        {name='',choices=items,mcBrowserLine='head',mcBrowserBare=true,mcBrowserHidden=true,mcBrowserColumns=2},
        {name='A',choices=items,mcBrowserLine='cell'},{name='B',choices=items,mcBrowserLine='cell'},
        {name='C',choices=items,mcBrowserLine='cell'},
    },nil,api)
    local bareRows=barePage.allRows
    local line=bareRows[2].mcFrame:GetParent()
    local box=line:GetParent()
    assert(line==bareRows[3].mcFrame:GetParent() and bareRows[4].mcFrame:GetParent()~=line
        and #box.children==3 and box.visible==0,'two per row, with no header in the group')
    assert(line.children[1]:GetContent()==nil and line.children[1].WidthOverride==20,'the bar\'s margin, without its line')
    -- Load order puts each name in a box after its number; a later layout (a filter or
    -- sort change) still styles the name, not the box, and leaves no page unparented.
    local name=bareRows[2].widget:GetContent()
    local numbered=widget();numbered.SetJustification=false;numbered.SetAutoWrapText=false
    bareRows[2].widget:SetContent(numbered);numbered:AddChild(name);bareRows[2].mcNumbered=true
    barePage:mcLayoutGroups()
    assert(bareRows[2].mcFrame:GetParent() and bareRows[2].mcNameLabel==name and name.Slot.Padding.Left==0
        and bareRows[3].widget:GetContent().Slot.Padding.Left==8,'a numbered name keeps its place on relayout')
end
-- In a grid the folded entry takes the next place beside the mods.
local gridMore=pages.build(widget(),{
    {name='Group',choices=items,mcBrowserLine='head'},
    {name='Mod',choices=items,mcBrowserLine='cell'},
    {name='and 1 more with no settings',choices=items,mcBrowserLine='cell',mcBrowserMore='g'},
},nil,api).allRows
local modCell,moreCell=gridMore[2],gridMore[3]
assert(modCell.mcFrame.parent and modCell.mcFrame.parent==moreCell.mcFrame.parent,'the folded entry fills a column like a mod')
assert(modCell.widget:GetContent().Slot.Padding.Top==2 and modCell.widget:GetContent().Slot.Padding.Bottom==4
    and moreCell.widget:GetContent().Slot.Padding.Bottom==4,'cells pad 2 px above the name, 4 below; beside a mod the entry lines up')
-- Starting a row of its own, the entry sits 2 px higher.
local alone=pages.build(widget(),{
    {name='Group',choices=items,mcBrowserLine='head',mcBrowserColumns=2},
    {name='A',choices=items,mcBrowserLine='cell'},{name='B',choices=items,mcBrowserLine='cell'},
    {name='and 1 more with no settings',choices=items,mcBrowserLine='cell',mcBrowserMore='g'},
},nil,api).allRows
assert(alone[4].widget:GetContent().Slot.Padding.Bottom==8 and alone[4].mcFrame.parent~=alone[2].mcFrame.parent,
    'in the first column the entry is raised')
-- A 'row' page takes a whole line of its own after the grid; each group has its own header.
local mixedProviders={{name='Bob',choices=items,mcBrowserLine='head'},
    {name='Declared',choices=items,mcBrowserLine='cell'},
    {name='A Very Long Mod Name Indeed',choices=items,mcBrowserLine='row'},
    {name='Various Authors',choices=items,mcBrowserLine='head'},
    {name='Solo',choices=items,mcBrowserLine='row'}}
local mixedRows=pages.build(widget(),mixedProviders,nil,api).allRows
local bob=groupBox(mixedRows[1])
local various=groupBox(mixedRows[4])
assert(#bob.children==4 and #various.children==3 and bob.parent==various.parent,
    'each group is its own box: a park, a header, then its lines')
assert(various.Slot.Padding.Top==bob.Slot.Padding.Top+14,'every group after the first starts 14 further down')
local rowLine=bob.children[4]
assert(#rowLine.children==2 and rowLine.children[1].HeightOverride==34
    and rowLine.children[2]:GetContent()==mixedRows[3].wrapper and mixedRows[3].wrapper.WidthOverride==584-38-9
    and mixedRows[3].wrapper.HeightOverride==34 and not mixedRows[3].widget:GetContent().AutoWrapText,
    'a row page is one line across the group')
assert(various.children[3].children[2]:GetContent()==mixedRows[5].wrapper,'the next group lists its own pages')
local ui=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},api)
ui.mcHeaderHost=widget()
ui:show(1)
local row=ui.panels[1].rows[1]
assert(#row.mcTabs==2 and row.mcLabel.Font.Size==20)
-- Each choice is outlined; the selected choice's outline is drawn at full strength.
local selectedTabs=0
for _,tab in ipairs(row.mcTabs) do
    assert(#tab.outline==4,'every tab choice has a four-sided outline')
    for _,bar in ipairs(tab.outline) do
        assert((bar.BrushColor.A>0.5)==(tab.selected==true),'only the selected choice has a bright outline')
    end
    if tab.selected then selectedTabs=selectedTabs+1 end
end
assert(selectedTabs==1,'exactly one tab choice is selected')
assert(row.mcTabs[1].box.MinDesiredWidth+row.mcTabs[2].box.MinDesiredWidth+4==440,
    'outlined choices share the reserved width with a 4-pixel gap')
assert(row.mcTabs[1].widget.WidgetStyle.NormalPadding.Left==4 and row.mcTabs[1].widget.WidgetStyle.PressedPadding.Right==4,
    'an outlined tab keeps its label 3 pixels inside the 1-pixel outline')
items[1].mcNavigation,items[1].mcLinkPage=true,'ModCoreControls'
local linked=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},api)
linked.mcHeaderHost=widget()
linked:show(1)
assert(#linked.panels[1].rows[1].mcTabs==1
    and linked.panels[1].rows[1].mcTabs[1].label.text=='Consumables'
    and linked.panels[1].rows[1].mcTabs[1].box.MinDesiredWidth==160,
    'page links must display one clickable tab')
-- A link row's label wraps in its column and the row grows from a 40-pixel minimum.
local linkRow=linked.panels[1].rows[1]
assert(linkRow.mcLabel.AutoWrapText==true,'link labels wrap')
for _,box in ipairs({linkRow.widget:GetParent(),linkRow.wrapper}) do
    assert(box.heightCleared and box.HeightOverride==nil and box.MinDesiredHeight==40,
        'link rows grow to fit their label, from a 40-pixel minimum')
end
assert(linkRow.widget:GetParent().WidthOverride==584-160-24,'the label column keeps its width')
assert(not row.mcLabel.AutoWrapText and not row.wrapper.heightCleared,
    'ordinary tab rows keep a fixed single-line label')
local linkSet=linked.model.set
function linked.model:set(index,value)
    if index==1 and value==0 then self.linkActivated=true end
    return linkSet(self,index,value)
end
linked.panels[1].rows[1].mcTabs[1].widget.clicked=true
linked:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(linked.model.linkActivated,'the single link tab must activate even at its default value')
items[1].mcNavigation,items[1].mcLinkPage=nil,nil
-- A read-only status whose choices share one label lines up with link rows: one 160-pixel
-- button that cannot be pressed.
local labels=items[1].labels
items[1].mcReadOnly,items[1].labels=true,{}
for n in ipairs(labels) do items[1].labels[n]='No settings' end
local status=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},api)
status.mcHeaderHost=widget()
status:show(1)
local statusRow=status.panels[1].rows[1]
assert(#statusRow.mcTabs==1 and statusRow.mcTabs[1].label.text=='No settings'
    and statusRow.mcTabs[1].box.MinDesiredWidth==160 and statusRow.widget:GetParent().WidthOverride==584-160-24
    and statusRow.mcTabs[1].enabled==false,
    'a read-only one-label status shows one disabled button placed like a link')
items[1].mcReadOnly,items[1].mcNavigation=nil,true
for n in ipairs(labels) do items[1].labels[n]='Play' end
local action=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},api)
action.mcHeaderHost=widget()
action:show(1)
local actionRow=action.panels[1].rows[1]
assert(#actionRow.mcTabs==1 and actionRow.mcTabs[1].label.text=='Play' and actionRow.mcTabs[1].box.MinDesiredWidth==160
    and actionRow.mcTabs[1].enabled==true,'a one-label navigation action shows one button that can be pressed')
local actionSets=0
local actionSet=action.model.set
function action.model:set(index,value) actionSets=actionSets+1;return actionSet(self,index,value) end
actionRow.mcTabs[1].widget.clicked=true
action:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(actionSets==1,'pressing it sets the row, even to its current value')
-- mcSilent keeps DMM's interface sounds off a row; other rows keep them.
local sounds={}
local soundApi={}
for key,value in pairs(api) do soundApi[key]=value end
soundApi.feedback=function(action) sounds[#sounds+1]=action end
local click=function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end
for _,silent in ipairs({false,true}) do
    items[1].mcSilent=silent or nil
    sounds={}
    local page=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},soundApi)
    page.mcHeaderHost=widget()
    page:show(1)
    page.panels[1].rows[1].mcTabs[1].widget.clicked=true
    page:tick({},click,false)
    -- DMM's own sounds follow the row it has just hovered or selected.
    page.hovered=1;page.mcTestFeedback('Hover')
    page.current=1;page.mcTestFeedback('Select')
    page.current=nil;page.mcTestFeedback('Select')
    assert(#sounds==(silent and 1 or 4),(silent and 'a silent row plays no interface sound' or 'a row plays its sounds'))
end
items[1].mcSilent=nil
-- mcChoiceSounds: on a Change to a choice with its own sound, that sound plays instead of
-- DMM's; none plays nothing; other choices and other sounds stay DMM's.
do
    local played={}
    local playerFor=M.choiceSoundPlayer
    local stops=0
    M.choiceSoundPlayer=function() return {play=function(_,path) played[#played+1]=path end,
        stop=function() stops=stops+1 end} end
    items[1].mcChoiceSounds={[0]='/Game/Zero.Zero',[1]=false}
    sounds={}
    local page=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},soundApi)
    page.mcHeaderHost=widget()
    page:show(1)
    page.current=1
    page.model.pending[1]=0;page.mcTestFeedback('Change')
    page.model.pending[1]=1;page.mcTestFeedback('Change')
    page.mcTestFeedback('Select')
    assert(#played==1 and played[1]=='/Game/Zero.Zero' and #sounds==1 and sounds[1]=='Select',
        'a choice\'s own sound replaces DMM\'s Change sound')
    assert(stops==1,'changing to a silent choice stops the previous choice\'s sound')
    items[1].mcChoiceSounds={[1]='/Game/One.One'}
    page.model.pending[1]=0;page.mcTestFeedback('Change')
    assert(#played==1 and sounds[2]=='Change' and stops==2,
        'a choice without its own sound keeps DMM\'s, and stops the previous choice\'s')
    -- The sound a choice started stops on another page, on hiding and on the menu closing.
    page:show(1)
    assert(stops==3,'showing a page stops the previous choice\'s sound')
    page:hide()
    assert(stops==4,'hiding the settings stops the previous choice\'s sound')
    lifecycle.hostClosing({})
    assert(stops==5,'closing the menu stops the previous choice\'s sound')
    items[1].mcChoiceSounds=nil
    M.choiceSoundPlayer=playerFor
end
items[1].mcNavigation,items[1].labels=nil,labels
-- mcDimValues fades the whole row while its own value is one of them.
items[1].mcDimValues={[1]=true}
local dimmed=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},api)
dimmed.mcHeaderHost=widget()
dimmed:show(1)
local dimRow=dimmed.panels[1].rows[1]
assert(dimRow.wrapper.opacity==1,'a row whose value is not listed shows in full')
dimmed.model.pending[1]=1;dimmed:refresh()
assert(dimRow.wrapper.opacity==0.45,'a listed value fades the row')
dimmed.model.pending[1]=0;dimmed:refresh()
assert(dimRow.wrapper.opacity==1,'changing back restores it')
items[1].mcDimValues=nil
assert(row.mcTabs[1].label.Slot.HorizontalAlignment==0 and row.mcTabs[1].label.Slot.VerticalAlignment==2,
    'Tab labels must fill their allocated button slots for centered text justification')
for _,tab in ipairs(row.mcTabs) do
    assert(tab.widget:GetParent():GetParent()==tab.box
        and tab.box:GetParent():GetParent()==row.wrapper:GetContent(),
        'Tab picker options sit in their outline inside the row')
end
local tabSlot=row.mcTabs[1].box:GetParent().Slot
assert(tabSlot.HorizontalAlignment==3 and tabSlot.Padding.Right==24,
    'Tab pickers must align right with a 24-pixel inset')
local linkTab=linked.panels[1].rows[1].mcTabs[1]
assert(#linkTab.outline==4 and linkTab.box:GetParent().Slot.Padding.Right==24,
    'Provider-link pickers must use the same outlined inset')
assert(row.mcTabs[1].selected and not row.mcTabs[2].selected)
assert(ui.panels[1].rows[2].mcLabel.text=='Slot 5')
local scroll=ui.panels[1].scroll
local function position(target)
    for n,child in ipairs(scroll.children) do if child==target then return n end end
end
local function textCount(text)
    local count=0;for _,child in ipairs(scroll.children) do if child.text==text then count=count+1 end end;return count
end
assert(textCount('Interaction: Independent')==1 and textCount('Interaction: Selective')==1,'Each parent heading renders once')
assert(textCount('Key Bindings')>=1 and textCount('Keys')==0,'mcLabel names the heading in place of its category')
local independent
for _,child in ipairs(scroll.children) do if child.text=='Interaction: Independent' then independent=child end end
assert(position(independent)<position(ui.panels[1].headings[3].widget),'Parent must precede its subgroup headings')
assert(position(ui.panels[1].headings[3].widget)<position(ui.panels[1].headings[2].widget),'Primary category must precede secondary')
assert(ui.panels[1].headings[2].widget.visible==1,'mcHeading=0 must collapse only the category heading')
-- A category heading is drawn like the game's own: 18pt, 2 pixels left, 24 above, with
-- a 1-pixel rule right after it that shows and hides with it.
local shownHeading=ui.panels[1].headings[3].widget
local shownRule=scroll.children[position(shownHeading)+1]
assert(shownHeading.Font.Size==18 and shownHeading.Slot.Padding.Left==-2 and shownHeading.Slot.Padding.Top==24
    and shownRule.HeightOverride==1 and shownRule.Slot.Padding.Left==-2 and shownRule.visible==4,
    'A category heading is larger, nudged left, spaced above and ruled beneath')
local hiddenHeading=ui.panels[1].headings[2].widget
assert(scroll.children[position(hiddenHeading)+1].visible==1,'A collapsed heading hides its rule')
assert(ui.panels[1].rows[2].visible and independent.visible==4,'Hidden subgroup heading must retain rows and visible parent')
local count=scroll:GetChildrenCount()
row.mcTabs[2].widget.clicked=true
ui:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(ui.model.pending[1]==1 and row.mcTabs[2].selected)
assert(ui.panels[1].rows[2].mcLabel.text=='Slot 1')
assert(position(independent)<position(ui.panels[1].headings[2].widget))
assert(position(ui.panels[1].headings[2].widget)<position(ui.panels[1].headings[3].widget))
assert(ui.panels[1].readyEvents==1,'Reordering must notify existing decorators that row paths changed')
ui:refresh();ui:prepare(1);assert(scroll:GetChildrenCount()==count,'No duplicate widgets on reuse')
assert(textCount('Interaction: Independent')==1 and textCount('Interaction: Selective')==1,'Reuse must not duplicate parent headings')
assert(ui.panels[1].readyEvents==1,'Unchanged refresh must not repeat page events')
local header=ui.panels[1].rows[4]
assert(header.mcHeader and header.wrapper:GetParent()==ui.mcHeaderHost)
assert(header.mcPlaceholder.visible==1 and header.mcLabel.Font.Size==22)
assert(header.mcLabel.Slot.Padding.Left==0 and ui.panels[1].rows[1].mcLabel.Slot.Padding.Left==0,
    'Level-one and level-two setting labels must have no stock left indent')
ui.model.pending[4]=0
ui.mcTestSetText(header.value,'Off *')
assert(header.value.text=='Off','Dirty suffix must never flicker in the value text')
local signal
for _,child in ipairs(header.wrapper:GetContent().children) do
    if child.text and child.text:match('^MC_VALUE_DIRTY_1\n') then signal=child end
end
assert(signal and signal.text=='MC_VALUE_DIRTY_1\n1\nOff')
ui.model.committed[4]=0
ui.mcTestSetText(header.value,'Off')
assert(signal.text=='MC_VALUE_DIRTY_1\n0\nOff',
    'Apply must signal clean state even when the displayed value text is unchanged')
ui.model:set(1,0);ui:refresh()
assert(ui.panels[1].readyEvents==2,'Visibility and ordering changes must coalesce into one page-ready event')
ui.model.visibilityOverride=true
function ui.model:visibility() return {true,true,true,true,self.visibilityOverride,true} end
ui:refresh()
assert(ui.panels[1].readyEvents==3,'Visibility-only changes must notify decorators after DMM refresh')
ui:refresh();assert(ui.panels[1].readyEvents==3,'Stable visibility must not repeat page-ready events')
ui.active=nil;local calls=0
ui:tick({},function() calls=calls+1 end,false);assert(calls==0,'Closed menus never inspect tabs')
items[1].group='Player';items[1].label='Quickslots'
local pickerHeaderSchema=schema:gsub('Id=Primary\nmcType=tab\nmcLevel=2',
    'Id=Primary\nmcType=tab\nmcHeading=true'):gsub('Id=Enabled\nmcHeading=true',
    'Id=Enabled\nmcLevel=2')
M.parse(pickerHeaderSchema,items)
-- DMM's focus highlight, recorded per widget.
local highlighted={}
api.highlight=function(target,alpha) highlighted[target]=alpha end
local pickerHeader=controls.build(widget(),{{id='ModCoreControls',choices=items}},api)
api.highlight=nil
pickerHeader.mcHeaderHost=page.controls.mcHeaderHost
pickerHeader.mcHeaderTitle=page.modTitle
pickerHeader.mcHeaderTabs=page.controls.mcHeaderTabs
pickerHeader.mcHeaderStatus=page.controls.mcHeaderStatus
pickerHeader:show(1)
local headerRow=pickerHeader.panels[1].rows[1]
local headerTabs=headerRow.mcHeaderTabsBox
assert(headerTabs and headerTabs:GetParent()==page.controls.mcHeaderTabs
    and headerTabs.Slot.HorizontalAlignment==3 and headerTabs.Slot.VerticalAlignment==1,
    'Header picker choices must hang right-aligned from the divider')
assert(#headerRow.mcTabs==#items[1].values and #headerTabs.children==2*#items[1].values+1
    and headerRow.value.visible==1 and headerTabs.visible==0,
    'Every header choice must be a tab between separators, replacing the value text')
local tabsWidth=headerRow.mcHeaderTabsWidth
assert(tabsWidth==2*110+3 and statusBox.WidthOverride==572-tabsWidth-12 and statusBox.Slot.Padding.Top==4,
    'The page status must stay beneath the divider, left of the header tabs')
headerRow.mcHeaderTabsWidth=8*70+9;pickerHeader:refresh()
assert(statusBox.WidthOverride==572 and statusBox.Slot.Padding.Top==4+29,
    'A page status without room beside the tabs must drop below them at full width')
headerRow.mcHeaderTabsWidth=tabsWidth;pickerHeader:refresh()
assert(statusBox.WidthOverride==572-tabsWidth-12 and statusBox.Slot.Padding.Top==4,
    'The page status must return beside the tabs when they fit again')
headerRow.mcTabs[2].widget.clicked=true
pickerHeader:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(pickerHeader.model.pending[1]==items[1].values[2] and headerRow.mcTabs[2].selected,
    'Clicking a header tab must select its choice')
assert(headerRow.mcTabs[1].label.Font.Size==12 and headerTabs.children[2].HeightOverride==29,
    'Header tabs must use a compact 12-point font and 28-pixel height')
assert(page.controls.mcHeaderTabs:GetParent().Slot.Padding.Bottom==12,
    'the page header ends 12 pixels above its first entry')
-- Tabs keep their share but a longer label widens its own tab, keeping 3 pixels each side.
for n,tab in ipairs(headerRow.mcTabs) do
    assert(tab.widget.WidgetStyle.NormalPadding.Left==3 and tab.widget.WidgetStyle.NormalPadding.Right==3
        and headerTabs.children[2*n].MinDesiredWidth==110,'header tabs pad their labels by 3 pixels')
    assert(tab.widget.WidgetStyle.NormalPadding.Top==0 and tab.widget.WidgetStyle.NormalPadding.Bottom==2
        and tab.widget.WidgetStyle.PressedPadding.Bottom==2 and headerTabs.children[2*n].HeightOverride==29,
        'a header tab label sits 1 pixel above centre in a tab of unchanged height')
end
local longLabels=items[1].labels
items[1].labels={longLabels[1],'Developer Tools And More'}
local longHeader=controls.build(widget(),{{id='ModCoreControls',choices=items}},api)
longHeader.mcHeaderHost,longHeader.mcHeaderTabs=widget(),widget()
longHeader:show(1)
local longRow=longHeader.panels[1].rows[1]
local grown=longRow.mcHeaderTabsBox.children[4].MinDesiredWidth
assert(longRow.mcHeaderTabsBox.children[2].MinDesiredWidth==110 and grown>=math.ceil(24*12*0.6)+6
    and longRow.mcHeaderTabsWidth==110+grown+3,'a long header label widens only its own tab')
items[1].labels=longLabels
assert(#headerRow.mcHeaderSeparators==#items[1].values+1,'a thin line before, between and after the tabs')
for _,bar in ipairs(headerRow.mcHeaderSeparators) do
    assert(bar.BrushColor.A<0.5,'every header separator stays thin and dim, the selected tab\'s too')
end
for n,tab in ipairs(headerRow.mcTabs) do
    assert((tab.glow.BrushColor.A>0)==(n==2) and tab.widget:GetParent()==tab.glow,
        'Only the selected header tab may glow')
    assert(#tab.under==2,'a soft band and a brighter edge under each tab')
    assert(tab.under[1].HeightOverride==4 and tab.under[1].Slot.Padding.Bottom==0
        and tab.under[2].HeightOverride==1 and tab.under[2].Slot.Padding.Bottom==-1,
        'the soft band is 4 tall, ending at the tab\'s bottom; the 1-pixel edge sits 1 below')
    for _,band in ipairs(tab.under) do
        assert(band.visible==(n==2 and 3 or 1),'the glow under a tab shows only while it is selected, never hit-tested')
    end
    assert(tab.label.opacity==(n==2 and 1 or 0.8),'labels of the other tabs are dimmed 20%')
end
-- The page-tab row never gets DMM's full focus background: the selected tab gets it.
pickerHeader.mcTestHighlight(headerRow.background,0.8,false)
assert(highlighted[headerRow.background]==0,'the title row is not highlighted as a whole')
assert(highlighted[headerRow.mcTabs[2].focus]==0.8 and (highlighted[headerRow.mcTabs[1].focus] or 0)==0,
    'the focus highlight shows on the selected tab')
assert(headerRow.mcTabs[2].focus.visible==3,'the focus image never takes the pointer')
pickerHeader.model.pending[1]=headerRow.mcTabs[1].value;pickerHeader:refresh()
assert(highlighted[headerRow.mcTabs[1].focus]==0.8 and highlighted[headerRow.mcTabs[2].focus]==0,
    'the focus highlight follows the selection')
pickerHeader.mcTestHighlight(headerRow.background,0,false)
assert(highlighted[headerRow.mcTabs[1].focus]==0,'losing focus clears it')
pickerHeader.model.pending[1]=headerRow.mcTabs[2].value;pickerHeader:refresh()
local otherRow=pickerHeader.panels[1].rows[2]
pickerHeader.mcTestHighlight(otherRow.background,0.5,false)
assert(highlighted[otherRow.background]==0.5,'other rows keep DMM\'s highlight')
-- Hovering a tab that is not selected highlights its background; leaving clears it.
local other=headerRow.mcTabs[1]
other.widget.hovered=true
pickerHeader:tick({},function() return false,false,false end,false)
assert(other.glow.BrushColor.A>0 and other.glow.BrushColor.A<headerRow.mcTabs[2].glow.BrushColor.A
    and other.under[1].visible==1 and other.label.opacity==0.8,'a hovered tab gets a fainter background, no glow under')
other.widget.hovered=false
pickerHeader:tick({},function() return false,false,false end,false)
assert(other.glow.BrushColor.A==0,'leaving the tab clears its background')
assert(pickerHeader.panels[1].rows[1].mcHeader
    and pickerHeader.panels[1].rows[1].mcLabel.Slot.Padding.Left==0
    and pickerHeader.panels[1].rows[1].mcLabel.visible==1
    and page.controls.mcHeaderHost.children[1]==pickerHeader.panels[1].rows[1].wrapper
    and page.controls.mcHeaderHost.children[2]==page.modTitle
    and pickerHeader.panels[1].rows[4].mcLabel.Slot.Padding.Left==0,
    'Level-one picker must share the title row above the divider without a second label')
items[1].values,items[1].labels,items[1].default={0},{'Slot 1'},0
M.parse('[Setting.Primary]\nId=Primary\nmcReadOnly=1\nmcReferenceLabel=Slot 1\nmcType=tab\n',items)
local readOnly=controls.build(widget(),{{choices=items}},api)
readOnly:show(1)
local referenceTabs=readOnly.panels[1].rows[1].mcTabs
assert(not readOnly.panels[1].rows[1].mcStar,'A read-only row is never dirty and gets no star')
assert(#referenceTabs==1 and referenceTabs[1].enabled==false and referenceTabs[1].label.text=='Slot 1',
    'Reference mode is a disabled Slot label')
referenceTabs[1].widget.clicked=true
local before=readOnly.model.pending[1]
readOnly:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(readOnly.model.pending[1]==before, 'Reference clicks cannot change the pending value')

items[1].values,items[1].labels={0,1},{'Errors','Errors'}
M.parse('[Setting.Primary]\nId=Primary\nmcReadOnly=1\n',items)
-- A read-only row cannot be selected: it is left out of navigation, a selection of it is
-- refused or moved, and the pointer passes through its buttons.
assert(items[1].mcReadOnly==true)
local fixed=controls.build(widget(),{{choices=items}},api)
function fixed:wireNavigation() end
fixed.visibleRows={};fixed:show(1);fixed:refresh()
assert(fixed.visibleRows[1]~=1 and #fixed.visibleRows>0,'navigation skips the read-only row')
assert(fixed.panels[1].rows[1].widget.visible==3,'its label button takes no pointer')
for _,part in ipairs(fixed.panels[1].rows[1].parts) do assert(part.widget.visible==3,'nor do its value buttons') end
fixed.current=nil;fixed:select(1);assert(fixed.current==nil,'selecting it is refused')
fixed.current=1;fixed:refresh();assert(fixed.current==fixed.visibleRows[1],'a selection on it moves to a selectable row')
print('PASS a read-only row cannot be selected')

-- mcTable shows static code and text pairs in columns filled top to bottom, every line
-- the same height and every code the same width.
local function tableManifest(fields) return '[Setting.Primary]\nId=Primary\n'..fields..'\n' end
assert(not pcall(M.parse,tableManifest('mcTable=A:a'),items),'mcTable requires a read-only row')
assert(not pcall(M.parse,tableManifest('mcReadOnly=1\nmcColumns=2'),items),'mcColumns requires mcTable')
for _,other in ipairs({'mcWrap=1','mcType=tab'}) do
    assert(not pcall(M.parse,tableManifest('mcReadOnly=1\nmcTable=A:a\n'..other),items),other)
end
local glyphs={}
for n=1,47 do glyphs[n]=string.format('%04X:%s',0x2190+n,utf8.char(0x2190+n)) end
M.parse(tableManifest('mcReadOnly=1\nmcColumns=6\nmcTable='..table.concat(glyphs,'|')),items)
local tablePage=controls.build(widget(),{{choices=items}},api)
tablePage:show(1)
local tableRow=tablePage.panels[1].rows[1]
local grid=assert(tableRow.mcTable,'an mcTable row gets a table').content
assert(#grid.children==6 and #grid.children[1].children==8 and #grid.children[6].children==7,
    '47 entries in 6 columns fill 8 lines top to bottom')
-- An 18pt Afacad line is 32 pixels; 4 pixels pad it above and below.
local line=40
assert(tableRow.mcTable.height==8*line and tableRow.wrapper.HeightOverride==8*line+16
    and tableRow.mcTable.scroll:GetParent().HeightOverride==8*line,'the whole table shows without scrolling')
assert(tableRow.mcLabel.visible==1 and not tableRow.mcTabs,'the table replaces the row label and value')
local function centred(slot) return slot.HorizontalAlignment==2 and slot.VerticalAlignment==2 end
for c,column in ipairs(grid.children) do
    for row,box in ipairs(column.children) do
        assert(box.HeightOverride==line and box.WidthOverride==math.floor(536/6) and centred(box.children[1].Slot),
            'every line is the same height, its pair centred in the column')
        local pair=box.children[1]
        local codeBox,textBox=pair.children[1],pair.children[2]
        -- 4 hex characters at 12pt are at most 4 x 2/3 x 16 pixels; one 18pt text 24.
        assert(codeBox.WidthOverride==43+8 and textBox.WidthOverride==24+8,'cells fit their content plus the same padding')
        assert(codeBox.HeightOverride==line and textBox.HeightOverride==line,'code and text cells are a full line tall')
        local code,text=codeBox.children[1],textBox.children[1]
        assert(centred(code.Slot) and centred(text.Slot),'code and text sit in the middle of their cells')
        local n=(c-1)*8+row
        assert(code.text==string.format('%04X',0x2190+n) and code.Font.Size==12 and code.color=='muted',
            'codes are 12pt muted')
        assert(text.text==utf8.char(0x2190+n) and text.Font.Size==18,'texts are 18pt')
    end
end
-- A table taller than the text area scrolls.
local tall={}
for n=1,30 do tall[n]='C'..n..':x' end
M.parse(tableManifest('mcReadOnly=1\nmcTable='..table.concat(tall,'|')),items)
local tallPage=controls.build(widget(),{{choices=items}},api)
tallPage:show(1)
assert(tallPage.panels[1].rows[1].mcTable.height==360 and #tallPage.panels[1].rows[1].mcTable.content.children==1,
    'one column by default, scrolling past 360 pixels')
-- Malformed tables show why instead of the table; the page still builds.
for _,case in ipairs({{'A:a|B','table entry 2 needs <code>:<text>'},{'A:a|','table entry 2 needs'},
        {'ABCDEFGHI:a','table entry 1 exceeds 8 characters'},{'A:a\nmcColumns=7','mcColumns must be'},
        {'A:a\nmcColumns=2.0','mcColumns must be'}}) do
    M.parse(tableManifest('mcReadOnly=1\nmcTable='..case[1]),items)
    local broken=controls.build(widget(),{{choices=items}},api)
    broken:show(1)
    local shown=broken.panels[1].rows[1].mcTable.content.text
    assert(shown:find('^Unavailable: ') and shown:find(case[2],1,true),shown)
end
M.parse(tableManifest('mcReadOnly=1'),items)
assert(items[1].mcTable==nil,'a reparse without mcTable clears it')
print('PASS mcTable shows static pairs in level, aligned columns')

for i=#items,1,-1 do items[i]=nil end
for i,group in ipairs({'Before','AlsoBefore','After'}) do
    items[i]={id='Entry'..i,kind=i==1 and 'picker' or 'toggle',group=group,label='Entry '..i,
        values={0,1},labels={'Off','On'}}
end
M.parse('[Category.Before]\nmcHeading=0\n[Category.AlsoBefore]\nmcHeading=0\n',items)
local initial=controls.build(widget(),{{choices=items}},api)
initial:show(1)
for i=1,2 do
    local row=initial.panels[1].rows[i]
    assert(row.mcLabel.Font.Size==18 and row.mcLabel.color=='muted'
        and (i==1 and row.mcLabel or row.widget:GetContent()).Slot.Padding.Left==-2
        and row.widget.WidgetStyle.NormalPadding.Left==0
        and row.widget.WidgetStyle.PressedPadding.Left==0
        and row.wrapper.Slot.Padding.Top==24 and row.wrapper.Slot.Padding.Bottom==4,
        'Rows before the first visible category must match its label style and spacing')
end
local after=initial.panels[1].rows[3]
assert(after.mcLabel.Font.Size==14 and after.mcLabel.color=='body'
    and after.widget:GetContent().Slot.Padding.Left==26
    and after.widget.WidgetStyle.NormalPadding.Left==0
    and after.wrapper.Slot.Padding.Top==0 and after.wrapper.Slot.Padding.Bottom==0,
    'Rows after the first category must keep the stock child style')
items[2].mcGroup.heading=true
initial:refresh()
local second=initial.panels[1].rows[2]
assert(second.mcLabel.Font.Size==14 and second.mcLabel.color=='body'
    and second.widget:GetContent().Slot.Padding.Left==26
    and second.widget.WidgetStyle.NormalPadding.Left==0
    and second.wrapper.Slot.Padding.Top==0 and second.wrapper.Slot.Padding.Bottom==0,
    'Showing an earlier category must restore the normal child style')
-- A field-type editor row is built on DMM's toggle row and indents like one,
-- not once on its content and again on its label.
items[4]={id='Entry4',kind='extension',group='After',label='Entry 4',values={0,1},labels={'Off','On'}}
local editorRows=controls.build(widget(),{{choices=items}},api)
editorRows:show(1)
local editorRow=editorRows.panels[1].rows[4]
assert(editorRow.widget:GetContent().Slot.Padding.Left==26 and editorRow.mcLabel.Slot.Padding.Left==0,
    'Editor rows indent once, like toggle rows')
items[4]=nil

-- Row label buttons follow DMM's build order: a picker's arrow and value buttons are
-- never taken for the next row's label, even when that label matches an arrow.
do
    local saved={}
    for i,item in ipairs(items) do saved[i]=item end
    for i=#items,1,-1 do items[i]=nil end
    items[1]={id='Order1',kind='picker',group='Order',label='Mode',values={0,1},labels={'A','B'}}
    items[2]={id='Order2',kind='toggle',group='Order',label='>',values={0,1},labels={'Off','On'}}
    M.parse('',items)
    local ordered=controls.build(widget(),{{choices=items}},api)
    ordered:show(1)
    local picker,toggle=ordered.panels[1].rows[1],ordered.panels[1].rows[2]
    assert(picker.widget.WidgetStyle.NormalPadding.Left==0 and toggle.widget.WidgetStyle.NormalPadding.Left==0
        and picker.parts[3].widget.WidgetStyle.NormalPadding.Left==16,
        'the label after a picker is its own row, not the picker\'s right arrow')
    -- A navigation picker separating colliding keybinds shows its choice and arrows in red,
    -- and returns to DMM's colors when the collision clears.
    ordered.model.mcConflictPickers={[1]=true};ordered:refresh()
    local arrowLeft,arrowRight=picker.parts[1].widget:GetContent(),picker.parts[3].widget:GetContent()
    assert(picker.value.colorAndOpacity.SpecifiedColor.R>0.8 and arrowLeft.colorAndOpacity.SpecifiedColor.R>0.8
        and arrowRight.colorAndOpacity.SpecifiedColor.R>0.8 and not toggle.value.colorAndOpacity,
        'the separating picker turns red, text and arrows')
    ordered.model.mcConflictPickers={};ordered:refresh()
    assert(picker.value.color=='body' and arrowLeft.color=='body' and arrowRight.color=='body',
        'clearing restores the body color')
    -- A failed DMM build leaves no construction state behind; the next build styles normally.
    local failing=controls.build(widget(),{{choices=items}},api)
    failing.mcTestFail='dmm build failed'
    local ok,err=pcall(failing.show,failing,1)
    assert(not ok and err=='dmm build failed','DMM build errors propagate unchanged')
    failing:show(1)
    assert(failing.panels[1].rows[2].widget.WidgetStyle.NormalPadding.Left==0 and failing.panels[1].rows[1].mcStar,
        'after a failed build the page builds and decorates normally')
    for i=#items,1,-1 do items[i]=nil end
    for i,item in ipairs(saved) do items[i]=item end
end

-- An mcCategory row stands in for its hidden group heading: it takes the heading's look
-- and the rest of its group indents beneath it while it shows.
do
    -- The controls fixture always renders the shared items list.
    local saved={}
    for i,item in ipairs(items) do saved[i]=item end
    local list=items
    for i=1,3 do
        list[i]={id='Visual'..i,kind=i==1 and 'picker' or 'toggle',group='Visuals',label='Visual '..i,
            values={0,1},labels={'Off','On'}}
    end
    M.parse('[Category.Visuals]\nmcHeading=0\n[Setting.Visual1]\nId=Visual1\nmcCategory=1\n',list)
    assert(list[1].mcCategory and not list[2].mcCategory)
    local built=controls.build(widget(),{{choices=list}},api)
    built:show(1)
    local heading=built.panels[1].rows[1]
    assert(heading.mcLabel.Font.Size==18 and heading.mcLabel.color=='muted'
        and heading.mcLabel.Slot.Padding.Left==-2
        and heading.wrapper.Slot.Padding.Top==24,'the category row looks like a category heading')
    assert(heading.wrapper.Slot.Padding.Bottom==0,'its rule hugs it')
    -- Its rule follows it as a heading's does, and shows and hides with it.
    local children=built.panels[1].scroll.children
    local at
    for n,child in ipairs(children) do if child==heading.wrapper then at=n end end
    local rule=at and children[at+1]
    assert(rule and rule.HeightOverride==1 and rule.Slot.Padding.Left==-2 and rule.Slot.Padding.Bottom==4
        and rule.visible==4,'the category row is ruled beneath like a heading')
    local rules=0
    for _,child in ipairs(children) do if child.HeightOverride==1 and child.visible~=1 then rules=rules+1 end end
    assert(rules==1,'one rule shows: the hidden heading\'s stays hidden')
    for i=2,3 do
        local row=built.panels[1].rows[i]
        assert(row.mcLabel.Font.Size==14 and row.mcLabel.color=='body'
            and row.widget:GetContent().Slot.Padding.Left==26,'rows indent beneath the category row')
    end
    -- The dirty star follows the label text in a box that replaces the label, so an
    -- unindented label never sits under it.
    local line=heading.mcLabel:GetParent()
    assert(line==heading.widget:GetContent() and line.children[1]==heading.mcLabel
        and line.children[2]==heading.mcStar and heading.mcStar.text=='*' and heading.mcStar.visible==2
        and heading.mcLabel.Slot.Padding.Left==-2 and heading.mcLabel.Slot.Size.SizeRule==0
        and heading.mcStar.Slot.Padding.Left==4 and heading.mcStar.Slot.Padding.Right==8
        and heading.mcStar.Font.Size==18,'the star follows the category row label, in its font')
    local toggleRow=built.panels[1].rows[2]
    local toggleLine=toggleRow.mcLabel:GetParent()
    assert(toggleLine.children[2]==toggleRow.mcStar and toggleRow.mcStar.Font.Size==14
        and toggleRow.widget:GetContent().children[1]:GetContent()==toggleLine,
        'a toggle row star follows its label inside the label box')
    function built.model:visibility() return {false,true,true} end
    built:refresh()
    local row=built.panels[1].rows[2]
    assert(row.mcLabel.Font.Size==18 and row.widget:GetContent().Slot.Padding.Left==-2,
        'a hidden category row indents nothing')
    assert(rule.visible==1,'a hidden category row hides its rule')
    assert(not pcall(M.parse,'[Setting.Visual1]\nId=Visual1\nmcCategory=1\nmcLevel=2\n',list),
        'mcCategory excludes mcLevel')
    for i=1,3 do items[i]=saved[i] end
end

-- A subgroup (mcWithin) heading is smaller, at the row indent and without a rule; its rows
-- indent further, 3pt smaller. A category without rows of its own gets a drawn heading.
do
    local saved={}
    for i,item in ipairs(items) do saved[i]=item end
    for i=#items,1,-1 do items[i]=nil end
    for i,group in ipairs({'Outer','Inner','Inner','Only'}) do
        items[i]={id='Row'..i,kind='picker',group=group,label='Row '..i,values={0,1},labels={'Active','Active'}}
    end
    M.parse('[Category.Outer]\n[Category.Inner]\nmcWithin=Outer\n[Category.Only]\nmcWithin=Bare\nmcWithinLabel=Bare\n',items)
    local built=controls.build(widget(),{{choices=items}},api)
    function built.model:visibility() return {true,true,true,true} end
    built:show(1)
    local panel=built.panels[1]
    local outer,inner,only=panel.headings[1],panel.headings[2],panel.headings[4]
    assert(outer.widget.Font.Size==18 and outer.widget.Slot.Padding.Left==-2 and not outer.mcSubheading,
        'a category with rows keeps its heading')
    for _,heading in ipairs({inner,only}) do
        assert(heading.mcSubheading and heading.widget.Font.Size==15 and heading.widget.Slot.Padding.Left==22
            and heading.widget.Slot.Padding.Top==10 and heading.widget.visible~=1 and heading.widget.color=='title',
            'a subgroup heading is smaller, in the title color, 12 pixels right of the row indent')
    end
    assert(outer.mcRuleVisible==true and inner.mcRuleVisible==false,'only a category heading has a rule')
    local top,nested=panel.rows[1],panel.rows[2]
    assert(top.mcLabel.Font.Size==14 and nested.mcLabel.Font.Size==13 and panel.rows[4].mcLabel.Font.Size==13,
        'subgroup rows are 1pt smaller')
    assert(nested.mcLabel.Slot.Padding.Left==top.mcLabel.Slot.Padding.Left+20,'subgroup rows indent 20 pixels further')
    -- Subgroup rows are compact: 4 pixels shorter throughout, the value's padding unchanged.
    local kept={}
    for i,item in ipairs(items) do kept[i]=item end
    for i=#items,1,-1 do items[i]=nil end
    for i,group in ipairs({'Outer','Inner','Plain'}) do
        items[i]={id='Row'..i,kind='picker',group=group,label='Row '..i,values={0,1,2},labels={'A','B','C'}}
    end
    M.parse('[Category.Outer]\n[Category.Inner]\nmcWithin=Outer\n[Category.Plain]\nmcWithin=Outer\nmcHeading=0\n',items)
    local compact=controls.build(widget(),{{choices=items}},api)
    function compact.model:visibility() return {true,true,true} end
    compact.model.pending[1],compact.model.pending[2],compact.model.pending[3]=0,0,0
    compact.mcTestRowHeight=40
    compact:show(1)
    local plainRow,compactRow=compact.panels[1].rows[1],compact.panels[1].rows[2]
    assert(plainRow.wrapper.HeightOverride==43 and compactRow.wrapper.HeightOverride==39,
        'a subgroup row is 4 pixels shorter: '..tostring(compactRow.wrapper.HeightOverride))
    for _,w in ipairs({compactRow.widget,compactRow.parts[1].widget,compactRow.parts[2].widget}) do
        assert(w:GetParent().HeightOverride==39,'and so is every box as tall as the row')
    end
    assert(compactRow.mcPipBox.Slot.Padding.Bottom==plainRow.mcPipBox.Slot.Padding.Bottom,
        'its indicator keeps its place above the row\'s bottom')
    assert(compactRow.value.Slot.Padding.Bottom==plainRow.value.Slot.Padding.Bottom,'its value keeps its bottom padding')
    -- A subgroup without a heading reads as its parent's own rows: drawn as theirs.
    local headless=compact.panels[1].rows[3]
    assert(headless.wrapper.HeightOverride==43 and headless.mcLabel.Font.Size==plainRow.mcLabel.Font.Size
        and headless.mcLabel.Slot.Padding.Left==plainRow.mcLabel.Slot.Padding.Left,
        'a headless subgroup\'s rows are regular rows')
    for i=#items,1,-1 do items[i]=nil end
    for i,item in ipairs(kept) do items[i]=item end
    local drawn
    for _,child in ipairs(panel.scroll.children) do
        if child.children[1] and child.children[1].text=='Bare' then drawn=child end
    end
    assert(drawn and drawn.children[1].Font.Size==18 and drawn.Slot.Padding.Left==-2 and drawn.Slot.Padding.Top==24
        and drawn.children[2].HeightOverride==1,'a row-less category gets a heading with its rule')
    -- DMM draws a category heading left-justified in the muted colour; the drawn one matches.
    local label=drawn.children[1]
    assert(label.Justification==0 and label.color=='muted' and label.Font.Size==outer.widget.Font.Size,
        'a drawn category heading is left-justified, muted and as large as a real one')
    local function at(target)
        for n,child in ipairs(panel.scroll.children) do if child==target then return n end end
    end
    assert(at(drawn)<at(only.widget) and at(nested.wrapper)<at(drawn),
        'the drawn heading sits before its subgroups, after the rows above')
    function built.model:visibility() return {true,true,true,false} end
    built:refresh()
    assert(drawn.visible==1,'the drawn heading hides with its subgroups')
    for i=#items,1,-1 do items[i]=nil end
    for i,item in ipairs(saved) do items[i]=item end
end

-- Level-styled labels take their font when built, without waiting for another SetFont.
do
    local saved={}
    for i,item in ipairs(items) do saved[i]=item end
    local list=items
    list[1]={id='Big',kind='picker',group='G',label='Big',values={0,1},labels={'Off','On'}}
    M.parse('[Setting.Big]\nId=Big\nmcLevel=2\n',list)
    local fonts={}
    local plain=api.caption
    api.caption=function(owner,text)
        local w=plain(owner,text)
        function w:SetFont(v) fonts[#fonts+1]=v.Size;self.Font=v end
        return w
    end
    local built=controls.build(widget(),{{choices=list}},api)
    built:show(1)
    api.caption=plain
    local found=false
    for _,size in ipairs(fonts) do if size==20 then found=true end end
    assert(found,'a level-two label applies its 20pt font')
    for i=1,#saved do items[i]=saved[i] end
end

-- A redraw between press and release must not turn one physical click into
-- another new press. The next press in a double click must still be accepted.
local arrow=initial.panels[1].rows[1].parts[1]
local sounds=0
local function pointerStep(pressed,hovered)
    local wasPressed,origin=arrow.pressed,arrow.pointer
    if pressed and not wasPressed then origin=hovered end
    local clicked=wasPressed and not pressed and origin and hovered
    arrow.pressed,arrow.pointer=pressed,origin
    if clicked then sounds=sounds+1;initial:refresh() end
end
pointerStep(true,true)
initial:refresh()
assert(arrow.pressed and arrow.pointer,'refresh must retain an arrow press until release')
pointerStep(false,true)
pointerStep(false,true)
pointerStep(true,true)
initial:refresh()
pointerStep(false,true)
pointerStep(false,true)
assert(sounds==2,'a double click must produce two changes without replaying either release')

local pointerRow=initial.panels[1].rows[1]
pointerRow.lastNavigation=0
pointerRow.nav:SetValue(0.4)
initial:tick({},function() return false,false,false end,false)
assert(pointerRow.nav:GetValue()==0,'mouse drag must not move the hidden picker navigation slider')
pointerRow.nav:SetValue(0.4)
initial:tick({},function() return false,false,false end,true)
assert(pointerRow.nav:GetValue()==0.4,'controller navigation must still reach the picker slider')

local nativeSlider=initial.panels[1].rows[3]
items[3].minimum,items[3].maximum,items[3].step=0,10,2
nativeSlider.slider=widget();nativeSlider.lastValue=0
nativeSlider.slider:SetValue(0.04)
initial:tick({},function() return false,false,false end,false)
assert(nativeSlider.lastValue==0.04,'raw slider movement within one snapped value must be consumed')
nativeSlider.slider:SetValue(0.25)
initial:tick({},function() return false,false,false end,false)
assert(nativeSlider.lastValue==0.04,'a slider move to another snapped value must reach DMM')

print('PASS nested headings, category style before first heading, tabs, font levels, ordering and reuse')

-- mcType=cycle: one button in the keybind key column showing only the current
-- choice at 13pt; a click moves to the next choice and wraps.
for i=#items,1,-1 do items[i]=nil end
items[1]={id='Wheel',kind='picker',group='After',label='Swap back to default',values={1,2},
    labels={'Abilities','Consumables'}}
assert(not pcall(M.parse,'[Setting.Wheel]\nId=Wheel\nmcType=wheel\n',items),'unknown mcType is refused')
M.parse('[Setting.Wheel]\nId=Wheel\nmcType=cycle\n',items)
assert(items[1].mcCycle and not items[1].mcTabs)
local cycling=controls.build(widget(),{{choices=items}},api)
cycling.model.pending[1]=2
cycling:show(1)
local cycleRow=cycling.panels[1].rows[1]
local cycleButton=cycleRow.mcTabs[1]
assert(#cycleRow.mcTabs==1 and cycleButton.label.text=='Consumables','only the current choice is shown')
assert(cycleButton.label.Font.Size==13,'cycle text is 13pt')
assert(cycleButton.box.WidthOverride==96 and cycleButton.box.HeightOverride==32,'the key box width')
local cycleSlot=cycleButton.box.Slot
assert(cycleSlot.HorizontalAlignment==1 and cycleSlot.Padding.Left==362+(190-96)/2,
    'it is centred on a picker\'s value column, whatever the row indent')
cycleButton.widget.clicked=true
cycling:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(cycling.model.pending[1]==1 and cycleButton.label.text=='Abilities','a click moves to the next choice and wraps')
print('PASS cycle pickers show one choice in the key column and advance on click')

-- mcType=onoff: a 44x20 switch centred in the value column, the current choice's label to
-- its left, holding 0 (off) or 1 (on). A 2-pixel outline whose side bars run between the top and
-- bottom ones, and inside it 3 pixels clear a toggle in the left (off, grey, dimmer) or right
-- (on, gold) half. A click anywhere across the value column flips it. The outline brightens
-- and a dim glow fills the switch while its row is hovered or selected.
-- A change slides the toggle across in 0.2 seconds, easing out, blending its colors.
for i=#items,1,-1 do items[i]=nil end
items[1]={id='Glow',kind='picker',group='After',label='Glow',values={0,1},labels={'Off','On'}}
items[2]={id='Three',kind='picker',group='After',label='Three',values={0,1,2},labels={'A','B','C'}}
assert(not pcall(M.parse,'[Setting.Three]\nId=Three\nmcType=onoff\n',items),'onoff needs the choices 0 and 1')
items[2]=nil
assert(not pcall(M.parse,'[Setting.Glow]\nId=Glow\nmcType=onoff\nmcTabsWidth=200\n',items),'mcTabsWidth is for tabs')
M.parse('[Setting.Glow]\nId=Glow\nmcType=onoff\n',items)
assert(items[1].mcOnOff and not items[1].mcTabs and not items[1].mcCycle)
local now=10
api.clock=function() return now end
local switching=controls.build(widget(),{{choices=items}},api)
switching.model.pending[1]=0
switching:show(1)
local switchRow=switching.panels[1].rows[1]
local switch,flip=switchRow.mcOnOff,switchRow.mcTabs[1]
assert(switch and #switchRow.mcTabs==1 and not switchRow.mcPipBox,'one switch and no indicator')
assert(switch.box.WidthOverride==44 and switch.box.HeightOverride==20,'the switch is 44 by 20')
assert(flip.box.WidthOverride==190 and flip.box.HeightOverride==nil and flip.box.Slot.HorizontalAlignment==1
    and flip.box.Slot.VerticalAlignment==0 and flip.box.Slot.Padding.Left==362,'the clickable area is the value column, row-high')
assert(flip.widget:GetParent()==switch.box:GetParent():GetParent(),'the button spans the switch and its label')
local lane=switch.box:GetParent()
assert(lane.children[2]==switch.box and lane.children[1]==switch.text,'the label, then the switch at the right')
assert(switch.text.Slot.Size.SizeRule==1 and switch.text.Justification==2 and switch.text.Slot.Padding.Right==12
    and switch.text.Slot.VerticalAlignment==2,'the label fills the rest, right-aligned and centred, 12 pixels from the switch')
assert(lane.Slot.Padding.Right==(190-44)-(190-44)//2,'the switch is centred in the value column')
assert(switch.text.text=='Off','the label shows the current choice')
assert(switch.text.opacity==0.75,'the label is a little dimmer than a value')
assert(#switch.bars==4,'a four-bar outline')
for _,bar in ipairs(switch.bars) do
    local box=bar:GetParent()
    assert((box.HeightOverride or box.WidthOverride)==2,'the outline is 2 pixels thick')
    local side=box.WidthOverride~=nil
    assert(not side or box.Slot.Padding.Top==2 and box.Slot.Padding.Bottom==2,'side bars run between top and bottom')
end
local toggleBox=switch.toggle:GetParent()
assert(toggleBox.WidthOverride==17 and toggleBox.HeightOverride==10,'the toggle fills half the inside, 3 pixels clear')
assert(toggleBox.Slot.Padding.Left==5 and toggleBox.Slot.Padding.Right==5 and toggleBox.Slot.HorizontalAlignment==1)
local function same(color,r,g,b,a)
    return math.abs(color.R-r)<1e-6 and math.abs(color.G-g)<1e-6 and math.abs(color.B-b)<1e-6 and math.abs(color.A-a)<1e-6
end
local idle=function() return false,false,false end
switching.hovered,switching.current=nil,nil
switching:tick({},idle,false)
assert(switch.on==false and toggleBox.RenderTranslation.X==0,'off sits left, without sliding there')
assert(same(switch.toggle.BrushColor,0.62,0.55,0.42,0.9*0.6) and same(switch.bars[1].BrushColor,0.62,0.55,0.42,0.4*0.6)
    and switch.glow.BrushColor.A==0,'off is grey, dimmer, with a dimmed outline and no glow')
flip.widget.clicked=true
switching:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(switching.model.pending[1]==1 and switch.on and toggleBox.RenderTranslation.X==0,'a click turns it on; the slide starts')
now=now+0.05;switching:tick({},idle,false)
local midway=toggleBox.RenderTranslation.X
assert(midway>0 and midway<17,'partway across after 0.05 seconds: '..midway)
assert(switch.toggle.BrushColor.R>0.62 and switch.toggle.BrushColor.R<0.95,'its color blends from grey to gold')
now=now+0.05;switching:tick({},idle,false)
assert(toggleBox.RenderTranslation.X>=midway,'it keeps going')
now=now+0.15;switching:tick({},idle,false)
assert(toggleBox.RenderTranslation.X==17 and same(switch.toggle.BrushColor,0.95,0.63,0.08,0.9),'on rests right, gold')
assert(switch.text.text=='On','the label follows the value')
switching.hovered,switching.current=nil,nil
switching:tick({},idle,false)
assert(same(switch.bars[1].BrushColor,0.95,0.63,0.08,0.4) and switch.glow.BrushColor.A==0,'a dimmed gold outline at rest')
switching.hovered=1
switching:tick({},idle,false)
assert(same(switch.bars[1].BrushColor,0.95,0.63,0.08,0.9) and same(switch.glow.BrushColor,0.95,0.63,0.08,0.1),
    'hovered: a brighter outline and a dim glow')
switching.hovered=nil;switching.current=1
switching:tick({},idle,false)
assert(switch.hot and switch.glow.BrushColor.A>0,'selected glows like hovered')
flip.widget.clicked=true
switching:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(switching.model.pending[1]==0 and switch.on==false,'a second click turns it off')
now=now+0.05;switching:tick({},idle,false)
assert(toggleBox.RenderTranslation.X<17 and toggleBox.RenderTranslation.X>0,'and slides back')
now=now+0.2;switching:tick({},idle,false)
assert(toggleBox.RenderTranslation.X==0 and same(switch.toggle.BrushColor,0.62,0.55,0.42,0.54),'off rests left, grey')
api.clock=nil
local framed=controls.build(widget(),{{choices=items}},api)
framed.model.pending[1]=0;framed:show(1)
local framedRow=framed.panels[1].rows[1]
framedRow.mcTabs[1].widget.clicked=true
framed:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
for _=1,20 do framed:tick({},idle,false) end
assert(framedRow.mcOnOff.toggleBox.RenderTranslation.X==17,'without a clock each tick counts as a 60 Hz frame')
print('PASS on/off switches draw their value and flip on click')

-- mcWrap: a read-only value in a wider 13pt column, broken at commas below 34
-- characters; the row grows with its lines.
local wrapped,lineCount=M.wrapList('Attack, Block, Dodge, Heavy Attack, Interact, Quickslot Left',34)
assert(wrapped=='Attack, Block, Dodge,\nHeavy Attack, Interact,\nQuickslot Left' and lineCount==3,wrapped)
for line in wrapped:gmatch('[^\n]+') do assert(#line<34,line) end
assert(select(1,M.wrapList('Unassigned',34))=='Unassigned' and select(2,M.wrapList('',34))==1)
for i=#items,1,-1 do items[i]=nil end
items[1]={id='Pad',kind='picker',group='After',label='Face Button Bottom',values={0},
    labels={'Attack, Block, Dodge, Heavy Attack, Interact, Quickslot Left'}}
assert(not pcall(M.parse,'[Setting.Pad]\nId=Pad\nmcWrap=1\n',items),'mcWrap requires a read-only row')
M.parse('[Setting.Pad]\nId=Pad\nmcReadOnly=1\nmcWrap=1\n',items)
local padUi=controls.build(widget(),{{choices=items}},api)
padUi:show(1)
local padRow=padUi.panels[1].rows[1]
assert(padRow.mcWrapped.text==wrapped and padRow.mcWrapped.Font.Size==13,'the wrapped value is 13pt')
assert(padRow.mcWrapped:GetParent().WidthOverride==584-230-24 and padRow.widget:GetParent().WidthOverride==230,
    'the value column is wider than DMM\'s picker value')
assert(padRow.wrapper.HeightOverride==66,'the row grows to fit three lines')
print('PASS wrapped read-only values break at commas in a wider column')

-- mcChoiceNotes: a picker choice's note shows on a small muted second line under
-- DMM's value, which moves up while the current choice has a note.
for i=#items,1,-1 do items[i]=nil end
items[1]={id='Template',kind='picker',group='Visuals',label='Quickslots',values={0,7,9},
    labels={'None','Wheels','Underbar'}}
local notes='[Setting.Template]\nId=Template\nmcChoiceNotes=7:Fangdango;9: Fangdango \n'
for _,bad in ipairs({'7:Fangdango;7:Other','8:Fangdango','7:','7:'..('x'):rep(65),'Fangdango'}) do
    assert(not pcall(M.parse,'[Setting.Template]\nId=Template\nmcChoiceNotes='..bad..'\n',items),bad)
end
local toggleItems={{id='Flag',kind='toggle',group='G',label='Flag',values={0,1},labels={'Off','On'}}}
assert(not pcall(M.parse,'[Setting.Flag]\nId=Flag\nmcChoiceNotes=1:On\n',toggleItems),'pickers only')
M.parse(notes,items)
assert(items[1].mcChoiceNotes[7]=='Fangdango' and items[1].mcChoiceNotes[9]=='Fangdango'
    and items[1].mcChoiceNotes[0]==nil,'notes are trimmed; None has none')
local noteUi=controls.build(widget(),{{choices=items}},api)
noteUi:show(1)
local noteRow=noteUi.panels[1].rows[1]
local noteBox=noteRow.mcNoteBox
-- The note overlays the row with the value's width and place, read from DMM's
-- size boxes; these test rows have none, so DMM's 330+32 and 190 pixels apply.
local noteSlot=noteBox.Slot
assert(noteBox:GetParent()==noteRow.background:GetParent() and noteBox.WidthOverride==190
    and noteSlot.HorizontalAlignment==1 and noteSlot.Padding.Left==362 and noteSlot.VerticalAlignment==3,
    'the note takes the value\'s width, under it')
assert(noteRow.mcNote.Slot.HorizontalAlignment==2 and noteRow.mcNote.Slot.VerticalAlignment==2,
    'the note is centered in that space')
assert(noteRow.mcNote.Font.Size==10 and noteRow.mcNote.color=='muted','the note is small and muted')
assert(#noteRow.parts==3 and noteRow.value.parent~=noteBox,'DMM\'s value keeps its place')
-- None has no note: one line, 2 pixels above where DMM puts it, a point smaller.
local valueSize=noteRow.mcValueSize
assert(noteBox.visible==1 and noteRow.value.Slot.Padding.Bottom==4 and valueSize
    and noteRow.value.Font.Size==valueSize-1)
noteUi.model.pending[1]=7;noteUi:refresh()
assert(noteBox.visible==3 and noteRow.mcNote.text=='Fangdango' and noteRow.value.Slot.Padding.Bottom==10
    and noteBox.Slot.Padding.Bottom==8 and noteRow.mcPipBox.Slot.Padding.Bottom==-1
    and noteRow.value.Font.Size==valueSize,
    'a noted choice shows its note without taking clicks, and the value moves up at full size')
noteUi.model.pending[1]=0;noteUi:refresh()
assert(noteBox.visible==1 and noteRow.value.Slot.Padding.Bottom==4 and noteRow.value.Font.Size==valueSize-1,'back to one line')
-- A picker with arrows shows one pip per choice under its value, the current one lit,
-- in the row's bottom pixels below the note; half strength until its row is hovered.
local pipBox=noteRow.mcPipBox
assert(pipBox and #noteRow.mcPips==3 and pipBox:GetParent()==noteRow.background:GetParent()
    and pipBox.WidthOverride==142 and pipBox.HeightOverride==4 and pipBox.Slot.Padding.Left==362+24
    and pipBox.Slot.VerticalAlignment==3 and pipBox.Slot.Padding.Bottom==-1+6 and pipBox.HeightOverride==4 and pipBox.visible==3,
    'the indicator spans 75% of the value\'s width, centred, in the bottom pixels, never hit-tested')
local widths={}
for n,b in ipairs(noteRow.mcPipBoxes) do widths[n]=b.WidthOverride end
assert(table.concat(widths,',')=='45,44,45' and noteRow.mcPipBoxes[2].Slot.Padding.Left==4,
    'the pips fill it, 4 pixels apart, differing by a pixel at most: '..table.concat(widths,','))
assert(-1+pipBox.HeightOverride<=noteBox.Slot.Padding.Bottom,'under a note, at its lowest, it sits below the note')
-- A change animates over ticks; settle runs enough of them for it to finish.
local function settle(ui) for _=1,20 do ui:tick({},function() return false,false,false end,false) end end
settle(noteUi)
local function lit() local out={} for n,pip in ipairs(noteRow.mcPips) do if pip.BrushColor.A>0.5 then out[#out+1]=n end end return table.concat(out,',') end
assert(lit()=='1','the first choice is current')
local function heights() local out={} for n,b in ipairs(noteRow.mcPipBoxes) do out[n]=b.HeightOverride end return table.concat(out,',') end
assert(heights()=='2,2,2' and noteRow.mcPipBoxes[2].Slot.VerticalAlignment==1
    and noteRow.mcPipBoxes[2].Slot.Padding.Top==1,
    'idle, the current pip is as tall as the others, all a pixel below the strip\'s top')
-- A change slides the new value in from the side it was stepped towards, fading in, while
-- the old pip fades out and the new one in; a step back comes from the other side.
do
    local now=20
    api.clock=function() return now end
    local value=noteRow.value
    local function mid(color,from,to) return color.A<math.max(from.A,to.A) and color.A>math.min(from.A,to.A) end
    noteUi.model.pending[1]=7;noteUi:refresh()
    assert(value.RenderTranslation.X==12 and value.opacity==0,'the new value starts 12 pixels right, unseen')
    now=now+0.05;noteUi:tick({},function() return false,false,false end,false)
    assert(value.RenderTranslation.X>0 and value.RenderTranslation.X<12 and value.opacity>0 and value.opacity<1,
        'partway in')
    assert(mid(noteRow.mcPips[1].BrushColor,{A=0.9},{A=0.35}) and mid(noteRow.mcPips[2].BrushColor,{A=0.9},{A=0.35}),
        'the old pip fading out, the new one in')
    now=now+0.2;noteUi:tick({},function() return false,false,false end,false)
    assert(value.RenderTranslation.X==0 and value.opacity==1 and lit()=='2','settled')
    noteUi.model.pending[1]=0;noteUi:refresh()
    assert(value.RenderTranslation.X==-12,'a step back comes from the left')
    now=now+0.3;noteUi:tick({},function() return false,false,false end,false)
    assert(value.RenderTranslation.X==0 and lit()=='1')
    api.clock=nil
end
noteUi.model.pending[1]=9;noteUi:refresh();settle(noteUi)
assert(lit()=='3' and heights()=='2,2,2','the indicator follows the choice')
assert(pipBox.opacity==0.5,'half strength while the row is not hovered')
noteUi.hovered=1;noteUi:tick({},function() return false,false,false end,false)
assert(pipBox.opacity==1 and heights()=='2,2,3','full strength while hovered, the current pip a pixel taller, downwards')
noteUi.hovered=nil;noteUi:tick({},function() return false,false,false end,false)
assert(pipBox.opacity==0.5 and heights()=='2,2,2','back to half and level when the pointer leaves')
noteUi.current=1;noteUi:tick({},function() return false,false,false end,false)
assert(pipBox.opacity==1 and heights()=='2,2,3','the selected row counts as hovered, keyboard or controller')
noteUi.current=nil;noteUi:tick({},function() return false,false,false end,false)
-- A click on the value's outer 40%, either side, steps like the arrow there: two clear
-- buttons over the text inside DMM's value button; the middle 20% is left to that button.
do
    local zones=noteRow.mcZones
    local stack=noteRow.value:GetParent()
    assert(zones and #zones==2 and stack:GetParent()==noteRow.parts[2].widget and stack.children[1]==noteRow.value
        and noteRow.value.Slot.Padding.Left==4 and noteRow.value.Slot.VerticalAlignment==2
        and stack.Slot.HorizontalAlignment==0 and stack.Slot.VerticalAlignment==0 and stack.Slot.Padding.Left==0,
        'the value text keeps its place and padding under the zones')
    local lane=zones[1].widget:GetParent()
    assert(lane==zones[2].widget:GetParent() and #lane.children==3 and lane.children[1]==zones[1].widget
        and lane.children[3]==zones[2].widget and zones[1].widget.Slot.Size.Value==0.4
        and zones[2].widget.Slot.Size.Value==0.4 and math.abs(lane.children[2].Slot.Size.Value-0.2)<1e-9
        and zones[1].widget.IsFocusable==false,'two 40% zones around a 20% middle, never focused')
    local change=noteUi.model.change
    function noteUi.model:change(i,direction)
        local values,at=self.items[i].values,1
        for n,value in ipairs(values) do if value==self.pending[i] then at=n end end
        self.pending[i]=values[math.max(1,math.min(#values,at+(direction==1 and -1 or 1)))]
    end
    local click=function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end
    noteUi.model.pending[1]=0;noteUi:refresh()
    zones[2].widget.clicked=true;noteUi:tick({},click,false)
    assert(noteUi.model.pending[1]==7 and noteUi.current==1,'the right zone steps forward and selects the row')
    zones[1].widget.clicked=true;noteUi:tick({},click,false)
    assert(noteUi.model.pending[1]==0,'the left zone steps back')
    noteRow.parts[3].widget:SetIsEnabled(false)
    zones[2].widget.clicked=true;noteUi:tick({},click,false)
    assert(noteUi.model.pending[1]==0,'not while its arrow is disabled')
    noteRow.parts[3].widget:SetIsEnabled(true)
    noteUi.model.change=change;noteUi.current,noteUi.hovered=nil,nil;noteUi:refresh()
    noteUi:tick({},function() return false,false,false end,false)
end
-- Like the game's own pickers, the arrows show only on the hovered or selected row, and
-- keep their place while hidden.
local function arrows() return noteRow.parts[1].widget:GetParent().visible..','..noteRow.parts[3].widget:GetParent().visible end
assert(arrows()=='2,2','arrows are hidden on an idle row')
noteUi.hovered=1;noteUi:tick({},function() return false,false,false end,false)
assert(arrows()=='0,0','arrows show on the hovered row')
noteUi.hovered=nil;noteUi.current=1;noteUi:tick({},function() return false,false,false end,false)
assert(arrows()=='0,0','arrows show on the selected row')
noteUi.current=nil;noteUi:tick({},function() return false,false,false end,false)
assert(arrows()=='2,2','arrows hide again when the row is neither')
-- A slider is drawn like a picker's indicator: its value smaller and centred on the control,
-- over a bar 75% of the control wide, filled to the value; a mark stands at the value while
-- its row is hovered or selected.
do
    local saved={}
    for n,item in ipairs(items) do saved[n]=item end
    for n=#items,1,-1 do items[n]=nil end
    items[1]={id='Volume',kind='slider',group='Audio',label='Volume',minimum=0,maximum=100,step=1}
    local sliding=controls.build(widget(),{{choices=items}},api)
    sliding.model.pending[1]=50
    sliding:show(1)
    local row=sliding.panels[1].rows[1]
    local surface=row.slider:GetParent()
    local bar=row.mcSlider
    assert(bar and surface:GetParent().WidthOverride==190 and row.value:GetParent()==surface
        and surface.children[1].visible==1,'one control in place of the track and value column')
    assert(row.widget:GetParent().WidthOverride==362,'the control takes a picker\'s value column')
    assert(row.value.Font.Size==12 and row.value.Slot.HorizontalAlignment==0 and row.value.Justification==1
        and row.value.Slot.VerticalAlignment==2 and row.value.Slot.Padding.Bottom==6 and row.value.visible==3,
        'the value is 2 points smaller, its text centred across the control, 3 pixels up, never hit-tested')
    assert(bar.span==142 and bar.bar.WidthOverride==142 and bar.bar.HeightOverride==10 and bar.bar.Slot.Padding.Bottom==4
        and row.slider.Slot.Padding.Left==24 and row.slider.Slot.Padding.Right==24 and row.slider.opacity==0,
        'the bar takes 75% of the control, centred, and the invisible native slider spans it')
    assert(bar.filled.WidthOverride==71 and bar.filled.HeightOverride==4,'the lit part is 4 tall, filled to the value')
    assert(bar.filled:GetParent():GetParent().Slot.VerticalAlignment==1 and bar.markSlot.VerticalAlignment==1
        and bar.markSlot.HorizontalAlignment==1,'the strip and mark keep their own heights, top-aligned')
    assert(bar.markSlot.Padding.Left==70 and #bar.mark.children==3 and bar.mark.children[2].WidthOverride==1
        and bar.mark.children[2].HeightOverride==10,'the 3-pixel mark is centred on the fill\'s end')
    assert(bar.bar.opacity==0.5 and bar.mark.visible==1,'idle: half strength, no mark')
    sliding.current=1;sliding:tick({},function() return false,false,false end,false)
    assert(bar.bar.opacity==1 and bar.mark.visible==3,'selected: full strength, with its mark')
    sliding.current=nil;sliding:tick({},function() return false,false,false end,false)
    assert(bar.bar.opacity==0.5 and bar.mark.visible==1,'back to idle')
    -- A change slides the fill, and the mark with it, to the new value.
    local now=30
    api.clock=function() return now end
    local idle=function() return false,false,false end
    sliding.model.pending[1]=0;sliding:refresh()
    assert(bar.filled.WidthOverride==71,'the slide starts where the fill is')
    now=now+0.05;sliding:tick({},idle,false)
    assert(bar.filled.WidthOverride<71 and bar.filled.WidthOverride>0
        and bar.markSlot.Padding.Left==bar.filled.WidthOverride-1,'partway, the mark at the fill\'s end')
    now=now+0.2;sliding:tick({},idle,false)
    assert(bar.filled.WidthOverride==0 and bar.markSlot.Padding.Left==0,'at the minimum the mark stays inside the bar')
    sliding.model.pending[1]=100;sliding:refresh()
    now=now+0.25;sliding:tick({},idle,false)
    assert(bar.filled.WidthOverride==142 and bar.markSlot.Padding.Left==139,'at the maximum too')
    api.clock=nil
    for n=#items,1,-1 do items[n]=nil end
    for n,item in ipairs(saved) do items[n]=item end
end
-- A toggle's value takes a picker's value column: its label ends at 362 whatever the indent,
-- and its value is 190 wide.
do
    local saved={}
    for n,item in ipairs(items) do saved[n]=item end
    for n=#items,1,-1 do items[n]=nil end
    items[1]={id='Lead',kind='picker',group='G',label='Lead',values={0,1},labels={'A','B'}}
    items[2]={id='Flag',kind='toggle',group='G',label='Flag',values={0,1},labels={'Off','On'}}
    local toggling=controls.build(widget(),{{choices=items}},api)
    toggling:show(1)
    local row=toggling.panels[1].rows[2]
    local content=row.widget:GetContent()
    local indent=content.Slot.Padding.Left
    assert(indent==26,'the toggle indents like other rows')
    assert(content.children[1].WidthOverride==362-indent and content.children[2].WidthOverride==190
        and row.value:GetParent()==content.children[2],'its value lines up with a picker\'s')
    for n=#items,1,-1 do items[n]=nil end
    for n,item in ipairs(saved) do items[n]=item end
end
-- At an end, DMM's hidden arrow shows faint instead; a disabled picker keeps both hidden.
noteRow.left,noteRow.right=noteRow.parts[1],noteRow.parts[3]
noteRow.renderLeft,noteRow.renderRight=true,false;noteRow.parts[3].widget:SetRenderOpacity(0)
noteRow.parts[3].widget:SetIsEnabled(false)
noteUi:refresh()
assert(noteRow.parts[3].widget.opacity==0.5,'the arrow at the last choice is faint, not hidden')
-- Clicks wrap around: the faint arrow, or that side of the value, goes to the other end, and
-- the new value slides in from the side clicked.
do
    local click=function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end
    assert(noteRow.parts[3].widget.enabled==true,'the faint arrow takes clicks')
    noteUi.model.pending[1]=9;noteUi:refresh();settle(noteUi)
    noteRow.parts[3].widget.clicked=true;noteUi:tick({},click,false)
    assert(noteUi.model.pending[1]==0 and noteUi.current==1,'past the last choice comes the first')
    assert(noteRow.value.RenderTranslation.X==12,'sliding in from the right, the side clicked')
    settle(noteUi)
    noteRow.renderLeft,noteRow.renderRight=false,true;noteUi:refresh()
    noteRow.mcZones[1].widget.clicked=true;noteUi:tick({},click,false)
    assert(noteUi.model.pending[1]==9 and noteRow.value.RenderTranslation.X==-12,
        'before the first choice comes the last, from the left')
    settle(noteUi)
    noteRow.renderLeft,noteRow.renderRight=true,false;noteUi:refresh()
    noteUi.current=nil
end
noteRow.renderLeft,noteRow.renderRight=false,false
noteRow.parts[1].widget:SetRenderOpacity(0);noteRow.parts[3].widget:SetRenderOpacity(0)
noteRow.parts[1].widget:SetIsEnabled(false);noteRow.parts[3].widget:SetIsEnabled(false)
noteUi:refresh()
assert(noteRow.parts[1].widget.opacity==0 and noteRow.parts[3].widget.opacity==0,'a disabled picker shows no arrows')
assert(not noteRow.parts[1].widget.enabled and not noteRow.parts[3].widget.enabled,'and takes no clicks')
noteRow.parts[1].widget:SetIsEnabled(true);noteRow.parts[3].widget:SetIsEnabled(true)
noteRow.left,noteRow.right=nil,nil
noteUi.model.pending[1]=0;noteUi:refresh()
-- Many choices: a track with a thumb at the current choice's place.
local manyItems={{id='Many',kind='picker',group='G',label='Many',values={},labels={}}}
for n=1,20 do manyItems[1].values[n]=n;manyItems[1].labels[n]=tostring(n) end
local savedItems={};for n,item in ipairs(items) do savedItems[n]=item end
for n=#items,1,-1 do items[n]=nil end;items[1]=manyItems[1]
local manyUi=controls.build(widget(),{{choices=items}},api)
manyUi.model.pending[1]=20;manyUi:show(1)
local thumb=manyUi.panels[1].rows[1].mcPipThumb
assert(thumb and #manyUi.panels[1].rows[1].mcPips==0 and thumb.width==7 and thumb.slot.Padding.Left==142-7 and thumb.slot.Padding.Top==1,
    'beyond sixteen choices a thumb marks the place along a track')
-- A change fades the thumb out, moves it, and fades it back in.
do
    local now=50
    api.clock=function() return now end
    manyUi.model.pending[1]=1;manyUi:refresh()
    assert(thumb.box.opacity==1 and thumb.slot.Padding.Left==142-7,'the thumb starts at its old place')
    now=now+0.02;manyUi:tick({},function() return false,false,false end,false)
    assert(thumb.box.opacity<1 and thumb.slot.Padding.Left==142-7,'fading out where it was')
    now=now+0.25;manyUi:tick({},function() return false,false,false end,false)
    assert(thumb.box.opacity==1 and thumb.slot.Padding.Left==0,'back at full strength at its new place')
    api.clock=nil
end
for n=#items,1,-1 do items[n]=nil end;for n,item in ipairs(savedItems) do items[n]=item end
-- A tab picker shows every choice itself and gets no note line.
M.parse(notes..'mcType=tab\n',items)
local tabUi=controls.build(widget(),{{choices=items}},api)
tabUi:show(1)
assert(tabUi.panels[1].rows[1].mcNote==nil,'tab pickers are not covered')
print('PASS picker choice notes show on a second line under the value')

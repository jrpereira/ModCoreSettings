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
local function widget()
    local w={children={},Font={SkewAmount=0},enabled=true,position=0,visible=0,
        WidgetStyle={NormalPadding={Left=16,Top=0,Right=0,Bottom=0},
            PressedPadding={Left=16,Top=0,Right=0,Bottom=0}}}
    function w:GetFullName() return 'Widget '..tostring(self) end
    function w:IsValid() return true end
    function w:GetParent() return self.parent end
    function w:GetChildrenCount() return #self.children end
    function w:GetChildAt(n) return self.children[n+1] end
    function w:GetContent() return self.children[1] end
    function w:AddChild(child)
        child.parent=self;self.children[#self.children+1]=child
        child.Slot={Padding={Left=0,Top=0,Right=0,Bottom=0}}
        setmetatable(child.Slot,{__index=function(_,key)
            return function(slot,value) slot[key:sub(4)]=value end
        end})
        return child.Slot
    end
    function w:RemoveChild(child)
        for n,v in ipairs(self.children) do if v==child then table.remove(self.children,n);child.parent=nil;return true end end
        return false
    end
    function w:RemoveFromParent() if self.parent then self.parent:RemoveChild(self) end end
    function w:ClearChildren() for _,child in ipairs(self.children) do child.parent=nil end;self.children={} end
    function w:SetContent(child) self:ClearChildren();return self:AddChild(child) end
    function w:SetVisibility(v) self.visible=v end
    function w:SetValue(v) self.position=v end
    function w:GetValue() return self.position end
    function w:SetIsEnabled(v) self.enabled=v end
    function w:GetIsEnabled() return self.enabled end
    function w:IsPressed() return self.pressed or false end
    function w:IsHovered() return self.hovered or false end
    function w:HasUserFocus() return false end
    function w:SetRenderOpacity(v) assert(type(v)=='number');self.opacity=v end
    function w:SetFont(v) self.Font=v end
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
    function w:ScrollToEnd() self.scrolledToEnd=(self.scrolledToEnd or 0)+1 end
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
        return child==title and titleWrapper or child
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
    ui.mcTestSetText,ui.mcTestFeedback=a.setText,a.feedback
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
            else l.Slot:SetPadding({Left=20,Top=0,Right=8,Bottom=0}) end
            local box=widget();box:SetContent(b)
            local bg=widget();local overlay=widget();overlay:AddChild(bg);overlay:AddChild(box)
            local value=a.caption(tree,'');overlay:AddChild(value)
            local parts={}
            -- Like DMM, only a picker adds its left, value and right buttons after the label.
            if s.kind=='picker' then
                for n=1,3 do local b2=a.button(tree,n==1 and '<' or n==3 and '>' or '');local size=widget();size:SetContent(b2);overlay:AddChild(size);parts[n]={widget=b2} end
            end
            local wrapper=widget();wrapper:SetContent(overlay);p.scroll:AddChild(wrapper)
            p.rows[i]={widget=b,value=value,background=bg,parts=parts,wrapper=wrapper,nav=widget(),visible=true}
        end
        p.built=true
    end
    function ui:show(i) self.active=i;self:prepare(i);self:refresh() end
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
local textLines,textChanged,textPolls={},false,0
local textSource={poll=function() textPolls=textPolls+1;return textLines,textChanged end}
assert(M.install(choices,controls,pages,{keyColumn={key=96,keyOffset=408},textSources={errors=textSource},
    textFormat=function(lines) return #lines==0 and 'None' or table.concat(lines,'\n') end,
    textTable=require('menu_contributions').textTable}))
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
-- A group: a header with a horizontal line, then barred lines of its pages; hidden and
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
-- whose rule is centred on the title line and fills the rest of the width.
assert(header.WidthOverride==584,'the header spans the list')
assert(header.Slot.Padding.Top==-4 and header.Slot.Padding.Bottom==8,'the header sits raised with a gap below')
local headerRow=header:GetContent()
local iconBox,text=headerRow.children[1],headerRow.children[2]
assert(#headerRow.children==2 and iconBox.WidthOverride==20 and iconBox:GetContent().text=='⁂'
    and iconBox:GetContent().Slot.HorizontalAlignment==2 and iconBox:GetContent().Slot.VerticalAlignment==2,
    'the icon sits centred in a box as wide as the line bar, over its line')
assert(iconBox.Slot.Padding.Right==8,'the title follows the icon closely')
assert(iconBox:GetContent().Slot.Padding.Top==12,'the icon sits level with the title')
assert(text.Slot.Size.SizeRule==1,'the text fills the rest of the header')
-- The title row (the highlight box) comes first; the kind line follows so it draws
-- over the box, pulled up into it.
local titleLine,kind=text.children[1],text.children[2]
assert(titleLine.Slot.Padding.Top==20 and lineRows[2].wrapper.HeightOverride==34,'the highlight box starts 20 down, 34 tall')
assert(titleLine.children[2].Slot.Padding.Top==6 and titleLine.children[2].Slot.Padding.Bottom==-2,'the rule sits with the title')
local titlePadding=titleLine.children[1]:GetContent():GetContent().Slot.Padding
assert(titlePadding.Left==-2 and titlePadding.Top==6 and titlePadding.Bottom==-1,'the title sits in its box')
assert(kind.text=='Collection' and kind.Font.Size==10 and kind.color=='muted' and kind.visible==4
    and kind.Slot.Padding.Top==-35 and kind.Slot.Padding.Left==10 and kind.opacity==0.6,
    'a small faint line names the kind of group, drawn over the box')
assert(math.abs(kind.Slot.Padding.Bottom-15.6)<0.01,'the kind line keeps the column as tall as the box')
assert(#titleLine.children==2 and titleLine.children[1]==lineRows[2].wrapper and lineRows[2].wrapper.WidthOverride==nil
    and titleLine.children[2].HeightOverride==2 and titleLine.children[2]:GetContent()
    and titleLine.children[2].Slot.VerticalAlignment==2 and titleLine.children[2].Slot.Size.SizeRule==1,
    'the title keeps its own width and its rule is centred on it, filling the rest')
assert(#grid.children==4 and grid.children[1].HeightOverride==37 and grid.children[1].WidthOverride==20
    and grid.children[1]:GetContent(),'a grid row starts with its vertical line')
for n,index in ipairs({3,5,6}) do
    local frame=grid.children[n+1]
    assert(frame:GetContent()==lineRows[index].wrapper and frame.BrushColor and frame.BrushColor.A<0.2
        and lineRows[index].wrapper.WidthOverride==180 and lineRows[index].wrapper.HeightOverride==37
        and frame.Slot.Padding.Right==8 and frame.Slot.Padding.Bottom==4,
        'pages fill three columns in order, each on a faint background, rows 4 px apart')
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
-- A heading's row sits in its title line, in the header text, row and width box, in its group.
local function groupBox(row) local w=row.wrapper;for _=1,5 do w=w:GetParent() end;return w end
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
assert(moreRow.widget:GetContent().Font.Size==12 and modRow.widget:GetContent().Font.Size==14,
    'the folded entry is two sizes smaller')
assert(modRow.mcFrame.Slot.Padding.Left==2 and modRow.mcFrame.Slot.Padding.Right==6
    and modRow.widget:GetContent().Slot.Padding.Left==6,'a mod row box sits 2 right of its line, its text 6 in')
-- In a grid the folded entry takes the next place beside the mods.
local gridMore=pages.build(widget(),{
    {name='Group',choices=items,mcBrowserLine='head'},
    {name='Mod',choices=items,mcBrowserLine='cell'},
    {name='and 1 more with no settings',choices=items,mcBrowserLine='cell',mcBrowserMore='g'},
},nil,api).allRows
local modCell,moreCell=gridMore[2],gridMore[3]
assert(modCell.mcFrame.parent and modCell.mcFrame.parent==moreCell.mcFrame.parent,'the folded entry fills a column like a mod')
assert(modCell.widget:GetContent().Slot.Padding.Top==0 and modCell.widget:GetContent().Slot.Padding.Bottom==3
    and moreCell.widget:GetContent().Slot.Padding.Bottom==3,'cells sit 5 px higher, 2 px shorter; beside a mod the entry lines up')
-- Starting a row of its own, the entry sits 4 px higher.
local alone=pages.build(widget(),{
    {name='Group',choices=items,mcBrowserLine='head',mcBrowserColumns=2},
    {name='A',choices=items,mcBrowserLine='cell'},{name='B',choices=items,mcBrowserLine='cell'},
    {name='and 1 more with no settings',choices=items,mcBrowserLine='cell',mcBrowserMore='g'},
},nil,api).allRows
assert(alone[4].widget:GetContent().Slot.Padding.Bottom==11 and alone[4].mcFrame.parent~=alone[2].mcFrame.parent,
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
local rowLine=bob.children[4]
assert(#rowLine.children==2 and rowLine.children[1].HeightOverride==40
    and rowLine.children[2]:GetContent()==mixedRows[3].wrapper and mixedRows[3].wrapper.WidthOverride==556
    and mixedRows[3].wrapper.HeightOverride==40 and not mixedRows[3].widget:GetContent().AutoWrapText,
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
local pickerHeader=controls.build(widget(),{{id='ModCoreControls',choices=items}},api)
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
assert(statusBox.WidthOverride==572 and statusBox.Slot.Padding.Top==4+28,
    'A page status without room beside the tabs must drop below them at full width')
headerRow.mcHeaderTabsWidth=tabsWidth;pickerHeader:refresh()
assert(statusBox.WidthOverride==572-tabsWidth-12 and statusBox.Slot.Padding.Top==4,
    'The page status must return beside the tabs when they fit again')
headerRow.mcTabs[2].widget.clicked=true
pickerHeader:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(pickerHeader.model.pending[1]==items[1].values[2] and headerRow.mcTabs[2].selected,
    'Clicking a header tab must select its choice')
assert(headerRow.mcTabs[1].label.Font.Size==12 and headerTabs.children[2].HeightOverride==28,
    'Header tabs must use a compact 12-point font and 28-pixel height')
assert(page.controls.mcHeaderTabs:GetParent().Slot.Padding.Bottom==12,
    'the page header ends 12 pixels above its first entry')
-- Tabs keep their share but a longer label widens its own tab, keeping 3 pixels each side.
for n,tab in ipairs(headerRow.mcTabs) do
    assert(tab.widget.WidgetStyle.NormalPadding.Left==3 and tab.widget.WidgetStyle.NormalPadding.Right==3
        and headerTabs.children[2*n].MinDesiredWidth==110,'header tabs pad their labels by 3 pixels')
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
for n,bar in ipairs(headerRow.mcHeaderSeparators) do
    local bright=n==2 or n==3
    assert(#headerRow.mcHeaderSeparators==#items[1].values+1
        and (bar.BrushColor.A>0.5)==bright,
        'Only the separators beside the selected header tab may be bright')
end
for n,tab in ipairs(headerRow.mcTabs) do
    assert((tab.glow.BrushColor.A>0)==(n==2) and tab.widget:GetParent()==tab.glow,
        'Only the selected header tab may glow')
end
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

-- mcText shows a source's text in a scrollable area across the row, newest at the bottom.
items[1].values,items[1].labels={0,1},{'Errors','Errors'}
assert(not pcall(M.parse,'[Setting.Primary]\nId=Primary\nmcText=errors\n',items),'mcText requires a read-only row')
assert(not pcall(M.parse,'[Setting.Primary]\nId=Primary\nmcReadOnly=1\nmcText=bad name\n',items))
M.parse('[Setting.Primary]\nId=Primary\nmcReadOnly=1\nmcText=errors\n',items)
local textPage=controls.build(widget(),{{choices=items}},api)
textPage:show(1)
local textRow=textPage.panels[1].rows[1]
local area=assert(textRow.mcText,'an mcText row gets a text area')
assert(area.scroll.children[1]==area.label and area.label.AutoWrapText and area.label.Font.Size==12
    and area.scroll:GetParent().HeightOverride==360 and textRow.wrapper.HeightOverride==376
    and textRow.mcLabel.visible==1 and not textRow.mcTabs,'the area replaces the row label and value')
local noClick=function() return false,false,false end
textPage:tick({},noClick,false)
assert(area.label.text=='None' and area.scroll.scrolledToEnd==1 and textPolls==1,'the first tick shows the source')
textPage:tick({},noClick,false)
assert(textPolls==1,'the source is polled at most once a second')
textLines,textChanged={'first error','second error'},true;area.polled=nil
textPage:tick({},noClick,false)
assert(area.label.text=='first error\nsecond error' and area.scroll.scrolledToEnd==2,
    'new lines show at the bottom, scrolled into view')
textChanged=false;area.polled=nil
textPage:tick({},noClick,false)
assert(textPolls==3 and area.scroll.scrolledToEnd==2,'unchanged text keeps the reader where they scrolled')
textRow.visible=false;area.polled=nil
textPage:tick({},noClick,false)
assert(textPolls==3,'a hidden text area is not polled')
M.parse('[Setting.Primary]\nId=Primary\nmcReadOnly=1\nmcText=missing\n',items)
local unavailable=controls.build(widget(),{{choices=items}},api)
unavailable:show(1);unavailable:tick({},noClick,false)
assert(unavailable.panels[1].rows[1].mcText.label.text=='Unavailable.','an unknown source says so')
M.parse('[Setting.Primary]\nId=Primary\nmcReadOnly=1\n',items)
assert(items[1].mcText==nil,'a reparse without mcText clears it')
print('PASS mcText shows a source in a scrollable area, newest at the bottom')

-- mcTable shows static code and text pairs in columns filled top to bottom, every line
-- the same height and every code the same width.
local function tableManifest(fields) return '[Setting.Primary]\nId=Primary\n'..fields..'\n' end
assert(not pcall(M.parse,tableManifest('mcTable=A:a'),items),'mcTable requires a read-only row')
assert(not pcall(M.parse,tableManifest('mcReadOnly=1\nmcColumns=2'),items),'mcColumns requires mcTable')
for _,other in ipairs({'mcText=errors','mcWrap=1','mcType=tab'}) do
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
    assert(row.mcLabel.Font.Size==16 and row.mcLabel.color=='muted'
        and row.widget:GetContent().Slot.Padding.Left==0
        and row.widget.WidgetStyle.NormalPadding.Left==0
        and row.widget.WidgetStyle.PressedPadding.Left==0
        and row.wrapper.Slot.Padding.Top==12 and row.wrapper.Slot.Padding.Bottom==4,
        'Rows before the first visible category must match its label style and spacing')
end
local after=initial.panels[1].rows[3]
assert(after.mcLabel.Font.Size==14 and after.mcLabel.color=='body'
    and after.widget:GetContent().Slot.Padding.Left==36
    and after.widget.WidgetStyle.NormalPadding.Left==0
    and after.wrapper.Slot.Padding.Top==0 and after.wrapper.Slot.Padding.Bottom==0,
    'Rows after the first category must keep the stock child style')
items[2].mcGroup.heading=true
initial:refresh()
local second=initial.panels[1].rows[2]
assert(second.mcLabel.Font.Size==14 and second.mcLabel.color=='body'
    and second.widget:GetContent().Slot.Padding.Left==36
    and second.widget.WidgetStyle.NormalPadding.Left==0
    and second.wrapper.Slot.Padding.Top==0 and second.wrapper.Slot.Padding.Bottom==0,
    'Showing an earlier category must restore the normal child style')
-- A field-type editor row is built on DMM's toggle row and indents like one,
-- not once on its content and again on its label.
items[4]={id='Entry4',kind='extension',group='After',label='Entry 4',values={0,1},labels={'Off','On'}}
local editorRows=controls.build(widget(),{{choices=items}},api)
editorRows:show(1)
local editorRow=editorRows.panels[1].rows[4]
assert(editorRow.widget:GetContent().Slot.Padding.Left==36 and editorRow.mcLabel.Slot.Padding.Left==0,
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
    assert(heading.mcLabel.Font.Size==16 and heading.mcLabel.color=='muted'
        and heading.widget:GetContent().Slot.Padding.Left==0
        and heading.wrapper.Slot.Padding.Top==12,'the category row looks like a category heading')
    for i=2,3 do
        local row=built.panels[1].rows[i]
        assert(row.mcLabel.Font.Size==14 and row.mcLabel.color=='body'
            and row.widget:GetContent().Slot.Padding.Left==36,'rows indent beneath the category row')
    end
    -- The dirty star follows the label text in a box that replaces the label, so an
    -- unindented label never sits under it.
    local line=heading.mcLabel:GetParent()
    assert(line==heading.widget:GetContent() and line.children[1]==heading.mcLabel
        and line.children[2]==heading.mcStar and heading.mcStar.text=='*' and heading.mcStar.visible==2
        and heading.mcLabel.Slot.Padding.Left==0 and heading.mcLabel.Slot.Size.SizeRule==0
        and heading.mcStar.Slot.Padding.Left==4 and heading.mcStar.Slot.Padding.Right==8
        and heading.mcStar.Font.Size==16,'the star follows the category row label, in its font')
    local toggleRow=built.panels[1].rows[2]
    local toggleLine=toggleRow.mcLabel:GetParent()
    assert(toggleLine.children[2]==toggleRow.mcStar and toggleRow.mcStar.Font.Size==14
        and toggleRow.widget:GetContent().children[1]:GetContent()==toggleLine,
        'a toggle row star follows its label inside the label box')
    function built.model:visibility() return {false,true,true} end
    built:refresh()
    local row=built.panels[1].rows[2]
    assert(row.mcLabel.Font.Size==16 and row.widget:GetContent().Slot.Padding.Left==0,
        'a hidden category row indents nothing')
    assert(not pcall(M.parse,'[Setting.Visual1]\nId=Visual1\nmcCategory=1\nmcLevel=2\n',list),
        'mcCategory excludes mcLevel')
    for i=1,3 do items[i]=saved[i] end
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
assert(cycleSlot.HorizontalAlignment==1 and cycleSlot.Padding.Left==20+16+408,
    'it sits in the key column, after the row indent')
cycleButton.widget.clicked=true
cycling:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(cycling.model.pending[1]==1 and cycleButton.label.text=='Abilities','a click moves to the next choice and wraps')
print('PASS cycle pickers show one choice in the key column and advance on click')

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
assert(noteRow.mcNote.Font.Size==11 and noteRow.mcNote.color=='muted','the note is small and muted')
assert(#noteRow.parts==3 and noteRow.value.parent~=noteBox,'DMM\'s value keeps its place')
-- None has no note: one line, as today.
assert(noteBox.visible==1 and noteRow.value.Slot.Padding.Bottom==0)
noteUi.model.pending[1]=7;noteUi:refresh()
assert(noteBox.visible==3 and noteRow.mcNote.text=='Fangdango' and noteRow.value.Slot.Padding.Bottom==4
    and noteBox.Slot.Padding.Bottom==4,
    'a noted choice shows its note without taking clicks, and the value moves up')
noteUi.model.pending[1]=0;noteUi:refresh()
assert(noteBox.visible==1 and noteRow.value.Slot.Padding.Bottom==0,'back to one line')
-- A tab picker shows every choice itself and gets no note line.
M.parse(notes..'mcType=tab\n',items)
local tabUi=controls.build(widget(),{{choices=items}},api)
tabUi:show(1)
assert(tabUi.panels[1].rows[1].mcNote==nil,'tab pickers are not covered')
print('PASS picker choice notes show on a second line under the value')

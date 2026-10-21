package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Range=require('range_editor')
local FieldTypes=require('field_types')

-- Declaration: numbers, steps and delta limits in steps.
local s=Range.declare({Min='0',Max='100',Step='5',DeltaMin='20',Suffix='%'})
assert(s.minimum==0 and s.maximum==100 and s.step==5 and s.count==20 and s.deltaMin==4 and s.deltaMax==20
    and s.suffix=='%','limits are kept in steps; DeltaMax defaults to Max-Min')
local plain=Range.declare({Min='1',Max='3'})
assert(plain.step==1 and plain.count==2 and plain.deltaMin==0 and plain.deltaMax==2 and plain.suffix=='')
local fine=Range.declare({Min='0',Max='1',Step='0.25'})
assert(fine.count==4)
for _,fields in ipairs({{Min='5',Max='5'},{Min='a',Max='1'},{Max='1'},{Min='0',Max='10',Step='3'},
    {Min='0',Max='10',Step='0'},{Min='0',Max='100',Step='1'},{Min='0',Max='10',DeltaMin='11'},
    {Min='0',Max='10',DeltaMin='5',DeltaMax='4'},{Min='0',Max='10',Step='2',DeltaMin='3'},
    {Min='0',Max='10',Suffix='a|b'},{Min='0',Max='10',Suffix='123456789'}}) do
    assert(not pcall(Range.declare,fields),'rejected declaration')
end
assert(pcall(Range.declare,{Min='0',Max='40'}),'forty steps are allowed')
print('PASS range declarations are checked and kept in steps')

-- Values: '<low>|<high>' on steps, inside Min and Max, with high-low inside the delta limits.
for raw,expected in pairs({['70|90']='70|90',[' 70 | 100 ']='70|100',['70.0|90']='70|90',['0|20']='0|20',
    ['80|100']='80|100',['0|100']='0|100'}) do
    assert(Range.normalize(s,raw)==expected,raw)
end
for _,raw in ipairs({'70|80','72|92','90|70','-5|20','90|105','70','70|','a|b','70|90|100',''}) do
    assert(Range.normalize(s,raw)==nil,raw)
end
assert(Range.normalize(s,nil)==nil and Range.normalize(s,70)==nil)
assert(Range.valid(s,'70|90') and not Range.valid(s,' 70|90') and not Range.valid(s,'70|80'))
assert(Range.normalize(fine,'0.25|0.75')=='0.25|0.75' and Range.normalize(fine,'.5|1.00')=='0.5|1'
    and Range.normalize(fine,'0.3|1')==nil)
assert(Range.format(s,'70|90')=='70% - 90%' and Range.format(plain,'1|3')=='1 - 3' and Range.format(s,'x')=='')
print('PASS range values are <low>|<high> on steps within the limits')

-- LowMax and HighMin give each marker its own zone: here low 0-40 and high 60-100.
local zones=Range.declare({Min='0',Max='100',Step='10',LowMax='40',HighMin='60'})
assert(zones.lowMax==4 and zones.highMin==6 and plain.lowMax==2 and plain.highMin==0,'stops in steps; defaults Max and Min')
assert(Range.normalize(zones,'40|60')=='40|60' and Range.normalize(zones,'0|100')=='0|100'
    and Range.normalize(zones,'50|60')==nil and Range.normalize(zones,'40|50')==nil,'values stay in their zones')
assert(table.concat({Range.move(zones,4,6,1,1)},',')=='' and table.concat({Range.move(zones,4,6,2,-1)},',')==''
    and table.concat({Range.move(zones,4,6,1,-1)},',')=='3,6','markers stop at LowMax and HighMin')
assert(table.concat({Range.place(zones,2,8,1,9)},',')=='4,8' and table.concat({Range.place(zones,2,8,2,0)},',')=='2,6',
    'a press beyond a zone stops at its edge')
for _,fields in ipairs({{Min='0',Max='100',Step='10',LowMax='105'},{Min='0',Max='100',Step='10',HighMin='15'},
    {Min='0',Max='100',Step='10',LowMax='40',HighMin='60',DeltaMax='10'}}) do
    assert(not pcall(Range.declare,fields),'rejected stops')
end
print('PASS LowMax and HighMin bound each marker')

-- Moving and placing markers stops at Min, Max and the delta limits.
local function moved(low,high,marker,direction) return table.concat({Range.move(s,low,high,marker,direction)},',') end
assert(moved(14,18,1,-1)=='13,18' and moved(14,18,1,1)=='' and moved(14,18,2,1)=='14,19' and moved(14,18,2,-1)=='',
    'DeltaMin=20 stops 70-90 from narrowing')
assert(moved(0,20,1,-1)=='' and moved(16,20,2,1)=='','Min and Max stop the markers')
local capped=Range.declare({Min='0',Max='10',DeltaMax='4'})
assert(table.concat({Range.move(capped,2,6,1,-1)},',')=='' and table.concat({Range.move(capped,2,6,2,1)},',')=='',
    'DeltaMax stops widening')
assert(table.concat({Range.place(s,14,18,1,17)},',')=='14,18' and table.concat({Range.place(s,14,18,1,3)},',')=='3,18'
    and table.concat({Range.place(s,14,18,2,15)},',')=='14,18' and table.concat({Range.place(s,14,18,2,25)},',')=='14,20')
assert(table.concat({Range.place(capped,2,6,1,0)},',')=='2,6' and table.concat({Range.place(capped,2,6,2,10)},',')=='2,6')
assert(Range.nearer(4,10,2)==1 and Range.nearer(4,10,12)==2 and Range.nearer(4,10,5)==1 and Range.nearer(4,10,9)==2
    and Range.nearer(4,10,7)==1 and Range.nearer(4,10,7,2)==2 and Range.nearer(4,10,4)==1 and Range.nearer(4,10,10)==2,
    'a press takes the marker at or beyond it, else the nearer; a tie goes to the highlighted one')
print('PASS markers stop at Min, Max, DeltaMin and DeltaMax')

-- Keys: Left/Right highlight; Enter grabs and lets go; a grabbed marker moves.
local state=Range.state(s)
assert(state:step('70|90',1)==nil and state.highlighted==2 and not state.grabbed and state:hint()=='ADJUST',
    'Right highlights the high marker')
assert(state:step('70|90',-1)==nil and state.highlighted==1,'Left highlights the low marker')
state:confirm()
assert(state.grabbed and state.highlighted==1 and state:hint()=='DONE','Enter grabs the highlighted marker')
assert(state:step('70|90',-1)=='65|90' and state:step('70|90',1)==nil,'a grabbed marker moves; DeltaMin stops it')
state:confirm()
assert(not state.grabbed and state.highlighted==1,'Enter lets go and keeps the highlight')
assert(state:step('70|90',1)==nil and state.highlighted==2)
state:leave()
assert(state.highlighted==nil and not state.grabbed)
state:confirm()
assert(state.grabbed and state.highlighted==1,'Enter with nothing highlighted grabs the low marker')
print('PASS Left/Right highlight a marker, Enter grabs and lets go')

-- The row: UMG stand-ins record what the editor does.
local function widget(kind)
    local w={kind=kind,children={},visibility=0,enabled=true,text=''}
    function w:IsValid() return true end
    local function slot(child)
        local sl={}
        function sl:SetHorizontalAlignment(v) self.h=v end
        function sl:SetVerticalAlignment(v) self.v=v end
        function sl:SetPadding(v) self.padding=v end
        function sl:SetSize() end
        child.slot=sl
        return sl
    end
    function w:SetContent(child) self.content=child;child.parent=self;return slot(child) end
    function w:GetContent() return self.content end
    function w:AddChild(child) self.children[#self.children+1]=child;child.parent=self;return slot(child) end
    w.AddChildToOverlay=w.AddChild
    function w:GetChildAt(i) return self.children[i+1] end
    function w:SetWidthOverride(v) self.width=v end
    function w:SetHeightOverride(v) self.height=v end
    function w:SetBrushColor(c) self.brush=c end
    function w:IsHovered() return self.hovered==true end
    function w:SetRenderOpacity(v) self.opacity=v end
    function w:SetPadding(v) self.ownPadding=v end
    for _,name in ipairs({'SetJustification','SetClickMethod','SetBackgroundColor'}) do
        w[name]=function() end
    end
    return w
end
local api={construct=function(path) return widget(path:match('UMG%.(.+)$')) end,
    need=function(value,label) assert(value,label);return value end}
local function toggleRow()
    local button,content=widget('Button'),widget('HorizontalBox')
    button:SetContent(content)
    local labelBox,valueBox,value=widget('SizeBox'),widget('SizeBox'),widget('TextBlock')
    content:AddChild(labelBox);content:AddChild(valueBox);valueBox:SetContent(value)
    return {widget=button,value=value}
end
local small=Range.declare({Min='0',Max='4',DeltaMin='1'})
local row=toggleRow()
local instance=Range.build(row,small,{api=api,tree={}})
local L=Range.layout
local content=row.widget:GetContent()
assert(content:GetChildAt(0).width==L.label and content:GetChildAt(1).width==L.value)
local hostBox=content:GetChildAt(1):GetContent()
local host=hostBox.content
assert(hostBox.width==L.control and host.children[1]==row.value,'DMM\'s caption sits in the control, above the line')
assert(row.value.slot.padding.Bottom==2*L.lift)
local track=host.children[2].content
local barBox,hits=track.children[1],track.children[2]
local bar=barBox.content
local strip=bar.children[1].content
local low,high=bar.children[2],bar.children[3]
assert(#hits.children==5,'a hit target per step')
local span=math.floor(L.control*L.share/2)*2
local cell=span/4
local widths=0
for _,box in ipairs(hits.children) do widths=widths+box.width end
assert(math.abs(widths-host.children[2].width)<1e-6,'the hit targets cover the track')
instance:set('1|3')
local function parts(a,b,c)
    local w={strip.children[1].width,strip.children[2].width,strip.children[3].width}
    return math.abs(w[1]-a)<1e-6 and math.abs(w[2]-b)<1e-6 and math.abs(w[3]-c)<1e-6
end
assert(parts(cell,2*cell,cell),'the line is lit across the span')
assert(strip.children[2].height==L.span and strip.children[1].height==L.rest,'the span is thicker')
local function centre(marker) return marker.slot.padding.Left+L.handle/2+L.contour end
assert(centre(low)==cell and centre(high)==3*cell,'handles sit on the span\'s ends')
assert(low.content.brush.A==0 and high.content.brush.A==0 and barBox.opacity==L.idle,'no contour; the line is dim at rest')
instance:focus(true)
assert(barBox.opacity==1,'a selected row lights its line')
assert(instance:step(1)==nil and high.content.brush.A==1 and high.content.brush.R==1,'a highlighted handle gets a white contour')
instance:confirm()
assert(low.opacity==L.dimmed and high.height==L.grabbed+2*L.contour,'a grabbed handle is raised; the other dims')
assert(instance:step(1)=='1|4')
instance:set('1|4')
assert(parts(cell,3*cell,0) and instance:step(1)==nil)
assert(instance.state.grabbed)
instance:focus(false)
assert(not instance.state.grabbed and instance.state.highlighted==nil and high.height==L.marker+2*L.contour
    and barBox.opacity==L.idle,'leaving the row lets go')
-- The mouse: a press takes the nearer marker; holding drags it.
local down=false
local function pointer() return down end
local function hover(n)
    for i,box in ipairs(hits.children) do box.content.hovered=i==n end
    track.hovered=n~=nil
end
hover(1)
assert(instance:tick(pointer)==nil,'hovering does nothing')
down=true
assert(instance:tick(pointer)=='0|4','a press on step 0 takes the low marker')
instance:set('0|4')
hover(4)
assert(instance:tick(pointer)=='3|4','holding drags it')
instance:set('3|4')
hover(5)
assert(instance:tick(pointer)==nil,'DeltaMin stops the drag')
down=false
assert(instance:tick(pointer)==nil and not instance.dragging)
hover(nil)
down=true
assert(instance:tick(pointer)==nil)
hover(2)
assert(instance:tick(pointer)==nil,'a button held when the pointer arrives is not a press')
print('PASS the range row draws its span and markers and follows keys and the mouse')

-- field_types: Left/Right reach the editor as steps, Enter/A as confirm, and the footer
-- hint follows the selected row.
do
    local registry=FieldTypes.new(function(event,detail) error(event..': '..tostring(detail)) end)
    registry:register('range',Range)
    local setting={id='R',kind='extension',editor='range',label='R',values={0,1,2}}
    for key,value in pairs(small) do setting[key]=value end
    assert(registry:merge('[Setting.R]\nId=R\nType=range\nMin=0\nMax=4\nDefault=1|3\n',{})[1].values[3]==2,
        'a navigation editor\'s shell has three positions')
    local choices
    choices={parse=function() return {} end,index=function() return 1 end,format=function() return '' end,
        open=function(provider)
            local model={items=provider.choices,pending={'1|3'},committed={'1|3'}}
            function model:set(i,value) if choices.index(self.items[i],value) then self.pending[i]=value end end
            function model:change() error('DMM change reached') end
            return model
        end}
    local nav={value=1}
    function nav:GetValue() return self.value end
    function nav:SetValue(v) self.value=v end
    local rowStub=toggleRow()
    rowStub.nav=nav
    local controls={build=function(_,providers)
        local ui={panels={{rows={rowStub}}}}
        function ui:show(index) self.panels[index].built=true;self.active=index;self.model=choices.open(providers[index]) end
        function ui:refresh() end
        function ui:tick() end
        function ui:hide() self.active=nil end
        return ui
    end}
    local presses,hints=0,{}
    local confirm={take=function(wants) local pressed=presses>0;presses=0;return pressed and wants end}
    local hint={show=function(text) hints[#hints+1]=text or 'hidden' end}
    registry:install({choices=choices,controls=controls,confirm=confirm,hint=hint,pointer=function() return false end})
    assert(choices.index(setting,'1|3')==2 and choices.index(setting,'1|1')==nil,'a valid value rests on the middle')
    local ui=controls.build({},{{id='P',testOnly=true,choices={setting}}},api)
    ui:show(1)
    local model=ui.model
    local instance=nil
    ui.current=1
    model:change(1,2)
    ui:tick()
    assert(hints[#hints]=='ADJUST','the hint shows while the row is selected')
    presses=1
    ui:tick()
    assert(hints[#hints]=='DONE','Enter grabs')
    model:change(1,2)
    ui:tick()
    assert(model.pending[1]=='1|4','Right moves the grabbed marker')
    nav.value=0
    model:set(1,0)
    ui:tick()
    assert(model.pending[1]=='1|3' and nav.value==1,'a native move left is a step; the shell returns to its middle')
    model:set(1,'0|2')
    assert(model.pending[1]=='0|2','text values still reach DMM\'s model')
    model:change(1,nil)
    ui:tick()
    assert(model.pending[1]=='0|2','a click without a direction is ignored')
    ui.current=nil
    ui:tick()
    assert(hints[#hints]=='hidden','the hint hides once the row is left')
    ui.current=1
    ui:tick()
    ui:hide()
    assert(hints[#hints]=='hidden','the hint hides with the page')
    instance=nil
end
print('PASS field types route Left/Right, Enter and the footer hint to navigation editors')

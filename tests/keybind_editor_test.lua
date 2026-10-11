package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Keybind=require('keybind_editor')

-- Minimal UMG stand-ins: each widget records what the editor does to it.
local function widget(kind)
    local w={kind=kind,children={},visibility=0,enabled=true,text=''}
    function w:IsValid() return true end
    local function slot(child)
        local s={}
        function s:SetHorizontalAlignment(v) self.h=v end
        function s:SetVerticalAlignment(v) self.v=v end
        function s:SetPadding(v) self.padding=v end
        function s:IsValid() return true end
        child.slot=s
        return s
    end
    function w:SetContent(child) self.content=child;child.parent=self;return slot(child) end
    function w:GetContent() return self.content end
    function w:AddChild(child) self.children[#self.children+1]=child;child.parent=self;return slot(child) end
    w.AddChildToOverlay=w.AddChild
    function w:GetChildAt(i) return self.children[i+1] end
    function w:SetVisibility(v) self.visibility=v end
    function w:SetIsEnabled(v) self.enabled=v end
    function w:GetIsEnabled() return self.enabled end
    function w:SetWidthOverride(v) self.width=v end
    function w:SetColorAndOpacity(c) self.color=c.SpecifiedColor end
    function w:SetRenderShear(v) self.shear=v.X end
    function w:SetRenderOpacity(v) self.opacity=v end
    function w:SetBrushColor(c) self.brush=c end
    function w:IsPressed() return self.pressed==true end
    function w:IsHovered() return self.hovered==true end
    function w:GetIsSelectingKey() return self.selecting==true end
    function w:SetSelectedKey(chord) self.SelectedKey=chord end
    for _,name in ipairs({'SetJustification','SetTextOverflowPolicy','SetFont','SetRenderTransformPivot','SetRenderScale',
        'SetBackgroundColor','SetHeightOverride','SetAllowGamepadKeys','SetAllowModifierKeys','SetEscapeKeys',
        'SetNoKeySpecifiedText'}) do w[name]=function() end end
    return w
end
FName=function(name) return {ToString=function() return name end} end
StaticFindObject=function() return {Conv_StringToText=function(_,s) return s end} end
local api={construct=function(path) return widget(path:match('UMG%.(.+)$')) end,
    need=function(value,label) assert(value,label);return value end,
    setText=function(w,copy) w.text=copy end,
    Theme={font=function(w,_,size) w.fontSize=size end},theme={}}

-- DMM's toggle row: a button holding label | value.
local function toggleRow()
    local button,content=widget('Button'),widget('HorizontalBox')
    button:SetContent(content)
    local labelBox,valueBox,value=widget('SizeBox'),widget('SizeBox'),widget('TextBlock')
    content:AddChild(labelBox);content:AddChild(valueBox);valueBox:SetContent(value)
    return {widget=button,value=value}
end
local function find(root,predicate)
    if predicate(root) then return root end
    for _,child in ipairs(root.children) do local hit=find(child,predicate);if hit then return hit end end
    if root.content then return find(root.content,predicate) end
end

-- Display names; stored values keep the engine key names.
for name,shown in pairs({LeftMouseButton='Left Button',RightMouseButton='Right Button',
    MiddleMouseButton='Middle Button',NumPadZero='NumPad 0',NumPadNine='NumPad 9',Seven='7',J='J'}) do
    assert(Keybind.displayName(name)==shown,name)
end
assert(Keybind.normalize(Keybind.declare({Triggers='Tap'}),'NumPadZero')=='NumPadZero|Tap')

local setting=Keybind.declare({Triggers='Tap|Hold',Optional='1',DefaultControl='IA_Combat_ToggleQuickslots'})
setting.id='Group'
local controls={resolve=function(id) assert(id=='IA_Combat_ToggleQuickslots');return {'LeftAlt'} end}
local row=toggleRow()
local editor=Keybind.build(row,setting,{api=api,tree={},modules={standardControls=controls}})
local valueBox=row.widget:GetContent():GetChildAt(1)
local selector=find(valueBox,function(w) return w.kind=='InputKeySelector' end)
local texts={}
local function collect(w) if w.kind=='TextBlock' then texts[#texts+1]=w end;for _,c in ipairs(w.children) do collect(c) end;if w.content then collect(w.content) end end
collect(valueBox)
local function shown(copy) for _,t in ipairs(texts) do if t.text==copy and t.visibility~=1 then return t end end end

-- Line: Mode, gap, key, gap, X. Mode and X backgrounds are at 30% of a standard control's.
local line=find(valueBox,function(w) return w.kind=='HorizontalBox' end)
assert(#line.children==5 and line.children[2].width==8 and line.children[4].width==8,
    'Mode and X are each 8 pixels from the key')
local function inner(box) return find(box,function(w) return w.kind=='Border' end) end
local modeText=find(line.children[1],function(w) return w.kind=='TextBlock' end)
local keyText=find(line.children[3],function(w) return w.kind=='TextBlock' end)
assert(line.children[1].width==66 and line.children[3].width==96,'Mode is 66 pixels wide')
assert(math.abs(inner(line.children[1]).brush.A-0.108)<1e-9
    and math.abs(inner(line.children[5]).brush.A-0.09)<1e-9,'Mode and X backgrounds are dimmed; Mode 20% stronger')
local clearText=find(line.children[5],function(w) return w.kind=='TextBlock' end)
assert(clearText.opacity==0.7,'X rests 30% dimmer')

-- Unbound with a default control: a small "default" at the top of the key box and
-- the default key flush with its bottom, at half strength; Mode and X hidden.
local function textOf(copy) return find(line.children[3],function(w) return w.kind=='TextBlock' and w.text==copy end) end
editor:set('none','none')
local defaultLabel,inheritedKey=assert(textOf('default')),assert(textOf('Left Alt'))
assert(defaultLabel.visibility==3 and inheritedKey.visibility==3 and keyText.visibility==1,
    'the default replaces the regular key text')
assert(defaultLabel.fontSize==9 and inheritedKey.fontSize==11 and keyText.fontSize==16,
    'default is 9pt, the default key 11pt, a regular key 16pt')
assert(defaultLabel.slot.v==1 and inheritedKey.slot.v==3 and inheritedKey.slot.padding.Bottom==0,
    'default sits at the top; the key is flush with the bottom')
assert(defaultLabel.color.A<1 and defaultLabel.color.R<1 and inheritedKey.color.R==1 and inheritedKey.color.A<1,
    'default is dim gray; the default key is dimmed white')
assert(inner(line.children[3]).brush.A==0.5,'the key box is at half strength')
assert(modeText.visibility==1 and inner(line.children[1]).visibility==1,'Mode is hidden while unbound')
assert(line.children[5].visibility==2,'X is hidden while unbound')
assert(editor:tick()==nil)
print('PASS an unbound key shows "default" over its default key')

-- Bound: the trigger, then the key in the active yellow at full strength, then X.
editor:set('LeftAlt|Hold','none')
assert(keyText.text=='Left Alt' and keyText.visibility~=1 and keyText.shear==0
    and defaultLabel.visibility==1 and inheritedKey.visibility==1)
assert(keyText.color.R>0.9 and keyText.color.B<0.2,'a bound key is yellow')
assert(inner(line.children[3]).brush.A==1,'a bound key is at full strength')
assert(modeText.text=='Hold' and inner(line.children[1]).visibility==0)
assert(line.children[5].visibility==0,'X shows for a bound optional key')
print('PASS a bound key shows its trigger, the key and X')

-- TriggerLabels changes only what Mode shows; values keep the trigger names.
do
    local labelled=Keybind.declare({Triggers='Hold|Tap',TriggerLabels='Hold|Toggle'})
    local labelledRow=toggleRow()
    local labelledEditor=Keybind.build(labelledRow,labelled,{api=api,tree={},modules={}})
    local labelledLine=find(labelledRow.widget:GetContent():GetChildAt(1),function(w) return w.kind=='HorizontalBox' end)
    local mode=find(labelledLine.children[1],function(w) return w.kind=='TextBlock' end)
    local button=find(labelledLine.children[1],function(w) return w.kind=='Button' end)
    labelledEditor:set('J|Tap','none')
    assert(mode.text=='Toggle','Tap shows as Toggle')
    assert(Keybind.normalize(labelled,'J|Toggle')==nil and Keybind.valid(labelled,'J|Tap'),'labels are never values')
    button.pressed=true;assert(labelledEditor:tick()==nil)
    button.pressed,button.hovered=false,true
    assert(labelledEditor:tick()=='J|Hold','Mode cycles the stored trigger names')
    labelledEditor:set('J|Hold','none')
    assert(mode.text=='Hold')
    for _,fields in ipairs({{Triggers='Hold|Tap',TriggerLabels='Toggle'},{Triggers='Tap',TriggerLabels=''}}) do
        assert(not pcall(Keybind.declare,fields),'one non-empty label per trigger')
    end
end
print('PASS trigger labels change what Mode shows, never the stored value')

-- A default that cannot be resolved yet is looked up again on the next render.
do
    local available=false
    local late={resolve=function() if available then return {'Q'} end;return nil,'key profile unavailable' end}
    local lateRow=toggleRow()
    local lateEditor=Keybind.build(lateRow,setting,{api=api,tree={},modules={standardControls=late}})
    lateEditor:set('none','none')
    local lateLine=find(lateRow.widget:GetContent():GetChildAt(1),function(w) return w.kind=='HorizontalBox' end)
    assert(not find(lateLine.children[3],function(w) return w.text=='Q' end))
    available=true
    lateEditor:set('J|Tap','none');lateEditor:set('none','none')
    assert(find(lateLine.children[3],function(w) return w.text=='Q' and w.visibility==3 end),
        'the default appears once the key profile is available')
    -- The page need not be edited: an open row retries from its tick.
    available=false
    local idleRow=toggleRow()
    local idleEditor=Keybind.build(idleRow,setting,{api=api,tree={},modules={standardControls=late}})
    idleEditor:set('none','none')
    local idleLine=find(idleRow.widget:GetContent():GetChildAt(1),function(w) return w.kind=='HorizontalBox' end)
    available=true
    assert(idleEditor:tick()==nil and find(idleLine.children[3],function(w) return w.text=='Q' and w.visibility==3 end),
        'an idle row shows the default once the key profile loads')
    -- A loaded profile that does not map the action is not asked again.
    local asked=0
    local unmapped={resolve=function() asked=asked+1;return nil,'standard control unavailable: IA_X' end}
    local unmappedEditor=Keybind.build(toggleRow(),setting,{api=api,tree={},modules={standardControls=unmapped}})
    unmappedEditor:set('none','none')
    local before=asked
    local time=os.time
    for second=1,5 do os.time=function() return time()+second end;unmappedEditor:tick() end
    os.time=time
    assert(before>=1 and asked==before,'an unmapped default control is not retried')
end
print('PASS a failed default lookup is retried')

-- Capturing a key keeps the current trigger.
selector.selecting=true
assert(editor:tick()==nil and shown('...'))
selector.selecting=false
selector.SelectedKey={Key={KeyName=FName('F')}}
assert(editor:tick()=='F|Hold')
-- Number keys are stored as their digit.
selector.selecting=true;editor:tick();selector.selecting=false
selector.SelectedKey={Key={KeyName=FName('One')}}
assert(editor:tick()=='1|Hold')
-- Escape or a modifier chord changes nothing.
selector.selecting=true;editor:tick();selector.selecting=false
selector.SelectedKey={Key={KeyName=FName('None')}}
assert(editor:tick()==nil and keyText.text=='Left Alt')
selector.selecting=true;editor:tick();selector.selecting=false
selector.SelectedKey={Key={KeyName=FName('G')},bCtrl=true}
assert(editor:tick()==nil)
print('PASS capture binds a new key and ignores Escape and chords')

-- Clicking the trigger cycles it; clicking X clears the key.
local buttons={}
local function collectButtons(w) if w.kind=='Button' then buttons[#buttons+1]=w end;for _,c in ipairs(w.children) do collectButtons(c) end;if w.content then collectButtons(w.content) end end
collectButtons(valueBox)
local trigger,key,clear=buttons[1],buttons[2],buttons[3]
assert(key.visibility==1,'the key box hit target gives way to the native capture widget')
-- A press dragged off the control and released there does nothing.
trigger.hovered=true;trigger.pressed=true;assert(editor:tick()==nil)
trigger.hovered=false;trigger.pressed=false;assert(editor:tick()==nil,'releasing off Mode cancels the click')
trigger.hovered=true;trigger.pressed=true;assert(editor:tick()==nil)
trigger.pressed=false;assert(editor:tick()=='LeftAlt|Tap')
trigger.hovered=false;editor:tick()
trigger.hovered=true;editor:tick();trigger.hovered=false;editor:tick()
assert(math.abs(inner(line.children[1]).brush.A-0.108)<1e-9,'hover ends on the dimmed Mode background')
editor:set('LeftAlt|Tap','none')
clear.hovered=true;editor:tick()
assert(clearText.opacity==1 and inner(line.children[5]).brush.R>0.9,'X lights up under the pointer')
clear.hovered=false;editor:tick()
assert(clearText.opacity==0.7 and math.abs(inner(line.children[5]).brush.A-0.09)<1e-9,'and dims again after')
clear.hovered=true;clear.pressed=true;editor:tick();clear.hovered=false;clear.pressed=false
assert(editor:tick()==nil,'releasing off X keeps the key')
clear.hovered=true;clear.pressed=true;editor:tick();clear.pressed=false
assert(editor:tick()=='none')
clear.hovered=false
print('PASS the trigger control cycles triggers and X clears the key')

-- Without a default control the placeholder is dim gray; without Optional it says Unbound.
local plain=Keybind.declare({Triggers='Hold',Optional='1'})
row=toggleRow();editor=Keybind.build(row,plain,{api=api,tree={},modules={}})
editor:set('none','none')
texts={};collect(row.widget:GetContent():GetChildAt(1))
placeholder=assert(shown('optional'))
assert(placeholder.color.R==placeholder.color.G and placeholder.color.R<1)
assert(placeholder.fontSize==14,'the optional placeholder is 2pt smaller than a key')
editor:set('J|Hold','none')
assert(placeholder.text=='J' and placeholder.fontSize==16,'a bound key returns to 16pt')
local required=Keybind.declare({Triggers='Tap'})
row=toggleRow();editor=Keybind.build(row,required,{api=api,tree={},modules={}})
editor:set('none','none')
texts={};collect(row.widget:GetContent():GetChildAt(1))
assert(shown('Unbound'))
print('PASS placeholders follow Optional and DefaultControl')

-- Conflict scope: rows sharing it must not bind the same key and trigger.
local scoped=Keybind.declare({Triggers='Tap|Hold',mcConflictScope='controls'})
assert(scoped.conflictScope=='controls' and Keybind.declare({}).conflictScope==nil)
assert(not pcall(Keybind.declare,{mcConflictScope='two words'}),'an invalid scope name fails the manifest')
assert(not pcall(Keybind.declare,{mcConflictScope=string.rep('a',65)}),'a scope name is at most 64 characters')
assert(Keybind.conflictKey(scoped,'J|Tap')==Keybind.conflictKey(scoped,'j|tap'),'keys and triggers ignore case')
assert(Keybind.conflictKey(scoped,'One|Tap')==Keybind.conflictKey(scoped,'1|Tap'),'digits compare as stored')
assert(Keybind.conflictKey(scoped,'J|Tap')~=Keybind.conflictKey(scoped,'J|Hold'),'Tap and Hold on one key do not collide')
assert(Keybind.conflictKey(scoped,'none')==nil and Keybind.conflictKey(scoped,'Escape')==nil,'unbound rows never collide')
row=toggleRow();editor=Keybind.build(row,scoped,{api=api,tree={},modules={}})
local scopedLine=find(row.widget:GetContent():GetChildAt(1),function(w) return w.kind=='HorizontalBox' end)
editor:set('J|Tap','J|Tap')
local normal=inner(scopedLine.children[3]).brush
editor:conflict(true)
local red=inner(scopedLine.children[3]).brush
assert(red.R>red.G*4 and red.A<1,'a colliding key has a dim red background')
editor:conflict(false)
assert(inner(scopedLine.children[3]).brush.R==normal.R and inner(scopedLine.children[3]).brush.A==normal.A,
    'clearing the collision restores the key background')
editor:conflict(true);editor:set('none','J|Tap')
assert(inner(scopedLine.children[3]).brush.R<0.2,'an unbound row is never red')
print('PASS colliding keys show a dim red background')

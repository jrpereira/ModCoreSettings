-- Runs in DMM's Lua state: the editor for Type=keybind settings (see field_types).
-- One setting, one text value: 'none' or '<FKey>|<trigger>', e.g. 'LeftAlt|Hold'.
-- The row shows the trigger control, the key box and an optional clear button;
-- while unbound, the key box shows the default control's keys.
--
-- Manifest fields: Triggers=Tap|Hold (the first is the default trigger),
-- TriggerLabels=Toggle|Hold (what the Mode control shows for each trigger, in order;
-- display only: the stored value keeps the trigger name),
-- Default=none|<FKey>|<FKey>|<trigger>, Optional=1, DefaultControl=IA_*,
-- mcConflictScope=<name> (rows on a page sharing it must not bind the same key and trigger).
local M={}
-- An unbound row retries its default keys once a second for at most this many seconds.
local DEFAULT_TRIES=30
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end
local function split(s)
    local out={};for part in ((s or '')..'|'):gmatch('(.-)|') do out[#out+1]=trim(part) end
    return out
end

local aliases={None='Unbound',SpaceBar='Space',BackSpace='Backspace',ThumbMouseButton='Mouse 4',
    ThumbMouseButton2='Mouse 5',LeftMouseButton='Left Button',RightMouseButton='Right Button',
    MiddleMouseButton='Middle Button',
    LeftShift='Left Shift',RightShift='Right Shift',LeftControl='Left Ctrl',RightControl='Right Ctrl',
    LeftAlt='Left Alt',RightAlt='Right Alt',LeftCommand='Left Win',RightCommand='Right Win'}
for digit,word in ipairs({'Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine'}) do
    aliases[word]=tostring(digit-1)
    aliases['NumPad'..word]='NumPad '..(digit-1)
end
local function displayName(name) return aliases[name] or name end
M.displayName=displayName

-- Number keys are stored as their digit: '1', not 'One'.
local digits={}
for digit,word in ipairs({'Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine'}) do
    digits[word:lower()]=tostring(digit-1)
end
local function keyName(name)
    if type(name)~='string' then return nil end
    if name:match('^%d$') then return name end
    if digits[name:lower()] then return digits[name:lower()] end
    return name:match('^%a[%w_]*$') and name~='None' and name~='Escape'
        and not name:find('^Gamepad_') and name or nil
end

function M.declare(fields)
    local triggers=split(fields.Triggers or 'Tap|Hold')
    local seen={}
    for _,name in ipairs(triggers) do
        assert(name:match('^%a+$') and not seen[name:lower()],'invalid or duplicate keybind trigger')
        seen[name:lower()]=true
    end
    assert(#triggers>=1 and #triggers<=4,'a keybind needs one to four triggers')
    local triggerLabels={}
    if fields.TriggerLabels~=nil then
        local labels=split(fields.TriggerLabels)
        assert(#labels==#triggers,'TriggerLabels needs one label per trigger')
        for n,label in ipairs(labels) do
            assert(label~='' and #label<=16,'invalid TriggerLabels entry')
            triggerLabels[triggers[n]]=label
        end
    end
    local optional=trim(fields.Optional)
    assert(optional=='' or optional=='0' or optional=='1','Optional must be 0 or 1')
    local control=trim(fields.DefaultControl)
    assert(control=='' or control:match('^[%w_]+$'),'invalid DefaultControl')
    local scope=trim(fields.mcConflictScope)
    assert(scope=='' or (#scope<=64 and scope:match('^[%w_]+$')),'invalid mcConflictScope')
    -- The first declared trigger is the default.
    return {triggers=triggers,defaultTrigger=triggers[1],triggerLabels=triggerLabels,optional=optional=='1',
        defaultControl=control~='' and control or nil,conflictScope=scope~='' and scope or nil}
end

-- Canonical text for a stored or declared value; nil when it is not valid.
function M.normalize(setting,raw)
    raw=trim(raw)
    if raw=='' or raw=='0' or raw:lower()=='none' then return 'none' end
    local key,trigger=raw:match('^([^|]+)|(.+)$')
    key=keyName(trim(key or raw))
    if not key then return nil end
    if not trigger then return key..'|'..setting.defaultTrigger end
    for _,name in ipairs(setting.triggers) do
        if name:lower()==trim(trigger):lower() then return key..'|'..name end
    end
end
function M.valid(setting,value) return type(value)=='string' and M.normalize(setting,value)==value end
function M.parts(value)
    if value=='none' then return nil,nil end
    return value:match('^([^|]+)|(.+)$')
end
-- The row's own value caption only carries DMM's dirty star.
function M.format() return '' end
-- What two rows in one conflict scope must not share: the key, ignoring case, and
-- the trigger. Unbound rows never collide.
function M.conflictKey(setting,value)
    local normalized=M.normalize(setting,value)
    local key,trigger=M.parts(normalized or 'none')
    if not key then return nil end
    return key:lower()..'|'..trigger:lower()
end

local placeholder={inherited={R=0.9,G=0.82,B=0.3,A=0.7},optional={R=0.6,G=0.6,B=0.6,A=0.7},
    key={R=1,G=1,B=1,A=1},none={R=1,G=1,B=1,A=0.45},
    -- A bound key uses the active tab yellow; an inherited one is dimmed.
    active={R=0.95,G=0.63,B=0.08,A=1},defaultCaption={R=0.6,G=0.6,B=0.6,A=0.7},
    defaultKey={R=1,G=1,B=1,A=0.75},
    -- A key that collides with another row in its conflict scope.
    conflict={R=0.55,G=0.08,B=0.06,A=0.6}}

-- Column widths of the editor row: label | Mode, gap, key, gap, X. Other rows
-- align with the key column through keyOffset, measured from the label's start.
M.layout={label=290,value=260,mode=66,gap=8,key=96,clear=28}
M.layout.keyOffset=M.layout.label+M.layout.mode+M.layout.gap

function M.build(row,setting,context)
    local layout=M.layout
    local api,tree=context.api,context.tree
    local function new(kind) return api.construct('/Script/UMG.'..kind,tree) end
    local function need(value,label) return api.need(value,label) end
    local function sized(widget,width,height)
        local box=new('SizeBox');box:SetWidthOverride(width);box:SetHeightOverride(height or 32)
        local slot=need(box:SetContent(widget),'keybind size content')
        slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
        return box
    end
    local function text(copy,scale,size)
        local block=new('TextBlock')
        block:SetJustification(1);block:SetTextOverflowPolicy(1)
        pcall(function() block:SetFont(row.value.Font) end)
        if size then pcall(function() api.Theme.font(block,api.theme,size);block:SetFont(block.Font) end) end
        if scale then pcall(function() block:SetRenderTransformPivot({X=0.5,Y=0.5});block:SetRenderScale({X=scale,Y=scale}) end) end
        api.setText(block,copy)
        return block
    end
    -- A framed control: background, text and a transparent hit button on top.
    -- dim scales the background's opacity for secondary controls.
    local function control(width,copy,dim)
        local overlay=new('Overlay')
        local inner=new('Border');inner:SetBrushColor({R=0.12,G=0.12,B=0.12,A=0.30*(dim or 1)})
        local label=text(copy,0.88)
        local slot=need(inner:SetContent(label),'keybind control text')
        slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(2)
        slot=need(overlay:AddChildToOverlay(inner),'keybind control background')
        slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
        local button=new('Button');button.IsFocusable=false
        pcall(function() button:SetBackgroundColor({R=0,G=0,B=0,A=0}) end)
        pcall(function() button:SetRenderOpacity(0) end)
        slot=need(overlay:AddChildToOverlay(button),'keybind control hit target')
        slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
        return {box=sized(overlay,width),inner=inner,text=label,button=button}
    end

    -- Make room on DMM's toggle row: label | editor.
    local content=need(row.widget:GetContent(),'keybind row content')
    local labelBox,valueBox=content:GetChildAt(0),content:GetChildAt(1)
    need(labelBox,'keybind label box'):SetWidthOverride(layout.label)
    need(valueBox,'keybind value box'):SetWidthOverride(layout.value)
    local host=new('Overlay')
    need(valueBox:SetContent(host),'keybind editor host')
    local caption=need(host:AddChildToOverlay(row.value),'keybind dirty caption')
    caption:SetHorizontalAlignment(3);caption:SetVerticalAlignment(2)
    row.value:SetJustification(2)
    local line=new('HorizontalBox')
    local lineSlot=need(host:AddChildToOverlay(line),'keybind editor line')
    lineSlot:SetHorizontalAlignment(1);lineSlot:SetVerticalAlignment(2)

    -- Mode | key | X. Mode and X are secondary: their backgrounds are at 30% of the
    -- standard control's. A bound key is at full strength, a default key at half.
    local secondary=0.30
    -- Mode's background is 20% stronger than X's; hover uses the active tab yellow.
    local modeDim=secondary*1.2
    local hoverColor={R=0.95,G=0.63,B=0.08,A=0.22}
    local base={R=0.12,G=0.12,B=0.12}
    local function shade(alpha) return {R=base.R,G=base.G,B=base.B,A=alpha} end
    -- What the Mode control shows for a trigger; the value keeps the trigger name.
    local function triggerLabel(name) return setting.triggerLabels and setting.triggerLabels[name] or name end
    local trigger=control(layout.mode,triggerLabel(setting.defaultTrigger),modeDim)
    need(line:AddChild(trigger.box),'keybind trigger')
    local gap=new('SizeBox');gap:SetWidthOverride(layout.gap);need(line:AddChild(gap),'keybind gap')
    local key=control(layout.key,'')
    -- Keys are 16pt before the box's 0.84 scale; the "optional" placeholder is 14pt.
    local keySize
    local function sizeKey(size)
        if keySize==size then return end
        keySize=size
        pcall(function() api.Theme.font(key.text,api.theme,size);key.text:SetFont(key.text.Font) end)
    end
    sizeKey(16)
    pcall(function() key.text:SetRenderTransformPivot({X=0.5,Y=0.5});key.text:SetRenderScale({X=0.84,Y=0.84}) end)
    need(line:AddChild(key.box),'keybind key')
    -- An inherited key shows inside the key box: a small "default" at the top and
    -- the key flush with the bottom. They may overlap.
    local defaultLabel=text('default',nil,9)
    local inheritedKey=text('',nil,11)
    pcall(function() defaultLabel:SetColorAndOpacity({SpecifiedColor=placeholder.defaultCaption,ColorUseRule=0}) end)
    pcall(function() inheritedKey:SetColorAndOpacity({SpecifiedColor=placeholder.defaultKey,ColorUseRule=0}) end)
    local keyLayers=key.box:GetContent()
    local labelSlot=need(keyLayers:AddChildToOverlay(defaultLabel),'keybind default label')
    labelSlot:SetHorizontalAlignment(0);labelSlot:SetVerticalAlignment(1)
    local inheritedSlot=need(keyLayers:AddChildToOverlay(inheritedKey),'keybind default key')
    inheritedSlot:SetHorizontalAlignment(0);inheritedSlot:SetVerticalAlignment(3)
    inheritedSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
    local inherited={defaultLabel,inheritedKey}
    local function showInherited(shown)
        for _,block in ipairs(inherited) do block:SetVisibility(shown and 3 or 1) end
    end
    showInherited(false)
    -- The native capture widget sits invisibly over the key box.
    local selector=new('InputKeySelector')
    selector:SetAllowGamepadKeys(false);selector:SetAllowModifierKeys(true)
    selector:SetEscapeKeys({{KeyName=FName('Escape')}})
    pcall(function()
        selector:SetNoKeySpecifiedText(StaticFindObject('/Script/Engine.Default__KismetTextLibrary'):Conv_StringToText(''))
    end)
    selector:SetRenderOpacity(0)
    local keyOverlay=key.box:GetContent()
    local slot=need(keyOverlay:AddChildToOverlay(selector),'keybind capture')
    slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
    key.button:SetVisibility(1)
    local clearGap=new('SizeBox');clearGap:SetWidthOverride(layout.gap);need(line:AddChild(clearGap),'keybind clear gap')
    local clear=control(layout.clear,'X',secondary)
    pcall(function() clear.text:SetColorAndOpacity({SpecifiedColor={R=1,G=0.24,B=0.18,A=1},ColorUseRule=0}) end)
    -- X rests 30% dimmer and lights up under the pointer.
    clear.text:SetRenderOpacity(0.7)
    need(line:AddChild(clear.box),'keybind clear')

    local instance={setting=setting,value=nil}
    local function chord(name) return {Key={KeyName=FName(name)},bShift=false,bCtrl=false,bAlt=false,bCmd=false} end
    local function selected()
        local ok,name,modified=pcall(function()
            local chosen=selector.SelectedKey
            local value=chosen.Key.KeyName:ToString()
            return value,chosen.bShift==true or chosen.bCtrl==true or chosen.bAlt==true or chosen.bCmd==true
        end)
        if ok then return name,modified end
    end
    -- Only a resolved default is kept: the key profile may not exist yet when the
    -- row is first shown, so a failed lookup is tried again on each render and,
    -- while it stays unresolved, from tick.
    local function defaultKeys()
        if instance.defaults==nil then
            local controls=context.modules.standardControls
            if setting.defaultControl and controls then
                local ok,names,why=pcall(controls.resolve,setting.defaultControl)
                -- A loaded profile that does not map the action will not start to.
                if ok and names==nil and tostring(why):find('^standard control unavailable') then
                    instance.defaultTries=DEFAULT_TRIES
                end
                if ok and type(names)=='table' and #names>0 then
                    local shown={}
                    for _,name in ipairs(names) do shown[#shown+1]=displayName(name) end
                    instance.defaults=table.concat(shown,', ')
                end
            end
        end
        return instance.defaults
    end
    local function style(widget,state)
        pcall(function() widget:SetColorAndOpacity({SpecifiedColor=placeholder[state],ColorUseRule=0}) end)
        pcall(function() widget:SetRenderShear({X=(state=='inherited' or state=='optional') and -12 or 0,Y=0}) end)
    end
    local function render()
        local bound,mode=M.parts(instance.value)
        local defaults=not bound and not instance.selecting and defaultKeys()
        if instance.selecting then api.setText(key.text,'...');style(key.text,'key')
        elseif bound then api.setText(key.text,displayName(bound));style(key.text,'active')
        elseif setting.optional then
            api.setText(key.text,'optional');style(key.text,setting.defaultControl and 'inherited' or 'optional')
        else api.setText(key.text,'Unbound');style(key.text,'none') end
        sizeKey((not bound and not instance.selecting and not defaults and setting.optional) and 14 or 16)
        key.text:SetVisibility(defaults and 1 or 3)
        showInherited(defaults and true or false)
        if defaults then api.setText(inheritedKey,defaults) end
        key.inner:SetBrushColor(instance.conflicted and bound and not instance.selecting and placeholder.conflict
            or shade((bound or instance.selecting) and 1 or defaults and 0.5 or 0.30))
        clear.box:SetVisibility(setting.optional and bound and 0 or 2)
        clear.button:SetIsEnabled(bound~=nil)
        local fixed=#setting.triggers==1
        trigger.inner:SetVisibility(bound and 0 or 1)
        trigger.text:SetVisibility(bound and 0 or 1)
        if bound then api.setText(trigger.text,triggerLabel(mode)) end
        trigger.text:SetRenderOpacity(fixed and 0.45 or 1)
        trigger.button:SetIsEnabled(bound~=nil and not fixed)
    end
    -- A press fires on release over the button; dragging off and releasing cancels it.
    local function clicked(button,state)
        local pressed=button:GetIsEnabled() and button:IsPressed()==true
        local fired=instance[state] and not pressed and button:IsHovered()==true
        instance[state]=pressed
        return fired
    end

    -- Setter: DMM's model value into the controls.
    function instance:set(value)
        if value==self.value then return end
        self.value=value
        pcall(function() selector:SetSelectedKey(chord('None')) end)
        render()
    end
    -- Marks the key as colliding with another row in its conflict scope.
    function instance:conflict(on)
        on=on==true
        if on==self.conflicted then return end
        self.conflicted=on
        if self.value~=nil then render() end
    end
    -- Getter: a finished edit as the new value, or nil.
    function instance:tick()
        if self.value==nil then return nil end
        local bound,mode=M.parts(self.value)
        local selecting=selector:GetIsSelectingKey()==true
        if selecting then
            if not self.selecting then self.selecting=true;render() end
            return nil
        end
        if self.selecting then
            self.selecting=false
            local name,modified=selected()
            pcall(function() selector:SetSelectedKey(chord('None')) end)
            render()
            name=keyName(name)
            if name and not modified then return name..'|'..(mode or setting.defaultTrigger) end
            return nil
        end
        -- A key profile that loads after the row was drawn still shows the default
        -- keys: retry once a second, for at most 30 seconds of an open page.
        if not bound and setting.defaultControl and self.defaults==nil and (self.defaultTries or 0)<DEFAULT_TRIES then
            local now=os.time()
            if now~=self.defaultTried then
                self.defaultTried=now;self.defaultTries=(self.defaultTries or 0)+1
                if defaultKeys() then render() end
            end
        end
        local hovered=trigger.button:IsHovered()==true
        if hovered~=self.hovered then
            self.hovered=hovered
            trigger.inner:SetBrushColor(hovered and hoverColor or shade(0.30*modeDim))
        end
        local clearHovered=clear.button:GetIsEnabled() and clear.button:IsHovered()==true
        if clearHovered~=self.clearHovered then
            self.clearHovered=clearHovered
            clear.inner:SetBrushColor(clearHovered and hoverColor or shade(0.30*secondary))
            clear.text:SetRenderOpacity(clearHovered and 1 or 0.7)
        end
        if clicked(clear.button,'clearPressed') and bound then return 'none' end
        if clicked(trigger.button,'triggerPressed') and bound then
            for n,name in ipairs(setting.triggers) do
                if name==mode then return bound..'|'..setting.triggers[n%#setting.triggers+1] end
            end
        end
        return nil
    end
    return instance
end

return M

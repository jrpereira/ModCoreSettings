-- Runs in DMM's Lua state: the editor for Type=range settings (see field_types).
-- One setting, one text value: '<low>|<high>', e.g. '70|90'. The row shows a track of
-- steps with the chosen span filled and a marker at each end, and the span as its caption.
--
-- Manifest fields: Min=, Max= (required), Step= (default 1; it divides Max-Min into at
-- most MAX_STEPS steps), DeltaMin= and DeltaMax= (the smallest and largest high-low,
-- multiples of Step; defaults 0 and Max-Min), LowMax= (the highest the low marker goes;
-- default Max), HighMin= (the lowest the high marker goes; default Min), Suffix= (shown
-- after each number, e.g. %), Default=<low>|<high>.
--
-- Keys: Left/Right highlight the low or high marker; Enter (controller: A) grabs it, and
-- then Left/Right move it a step, stopping at its own limits and at DeltaMin and DeltaMax;
-- Enter lets go.
-- Leaving the row lets go and clears the highlight. The mouse moves the nearer marker to
-- the step it is pressed on, and drags it while held.
local M={navigation=true}
-- How to use the control, shown above the row's description: Enter to grab is not obvious.
M.help='Press Left/Right to select an end, Enter (A) to grab it, Left/Right to move it, and Enter (A) to let go.'
M.MAX_STEPS=40
-- Values are compared in steps; a stored number may be this far off a step.
local EPSILON=1e-6
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end

-- A number as the value and caption show it: no trailing zeros, no exponent.
local function number(x)
    local text=string.format('%.6f',x):gsub('0+$',''):gsub('%.$','')
    return text=='-0' and '0' or text
end
M.number=number

-- Whole steps from Min to x, or nil when x is not on a step.
local function steps(x,from,step)
    local n=(x-from)/step
    local whole=math.floor(n+0.5)
    if math.abs(n-whole)>EPSILON then return nil end
    return whole
end

function M.declare(fields)
    local low,high=tonumber(trim(fields.Min)),tonumber(trim(fields.Max))
    assert(low and high and low<high,'a range needs numbers Min < Max')
    local step=fields.Step==nil and 1 or tonumber(trim(fields.Step))
    assert(step and step>0,'invalid range Step')
    local count=steps(high,low,step)
    assert(count and count>=1 and count<=M.MAX_STEPS,'range Step must divide Max-Min into 1 to '..M.MAX_STEPS..' steps')
    local function delta(raw,default,name)
        if raw==nil or trim(raw)=='' then return default end
        local value=tonumber(trim(raw))
        local n=value and steps(value,0,step)
        assert(n and n>=0 and n<=count,'range '..name..' must be a multiple of Step from 0 to Max-Min')
        return n
    end
    local deltaMin,deltaMax=delta(fields.DeltaMin,0,'DeltaMin'),delta(fields.DeltaMax,count,'DeltaMax')
    assert(deltaMin<=deltaMax,'range DeltaMin must not exceed DeltaMax')
    local function stop(raw,default,name)
        if raw==nil or trim(raw)=='' then return default end
        local value=tonumber(trim(raw))
        local n=value and steps(value,low,step)
        assert(n and n>=0 and n<=count,'range '..name..' must be a step from Min to Max')
        return n
    end
    local lowMax,highMin=stop(fields.LowMax,count,'LowMax'),stop(fields.HighMin,0,'HighMin')
    -- The closest the markers can be is HighMin-LowMax apart, when the zones are separate.
    assert(math.max(0,highMin-lowMax)<=deltaMax,'range LowMax, HighMin and DeltaMax leave no value')
    local suffix=fields.Suffix or ''
    assert(#suffix<=8 and not suffix:find('[|%c]'),'invalid range Suffix')
    return {minimum=low,maximum=high,step=step,count=count,deltaMin=deltaMin,deltaMax=deltaMax,
        lowMax=lowMax,highMin=highMin,suffix=suffix}
end

-- The value in steps: low and high from Min, or nil when the value is invalid.
function M.parts(setting,value)
    if type(value)~='string' then return nil end
    local a,b=value:match('^%s*([^|]-)%s*|%s*([^|]-)%s*$')
    a,b=tonumber(a),tonumber(b)
    if not a or not b then return nil end
    local low,high=steps(a,setting.minimum,setting.step),steps(b,setting.minimum,setting.step)
    if not low or not high or low<0 or high>setting.count then return nil end
    if low>(setting.lowMax or setting.count) or high<(setting.highMin or 0) then return nil end
    local span=high-low
    if span<setting.deltaMin or span>setting.deltaMax then return nil end
    return low,high
end
-- The canonical value for low and high in steps.
function M.value(setting,low,high)
    return number(setting.minimum+low*setting.step)..'|'..number(setting.minimum+high*setting.step)
end

function M.normalize(setting,raw)
    local low,high=M.parts(setting,raw)
    return low and M.value(setting,low,high) or nil
end
function M.valid(setting,value) return type(value)=='string' and M.normalize(setting,value)==value end
function M.format(setting,value)
    local low,high=M.parts(setting,value)
    if not low then return '' end
    local function show(n) return number(setting.minimum+n*setting.step)..setting.suffix end
    return show(low)..' - '..show(high)
end

-- One marker (1 low, 2 high) a step in direction (-1 or 1): new low and high, or nil
-- when its limits (Min and LowMax, HighMin and Max), DeltaMin or DeltaMax stop it.
function M.move(setting,low,high,marker,direction)
    if marker==1 then
        local n=low+direction
        if n<0 or n>(setting.lowMax or setting.count) or high-n<setting.deltaMin or high-n>setting.deltaMax then return nil end
        return n,high
    end
    local n=high+direction
    if n>setting.count or n<(setting.highMin or 0) or n-low<setting.deltaMin or n-low>setting.deltaMax then return nil end
    return low,n
end
-- One marker as close to step n as the limits allow: new low and high.
function M.place(setting,low,high,marker,n)
    if marker==1 then
        return math.max(math.max(0,high-setting.deltaMax),math.min(n,high-setting.deltaMin,setting.lowMax or setting.count)),high
    end
    return low,math.min(math.min(setting.count,low+setting.deltaMax),math.max(n,low+setting.deltaMin,setting.highMin or 0))
end
-- The marker a press on step n takes: the one at or beyond it, else the nearer; a tie
-- goes to the highlighted marker, then the low one.
function M.nearer(low,high,n,highlighted)
    if n<=low then return 1 end
    if n>=high then return 2 end
    if n-low==high-n then return highlighted or 1 end
    return n-low<high-n and 1 or 2
end

-- The keyboard and controller state of one row: which marker is highlighted (1, 2 or
-- nil) and whether it is grabbed. Calls return the new value, or nil when it stays.
function M.state(setting)
    local state={highlighted=nil,grabbed=false}
    function state:step(value,direction)
        if not self.grabbed then
            self.highlighted=direction<0 and 1 or 2
            return nil
        end
        local low,high=M.parts(setting,value)
        if not low then return nil end
        low,high=M.move(setting,low,high,self.highlighted,direction)
        return low and M.value(setting,low,high) or nil
    end
    -- Enter grabs the highlighted marker (the low one when none is), or lets go.
    function state:confirm()
        if self.grabbed then self.grabbed=false
        else self.highlighted=self.highlighted or 1;self.grabbed=true end
    end
    function state:leave() self.highlighted,self.grabbed=nil,false end
    function state:hint() return self.grabbed and 'DONE' or 'ADJUST' end
    return state
end

-- Drawn like ModCoreSettings' slider (presentation.lua): the value above, two points
-- smaller; a thin line, its span lit and thicker; a thin handle at each end. A highlighted
-- handle gets a white contour; a grabbed one is raised and the other hides. The line is dim
-- until the row is selected or hovered.
local colors={lit={R=0.95,G=0.63,B=0.08,A=0.9},dim={R=0.62,G=0.55,B=0.42,A=0.35},
    contour={R=1,G=1,B=1,A=1},none={R=1,G=1,B=1,A=0}}

-- The value column (as a picker's: control 190 wide, the line 75% of it), the line's
-- heights (rest 2, span 4), the handle (3 wide, 10 tall, 14 when grabbed, from 2 above the
-- line) and its 1-pixel contour, the line's place (bottom 4 above the row's) and the
-- value's (lift 3 above the centre, shrink 2 points). Opacities: idle line 0.5, the other
-- handle while one is grabbed 0.35.
M.layout={label=330,value=210,control=190,share=0.75,rest=2,span=4,handle=3,marker=10,grabbed=14,
    above=2,contour=1,bottom=4,lift=3,shrink=2,idle=0.5,row=40}

function M.build(row,setting,context)
    local layout=M.layout
    local api,tree=context.api,context.tree
    local function new(kind) return api.construct('/Script/UMG.'..kind,tree) end
    local function need(value,label) return api.need(value,label) end
    local function sized(widget,width,height)
        local box=new('SizeBox')
        if width then box:SetWidthOverride(width) end
        if height then box:SetHeightOverride(height) end
        local slot=need(box:SetContent(widget),'range size content')
        slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
        return box
    end
    local function line(color,width,height)
        local fill=new('Border');fill:SetBrushColor(color)
        return sized(fill,width,height),fill
    end

    -- Make room on DMM's toggle row: label | control, the control as wide as a picker's value.
    local content=need(row.widget:GetContent(),'range row content')
    -- The shell button pads its content above and below (1.5 each); taking that back gives
    -- the control the row's full height, so the line sits where a slider's bar does.
    pcall(function()
        local inset,slot=row.widget.WidgetStyle.NormalPadding,content.Slot
        local p=slot.Padding
        slot:SetPadding({Left=p.Left,Top=-(inset.Top or 0),Right=p.Right,Bottom=-(inset.Bottom or 0)})
    end)
    local labelBox,valueBox=content:GetChildAt(0),content:GetChildAt(1)
    need(labelBox,'range label box'):SetWidthOverride(layout.label)
    need(valueBox,'range value box'):SetWidthOverride(layout.value)
    local host=new('Overlay')
    local hostSlot=need(valueBox:SetContent(sized(host,layout.control,layout.row)),'range editor host')
    hostSlot:SetHorizontalAlignment(1);hostSlot:SetVerticalAlignment(0)

    -- The value: DMM's caption (the span and its dirty star), centred above the line.
    local caption=need(host:AddChildToOverlay(row.value),'range caption')
    caption:SetHorizontalAlignment(0);caption:SetVerticalAlignment(2)
    caption:SetPadding({Left=0,Top=0,Right=0,Bottom=2*layout.lift})
    row.value:SetJustification(1)
    pcall(function()
        api.Theme.font(row.value,api.theme,(tonumber(row.value.Font and row.value.Font.Size) or 14)-layout.shrink)
        row.value:SetFont(row.value.Font)
    end)

    -- The track: the line with a handle per end, a margin past each end, over the row's
    -- height. A step's place is centred on it; the end ones reach into the margins.
    local span=math.floor(layout.control*layout.share/2)*2
    local count=setting.count
    local cell=span/count
    local margin=math.min(cell/2,(layout.control-span)/2)
    local function at(n) return n*cell end
    local track=new('Overlay')
    local trackSlot=need(host:AddChildToOverlay(sized(track,span+2*margin,layout.row)),'range track')
    trackSlot:SetHorizontalAlignment(2);trackSlot:SetVerticalAlignment(0)
    local bar=new('Overlay')
    local barBox=sized(bar,span,layout.grabbed)
    local barSlot=need(track:AddChildToOverlay(barBox),'range line')
    barSlot:SetHorizontalAlignment(1);barSlot:SetVerticalAlignment(3)
    barSlot:SetPadding({Left=margin,Top=0,Right=0,Bottom=layout.bottom})
    barBox:SetRenderOpacity(layout.idle)
    -- The line: dim before the span, lit across it, dim after; centred on one line.
    local strip=new('HorizontalBox')
    local parts={}
    for n,color in ipairs({colors.dim,colors.lit,colors.dim}) do
        local box=line(color,0,n==2 and layout.span or layout.rest)
        need(strip:AddChild(box),'range line part'):SetVerticalAlignment(2)
        parts[n]=box
    end
    local stripSlot=need(bar:AddChildToOverlay(sized(strip,nil,layout.span)),'range strip')
    stripSlot:SetHorizontalAlignment(0);stripSlot:SetVerticalAlignment(1)
    stripSlot:SetPadding({Left=0,Top=layout.grabbed-layout.marker+layout.above,Right=0,Bottom=0})
    -- A handle: a thin mark (dim, lit, dim) in a contour that shows while it is highlighted.
    local markers={}
    for n=1,2 do
        local mark=new('HorizontalBox')
        for _,color in ipairs({colors.dim,colors.lit,colors.dim}) do need(mark:AddChild((line(color,1,nil))),'range handle line') end
        local contour=new('Border');contour:SetBrushColor(colors.none)
        contour:SetPadding({Left=layout.contour,Top=layout.contour,Right=layout.contour,Bottom=layout.contour})
        need(contour:SetContent(mark),'range handle contour')
        local box=sized(contour,layout.handle+2*layout.contour,layout.marker+2*layout.contour)
        local slot=need(bar:AddChildToOverlay(box),'range handle')
        slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(3)
        markers[n]={contour=contour,box=box,slot=slot}
    end
    -- The mouse goes to an invisible native slider over the whole track. The menu takes the
    -- mouse button before the player controller sees it, so a press shows as the slider
    -- capturing the pointer; it holds the capture, and follows the pointer, until let go.
    -- Its value is the pointer's place along the track (0 to 1): no handle, so no inset.
    local width=span+2*margin
    local mouse=new('Slider');mouse.IsFocusable=false
    pcall(function() mouse.RequiresControllerLock=false end)
    mouse:SetMinValue(0);mouse:SetMaxValue(1);mouse:SetStepSize(1/(4*width))
    pcall(function() mouse:SetSliderBarColor(colors.none) end)
    pcall(function() mouse:SetSliderHandleColor(colors.none) end)
    pcall(function()
        local style=mouse.WidgetStyle
        for _,name in ipairs({'NormalThumbImage','HoveredThumbImage','DisabledThumbImage'}) do style[name].ImageSize={X=0,Y=0} end
    end)
    pcall(function() mouse:SetIndentHandle(false) end)
    local mouseSlot=need(track:AddChildToOverlay(sized(mouse,width,layout.row)),'range mouse slider')
    mouseSlot:SetHorizontalAlignment(0);mouseSlot:SetVerticalAlignment(0)
    -- The step under a place along the track, between 0 and count.
    local function stepAt(place)
        return math.max(0,math.min(count,math.floor((place*width-margin)/cell+0.5)))
    end

    local instance={setting=setting,value=nil,state=M.state(setting),focused=false}
    local function render()
        local low,high=M.parts(setting,instance.value)
        if not low then return end
        parts[1]:SetWidthOverride(at(low));parts[2]:SetWidthOverride(at(high)-at(low))
        parts[3]:SetWidthOverride(span-at(high))
        local state=instance.state
        -- A marker dragged with the mouse shows as highlighted and grabbed.
        local dragged=instance.dragging
        local highlighted,grabbed=dragged or state.highlighted,state.grabbed or dragged~=nil
        -- Like a slider's mark, the handles show only while the row is hovered or selected;
        -- while one is grabbed, the other hides.
        local hot=instance.focused or grabbed or instance.hovered==true
        for n,step in ipairs({low,high}) do
            local marker=markers[n]
            local mine=highlighted==n
            local raised=grabbed and mine
            local height=(raised and layout.grabbed or layout.marker)+2*layout.contour
            marker.contour:SetBrushColor(mine and colors.contour or colors.none)
            marker.box:SetHeightOverride(height)
            marker.box:SetVisibility(hot and (mine or not grabbed) and 4 or 1)
            marker.slot:SetPadding({Left=at(step)-layout.handle/2-layout.contour,Top=0,Right=0,Bottom=0})
        end
        if hot~=instance.hot then instance.hot=hot;barBox:SetRenderOpacity(hot and 1 or layout.idle) end
    end
    instance.render=render

    -- Setter: DMM's model value into the track.
    function instance:set(value)
        if value==self.value then return end
        self.value=value
        render()
    end
    -- Left/Right on the row (-1 or 1): highlight a marker, or move the grabbed one.
    function instance:step(direction)
        if self.value==nil then return nil end
        local value=self.state:step(self.value,direction)
        render()
        return value
    end
    function instance:confirm()
        self.state:confirm()
        render()
    end
    -- The row is selected (on) or not; leaving it lets go and clears the highlight.
    function instance:focus(on)
        if on then
            if not self.focused then self.focused=true;render() end
            return
        end
        if not self.focused and self.state.highlighted==nil and not self.state.grabbed then return end
        self.focused=false
        self.state:leave()
        render()
    end
    function instance:hint() return self.state:hint() end
    -- Getter: a press or drag on the track as the new value, or nil. A press takes the
    -- nearer marker (see M.nearer) and holding drags it; letting go ends the drag.
    function instance:tick()
        if self.value==nil then return nil end
        local hovered=track:IsHovered()==true
        if hovered~=self.hovered then self.hovered=hovered;render() end
        local ok,captured=pcall(function() return mouse:HasMouseCapture() end)
        local down=ok and captured==true
        local pressed=down and not self.down
        self.down=down
        if not down then
            if self.dragging then self.dragging=nil;render() end
            return nil
        end
        local low,high=M.parts(setting,self.value)
        if not low then return nil end
        local over=stepAt(tonumber(mouse:GetValue()) or 0)
        if pressed then self.dragging=M.nearer(low,high,over,self.state.highlighted);render() end
        if not self.dragging then return nil end
        low,high=M.place(setting,low,high,self.dragging,over)
        local value=M.value(setting,low,high)
        return value~=self.value and value or nil
    end
    return instance
end

return M

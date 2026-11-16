package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- The live preview: a page whose menu data declares preview gets a 4:3 area at the bottom
-- of its side panel, and its provider is told through shared variables and a command.
local Preview=require('preview_panel')

local function widget(kind)
    local w={kind=kind,children={},visible=4}
    function w:SetContent(child)
        if child.parent and child.parent.content==child then child.parent.content=nil end
        self.content=child;child.parent=self;child.Slot={Padding={Left=0,Top=0,Right=0,Bottom=0}}
        local slot=child.Slot
        function slot:SetHorizontalAlignment(v) self.HorizontalAlignment=v end
        function slot:SetVerticalAlignment(v) self.VerticalAlignment=v end
        function slot:SetPadding(v) self.Padding=v end
        return slot
    end
    function w:AddChildToOverlay(child)
        if child.parent and child.parent.content==child then child.parent.content=nil end
        self.children[#self.children+1]=child;child.parent=self
        local slot={Padding={Left=0,Top=0,Right=0,Bottom=0}}
        function slot:SetHorizontalAlignment(v) self.HorizontalAlignment=v end
        function slot:SetVerticalAlignment(v) self.VerticalAlignment=v end
        function slot:SetPadding(v) self.Padding=v end
        child.Slot=slot
        return slot
    end
    function w:GetParent() return self.parent end
    function w:SetWidthOverride(v) self.WidthOverride=v end
    function w:SetHeightOverride(v) self.HeightOverride=v end
    function w:SetVisibility(v) self.visible=v end
    function w:SetClipping(v) self.clipping=v end
    function w:SetStretch(v) self.stretch=v end
    function w:SetBrushFromTexture(t) self.texture=t end
    return w
end
local texts={}
local api={construct=function(path) return widget(path:match('UMG%.(.+)$')) end,need=function(v) return assert(v) end,
    button=function(_,text)
        local b=widget('Button');local l=widget('TextBlock');l.text=text;b.label=l
        function b:IsPressed() return self.pressed==true end
        function b:IsHovered() return self.hovered==true end
        return b,l
    end,
    setText=function(label,text) label.text=text end}
local panel=widget('SizeBox')
local scroll=widget('ScrollBox')
panel:SetContent(scroll)

local model={items={{id='Style'},{id='Size'},{id='Note'}},pending={'fiend','30|80',nil}}
local shown,hidden,ticks=0,0,0
local page={detailScroll=scroll,controls={model=model}}
function page.controls:show(index) shown=shown+1 end
function page.controls:hide() hidden=hidden+1 end
function page.controls:tick() ticks=ticks+1;return false end
local providers={{id='P',mcPreview={background='C:/Mods/P/images/back.jpg'}},{id='Plain'}}
local vars,commands,reports={},{},{}
local shared={SetSharedVariable=function(_,k,v) vars[k]=v end,GetSharedVariable=function(_,k) return vars[k] end}
local texture={name='texture'}
local wrapped=Preview.wrap(page,providers,api,{shared=shared,tree={},report=function(e,d) reports[#reports+1]=e..' '..d end,
    texture=function(path) assert(path=='C:/Mods/P/images/back.jpg');return texture end,
    exec=function(command) commands[#commands+1]=command end})
assert(wrapped==page and page.mcPreview,'the page is wrapped')

-- A page without a preview leaves the panel alone.
page.controls:show(2)
assert(shown==1 and panel.content==scroll and #commands==0,'no preview, no change')

-- A page with one: the description scrolls above a 4:3 preview at the bottom.
page.controls:show(1)
local stack=panel.content
assert(stack.kind=='Overlay' and stack.children[1]==scroll,'the description scroll stays, in an overlay')
local preview=stack.children[2]
assert(preview.WidthOverride==576 and preview.HeightOverride==324 and preview.visible==4 and preview.clipping==1,
    'a 576 by 324 (16:9) preview, shown and clipped')
assert(preview.Slot.HorizontalAlignment==2 and preview.Slot.VerticalAlignment==3 and preview.Slot.Padding.Bottom==20,
    'centred at the bottom, 20 above it')
assert(scroll.Slot.Padding.Bottom==324+20+16,'the description stops 16 above the preview')
local frame=preview.content
local background,scale=frame.children[1],frame.children[2]
assert(background.texture==texture and background.visible==4,'the background picture fills it')
local screen=scale.content
local host=screen.content
assert(scale.stretch==2 and screen.WidthOverride==1920 and screen.HeightOverride==1080 and host.kind=='Overlay',
    'a 1920 by 1080 screen scaled to fit holds the host')
assert(vars[Preview.HOST]==host and vars[Preview.STATE]:match('^%d+ open P$'),'the host and state are shared')
assert(vars[Preview.VALUES]:match('^%d+\nStyle=fiend\nSize=30|80$'),'with the page\'s values: '..vars[Preview.VALUES])
assert(commands[#commands]==Preview.COMMAND,'and the provider is told')

-- The sound button sits top right over the preview; a click moves it auto -> on -> off.
local soundButton=frame.children[3]
assert(soundButton and soundButton.kind=='Button' and soundButton.label.text=='Sound: Auto'
    and soundButton.Slot.HorizontalAlignment==3 and soundButton.Slot.VerticalAlignment==1,'the sound button, top right')
assert(vars[Preview.SOUND]=='auto','auto by default')
local function click()
    soundButton.pressed,soundButton.hovered=true,true;page.controls:tick()
    soundButton.pressed=false;page.controls:tick()
end
click()
assert(vars[Preview.SOUND]=='on' and soundButton.label.text=='Sound: On','a click turns it on')
click();assert(vars[Preview.SOUND]=='off' and soundButton.label.text=='Sound: Off','then off')
click();assert(vars[Preview.SOUND]=='auto','then back to auto')
-- The selected setting is shared, for auto.
page.controls.current=2
page.controls:tick()
assert(vars[Preview.FOCUS]=='Size','the selected setting is shared')
-- A changed value is republished on the next tick; an unchanged one is not.
local sent=#commands
page.controls:tick()
assert(#commands==sent,'nothing changed, nothing sent')
model.pending[2]='40|90'
page.controls:tick()
assert(#commands==sent+1 and vars[Preview.VALUES]:find('Size=40|90',1,true),'a change is sent')

-- Hiding the page closes the preview and gives the description its height back.
page.controls:hide()
assert(hidden==1 and preview.visible==1 and scroll.Slot.Padding.Bottom==0
    and vars[Preview.HOST]==nil and vars[Preview.STATE]:match('^%d+ closed P$'),'closing hides it and tells the provider')
-- Showing it again reuses the same panel.
page.controls:show(1)
assert(panel.content==stack and #stack.children==2 and preview.visible==4,'reopened in place')
-- A plain page after it closes the preview.
page.controls:show(2)
assert(preview.visible==1 and vars[Preview.STATE]:match(' closed P$'),'switching to a page without one closes it')
assert(#reports==0,table.concat(reports,'; '))
print('PASS preview panel: a 16:9 preview under the description, its host and values shared with the provider')

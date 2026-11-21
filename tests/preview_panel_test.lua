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
    function w:SetBlurStrength(v) self.blur=v end
    function w:SetText(v) self.text=v end
    function w:SetFont(f) self.Font={TypefaceFontName=f.TypefaceFontName,SkewAmount=f.SkewAmount,FontObject=f.FontObject} end
    function w:SetRenderOpacity(v) self.opacity=v end
    function w:SetColorAndOpacity(v) self.ColorAndOpacity=v end
    w.Font={TypefaceFontName='Regular',SkewAmount=0}
    function w:AddChildToHorizontalBox(child)
        self.children[#self.children+1]=child;child.parent=self
        local slot={Padding={Left=0,Top=0,Right=0,Bottom=0}}
        function slot:SetVerticalAlignment(v) self.VerticalAlignment=v end
        function slot:SetPadding(v) self.Padding=v end
        child.Slot=slot
        return slot
    end
    return w
end
local texts={}
local api={construct=function(path) return widget(path:match('UMG%.(.+)$')) end,need=function(v) return assert(v) end,
    button=function(_,text)
        local b=widget('Button');local l=widget('TextBlock');l.text=text;b.label=l
        l.Font={TypefaceFontName='Regular',SkewAmount=0,FontObject={GetFullName=function() return 'Font Body' end,
            CompositeFont={DefaultTypeface={Fonts={{Name='Regular'},{Name='Bold'},{Name='Bold Italic'},{Name='Italic'}}}}}}
        function b:IsPressed() return self.pressed==true end
        function b:IsHovered() return self.hovered==true end
        return b,l
    end,
    setText=function(label,text) label.text=text end}
local panel=widget('SizeBox')
local scroll=widget('ScrollBox')
panel:SetContent(scroll)

local model={items={{id='Style',mcKeys={'off','fiend'}},{id='Size'},{id='Note'}},pending={2,'30|80',nil}}
local shown,hidden,ticks=0,0,0
local page={detailScroll=scroll,controls={model=model}}
function page.controls:show(index) shown=shown+1 end
function page.controls:hide() hidden=hidden+1 end
function page.controls:tick() ticks=ticks+1;return false end
local providers={{id='P',mcPreview={background='C:/Mods/P/images/back.jpg'}},{id='Plain'},{id='Bare',mcPreview={}},
    {id='Missing',mcPreview={background='C:/Mods/M/images/none.jpg'}}}
local vars,commands,reports={},{},{}
local shared={SetSharedVariable=function(_,k,v) vars[k]=v end,GetSharedVariable=function(_,k) return vars[k] end}
local texture={name='texture'}
local wrapped=Preview.wrap(page,providers,api,{shared=shared,tree={},report=function(e,d) reports[#reports+1]=e..' '..d end,
    -- A picture that cannot be read gives none (dmm_extension reports it).
    texture=function(path) if path=='C:/Mods/M/images/none.jpg' then return nil end
        assert(path=='C:/Mods/P/images/back.jpg');return texture end,
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
assert(preview.Slot.HorizontalAlignment==1 and preview.Slot.VerticalAlignment==3 and preview.Slot.Padding.Bottom==68
    and preview.Slot.Padding.Left==40,'at the bottom, 68 above it, starting 40 in like the header and description text')
assert(scroll.Slot.Padding.Bottom==324+68+16,'the description stops 16 above the preview')
local frame=preview.content
local fill,background,blur,scale=frame.children[1],frame.children[2],frame.children[3],frame.children[4]
assert(blur.kind=='BackgroundBlur' and blur.blur==12 and blur.visible==1,'a blur over the picture, off by default')
assert(background.texture==texture and background.visible==4 and background.opacity==1,'the background picture fills it')
assert(fill.kind=='Image' and fill.visible==1 and fill.ColorAndOpacity.B>fill.ColorAndOpacity.R
    and fill.ColorAndOpacity.B<0.5,'a dim light blue screen, for the background off')
local screen=scale.content
local host=screen.content
assert(scale.stretch==2 and screen.WidthOverride==1920 and screen.HeightOverride==1080 and host.kind=='Overlay',
    'a 1920 by 1080 screen scaled to fit holds the host')
assert(vars[Preview.HOST]==host and vars[Preview.STATE]:match('^%d+ open P$'),'the host and state are shared')
assert(vars[Preview.VALUES]:match('^%d+\nStyle=fiend\nSize=30|80$'),'with the page\'s values, a keyed picker\'s as its key: '..vars[Preview.VALUES])
assert(commands[#commands]==Preview.COMMAND,'and the provider is told')

-- Under the preview's right end, each in a fixed box so its text never moves it, its text
-- left-aligned: the sound button 20 past the preview's right edge, the background button left of
-- it. Each reads '<name>:' (70% opaque) and its value: On and Auto white and bold, Off
-- italic and 70% opaque.
local backgroundBox,soundBox=stack.children[3],stack.children[4]
local backgroundButton,soundButton=backgroundBox.content,soundBox.content
local function parts(button) local line=button.content;return line,line.children[1],line.children[2] end
local soundLine,soundPrefix,soundValue=parts(soundButton)
assert(soundBox.kind=='SizeBox' and soundBox.WidthOverride==150 and soundBox.HeightOverride==32
    and soundBox.visible==4 and soundButton.kind=='Button' and soundLine.kind=='HorizontalBox'
    and soundLine.Slot.HorizontalAlignment==1
    and soundBox.Slot.HorizontalAlignment==1 and soundBox.Slot.VerticalAlignment==3
    and soundBox.Slot.Padding.Left==40+576-150+20 and soundBox.Slot.Padding.Bottom==68-6-32,
    'the sound button, 20 past the preview\'s right end, its text left-aligned')
assert(backgroundBox.WidthOverride==230 and backgroundBox.Slot.Padding.Left==40+576-150+20-230 and backgroundBox.visible==4,
    'the background button left of it')
assert(soundPrefix.text=='Sound:' and soundPrefix.opacity==0.7 and soundValue.Slot.Padding.Left==6,'Sound: at 70%')
local function bright(value) return value.ColorAndOpacity.SpecifiedColor.R==1 and value.opacity==1
    and value.Font.TypefaceFontName=='Bold' end
local function dim(value) return value.opacity==0.7 and value.Font.TypefaceFontName=='Italic' end
assert(soundValue.text=='Auto' and bright(soundValue),'Auto: white and bold')
assert(vars[Preview.SOUND]=='auto','auto by default')
local function click(button)
    button=button or soundButton
    button.pressed,button.hovered=true,true;page.controls:tick()
    button.pressed=false;page.controls:tick()
end
click()
assert(vars[Preview.SOUND]=='on' and soundValue.text=='On' and bright(soundValue),'a click turns it on')
click();assert(vars[Preview.SOUND]=='off' and soundValue.text=='Off' and dim(soundValue),'then off: italic, 70%')
click();assert(vars[Preview.SOUND]=='auto' and bright(soundValue),'then back to auto')
-- Background: on by default, the picture as it is; blurred blurs it; dimmed draws it 30%
-- opaque; off shows a dim light blue screen instead.
local _,backgroundPrefix,backgroundValue=parts(backgroundButton)
assert(backgroundPrefix.text=='Background:' and backgroundValue.text=='On' and bright(backgroundValue),'Background: On')
local commandsBefore=#commands
click(backgroundButton)
assert(backgroundValue.text=='Blurred' and bright(backgroundValue) and blur.visible==4 and background.visible==4
    and background.opacity==1 and fill.visible==1,'Background: Blurred blurs the picture')
assert(#commands==commandsBefore,'the background is the panel\'s own, the provider is not told')
click(backgroundButton)
assert(backgroundValue.text=='Dimmed' and bright(backgroundValue) and blur.visible==1 and background.visible==4
    and background.opacity==0.3 and fill.visible==1,'Background: Dimmed draws the picture 30% opaque')
click(backgroundButton)
assert(backgroundValue.text=='Off' and dim(backgroundValue) and blur.visible==1 and background.visible==1
    and fill.visible==4,'Background: Off, a dim light blue screen')
click(backgroundButton)
assert(backgroundValue.text=='On' and background.visible==4 and background.opacity==1 and fill.visible==1,'and on again')
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
assert(hidden==1 and preview.visible==1 and soundBox.visible==1 and backgroundBox.visible==1 and scroll.Slot.Padding.Bottom==0
    and vars[Preview.HOST]==nil and vars[Preview.STATE]:match('^%d+ closed P$'),'closing hides it and tells the provider')
-- Showing it again reuses the same panel.
page.controls:show(1)
assert(panel.content==stack and #stack.children==4 and preview.visible==4 and soundBox.visible==4
    and backgroundBox.visible==4,'reopened in place')
-- A plain page after it closes the preview.
page.controls:show(2)
assert(preview.visible==1 and vars[Preview.STATE]:match(' closed P$'),'switching to a page without one closes it')
-- A preview without a picture, or with one that cannot be read, shows no background:
-- an Image without a texture would draw a white box.
page.controls:show(3)
assert(preview.visible==4 and background.visible==1 and vars[Preview.STATE]:match(' open Bare$'),'no picture, no background')
-- On, blurred or dimmed without a picture shows nothing behind the host; off the screen.
assert(blur.visible==1 and fill.visible==1,'on, no picture: nothing behind')
click(backgroundButton)
assert(background.visible==1 and blur.visible==1 and fill.visible==1,'blurred, no picture: nothing behind')
click(backgroundButton);click(backgroundButton)
assert(fill.visible==4,'off: the screen')
page.controls:show(1)
assert(background.texture==texture and background.visible==1 and fill.visible==4,
    'a page with a picture loads it again, behind the screen while the background is off')
click(backgroundButton)
assert(background.visible==4,'and shows it on')
page.controls:show(4)
assert(preview.visible==4 and background.visible==1,'an unreadable picture leaves the preview without one')
page.controls:hide()
assert(#reports==0,table.concat(reports,'; '))
-- Installed, the buttons start from config.ini's [Modules] PreviewSound and
-- PreviewBackground at each build, and a click saves the new state there.
local saved=Preview.saved('[Modules]\nPreviewSound = off\nPreviewBackground=dimmed\n')
assert(saved.sound=='off' and saved.backdrop=='dimmed','the saved states')
saved=Preview.saved('[Modules]\nPreviewSound=loud\n')
assert(saved.sound=='auto' and saved.backdrop=='on','unset or unknown: the defaults')
do
    local config='[Modules]\nSortBy=1\nPreviewBackground=blurred\n'
    local pages={build=function(tree)
        local sidePanel,sideScroll=widget('SizeBox'),widget('ScrollBox');sidePanel:SetContent(sideScroll)
        local built={detailScroll=sideScroll,controls={model={items={},pending={}}}}
        function built.controls:show() end
        function built.controls:tick() end
        return built
    end}
    assert(Preview.install(pages,{shared=shared,tree={},texture=function() return texture end,
        read=function() return config end,write=function(text) config=text end}))
    local built=pages.build({},{{id='P',mcPreview={background='x.jpg'}}},nil,api)
    built.controls:show(1)
    local box=built.detailScroll:GetParent()
    local frame2=box.children[2].content
    assert(frame2.children[3].visible==4,'built blurred, as saved')
    local button=box.children[3].content
    local _,_,value=button.content,nil,button.content.children[2]
    assert(value.text=='Blurred','the button reads the saved state')
    button.pressed,button.hovered=true,true;built.controls:tick()
    button.pressed=false;built.controls:tick()
    assert(value.text=='Dimmed' and config:find('PreviewBackground=dimmed',1,true) and config:find('SortBy=1',1,true),
        'a click saves the new state, other settings kept: '..config)
    config=config:gsub('PreviewBackground=dimmed','PreviewBackground=off')
    built=pages.build({},{{id='P',mcPreview={background='x.jpg'}}},nil,api)
    built.controls:show(1)
    assert(built.detailScroll:GetParent().children[3].content.content.children[2].text=='Off',
        'the next build starts from the saved state, set on the MCS page')
end
-- Closing the menu (hostClosing) closes the open preview, and a problem that repeats on every
-- tick is logged once.
do
    local handlers={}
    local bus={on=function(_,name,callback) handlers[name]=callback end}
    local logged={}
    local pages={build=function()
        local sidePanel,sideScroll=widget('SizeBox'),widget('ScrollBox');sidePanel:SetContent(sideScroll)
        local built={detailScroll=sideScroll,controls={model={items={{id='A'}},pending={}}}}
        function built.controls:show() end
        function built.controls:tick() end
        return built
    end}
    local states={}
    local watched={SetSharedVariable=function(_,k,v) if k==Preview.STATE then states[#states+1]=v end end}
    assert(Preview.install(pages,{shared=watched,events=bus,report=function(e,d) logged[#logged+1]=e..' '..d end}))
    local built=pages.build({},{{id='P',mcPreview={}}},nil,api)
    built.controls:show(1)
    assert(states[#states]:find(' open P$'),states[#states])
    handlers.hostClosing({})
    assert(states[#states]:find(' closed P$'),'closing the menu closes the preview: '..tostring(states[#states]))
    handlers.hostClosing({})
    assert(#states==2,'a second close does nothing')
    built.controls:show(1)
    -- A model whose values cannot be encoded fails on every tick.
    built.controls.model.items[1].mcKeys={'a'};built.controls.model.pending[1]=5
    built.controls.model.items[1].values=nil
    local encode=Preview.encode
    Preview.encode=function() error('broken model') end
    for _=1,5 do built.controls:tick() end
    Preview.encode=encode
    local count=0
    for _,line in ipairs(logged) do if line:find('broken model',1,true) then count=count+1 end end
    assert(count==1,'a repeating problem is logged once, not '..count)
end
print('PASS preview panel: a 16:9 preview under the description, its host and values shared with the provider')

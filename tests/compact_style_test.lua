package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Compact=require('compact_style')

-- The stored style, off when unset or unknown; which pages look compact.
assert(Compact.style('[Modules]\nCompactStyle=index\n')=='index' and Compact.style('[Modules]\nCompactStyle=everywhere\n')=='everywhere'
    and Compact.style('[Modules]\nCompactStyle=x\n')=='off' and Compact.style(nil)=='off','the stored style')
assert(Compact.compact('index','browser',false) and not Compact.compact('index','settings',true)
    and Compact.compact('everywhere','settings',false) and not Compact.compact('off','browser',true),'index: the mod list only')
assert(Compact.compact('index','dialog',true)==true and Compact.compact('index','dialog',false)==false,'a dialog keeps the page\'s look')

-- DMM's menu as it builds it: backdrop -> outer (background, design scale -> design box -> overlay).
local function widget(kind)
    local w={kind=kind,children={},visibility=4,opacity=1}
    function w:IsValid() return true end
    function w:GetParent() return self.parent end
    function w:GetChildrenCount() return #self.children end
    function w:GetChildAt(i) return self.children[i+1] end
    local function slot(child)
        local s={Padding={Left=0,Top=0,Right=0,Bottom=0}}
        function s:SetPadding(p) self.Padding=p end
        function s:SetHorizontalAlignment(v) self.h=v end
        function s:SetVerticalAlignment(v) self.v=v end
        child.Slot=s
        return s
    end
    function w:RemoveFromParent()
        local parent=self.parent
        if parent then
            if parent.content==self then parent.content=nil end
            for i,c in ipairs(parent.children) do if c==self then table.remove(parent.children,i) end end
        end
        self.parent=nil
    end
    function w:SetContent(child)
        if self.content then self.content.parent=nil end
        child:RemoveFromParent();self.content=child;child.parent=self;return slot(child)
    end
    function w:AddChildToOverlay(child)
        child:RemoveFromParent();self.children[#self.children+1]=child;child.parent=self;return slot(child)
    end
    function w:SetBlurStrength(v) self.blur=v end
    function w:SetPadding(v) self.padding=v end
    function w:SetHorizontalAlignment(v) self.h=v end
    function w:SetVerticalAlignment(v) self.v=v end
    function w:SetBrushColor(c) self.BrushColor=c end
    function w:SetBrushFromMaterial(m) self.material=m end
    function w:SetStretch(v) self.stretch=v end
    function w:SetWidthOverride(v) self.width=v end
    function w:SetHeightOverride(v) self.height=v end
    function w:SetVisibility(v) self.visibility=v end
    function w:GetVisibility() return self.visibility end
    function w:SetRenderOpacity(v) self.opacity=v end
    function w:GetRenderOpacity() return self.opacity end
    function w:SetRenderTransformPivot(v) self.pivot=v end
    function w:SetRenderScale(v) self.scale=v end
    function w:GetContent() return self.content end
    return w
end
local function menu()
    local backdrop,outer,background,scale,design,overlay=widget('Border'),widget('Overlay'),widget('Image'),
        widget('ScaleBox'),widget('SizeBox'),widget('Overlay')
    backdrop.BrushColor={R=0.003,G=0.004,B=0.006,A=1}
    backdrop:SetContent(outer);outer:AddChildToOverlay(background);outer:AddChildToOverlay(scale)
    scale:SetContent(design);design:SetContent(overlay)
    local page=widget('SwitcherRoot')
    overlay:AddChildToOverlay(page).Padding={Left=164,Top=76,Right=164,Bottom=80}
    -- One of DMM's vertical dividers, deep in the page.
    local column,divider=widget('HorizontalBox'),widget('SizeBox')
    divider.WidthOverride,divider.HeightOverride=20,660
    page:SetContent(column);column:AddChildToOverlay(divider)
    return {backdrop=backdrop,outer=outer,background=background,scale=scale,overlay=overlay,page=page,divider=divider}
end
local pause=widget('WBP_PauseMenu_C')
local function api(material)
    return {construct=function(path) return widget(path:match('UMG%.(.+)$')) end,
        findMaterial=function(path) assert(path==Compact.PANEL_MATERIAL);return material end,
        pause=function() return pause end}
end

-- Built before the menu shows: a blur between the backdrop and outer, the tint and the
-- panel under DMM's design, all off at first.
local m=menu()
local look=Compact.build(m.overlay,'tree',api('material'))
local blur=m.backdrop.content
assert(blur.kind=='BackgroundBlur' and blur.content==m.outer and blur.blur==0,'a blur between the backdrop and the menu, off')
local layers=m.outer.children
assert(#layers==4 and layers[1]==m.background and layers[2].kind=='Border' and layers[3].kind=='ScaleBox'
    and layers[4]==m.scale,'the tint and the panel under DMM\'s design')
local tint,panelScale=layers[2],layers[3]
local panelBox=panelScale.content.content.children[1]
assert(tint.BrushColor.A==0.2 and panelBox.width==850 and panelBox.Slot.h==1 and panelBox.content.material=='material',
    'a 20% tint and the pause menu\'s panel, 850 wide on the left')
assert(tint.visibility==1 and panelScale.visibility==1 and m.background.visibility==4,'DMM\'s look at first')

-- Compact: the game blurred and tinted, the panel, no background, the page at the top left,
-- the pause menu hidden; back to DMM's look restores each.
look:show(true)
assert(blur.blur==5 and m.backdrop.BrushColor.A==0 and m.background.visibility==1 and tint.visibility==3
    and panelScale.visibility==3,'the pause menu\'s look')
assert(m.page.Slot.Padding.Left==48 and m.page.Slot.Padding.Top==40 and m.page.Slot.Padding.Bottom==80,'the page at the top left')
assert(m.page.scale.X==0.8 and m.page.pivot.X==0 and m.page.pivot.Y==0,'drawn at 80% from its top left')
assert(m.divider.visibility==2,'the dividers hidden, keeping their place')
assert(pause.opacity==0,'the pause menu under it is hidden')
look:show(false)
assert(blur.blur==0 and m.backdrop.BrushColor.A==1 and m.background.visibility==4 and tint.visibility==1
    and m.page.Slot.Padding.Left==164 and m.page.Slot.Padding.Top==76 and pause.opacity==1
    and m.page.scale.X==1 and m.divider.visibility==4,'DMM\'s look again')
look:show(true);look:close()
assert(pause.opacity==1,'closing the mod menu shows the pause menu again')

-- Without the material, a plain dark panel.
local plain=menu()
Compact.build(plain.overlay,'tree',api(nil))
local plainBox=plain.outer.children[3].content.content.children[1]
assert(plainBox.content.material==nil and plainBox.content.BrushColor.A>0,'a plain dark panel')

-- Installed: each menu reads the style when it opens; in a loaded game a compact style
-- builds the look and each sync shows it for the page; the menu closing shows the pause
-- menu again. The mod list is one column under a compact style in a loaded game.
local stored,inGame='[Modules]\nCompactStyle=index\n',true
local closed,tick=0,0
local native={new=function() return {sync=function() end} end,close=function() closed=closed+1 end}
local reports={}
local installed=Compact.install(native,{read=function() return stored end,inGame=function() return inGame end,
    clock=function() tick=tick+1;return tick end,
    pause=function() return pause end,findMaterial=function() return 'material' end,
    report=function(e,d) reports[#reports+1]=e..' '..d end})
local game=menu()
local actions=native.new('pc','tree',game.overlay,{construct=function(path) return widget(path:match('UMG%.(.+)$')) end})
assert(game.backdrop.content.kind=='BackgroundBlur','built under a compact style in a game')
actions:sync('browser')
assert(game.page.Slot.Padding.Left==48 and pause.opacity==0,'the mod list looks compact')
actions:sync('dialog')
assert(game.page.Slot.Padding.Left==48,'a dialog keeps it')
actions:sync('settings')
assert(game.page.Slot.Padding.Left==164 and pause.opacity==1,'index: a settings page keeps DMM\'s look')
actions:sync('browser');native.close()
assert(closed==1 and pause.opacity==1,'closing restores the pause menu')
assert(installed.columns()==1 and installed.applies('index') and not installed.applies('settings'),
    'index: one column, compact on the mod list only')
stored='[Modules]\nCompactStyle=everywhere\n'
assert(installed.applies('index') and installed.applies('settings'),'everywhere: settings pages too')
stored='[Modules]\nCompactStyle=index\n'
inGame=false
local main=menu()
native.new('pc','tree',main.overlay,{construct=function(path) return widget(path:match('UMG%.(.+)$')) end})
assert(main.backdrop.content==main.outer and installed.columns()==nil and not installed.applies('index'),
    'the main menu keeps DMM\'s look and columns')
inGame,stored=true,'[Modules]\nCompactStyle=off\n'
local off=menu()
native.new('pc','tree',off.overlay,{})
assert(off.backdrop.content==off.outer and installed.columns()==nil,'off keeps DMM\'s look and columns')
assert(#reports==0,table.concat(reports,'; '))
print('PASS compact style: the pause menu\'s look and a one-column list in a loaded game')

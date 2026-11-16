-- Use Compact Style ([Modules] CompactStyle): in a loaded game, the mod menu takes the
-- pause menu's look instead of its own full-screen background. The game shows blurred
-- behind it, tinted, with the pause menu's dark panel down the left; the page starts close
-- to the top left, inside the panel, and the mod list is one column. Index applies it to the
-- mod list only, Everywhere to every page; Off, and the main menu, keep DMM's look.
--
-- DMM builds its menu as: a root Border (backdrop) holding an Overlay (outer) with its
-- background picture and a ScaleBox fitting its 1920 by 1080 design. When the menu opens
-- with a compact style, before it reaches the screen, a BackgroundBlur goes between the
-- backdrop and outer, and outer takes the tint and the panel (in a design-sized ScaleBox of
-- its own) under DMM's design. Each page then switches between the two looks. The pause
-- menu stays drawn under the mod menu, so it is hidden while the compact look shows and
-- shown again when the mod menu closes.
local M={version=1}

-- The pause menu's look (WBP_PauseMenu, checked live 2026-11-16): blur strength 5, a 20%
-- black tint, and a panel 1700 of its 3840-wide design (850 of DMM's 1920) holding
-- MI_UI_Pause_Background. Without the material the panel is a plain dark one.
M.BLUR,M.TINT,M.PANEL_WIDTH=5,{R=0,G=0,B=0,A=0.2},850
M.PANEL_MATERIAL='/Game/_Dawnwalker/UI/_Unified/PauseMenu/Materials/MI_UI_Pause_Background.MI_UI_Pause_Background'
M.PANEL_FALLBACK={R=0.01,G=0.01,B=0.012,A=0.6}
-- Where DMM's page starts (its design's left and top padding), and where it starts compact,
-- drawn at PAGE_SCALE from its top left.
M.PAGE_LEFT,M.PAGE_TOP,M.COMPACT_LEFT,M.COMPACT_TOP,M.PAGE_SCALE=164,76,48,40,0.8
-- DMM's vertical dividers between a page's columns: boxes this size, hidden while compact.
M.DIVIDER={X=20,Y=660}
local DESIGN={X=1920,Y=1080}

-- config.ini's [Modules] CompactStyle: off, index or everywhere (off when unset or unknown).
function M.style(text)
    local Ini=require('mc_ini')
    local ok,entry=pcall(function() return Ini.entries(Ini.parse(text or ''),'Modules','CompactStyle')[1] end)
    local value=ok and entry and entry.value:match('^%s*(.-)%s*$')
    return (value=='index' or value=='everywhere') and value or 'off'
end
-- Whether a page in scope (DMM's 'browser', 'settings' or 'dialog') looks compact under
-- style. A dialog keeps the page's look.
function M.compact(style,scope,current)
    if scope=='dialog' then return current end
    return style=='everywhere' or style=='index' and scope=='browser'
end

local function valid(widget) return widget~=nil and widget:IsValid() and widget or nil end

-- Builds the compact layers into DMM's menu (see the top); returns a look with :show(on).
-- api: construct(classPath,outer), findMaterial(path), pause() -> the pause menu or nil.
function M.build(overlay,tree,api)
    local design=assert(valid(overlay:GetParent()),'DMM design box')
    local scale=assert(valid(design:GetParent()),'DMM design scale')
    local outer=assert(valid(scale:GetParent()),'DMM root overlay')
    local backdrop=assert(valid(outer:GetParent()),'DMM backdrop')
    local background=assert(valid(outer:GetChildAt(0)),'DMM background')
    local function new(kind) return api.construct('/Script/UMG.'..kind,tree) end
    local blur=new('BackgroundBlur')
    blur:SetBlurStrength(0)
    blur:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
    blur:SetHorizontalAlignment(0);blur:SetVerticalAlignment(0)
    assert(backdrop:SetContent(blur),'compact blur')
    assert(blur:SetContent(outer),'compact root')
    local tint=new('Border')
    tint:SetBrushColor(M.TINT)
    local panelScale,panelDesign,panelOverlay,panelBox,panel=new('ScaleBox'),new('SizeBox'),new('Overlay'),new('SizeBox'),new('Border')
    panelScale:SetStretch(2)
    panelDesign:SetWidthOverride(DESIGN.X);panelDesign:SetHeightOverride(DESIGN.Y)
    panelBox:SetWidthOverride(M.PANEL_WIDTH)
    local material=api.findMaterial and api.findMaterial(M.PANEL_MATERIAL)
    if material then panel:SetBrushFromMaterial(material) else panel:SetBrushColor(M.PANEL_FALLBACK) end
    assert(panelBox:SetContent(panel),'compact panel')
    local boxSlot=assert(panelOverlay:AddChildToOverlay(panelBox),'compact panel box')
    boxSlot:SetHorizontalAlignment(1);boxSlot:SetVerticalAlignment(0)
    assert(panelDesign:SetContent(panelOverlay),'compact panel design')
    assert(panelScale:SetContent(panelDesign),'compact panel scale')
    -- Under DMM's design: it leaves outer and comes back after the tint and the panel.
    scale:RemoveFromParent()
    for _,layer in ipairs({tint,panelScale,scale}) do
        local slot=assert(outer:AddChildToOverlay(layer),'compact layer')
        slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
    end
    local backdropColor,backgroundShown=backdrop.BrushColor,background:GetVisibility()
    backdropColor={R=backdropColor.R,G=backdropColor.G,B=backdropColor.B,A=backdropColor.A}
    local look={on=nil,page=nil,pause=nil,dividers=nil}
    -- Every SizeBox under widget the divider's size, depth first.
    local function dividers(widget,found)
        found=found or {}
        local ok,width=pcall(function() return widget.WidthOverride end)
        if ok and width==M.DIVIDER.X and widget.HeightOverride==M.DIVIDER.Y then found[#found+1]=widget end
        local counted,count=pcall(function() return widget:GetChildrenCount() end)
        if counted and type(count)=='number' and count>0 then
            for index=0,count-1 do dividers(widget:GetChildAt(index),found) end
        else
            local held,content=pcall(function() return widget:GetContent() end)
            if held and content and valid(content) then dividers(content,found) end
        end
        return found
    end
    -- The page's slot in DMM's design, found once DMM has added it.
    local function pageSlot()
        if look.page then return look.page end
        for index=0,overlay:GetChildrenCount()-1 do
            local slot=overlay:GetChildAt(index).Slot
            local padding=slot and slot.Padding
            if padding and padding.Left==M.PAGE_LEFT and padding.Top==M.PAGE_TOP then
                look.page,look.pageWidget=slot,overlay:GetChildAt(index)
                return slot
            end
        end
    end
    function look:show(on)
        if self.on==on then return end
        self.on=on
        backdrop:SetBrushColor(on and {R=backdropColor.R,G=backdropColor.G,B=backdropColor.B,A=0} or backdropColor)
        background:SetVisibility(on and 1 or backgroundShown)
        blur:SetBlurStrength(on and M.BLUR or 0)
        tint:SetVisibility(on and 3 or 1)
        panelScale:SetVisibility(on and 3 or 1)
        local slot=pageSlot()
        if slot then
            local p=slot.Padding
            slot:SetPadding({Left=on and M.COMPACT_LEFT or M.PAGE_LEFT,Top=on and M.COMPACT_TOP or M.PAGE_TOP,
                Right=p.Right,Bottom=p.Bottom})
            local page=self.pageWidget
            if page then
                page:SetRenderTransformPivot({X=0,Y=0})
                page:SetRenderScale({X=on and M.PAGE_SCALE or 1,Y=on and M.PAGE_SCALE or 1})
                self.dividers=self.dividers or dividers(page)
                for _,divider in ipairs(self.dividers) do divider:SetVisibility(on and 2 or 4) end
            end
        end
        -- The pause menu under the mod menu: hidden while compact, its opacity kept.
        local pause=self.pause or (api.pause and api.pause())
        if pause and valid(pause) then
            if on and not self.pause then self.pause,self.pauseOpacity=pause,pause:GetRenderOpacity() end
            if self.pause then self.pause:SetRenderOpacity(on and 0 or self.pauseOpacity) end
        end
    end
    -- The mod menu closing: the pause menu shows again.
    function look:close()
        if self.pause and valid(self.pause) then self.pause:SetRenderOpacity(self.pauseOpacity) end
        self.pause=nil
    end
    look:show(false)
    return look
end

-- native: DMM's nativeactions module (new(pc,tree,overlay,api) per menu, close() when it
-- closes). options: read() -> config.ini text, inGame() -> whether a game is loaded, clock()
-- (os.time by default),
-- pause() -> the pause menu, findMaterial(path), report(event,detail).
function M.install(native,options)
    assert(type(native)=='table' and type(native.new)=='function','DMM native actions unavailable')
    local report=options.report or function() end
    local look
    local new,close=native.new,native.close
    native.new=function(pc,tree,overlay,api,...)
        look=nil
        local actions=new(pc,tree,overlay,api,...)
        local style='off'
        local ok,why=pcall(function()
            style=M.style(options.read())
            if style=='off' or not (options.inGame and options.inGame()) then style='off';return end
            look=M.build(overlay,tree,{construct=api and api.construct or function(path,outer)
                return StaticConstructObject(StaticFindObject(path),outer) end,
                findMaterial=options.findMaterial,pause=options.pause})
        end)
        if not ok then look=nil;report('COMPACT_STYLE_FAILED',tostring(why)) end
        local sync=actions and actions.sync
        if look and type(sync)=='function' then
            local current=false
            function actions:sync(scope,...)
                local shown,err=pcall(function()
                    current=M.compact(style,scope,current)
                    look:show(current)
                end)
                if not shown then report('COMPACT_STYLE_FAILED',tostring(err)) end
                return sync(self,scope,...)
            end
        end
        return actions
    end
    if type(close)=='function' then
        native.close=function(...)
            if look then pcall(look.close,look) end
            look=nil
            return close(...)
        end
    end
    -- The style now in a loaded game ('off' outside one), read at most once a second: page
    -- builds ask for every row.
    local readAt,current
    local function now()
        local time=(options.clock or os.time)()
        if readAt~=time then
            readAt=time
            local ok,style=pcall(function() return M.style(options.read()) end)
            current=ok and style or 'off'
            if current~='off' and not (options.inGame and options.inGame()) then current='off' end
        end
        return current
    end
    return {
        -- Whether the mod list is one column now: a compact style in a loaded game.
        columns=function() return now()~='off' and 1 or nil end,
        -- Whether the compact style applies to the mod list ('index') or to settings pages
        -- ('settings') now.
        applies=function(kind)
            local style=now()
            if kind=='index' then return style~='off' end
            return style=='everywhere'
        end,
    }
end

return M

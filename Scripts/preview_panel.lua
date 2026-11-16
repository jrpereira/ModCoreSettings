-- A live preview in a settings page's side panel. A page whose menu data declares
-- preview={background=<picture path>} gets, while it is shown, a 16:9 area at the bottom of
-- the side panel: the background picture, and over it a screen-sized host scaled down to
-- fit, which the page's provider fills (ModCore Templates attaches the page's templates to
-- it). The description scrolls above it.
--
-- The provider is told through shared variables and a console command, as ModCore events
-- are:
--   MCS.Preview.v1.host    the host widget: an Overlay PREVIEW_SCREEN pixels in size
--   MCS.Preview.v1.state   '<revision> open <page id>' or '<revision> closed <page id>'
--   MCS.Preview.v1.values  '<revision>\n' then one 'id=value' line per setting, the page's
--                          current values, applied or not
--   MCS.Preview.v1.sound   'auto', 'on' or 'off': the preview's sound button
--   MCS.Preview.v1.focus   the selected setting's id, or ''
-- then runs the console command MCS_Preview_v1. Values are republished whenever one changes.
local M={version=1}

M.SCREEN={width=1920,height=1080}
M.COMMAND='MCS_Preview_v1'
M.HOST,M.STATE,M.VALUES='MCS.Preview.v1.host','MCS.Preview.v1.state','MCS.Preview.v1.values'
M.SOUND,M.FOCUS='MCS.Preview.v1.sound','MCS.Preview.v1.focus'
-- The sound button's states, in click order: auto lets the provider decide (Preymonition
-- plays its sounds while a sound setting is selected), on always, off never.
M.SOUNDS={'auto','on','off'}
local SOUND_LABELS={auto='Sound: Auto',on='Sound: On',off='Sound: Off'}
-- The preview in DMM's 1280-wide page: 16:9, as wide as the description inside the side
-- panel's 630 (its 40 and 12 margins leave 578), its bottom PREVIEW_BOTTOM above the
-- panel's; the description keeps PREVIEW_GAP above it.
local PREVIEW_WIDTH,PREVIEW_HEIGHT,PREVIEW_BOTTOM,PREVIEW_GAP=576,324,20,16

-- One 'id=value' line per setting with an id; values as text, numbers without trailing zeros.
function M.encode(model)
    local lines={}
    for i,item in ipairs(model and model.items or {}) do
        local value=model.pending[i]
        if item.id and value~=nil then
            if type(value)=='number' then value=(value%1==0) and string.format('%d',value) or tostring(value) end
            value=tostring(value)
            if not value:find('[\r\n]') then lines[#lines+1]=item.id..'='..value end
        end
    end
    return table.concat(lines,'\n')
end

-- options: shared (ModRef), texture(path) -> UTexture2D or nil, report(event,detail),
-- exec(command) runs a console command (through the player's viewport by default),
-- sound {state=} kept between page builds.
function M.wrap(page,providers,api,options)
    if type(page)~='table' or type(page.controls)~='table' or not page.detailScroll then return page end
    local shared,report=options.shared,options.report or function() end
    local function new(kind) return api.construct('/Script/UMG.'..kind,options.tree) end
    local controls=page.controls
    local revision=0
    local current,shownValues=nil,nil
    local box,preview,background,host
    local sound=options.sound or {state='auto'}
    local soundButton,soundLabel,soundWasPressed
    local focus

    -- The side panel: the description's scroll, and the preview at its bottom.
    local function build()
        if box then return true end
        local panel=page.detailScroll:GetParent()
        if not panel then return false end
        local stack=new('Overlay')
        api.need(panel:SetContent(stack),'MCS preview panel')
        local scrollSlot=stack:AddChildToOverlay(page.detailScroll)
        scrollSlot:SetHorizontalAlignment(0);scrollSlot:SetVerticalAlignment(0)
        preview=new('SizeBox');preview:SetWidthOverride(PREVIEW_WIDTH);preview:SetHeightOverride(PREVIEW_HEIGHT)
        preview:SetClipping(1)
        local frame=new('Overlay')
        api.need(preview:SetContent(frame),'MCS preview frame')
        background=new('Image')
        local backgroundSlot=frame:AddChildToOverlay(background)
        backgroundSlot:SetHorizontalAlignment(0);backgroundSlot:SetVerticalAlignment(0)
        local scale=new('ScaleBox');scale:SetStretch(2)
        local scaleSlot=frame:AddChildToOverlay(scale)
        scaleSlot:SetHorizontalAlignment(0);scaleSlot:SetVerticalAlignment(0)
        local screen=new('SizeBox');screen:SetWidthOverride(M.SCREEN.width);screen:SetHeightOverride(M.SCREEN.height)
        api.need(scale:SetContent(screen),'MCS preview scale')
        host=new('Overlay')
        api.need(screen:SetContent(host),'MCS preview host')
        -- The sound button, top right over the preview.
        if api.button then
            soundButton,soundLabel=api.button(options.tree,SOUND_LABELS[sound.state])
            soundButton.IsFocusable=false
            local soundSlot=frame:AddChildToOverlay(soundButton)
            soundSlot:SetHorizontalAlignment(3);soundSlot:SetVerticalAlignment(1)
            soundSlot:SetPadding({Left=0,Top=6,Right=6,Bottom=0})
        end
        local previewSlot=stack:AddChildToOverlay(preview)
        previewSlot:SetHorizontalAlignment(2);previewSlot:SetVerticalAlignment(3)
        previewSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=PREVIEW_BOTTOM})
        preview:SetVisibility(1)
        box=scrollSlot
        return true
    end
    local function publish(state,id)
        revision=revision+1
        if not shared then return end
        shared:SetSharedVariable(M.SOUND,sound.state)
        shared:SetSharedVariable(M.HOST,state=='open' and host or nil)
        shared:SetSharedVariable(M.STATE,string.format('%d %s %s',revision,state,id))
        local exec=options.exec
        if exec then pcall(exec,M.COMMAND) end
    end
    -- The selected setting, for a provider's auto sound.
    local function focused()
        local model=controls.model
        local item=model and model.items and controls.current and model.items[controls.current]
        return item and item.id or ''
    end
    local function values(force)
        if not current then return end
        local now=focused()
        if now~=focus then
            focus=now
            if shared then shared:SetSharedVariable(M.FOCUS,now) end
            force=true
        end
        local text=M.encode(controls.model)
        if not force and text==shownValues then return end
        shownValues=text
        revision=revision+1
        if shared then
            shared:SetSharedVariable(M.VALUES,revision..'\n'..text)
            if options.exec then pcall(options.exec,M.COMMAND) end
        end
    end
    local function close()
        if not current then return end
        local id=current
        current,shownValues=nil,nil
        if preview then preview:SetVisibility(1) end
        if box then box:SetPadding({Left=0,Top=0,Right=0,Bottom=0}) end
        local ok,err=pcall(publish,'closed',id)
        if not ok then report('PREVIEW_FAILED',tostring(err)) end
    end
    local function open(index)
        local provider=providers[index]
        local spec=provider and provider.mcPreview
        if not spec then close();return end
        local ok,err=pcall(function()
            assert(build(),'side panel unavailable')
            if current~=provider.id then close() end
            if spec.background and options.texture then
                local texture=options.texture(spec.background)
                if texture then background:SetBrushFromTexture(texture,false);background:SetVisibility(4)
                else background:SetVisibility(1) end
            end
            preview:SetVisibility(4)
            box:SetPadding({Left=0,Top=0,Right=0,Bottom=PREVIEW_HEIGHT+PREVIEW_BOTTOM+PREVIEW_GAP})
            current=provider.id
            values(true)
            publish('open',provider.id)
        end)
        if not ok then report('PREVIEW_FAILED',tostring(provider.id)..': '..tostring(err)) end
    end
    local show,hide,tick=controls.show,controls.hide,controls.tick
    function controls:show(index,...)
        local results=table.pack(show(self,index,...))
        open(index)
        return table.unpack(results,1,results.n)
    end
    if type(hide)=='function' then
        function controls:hide(...)
            close()
            return hide(self,...)
        end
    end
    if type(tick)=='function' then
        function controls:tick(...)
            local results=table.pack(tick(self,...))
            if current then
                local ok,err=pcall(values,false)
                if not ok then report('PREVIEW_FAILED',tostring(err)) end
                -- A click on the sound button moves it to its next state.
                if soundButton then
                    local pressed=soundButton:IsPressed()==true
                    if soundWasPressed and not pressed and soundButton:IsHovered()==true then
                        local index=1
                        for n,state in ipairs(M.SOUNDS) do if state==sound.state then index=n end end
                        sound.state=M.SOUNDS[index%#M.SOUNDS+1]
                        if api.setText then api.setText(soundLabel,SOUND_LABELS[sound.state]) end
                        if shared then
                            shared:SetSharedVariable(M.SOUND,sound.state)
                            if options.exec then pcall(options.exec,M.COMMAND) end
                        end
                    end
                    soundWasPressed=pressed
                end
            end
            return table.unpack(results,1,results.n)
        end
    end
    page.mcPreview={close=close,host=function() return host end}
    return page
end

-- options as for wrap; tree and api come from each build.
function M.install(pages,options)
    assert(type(pages)=='table' and type(pages.build)=='function','DMM pages API unavailable')
    if pages.mcPreviewVersion then return false end
    local build=pages.build
    -- The sound button's state lasts the session.
    local sound={state='auto'}
    pages.build=function(tree,providers,status,api)
        local page=build(tree,providers,status,api)
        local own={}
        for key,value in pairs(options or {}) do own[key]=value end
        own.tree=tree
        own.sound=sound
        local ok,result=pcall(M.wrap,page,providers,api,own)
        if not ok then
            if own.report then own.report('PREVIEW_FAILED',tostring(result)) end
            return page
        end
        return result
    end
    pages.mcPreviewVersion=M.version
    return true
end

return M

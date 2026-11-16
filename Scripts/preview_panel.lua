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
-- The focus button's: on blurs the background picture, so what the provider draws over it
-- stands out.
M.FOCUSES={'off','on'}
local VALUE_LABELS={auto='Auto',on='On',off='Off'}
-- The preview in DMM's 1280-wide page: 16:9, as wide as the description inside the side
-- panel's 630 (its 40 and 12 margins leave 578), starting where the header and description
-- text do, PREVIEW_LEFT in; its bottom PREVIEW_BOTTOM above the panel's; the description
-- keeps PREVIEW_GAP above it.
local PREVIEW_WIDTH,PREVIEW_HEIGHT,PREVIEW_BOTTOM,PREVIEW_GAP,PREVIEW_LEFT=576,324,68,16,40
-- Under the preview's right end, SOUND_GAP below it: the sound button, SOUND_SHIFT past
-- the preview's right edge, and the focus button left of it. Each sits in a box of fixed
-- size, its text left-aligned, so the value changing never moves it. A button reads
-- '<name>: <value>': the name PREFIX_OPACITY opaque; On and Auto bright white and bold, Off
-- italic and PREFIX_OPACITY opaque. BLUR is the focused background's blur strength.
local SOUND_WIDTH,SOUND_HEIGHT,SOUND_GAP,SOUND_SHIFT,FOCUS_WIDTH=150,32,6,20,140
local PREFIX_OPACITY,VALUE_GAP,BLUR=0.7,6,12
local WHITE={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0}

-- The face of a label's font whose name holds word ('bold', 'italic'), or '' when it has
-- none; looked up once per font.
local faces={}
local function faceName(value)
    if value==nil then return '' end
    return type(value)=='string' and value or value:ToString()
end
local function faceWith(font,word)
    local key=''
    pcall(function() key=font.FontObject:GetFullName() end)
    key=key..'|'..word
    if faces[key]==nil then
        local found=''
        pcall(function()
            local entries=font.FontObject.CompositeFont.DefaultTypeface.Fonts
            local function inspect(entry)
                pcall(function() entry=entry:get() end)
                local name=faceName(entry.Name)
                local lower=name:lower()
                -- The plainest match: Bold before Bold Italic, Italic before Bold Italic.
                if lower:find(word,1,true) and (found=='' or #name<#found) then found=name end
            end
            if type(entries)=='table' then for _,entry in ipairs(entries) do inspect(entry) end
            else entries:ForEach(function(_,entry) inspect(entry) end) end
        end)
        faces[key]=found
    end
    return faces[key]
end

-- One 'id=value' line per setting with an id; values as text, numbers without trailing zeros,
-- a keyed picker's as its key.
function M.encode(model)
    local lines={}
    for i,item in ipairs(model and model.items or {}) do
        local value=model.pending[i]
        -- A keyed picker's model holds the choice's position; the provider gets its key.
        if item.mcKeys and type(value)=='number' then value=item.mcKeys[value] end
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
    local focusing=options.focus or {state='off'}
    local buttons={}
    local blur
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
        -- Focus blurs the picture behind it, not what the host draws over it.
        blur=new('BackgroundBlur')
        blur:SetBlurStrength(BLUR)
        local blurSlot=frame:AddChildToOverlay(blur)
        blurSlot:SetHorizontalAlignment(0);blurSlot:SetVerticalAlignment(0)
        blur:SetVisibility(focusing.state=='on' and 4 or 1)
        local scale=new('ScaleBox');scale:SetStretch(2)
        local scaleSlot=frame:AddChildToOverlay(scale)
        scaleSlot:SetHorizontalAlignment(0);scaleSlot:SetVerticalAlignment(0)
        local screen=new('SizeBox');screen:SetWidthOverride(M.SCREEN.width);screen:SetHeightOverride(M.SCREEN.height)
        api.need(scale:SetContent(screen),'MCS preview scale')
        host=new('Overlay')
        api.need(screen:SetContent(host),'MCS preview host')
        local previewSlot=stack:AddChildToOverlay(preview)
        previewSlot:SetHorizontalAlignment(1);previewSlot:SetVerticalAlignment(3)
        previewSlot:SetPadding({Left=PREVIEW_LEFT,Top=0,Right=0,Bottom=PREVIEW_BOTTOM})
        preview:SetVisibility(1)
        -- The focus and sound buttons, under the preview's right end.
        if api.button then
            local soundLeft=PREVIEW_LEFT+PREVIEW_WIDTH-SOUND_WIDTH+SOUND_SHIFT
            for _,spec in ipairs({
                {name='Focus',states=M.FOCUSES,kept=focusing,width=FOCUS_WIDTH,left=soundLeft-FOCUS_WIDTH},
                {name='Sound',states=M.SOUNDS,kept=sound,width=SOUND_WIDTH,left=soundLeft}}) do
                local button,label=api.button(options.tree,'')
                button.IsFocusable=false
                -- '<name>:' and the value, two texts in the button's own font, left-aligned.
                local line=new('HorizontalBox')
                local lineSlot=api.need(button:SetContent(line),'MCS preview button text')
                lineSlot:SetHorizontalAlignment(1);lineSlot:SetVerticalAlignment(2)
                local prefix,value=new('TextBlock'),new('TextBlock')
                for _,text in ipairs({prefix,value}) do
                    text:SetFont(label.Font)
                    if api.Theme then pcall(api.Theme.textColor,text,'body') end
                end
                prefix:SetText(FText and FText(spec.name..':') or spec.name..':')
                prefix:SetRenderOpacity(PREFIX_OPACITY)
                line:AddChildToHorizontalBox(prefix):SetVerticalAlignment(2)
                local valueSlot=line:AddChildToHorizontalBox(value)
                valueSlot:SetVerticalAlignment(2)
                valueSlot:SetPadding({Left=VALUE_GAP,Top=0,Right=0,Bottom=0})
                local box=new('SizeBox');box:SetWidthOverride(spec.width);box:SetHeightOverride(SOUND_HEIGHT)
                api.need(box:SetContent(button),'MCS preview button')
                local slot=stack:AddChildToOverlay(box)
                slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(3)
                slot:SetPadding({Left=spec.left,Top=0,Right=0,Bottom=PREVIEW_BOTTOM-SOUND_GAP-SOUND_HEIGHT})
                box:SetVisibility(1)
                local entry={spec=spec,button=button,value=value,box=box,
                    base={face=faceName(value.Font.TypefaceFontName),skew=tonumber(value.Font.SkewAmount) or 0,
                        color=value.ColorAndOpacity}}
                buttons[#buttons+1]=entry
                M.styleValue(entry,spec.kept.state)
            end
        end
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
        for _,entry in ipairs(buttons) do entry.box:SetVisibility(1) end
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
            -- Without a picture, or one that cannot be read, nothing shows behind the
            -- host: an Image without a texture would draw a white box.
            local texture=spec.background and options.texture and options.texture(spec.background)
            if texture then background:SetBrushFromTexture(texture,false);background:SetVisibility(4)
            else background:SetVisibility(1) end
            preview:SetVisibility(4)
            for _,entry in ipairs(buttons) do entry.box:SetVisibility(4) end
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
                -- A click on a button moves it to its next state.
                for _,entry in ipairs(buttons) do
                    local button,spec=entry.button,entry.spec
                    local pressed=button:IsPressed()==true
                    if entry.wasPressed and not pressed and button:IsHovered()==true then
                        local index=1
                        for n,state in ipairs(spec.states) do if state==spec.kept.state then index=n end end
                        spec.kept.state=spec.states[index%#spec.states+1]
                        local styled,why=pcall(M.styleValue,entry,spec.kept.state)
                        if not styled then report('PREVIEW_FAILED',tostring(why)) end
                        if spec.name=='Focus' then
                            if blur then blur:SetVisibility(spec.kept.state=='on' and 4 or 1) end
                        elseif shared then
                            shared:SetSharedVariable(M.SOUND,sound.state)
                            if options.exec then pcall(options.exec,M.COMMAND) end
                        end
                    end
                    entry.wasPressed=pressed
                end
            end
            return table.unpack(results,1,results.n)
        end
    end
    page.mcPreview={close=close,host=function() return host end}
    return page
end

-- Shows a button's value for state: On and Auto bright white in the font's bold face;
-- Off in its italic face (or slanted, without one) and PREFIX_OPACITY opaque.
function M.styleValue(entry,state)
    local value,base=entry.value,entry.base
    value:SetText(FText and FText(VALUE_LABELS[state]) or VALUE_LABELS[state])
    local font=value.Font
    local off=state=='off'
    local face=faceWith(font,off and 'italic' or 'bold')
    if face=='' then face=base.face end
    font.TypefaceFontName=FName and FName(face) or face
    font.SkewAmount=(off and faceWith(font,'italic')=='') and base.skew+0.2 or base.skew
    value:SetFont(font)
    if off then
        if base.color then value:SetColorAndOpacity(base.color) end
        value:SetRenderOpacity(PREFIX_OPACITY)
    else
        value:SetColorAndOpacity(WHITE)
        value:SetRenderOpacity(1)
    end
end

-- options as for wrap; tree and api come from each build.
function M.install(pages,options)
    assert(type(pages)=='table' and type(pages.build)=='function','DMM pages API unavailable')
    if pages.mcPreviewVersion then return false end
    local build=pages.build
    -- The sound and focus buttons' states last the session.
    local sound,focus={state='auto'},{state='off'}
    pages.build=function(tree,providers,status,api)
        local page=build(tree,providers,status,api)
        local own={}
        for key,value in pairs(options or {}) do own[key]=value end
        own.tree=tree
        own.sound=sound
        own.focus=focus
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

-- Presentation only: DMM owns dirty state, pending values, Apply and Restore.
local Discovery=require('widget_discovery')
local M={}
local Protocols=require('mcs_protocols')
local PREFIX=Protocols.dirty
local SIGNAL=Protocols.valueDirty
local function encode(s) return (s:gsub('%%','%%25'):gsub('\n','%%0A'):gsub('\r','%%0D')) end
local function decode(s) return (s:gsub('%%(%x%x)',function(h) return string.char(tonumber(h,16)) end)) end
local function name(value) return type(value)=='string' and value or value:ToString() end

function M.signal(text,setting)
    local function clean(value)
        if not setting then return false end
        if setting.kind=='slider' then
            local prefix,suffix=setting.prefix or '',setting.suffix or ''
            if value:sub(1,#prefix)~=prefix or (#suffix>0 and value:sub(-#suffix)~=suffix) then return false end
            local number=tonumber(value:sub(#prefix+1,#value-#suffix))
            return number and number==number and math.abs(number)<=1000000000
                and prefix..string.format('%.'..setting.decimals..'f',number)..suffix==value
        end
        for _,label in ipairs(setting.labels or {}) do if value==label then return true end end
        return false
    end
    if clean(text) then return false,text end -- Literal '*' in a schema label/suffix.
    local value=text:gsub('%s+%*%s*$','')
    if value~=text and clean(value) then return true,value end
    return false,text -- Unknown/unavailable/localized text is never guessed dirty.
end
local function parseMarker(text)
    local fields={}
    for line in text:sub(#PREFIX+1):gmatch('([^\n]*)\n') do fields[#fields+1]=line end
    assert(#fields==10 or #fields==11,'invalid dirty-label state')
    return {dirty=fields[1]=='1',base=decode(fields[2]),face=decode(fields[3]),
        skew=assert(tonumber(fields[4])),italic=decode(fields[5]),italicSkew=assert(tonumber(fields[6])),suppressed=fields[7]=='1',pending=decode(fields[8]),lastValue=decode(fields[9]),rendered=fields[10],signal=decode(fields[11] or '')}
end
local function parseSignal(raw)
    local flag,clean=raw:sub(#SIGNAL+1):match('^([01])\n(.*)$')
    assert(flag,'invalid dirty-value signal')
    return {dirty=flag=='1',clean=clean,raw=raw}
end
-- The shell's dirty-state marker and DMM's value signal, read in one pass over its
-- children: marker widget, its state, then the signal (each nil when absent).
local function readShell(shell)
    local marker,state,signal
    for i=0,Discovery.childCount(shell)-1 do
        local child=Discovery.childAt(shell,i)
        if Discovery.isTextBlock(child) then
            local text=Discovery.textOf(child) or ''
            if not marker and text:sub(1,#PREFIX)==PREFIX then marker,state=child,parseMarker(text)
            elseif not signal and text:sub(1,#SIGNAL)==SIGNAL then signal=parseSignal(text) end
            if marker and signal then break end
        end
    end
    return marker,state,signal
end
local function readMarker(shell)
    local marker,state=readShell(shell)
    return marker,state
end
-- ModCoreSettings' presentation places the star right after the label text, in
-- the box both share. A row without one shows only the italic label.
local function starOf(label)
    local line=Discovery.parentOf(label)
    if Discovery.className(line)~='HorizontalBox' then return nil end
    local labelAddress=Discovery.address(label)
    for i=0,Discovery.childCount(line)-1 do
        local child=Discovery.childAt(line,i)
        if Discovery.isTextBlock(child) and Discovery.address(child)~=labelAddress
            and Discovery.textOf(child)=='*' then return child end
    end
end
local function serialized(state)
    return PREFIX..table.concat({state.dirty and '1' or '0',encode(state.base),encode(state.face),
        tostring(state.skew),encode(state.italic),tostring(state.italicSkew),state.suppressed and '1' or '0',encode(state.pending or ''),encode(state.lastValue or ''),state.rendered or '',encode(state.signal or '')},'\n')..'\n'
end
local function styleState(label,dirty)
    local font=label.Font
    local state={dirty=dirty,base=Discovery.textOf(label),
        face=name(font.TypefaceFontName),skew=tonumber(font.SkewAmount) or 0,italic=''}
    -- Prefer a real italic face in the existing font. Some fonts provide only a
    -- regular face; Slate's font skew supplies the same slanted presentation.
    pcall(function()
        local entries=font.FontObject.CompositeFont.DefaultTypeface.Fonts
        local best=0
        local function inspect(entry)
            pcall(function() entry=entry:get() end)
            local face=name(entry.Name)
            local key=face:lower()
            if key:find('italic',1,true) or key:find('oblique',1,true) then
                local rank=(key:find('bold',1,true) or key:find('black',1,true)) and 1 or 2
                if rank>best then best=rank;state.italic=face end
            end
        end
        if type(entries)=='table' then for _,entry in ipairs(entries) do inspect(entry) end
        else entries:ForEach(function(_,entry) inspect(entry) end) end
    end)
    state.italicSkew=state.italic~='' and state.skew or state.skew+0.2
    return state
end

function M.new(log)
    local controller={records={},busy=false}
    local function displayed(state) return state.dirty and not state.suppressed end
    local textLibrary
    local function setText(widget,text)
        if Discovery.textOf(widget)==text then return end
        if not Discovery.valid(textLibrary) then textLibrary=StaticFindObject('/Script/Engine.Default__KismetTextLibrary') end
        assert(Discovery.valid(textLibrary),'text library unavailable')
        widget:SetText(textLibrary:Conv_StringToText(text))
    end
    local function render(label,state,dirty,shell)
        -- Presentation metadata may change a label while the same row lives.
        state.base=Discovery.textOf(label) or state.base
        local presentation=dirty and '1' or '0'
        if state.rendered==presentation then return end
        setText(label,state.base)
        local star=starOf(label)
        if star then star:SetVisibility(dirty and 4 or 2) end -- Hit-test invisible / hidden; label layout never changes.
        local face=dirty and state.italic~='' and state.italic or state.face
        local skew=dirty and state.italicSkew or state.skew
        local font=label.Font
        if name(font.TypefaceFontName)~=face or tonumber(font.SkewAmount)~=skew then
            local previousFace,previousSkew=font.TypefaceFontName,font.SkewAmount
            font.TypefaceFontName=FName(face);font.SkewAmount=skew
            local ok,err=pcall(label.SetFont,label,font)
            if not ok then font.TypefaceFontName=previousFace;font.SkewAmount=previousSkew;error(err) end
        end
        state.rendered=presentation
        setText(assert(readMarker(shell)),serialized(state))
    end
    local function protected(fn)
        if controller.busy then return end
        controller.busy=true
        local ok,result=pcall(fn)
        controller.busy=false
        if not ok then log('DIRTY_LABEL_FAILED',tostring(result)) end
        return ok,result
    end
    local function renderRecord(resolve,record)
        local shell,label=resolve(record.shell),resolve(record.label)
        if not shell or not label then return end
        local _,state=readMarker(shell)
        if not state then return end
        render(label,state,displayed(state),shell)
    end
    function controller:close()
        self.records={};self.path=nil;self.allowed=nil;self.routes=nil;self.live=nil;self.bound=false
    end
    function controller:open(path,allowed,live)
        if self.path==path then
            self.records={};self.allowed=allowed;self.live=live
            self.routes=nil;self.bound=false
            return true
        end
        self:close();self.path=path;self.allowed=allowed;self.live=live
        return true
    end
    function controller:bind(rows,routes)
        protected(function()
            for _,row in ipairs(rows) do
                local shell=row.overlay or row.shell
                -- A level-one row sits in the page title row, which shows no dirty star.
                if not (row.dmmSetting and row.dmmSetting.mcHeader)
                    and Discovery.valid(shell) and Discovery.valid(row.labelWidget)
                    and Discovery.valid(row.valueWidget) then
                    local valueId=Discovery.address(row.valueWidget)
                    local record={value=routes[valueId],label=routes[Discovery.address(row.labelWidget)],
                        shell=routes[Discovery.address(shell)],setting=row.dmmSetting}
                    if record.value and record.label and record.shell then
                        local marker,state,signal=readShell(shell)
                        local dirty,clean
                        if signal then dirty,clean=signal.dirty,signal.clean
                        else dirty,clean=M.signal(Discovery.textOf(row.valueWidget) or '',row.dmmSetting) end
                        if not marker then
                            state=styleState(row.labelWidget,dirty)
                            state.suppressed=false;state.lastValue=clean;state.signal=signal and signal.raw or ''
                            local tree=shell:GetOuter()
                            marker=StaticConstructObject(StaticFindObject('/Script/UMG.TextBlock'),tree)
                            assert(Discovery.valid(marker),'dirty marker construction failed')
                            marker:SetVisibility(1)
                            setText(marker,serialized(state))
                            assert(shell:AddChildToOverlay(marker),'dirty marker attachment failed')
                        else
                            if signal then
                                state.dirty=dirty;state.suppressed=false;state.lastValue=clean;state.signal=signal.raw
                            elseif dirty then
                                state.dirty=true;state.suppressed=false;state.lastValue=clean
                            elseif clean~=state.lastValue then
                                state.dirty=false;state.suppressed=false;state.lastValue=clean
                            end
                            state.pending='';setText(marker,serialized(state))
                        end
                        self.records[valueId]=record
                        setText(row.valueWidget,clean)
                        render(row.labelWidget,state,displayed(state),shell)
                    end
                end
            end
            self.bound=true
            self.routes=routes
        end)
    end
    -- DMM encodes dirty state in the value text. Observe only the rows already
    -- bound on the active settings page; never hook the process-wide SetText path.
    -- Returns how many rows were observed; self.changed is how many of them changed.
    function controller:refresh(host)
        self.changed=0
        if not self.bound or not self.allowed or self.busy then return 0 end
        local ok,count=protected(function()
            if not self.allowed() or (self.live and not self.live()) then return 0 end
            local resolve=Discovery.routeResolver(host,self.allowed)
            if not resolve then return 0 end
            local refreshed,changed=0,0
            for _,record in pairs(self.records) do
                if not self.allowed() then self.changed=changed;return refreshed end
                local widget=resolve(record.value)
                local shell=resolve(record.shell)
                if widget and shell then
                    local marker,state,signal=readShell(shell)
                    if marker and state then
                        local raw=Discovery.textOf(widget) or ''
                        local dirty,clean
                        if signal then dirty,clean=signal.dirty,signal.clean
                        else dirty,clean=M.signal(raw,record.setting) end
                        -- This writes the clean value back. Seeing that same clean
                        -- value on the next tick is not a new DMM notification.
                        if (signal and signal.raw~=state.signal) or (not signal and raw~=state.lastValue) then
                            state.dirty=dirty
                            state.suppressed=not signal and dirty and ((state.pending~='' and state.pending==clean)
                                or (state.suppressed and state.lastValue==clean)) or false
                            state.pending='';state.lastValue=clean;state.signal=signal and signal.raw or ''
                            setText(marker,serialized(state));setText(widget,clean)
                            renderRecord(resolve,record)
                            changed=changed+1
                        end
                        refreshed=refreshed+1
                    end
                end
            end
            self.changed=changed
            return refreshed
        end)
        return ok and count or 0
    end
    return controller
end
return M

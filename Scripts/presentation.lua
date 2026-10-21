-- Runs in DMM's Lua state. Uses its existing menu tick and model, never a timer.
local M={version=1}
local Manifest=require('mcs_manifest')
local Protocols=require('mcs_protocols')
local ChoiceSound=require('mcs_choice_sound')
local dirtySignalPrefix=Protocols.valueDirty
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end
-- The player of choice sounds (mcChoiceSounds); report(event,detail) receives failures.
function M.choiceSoundPlayer(report) return ChoiceSound.player(nil,report) end
local function identityText(value)
    return tostring(value):gsub('%%','%%25'):gsub('\n','%%0A'):gsub('\r','%%0D')
end
local function settingIdentity(index,provider,setting)
    local values,labels=setting.values or {},setting.labels or {}
    assert(#values==#labels and #values<=64,'invalid setting identity choices')
    local fields={Protocols.setting:sub(1,-2),tostring(index),identityText(provider.id),identityText(setting.id),
        setting.kind or '',tostring(setting.minimum or ''),tostring(setting.maximum or ''),
        tostring(setting.step or ''),tostring(setting.decimals or ''),identityText(setting.prefix or ''),
        identityText(setting.suffix or ''),tostring(#values)}
    for _,value in ipairs(values) do fields[#fields+1]=identityText(value) end
    for _,label in ipairs(labels) do fields[#fields+1]=identityText(label) end
    local result=table.concat(fields,'\n')
    assert(#result<=16384,'setting identity exceeds 16 KiB')
    return result
end
-- DMM's settings page widths in its 1920-wide design: rows and the header strip are ROW_WIDTH
-- wide; PAGE_WIDTH is the width of the page itself.
local ROW_WIDTH,PAGE_WIDTH=572,584
-- A mod-list group title's padding in its highlight box (set live against the game).
local HEADER_TITLE_PADDING={Left=-2,Top=6,Right=12,Bottom=-1}
local styles={
    [1]={22,'title'},[2]={16,'muted'},[3]={15,'muted'},
    [4]={14,'body'},[5]={12,'muted'},[6]={11,'muted'},
}
-- A level-2 setting label is larger than a level-2 heading: it names the page's main
-- choice, while the heading groups rows.
local settingLabelSizes={[2]=20}
-- A category heading, as the game's own settings draw theirs: categorySize points,
-- categoryLeft pixels left of the page edge, categoryTop pixels above, and a 1-pixel
-- rule under it. Rows under a category indent rowIndent pixels.
local categorySize,categoryLeft,categoryTop,categoryRuleBottom,rowIndent=18,-2,24,4,10
-- A subgroup's heading (mcWithin): subheadingSize points in the title color, subheadingShift
-- pixels right of the row indent, subheadingTop pixels above, with no rule. Its rows indent
-- nestedIndent pixels further, their labels nestedShrink points smaller.
local subheadingSize,subheadingShift,subheadingTop,nestedIndent,nestedShrink=15,12,10,20,1
-- Subgroup rows are compact (provisional; zero all three to undo): nestedRowShrink pixels
-- shorter, their values nestedValueShrink points smaller. Indicators, notes and slider bars
-- keep their place above the row's bottom; a value gets nestedValueLift more pixels of bottom
-- padding (2 raise it a pixel). 0 keeps it aligned in the game.
local nestedRowShrink,nestedValueShrink,nestedValueLift=4,1,0
-- A subgroup row: one in a subgroup (mcWithin) that shows its heading. A subgroup without
-- a heading reads as its parent's own rows, so its rows are drawn as theirs.
local function subgroupRow(setting)
    return setting.mcGroup~=nil and setting.mcGroup.within~=nil and setting.mcGroup.heading~=false
end
-- A parent heading's place; one drawn for a category sits where its heading would.
local function parentPadding(parent)
    if parent.category then return {Left=categoryLeft,Top=categoryTop,Right=0,Bottom=0} end
    return {Left=0,Top=18,Right=0,Bottom=6}
end
local headerSeparatorDim={R=0.62,G=0.55,B=0.42,A=0.25}
-- Opacity of anything shown faded: a disabled choice, or a row mcDimValues fades.
local fadedOpacity=0.45
local headerSeparatorBright={R=0.62,G=0.55,B=0.42,A=0.9}
local headerGlowOn={R=0.95,G=0.63,B=0.08,A=0.10}
local headerGlowOff={R=0,G=0,B=0,A=0}
-- A hovered page tab's background; the selected tab keeps its own glow.
local headerHover={R=0.95,G=0.63,B=0.08,A=0.06}
-- The glow under the selected page tab: a soft band with a brighter edge at the bottom.
local headerUnderSoft,headerUnderEdge={R=0.95,G=0.63,B=0.08,A=0.14},{R=0.95,G=0.63,B=0.08,A=0.6}
-- The soft band sits headerUnderSoftDrop below the tab's bottom; the edge is a 1-pixel line
-- drawn headerUnderEdgeDrop pixels below it.
local headerUnderSoftHeight,headerUnderSoftDrop,headerUnderEdgeHeight,headerUnderEdgeDrop=4,0,1,1
-- A picker's choice indicator under its value: one pip per choice up to pipLimit, else a
-- track with a thumb. Its strip is pipActiveHeight tall and starts pipBottom from the row's
-- bottom; the pips (pipHeight) sit a pixel below its top, on the row's last pixels, and the
-- current one (or the thumb) grows downwards while its row is hot. Below a choice note.
-- The indicator spans pipShare of the value's width, centred; the pips share it, pipGap
-- apart, each as wide as its place allows (they differ by a pixel at most).
local pipLimit,pipHeight,pipActiveHeight,pipBottom,pipGap,pipShare=16,2,4,-1,4,0.75
-- A click on the outer stepZone of a picker's value, either side, steps like the arrow there.
local stepZone=0.4
local pipOn,pipOff={R=0.95,G=0.63,B=0.08,A=0.9},{R=0.62,G=0.55,B=0.42,A=0.35}
-- A slider is drawn like a picker's indicator: its value sliderValueShrink points smaller,
-- centred on the control, over a bar sliderShare of the control's width: the filled part
-- pipActiveHeight tall and lit, the rest pipHeight and dim, centred on one line. While its
-- row is hovered or selected, a 3-pixel mark (lit between two dim lines) stands at the value,
-- sliderMarkHeight tall from sliderMarkAbove above the bar. The bar sits sliderBottom above
-- the row's bottom.
local sliderValueShrink,sliderShare,sliderMarkHeight,sliderMarkAbove,sliderBottom=2,0.75,10,2,4
-- The slider's value sits sliderValueLift pixels above the control's centre.
local sliderValueLift=3
-- A picker's value column in DMM's row: 330 of label and a 32-pixel arrow before it, 190
-- wide. A toggle's value takes the same column, so every value lines up.
local pickerLabelWidth,pickerArrowWidth,pickerValueWidth=330,32,190
local pickerValueLeft=pickerLabelWidth+pickerArrowWidth
-- A one-line picker row's height (DMM's is 40), and with choice notes; row labels are drawn
-- labelDrop pixels lower; a toggle-shell row's button starts toggleShift pixels left, so its
-- selection background starts where headings do.
local pickerRowHeight,notedPickerRowHeight,labelDrop,toggleShift=43,42,1,14
-- A picker arrow at the first or last choice: shown faint, not hidden. A click on it wraps
-- around to the other end, as does a click on that side of the value.
local edgeArrowOpacity=0.5
-- A choice note's size, and how far up the note sits while the current choice has one.
local noteSize,noteRaise=10,8
-- DMM centres a picker's value, so bottom padding raises it by half: noteValueLift raises
-- it 5 pixels over a note. An arrow picker showing no note raises its value 2 pixels
-- (plainValueLift), plainValueShrink points smaller, while its indicator sits plainPipLift higher.
local noteValueLift,plainValueLift,plainValueShrink,plainPipLift=10,4,1,6
-- The indicator's opacity while its row is not hovered: half of full.
local pipIdleOpacity=0.5
-- The current pip (or thumb) is pipHotHeight tall while its row is hovered or selected,
-- else pipHeight like the others. Every pip starts pipTop from the strip's top, so the
-- current one grows downwards.
local pipHotHeight,pipTop=3,(pipActiveHeight-pipHeight)//2
-- On a change a slider's fill slides to its new length over valueSlide seconds too. On a
-- change an arrow picker's new value slides in valueSlideDistance pixels from the side
-- it was stepped towards, fading in, over valueSlide seconds; the indicator fades the old
-- place out and the new one in over the same time (a thumb fades out, moves, fades back in).
local valueSlide,valueSlideDistance=0.2,12
-- An animation tick with no clock counts as one 60 Hz frame.
local animationFrame=0.016
local function mix(from,to,t)
    return {R=from.R+(to.R-from.R)*t,G=from.G+(to.G-from.G)*t,B=from.B+(to.B-from.B)*t,A=from.A+(to.A-from.A)*t}
end
local function sizePips(row)
    local height=row.mcPipHot and pipHotHeight or pipHeight
    for n,box in ipairs(row.mcPipBoxes or {}) do box:SetHeightOverride(n==row.mcPipShown and height or pipHeight) end
    if row.mcPipThumb then row.mcPipThumb.box:SetHeightOverride(height) end
end
-- A page tab's label when it is not the selected one.
local headerTabDimmed=0.8
-- A page tab's label sits headerTabRaise pixels above its tab's centre.
local headerTabRaise=1
-- Paints a page tab for its state: selected (glow behind and under, full label), hovered
-- (background) or neither (dimmed label). Only state changes touch the widgets.
local function paintHeaderTab(tab)
    local state=tab.selected and 'selected' or tab.hovered and 'hovered' or 'idle'
    if tab.painted==state then return end
    tab.glow:SetBrushColor(state=='selected' and headerGlowOn or state=='hovered' and headerHover or headerGlowOff)
    for _,band in ipairs(tab.under or {}) do band:SetVisibility(state=='selected' and 3 or 1) end
    tab.label:SetRenderOpacity(state=='selected' and 1 or headerTabDimmed)
    tab.painted=state
end
-- The page status shares the header tab row, left of the tabs, while it has
-- this much width; otherwise it drops below them at full width.
local headerStatusMinWidth,headerStatusGap,headerTabHeight,headerGap=160,12,29,12
-- A cycle button's background matches the keybind editor's Mode control.
local cycleBackground={R=0.12,G=0.12,B=0.12,A=0.09}
-- An on/off switch (mcType=onoff) is an onOffWidth by onOffHeight outline, onOffLine pixels
-- thick. Inside it, onOffMargin pixels clear, the toggle fills the left half (off) or the
-- right half (on). Off is grey, on is gold (the indicators' colors). The outline is dimmed
-- unless its row is hovered or selected, when a dim glow also fills the switch. Each side bar
-- runs between the top and bottom bars. On a change the toggle slides across in onOffSlide
-- seconds, easing out like DMM's highlights, and its colors blend along the way.
local onOffWidth,onOffHeight,onOffLine,onOffMargin=44,20,2,3
local onOffGold,onOffGrey={R=0.95,G=0.63,B=0.08},{R=0.62,G=0.55,B=0.42}
local onOffOutlineIdle,onOffOutlineHot,onOffToggle,onOffGlow=0.4,0.9,0.9,0.1
local onOffSlide=0.2
-- Off, every part of the switch is drawn at onOffDim of its strength; it brightens to full
-- as the toggle slides on. The choice's label, onOffTextShrink points smaller than DMM's
-- value, vertically centred and at onOffTextOpacity, sits onOffTextGap pixels left of the switch.
local onOffTextShrink,onOffTextOpacity=2,0.75
local onOffDim,onOffTextGap=0.6,12
local function blend(position,alpha)
    local function channel(key) return onOffGrey[key]+(onOffGold[key]-onOffGrey[key])*position end
    return {R=channel('R'),G=channel('G'),B=channel('B'),A=alpha*(onOffDim+(1-onOffDim)*position)}
end
-- Paints an on/off switch with its toggle at position (0 off, 1 on, between while sliding)
-- and its outline and glow for whether its row is hot.
local function paintOnOff(switch)
    local position,hot=switch.position,switch.hot
    for _,bar in ipairs(switch.bars) do bar:SetBrushColor(blend(position,hot and onOffOutlineHot or onOffOutlineIdle)) end
    switch.glow:SetBrushColor(blend(position,hot and onOffGlow or 0))
    switch.toggle:SetBrushColor(blend(position,onOffToggle))
    switch.toggleBox:SetRenderTranslation({X=math.floor(position*switch.travel+0.5),Y=0})
end
-- A module's faint backdrop in the mod list, grouped or not: the separators' warm grey.
local moduleBackground={R=0.62,G=0.55,B=0.42,A=0.14}
-- A navigation picker's choice while it separates two colliding keybinds.
local conflictRed={R=0.85,G=0.2,B=0.16,A=1}
function M.parse(content,items)
    local sections=Manifest.sections(content)
    local byId,groups,parents,seen={},{},{},{}
    for _,s in ipairs(items) do byId[s.id]=s end
    local function level(value)
        if value==nil then return nil end
        return assert(tonumber(value:match('^[0-6]$')),'mcLevel must be an integer from 0 through 6')
    end
    local function flag(value,name)
        if value==nil then return nil end
        assert(value=='0' or value=='1' or value=='true' or value=='false',
            name..' must be 0, 1, true, or false')
        return value=='1' or value=='true'
    end
    -- mcPlayerExists=1 shows a row or category only while a player is in the world; 0 only
    -- while none is.
    local function playerRule(value)
        if value==nil then return nil end
        assert(value=='0' or value=='1','mcPlayerExists must be 0 or 1')
        return value=='1'
    end
    local function labelRule(r)
        if not r.mcLabelWhen and not r.mcLabels then return nil end
        local source=assert(byId[r.mcLabelWhen],'unknown mcLabelWhen')
        assert(source.kind~='slider','mcLabelWhen requires a picker or toggle')
        local result={source=source,values={}}
        for entry in ((r.mcLabels or '')..';'):gmatch('(.-);') do
            local value,label=entry:match('^%s*([^:]+):(.+)$')
            value=tonumber(value)
            assert(value and label and not result.values[value],'invalid mcLabels')
            local valid=false
            for _,v in ipairs(source.values) do if v==value then valid=true end end
            assert(valid,'mcLabels value outside source choices')
            result.values[value]=trim(label)
        end
        return result
    end
    -- mcChoiceNotes=<value>:<text>;... gives a picker's choices a second line.
    local function choiceNotes(r,s)
        if r.mcChoiceNotes==nil then return nil end
        assert(s.kind=='picker','mcChoiceNotes requires a picker')
        local notes={}
        for entry in (r.mcChoiceNotes..';'):gmatch('(.-);') do
            local value,note=entry:match('^%s*([^:]+):(.+)$')
            value,note=tonumber(value),trim(note)
            assert(value and note~='' and #note<=64 and notes[value]==nil,'invalid mcChoiceNotes')
            local valid=false
            for _,v in ipairs(s.values) do if v==value then valid=true end end
            assert(valid,'mcChoiceNotes value outside picker choices')
            notes[value]=note
        end
        return notes
    end
    -- mcDimValues=<value>|<value> fades the row while its own value is one of these.
    local function dimValues(r,s)
        if r.mcDimValues==nil then return nil end
        assert(s.kind=='picker','mcDimValues requires a picker')
        local values={}
        for entry in (r.mcDimValues..'|'):gmatch('(.-)|') do
            local value=tonumber(trim(entry))
            local valid=false
            for _,v in ipairs(s.values) do if v==value then valid=true end end
            assert(valid,'mcDimValues value outside the row\'s choices')
            values[value]=true
        end
        return values
    end
    for _,section in ipairs(sections) do
        local r=section.fields
        local group=section.name:match('^Category%.(.+)$')
        if group then
            local order=labelRule({mcLabelWhen=r.mcOrderWhen,mcLabels=r.mcOrders})
            if order then
                for value,rank in pairs(order.values) do
                    rank=tonumber(rank)
                    assert(rank and rank==rank and math.abs(rank)<=1000000,'invalid mcOrders rank')
                    order.values[value]=rank
                end
            end
            local parent
            if r.mcParent~=nil then
                local label=trim(r.mcParent)
                assert(label~='','mcParent requires a non-empty label')
                local font=level(r.mcParentLevel) or 2
                parent=parents[label]
                if parent then assert(parent.font==font,'categories sharing mcParent must use the same mcParentLevel')
                else parent={key=label,label=label,font=font};parents[label]=parent end
            elseif r.mcParentLevel~=nil then error('mcParentLevel requires mcParent') end
            -- mcWithin=<category> makes this category a subgroup of that one; when that one
            -- has no rows (so DMM draws no heading for it), mcWithinLabel is its heading.
            local within=r.mcWithin~=nil and trim(r.mcWithin) or nil
            assert(within~='' and within~=group,'mcWithin requires another category')
            assert(not within or not parent,'mcWithin cannot be combined with mcParent')
            local withinLabel=r.mcWithinLabel~=nil and trim(r.mcWithinLabel) or nil
            assert(withinLabel~='','mcWithinLabel requires a non-empty label')
            assert(not withinLabel or within,'mcWithinLabel requires mcWithin')
            -- mcLabel=<text> is the heading's text in place of the category name.
            local label=r.mcLabel~=nil and trim(r.mcLabel) or nil
            assert(label~='','mcLabel requires a non-empty label')
            groups[group]={font=level(r.mcLevel),help=r.mcHelp,labelRule=labelRule(r),label=label,order=order,parent=parent,
                heading=flag(r.mcHeading,'mcHeading')~=false,playerExists=playerRule(r.mcPlayerExists),
                silent=flag(r.mcSilent,'mcSilent'),within=within,withinLabel=withinLabel}
        end
        if section.setting then
            local id=section.id
            local s=byId[id]
            if s and not seen[id] then
                seen[id]=true
                s.mcFont=level(r.mcLevel)
                s.mcHeading=flag(r.mcHeading,'mcHeading') or false
                s.mcReadOnly=flag(r.mcReadOnly,'mcReadOnly')
                s.mcCategory=flag(r.mcCategory,'mcCategory')
                assert(not s.mcCategory or r.mcLevel==nil and not s.mcHeading,
                    'mcCategory cannot be combined with mcLevel or mcHeading')
                s.mcWrap=flag(r.mcWrap,'mcWrap')
                assert(not s.mcWrap or s.kind=='picker' and r.mcReadOnly=='1','mcWrap requires a read-only picker')
                -- mcTable=<code>:<text>|... shows static pairs in mcColumns columns. Its
                -- entries are decoded when the row is built, so a malformed table shows
                -- a placeholder instead of skipping the page.
                if r.mcTable~=nil then
                    assert(s.kind=='picker' and r.mcReadOnly=='1','mcTable requires a read-only picker')
                    assert(not s.mcWrap and r.mcType==nil,'mcTable cannot be combined with mcWrap or mcType')
                    s.mcTable={text=r.mcTable,columns=r.mcColumns}
                else
                    assert(r.mcColumns==nil,'mcColumns requires mcTable')
                    s.mcTable=nil
                end
                s.mcPlayerExists=playerRule(r.mcPlayerExists)
                -- mcSilent=1 keeps DMM's interface sounds off the row, as on a row that
                -- plays sounds of its own.
                s.mcSilent=flag(r.mcSilent,'mcSilent')
                s.mcReferenceLabel=r.mcReferenceLabel
                s.mcLabelRule=labelRule(r)
                s.mcChoiceNotes=choiceNotes(r,s)
                -- mcChoiceSounds=<value>:<event path>;... plays a choice's own sound
                -- instead of DMM's when the row changes to it.
                s.mcChoiceSounds=ChoiceSound.parse(r.mcChoiceSounds,s)
                s.mcDimValues=dimValues(r,s)
                s.mcTabs,s.mcCycle,s.mcOnOff,s.mcTabsWidth,s.mcHeader=nil,nil,nil,nil,nil
                local hasLevel=r.mcLevel~=nil
                local decoration=r.mcType
                if decoration~=nil then
                    assert(decoration=='tab' or decoration=='cycle' or decoration=='onoff','mcType must be tab, cycle or onoff')
                end
                if decoration=='tab' then
                    assert(s.kind=='picker','mcType=tab requires a picker')
                    assert(#s.values<=8,'mcType=tab supports at most eight choices')
                    s.mcTabs=true
                elseif decoration=='cycle' then
                    assert(s.kind=='picker','mcType=cycle requires a picker')
                    s.mcCycle=true
                elseif decoration=='onoff' then
                    -- An on/off switch: the picker's choices are 0 (off) and 1 (on).
                    assert(s.kind=='picker','mcType=onoff requires a picker')
                    assert(#s.values==2 and s.values[1]==0 and s.values[2]==1,'mcType=onoff requires the choices 0 and 1')
                    s.mcOnOff=true
                end
                if r.mcTabsWidth~=nil then
                    local width=tonumber(r.mcTabsWidth)
                    assert(decoration=='tab','mcTabsWidth requires mcType=tab')
                    assert(width and width%1==0 and width>=160 and width<=440,
                        'mcTabsWidth must be an integer from 160 through 440')
                    s.mcTabsWidth=width
                end
                if hasLevel then s.mcHeader=s.mcFont==1 end
                if s.mcHeading then s.mcHeader=true end
            end
        end
    end
    local headers,rows=0,{}
    for _,s in ipairs(items) do
        s.mcGroup=groups[s.group]
        rows[s.group]=true
        if s.mcHeader then headers=headers+1 end
    end
    -- A subgroup's category is not a subgroup itself. When that category has no rows,
    -- DMM draws no heading for it, so its subgroups share one drawn in the category style.
    for _,group in pairs(groups) do
        if group.within then
            local outer=groups[group.within]
            assert(not (outer and outer.within),'mcWithin must name a category that is not a subgroup')
            assert(not (rows[group.within] and group.withinLabel),'mcWithinLabel is for a category without rows')
            if group.withinLabel then
                local key='\0'..group.within
                local shared=parents[key]
                assert(not shared or shared.label==group.withinLabel,'subgroups of one category share its mcWithinLabel')
                parents[key]=shared or {key=key,label=group.withinLabel,category=true}
                group.parent=parents[key]
            end
        end
    end
    assert(headers<=1,'only one level-one setting per provider')
    return items
end
-- Breaks a comma-separated list into lines shorter than limit characters, each
-- continued line ending in its comma. Returns the text and its line count.
function M.wrapList(text,limit)
    local lines,line={},nil
    for item in (text..','):gmatch('%s*(.-)%s*,') do
        if item~='' then
            if line and #line+2+#item<limit then line=line..', '..item
            else
                if line then lines[#lines+1]=line..',' end
                line=item
            end
        end
    end
    if line then lines[#lines+1]=line end
    return table.concat(lines,'\n'),math.max(#lines,1)
end

function M.style(label,level,api)
    local style=styles[level]
    if not style then return end
    api.Theme.font(label,api.theme,style[1])
    api.Theme.textColor(label,style[2])
    if level==5 then label:SetRenderOpacity(0.85) end
end
-- options.keyColumn (optional): the keybind editor's layout; cycle buttons align
-- with its key column, and otherwise sit at the right like tabs.
function M.install(choices,controls,pages,options)
    if controls.mcPresentationVersion then return false end
    local keyColumn=options and options.keyColumn
    -- Where a keybind's key box (and a cycle button) starts: centred on a picker's value column.
    local function keyLeft() return pickerValueLeft+(pickerValueWidth-keyColumn.key)/2 end
    -- An mcTable row taller than this scrolls.
    local tableMaxHeight=360
    -- textTable(text,columns) decodes an mcTable row: menu_contributions.textTable.
    local textTable=options and options.textTable or function() error('table decoder unavailable',0) end
    -- An mcTable line: codes 12pt muted, texts 18pt, each centred in a cell with tablePad
    -- pixels around it. Sizes come from Afacad: a point is 4/3 pixel, a line 4/3 em, a code
    -- character at most 2/3 em and a text character about 1 em.
    local tableCode,tableText,tablePad=12,18,4
    local function em(points) return points*4/3 end
    local tableLine=math.ceil(em(math.max(tableCode,tableText))*4/3)+2*tablePad
    local parse,build=choices.parse,controls.build
    -- One player of choice sounds (mcChoiceSounds) for every page and menu: a sound a
    -- choice started stops on the next change, on another page, and when the menu closes
    -- (options.events, DMM's lifecycle bus: hostClosing).
    local choicePlayer
    local function stopChoiceSound() if choicePlayer then choicePlayer:stop() end end
    local events=options and options.events
    if events then events:on('hostClosing',stopChoiceSound) end
    choices.parse=function(content) return M.parse(content,parse(content)) end
    -- mcPlayerExists works like a hidden Yes|No picker that follows whether a player is in
    -- the world: rows and categories marked with it show only on its value, alongside their
    -- VisibleWhen. options.playerExists() answers it each time DMM checks visibility.
    local playerExists=options and options.playerExists or function() return false end
    local open=choices.open
    choices.open=function(provider)
        local model=open(provider)
        local function wanted(item)
            local group=item.mcGroup and item.mcGroup.playerExists
            return item.mcPlayerExists,group
        end
        local gated=false
        for _,item in ipairs(model.items or {}) do
            local own,group=wanted(item)
            gated=gated or own~=nil or group~=nil
        end
        if not gated then return model end
        local visibility=model.visibility
        function model:visibility()
            local visible=visibility(self)
            local ok,exists=pcall(playerExists)
            exists=ok and exists==true
            for i,item in ipairs(self.items) do
                local own,group=wanted(item)
                if (own~=nil and own~=exists) or (group~=nil and group~=exists) then visible[i]=false end
            end
            -- As in DMM, a row whose VisibleWhen source is hidden is hidden too.
            local changed=true
            while changed do
                changed=false
                for i,item in ipairs(self.items) do
                    for _,rule in ipairs(visible[i] and item.visibility or {}) do
                        if not visible[rule.target] then visible[i],changed=false,true;break end
                    end
                end
            end
            return visible
        end
        return model
    end
    controls.build=function(tree,providers,api)
        local adapted={}
        -- Cached pages may be evicted; do not retain their Lua widget wrappers.
        local labels=setmetatable({},{__mode='k'})
        local rowButtonInset=setmetatable({},{__mode='k'})
        local helpWidgets=setmetatable({},{__mode='k'})
        local headingRules=setmetatable({},{__mode='k'})
        -- The rule under a row that stands in for its group's heading (mcCategory), by
        -- the row's label button.
        local categoryRules=setmetatable({},{__mode='k'})
        local valueSignals=setmetatable({},{__mode='k'})
        local ui
        -- While DMM builds a page: the provider, the last row whose label button was
        -- seen, and how many of that row's value buttons follow before the next label.
        local constructing,pendingHeading,buttonSettingIndex,buttonsToSkip
        -- The label button of an mcCategory row whose rule waits for DMM to add the row.
        local pendingCategoryRule
        for k,v in pairs(api) do adapted[k]=v end
        -- A page-tab row is not highlighted as a whole when it has focus: its selected tab
        -- takes DMM's focus highlight instead. headerFocus maps the row's highlighted widget
        -- to the row; DMM's highlight calls for it are redirected here.
        local headerFocus=setmetatable({},{__mode='k'})
        local highlight=api.highlight
        local function focusHeaderTabs(row)
            for _,tab in ipairs(row.mcTabs or {}) do
                local want=tab.selected and row.mcFocusAlpha or 0
                if tab.focus and tab.focusAlpha~=want then highlight(tab.focus,want,false);tab.focusAlpha=want end
            end
        end
        if highlight then
            adapted.highlight=function(widget,alpha,background)
                local row=headerFocus[widget]
                if not row then return highlight(widget,alpha,background) end
                highlight(widget,0,background)
                row.mcFocusAlpha=alpha
                focusHeaderTabs(row)
            end
        end
        -- DMM plays a sound after making the row its own: hovered for Hover, current for
        -- Select and Change. A silent row (mcSilent, or its category's) plays none. On a
        -- Change the new value is already set: a choice with its own sound (mcChoiceSounds)
        -- plays that instead, or none. Any change on such a row first stops the sound the
        -- previous choice started.
        if api.feedback then
            adapted.feedback=function(action,...)
                local index=ui and ui.active and (action=='Hover' and ui.hovered or ui.current)
                local setting=index and ui.model and ui.model.items and ui.model.items[index]
                if setting and (setting.mcSilent or setting.mcGroup and setting.mcGroup.silent) then return end
                local sound
                if action=='Change' and setting and setting.mcChoiceSounds and ui.model.pending then
                    sound=setting.mcChoiceSounds[ui.model.pending[index]]
                    if sound or choicePlayer then
                        choicePlayer=choicePlayer or M.choiceSoundPlayer(api.log)
                        if sound then choicePlayer:play(sound) else choicePlayer:stop() end
                    end
                end
                if sound~=nil then return end
                return api.feedback(action,...)
            end
        end
        adapted.setText=function(widget,value)
            local signal=valueSignals[widget]
            if not signal then return api.setText(widget,value) end
            local setting=ui.model and ui.model.items[signal.index]
            local clean=setting and not ui.model.error
                and choices.format(setting,ui.model.pending[signal.index]) or nil
            local dirty=clean~=nil and value==clean..' *'
            local display=dirty and clean or value
            api.setText(signal.marker,dirtySignalPrefix..(dirty and '1' or '0')..'\n'..display)
            return api.setText(widget,display)
        end
        -- A rule like a heading's, under an mcCategory row: DMM adds the row to the page
        -- after building its buttons, so the rule follows once the next heading or row
        -- starts, or the page is built.
        local function headingRule()
            local rule=api.construct('/Script/UMG.Border',tree);rule:SetBrushColor(headerSeparatorDim)
            local box=api.construct('/Script/UMG.SizeBox',tree);box:SetHeightOverride(1)
            api.need(box:SetContent(rule),'MCS heading rule')
            return box
        end
        local function addCategoryRule()
            local button=pendingCategoryRule
            pendingCategoryRule=nil
            local panel=button and ui and ui.panels and ui.panels[constructing]
            if not panel then return end
            local box=headingRule()
            api.need(panel.scroll:AddChild(box),'MCS category rule')
                :SetPadding({Left=categoryLeft,Top=0,Right=0,Bottom=categoryRuleBottom})
            categoryRules[button]=box
        end
        adapted.caption=function(owner,text)
            local label=api.caption(owner,text)
            if constructing then
                for _,s in ipairs(providers[constructing].choices or {}) do
                    if text==s.group then
                        addCategoryRule()
                        local help=s.mcGroup and s.mcGroup.heading and s.mcGroup.help
                        pendingHeading={heading=label,help=help or nil};break
                    end
                end
            end
            return label
        end
        -- DMM adds a heading to the page after captioning it, and its first row after
        -- that: the heading's rule, then its help, go in between.
        adapted.button=function(...)
            if pendingHeading then
                local parent=pendingHeading.heading:GetParent()
                local box=headingRule()
                api.need(parent:AddChild(box),'MCS heading rule')
                    :SetPadding({Left=categoryLeft,Top=0,Right=0,Bottom=categoryRuleBottom})
                headingRules[pendingHeading.heading]=box
                if pendingHeading.help then
                    local help=api.caption(tree,pendingHeading.help);help:SetAutoWrapText(true)
                    M.style(help,5,api)
                    local slot=api.need(parent:AddChild(help),'MCS group help')
                    slot:SetPadding({Left=rowIndent,Top=0,Right=20,Bottom=8})
                    helpWidgets[pendingHeading.heading]=help
                end
                pendingHeading=nil
            end
            local button,label=api.button(...)
            -- DMM builds each row's label button first; a picker then adds its left,
            -- value and right buttons. The label text only confirms the position: a
            -- page whose buttons fall out of step gets no further row styling.
            if constructing and buttonsToSkip>0 then buttonsToSkip=buttonsToSkip-1
            elseif constructing then
                local nextSetting=providers[constructing].choices[buttonSettingIndex+1]
                if not nextSetting or select(2,...)~=nextSetting.label then buttonsToSkip=math.huge
                else
                    addCategoryRule()
                    buttonSettingIndex=buttonSettingIndex+1
                    buttonsToSkip=nextSetting.kind=='picker' and 3 or 0
                    if nextSetting.mcCategory then pendingCategoryRule=button end
                    if nextSetting.mcFont==nil and not nextSetting.mcHeader then
                        local style=button.WidgetStyle
                        local normal,pressed=style.NormalPadding,style.PressedPadding
                        rowButtonInset[button]=normal.Left
                        style.NormalPadding={Left=0,Top=normal.Top,
                            Right=normal.Right,Bottom=normal.Bottom}
                        style.PressedPadding={Left=0,Top=pressed.Top,
                            Right=pressed.Right,Bottom=pressed.Bottom}
                    end
                end
            end
            labels[button]=label
            return button,label
        end
        ui=build(tree,providers,adapted)
        local prepare,show,hide,refresh,tick,clearPresses,isPressed=ui.prepare,ui.show,ui.hide,ui.refresh,ui.tick,ui.clearPresses,ui.isPressed
        local select=ui.select
        local function new(kind) return api.construct('/Script/UMG.'..kind,tree) end
        local function add(parent,child) return api.need(parent:AddChild(child),'MCS presentation child') end
        local function sized(child,width,height)
            local box=new('SizeBox');box:SetWidthOverride(width);box:SetHeightOverride(height or 40)
            local slot=api.need(box:SetContent(child),'MCS presentation size')
            slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
            return box
        end
        -- A tab keeps at least share pixels but grows to fit its label with tabPadding
        -- pixels each side. The text width is estimated for the layout; the box's minimum
        -- width (not an override) lets a label wider than the estimate still widen its tab.
        local tabPadding=3
        local function tabWidth(text,size,share,inset)
            local chars=utf8.len(text) or #text
            return math.max(share,math.ceil(chars*size*0.6)+2*(tabPadding+inset))
        end
        local function tabSized(child,width,height)
            local box=new('SizeBox');box:SetMinDesiredWidth(width);box:SetHeightOverride(height)
            local slot=api.need(box:SetContent(child),'MCS presentation size')
            slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
            return box
        end
        -- raise (optional) lifts the vertically centred label that many pixels in a tab of
        -- unchanged height.
        local function padTab(button,side,raise)
            local bottom=2*(raise or 0)
            local style=button.WidgetStyle
            style.NormalPadding={Left=side,Top=0,Right=side,Bottom=bottom}
            style.PressedPadding={Left=side,Top=0,Right=side,Bottom=bottom}
        end
        local pickerRightMargin=24
        -- Real seconds for animations, read as DMM reads its own (api.clock in tests); nil
        -- when the engine cannot answer.
        local gameplay
        local function clock()
            if api.clock then return api.clock() end
            local find=rawget(_G,'StaticFindObject')
            if not find then return nil end
            local ok,now=pcall(function()
                gameplay=gameplay or find('/Script/Engine.Default__GameplayStatics')
                return gameplay:GetRealTimeSeconds(api.pc or tree)
            end)
            return ok and type(now)=='number' and now or nil
        end
        -- The arrow of an arrow picker at its first or last choice, which DMM disabled; nil
        -- elsewhere, and on a disabled picker (both arrows off).
        local function edgeArrow(row)
            if not (row.left and row.right) or row.renderLeft==row.renderRight then return nil end
            return row.renderLeft and row.right or row.left
        end
        -- Running animations by key: apply(t) draws progress t (0 to 1, eased out like DMM's
        -- highlights) for each tick until duration has passed. A tick with no clock counts as
        -- one 60 Hz frame. A new animation under a key replaces the running one.
        local animations={}
        local function animate(key,duration,apply)
            animations[key]={start=clock(),elapsed=0,duration=duration,apply=apply}
            apply(0)
        end
        local function stepAnimations()
            if next(animations)==nil then return end
            local now=clock()
            for key,animation in pairs(animations) do
                animation.elapsed=now and animation.start and now-animation.start or animation.elapsed+animationFrame
                local t=math.max(0,math.min(1,animation.elapsed/animation.duration))
                animation.apply(1-(1-t)^3)
                if t>=1 then animations[key]=nil end
            end
        end
        -- Label column of a wrapped read-only row; the value takes the rest.
        local wrapLabelWidth=230
        -- Field-type editors are built on DMM's toggle row, whose label sits in the
        -- row content; its indent belongs on that content's slot, not the label's.
        local function toggleShell(setting) return setting.kind=='toggle' or setting.kind=='extension' end
        -- The dirty star follows the label text: label and star share a box in the
        -- label's place, so the star moves with the text and never overlaps it.
        -- ModCoreSettings' dirty labels show and hide it. The box clips, so a label
        -- longer than its column is cut there instead of reaching the controls.
        local function starAfter(label)
            local padding=label.Slot.Padding
            local line=new('HorizontalBox');line:SetClipping(1)
            local lineSlot=api.need(label:GetParent():SetContent(line),'MCS label line')
            lineSlot:SetHorizontalAlignment(0);lineSlot:SetVerticalAlignment(2)
            lineSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
            local labelSlot=add(line,label)
            labelSlot:SetSize({SizeRule=0,Value=1});labelSlot:SetVerticalAlignment(2)
            labelSlot:SetPadding({Left=padding.Left,Top=padding.Top,Right=0,Bottom=padding.Bottom})
            local star=api.caption(tree,'*')
            star:SetVisibility(2)
            local starSlot=add(line,star)
            starSlot:SetSize({SizeRule=0,Value=1});starSlot:SetVerticalAlignment(2)
            starSlot:SetPadding({Left=4,Top=0,Right=padding.Right,Bottom=0})
            return star
        end
        -- A navigation picker that separates two colliding keybinds shows its choice,
        -- text and arrows, in red. DMM gives that text the body color and leaves arrow
        -- art untinted, so clearing restores exactly those.
        local function conflictStyle(row,red)
            local function text(widget)
                if red then widget:SetColorAndOpacity({SpecifiedColor=conflictRed,ColorUseRule=0})
                else api.Theme.textColor(widget,'body') end
            end
            if row.value then text(row.value) end
            for _,part in ipairs({row.parts[1],row.parts[3]}) do
                local content=part and part.widget:GetContent()
                if content then
                    -- Arrow art sits in a size box; without art the arrow is a text label.
                    local ok,art=pcall(function() return content:GetContent() end)
                    if ok and art then art:SetColorAndOpacity(red and conflictRed or {R=1,G=1,B=1,A=1})
                    else text(content) end
                end
            end
        end
        -- The star matches its label's font and color whenever the label is restyled.
        local function starStyle(row)
            if not row.mcStar then return end
            row.mcStar:SetFont(row.mcLabel.Font)
            pcall(function() row.mcStar:SetColorAndOpacity(row.mcLabel.ColorAndOpacity) end)
        end
        -- A frame of four bars, thickness pixels (default 1) wide, around a tab choice or
        -- an on/off switch. The fill stays clear so the row's own background shows through.
        local function outlined(child,thickness)
            local overlay=new('Overlay')
            local slot=add(overlay,child);slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
            local bars={}
            for _,edge in ipairs({{h=0,v=1},{h=0,v=3},{h=1,v=0},{h=3,v=0}}) do
                local bar=new('Border');bar:SetBrushColor(headerSeparatorDim)
                local box=new('SizeBox')
                if edge.h==0 then box:SetHeightOverride(thickness or 1) else box:SetWidthOverride(thickness or 1) end
                api.need(box:SetContent(bar),'MCS tab outline')
                local barSlot=add(overlay,box);barSlot:SetHorizontalAlignment(edge.h);barSlot:SetVerticalAlignment(edge.v)
                -- The side bars run between the top and bottom ones, so no corner is drawn twice.
                if edge.h~=0 then barSlot:SetPadding({Left=0,Top=thickness or 1,Right=0,Bottom=thickness or 1}) end
                bars[#bars+1]=bar
            end
            return overlay,bars
        end
        local function decorate(index)
            local panel=ui.panels[index]
            if panel.mcPresented then return end
            for i,row in ipairs(panel.rows) do
                local setting=providers[index].choices[i]
                row.mcLabel=labels[row.widget]
                -- Navigation and read-only rows are never dirty.
                if row.mcLabel and not setting.mcNavigation and not setting.mcReadOnly then
                    row.mcStar=starAfter(row.mcLabel)
                end
                -- Every label is drawn labelDrop pixels lower; only the drawing moves.
                if row.mcLabel then
                    local line=row.mcStar and row.mcLabel:GetParent() or row.mcLabel
                    line:SetRenderTranslation({X=0,Y=labelDrop})
                end
                -- A selected or hovered row's background starts where headings do. A
                -- toggle-shell row's button is its background: it starts toggleShift
                -- further left, and its content's indent gives that back.
                if row.background then
                    local p=row.background.Slot.Padding
                    row.background.Slot:SetPadding({Left=categoryLeft,Top=p.Top,Right=p.Right,Bottom=p.Bottom})
                elseif toggleShell(setting) then
                    local p=row.widget.Slot.Padding
                    row.widget.Slot:SetPadding({Left=-toggleShift,Top=p.Top,Right=p.Right,Bottom=p.Bottom})
                end
                local identity=api.caption(tree,settingIdentity(i,providers[index],setting))
                identity:SetVisibility(1)
                add(row.wrapper:GetContent(),identity)
                if row.value then
                    local marker=api.caption(tree,dirtySignalPrefix..'0\n')
                    marker:SetVisibility(1)
                    add(row.wrapper:GetContent(),marker)
                    valueSignals[row.value]={marker=marker,index=i}
                end
                local level=setting.mcHeading and 1 or setting.mcFont
                M.style(row.mcLabel,level,api)
                if settingLabelSizes[level] then api.Theme.font(row.mcLabel,api.theme,settingLabelSizes[level]) end
                -- Theme.font only writes the property; a built label shows it after SetFont.
                if level then row.mcLabel:SetFont(row.mcLabel.Font) end
                starStyle(row)
                if level==1 or level==2 then
                    local slot=toggleShell(setting) and row.widget:GetContent().Slot or row.mcLabel.Slot
                    local padding=slot.Padding
                    slot:SetPadding({Left=0,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom})
                end
                if setting.mcHeader and ui.mcHeaderHost then
                    assert(not panel.mcHeader,'only one level-one setting per provider')
                    local placeholder=new('SizeBox')
                    local path=assert(row.wrapper:GetFullName():match('^%S+ (.+)$'))
                    local marker=api.caption(tree,Protocols.headerRow..path)
                    api.need(placeholder:SetContent(marker),'MCS header identity')
                    placeholder:SetVisibility(1)
                    local children={}
                    for n=0,panel.scroll:GetChildrenCount()-1 do
                        local child=panel.scroll:GetChildAt(n)
                        local padding=child.Slot.Padding
                        children[#children+1]={widget=child:GetFullName()==row.wrapper:GetFullName() and placeholder or child,
                            padding={Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom}}
                    end
                    panel.scroll:ClearChildren()
                    for _,child in ipairs(children) do add(panel.scroll,child.widget):SetPadding(child.padding) end
                    row.mcLabel:SetVisibility(1)
                    add(ui.mcHeaderHost,row.wrapper)
                    local title=ui.mcHeaderTitle
                    if title then
                        assert(ui.mcHeaderHost:RemoveChild(title),'MCS page title relocation')
                        local titleSlot=add(ui.mcHeaderHost,title)
                        titleSlot:SetHorizontalAlignment(1);titleSlot:SetVerticalAlignment(2)
                    end
                    row.mcHeader=true;row.mcPlaceholder=placeholder;panel.mcHeader=row
                    row.mcHeaderTabs=setting.kind=='picker' and ui.mcHeaderTabs~=nil
                end
                if row.mcHeaderTabs then
                    -- A header picker shows every choice as a tab hanging from the
                    -- divider, right-aligned, separated by thin vertical bars, all drawn
                    -- alike. The selected tab glows behind and under its label.
                    local tabs=new('HorizontalBox')
                    row.mcTabs={};row.mcHeaderSeparators={}
                    local count=#setting.values
                    local share=math.floor(math.min(110,(ROW_WIDTH-(count+1))/count))
                    local total=count+1
                    local function separator()
                        local bar=new('Border');bar:SetBrushColor(headerSeparatorDim)
                        add(tabs,sized(bar,1,headerTabHeight))
                        row.mcHeaderSeparators[#row.mcHeaderSeparators+1]=bar
                    end
                    separator()
                    for n,value in ipairs(setting.values) do
                        local button,label=api.button(tree,setting.labels[n]);button.IsFocusable=false
                        padTab(button,tabPadding,headerTabRaise)
                        api.Theme.font(label,api.theme,12)
                        label:SetJustification(1);label:SetTextOverflowPolicy(1)
                        label.Slot:SetHorizontalAlignment(0);label.Slot:SetVerticalAlignment(2)
                        local glow=new('Border');glow:SetBrushColor(headerGlowOff)
                        api.need(glow:SetContent(button),'MCS header tab glow')
                        local stack=new('Overlay')
                        -- DMM's focus highlight, behind the tab: shown on the selected tab while
                        -- the row has focus, instead of across the whole title row.
                        local focus=api.Theme.image(tree,api.theme,'selection',api)
                        focus:SetRenderOpacity(0);focus:SetVisibility(3)
                        local focusSlot=add(stack,focus);focusSlot:SetHorizontalAlignment(0);focusSlot:SetVerticalAlignment(0)
                        local glowSlot=add(stack,glow);glowSlot:SetHorizontalAlignment(0);glowSlot:SetVerticalAlignment(0)
                        local under={}
                        for _,band in ipairs({{headerUnderSoft,headerUnderSoftHeight,headerUnderSoftDrop},
                            {headerUnderEdge,headerUnderEdgeHeight,headerUnderEdgeDrop}}) do
                            local fill=new('Border');fill:SetBrushColor(band[1])
                            local box=new('SizeBox');box:SetHeightOverride(band[2])
                            api.need(box:SetContent(fill),'MCS header tab underglow')
                            -- Collapsed until its tab is selected, then shown without hit
                            -- testing, so the tab's button still takes the pointer.
                            box:SetVisibility(1)
                            local bandSlot=add(stack,box);bandSlot:SetHorizontalAlignment(0);bandSlot:SetVerticalAlignment(3)
                            bandSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=-band[3]})
                            under[#under+1]=box
                        end
                        local width=tabWidth(setting.labels[n],12,share,0)
                        total=total+width
                        add(tabs,tabSized(stack,width,headerTabHeight))
                        row.mcTabs[#row.mcTabs+1]={widget=button,label=label,value=value,
                            pressed=false,pointer=false,glow=glow,under=under,header=true,focus=focus}
                        separator()
                    end
                    local slot=add(ui.mcHeaderTabs,tabs)
                    slot:SetHorizontalAlignment(3);slot:SetVerticalAlignment(1)
                    row.mcHeaderTabsBox=tabs
                    row.mcHeaderTabsWidth=total
                    if highlight then
                        local target=row.background or row.widget
                        headerFocus[target]=row
                        -- DMM may already have highlighted the row; move that to its tab.
                        if row.paintOn~=nil then
                            adapted.highlight(target,api.Theme.selectionState(target,api.theme,row.paintOn,
                                row.paintHover,row.background~=nil),not row.background)
                        end
                    end
                    if row.value then row.value:SetVisibility(1) end
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                elseif setting.mcTabs then
                    -- Keep DMM's original controls alive for navigation, dirty
                    -- notifications and reconstruction. No stock reparenting.
                    local tabs=new('HorizontalBox')
                    row.mcTabs={}
                    local count=#setting.values
                    local providerLink=setting.mcNavigation and setting.mcLinkPage
                    -- A read-only status or navigation action whose choices share one
                    -- label (No settings beside an Open link, or Play) shows one button,
                    -- sized and placed like a link.
                    if (setting.mcReadOnly or setting.mcNavigation) and not setting.mcReferenceLabel then
                        local same=true
                        for _,text in ipairs(setting.labels) do same=same and text==setting.labels[1] end
                        providerLink=providerLink or same
                    end
                    local totalWidth=providerLink and 160 or
                        (setting.mcReferenceLabel and 150 or (setting.mcTabsWidth or math.min(384,110*count)))
                    local choices={}
                    for n,value in ipairs(setting.values) do
                        if not providerLink or n==1 then choices[#choices+1]={value=value,label=setting.labels[n]} end
                    end
                    -- Outlined choices sit 4 pixels apart, sharing the reserved width; a
                    -- longer label widens its own choice, and the row reserves the total.
                    local share=(totalWidth-4*(#choices-1))/#choices
                    totalWidth=4*(#choices-1)
                    for _,choice in ipairs(choices) do
                        choice.width=tabWidth(choice.label,14,share,1)
                        totalWidth=totalWidth+choice.width
                    end
                    for n,choice in ipairs(choices) do
                        local button,label=api.button(tree,choice.label);button.IsFocusable=false
                        padTab(button,tabPadding+1)
                        label:SetJustification(1);label:SetTextOverflowPolicy(1)
                        -- Stretch the text block across the button, then let centered
                        -- text justification position its contents.
                        label.Slot:SetHorizontalAlignment(0);label.Slot:SetVerticalAlignment(2)
                        local frame,outline=outlined(button)
                        local box=tabSized(frame,choice.width,32)
                        local boxSlot=add(tabs,box)
                        boxSlot:SetVerticalAlignment(2)
                        if n>1 then boxSlot:SetPadding({Left=4,Top=0,Right=0,Bottom=0}) end
                        row.mcTabs[#row.mcTabs+1]={widget=button,label=label,value=choice.value,pressed=false,pointer=false,
                            box=box,outline=outline}
                    end
                    local overlay=row.background:GetParent()
                    local slot=add(overlay,tabs);slot:SetHorizontalAlignment(3);slot:SetVerticalAlignment(2)
                    slot:SetPadding({Left=0,Top=0,Right=pickerRightMargin,Bottom=0})
                    if setting.mcReadOnly and setting.mcReferenceLabel then
                        local reference,text=api.button(tree,setting.mcReferenceLabel)
                        reference.IsFocusable=false;reference:SetIsEnabled(false)
                        text:SetJustification(1)
                        local box=sized(reference,96,32)
                        box:SetRenderTranslation({X=-(totalWidth+8),Y=0})
                        local referenceSlot=add(overlay,box)
                        referenceSlot:SetHorizontalAlignment(3);referenceSlot:SetVerticalAlignment(2)
                        referenceSlot:SetPadding({Left=0,Top=0,Right=pickerRightMargin,Bottom=0})
                    end
                    row.widget:GetParent():SetWidthOverride(PAGE_WIDTH-totalWidth-pickerRightMargin)
                    if providerLink then
                        -- A link row's label wraps within its column and the row grows to
                        -- fit; one line keeps DMM's 40-pixel row. The button stays centred.
                        row.mcLabel:SetAutoWrapText(true)
                        for _,box in ipairs({row.widget:GetParent(),row.wrapper}) do
                            box:ClearHeightOverride();box:SetMinDesiredHeight(40)
                        end
                    end
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                elseif setting.mcCycle then
                    -- One button showing only the current choice; a click moves to the
                    -- next, like the keybind editor's Mode. It sits in the key column,
                    -- under the keys, at the key box's width.
                    local width=keyColumn and keyColumn.key or 96
                    local button,label=api.button(tree,'');button.IsFocusable=false
                    api.Theme.font(label,api.theme,13)
                    label:SetJustification(1);label:SetTextOverflowPolicy(1)
                    label.Slot:SetHorizontalAlignment(0);label.Slot:SetVerticalAlignment(2)
                    local frame=new('Border');frame:SetBrushColor(cycleBackground)
                    api.need(frame:SetContent(button),'MCS cycle frame')
                    local box=sized(frame,width,32)
                    local overlay=row.background:GetParent()
                    local slot=add(overlay,box);slot:SetVerticalAlignment(2)
                    if keyColumn then
                        slot:SetHorizontalAlignment(1)
                        row.mcCyclePlace=function(indent)
                            slot:SetPadding({Left=keyLeft(),Top=0,Right=0,Bottom=0})
                            row.widget:GetParent():SetWidthOverride(keyLeft()-indent)
                        end
                        row.mcCyclePlace(rowIndent+(rowButtonInset[row.widget] or 0))
                    else
                        slot:SetHorizontalAlignment(3)
                        slot:SetPadding({Left=0,Top=0,Right=pickerRightMargin,Bottom=0})
                        row.widget:GetParent():SetWidthOverride(PAGE_WIDTH-width-pickerRightMargin)
                    end
                    row.mcTabs={{widget=button,label=label,value=setting.values[1],pressed=false,pointer=false,
                        cycle=true,box=box}}
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                elseif setting.mcOnOff and row.value then
                    -- The value column, after DMM's label column and left arrow, holds the
                    -- current choice's label, right-aligned, then the switch, centred in the
                    -- column. One clear button across the column, row-high, takes the pointer
                    -- and flips it; DMM's arrows and value stay alive, hidden, for keys and
                    -- controller.
                    local function boxWidth(widget,fallback)
                        local ok,width=pcall(function() return widget:GetParent().WidthOverride end)
                        return ok and tonumber(width) or fallback
                    end
                    local left=boxWidth(row.widget,pickerLabelWidth)+boxWidth(row.parts[1].widget,pickerArrowWidth)
                    local width=boxWidth(row.parts[2].widget,pickerValueWidth)
                    local glow=new('Border');glow:SetBrushColor(headerGlowOff)
                    local frame,bars=outlined(glow,onOffLine)
                    local switch=new('Overlay')
                    local frameSlot=add(switch,frame);frameSlot:SetHorizontalAlignment(0);frameSlot:SetVerticalAlignment(0)
                    local inset=onOffLine+onOffMargin
                    local toggle=new('Border');toggle:SetBrushColor(headerGlowOff)
                    local toggleBox=sized(toggle,(onOffWidth-2*inset)//2,onOffHeight-2*inset)
                    -- The toggle rests at the left; its render translation carries it right.
                    local toggleSlot=add(switch,toggleBox)
                    toggleSlot:SetHorizontalAlignment(1);toggleSlot:SetVerticalAlignment(2)
                    toggleSlot:SetPadding({Left=inset,Top=0,Right=inset,Bottom=0})
                    local switchBox=sized(switch,onOffWidth,onOffHeight)
                    local text=api.caption(tree,'')
                    api.Theme.font(text,api.theme,(tonumber(row.value.Font and row.value.Font.Size) or 14)-onOffTextShrink)
                    text:SetFont(text.Font);api.Theme.textColor(text,'body')
                    text:SetJustification(2);text:SetTextOverflowPolicy(1);text:SetRenderOpacity(onOffTextOpacity)
                    local lane=new('HorizontalBox')
                    local textSlot=add(lane,text)
                    textSlot:SetSize({SizeRule=1,Value=1});textSlot:SetVerticalAlignment(2)
                    textSlot:SetPadding({Left=0,Top=0,Right=onOffTextGap,Bottom=0})
                    add(lane,switchBox):SetVerticalAlignment(2)
                    local button,label=api.button(tree,'');button.IsFocusable=false
                    local area=new('Overlay')
                    for _,child in ipairs({lane,button}) do
                        local childSlot=add(area,child);childSlot:SetHorizontalAlignment(0);childSlot:SetVerticalAlignment(0)
                    end
                    lane.Slot:SetPadding({Left=0,Top=0,Right=width-onOffWidth-(width-onOffWidth)//2,Bottom=0})
                    local box=new('SizeBox');box:SetWidthOverride(width)
                    local areaSlot=api.need(box:SetContent(area),'MCS on/off area')
                    areaSlot:SetHorizontalAlignment(0);areaSlot:SetVerticalAlignment(0)
                    local slot=add(row.background:GetParent(),box)
                    slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(0)
                    slot:SetPadding({Left=left,Top=0,Right=0,Bottom=0})
                    row.mcOnOff={bars=bars,glow=glow,toggle=toggle,toggleBox=toggleBox,box=switchBox,text=text,
                        travel=onOffWidth-2*inset-(onOffWidth-2*inset)//2,position=0,hot=false}
                    row.mcTabs={{widget=button,label=label,value=1,pressed=false,pointer=false,onOff=true,box=box}}
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                elseif setting.mcTable then
                    -- Code and text pairs across the row in columns filled top to bottom.
                    -- Every code and every text sits centred in a cell of fixed size, at
                    -- least a line tall, so nothing is clipped off-centre, the columns stay
                    -- level and the texts line up whatever the codes' widths. Each pair is
                    -- centred in its column. Taller than tableMaxHeight, the table scrolls.
                    local width=PAGE_WIDTH-2*pickerRightMargin
                    local ok,entries,columns=pcall(textTable,setting.mcTable.text,setting.mcTable.columns)
                    local content,height
                    if ok then
                        local lines=math.max(1,math.ceil(#entries/columns))
                        local cell=math.floor(width/columns)
                        local codes,texts=0,0
                        for _,entry in ipairs(entries) do
                            codes=math.max(codes,utf8.len(entry.code));texts=math.max(texts,utf8.len(entry.text))
                        end
                        local textWidth=math.ceil(texts*em(tableText))+2*tablePad
                        local codeWidth=math.max(0,math.min(math.ceil(codes*em(tableCode)*2/3)+2*tablePad,cell-textWidth))
                        local function centred(widget,cellWidth)
                            widget:SetJustification(1)
                            local box=new('SizeBox');box:SetWidthOverride(cellWidth);box:SetHeightOverride(tableLine)
                            local slot=api.need(box:SetContent(widget),'MCS table cell')
                            slot:SetHorizontalAlignment(2);slot:SetVerticalAlignment(2)
                            return box
                        end
                        content=new('HorizontalBox')
                        for c=1,columns do
                            local column=new('VerticalBox')
                            for n=(c-1)*lines+1,math.min(c*lines,#entries) do
                                local pair=new('HorizontalBox')
                                local code=api.caption(tree,entries[n].code)
                                api.Theme.font(code,api.theme,tableCode);api.Theme.textColor(code,'muted')
                                add(pair,centred(code,codeWidth)):SetVerticalAlignment(2)
                                local text=api.caption(tree,entries[n].text)
                                api.Theme.font(text,api.theme,tableText)
                                add(pair,centred(text,textWidth)):SetVerticalAlignment(2)
                                local box=new('SizeBox');box:SetWidthOverride(cell);box:SetHeightOverride(tableLine)
                                local slot=api.need(box:SetContent(pair),'MCS table pair')
                                slot:SetHorizontalAlignment(2);slot:SetVerticalAlignment(2)
                                add(column,box)
                            end
                            add(content,column)
                        end
                        height=math.min(lines*tableLine,tableMaxHeight)
                    else
                        content=api.caption(tree,'Unavailable: '..tostring(entries))
                        api.Theme.font(content,api.theme,12);api.Theme.textColor(content,'muted')
                        content:SetAutoWrapText(true)
                        height=40
                    end
                    local scroll=new('ScrollBox')
                    add(scroll,content)
                    local box=new('SizeBox');box:SetWidthOverride(width);box:SetHeightOverride(height)
                    api.need(box:SetContent(scroll),'MCS table area')
                    local overlay=row.background:GetParent()
                    local slot=add(overlay,box);slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(2)
                    slot:SetPadding({Left=pickerRightMargin,Top=0,Right=0,Bottom=0})
                    row.wrapper:SetHeightOverride(height+16)
                    row.mcLabel:SetVisibility(1)
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                    row.mcTable={content=content,scroll=scroll,height=height}
                elseif setting.mcWrap then
                    -- A read-only value too long for DMM's picker: 13pt text in a wider
                    -- column, broken at commas below 34 characters; the row grows to fit.
                    local text,lines=M.wrapList(setting.labels[1] or '',34)
                    local value=api.caption(tree,text)
                    api.Theme.font(value,api.theme,13)
                    value:SetJustification(0);value:SetAutoWrapText(true)
                    local box=new('SizeBox');box:SetWidthOverride(PAGE_WIDTH-wrapLabelWidth-pickerRightMargin)
                    api.need(box:SetContent(value),'MCS wrapped value')
                    local overlay=row.background:GetParent()
                    local slot=add(overlay,box);slot:SetHorizontalAlignment(3);slot:SetVerticalAlignment(2)
                    slot:SetPadding({Left=0,Top=0,Right=pickerRightMargin,Bottom=0})
                    row.widget:GetParent():SetWidthOverride(wrapLabelWidth)
                    row.wrapper:SetHeightOverride(math.max(40,lines*18+12))
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                    row.mcWrapped=value
                elseif setting.mcChoiceNotes and row.value and not row.mcHeaderTabs then
                    -- A choice's note sits under DMM's value, small and muted like the
                    -- keybind editor's "default", inside the 40-pixel row. It overlays
                    -- the row so DMM's value button keeps its structure, taking the
                    -- value's width and place from DMM's own size boxes: after the
                    -- label column and left arrow. The text is centered in that width.
                    local function boxWidth(widget,fallback)
                        local ok,width=pcall(function() return widget:GetParent().WidthOverride end)
                        return ok and tonumber(width) or fallback
                    end
                    local left=boxWidth(row.widget,pickerLabelWidth)+boxWidth(row.parts[1].widget,pickerArrowWidth)
                    local note=api.caption(tree,'')
                    api.Theme.font(note,api.theme,noteSize);note:SetFont(note.Font)
                    api.Theme.textColor(note,'muted')
                    note:SetJustification(1);note:SetTextOverflowPolicy(1)
                    local box=new('SizeBox')
                    box:SetWidthOverride(boxWidth(row.parts[2].widget,pickerValueWidth));box:SetHeightOverride(16)
                    local noteSlot=api.need(box:SetContent(note),'MCS choice note')
                    noteSlot:SetHorizontalAlignment(2);noteSlot:SetVerticalAlignment(2)
                    local slot=add(row.background:GetParent(),box)
                    slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(3)
                    slot:SetPadding({Left=left,Top=0,Right=0,Bottom=noteRaise})
                    -- Never in the way of the value button underneath.
                    box:SetVisibility(1)
                    row.mcNote,row.mcNoteBox=note,box
                end
                -- A picker with arrows (<>) shows how many choices it has and which is
                -- current: pips, or a track and thumb for many choices, centered under the
                -- value in the row's bottom pixels, below any choice note.
                if setting.kind=='picker' and row.value and row.background and row.parts and #row.parts==3
                    and not row.mcTabs and not row.mcHeaderTabs and not setting.mcTabs and not setting.mcCycle
                    and not setting.mcOnOff
                    and not setting.mcTable and not setting.mcWrap
                    and not setting.mcReadOnly and #(setting.values or {})>=2 then
                    local function boxWidth(widget,fallback)
                        local ok,width=pcall(function() return widget:GetParent().WidthOverride end)
                        return ok and tonumber(width) or fallback
                    end
                    local value=boxWidth(row.parts[2].widget,pickerValueWidth)
                    local width=math.floor(value*pipShare/2)*2
                    local left=boxWidth(row.widget,pickerLabelWidth)+boxWidth(row.parts[1].widget,pickerArrowWidth)+(value-width)//2
                    local count=#setting.values
                    local box=new('SizeBox');box:SetWidthOverride(width);box:SetHeightOverride(pipActiveHeight)
                    local pips,pipBoxes={},{}
                    if count<=pipLimit then
                        local strip=new('HorizontalBox')
                        -- Pip n takes the n-th of count equal places (each with its gap), rounded.
                        local step=(width+pipGap)/count
                        local function edge(n) return math.floor(n*step+0.5) end
                        for n=1,count do
                            local pip=new('Border');pip:SetBrushColor(pipOff)
                            local each=math.max(1,edge(n)-edge(n-1)-pipGap)
                            local pipBox=new('SizeBox');pipBox:SetWidthOverride(each);pipBox:SetHeightOverride(pipHeight)
                            api.need(pipBox:SetContent(pip),'MCS picker pip')
                            local pipSlot=add(strip,pipBox)
                            pipSlot:SetPadding({Left=n>1 and pipGap or 0,Top=pipTop,Right=0,Bottom=0});pipSlot:SetVerticalAlignment(1)
                            pips[n],pipBoxes[n]=pip,pipBox
                        end
                        local stripSlot=api.need(box:SetContent(strip),'MCS picker pips')
                        stripSlot:SetHorizontalAlignment(2);stripSlot:SetVerticalAlignment(0)
                    else
                        -- Too many for pips: a track, and a thumb a choice wide at its place.
                        local stack=new('Overlay')
                        local track=new('Border');track:SetBrushColor(pipOff)
                        local trackBox=new('SizeBox');trackBox:SetHeightOverride(pipHeight)
                        api.need(trackBox:SetContent(track),'MCS picker track line')
                        local trackSlot=add(stack,trackBox);trackSlot:SetHorizontalAlignment(0);trackSlot:SetVerticalAlignment(2)
                        local thumb=new('Border');thumb:SetBrushColor(pipOn)
                        local thumbBox=new('SizeBox');thumbBox:SetHeightOverride(pipHeight)
                        thumbBox:SetWidthOverride(math.max(4,math.floor(width/count)))
                        api.need(thumbBox:SetContent(thumb),'MCS picker thumb')
                        local thumbSlot=add(stack,thumbBox);thumbSlot:SetHorizontalAlignment(1);thumbSlot:SetVerticalAlignment(1);thumbSlot:SetPadding({Left=0,Top=pipTop,Right=0,Bottom=0})
                        api.need(box:SetContent(stack),'MCS picker track')
                        row.mcPipThumb={slot=thumbSlot,box=thumbBox,width=math.max(4,math.floor(width/count)),span=width}
                    end
                    local slot=add(row.background:GetParent(),box)
                    slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(3)
                    slot:SetPadding({Left=left,Top=0,Right=0,Bottom=pipBottom})
                    row.mcPipLeft=left
                    -- Never in the way of the value button underneath.
                    box:SetVisibility(3);box:SetRenderOpacity(pipIdleOpacity)
                    row.mcPips,row.mcPipBoxes,row.mcPipBox,row.mcPipShown,row.mcPipHot=pips,pipBoxes,box,nil,false
                    -- The value's outer parts step like its arrows: two clear buttons over the
                    -- text, inside DMM's value button, so the row still reads as hovered over
                    -- them. The middle passes clicks to the value button, as before.
                    -- Wrappers are new on every lookup, so widgets compare by full name.
                    local valueButton=row.parts[2].widget
                    local holder=row.value:GetParent()
                    if holder and holder:GetFullName()==valueButton:GetFullName() then
                        local padding=row.value.Slot.Padding
                        local stack=new('Overlay')
                        -- A button centres new content; the zones need its whole width.
                        local stackSlot=api.need(valueButton:SetContent(stack),'MCS picker value zones')
                        stackSlot:SetHorizontalAlignment(0);stackSlot:SetVerticalAlignment(0)
                        stackSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
                        local textSlot=add(stack,row.value)
                        textSlot:SetHorizontalAlignment(0);textSlot:SetVerticalAlignment(2)
                        textSlot:SetPadding({Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom})
                        local lane=new('HorizontalBox')
                        local laneSlot=add(stack,lane);laneSlot:SetHorizontalAlignment(0);laneSlot:SetVerticalAlignment(0)
                        row.mcZones={}
                        for n,share in ipairs({stepZone,1-2*stepZone,stepZone}) do
                            local part=n==2 and new('Spacer') or api.button(tree,'')
                            if n~=2 then part.IsFocusable=false end
                            add(lane,part):SetSize({SizeRule=1,Value=share})
                            if n~=2 then
                                row.mcZones[#row.mcZones+1]={widget=part,arrow=n,direction=n==1 and 1 or 2,
                                    pressed=false,pointer=false}
                            end
                        end
                    end
                end
                -- A one-line picker row is pickerRowHeight tall: its columns grow with it and
                -- their content sits 1 pixel lower, so 1 pixel more above and 2 below. With
                -- choice notes it is notedPickerRowHeight, its content centred: 1 more each way.
                if setting.kind=='picker' and row.parts and #row.parts==3
                    and tonumber(row.wrapper.HeightOverride)==40 then
                    local noted=setting.mcChoiceNotes~=nil
                    local height=noted and notedPickerRowHeight or pickerRowHeight
                    row.wrapper:SetHeightOverride(height)
                    for _,widget in ipairs({row.widget,row.parts[1].widget,row.parts[2].widget,row.parts[3].widget}) do
                        widget:GetParent():SetHeightOverride(height)
                        widget.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=noted and 0 or 1})
                    end
                end
            end
            -- Sliders: DMM's track and value column give way to one control holding the value,
            -- centred, and the bar; the native slider, still taking input, spans the bar. The
            -- control takes a picker's value column, so every value lines up.
            for i,row in ipairs(panel.rows) do
                local setting=providers[index].choices[i]
                local surface=row.slider and row.slider:GetParent()
                if setting.kind=='slider' and surface and row.value then
                    local surfaceBox,valueBox=surface:GetParent(),row.value:GetParent()
                    local width=pickerValueWidth
                    local span=math.floor(width*sliderShare/2)*2
                    local margin=(width-span)/2
                    row.widget:GetParent():SetWidthOverride(pickerValueLeft)
                    surfaceBox:SetWidthOverride(width)
                    valueBox:SetWidthOverride(0);valueBox:SetVisibility(1)
                    local track=surface:GetChildAt(0)
                    if track and track~=row.slider then track:SetVisibility(1) end
                    row.slider.Slot:SetPadding({Left=margin,Top=0,Right=margin,Bottom=0})
                    -- DMM shows the native handle on a hovered or selected row; the mark
                    -- replaces it. Opacity leaves the slider's input as it was.
                    row.slider:SetRenderOpacity(0)
                    local value=row.value
                    value:RemoveFromParent()
                    api.Theme.font(value,api.theme,(tonumber(value.Font and value.Font.Size) or 14)-sliderValueShrink)
                    value:SetFont(value.Font);value:SetJustification(1);value:SetVisibility(3)
                    -- Across the whole control, its text centred: the text's centre is the control's.
                    local valueSlot=add(surface,value);valueSlot:SetHorizontalAlignment(0);valueSlot:SetVerticalAlignment(2)
                    valueSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=2*sliderValueLift})
                    local function line(color,lineWidth,height)
                        local fill=new('Border');fill:SetBrushColor(color)
                        local box=new('SizeBox');box:SetHeightOverride(height)
                        if lineWidth then box:SetWidthOverride(lineWidth) end
                        api.need(box:SetContent(fill),'MCS slider line')
                        return box
                    end
                    local bar=new('SizeBox');bar:SetWidthOverride(span);bar:SetHeightOverride(sliderMarkHeight)
                    local stack=new('Overlay')
                    api.need(bar:SetContent(stack),'MCS slider bar')
                    local strip=new('HorizontalBox')
                    local filled=line(pipOn,0,pipActiveHeight)
                    add(strip,filled):SetVerticalAlignment(2)
                    local restSlot=add(strip,line(pipOff,nil,pipHeight))
                    restSlot:SetVerticalAlignment(2);restSlot:SetSize({SizeRule=1,Value=1})
                    local stripBox=new('SizeBox');stripBox:SetHeightOverride(pipActiveHeight)
                    api.need(stripBox:SetContent(strip),'MCS slider strip')
                    local stripSlot=add(stack,stripBox);stripSlot:SetHorizontalAlignment(0);stripSlot:SetVerticalAlignment(1)
                    stripSlot:SetPadding({Left=0,Top=sliderMarkAbove,Right=0,Bottom=0})
                    local mark=new('HorizontalBox')
                    for _,color in ipairs({pipOff,pipOn,pipOff}) do add(mark,line(color,1,sliderMarkHeight)) end
                    local markSlot=add(stack,mark);markSlot:SetHorizontalAlignment(1);markSlot:SetVerticalAlignment(1)
                    mark:SetVisibility(1)
                    local barSlot=add(surface,bar);barSlot:SetHorizontalAlignment(2);barSlot:SetVerticalAlignment(3)
                    barSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=sliderBottom})
                    bar:SetVisibility(3);bar:SetRenderOpacity(pipIdleOpacity)
                    row.mcSlider={bar=bar,filled=filled,mark=mark,markSlot=markSlot,span=span,hot=false,shown=nil}
                end
            end
            -- Subgroup rows are compact: every box as tall as the row loses nestedRowShrink
            -- pixels, and the value text nestedValueShrink points, raised nestedValueLift.
            for i,row in ipairs(panel.rows) do
                local setting=providers[index].choices[i]
                local height=tonumber(row.wrapper.HeightOverride)
                if subgroupRow(setting) and height and nestedRowShrink>0 then
                    local function shrink(widget)
                        if tonumber(widget.HeightOverride)==height then widget:SetHeightOverride(height-nestedRowShrink) end
                        local ok,count=pcall(function() return widget:GetChildrenCount() end)
                        for n=0,(ok and tonumber(count) or 0)-1 do shrink(widget:GetChildAt(n)) end
                    end
                    shrink(row.wrapper)
                end
                if subgroupRow(setting) and nestedValueShrink>0 then
                    for _,text in ipairs({row.value,row.mcOnOff and row.mcOnOff.text}) do
                        api.Theme.font(text,api.theme,(tonumber(text.Font and text.Font.Size) or 14)-nestedValueShrink)
                        text:SetFont(text.Font)
                    end
                    row.mcValueLift=nestedValueLift
                    if row.mcSlider then
                        local padding=row.value.Slot.Padding
                        row.value.Slot:SetPadding({Left=padding.Left,Top=padding.Top,Right=padding.Right,
                            Bottom=padding.Bottom+nestedValueLift})
                    end
                end
            end
            -- A read-only row is never selected: the pointer passes through its buttons, so it is
            -- not hovered or clicked either.
            for i,row in ipairs(panel.rows) do
                if providers[index].choices[i].mcReadOnly then
                    row.widget:SetVisibility(3)
                    for _,part in ipairs(row.parts or {}) do part.widget:SetVisibility(3) end
                end
            end
            -- As in the game's own settings, a picker shows its arrows only while its row is
            -- hovered or selected. Hidden arrows keep their place, so the value never moves.
            -- Arrows a decoration already collapsed stay collapsed.
            for i,row in ipairs(panel.rows) do
                if providers[index].choices[i].kind=='picker' and row.parts and #row.parts==3 then
                    local boxes={}
                    for _,n in ipairs({1,3}) do
                        local box=row.parts[n].widget:GetParent()
                        local shown=box:GetVisibility()
                        if shown~=1 then boxes[#boxes+1]={box=box,shown=shown};box:SetVisibility(2) end
                    end
                    if #boxes>0 then row.mcArrowBoxes,row.mcArrowsHot=boxes,false end
                end
            end
            local parentWidgets={}
            for _,heading in ipairs(panel.headings) do
                local setting=providers[index].choices[heading.first]
                local slot=heading.widget.Slot
                local padding=slot.Padding
                slot:SetPadding({Left=categoryLeft,Top=categoryTop,Right=padding.Right,Bottom=padding.Bottom})
                api.Theme.font(heading.widget,api.theme,categorySize)
                if setting.mcGroup and setting.mcGroup.within then
                    heading.mcSubheading=true
                    slot:SetPadding({Left=rowIndent+subheadingShift,Top=subheadingTop,Right=padding.Right,Bottom=padding.Bottom})
                    api.Theme.font(heading.widget,api.theme,subheadingSize)
                    local help=helpWidgets[heading.widget]
                    if help then
                        local p=help.Slot.Padding
                        help.Slot:SetPadding({Left=rowIndent+nestedIndent,Top=p.Top,Right=p.Right,Bottom=p.Bottom})
                    end
                end
                if setting.mcGroup then M.style(heading.widget,setting.mcGroup.font,api) end
                if heading.mcSubheading then api.Theme.textColor(heading.widget,'title') end
                -- Theme.font only writes the property; a built heading shows it after SetFont.
                heading.widget:SetFont(heading.widget.Font)
                if setting.mcGroup then
                    if not setting.mcGroup.heading then
                        heading.widget:SetVisibility(1);heading.visible=false
                    end
                    local parent=setting.mcGroup.parent
                    if parent then
                        heading.mcParent=parent
                        if not parentWidgets[parent.key] then
                            local label=api.caption(tree,parent.label)
                            local widget=label
                            if parent.category then
                                -- A category heading drawn for subgroups whose category
                                -- has no rows: DMM's heading look (left, muted), its size,
                                -- and its rule.
                                label:SetJustification(0)
                                api.Theme.textColor(label,'muted')
                                api.Theme.font(label,api.theme,categorySize);label:SetFont(label.Font)
                                widget=api.construct('/Script/UMG.VerticalBox',tree)
                                add(widget,label)
                                local rule=api.construct('/Script/UMG.Border',tree);rule:SetBrushColor(headerSeparatorDim)
                                local box=api.construct('/Script/UMG.SizeBox',tree);box:SetHeightOverride(1)
                                api.need(box:SetContent(rule),'MCS heading rule')
                                add(widget,box):SetPadding({Left=0,Top=0,Right=0,Bottom=categoryRuleBottom})
                            else M.style(label,parent.font,api) end
                            add(panel.scroll,widget):SetPadding(parentPadding(parent))
                            parentWidgets[parent.key]={widget=widget,parent=parent}
                        end
                    end
                end
            end
            -- Capture existing scroll children only once, after construction.
            -- Ordering moves whole category blocks; rows retain their children.
            local ordered=false
            for _,s in ipairs(providers[index].choices) do if s.mcGroup and s.mcGroup.order then ordered=true end end
            if ordered or next(parentWidgets) then
                panel.mcBlocks={}
                -- Known widgets are kept by full name: GetChildAt answers with a new
                -- wrapper each time, never equal to the one captured.
                local known={}
                local function capture(block,child)
                    local p=child.Slot.Padding
                    block.children[#block.children+1]={widget=child,padding={Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom}}
                    known[child:GetFullName()]=true
                end
                for _,heading in ipairs(panel.headings) do
                    local block={heading=heading,parent=heading.mcParent,children={}};panel.mcBlocks[#panel.mcBlocks+1]=block
                    capture(block,heading.widget)
                    if headingRules[heading.widget] then capture(block,headingRules[heading.widget]) end
                    if helpWidgets[heading.widget] then capture(block,helpWidgets[heading.widget]) end
                    for i=heading.first,heading.last do
                        capture(block,panel.rows[i].mcPlaceholder or panel.rows[i].wrapper)
                        if categoryRules[panel.rows[i].widget] then capture(block,categoryRules[panel.rows[i].widget]) end
                    end
                end
                local extra={children={}}
                -- Parent headings were added only to obtain real UMG widgets.
                -- They are rebuilt from mcLayout and must not become extras.
                for _,entry in pairs(parentWidgets) do known[entry.widget:GetFullName()]=true end
                for n=0,panel.scroll:GetChildrenCount()-1 do
                    local child=panel.scroll:GetChildAt(n)
                    if not known[child:GetFullName()] then capture(extra,child) end
                end
                panel.mcLayout={}
                local entriesByParent={}
                local unparented
                for _,block in ipairs(panel.mcBlocks) do
                    local entry
                    if block.parent then
                        entry=entriesByParent[block.parent.key]
                        if not entry then
                            entry={parent=block.parent,parentWidget=parentWidgets[block.parent.key].widget,blocks={}}
                            entriesByParent[block.parent.key]=entry;panel.mcLayout[#panel.mcLayout+1]=entry
                        end
                        unparented=nil
                    else
                        if not unparented then unparented={blocks={}};panel.mcLayout[#panel.mcLayout+1]=unparented end
                        entry=unparented
                    end
                    entry.blocks[#entry.blocks+1]=block
                end
                if #extra.children>0 then panel.mcLayout[#panel.mcLayout+1]={blocks={extra},extra=true} end
                panel.mcParentWidgets=parentWidgets
            end
            panel.mcPresented=true
        end
        -- Construction state never outlives DMM's build, even when the build fails.
        function ui:prepare(index,...)
            constructing,buttonSettingIndex,buttonsToSkip,pendingHeading,pendingCategoryRule=index,0,0,nil,nil
            local results=table.pack(pcall(prepare,self,index,...))
            if results[1] then
                local ruled,why=pcall(addCategoryRule)
                if not ruled then results={false,why,n=2} end
            end
            constructing,pendingHeading,pendingCategoryRule=nil,nil,nil
            if not results[1] then error(results[2],0) end
            decorate(index)
            return table.unpack(results,2,results.n)
        end
        function ui:show(index,...) stopChoiceSound();self:prepare(index);return show(self,index,...) end
        if hide then function ui:hide(...) stopChoiceSound();return hide(self,...) end end
        local function readOnly(self,index)
            local setting=self.model and self.model.items and self.model.items[index]
            return setting~=nil and setting.mcReadOnly==true
        end
        function ui:select(index,...)
            if index and readOnly(self,index) then return end
            return select(self,index,...)
        end
        local function dynamic(rule,model,fallback)
            if not rule then return fallback end
            for i,s in ipairs(model.items) do
                if s.id==rule.source.id then return rule.values[model.pending[i]] or fallback end
            end
            return fallback
        end
        function ui:refresh(...)
            if self.active then decorate(self.active) end
            -- DMM refreshes controls while a native press may still be held. Keep
            -- the press origin until the release handler observes the release.
            local pressed={}
            if self.active then
                for i,row in ipairs(self.panels[self.active].rows) do
                    local state={row.pressed,row.pointer,parts={}}
                    for n,part in ipairs(row.parts or {}) do
                        state.parts[n]={part.pressed,part.pointer}
                    end
                    pressed[i]=state
                end
            end
            local result=refresh(self,...)
            -- A slider's bar fills to its pending value; the mark stands at the fill's end. The
            -- first value shows at rest; a change slides the fill from where it is, like a
            -- picker's value. A drag restarts the slide each tick, so the fill follows closely.
            for i,row in ipairs(self.panels[self.active].rows) do
                local bar=row.mcSlider
                local setting=bar and self.model.items[i]
                local value=bar and self.model.pending[i]
                if bar and setting and type(value)=='number' and setting.maximum~=setting.minimum then
                    local share=math.max(0,math.min(1,(value-setting.minimum)/(setting.maximum-setting.minimum)))
                    local target=math.floor(share*bar.span+0.5)
                    local function fill(width)
                        local filled=math.floor(width+0.5)
                        if bar.shown~=filled then
                            bar.filled:SetWidthOverride(filled)
                            bar.markSlot:SetPadding({Left=math.max(0,math.min(bar.span-3,filled-1)),Top=0,Right=0,Bottom=0})
                            bar.shown=filled
                        end
                        bar.width=width
                    end
                    if bar.target==nil then fill(target)
                    elseif bar.target~=target then
                        local from=bar.width
                        animate(bar,valueSlide,function(t) fill(from+(target-from)*t) end)
                    end
                    bar.target=target
                end
            end
            -- At the first or last choice DMM disables and hides that arrow; it shows faint
            -- instead and stays enabled, so a click on it can wrap around (see wrapEdge). Both
            -- hidden (a disabled picker) stays hidden.
            for _,row in ipairs(self.panels[self.active].rows) do
                -- DMM sets an arrow's state only when it changes, so the faint one is set
                -- again on every refresh rather than remembered.
                local arrow=edgeArrow(row)
                if arrow then
                    arrow.widget:SetIsEnabled(true)
                    arrow.widget:SetRenderOpacity(edgeArrowOpacity)
                end
            end
            for i,state in ipairs(pressed) do
                local row=self.panels[self.active].rows[i]
                if row.visible then
                    row.pressed,row.pointer=state[1],state[2]
                    for n,part in ipairs(row.parts or {}) do
                        local old=state.parts[n]
                        if old then part.pressed,part.pointer=old[1],old[2] end
                    end
                end
            end
            local pageReady=false
            for i,row in ipairs(self.panels[self.active].rows) do
                local setting=self.model.items[i]
                if row.mcHeader then row.wrapper:SetVisibility(row.visible and 0 or 1) end
                if row.mcHeaderTabsBox then row.mcHeaderTabsBox:SetVisibility(row.visible and 0 or 1) end
                if setting.mcLabelRule then
                    local text=dynamic(setting.mcLabelRule,self.model,setting.label)
                    if text~=row.mcLabelText then api.setText(row.mcLabel,text);row.mcLabelText=text end
                end
                if setting.mcDimValues then
                    local dim=setting.mcDimValues[self.model.pending[i]]==true
                    if row.mcDim~=dim then row.wrapper:SetRenderOpacity(dim and fadedOpacity or 1);row.mcDim=dim end
                end
                if row.mcNote then
                    -- The value moves up to make room while its choice has a note.
                    local note=setting.mcChoiceNotes[self.model.pending[i]]
                    if note~=row.mcNoteText then
                        if note then api.setText(row.mcNote,note) end
                        row.mcNoteBox:SetVisibility(note and 3 or 1)
                        local padding=row.value.Slot.Padding
                        row.value.Slot:SetPadding({Left=padding.Left,Top=padding.Top,
                            Right=padding.Right,Bottom=(note and noteValueLift or 0)+(row.mcValueLift or 0)})
                        row.mcNoteText=note
                    end
                end
                if row.mcPipBox then
                    -- Showing no note, the value is smaller and it and the indicator sit a little higher.
                    local noted=row.mcNoteText~=nil
                    if row.mcPipNoted~=noted then
                        row.mcValueSize=row.mcValueSize or tonumber(row.value.Font and row.value.Font.Size) or 14
                        api.Theme.font(row.value,api.theme,noted and row.mcValueSize or row.mcValueSize-plainValueShrink)
                        row.value:SetFont(row.value.Font)
                        local padding=row.value.Slot.Padding
                        row.value.Slot:SetPadding({Left=padding.Left,Top=padding.Top,Right=padding.Right,
                            Bottom=(noted and noteValueLift or plainValueLift)+(row.mcValueLift or 0)})
                        row.mcPipBox.Slot:SetPadding({Left=row.mcPipLeft,Top=0,Right=0,
                            Bottom=noted and pipBottom or pipBottom+plainPipLift})
                        row.mcPipNoted=noted
                    end
                    local current=1
                    for n,value in ipairs(setting.values) do if value==self.model.pending[i] then current=n end end
                    if row.mcPipShown~=current then
                        local previous,thumb,value=row.mcPipShown,row.mcPipThumb,row.value
                        local function place(n)
                            local offset=math.floor((n-1)*(thumb.span-thumb.width)/math.max(1,#setting.values-1))
                            thumb.slot:SetPadding({Left=offset,Top=pipTop,Right=0,Bottom=0})
                        end
                        for n,pip in ipairs(row.mcPips) do pip:SetBrushColor(n==current and pipOn or pipOff) end
                        if previous then
                            -- The new value slides in from the side it was stepped towards, which
                            -- a wrap around reverses.
                            local side=row.mcStepSide or (current>previous and 1 or -1)
                            animate(value,valueSlide,function(t)
                                value:SetRenderTranslation({X=side*valueSlideDistance*(1-t),Y=0})
                                value:SetRenderOpacity(t)
                            end)
                            local pips=row.mcPips
                            if pips[previous] then
                                animate(pips,valueSlide,function(t)
                                    pips[previous]:SetBrushColor(mix(pipOn,pipOff,t))
                                    pips[current]:SetBrushColor(mix(pipOff,pipOn,t))
                                end)
                            end
                            if thumb then
                                animate(thumb,valueSlide,function(t)
                                    thumb.box:SetRenderOpacity(math.abs(1-2*t))
                                    place(t<0.5 and previous or current)
                                end)
                            end
                        elseif thumb then place(current) end
                        row.mcPipShown,row.mcStepSide=current,nil
                        sizePips(row)
                    end
                end
                for _,tab in ipairs(row.mcTabs or {}) do
                    if tab.cycle then
                        local current,shown=self.model.pending[i],1
                        for n,value in ipairs(setting.values) do if value==current then shown=n end end
                        if tab.shown~=shown then api.setText(tab.label,setting.labels[shown]);tab.shown=shown end
                        tab.value=setting.values[shown%#setting.values+1]
                    end
                    if tab.onOff then
                        -- A click sets the other value.
                        local on=self.model.pending[i]==1
                        tab.value=on and 0 or 1
                        local text=setting.labels[on and 2 or 1]
                        if row.mcOnOff.shownText~=text then api.setText(row.mcOnOff.text,text);row.mcOnOff.shownText=text end
                        -- The first value shows at rest; a change slides from where the toggle is.
                        local switch=row.mcOnOff
                        if switch.on==nil then
                            switch.position=on and 1 or 0
                            paintOnOff(switch)
                        elseif switch.on~=on then
                            local from,to=switch.position,on and 1 or 0
                            animate(switch,onOffSlide,function(t)
                                switch.position=from+(to-from)*t
                                paintOnOff(switch)
                            end)
                        end
                        switch.on=on
                    end
                    local mapping=self.model.items[i].mcMapping
                    local enabled=not setting.mcReadOnly and not self.model.error and (not mapping or tab.value~=mapping.custom)
                    local current=self.model.pending[i]
                    local selected=current==tab.value
                    if tab.selected~=selected or tab.enabled~=enabled then
                        api.Theme.textColor(tab.label,selected and 'menuActive' or 'body')
                        tab.widget:SetIsEnabled(enabled)
                        tab.widget:SetRenderOpacity((enabled or selected) and 1 or fadedOpacity)
                        if tab.onOff then tab.box:SetRenderOpacity(enabled and 1 or fadedOpacity) end
                        for _,bar in ipairs(tab.outline or {}) do
                            bar:SetBrushColor(selected and headerSeparatorBright or headerSeparatorDim)
                        end
                        tab.selected,tab.enabled=selected,enabled
                    end
                    if not row.visible or not enabled then tab.pressed,tab.pointer=false,false end
                end
                if row.mcHeaderSeparators then
                    for _,tab in ipairs(row.mcTabs) do paintHeaderTab(tab) end
                    -- The focus highlight follows the selected tab.
                    if row.mcFocusAlpha then focusHeaderTabs(row) end
                end
            end
            for index,panel in ipairs(self.panels) do
                if index~=self.active and panel.mcHeader then
                    panel.mcHeader.wrapper:SetVisibility(1)
                    if panel.mcHeader.mcHeaderTabsBox then panel.mcHeader.mcHeaderTabsBox:SetVisibility(1) end
                end
            end
            local status=self.mcHeaderStatus
            if status then
                local header=self.panels[self.active].mcHeader
                local used=header and header.visible and header.mcHeaderTabsWidth or 0
                local free=ROW_WIDTH-used-headerStatusGap
                local beside=used==0 or free>=headerStatusMinWidth
                local width=(used==0 or not beside) and ROW_WIDTH or free
                local top=beside and 0 or headerTabHeight
                if status.width~=width or status.top~=top then
                    status.box:SetWidthOverride(width)
                    local p=status.padding
                    status.slot:SetPadding({Left=p.Left,Top=p.Top+top,Right=p.Right,Bottom=p.Bottom})
                    status.width,status.top=width,top
                end
            end
            for _,heading in ipairs(self.panels[self.active].headings) do
                local setting=self.model.items[heading.first]
                local shown=false
                for i=heading.first,heading.last do
                    local row=self.panels[self.active].rows[i]
                    if row.visible and not row.mcHeader then shown=true;break end
                end
                local group=setting.mcGroup
                heading.mcContentVisible=shown
                local headingShown=shown and (not group or group.heading)
                if heading.visible~=headingShown then
                    heading.widget:SetVisibility(headingShown and 0 or 1);heading.visible=headingShown
                end
                if group and (group.labelRule or group.label) then
                    local text=dynamic(group.labelRule,self.model,group.label or setting.group)
                    if heading.text~=text then api.setText(heading.widget,text);heading.text=text end
                end
                -- A subgroup heading has no rule.
                local rule=headingRules[heading.widget]
                local ruleShown=heading.visible and not heading.mcSubheading
                if rule and heading.mcRuleVisible~=ruleShown then
                    rule:SetVisibility(ruleShown and 4 or 1);heading.mcRuleVisible=ruleShown
                end
                local help=helpWidgets[heading.widget]
                if help and heading.mcHelpVisible~=heading.visible then
                    help:SetVisibility(heading.visible and 4 or 1);heading.mcHelpVisible=heading.visible
                end
            end
            local panel=self.panels[self.active]
            local visible={}
            for i,row in ipairs(panel.rows) do visible[i]=row.visible and '1' or '0' end
            local visibilitySignature=table.concat(visible)
            if panel.mcVisibility and panel.mcVisibility~=visibilitySignature then pageReady=true end
            panel.mcVisibility=visibilitySignature
            if panel.mcBlocks then
                local signatureParts,orderedFlat={},{}
                local function reorder(blocks)
                    local slots,candidates,result={},{},{}
                    for n,block in ipairs(blocks) do
                        result[n]=block
                        local s=block.heading and self.model.items[block.heading.first]
                        local rule=s and s.mcGroup and s.mcGroup.order
                        local rank=dynamic(rule,self.model,n)
                        signatureParts[#signatureParts+1]=(block.heading and tostring(block.heading.first) or 'extra')..'='..tostring(rank)
                        if rule then
                            slots[#slots+1]=n;candidates[#candidates+1]={block=block,rank=rank,original=n}
                        end
                    end
                    table.sort(candidates,function(a,b) return a.rank==b.rank and a.original<b.original or a.rank<b.rank end)
                    for n,position in ipairs(slots) do result[position]=candidates[n].block end
                    return result
                end
                for _,entry in ipairs(panel.mcLayout) do
                    signatureParts[#signatureParts+1]='parent='..(entry.parent and entry.parent.key or '')
                    entry.orderedBlocks=reorder(entry.blocks)
                    for _,block in ipairs(entry.orderedBlocks) do
                        if block.heading then orderedFlat[#orderedFlat+1]=block end
                    end
                end
                local signature=table.concat(signatureParts,':')
                if signature~=panel.mcOrder or not panel.mcLayoutBuilt then
                    panel.scroll:ClearChildren()
                    for _,entry in ipairs(panel.mcLayout) do
                        if entry.parentWidget then
                            add(panel.scroll,entry.parentWidget):SetPadding(parentPadding(entry.parent))
                        end
                        for _,block in ipairs(entry.orderedBlocks) do
                            for _,child in ipairs(block.children) do add(panel.scroll,child.widget):SetPadding(child.padding) end
                        end
                    end
                    if panel.mcLayoutBuilt then pageReady=true end
                    panel.mcOrder=signature
                    panel.mcLayoutBuilt=true
                end
                panel.mcOrderedBlocks=orderedFlat
                for _,entry in ipairs(panel.mcLayout) do
                    if entry.parentWidget then
                        local shown=false
                        for _,block in ipairs(entry.blocks) do
                            if block.heading and block.heading.mcContentVisible then shown=true;break end
                        end
                        if entry.parentVisible~=shown then
                            entry.parentWidget:SetVisibility(shown and 4 or 1);entry.parentVisible=shown
                        end
                    end
                end
            end
            local categoryAdded=false
            local function alignRows(heading)
                if heading.visible then categoryAdded=true end
                for i=heading.first,heading.last do
                    local row,setting=panel.rows[i],self.model.items[i]
                    if row.mcLabel and setting.mcFont==nil and not setting.mcHeader then
                        -- An mcCategory row stands in for its group's heading: it takes
                        -- the heading's look, and the rows after it indent beneath it.
                        local beforeCategory=setting.mcCategory or not categoryAdded
                        if setting.mcCategory and row.visible then categoryAdded=true end
                        -- Its rule shows with it.
                        local rule=categoryRules[row.widget]
                        if rule and row.mcCategoryRuleVisible~=(row.visible==true) then
                            rule:SetVisibility(row.visible and 4 or 1);row.mcCategoryRuleVisible=row.visible==true
                        end
                        -- A subgroup's rows indent further, a little smaller.
                        local nested=not beforeCategory and subgroupRow(setting)
                        local style=beforeCategory and 'category' or nested and 'nested' or 'row'
                        if row.mcCategoryStyle~=style then
                            api.Theme.font(row.mcLabel,api.theme,beforeCategory and categorySize
                                or nested and 14-nestedShrink or 14)
                            row.mcLabel:SetFont(row.mcLabel.Font)
                            api.Theme.textColor(row.mcLabel,beforeCategory and 'muted' or 'body')
                            starStyle(row)
                            row.mcCategoryStyle=style
                        end
                        local labelSlot=toggleShell(setting) and row.widget:GetContent().Slot
                            or row.mcLabel.Slot
                        local labelPadding=labelSlot.Padding
                        local indent=beforeCategory and categoryLeft
                            or rowIndent+(nested and nestedIndent or 0)+(rowButtonInset[row.widget] or 0)
                        if row.mcCyclePlace then row.mcCyclePlace(indent) end
                        local contentLeft=toggleShell(setting) and not row.background and indent+toggleShift or indent
                        if labelPadding.Left~=contentLeft then
                            labelSlot:SetPadding({Left=contentLeft,Top=labelPadding.Top,
                                Right=labelPadding.Right,Bottom=labelPadding.Bottom})
                        end
                        -- A toggle's label and value sit in its indented content: its label
                        -- column ends where a picker's value column starts, and its value
                        -- takes that column's width.
                        local content=setting.kind=='toggle' and row.value and row.widget:GetContent()
                        if content and row.mcToggleIndent~=indent and content:GetChildrenCount()==2 then
                            content:GetChildAt(0):SetWidthOverride(pickerValueLeft-indent)
                            content:GetChildAt(1):SetWidthOverride(pickerValueWidth)
                            row.mcToggleIndent=indent
                        end
                        -- A keybind's key box is centred on a picker's value column, whatever
                        -- the row's indent; the editor ends at the row's 584 less the button's
                        -- 12-pixel right padding.
                        local keyLane=keyColumn and setting.kind=='extension' and setting.editor=='keybind'
                            and row.widget:GetContent()
                        if keyLane and row.mcKeyIndent~=indent and keyLane:GetChildrenCount()==2 then
                            local label=keyLeft()-indent-keyColumn.mode-keyColumn.gap
                            keyLane:GetChildAt(0):SetWidthOverride(label)
                            keyLane:GetChildAt(1):SetWidthOverride(ROW_WIDTH-indent-label)
                            row.mcKeyIndent=indent
                        end
                        -- A range's track starts where a picker's value column does and
                        -- runs, with its caption, to the row's end.
                        local rangeLane=setting.kind=='extension' and setting.editor=='range'
                            and row.widget:GetContent()
                        if rangeLane and row.mcRangeIndent~=indent and rangeLane:GetChildrenCount()==2 then
                            rangeLane:GetChildAt(0):SetWidthOverride(pickerValueLeft-indent)
                            rangeLane:GetChildAt(1):SetWidthOverride(ROW_WIDTH-pickerValueLeft)
                            row.mcRangeIndent=indent
                        end
                        local wrapperSlot=row.wrapper.Slot
                        local wrapperPadding=wrapperSlot.Padding
                        -- An mcCategory row's rule hugs it, with no space between.
                        local top=beforeCategory and categoryTop or 0
                        local bottom=beforeCategory and not setting.mcCategory and 4 or 0
                        if wrapperPadding.Top~=top or wrapperPadding.Bottom~=bottom then
                            wrapperSlot:SetPadding({Left=wrapperPadding.Left,Top=top,
                                Right=wrapperPadding.Right,Bottom=bottom})
                        end
                    end
                end
            end
            if panel.mcLayout then
                for _,entry in ipairs(panel.mcLayout) do
                    if entry.parentWidget and entry.parentVisible then categoryAdded=true end
                    for _,block in ipairs(entry.orderedBlocks) do
                        if block.heading then alignRows(block.heading) end
                    end
                end
            else
                for _,heading in ipairs(panel.headings) do alignRows(heading) end
            end
            if panel.mcBlocks then
                if self.visibleRows then
                    local visible={}
                    -- Header controls precede scroll content for navigation.
                    for i,row in ipairs(panel.rows) do if row.mcHeader and row.visible then visible[#visible+1]=i end end
                    for _,block in ipairs(panel.mcOrderedBlocks or panel.mcBlocks) do
                        if block.heading then
                            for i=block.heading.first,block.heading.last do
                                if panel.rows[i].visible and not panel.rows[i].mcHeader and not readOnly(self,i) then
                                    visible[#visible+1]=i
                                end
                            end
                        end
                    end
                    self.visibleRows=visible;self:wireNavigation(self.footer)
                end
            end
            if self.visibleRows and not panel.mcBlocks then
                local navigation={}
                for i,row in ipairs(panel.rows) do
                    if row.visible and not readOnly(self,i) then navigation[#navigation+1]=i end
                end
                self.visibleRows=navigation;self:wireNavigation(self.footer)
            end
            -- DMM may have selected a read-only row before it was left out: move to the nearest
            -- selectable row above it, else the first.
            if self.visibleRows and self.current and readOnly(self,self.current) then
                local replacement=self.visibleRows[1]
                for _,i in ipairs(self.visibleRows) do if i<self.current then replacement=i else break end end
                select(self,replacement,true)
            end
            -- Field types mark the pickers separating colliding keybinds on each refresh.
            local separating=not self.model.error and self.model.mcConflictPickers or {}
            for i,row in ipairs(panel.rows) do
                local red=separating[i]==true
                if row.parts and #row.parts==3 and not row.mcTabs and (row.mcConflictRed or false)~=red then
                    conflictStyle(row,red)
                    row.mcConflictRed=red
                end
            end
            if pageReady then
                -- Cached panels have no stable child index after eviction.
                -- Notify decorators directly without changing the selected widget.
                if api.events then
                    api.events:emit('providerRefreshed',{tree=tree,provider=providers[self.active],panel=panel,pc=api.pc})
                end
            end
            return result
        end
        -- Steps picker i one choice in DMM's direction (1 left, 2 right), wrapping around at
        -- either end, as a click does.
        local function step(self,i,direction)
            local setting,row=self.model.items[i],self.panels[self.active].rows[i]
            local count,index=#setting.values,1
            for n,value in ipairs(setting.values) do if value==self.model.pending[i] then index=n end end
            row.mcStepSide=direction==1 and -1 or 1
            self:select(i,false);self.model:set(i,setting.values[(index-1+row.mcStepSide)%count+1]);self:refresh()
            if adapted.feedback then adapted.feedback('Change') end
        end
        function ui:tick(queued,released,controller)
            stepAnimations()
            if self.active and not self.model.error then
                for i,row in ipairs(self.panels[self.active].rows) do
                    if row.visible then
                        -- The transparent navigation slider sits behind picker
                        -- buttons. A mouse drag can move it without a new picker
                        -- choice; only controller navigation may drive that slider.
                        if not controller and not row.slider and row.lastNavigation~=nil then
                            if row.nav:GetValue()~=row.lastNavigation then
                                row.nav:SetValue(row.lastNavigation)
                            end
                        end
                        -- Native sliders expose raw floats, while the model stores
                        -- snapped values. Do not replay Change for a different raw
                        -- float that resolves to the already selected value.
                        if row.slider and row.lastValue~=nil then
                            local value=row.slider:GetValue()
                            local setting=self.model.items[i]
                            if value~=row.lastValue and setting.step and
                                choices.snap(setting,setting.minimum+value*(setting.maximum-setting.minimum))
                                    ==self.model.pending[i] then
                                row.lastValue=value
                            end
                        end
                        if row.mcPipBox then
                            -- Full strength while its row is hovered or selected (the row
                            -- the keys and a controller move); DMM records both each tick.
                            local hot=self.hovered==i or self.current==i
                            if row.mcPipHot~=hot then
                                row.mcPipBox:SetRenderOpacity(hot and 1 or pipIdleOpacity);row.mcPipHot=hot
                                sizePips(row)
                            end
                        end
                        if row.mcSlider then
                            -- Full strength, with its mark, while hovered or selected.
                            local hot=self.hovered==i or self.current==i
                            if row.mcSlider.hot~=hot then
                                row.mcSlider.bar:SetRenderOpacity(hot and 1 or pipIdleOpacity)
                                row.mcSlider.mark:SetVisibility(hot and 3 or 1)
                                row.mcSlider.hot=hot
                            end
                        end
                        if row.mcOnOff then
                            local hot=self.hovered==i or self.current==i
                            if row.mcOnOff.hot~=hot then row.mcOnOff.hot=hot;paintOnOff(row.mcOnOff) end
                        end
                        if row.mcArrowBoxes then
                            local hot=self.hovered==i or self.current==i
                            if row.mcArrowsHot~=hot then
                                for _,arrow in ipairs(row.mcArrowBoxes) do arrow.box:SetVisibility(hot and arrow.shown or 2) end
                                row.mcArrowsHot=hot
                            end
                        end
                        -- A click on a picker's value zone steps like its arrow, while that
                        -- arrow could be clicked, wrapping around at either end.
                        for _,zone in ipairs(row.mcZones or {}) do
                            local clicked
                            clicked,zone.pressed,zone.pointer=released(zone.widget,zone.pressed,zone.pointer,
                                not controller and zone.widget:IsHovered()==true)
                            if clicked and row.parts[zone.arrow].widget:GetIsEnabled() then
                                step(self,i,zone.direction)
                                return tick(self,queued,released,controller)
                            end
                        end
                        -- A click on the faint arrow at an end wraps around. It is taken here,
                        -- before DMM sees it, sharing DMM's press state for that arrow.
                        local edge=edgeArrow(row)
                        if edge then
                            local clicked
                            clicked,edge.pressed,edge.pointer=released(edge.widget,edge.pressed,edge.pointer,
                                not controller and edge.widget:IsHovered()==true)
                            if clicked then
                                step(self,i,edge==row.left and 1 or 2)
                                return tick(self,queued,released,controller)
                            end
                        end
                        -- A controller has no pointer to hover with; its presses come through focus.
                        for _,tab in ipairs(row.mcTabs or {}) do
                            tab.hovered=not controller and tab.widget:IsHovered()==true
                            if tab.header then paintHeaderTab(tab) end
                        end
                        for _,tab in ipairs(row.mcTabs or {}) do
                            local clicked
                            clicked,tab.pressed,tab.pointer=released(tab.widget,tab.pressed,tab.pointer,tab.hovered)
                            if clicked and tab.enabled then
                                self:select(i,false);self.model:set(i,tab.value);self:refresh()
                                if adapted.feedback then adapted.feedback('Change') end
                                return tick(self,queued,released,controller)
                            end
                        end
                    end
                end
            end
            return tick(self,queued,released,controller)
        end
        function ui:clearPresses()
            clearPresses(self)
            if self.active then
                for _,row in ipairs(self.panels[self.active].rows) do
                    for _,tab in ipairs(row.mcTabs or {}) do tab.pressed,tab.pointer=false,false end
                    for _,zone in ipairs(row.mcZones or {}) do zone.pressed,zone.pointer=false,false end
                end
            end
        end
        function ui:isPressed()
            if isPressed(self) then return true end
            if self.active then
                for _,row in ipairs(self.panels[self.active].rows) do
                    if row.visible then
                        for _,tab in ipairs(row.mcTabs or {}) do if tab.widget:IsPressed() then return true end end
                        for _,zone in ipairs(row.mcZones or {}) do if zone.widget:IsPressed() then return true end end
                    end
                end
            end
            return false
        end
        return ui
    end
    controls.mcPresentationVersion=M.version
    if pages then
        local buildPages=pages.build
        pages.build=function(tree,providers,status,api)
            -- Unapplied changes show as a * after the page title instead of DMM's status
            -- text. The status line keeps every other message: errors, failed Applies, hints.
            local page,titleText
            local adapted={}
            for key,value in pairs(api) do adapted[key]=value end
            local function unapplied()
                local model=page and page.controls and page.controls.model
                return model and not model.error and type(model.dirty)=='function' and model:dirty() or false
            end
            local function showTitle()
                if titleText then api.setText(page.modTitle,unapplied() and titleText..' *' or titleText) end
            end
            adapted.setText=function(widget,text)
                if page and widget==page.modTitle then titleText=text;return showTitle() end
                if page and widget==page.controlStatus then
                    local T=api.t or function(copy) return copy end
                    if text==T('Unapplied changes') then text='' end
                    local result=api.setText(widget,text)
                    showTitle()
                    return result
                end
                return api.setText(widget,text)
            end
            page=buildPages(tree,providers,status,adapted)
            local title=assert(page.modTitle,'MCS page title')
            local parent=assert(title:GetParent(),'MCS page header parent')
            local host=api.construct('/Script/UMG.Overlay',tree)
            local children={}
            for n=0,parent:GetChildrenCount()-1 do
                local child=parent:GetChildAt(n)
                local padding=child.Slot.Padding
                children[#children+1]={widget=child,padding={
                    Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom}}
            end
            assert(#children>=2 and children[1].widget:GetFullName()==title:GetFullName(),
                'MCS page header layout')
            local pageStatus=assert(page.controlStatus,'MCS page status')
            local statusName,statusPadding=pageStatus:GetFullName()
            parent:ClearChildren()
            -- A header picker's choices hang as tabs from the divider under the
            -- title. The page status shares that row, so it stays beneath the
            -- divider whether or not tabs are shown.
            local strip=api.construct('/Script/UMG.Overlay',tree)
            local stripBox=api.construct('/Script/UMG.SizeBox',tree)
            stripBox:SetWidthOverride(ROW_WIDTH)
            api.need(stripBox:SetContent(strip),'MCS header tabs strip')
            for index,child in ipairs(children) do
                if child.widget:GetFullName()==statusName then
                    statusPadding=child.padding
                else
                    api.need(parent:AddChild(index==1 and host or child.widget),'MCS page header child')
                        :SetPadding(child.padding)
                end
                -- The strip ends the header: the page's first entry sits headerGap below it.
                if index==2 then
                    api.need(parent:AddChild(stripBox),'MCS header tabs slot')
                        :SetPadding({Left=0,Top=0,Right=0,Bottom=headerGap})
                end
            end
            assert(statusPadding,'MCS page status placement')
            local statusBox=api.construct('/Script/UMG.SizeBox',tree)
            statusBox:SetWidthOverride(ROW_WIDTH)
            api.need(statusBox:SetContent(pageStatus),'MCS page status box')
            local statusSlot=api.need(strip:AddChild(statusBox),'MCS page status slot')
            statusSlot:SetHorizontalAlignment(1);statusSlot:SetVerticalAlignment(1)
            statusSlot:SetPadding(statusPadding)
            api.need(host:AddChild(title),'MCS page title')
            title:SetVisibility(4)
            M.style(title,1,api)
            M.style(page.filterLabel,1,api)
            page.filterLabel.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
            -- DMM's browser title is a filter button in a 590x40 box: the button's inset
            -- and the centred label offset it from a page title. Sit it the same way.
            local filterStyle=page.filterButton.WidgetStyle
            filterStyle.NormalPadding={Left=0,Top=0,Right=0,Bottom=0}
            filterStyle.PressedPadding={Left=0,Top=0,Right=0,Bottom=0}
            page.filterLabel.Slot:SetVerticalAlignment(1)
            -- The index has no filter: its button is a plain title that takes no input.
            page.filterButton:SetVisibility(4)
            local header=assert(page.filterButton:GetParent(),'MCS mod-browser header')
            header:SetWidthOverride(ROW_WIDTH);header:ClearHeightOverride()
            local list=assert(header:GetParent(),'MCS mod-browser page')
            local headerName=header:GetFullName()
            local children={}
            for n=0,list:GetChildrenCount()-1 do
                local child=list:GetChildAt(n)
                local padding=child.Slot.Padding
                children[#children+1]={widget=child,padding={
                    Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom}}
            end
            list:ClearChildren()
            local inserted=false
            for _,child in ipairs(children) do
                local slot=api.need(list:AddChild(child.widget),'MCS mod-browser child')
                slot:SetPadding(child.padding)
                if child.widget:GetFullName()==headerName then
                    local line=api.construct('/Script/UMG.SizeBox',tree)
                    line:SetWidthOverride(ROW_WIDTH);line:SetHeightOverride(2)
                    api.need(line:SetContent(api.Theme.image(tree,api.theme,'horizontal',api)),'MCS mod-browser divider')
                    api.need(list:AddChild(line),'MCS mod-browser divider slot')
                    inserted=true
                end
            end
            assert(inserted,'MCS mod-browser header placement')
            local function styleBrowserRows(rows)
                for _,row in ipairs(rows or {}) do
                    if row.widget then
                        local label=api.need(row.widget:GetContent(),'MC mod-list label')
                        local provider=providers[row.providerIndex]
                        local browserLevel=provider and provider.mcBrowserLevel or 2
                        if not styles[browserLevel] then browserLevel=2 end
                        local indent=provider and provider.mcBrowserIndent or 0
                        if type(indent)~='number' or indent< -80 or indent>80 then indent=0 end
                        M.style(label,browserLevel,api)
                        -- A group title is a size below its mods; its icon and rule mark it.
                        if provider and provider.mcBrowserKind then api.Theme.font(label,api.theme,13) end
                        -- The "and N more" entry is a size smaller than the mods it folds.
                        if provider and provider.mcBrowserMore then api.Theme.font(label,api.theme,12) end
                        if row.wrapper then
                            row.wrapper:SetWidthOverride(PAGE_WIDTH-2*indent)
                            local slot=row.wrapper.Slot
                            local padding=slot.Padding
                            slot:SetPadding({Left=indent,Top=padding.Top,
                                Right=padding.Right,Bottom=padding.Bottom})
                        end
                        if provider and provider.mcBrowserKind then label.Slot:SetPadding(HEADER_TITLE_PADDING)
                        else label.Slot:SetPadding({Left=row.wrapper and 0 or indent,Top=4,Right=12,Bottom=4}) end
                        if provider and provider.mcBrowserHeading then api.setText(label,provider.name) end
                        if provider and provider.mcBrowserLabel then api.setText(label,provider.mcBrowserLabel) end
                    end
                end
            end
            -- Each browser group (mcBrowserLine) is a header row, its heading followed by a
            -- horizontal line, then its pages: a 'cell' page in a grid (three columns, or its
            -- heading's mcBrowserColumns) on a faint background, its name left-aligned and
            -- wrapping to two lines before it is cut off; a 'row' page on a line of its own,
            -- also left-aligned. Each line keeps a blank margin on its left. Hidden
            -- pages keep their place in the list.
            local ICON,ICON_HEIGHT,BAR,GAP,CELLS,WIDTH=40,54,20,8,3,PAGE_WIDTH
            local KIND_INDENT,CELL_LINE_HEIGHT=10,0.8
            -- A grid cell's height and its name's padding above and below. The "and N
            -- more" cell takes a grid place like a mod; starting a row, its smaller text sits
            -- MORE_RAISE higher.
            local CELL_HEIGHT,CELL_TOP,CELL_BOTTOM,MORE_RAISE=34,2,4,2
            -- Inside a group, mod names are GROUPED_SIZE points (the "and N more" entry two
            -- sizes below), and a 'row' page is ROW_HEIGHT tall with ROW_PAD above and below
            -- its name.
            local GROUPED_SIZE,GROUPED_MORE_SIZE,ROW_HEIGHT,ROW_PAD=13,11,34,1
            -- Extra space above every group after the first.
            local SECTION_GAP=14
            -- Space between one row of grid cells and the next; GAP stays between columns.
            local CELL_ROW_GAP=4
            -- Space under each mod of an ungrouped list.
            local LOOSE_GAP=4
            -- Group header, tuned live: its highlight box (the title row) starts BOX_TOP
            -- down and is BOX_HEIGHT tall; the kind line sits KIND_TOP down, drawn after
            -- the box so its glow does not cover it. KIND_LINE is the kind text's height.
            local BOX_TOP,BOX_HEIGHT,KIND_TOP,KIND_LINE=20,34,19,19.4
            -- The header's rule is 2 pixels tall, RULE_TOP down, and starts RULE_GAP right
            -- of the wider of the title and the kind line, ending RULE_END short of the right.
            local RULE_TOP,RULE_GAP,RULE_END=35,8,6
            -- The header is drawn HEADER_RAISE up from its place in the group, with
            -- HEADER_GAP of bottom padding; a mod row's box sits ROW_SHIFT right of the left margin.
            -- HEADER_INDENT moves the header's icon and title right of the left margin's column.
            local HEADER_RAISE,HEADER_GAP,ROW_SHIFT,HEADER_INDENT=4,8,2,2
            -- Under a heading that is shown, how much further right than the icon column the
            -- mods start, and how much more space they keep between columns and between lines.
            local GROUP_INDENT,GROUP_COLUMN_GAP,GROUP_LINE_GAP=18,1,2
            local function frame(row,width,height)
                local box=api.construct('/Script/UMG.Border',tree)
                box:SetBrushColor(moduleBackground)
                box:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
                row.wrapper:SetWidthOverride(width);row.wrapper:SetHeightOverride(height)
                api.need(box:SetContent(row.wrapper),'MCS mod-list cell background')
                return box
            end
            local function rule(direction,height)
                local box=api.construct('/Script/UMG.SizeBox',tree)
                box:SetHeightOverride(height)
                api.need(box:SetContent(api.Theme.image(tree,api.theme,direction,api)),'MCS mod-list group line')
                return box
            end
            local function place(box,widget,padding)
                api.need(box:AddChild(widget),'MCS mod-list cell'):SetPadding(padding or {Left=0,Top=0,Right=0,Bottom=0})
            end
            -- A group's grid columns: its heading's mcBrowserColumns (1-4), else CELLS. Cells
            -- share the row's width left of the group's margin.
            local function columnsOf(head)
                local provider=head and providers[head.providerIndex]
                local columns=provider and tonumber(provider.mcBrowserColumns)
                return columns and columns>=1 and columns<=4 and math.floor(columns) or CELLS
            end
            -- A group's spacing: its left margin (the icon column), the gap after each column
            -- and the gap under each line, wider under a heading that is shown (a list
            -- without one keeps the plain spacing).
            local function spacingOf(head)
                local provider=head and providers[head.providerIndex]
                if provider and provider.mcBrowserBare then return BAR,GAP,0 end
                return BAR+GROUP_INDENT,GAP+GROUP_COLUMN_GAP,GROUP_LINE_GAP
            end
            local function cellWidth(columns,margin,gap)
                return math.floor((WIDTH-margin)/columns)-gap
            end
            local function groupLines(head,members)
                local lines,grid={},nil
                local columns=columnsOf(head)
                local margin,gap,extra=spacingOf(head)
                local function line(height)
                    local box=api.construct('/Script/UMG.HorizontalBox',tree)
                    -- The margin, with no line drawn in it.
                    local space=api.construct('/Script/UMG.SizeBox',tree)
                    space:SetWidthOverride(margin);space:SetHeightOverride(height);place(box,space)
                    lines[#lines+1]=box
                    return box
                end
                for _,row in ipairs(members) do
                    -- The name's text block, kept from the first layout: in load order the
                    -- button's content becomes a box holding the number and the name.
                    row.mcNameLabel=row.mcNameLabel or row.widget:GetContent()
                    local label=row.mcNameLabel
                    api.Theme.font(label,api.theme,providers[row.providerIndex].mcBrowserMore and GROUPED_MORE_SIZE or GROUPED_SIZE)
                    row.mcFrame:RemoveFromParent()
                    if providers[row.providerIndex].mcBrowserLine=='cell' then
                        if not grid or grid.count==columns then grid={box=line(CELL_HEIGHT),count=0} end
                        grid.count=grid.count+1
                        label:SetJustification(0);label:SetAutoWrapText(true)
                        -- A wrapped name sits tight, left-aligned and centred vertically. Line
                        -- height has no setter; the cell is re-placed below, which rebuilds
                        -- the text from it.
                        label.LineHeightPercentage=CELL_LINE_HEIGHT
                        -- Raised only when it starts a row; beside mods it lines up with them.
                        local raise=providers[row.providerIndex].mcBrowserMore and grid.count==1
                            and 2*MORE_RAISE or 0
                        -- A numbered name (load order) has its number's box before it instead.
                        label.Slot:SetPadding({Left=row.mcNumbered and 0 or 8,Top=CELL_TOP,Right=8,Bottom=CELL_BOTTOM+raise})
                        label.Slot:SetHorizontalAlignment(0);label.Slot:SetVerticalAlignment(2)
                        place(grid.box,row.mcFrame,{Left=0,Top=0,Right=gap,Bottom=CELL_ROW_GAP+extra})
                    else
                        grid=nil
                        label:SetJustification(0)
                        label.Slot:SetPadding({Left=6,Top=ROW_PAD,Right=12,Bottom=ROW_PAD})
                        label.Slot:SetHorizontalAlignment(0)
                        place(line(ROW_HEIGHT),row.mcFrame,{Left=ROW_SHIFT,Top=0,Right=gap-ROW_SHIFT,Bottom=GAP+extra})
                    end
                end
                return lines
            end
            -- Each group is one box in the list, rebuilt from its shown pages whenever the
            -- filter changes, so a hidden page leaves no gap and an empty group disappears.
            -- The header and every page first move to the group's collapsed park: a widget
            -- left without a parent is not rooted, and garbage collection would free it
            -- under the wrapper kept here, crashing the next filter change.
            local function layoutGroup(group,shown)
                group.header:RemoveFromParent();place(group.park,group.header)
                for _,row in ipairs(group.members) do
                    row.mcFrame:RemoveFromParent();place(group.park,row.mcFrame)
                end
                for _,line in ipairs(group.lines) do line:RemoveFromParent() end
                group.lines={}
                local visible=shown(group.head)
                -- A list without a heading shows while any of its pages does.
                if group.bare then
                    visible=false
                    for _,row in ipairs(group.members) do visible=visible or shown(row) end
                end
                group.box:SetVisibility(visible and 0 or 1)
                if not visible then return end
                if not group.bare then
                    group.header:RemoveFromParent()
                    place(group.box,group.header,{Left=0,Top=-HEADER_RAISE,Right=0,Bottom=HEADER_GAP})
                end
                local members={}
                for _,row in ipairs(group.members) do
                    if shown(row) then members[#members+1]=row end
                end
                -- A failed layout parks every page again before it is reported: a page left
                -- without a parent would be freed under its row and crash the next change.
                local ok,lines=pcall(groupLines,group.head,members)
                if not ok then
                    for _,row in ipairs(group.members) do
                        row.mcFrame:RemoveFromParent();place(group.park,row.mcFrame)
                    end
                    error(lines,0)
                end
                group.lines=lines
                for _,line in ipairs(group.lines) do place(group.box,line) end
            end
            local function lineBrowserRows(rows)
                local groups,current={},nil
                for _,row in ipairs(rows or {}) do
                    local provider=providers[row.providerIndex]
                    local line=row.wrapper and provider and provider.mcBrowserLine
                    if line=='head' and (not provider.mcBrowserHidden or provider.mcBrowserBare) then
                        current={head=row,members={}};groups[#groups+1]=current
                    elseif (line=='cell' or line=='row') and current then
                        if not provider.mcBrowserHidden then current.members[#current.members+1]=row end
                    elseif line~='cell' and line~='row' then current=nil end
                end
                -- A mod on a line of its own outside any group (an ungrouped list) gets the
                -- same backdrop, LOOSE_GAP above the next; an "and N more" entry gets none.
                local loose,looseRows={},{}
                for _,row in ipairs(rows or {}) do
                    local provider=providers[row.providerIndex]
                    if row.wrapper and provider and provider.mcBrowserLine=='row' and not provider.mcBrowserHidden
                        and not provider.mcBrowserMore then
                        loose[row.wrapper:GetFullName()]=row;looseRows[#looseRows+1]=row
                    end
                end
                for _,group in ipairs(groups) do
                    for _,row in ipairs(group.members) do loose[row.wrapper:GetFullName()]=nil end
                end
                if #groups==0 and not next(loose) then return end
                -- Read and clear the list before any row moves into a group.
                local first=groups[1] and groups[1].head or looseRows[1]
                local scroll=assert(first.wrapper:GetParent(),'MCS mod-list rows')
                local children={}
                for n=0,scroll:GetChildrenCount()-1 do
                    local child=scroll:GetChildAt(n)
                    local padding=child.Slot.Padding
                    children[#children+1]={widget=child,padding={
                        Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom}}
                end
                scroll:ClearChildren()
                local heads,moved={},{}
                for _,group in ipairs(groups) do
                    heads[group.head.wrapper:GetFullName()]=group
                    for _,row in ipairs(group.members) do
                        moved[row.wrapper:GetFullName()]=true
                        local cell=providers[row.providerIndex].mcBrowserLine=='cell'
                        local margin,gap=spacingOf(group.head)
                        row.mcFrame=frame(row,cell and cellWidth(columnsOf(group.head),margin,gap) or WIDTH-margin-gap,
                            cell and CELL_HEIGHT or ROW_HEIGHT)
                        -- The "and N more" entry has no background of its own.
                        if providers[row.providerIndex].mcBrowserMore then
                            row.mcFrame:SetBrushColor({R=0,G=0,B=0,A=0})
                        end
                    end
                    -- The header: the group's icon in a box of its own, then a small line
                    -- naming the kind of group above the title, then a rule filling the
                    -- rest of the width.
                    local provider=providers[group.head.providerIndex]
                    -- A heading that is never shown (mcBrowserBare) waits in the park.
                    group.bare=provider.mcBrowserBare==true
                    local header=api.construct('/Script/UMG.HorizontalBox',tree)
                    local iconBox=api.construct('/Script/UMG.SizeBox',tree)
                    -- As wide as the left margin below, so the icon centres over it; the
                    -- title's text then lines up with its mods' names.
                    iconBox:SetWidthOverride(BAR);iconBox:SetHeightOverride(ICON_HEIGHT)
                    local icon=api.caption(tree,provider.mcBrowserIcon or '')
                    api.Theme.font(icon,api.theme,20);icon:SetFont(icon.Font);icon:SetJustification(1)
                    local iconSlot=api.need(iconBox:SetContent(icon),'MCS mod-list group icon')
                    iconSlot:SetHorizontalAlignment(2);iconSlot:SetVerticalAlignment(2)
                    -- Centred 5px below the box's middle, level with the title.
                    iconSlot:SetPadding({Left=0,Top=10,Right=0,Bottom=0})
                    place(header,iconBox,{Left=HEADER_INDENT,Top=0,Right=8,Bottom=0})
                    local text=api.construct('/Script/UMG.VerticalBox',tree)
                    local kind=api.caption(tree,provider.mcBrowserKind or '')
                    api.Theme.font(kind,api.theme,10);kind:SetFont(kind.Font);api.Theme.textColor(kind,'muted')
                    kind:SetVisibility((provider.mcBrowserKind or '')~='' and 4 or 1)
                    kind:SetRenderOpacity(0.6)
                    -- Left-aligned with the title's text, which sits inside its row's padding.
                    kind:SetJustification(0)
                    -- The title keeps its own width; the column is as wide as the wider of
                    -- it and the kind line.
                    group.head.wrapper:ClearWidthOverride();group.head.wrapper:SetHeightOverride(BOX_HEIGHT)
                    place(text,group.head.wrapper,{Left=0,Top=BOX_TOP,Right=0,Bottom=0})
                    group.head.wrapper.Slot:SetHorizontalAlignment(1)
                    -- Added after the title row so it draws over the highlight box, then
                    -- pulled up to KIND_TOP; its bottom padding keeps the column as tall as
                    -- the box.
                    local kindSlot=api.need(text:AddChild(kind),'MCS mod-list group kind')
                    kindSlot:SetPadding({Left=KIND_INDENT,Top=KIND_TOP-BOX_TOP-BOX_HEIGHT,Right=0,
                        Bottom=BOX_TOP+BOX_HEIGHT-KIND_TOP-KIND_LINE})
                    kindSlot:SetHorizontalAlignment(0)
                    place(header,text)
                    local line=rule('horizontal',2)
                    local lineSlot=api.need(header:AddChild(line),'MCS mod-list group header line')
                    lineSlot:SetVerticalAlignment(1);lineSlot:SetSize({SizeRule=1,Value=1})
                    lineSlot:SetPadding({Left=RULE_GAP,Top=RULE_TOP,Right=RULE_END,Bottom=0})
                    local width=api.construct('/Script/UMG.SizeBox',tree)
                    width:SetWidthOverride(WIDTH)
                    api.need(width:SetContent(header),'MCS mod-list group header width')
                    group.header=width
                    group.box=api.construct('/Script/UMG.VerticalBox',tree)
                    group.park=api.construct('/Script/UMG.VerticalBox',tree)
                    group.park:SetVisibility(1);place(group.box,group.park)
                    group.lines={}
                end
                local placed=0
                for _,child in ipairs(children) do
                    local name=child.widget:GetFullName()
                    local group=heads[name]
                    if group then
                        local padding=child.padding
                        if placed>0 then
                            padding={Left=padding.Left,Top=padding.Top+SECTION_GAP,Right=padding.Right,Bottom=padding.Bottom}
                        end
                        placed=placed+1
                        api.need(scroll:AddChild(group.box),'MCS mod-list group'):SetPadding(padding)
                    elseif loose[name] then
                        local row,padding=loose[name],child.padding
                        row.mcFrame=frame(row,row.wrapper.WidthOverride,row.wrapper.HeightOverride)
                        row.mcLooseFrame=row.mcFrame
                        api.need(scroll:AddChild(row.mcFrame),'MCS mod-list row'):SetPadding({Left=padding.Left,
                            Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom+LOOSE_GAP})
                    elseif not moved[name] then
                        api.need(scroll:AddChild(child.widget),'MCS mod-list child'):SetPadding(child.padding)
                    end
                end
                -- shown(row) (optional) says which rows the filter shows; all, by default.
                function page:mcLayoutGroups(shown)
                    for _,group in ipairs(groups) do layoutGroup(group,shown or function() return true end) end
                end
                page:mcLayoutGroups()
            end
            styleBrowserRows(page.allRows)
            lineBrowserRows(page.allRows)
            page.controls.mcHeaderHost=host
            page.controls.mcHeaderTitle=title
            page.controls.mcHeaderTabs=strip
            page.controls.mcHeaderStatus={box=statusBox,slot=statusSlot,padding=statusPadding,width=ROW_WIDTH,top=0}
            return page
        end
    end
    return true
end
return M

-- A row whose identity cannot be trusted shows only its label and a short error.
-- Its value controls are hidden and disabled, so the row cannot be edited.
local Discovery=require('widget_discovery')
local M={}

local markerText=require('mcs_protocols').rowError
local function valid(o) return Discovery.valid(o) end
local function need(o,label) assert(valid(o),label..' unavailable'); return o end

local textLib
local function setText(widget,text)
    local ok,result=pcall(function()
        if not valid(textLib) then textLib=StaticFindObject('/Script/Engine.Default__KismetTextLibrary') end
        if not valid(textLib) or not valid(widget) then return false end
        widget:SetText(textLib:Conv_StringToText(text))
        return true
    end)
    return ok and result
end
local function textBlock(tree)
    return need(StaticConstructObject(need(StaticFindObject('/Script/UMG.TextBlock'),'TextBlock class'),tree),
        'row error text')
end
local function isText(widget) return Discovery.isTextBlock(widget) end
-- Hides every child of panel except keep and text captions (identities, markers).
local function hideExcept(panel,keep)
    for i=0,Discovery.childCount(panel)-1 do
        local child=Discovery.childAt(panel,i)
        if valid(child) and child~=keep and Discovery.address(child)~=Discovery.address(keep) and not isText(child) then
            pcall(function() child:SetVisibility(2) end)
        end
    end
end

-- Returns the row's existing error marker and message widgets, if it was marked before.
local function existing(shell)
    for i=0,Discovery.childCount(shell)-1 do
        local child=Discovery.childAt(shell,i)
        if isText(child) and Discovery.textOf(child)==markerText then
            return child,Discovery.childAt(shell,i+1)
        end
    end
end

function M.mark(row,message)
    local shell=need(Discovery.contentOf(row.wrapper),'row shell')
    pcall(function() row.nav:SetIsEnabled(false) end)
    pcall(function() row.slider:SetIsEnabled(false) end)
    if row.kind=='slider' then
        hideExcept(row.line,row.labelBox)
        hideExcept(row.overlay,row.line)
    elseif row.kind=='picker' then
        hideExcept(row.lane,row.labelBox)
        hideExcept(row.content,row.lane)
    elseif row.kind=='toggle' then
        pcall(function() row.valueWidget:SetVisibility(2) end)
        pcall(function() row.button:SetVisibility(4) end)
    end
    local marker,text=existing(shell)
    if not (marker and isText(text)) then
        local tree=row.tree or need(row.wrapper:GetOuter(),'row widget tree')
        marker=textBlock(tree)
        assert(setText(marker,markerText),'row error marker write failed')
        marker:SetVisibility(1)
        need(shell:AddChildToOverlay(marker),'row error marker slot')
        text=textBlock(tree)
        pcall(function() text:SetFont(row.labelWidget.Font) end)
        pcall(function() text:SetRenderTransformPivot({X=1,Y=0.5});text:SetRenderScale({X=0.84,Y=0.84}) end)
        pcall(function() text:SetColorAndOpacity({SpecifiedColor={R=0.9,G=0.35,B=0.3,A=1},ColorUseRule=0}) end)
        text:SetVisibility(3)
        local slot=need(shell:AddChildToOverlay(text),'row error slot')
        slot:SetHorizontalAlignment(3);slot:SetVerticalAlignment(2)
        slot:SetPadding({Left=0,Top=0,Right=24,Bottom=0})
    end
    if Discovery.textOf(text)~=message then assert(setText(text,message),'row error text write failed') end
    return true
end

return M

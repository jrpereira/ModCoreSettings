-- Runs in DMM's Lua state: the footer hint for the selected row's field-type editor
-- (see field_types), e.g. "ENTER  ADJUST" on a range row. It sits at the end of DMM's
-- footer actions and looks like them: a glyph and a label. The glyph is the key that
-- confirms the row: Enter on a keyboard, A on a controller. No game action has both (its
-- Confirm is Space and A, ConfirmReturn Enter and B), so the glyph shows ConfirmReturn's
-- key on a keyboard and Confirm's on a controller, following DMM's input mode. It is
-- display only: nothing binds either action to it.
local M={version=1}
local base='/Game/_Dawnwalker/UI/_Unified/'

-- native: DMM's nativeactions module; its new() is wrapped to find each menu's footer.
-- pages (optional): DMM's pages module; its pages' setInputMode tells the input mode.
-- name(text) (optional) makes an FName.
-- Returns the hint: hint.show(text or nil,api) (api: DMM's page api).
function M.install(native,pages,name)
    assert(type(native)=='table' and type(native.new)=='function','DMM native actions unavailable')
    local hint={}
    local menu,built,label,icon,row,failed
    local mode='keyboard'
    local function valid(widget) return widget and widget:IsValid() and widget or nil end
    -- The action whose glyph is the confirming key in the current input mode.
    local function glyph()
        if mode~='keyboard' or not (row and name) then return row end
        return {DataTable=row.DataTable,RowName=name('ConfirmReturn')}
    end
    local function refresh()
        if valid(icon) and row then pcall(function() icon:SetInputAction(glyph()) end) end
    end
    if type(pages)=='table' and type(pages.build)=='function' then
        local build=pages.build
        pages.build=function(...)
            local ui=build(...)
            local set=type(ui)=='table' and ui.setInputMode
            if set then
                function ui:setInputMode(value,...)
                    local results=table.pack(set(self,value,...))
                    if value~=mode then mode=value;refresh() end
                    return table.unpack(results,1,results.n)
                end
            end
            return ui
        end
    end
    local new=native.new
    native.new=function(pc,tree,...)
        local actions=new(pc,tree,...)
        menu={actions=actions,tree=tree}
        built,label,icon,row,failed=nil,nil,nil,nil,nil
        -- DMM refreshes its glyphs when the input mode changes; the hint's follows.
        local glyphs=actions.glyphs
        function actions:glyphs(...)
            local results=table.pack(glyphs(self,...))
            refresh()
            return table.unpack(results,1,results.n)
        end
        return actions
    end
    -- DMM's footer row: the Apply glyph -> its box -> its item -> its button -> the row.
    local function footer()
        local records=menu and menu.actions and menu.actions.records
        local apply=records and records.apply
        local widget=apply and valid(apply.icon)
        for _=1,3 do widget=widget and valid(widget:GetParent()) end
        return widget and valid(widget:GetParent())
    end
    local function build(api)
        local line=assert(footer(),'DMM footer unavailable')
        local tree=menu.tree
        local confirm=assert(menu.actions.records.popupApply,'DMM Confirm action unavailable')
        row=confirm.row
        local item=api.construct('/Script/UMG.HorizontalBox',tree)
        local box=api.construct('/Script/UMG.SizeBox',tree)
        box:SetWidthOverride(40);box:SetHeightOverride(40)
        icon=api.construct('/Script/RebelInputDisplay.RebelInputWidget',tree)
        icon:SetVisibility(4);icon:SetInputAction(glyph())
        assert(box:SetContent(icon),'hint glyph')
        assert(item:AddChild(box),'hint glyph slot')
        label=api.caption(tree,'')
        api.Theme.font(label,api.theme,14)
        api.Theme.textColor(label,'muted')
        local slot=assert(item:AddChild(label),'hint label slot')
        slot:SetPadding({Left=12,Top=0,Right=28,Bottom=0});slot:SetVerticalAlignment(2)
        assert(line:AddChild(item),'hint footer slot'):SetVerticalAlignment(2)
        built=item
    end
    function hint.show(text,api)
        if failed then return end
        if not valid(built) then
            if not text then return end
            local ok,err=pcall(build,api)
            -- A failed build is not retried in this menu: one report.
            if not ok then failed=true;error(err,0) end
        end
        if text then api.setText(label,text) end
        built:SetVisibility(text and 4 or 1)
    end
    return hint
end

return M

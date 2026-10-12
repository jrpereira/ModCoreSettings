-- The mod list's footer button (DMM's Filter Mods, Backspace) sorts the list instead: each
-- press moves to the next way of listing mods and saves it as the Settings page's Sort by
-- ([Modules] SortBy in config.ini). The button is found by its glyph: DMM asks its
-- native actions for the filter icon, which sits beside the button's label. It shows a
-- small, faded "sort by" over the current way, and moves from DMM's footer to under the
-- mod list, a quarter of the way across the screen.
local M={version=1}
-- "sort by": text size and opacity; the current way's text size (DMM's footer uses 14). The button's left edge in DMM's 1920-wide design (a
-- quarter of the screen, clear of Back), and its distance from the bottom, as DMM's footer.
-- TEXT_RAISE lifts both lines without moving the glyph.
local CAPTION_SIZE,CAPTION_OPACITY,LABEL_SIZE,TEXT_RAISE=11,0.75,12,2
local LEFT,BOTTOM=480,84

-- In the order a press cycles through: SortBy value and label.
M.MODES={{value=2,label='Recently Added'},{value=1,label='Categories'},{value=0,label='Alphabetical'},
    {value=3,label='Load Order'}}

local function index(value)
    for n,mode in ipairs(M.MODES) do if mode.value==value then return n end end
end

-- The value after value, in press order; an unknown value starts at the first.
function M.next(value)
    local n=index(value)
    return M.MODES[n and n%#M.MODES+1 or 1].value
end

-- The button's label: the current way, in capitals like DMM's other footer labels.
function M.text(value)
    local n=index(value)
    return (n and M.MODES[n].label or M.MODES[1].label):upper()
end

-- config.ini text with [Modules] SortBy set to value; other lines are kept as they are.
function M.config(text,value)
    return require('mc_ini').set(text or '','Modules','SortBy',value)
end

-- native: DMM's nativeactions module. read(path)/write(path,text) reach config.ini. Returns
-- the button: button:press(value) saves the next way; button:show(value,api,tree) labels and
-- places it (api: DMM's page api, with setText, construct, caption, Theme and theme).
function M.install(native,configPath,read,write,report)
    assert(type(native)=='table' and type(native.new)=='function','DMM native actions unavailable')
    local button={}
    local actions,label,shown,placed
    local new=native.new
    native.new=function(...)
        actions,label,shown,placed=nil,nil,nil,nil
        actions=new(...)
        return actions
    end
    local function valid(widget) return widget and widget:IsValid() and widget or nil end
    -- The button's row beside the filter glyph: icon -> its box -> the row, which holds the
    -- glyph's box and the label.
    local function row()
        local icon=actions and actions.records and actions.records.filter and valid(actions.records.filter.icon)
        local box=icon and valid(icon:GetParent())
        local found=box and valid(box:GetParent())
        return found and found:GetChildrenCount()>=2 and found or nil
    end
    -- Once per menu: "sort by" goes over the label, and the button moves from the footer
    -- (button -> footer row -> its scale box -> its bounds -> DMM's design overlay) to under
    -- the mod list. The footer keeps DMM's other actions.
    local function place(line,api,tree)
        label=assert(valid(line:GetChildAt(1)),'sort button label')
        local padding=label.Slot.Padding
        padding={Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom}
        local stack=api.construct('/Script/UMG.VerticalBox',tree)
        local caption=api.caption(tree,'sort by')
        api.Theme.font(caption,api.theme,CAPTION_SIZE)
        api.Theme.textColor(caption,'muted')
        caption:SetRenderOpacity(CAPTION_OPACITY)
        api.Theme.font(label,api.theme,LABEL_SIZE)
        label:RemoveFromParent()
        -- Both lines start at the left; DMM's captions are centred.
        for _,text in ipairs({caption,label}) do
            text:SetJustification(0)
            assert(stack:AddChild(text),'sort button text line'):SetHorizontalAlignment(1)
        end
        local slot=assert(line:AddChild(stack),'sort button text')
        slot:SetPadding(padding);slot:SetVerticalAlignment(2)
        stack:SetRenderTranslation({X=0,Y=-TEXT_RAISE})
        local widget=assert(valid(line:GetParent()),'sort button')
        local footer=valid(widget:GetParent())
        local scale=footer and valid(footer:GetParent())
        local bounds=scale and valid(scale:GetParent())
        local overlay=assert(bounds and valid(bounds:GetParent()),'menu overlay')
        widget:RemoveFromParent()
        local moved=assert(overlay:AddChildToOverlay(widget),'sort button slot')
        moved:SetHorizontalAlignment(1);moved:SetVerticalAlignment(3)
        moved:SetPadding({Left=LEFT,Top=0,Right=0,Bottom=BOTTOM})
    end
    function button:show(value,api,tree)
        if shown==value and valid(label) then return end
        local ok,err=pcall(function()
            if not placed then
                local line=row()
                if not line then return end
                -- A failed move puts the label back and is not retried: one report per menu.
                local moved,why=pcall(place,line,api,tree)
                if not moved then
                    placed='failed'
                    if valid(label) and not valid(label:GetParent()) then pcall(line.AddChild,line,label) end
                    error(why,0)
                end
                placed=true
            end
            if placed~=true then return end
            if not valid(label) then return end
            api.setText(label,M.text(value))
            shown=value
        end)
        if not ok then report('SORT_BUTTON_FAILED',tostring(err)) end
    end
    function button:press(value)
        local nextValue=M.next(value)
        local ok,err=pcall(function() write(configPath,M.config(read(configPath),nextValue)) end)
        if not ok then report('SORT_BUTTON_FAILED',tostring(err)) end
        return ok and nextValue or nil
    end
    return button
end

return M

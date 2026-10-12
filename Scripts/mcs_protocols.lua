-- The versioned strings hidden TextBlocks carry between MCS's two Lua states. DMM's state
-- (presentation.lua) writes them into a page's widget tree; MCS's own state
-- (widget_discovery, dirty_labels, row_error) reads them back. A change to a format bumps
-- its number here, once, so both sides move together. Each prefix ends where the first
-- field begins.
return {
    -- One per setting row: its index, provider, id, kind and choices, percent-escaped.
    setting='MC_SETTING_6\n',
    -- A row's dirty state, as the label's text.
    dirty='MC_DIRTY_3\n',
    -- A value row's dirty signal for the label next to it.
    valueDirty='MC_VALUE_DIRTY_1\n',
    -- A heading row moved out of the list; the path of the widget that stands in for it follows.
    headerRow='MC_HEADER_ROW\n',
    -- A row whose identity cannot be trusted.
    rowError='MC_ROW_ERROR_1\n',
}

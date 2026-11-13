-- Whether a module's mod.json dependencies are met by the loaded modules. A requirement
-- names a module id and, optionally, a version: "1.6.0+" (that version or later; a '?'
-- part counts as 0, so "1.6.?+" is 1.6.0 or later) or "1.6.0" (that version exactly).
-- Versions compare part by part as numbers; missing parts are 0.
local M = {}

-- UE4SS runs every module, so it is always loaded; its version is not known.
M.HOST = 'UE4SS'
M.MET, M.UNMET = '√', '⚠'

-- A version's numeric parts, or nil. wildcard lets '?' stand for 0 (requirements only);
-- an installed version may carry a v prefix and a suffix after its numbers (1.2.0-dev).
function M.parts(text, wildcard)
    if type(text) ~= 'string' then return nil end
    local core = wildcard and text:match('^%s*[vV]?([%d%?][%d%?%.]*)') or text:match('^%s*[vV]?(%d[%d%.]*)')
    if not core or core:find('%.%.') or core:sub(-1) == '.' then return nil end
    local parts = {}
    for part in core:gmatch('[^%.]+') do
        if part == '?' then parts[#parts + 1] = 0
        elseif part:match('^%d+$') then parts[#parts + 1] = tonumber(part)
        else return nil end
    end
    return #parts > 0 and #parts <= 8 and parts or nil
end

-- -1, 0 or 1 as a is older than, equal to or newer than b.
function M.compare(a, b)
    for index = 1, math.max(#a, #b) do
        local x, y = a[index] or 0, b[index] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

-- A requirement's version as published: each '?' becomes 0.
function M.published(version)
    return (version:gsub('%?', '0'))
end

-- One dependency checked against installed(id) -> {name=, version=} or nil.
-- Returns {id, name, required, installed, met, problem}.
function M.check(dependency, installed)
    local found = installed(dependency.id)
    local result = {id=dependency.id, name=found and found.name or dependency.id,
        required=type(dependency.version) == 'string' and dependency.version ~= '' and dependency.version or nil,
        installed=found and found.version or nil}
    if not found then result.problem = 'not loaded'; return result end
    if not result.required then result.met = true; return result end
    local spec = result.required:match('^%s*(.-)%s*$')
    local minimum = spec:sub(-1) == '+'
    local wanted = M.parts(minimum and spec:sub(1, -2) or spec, true)
    if not wanted then result.problem = 'unreadable requirement'; return result end
    local have = M.parts(found.version)
    if not have then result.problem = 'version unknown'; return result end
    local order = M.compare(have, wanted)
    if minimum and order >= 0 or not minimum and order == 0 then result.met = true
    else result.problem = order < 0 and 'too old' or 'too new' end
    return result
end

-- Every dependency of one module: {met=all met, items={...}} in declared order, or nil
-- without dependencies. installed(id) as in check; UE4SS is always loaded.
function M.evaluate(dependencies, installed)
    if type(dependencies) ~= 'table' or #dependencies == 0 then return nil end
    local function lookup(id)
        local found = installed(id)
        if not found and id == M.HOST then return {name=M.HOST} end
        return found
    end
    local report = {met=true, items={}}
    for _, dependency in ipairs(dependencies) do
        local item = M.check(dependency, lookup)
        report.items[#report.items + 1] = item
        report.met = report.met and item.met == true
    end
    return report
end

-- The requirements as lines under a Requirements heading: a mark, the module and the
-- version it needs, then what is loaded; an unmet one says why. Unmet ones come first, each
-- group alphabetical. The
-- marks are followed by spaces, and the check, narrower than the warning, has one before
-- it and more after, so the names line up.
function M.describe(report)
    local lines = {}
    -- Unmet first, then met, each by name (ignoring case), ties in declared order.
    local ordered, position = {}, {}
    for index, item in ipairs(report.items) do ordered[index], position[item] = item, index end
    table.sort(ordered, function(a, b)
        if (a.met == true) ~= (b.met == true) then return not a.met end
        local x, y = a.name:lower(), b.name:lower()
        if x ~= y then return x < y end
        return position[a] < position[b]
    end)
    for _, item in ipairs(ordered) do
        local state
        if item.problem == 'not loaded' then state = item.problem
        else
            state = item.installed or 'loaded'
            if item.problem then state = state .. ' (' .. item.problem .. ')' end
        end
        lines[#lines + 1] = (item.met and ' ' .. M.MET .. '    ' or M.UNMET .. '  ') .. item.name
            .. (item.required and ' ' .. M.published(item.required) or '') .. ': ' .. state
    end
    return table.concat(lines, '\n')
end

return M

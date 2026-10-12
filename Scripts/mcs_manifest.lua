-- Reads a settings manifest the way DMM's choices.parse does, so every module that
-- reads its own keys finds the same sections and setting ids. Runs in DMM's Lua state;
-- dmm_extension preloads it as package.loaded.mcs_manifest.
local M={version=1}
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end
M.trim=trim

-- Returns every [section] in order, and the manifest's lines (a final empty line
-- dropped). Each section has:
--   name        the text between the brackets
--   first,last  its header line and its last line
--   fields      key -> value, both trimmed; a repeated key keeps its last value
--   duplicates  key -> true for each key given more than once
--   malformed   lines that are neither blank, a comment, nor key=value
-- [Setting] and [Setting.*] sections also have setting (their position among
-- setting sections) and id (Id, or DMM's fallback 'setting_<setting>').
-- Lines before the first section, and comment lines (';' or '#'), are skipped.
function M.sections(content)
    local doc=require('mc_ini').parse(content)
    local lines={}
    for n,line in ipairs(doc.lines) do lines[n]=line.text end
    local malformed={}
    for _,n in ipairs(doc.malformed) do malformed[n]=true end
    local list,settings={},0
    for _,parsed in ipairs(doc.sections) do
        if parsed.header then
            local section={name=parsed.name,first=parsed.header,last=parsed.last,fields={},duplicates={},malformed={}}
            if section.name=='Setting' or section.name:match('^Setting%.') then
                settings=settings+1
                section.setting=settings
            end
            for _,entry in ipairs(parsed.entries) do
                if section.fields[entry.key]~=nil then section.duplicates[entry.key]=true end
                section.fields[entry.key]=trim(entry.raw)
            end
            for n=parsed.header+1,parsed.last do
                if malformed[n] then section.malformed[#section.malformed+1]=n end
            end
            if section.setting then section.id=section.fields.Id or ('setting_'..section.setting) end
            list[#list+1]=section
        end
    end
    return list,lines
end

-- Only the [Setting] and [Setting.*] sections, in order.
function M.settings(content)
    local out={}
    for _,section in ipairs((M.sections(content))) do
        if section.setting then out[#out+1]=section end
    end
    return out
end

return M

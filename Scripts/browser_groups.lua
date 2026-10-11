-- Arrange the mod browser into groups before DMM builds its rows. Every mod follows the
-- same rules: a valid collection (mod.json preferred shared by enough mods) lists it
-- there only; otherwise it is listed under each top category its categories belong to.
local M = {}

local GROUP_PREFIX = 'ModCore.browser.group.'
local VARIOUS = 'Various Authors'
local TITLE = 'Modules'
-- Opacity of quiet rows (mods without settings, "and N more" entries): at rest,
-- hovered, and, for a mod, selected (keyboard selection or the mod described).
local QUIET_OPACITY, QUIET_HOVER_OPACITY, QUIET_SELECTED_OPACITY = 0.5, 0.75, 0.7
-- The page that carries the index tabs (Errors, Developer Tools): MCS's own.
local HOST = 'ModCoreSettings'
-- The MCS_Page values of those tabs, after the page's own three.
local TABS = {errors=4, tools=5}
local COLLECTION_ICON = '⁂'
-- Every group is a grid of this many columns unless options.columns (1-3, [Modules]
-- ModulesPerRow) says otherwise; an ungrouped list is one mod per line.
local GROUP_COLUMNS = 2
-- The Recently added list's sections, newest first: key, title, and the age in seconds a
-- mod's added time must be under (the last section takes the rest).
local RECENT = {{'recent:day', 'Last 24 hours', 86400}, {'recent:week', 'Last 7 days', 7 * 86400},
    {'recent:month', 'Last 30 days', 30 * 86400}, {'recent:earlier', 'Earlier'}}
local RECENT_ICON = '○'
-- Links to ModCore's own pages, top right on the title's line: text and page id. Their
-- text size, the gap between them, and the space after the last.
local LINKS = {{'settings', 'ModCoreSettings'}, {'controls', 'ModCoreControls'}}
local LINK_SIZE, LINK_GAP, LINK_END = 12, 7, 5
-- Load order numbers: their box width, text size, opacity and the gap before the name.
-- Box and gap fill the row's left margin (20 in a plain list), so names start where they
-- do in Alphabetical. Numbers are right-aligned in their box.
local LOAD_NUMBER_WIDTH, LOAD_NUMBER_SIZE, LOAD_NUMBER_OPACITY, LOAD_NUMBER_GAP = 16, 12, 0.7, 4
-- A group heading: its icon, a small line naming the kind of group, and its title.
local function heading(key, title, kind, icon, columns)
    return {id=GROUP_PREFIX .. key, name=title, author='', version='',
        description=kind and kind ~= '' and kind .. ': ' .. title or title,
        choices={}, settingsCount=0, testOnly=false, noSettings=true, mcBrowserHeading=true,
        mcBrowserKind=kind, mcBrowserIcon=icon, mcBrowserLevel=3, mcBrowserIndent=0,
        mcBrowserColumns=columns or GROUP_COLUMNS}
end

-- The entry that folds a group's mods without settings; selecting it lists them.
local function more(key, count)
    return {id=GROUP_PREFIX .. key .. '.more', name='and ' .. count .. ' more with no settings',
        author='', version='', description='Show the ' .. count .. ' mods in this group that have no settings.',
        choices={}, settingsCount=0, choicesLoaded=true, deferred=false, testOnly=false,
        mcBrowserMore=key}
end

-- The index tabs' sections, appended to the host page's manifest. Every row is navigation
-- or read-only, so the tabs own no config. openable[id] marks the pages a link can open,
-- or names the slot a link page opens; versions[id] (optional) follows a page's name.
-- tools lists the developer tool pages (group='tool'), which open only from here.
function M.manifest(openable, versions, tools)
    versions = versions or {}
    local lines = {}
    local function block(section, fields)
        lines[#lines + 1] = '[' .. section .. ']'
        for _, field in ipairs(fields) do lines[#lines + 1] = field[1] .. '=' .. tostring(field[2]) end
        lines[#lines + 1] = ''
    end
    local function label(text) return (tostring(text):gsub('[|;%c%[%]]', ' ')) end
    local count = 0
    local function section(group, list, tab, empty)
        block('Category.' .. group, {{'VisibleWhen', 'MCS_Page'}, {'VisibleValues', tab}, {'mcHeading', 0}})
        if #list == 0 then
            block('Setting.MCS_Index_Empty_' .. tab, {{'Id', 'MCS_Index_Empty_' .. tab}, {'Label', group},
                {'Group', group}, {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'},
                {'PresetLabels', empty .. '|' .. empty}, {'mcReadOnly', 1}, {'mcType', 'tab'}})
            return
        end
        for _, entry in ipairs(list) do
            count = count + 1
            local id = 'MCS_Index_' .. count
            local version = versions[entry.id]
            local name = version and entry.name .. ' v' .. version or entry.name
            local fields = {{'Id', id}, {'Label', label(name)}, {'Group', group},
                {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'}}
            if openable[entry.id] then
                for _, field in ipairs({{'PresetLabels', 'Open|Open'}, {'mcNavigation', 1}, {'mcType', 'tab'},
                    {'mcLinkPage', type(openable[entry.id]) == 'string' and openable[entry.id] or entry.id}}) do
                    fields[#fields + 1] = field
                end
            else
                for _, field in ipairs({{'PresetLabels', 'No settings|No settings'}, {'mcReadOnly', 1}, {'mcType', 'tab'}}) do
                    fields[#fields + 1] = field
                end
            end
            block('Setting.' .. id, fields)
        end
    end
    -- The latest error lines of UE4SS.log, newest at the bottom (the host's 'errors' source).
    block('Category.Errors', {{'VisibleWhen', 'MCS_Page'}, {'VisibleValues', TABS.errors}, {'mcHeading', 0}})
    block('Setting.MCS_Index_Errors', {{'Id', 'MCS_Index_Errors'}, {'Label', 'Errors'}, {'Group', 'Errors'},
        {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'}, {'PresetLabels', 'Errors|Errors'},
        {'mcReadOnly', 1}, {'mcText', 'errors'}})
    section('Developer Tools', tools or {}, TABS.tools, 'None installed')
    return table.concat(lines, '\n')
end

local function clean(value)
    if type(value) ~= 'string' then return nil end
    value = value:match('^%s*[vV]?(%d[%w%.%-%+]*)%s*$')
    return value and #value <= 32 and value or nil
end

-- A reader for a mod folder's version under mods (the Mods folder, ending in a separator):
-- its VERSION file, else the version in a native mod's dlls/main.json. open defaults to io.open.
function M.folderVersion(mods, open)
    if type(mods) ~= 'string' then return nil end
    open = open or io.open
    local function read(path)
        local file = open(path, 'rb')
        if not file then return nil end
        local content = file:read(4096)
        file:close()
        return content
    end
    return function(folder)
        assert(not folder:find('[/\\]') and folder ~= '..' and folder ~= '.', 'invalid mod folder')
        local version = read(mods .. folder .. '/VERSION')
        if version then return version:match('^%s*(.-)%s*$') end
        local json = read(mods .. folder .. '/dlls/main.json')
        return json and json:match('"version"%s*:%s*"([^"]+)"')
    end
end

-- A reader for a mod folder's mod.json fields under mods (the Mods folder, ending in a
-- separator): preferred, its collection; settings, false when the mod has none to show;
-- name, author, version, icon and description; and requires, the set of dependency ids.
-- mod.json is decoded as JSON, as the boot index decodes it; an unreadable one gives no
-- fields. Each folder is read once: mod.json changes need a restart, like the index.
-- open defaults to io.open.
function M.folderManifest(mods, open)
    if type(mods) ~= 'string' then return nil end
    open = open or io.open
    local Json = require('mcs_module_json')
    local cache = {}
    local function read(folder)
        local file = open(mods .. folder .. '/mod.json', 'rb')
        if not file then return {} end
        local json = file:read(65536) or ''
        file:close()
        local ok, manifest = pcall(Json.decode, (json:gsub('^\239\187\191', '')))
        if not ok or type(manifest) ~= 'table' then return {} end
        local function text(key, limit)
            local value = manifest[key]
            return type(value) == 'string' and value ~= '' and #value <= limit
                and not value:find('%c') and value or nil
        end
        local fields = {preferred=text('preferred', 120), name=text('name', 200), author=text('author', 120),
            version=text('version', 64), icon=text('icon', 16), description=text('description', 4096),
            requires={}}
        if manifest.settings == false then fields.settings = false end
        for _, dependency in ipairs(type(manifest.dependencies) == 'table' and manifest.dependencies or {}) do
            if type(dependency) == 'table' and type(dependency.id) == 'string' then fields.requires[dependency.id] = true end
        end
        return fields
    end
    return function(folder)
        assert(type(folder) == 'string' and not folder:find('[/\\]') and folder ~= '..' and folder ~= '.',
            'invalid mod folder')
        if not cache[folder] then cache[folder] = read(folder) end
        return cache[folder]
    end
end

local function trimmed(value)
    value = type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
    return value ~= '' and value or nil
end

-- The folder a provider's mod lives in: a contributed page's attach folder, a detected
-- UE4SS folder's name, or the folder holding its settings manifest.
local function folderOf(provider)
    if provider.mcFolder then return provider.mcFolder end
    if provider.detectedKind == 'ue4ss' then return provider.name end
    local path = type(provider.path) == 'string' and provider.path:gsub('\\', '/') or nil
    return path and path:match('([^/]+)/[^/]+$')
end

-- "A", "A and B", "A, B and C"; join is the last separator's word.
local function joined(list, join)
    if #list <= 1 then return list[1] end
    return table.concat(list, ', ', 1, #list - 1) .. ' ' .. (join or 'and') .. ' ' .. list[#list]
end

-- Appends the index tabs to the host page's manifest on each build. Returns whether the
-- host now carries them.
local function extend(host, openable, versions, tools, parse, read, report)
    if not host or not parse or not read then return false end
    local ok, err = pcall(function()
        if host.mcBaseManifest == nil then
            host.mcBaseManifest = assert(host.mcManifest or read(host.path), 'host page manifest unreadable')
                :gsub('^\239\187\191', '')
        end
        local manifest = host.mcBaseManifest:gsub('%s*$', '') .. '\n\n' .. M.manifest(openable, versions, tools)
        local choices = parse(manifest)
        host.choices, host.settingsCount, host.mcManifest = choices, #choices, manifest
        host.choicesLoaded, host.deferred = true, false
    end)
    if not ok and report then report('BROWSER_INDEX_FAILED', tostring(err)) end
    return ok
end

-- Every listed mod lands in groups: valid collections, then top categories in taxonomy
-- order (or, without a taxonomy, each mod.json group or author shared by several mods),
-- then Various Authors. Within a group, mods with settings come first, walked by
-- category in taxonomy order and then load order; mods without settings fold into a
-- final entry that lists them when selected.
-- options: folderManifest(folder), folderVersion(folder), pageVersions, categoryRegister,
-- taxonomy, preferredMinimum, groupModules, read(path) (to extend the host page),
-- recent (folder -> {added=,updated=,baseline=}: list ungrouped mods by their latest install
-- or update, newest first, in sections by age; a mod with neither known is Earlier), now (the
-- time to measure age from), loadOrder (list ungrouped mods in load order), singleCategory
-- (list each mod only under the top category holding most of its categories, ties to the
-- first declared), columns (each group's grid columns, 1-3; default 2).
function M.arrange(providers, parse, report, options)
    options = options or {}
    local listed, tools, seen = {}, {}, {}
    local host
    local parentOf = {}
    local lastParent
    for _, provider in ipairs(providers) do
        local id = provider.id
        if tostring(id):sub(1, #GROUP_PREFIX) ~= GROUP_PREFIX and seen[id] ~= provider then
            assert(not seen[id], 'duplicate browser provider: ' .. tostring(id))
            seen[id] = provider
            -- A page listed under another (indented by its contributor) stays with it.
            if provider.mcBrowserChild == nil then
                provider.mcBrowserChild = provider.mcBrowserLine == nil and provider.mcBrowserLevel == 4
            end
            if provider.mcListGroup == nil then
                local folder = folderOf(provider)
                local fields = {}
                if folder and options.folderManifest then
                    local ok, read = pcall(options.folderManifest, folder)
                    fields = ok and type(read) == 'table' and read or {}
                end
                -- A preferred group names a collection; "author" is the default author grouping.
                local preferred = trimmed(fields.preferred)
                provider.mcListGroup = preferred ~= 'author' and preferred or false
                provider.mcFolderAuthor = trimmed(fields.author)
                -- A mod that declares it has no settings is not listed as incompatible.
                provider.mcNoSettingsDeclared = fields.settings == false and provider.noSettings or nil
                -- A mod found on disk, or a contributed page standing in for one, takes its
                -- details from its folder: its mod.json, else the folder's version.
                if (provider.detectedKind or provider.mcModuleEntry) and folder then
                    provider.mcFolder = provider.mcFolder or folder
                    local version
                    if options.folderVersion then
                        local ok, value = pcall(options.folderVersion, folder)
                        version = ok and trimmed(value) or nil
                    end
                    provider.name = fields.name or provider.name
                    provider.author = fields.author or provider.author
                    provider.version = fields.version or version or provider.version
                    provider.mcBrowserIcon = fields.icon or provider.mcBrowserIcon
                    if provider.mcNoSettingsDeclared then
                        provider.description = (fields.description and fields.description .. '\n\n' or '')
                            .. provider.name .. ' has no settings to change.'
                    elseif fields.description then provider.description = fields.description end
                end
            end
            if id == HOST then host = provider end
            if provider.mcBrowserGroup == 'tool' then tools[#tools + 1] = provider
            elseif provider.mcBrowserChild and lastParent then
                parentOf[provider] = lastParent
                lastParent.mcChildren = lastParent.mcChildren or {}
                lastParent.mcChildren[#lastParent.mcChildren + 1] = provider
            else
                provider.mcChildren = nil
                listed[#listed + 1] = provider
                lastParent = provider
            end
        end
    end
    -- Children are re-collected each build.
    for _, provider in ipairs(listed) do
        if provider.mcChildren then
            local kept = {}
            for _, child in ipairs(provider.mcChildren) do if parentOf[child] == provider then kept[#kept + 1] = child end end
            provider.mcChildren = kept
        end
    end
    local order = {}
    for index, provider in ipairs(listed) do order[provider] = index end
    -- Within a group mods follow load order: UE4SS starts mod folders by name, so
    -- numbered folders (0_, 1_ ... 9_) keep their sequence. Pages without a folder keep
    -- their place ahead of them.
    local loaded = {}
    do
        local byFolder = {}
        for index, provider in ipairs(listed) do
            byFolder[index] = {provider=provider, index=index,
                folder=tostring(folderOf(provider) or ''):lower()}
        end
        table.sort(byFolder, function(a, b)
            if a.folder ~= b.folder then return a.folder < b.folder end
            return a.index < b.index
        end)
        for n, item in ipairs(byFolder) do loaded[item.provider] = n end
    end
    local register, taxonomy = options.categoryRegister, options.taxonomy
    local default = {categories={'other'}, parents={'other'}, tags={}}
    local function entryOf(provider)
        local folder = folderOf(provider)
        return register and folder and register[folder] or default
    end
    -- A collection forms when enough distinct folders prefer it. A preferred main
    -- category or category is not a collection: it counts as declared first.
    local preferredCounts, folderSeen = {}, {}
    if register then
        for _, provider in ipairs(listed) do
            local folder = folderOf(provider)
            local entry = folder and register[folder]
            if entry and entry.preferred and not folderSeen[folder]
                and not (taxonomy and taxonomy.definitions[entry.preferred]) then
                folderSeen[folder] = true
                preferredCounts[entry.preferred] = (preferredCounts[entry.preferred] or 0) + 1
            end
        end
    end
    local minimum = options.preferredMinimum or 2
    local columns = tonumber(options.columns)
    if not (columns == 1 or columns == 2 or columns == 3) then columns = GROUP_COLUMNS end
    local groups, byKey = {}, {}
    local function group(key, title, kind, icon)
        local found = byKey[key]
        if not found then
            found = {key=key, title=title, kind=kind, icon=icon, members={}, has={}}
            byKey[key] = found
            groups[#groups + 1] = found
        end
        return found
    end
    local function join(found, provider)
        if not found.has[provider] then found.has[provider] = true;found.members[#found.members + 1] = provider end
    end
    local collections, sections, plain = {}, {}, {}
    local moduleCount, counted = 0, {}
    for _, provider in ipairs(listed) do
        local folder = folderOf(provider) or provider.id
        if not counted[folder] then counted[folder] = true;moduleCount = moduleCount + 1 end
        provider.mcTaxonomyEntry, provider.mcLoadIndex = nil, nil
        if taxonomy then
            local entry = entryOf(provider)
            provider.mcTaxonomyEntry = entry
            local preferred = entry.preferred
            if options.groupModules == false then
                plain[#plain + 1] = provider
            elseif preferred and not taxonomy.definitions[preferred] and minimum > 0
                and (preferredCounts[preferred] or 0) >= minimum then
                local kind = preferred == provider.mcFolderAuthor and 'Author' or 'Collection'
                local found = group('preferred:' .. preferred, preferred, kind, COLLECTION_ICON)
                collections[found] = true
                join(found, provider)
            else
                -- A preferred main category or category counts as declared first.
                local declared = {}
                if preferred and taxonomy.definitions[preferred] then declared[1] = preferred end
                for _, id in ipairs(entry.categories or {}) do declared[#declared + 1] = id end
                provider.mcCategories = declared
                local ok, parents = pcall(taxonomy.parents, taxonomy, declared)
                if not ok then parents = entry.parents or {'other'} end
                for _, section in ipairs(parents) do
                    sections[section] = true
                    local definition = {}
                    for _, candidate in ipairs(taxonomy.data.sections) do
                        if candidate.id == section then definition = candidate; break end
                    end
                    group('section:' .. section, nil, definition.description or section,
                        definition.icon or '…')
                end
            end
        else
            local own = trimmed(provider.mcListGroup)
            local key = own or not provider.detectedKind and trimmed(provider.author) or nil
            if options.groupModules == false or not key then plain[#plain + 1] = provider
            else
                local found = group('list:' .. key, key, own and 'Collection' or 'Author', COLLECTION_ICON)
                join(found, provider)
            end
        end
    end
    -- Top category members, in load order.
    if taxonomy then
        local function sectionOf(id)
            local definition = taxonomy.definitions[id]
            local parent = definition and definition.parent
            while parent and not taxonomy.sections[parent] do
                local ancestor = taxonomy.definitions[parent]
                parent = ancestor and ancestor.parent
            end
            return parent
        end
        local function topCategoryOf(id)
            local current=id
            while taxonomy.definitions[current] and taxonomy.definitions[current].parent
                and not taxonomy.sections[taxonomy.definitions[current].parent] do
                current=taxonomy.definitions[current].parent
            end
            return current
        end
        -- In a single category, a mod is listed only under the top category holding most of
        -- its categories; a tie goes to the one declared first (a preferred category counts
        -- as declared first).
        local only = {}
        if options.singleCategory then
            for _, provider in ipairs(listed) do
                local counts, best = {}, nil
                for _, id in ipairs(provider.mcCategories or {}) do
                    local section = taxonomy.definitions[id] and sectionOf(id)
                    if section then
                        counts[section] = (counts[section] or 0) + 1
                        if not best or counts[section] > counts[best] then best = section end
                    end
                end
                only[provider] = best
            end
        end
        for _, found in ipairs(groups) do
            local section = found.key:match('^section:(.+)$')
            if section then
                local ranked = {}
                for _, provider in ipairs(listed) do
                    for _, id in ipairs(provider.mcCategories or {}) do
                        if taxonomy.definitions[id] and sectionOf(id) == section
                            and (not options.singleCategory or only[provider] == section) then
                            ranked[#ranked + 1] = {provider=provider};break
                        end
                    end
                end
                table.sort(ranked, function(a, b) return loaded[a.provider] < loaded[b.provider] end)
                local present, titles = {}, {}
                for _, item in ipairs(ranked) do
                    join(found, item.provider)
                    for _, id in ipairs(item.provider.mcCategories or {}) do
                        local definition = taxonomy.definitions[id]
                        if definition and sectionOf(id) == section then present[topCategoryOf(id)] = true end
                    end
                end
                for _, definition in ipairs(taxonomy.data.categories) do
                    if present[definition.id] then titles[#titles + 1] = definition.description or definition.id end
                end
                found.title = joined(titles, section == 'other' and 'or' or 'and') or found.kind
            end
        end
    end
    for _, found in ipairs(groups) do
        table.sort(found.members, function(a, b) return loaded[a] < loaded[b] end)
    end
    -- A list group of one mod joins the plain list.
    local kept = {}
    for _, found in ipairs(groups) do
        if not taxonomy and #found.members < 2 then
            for _, provider in ipairs(found.members) do plain[#plain + 1] = provider end
        elseif #found.members > 0 then kept[#kept + 1] = found end
    end
    -- Top categories in taxonomy order, then collections in the load order of their
    -- first mod.
    local rank = {}
    if taxonomy then
        for n, section in ipairs(taxonomy.data.sections) do rank['section:' .. section.id] = n end
    end
    table.sort(kept, function(a, b)
        local ra, rb = rank[a.key], rank[b.key]
        if (ra ~= nil) ~= (rb ~= nil) then return ra ~= nil end
        if ra and rb then return ra < rb end
        return loaded[a.members[1]] < loaded[b.members[1]]
    end)
    -- The index tabs on MCS's own page: the developer tools.
    local openable = {}
    for _, provider in ipairs(providers) do
        local link = provider.mcLinkSlot
        if link then openable[provider.id] = link.address
        elseif not provider.noSettings then openable[provider.id] = true end
    end
    local versions = {}
    for _, provider in ipairs(providers) do
        versions[provider.id] = clean(provider.version) or clean((options.pageVersions or {})[provider.id])
    end
    local indexed = extend(host, openable, versions, tools, parse, options.read, report)
    local result = {}
    -- A mod listed in several groups is the same provider at several positions, so the
    -- group entry that unfolds it is kept per position, not on the provider.
    local foldedAt = {}
    local function add(provider, line, label, fold)
        if line ~= 'head' then provider.mcBrowserLevel, provider.mcBrowserIndent = 4, 20 end
        -- A mod without settings shows its name alone, without DMM's notice.
        if provider.noSettings and not provider.mcBrowserHeading and not label then label = provider.name end
        provider.mcBrowserLine, provider.mcBrowserLabel = line, label
        result[#result + 1] = provider
        foldedAt[#result] = fold
    end
    local folded = {}
    local function members(found, list, line)
        local without = {}
        local function one(provider)
            if provider.noSettings then without[#without + 1] = provider
            else
                add(provider, line)
                for _, child in ipairs(provider.mcChildren or {}) do add(child, line) end
            end
        end
        for _, provider in ipairs(list) do one(provider) end
        local fold = found and found.key or 'plain'
        for _, provider in ipairs(without) do
            add(provider, line, nil, fold)
            for _, child in ipairs(provider.mcChildren or {}) do add(child, line, nil, fold) end
        end
        if #without > 0 then
            local entry = more(found and found.key or 'plain', #without)
            folded[#folded + 1] = entry
            -- In a grid it fills a place like any mod; in a plain list it is a line.
            add(entry, line)
        end
    end
    for _, found in ipairs(kept) do
        add(heading(found.key, found.title, found.kind, found.icon, columns), 'head')
        members(found, found.members, 'cell')
    end
    local function byName(a, b)
        local an, bn = tostring(a.name or ''):lower(), tostring(b.name or ''):lower()
        if an ~= bn then return an < bn end
        if a.id ~= b.id then return tostring(a.id) < tostring(b.id) end
        return order[a] < order[b]
    end
    if #plain > 0 and options.recent then
        local now = options.now or os.time()
        local function added(provider)
            local record = options.recent[folderOf(provider) or '']
            if type(record) ~= 'table' then return nil end
            local installed = record.baseline ~= true and tonumber(record.added) or nil
            local updated = tonumber(record.updated)
            if installed and updated then return math.max(installed, updated) end
            return updated or installed
        end
        table.sort(plain, function(a, b)
            local ta, tb = added(a) or -math.huge, added(b) or -math.huge
            if ta ~= tb then return ta > tb end
            return byName(a, b)
        end)
        -- Newest first, so each section is the next run of the list.
        local at = 1
        for _, section in ipairs(RECENT) do
            local list = {}
            while plain[at] do
                local time = added(plain[at])
                if section[3] and not (time and now - time < section[3]) then break end
                list[#list + 1] = plain[at];at = at + 1
            end
            if #list > 0 then
                -- Unlike other groups, a section keeps its mods newest first.
                add(heading(section[1], section[2], 'Added', RECENT_ICON, columns), 'head')
                members({key=section[1]}, list, 'cell')
            end
        end
    elseif #plain > 0 then
        local headed = options.groupModules ~= false
        -- Ungrouped, every mod is in this one list, sorted by name or in load order;
        -- grouped, the leftovers are a group like any other, in load order.
        table.sort(plain, function(a, b)
            if not headed and not options.loadOrder then return byName(a, b) end
            return loaded[a] < loaded[b]
        end)
        local found = headed and {key='various'} or nil
        if headed then add(heading('various', register and 'Other' or VARIOUS, '', '…', columns), 'head') end
        -- In load order every mod with a folder keeps its number, so the numbers shown skip
        -- the mods folded away; unfolding them shows theirs.
        local number = 0
        for _, provider in ipairs(plain) do
            if options.loadOrder and folderOf(provider) then number = number + 1;provider.mcLoadIndex = number end
        end
        members(found, plain, headed and 'cell' or 'row')
    end
    -- Tool pages stay among the providers so their links open them; while the index tabs
    -- reach them they are never listed, otherwise they are listed like any mod.
    for _, tool in ipairs(tools) do
        tool.mcBrowserHidden = indexed or nil
        add(tool, 'row')
    end
    for index, provider in ipairs(result) do providers[index] = provider end
    for index = #result + 1, #providers do providers[index] = nil end
    providers.mcModuleCount = moduleCount
    providers.mcFolded = #folded > 0
    providers.mcFoldedAt = foldedAt
    return providers
end

-- The Modules page lists MCS's modules: pages and detected mods whose folder is an
-- active module in register, MCS's own page and the developer tools. Disabled folders
-- (their settings pages too) and packages outside Mods/ are dropped, in place, since DMM
-- indexes this same list. An empty or missing register leaves the list as DMM built it.
function M.modules(providers, register)
    if type(register) ~= 'table' or next(register) == nil then return providers end
    local kept = {}
    for _, provider in ipairs(providers) do
        local folder = folderOf(provider)
        if provider.id == HOST or provider.mcBrowserGroup == 'tool'
            or tostring(provider.id):sub(1, #GROUP_PREFIX) == GROUP_PREFIX
            or folder and register[folder] then
            kept[#kept + 1] = provider
        end
    end
    for index = #providers, 1, -1 do providers[index] = nil end
    for index, provider in ipairs(kept) do providers[index] = provider end
    return providers
end

-- report(event,detail) (optional) receives failures. parse(manifest) (optional) builds the
-- host page's index tabs. folderVersion(folder) (optional) reads a mod folder's version,
-- folderManifest(folder) (optional) its mod.json fields; read(path) (optional) the host
-- page's manifest. sort (optional, sort_button's button) turns DMM's filter button into
-- Sort by.
function M.install(pages, report, parse, folderVersion, folderManifest, groupingOptions, read, sort)
    if pages.mcBrowserGroupsVersion then return false end
    report = report or function() end
    assert(type(pages)=='table' and type(pages.build)=='function', 'DMM pages API unavailable')
    local build = pages.build
    pages.build = function(tree, providers, status, api)
        local options={pageVersions=type(api)=='table' and api.mcPageVersions or nil, folderVersion=folderVersion,
            folderManifest=folderManifest, read=read}
        if groupingOptions then
            local ok,value=pcall(groupingOptions)
            if ok then for key,setting in pairs(value) do options[key]=setting end
            else report('BROWSER_GROUPS_FAILED',value) end
        end
        local listed,why=pcall(M.modules,providers,options.categoryRegister)
        if not listed then report('BROWSER_GROUPS_FAILED',why) end
        M.arrange(providers, parse, report,options)
        local page = build(tree, providers, status, api)
        if type(page)=='table' and type(page.setFilter)=='function' then
            local setFilter = page.setFilter
            -- Compatible-only filtering keeps the group headings, which have no settings of
            -- their own, and mods that declare they have none; pages opened only through
            -- links (mcBrowserHidden) are never listed. Mods without settings stay folded
            -- until their group's last entry is selected. A failure leaves DMM's own filtering.
            page.mcModuleCount=providers.mcModuleCount
            page.mcExpanded={}
            local categoryFilter,tagFilter=options.categoryFilter,options.tagFilter
            local hidden = options.taxonomy~=nil or providers.mcFolded
            for _, provider in ipairs(providers) do
                hidden = hidden or provider.mcBrowserHidden == true or provider.mcNoSettingsDeclared == true
                    or provider.mcBrowserHeading == true
            end
            -- No filter: every module is listed, and the filter button is the page title.
            -- DMM's footer filter button (Backspace) asks for the other filter, true: with
            -- sort it moves to the next way of listing instead, rebuilt on the next tick.
            function page:setFilter(compatibleOnly)
                if compatibleOnly == true and sort then
                    if sort:press(options.arrangement) and type(self.mcRefreshIndex) == 'function' then
                        self:mcRefreshIndex()
                    end
                    return
                end
                setFilter(self, false)
                if type(api)=='table' and api.setText and self.filterLabel then
                    local titled,why=pcall(api.setText,self.filterLabel,TITLE)
                    if not titled then report('BROWSER_GROUPS_FAILED',why) end
                end
                if not self.compatibleOnly and not hidden then return end
                local ok, err = pcall(function()
                    local rows, visible = {}, {}
                    for index, row in ipairs(self.allRows) do
                        local provider = providers[row.providerIndex]
                        local entry=provider.mcTaxonomyEntry
                        local allowed=not options.taxonomy or not entry or (options.taxonomy:matches(entry,categoryFilter,false)
                            and options.taxonomy:matches(entry,tagFilter,true))
                        local folded=providers.mcFoldedAt and providers.mcFoldedAt[row.providerIndex]
                        if provider.mcBrowserMore then
                            allowed=not self.compatibleOnly and not self.mcExpanded[provider.mcBrowserMore]
                        elseif folded then
                            allowed=allowed and self.mcExpanded[folded]==true
                        end
                        visible[index] = allowed and not provider.mcBrowserHidden and (not self.compatibleOnly
                            or provider.mcBrowserHeading or provider.mcNoSettingsDeclared or not provider.noSettings)
                    end
                    -- A group heading shows only while one of its pages does.
                    for index, row in ipairs(self.allRows) do
                        local provider = providers[row.providerIndex]
                        if provider.mcBrowserHeading and provider.mcBrowserLine == 'head' then
                            local any, next = false, index + 1
                            while self.allRows[next] do
                                local member = providers[self.allRows[next].providerIndex]
                                if member.mcBrowserLine == 'head' or member.mcBrowserLine == nil then break end
                                any = any or visible[next] and not member.mcBrowserMore
                                    or member.mcBrowserMore and visible[next]
                                next = next + 1
                            end
                            visible[index] = any
                        end
                    end
                    for index, row in ipairs(self.allRows) do
                        local shown = visible[index]
                        if shown then
                            rows[#rows + 1] = row
                            row.index = #rows
                        end
                        row.wrapper:SetVisibility(shown and 0 or 1)
                    end
                    self.rows = rows
                    if type(self.mcLayoutGroups) == 'function' then
                        local shown = {}
                        for index, row in ipairs(self.allRows) do shown[row] = visible[index] end
                        self:mcLayoutGroups(function(row) return shown[row] == true end)
                    end
                    self:refreshHint()
                    self.scroll:ScrollToStart()
                    self.empty:SetVisibility(#rows == 0 and 0 or 1)
                    for i, row in ipairs(rows) do
                        if i > 1 then row.widget:SetNavigationRuleExplicit(2, rows[i - 1].widget)
                        else row.widget:SetNavigationRuleBase(2, 3) end
                        if i < #rows then row.widget:SetNavigationRuleExplicit(3, rows[i + 1].widget)
                        else row.widget:SetNavigationRuleBase(3, 3) end
                    end
                end)
                if not ok then report('BROWSER_GROUPS_FAILED', err) end
            end
            -- Selecting a group's "and X more" entry lists its mods without settings.
            if type(page.showDetail)=='function' then
                local showDetail=page.showDetail
                function page:showDetail(rowIndex)
                    local row=self.rows and self.rows[rowIndex]
                    local provider=row and providers[row.providerIndex]
                    if provider and provider.mcBrowserMore then
                        self.mcExpanded[provider.mcBrowserMore]=true
                        self:setFilter(self.compatibleOnly)
                        return
                    end
                    return showDetail(self,rowIndex)
                end
            end
            function page:setCategoryFilter(values,mode)
                if options.taxonomy then options.taxonomy:matches({categories={},parents={},tags={}}, {values=values,mode=mode},false) end
                categoryFilter={values=values,mode=mode};self:setFilter(self.compatibleOnly)
            end
            function page:setTagFilter(values,mode)
                if options.taxonomy then options.taxonomy:matches({categories={},parents={},tags={}}, {values=values,mode=mode},true) end
                tagFilter={values=values,mode=mode};self:setFilter(self.compatibleOnly)
            end
            -- The hint counts module folders, not menu entries (headings, a mod listed under
            -- several categories, folded entries). With DMM's page api it is only the count of
            -- every listed mod, folded ones included, and of those without settings, without
            -- DMM's input help.
            if type(page.refreshHint)=='function' then
                local refreshHint=page.refreshHint
                if type(api)=='table' and api.setText and page.hint then
                    local T=api.t or function(copy,values) return (copy:gsub('{([%w_]+)}',values)) end
                    refreshHint=function(self)
                        local seen,total,quiet={},0,0
                        for _,row in ipairs(self.allRows or {}) do
                            local provider=providers[row.providerIndex]
                            if provider and not provider.mcBrowserHeading and not provider.mcBrowserMore
                                and not provider.mcBrowserHidden then
                                local folder=folderOf(provider) or provider.id
                                if not seen[folder] then
                                    seen[folder]=true;total=total+1
                                    if provider.noSettings then quiet=quiet+1 end
                                end
                            end
                        end
                        local text=T('{count} mods',{count=total})
                        if quiet>0 then text=text..' '..T('({count} with no settings)',{count=quiet}) end
                        api.setText(self.hint,text)
                    end
                end
                function page:refreshHint()
                    local rows,seen,count=self.rows,{},{}
                    for _,row in ipairs(rows or {}) do
                        local provider=providers[row.providerIndex]
                        if provider and not provider.mcBrowserHeading and not provider.mcBrowserMore then
                            local folder=folderOf(provider) or provider.id
                            if not seen[folder] then seen[folder]=true;count[#count+1]=row end
                        end
                    end
                    self.rows=count
                    local ok,err=pcall(refreshHint,self)
                    self.rows=rows
                    if not ok then report('BROWSER_GROUPS_FAILED',err) end
                end
            end
            -- Quiet rows (mods without settings, "and N more" entries) are dimmed and
            -- never get the highlight pattern a page that opens gets: hovering or
            -- selecting one only brightens it.
            local function quiet(provider)
                return provider and not provider.mcBrowserHeading
                    and (provider.mcBrowserMore ~= nil or provider.noSettings == true)
            end
            local function dim(row,opacity)
                local ok,err=pcall(function()
                    if type(api)=='table' and api.highlight then api.highlight(row.widget,0,true)
                    else row.widget:SetBackgroundColor({R=1,G=1,B=1,A=0}) end
                    row.widget:SetRenderOpacity(opacity)
                end)
                if not ok then report('BROWSER_GROUPS_FAILED',err) end
            end
            local function quieten(self)
                local rows=self.rows or {}
                local current=self.highlighted and rows[self.highlighted]
                local described=self.described and rows[self.described]
                for _,row in ipairs(self.allRows or {}) do
                    local provider=providers[row.providerIndex]
                    if quiet(provider) then
                        local opacity=QUIET_OPACITY
                        local mod=provider.mcBrowserMore==nil
                        if row==current then
                            opacity=mod and self.selected==self.highlighted and QUIET_SELECTED_OPACITY
                                or QUIET_HOVER_OPACITY
                        elseif mod and row==described then opacity=QUIET_SELECTED_OPACITY end
                        dim(row,opacity)
                    end
                end
            end
            quieten(page)
            if type(page.highlight)=='function' then
                local highlight=page.highlight
                function page:highlight(index)
                    highlight(self,index)
                    self.highlighted=index
                    quieten(self)
                end
            end
            if type(page.describe)=='function' then
                local describe=page.describe
                function page:describe(index)
                    describe(self,index)
                    self.described=index
                    quieten(self)
                end
            end
            -- The title's line carries links to ModCore's own pages, right-aligned. DMM asks
            -- the page each tick whether its filter title was clicked (tickFilter); with
            -- the title inert, that is where the links are checked. A link opens its page
            -- as page links do, through the listed row.
            local links = {}
            if type(api) == 'table' and api.button and api.construct and page.filterButton then
                local ok, err = pcall(function()
                    local available = {}
                    for _, provider in ipairs(providers) do
                        if not provider.noSettings then available[provider.id] = true end
                    end
                    local line = api.construct('/Script/UMG.HorizontalBox', tree)
                    for _, link in ipairs(LINKS) do
                        if available[link[2]] then
                            local widget, label = api.button(tree, link[1])
                            widget.IsFocusable = false
                            if api.Theme and api.theme then
                                api.Theme.font(label, api.theme, LINK_SIZE)
                                api.Theme.textColor(label, 'muted')
                            end
                            label.Slot:SetPadding({Left=6, Top=2, Right=6, Bottom=2})
                            local slot = assert(line:AddChild(widget), 'browser link')
                            slot:SetPadding({Left=#links > 0 and LINK_GAP or 0, Top=0, Right=0, Bottom=0})
                            slot:SetVerticalAlignment(2)
                            links[#links + 1] = {widget=widget, id=link[2], pressed=false, pointer=false}
                        end
                    end
                    if #links == 0 then return end
                    local header = assert(page.filterButton:GetParent(), 'browser title box')
                    local stack = api.construct('/Script/UMG.Overlay', tree)
                    assert(header:SetContent(stack), 'browser title line')
                    local titleSlot = assert(stack:AddChild(page.filterButton), 'browser title')
                    titleSlot:SetHorizontalAlignment(0);titleSlot:SetVerticalAlignment(0)
                    local linkSlot = assert(stack:AddChild(line), 'browser links')
                    linkSlot:SetHorizontalAlignment(3);linkSlot:SetVerticalAlignment(2)
                    linkSlot:SetPadding({Left=0, Top=0, Right=LINK_END, Bottom=0})
                end)
                if not ok then links = {};report('BROWSER_GROUPS_FAILED', err) end
            end
            local function open(self, id)
                for rowIndex, row in ipairs(self.rows or {}) do
                    local provider = providers[row.providerIndex]
                    if provider and provider.id == id then return self:showDetail(rowIndex) end
                end
                -- Not listed (a filter hides it): offered to showDetail as the only row.
                for _, row in ipairs(self.allRows or {}) do
                    local provider = providers[row.providerIndex]
                    if provider and provider.id == id then
                        local listed = self.rows
                        self.rows = {row}
                        local ok, err = pcall(self.showDetail, self, 1)
                        self.rows = listed
                        assert(ok, err)
                        return
                    end
                end
            end
            function page:tickFilter(released)
                for _, link in ipairs(links) do
                    local hovered = link.widget:IsHovered() == true
                    if hovered ~= link.hovered and api.highlight then
                        link.hovered = hovered
                        api.highlight(link.widget, hovered and 0.22 or 0, true)
                    end
                    local activate
                    activate, link.pressed, link.pointer = released(link.widget, link.pressed, link.pointer, hovered)
                    if activate then
                        local ok, err = pcall(open, self, link.id)
                        if not ok then report('BROWSER_GROUPS_FAILED', err) end
                        return true
                    end
                end
                return false
            end
            -- In load order each mod's name follows its number, small and faint, in a box
            -- of its own so the names line up. The row starts that much further left, into
            -- its margin, and is that much wider: names start where they do in Alphabetical,
            -- and the numbers sit in the margin (a button clips what is drawn outside it).
            if options.loadOrder and type(api) == 'table' and api.construct and api.caption then
                for _, row in ipairs(page.allRows or {}) do
                    local index = providers[row.providerIndex] and providers[row.providerIndex].mcLoadIndex
                    if index then
                        local ok, err = pcall(function()
                            local label = assert(row.widget:GetContent(), 'mod-list label')
                            local padding = label.Slot.Padding
                            padding = {Left=padding.Left, Top=padding.Top, Right=padding.Right, Bottom=padding.Bottom}
                            local line = api.construct('/Script/UMG.HorizontalBox', tree)
                            local box = api.construct('/Script/UMG.SizeBox', tree)
                            box:SetWidthOverride(LOAD_NUMBER_WIDTH)
                            local number = api.caption(tree, tostring(index))
                            if api.Theme and api.theme then
                                api.Theme.font(number, api.theme, LOAD_NUMBER_SIZE)
                                api.Theme.textColor(number, 'muted')
                            end
                            number:SetJustification(2)
                            number:SetRenderOpacity(LOAD_NUMBER_OPACITY)
                            local numberSlot = assert(box:SetContent(number), 'load number')
                            numberSlot:SetVerticalAlignment(2)
                            -- Fill the button as DMM's label did; a button centres new content.
                            local lineSlot = assert(row.widget:SetContent(line), 'load number row')
                            lineSlot:SetHorizontalAlignment(0);lineSlot:SetVerticalAlignment(0)
                            lineSlot:SetPadding({Left=0, Top=0, Right=0, Bottom=0})
                            local boxSlot = assert(line:AddChild(box), 'load number slot')
                            boxSlot:SetVerticalAlignment(2)
                            boxSlot:SetPadding({Left=padding.Left, Top=0, Right=LOAD_NUMBER_GAP, Bottom=0})
                            local wrapperSlot = row.wrapper and row.wrapper.Slot
                            if wrapperSlot then
                                local margin = wrapperSlot.Padding
                                local shift = math.min(margin.Left, LOAD_NUMBER_WIDTH + LOAD_NUMBER_GAP)
                                wrapperSlot:SetPadding({Left=margin.Left - shift, Top=margin.Top,
                                    Right=margin.Right, Bottom=margin.Bottom})
                                local width = tonumber(row.wrapper.WidthOverride)
                                if width and width > 0 then row.wrapper:SetWidthOverride(width + shift) end
                            end
                            local labelSlot = assert(line:AddChild(label), 'load order label')
                            labelSlot:SetVerticalAlignment(2);labelSlot:SetSize({SizeRule=1, Value=1})
                            labelSlot:SetPadding({Left=0, Top=padding.Top, Right=padding.Right, Bottom=padding.Bottom})
                        end)
                        if not ok then report('BROWSER_GROUPS_FAILED', err) end
                    end
                end
            end
            -- DMM sets the input mode on every tick of an open menu: the footer exists by then.
            if sort and type(api) == 'table' and api.setText and type(page.setInputMode) == 'function' then
                local setInputMode = page.setInputMode
                function page:setInputMode(...)
                    sort:show(options.arrangement, api, tree)
                    return setInputMode(self, ...)
                end
            end
            page:setFilter()
        end
        return page
    end
    pages.mcBrowserGroupsVersion = 1
    return true
end

return M

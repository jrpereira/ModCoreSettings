# Integration reference

Start with the [developer guide](DEVELOPERS.md) for a complete first setting.
Examples below are fragments unless they include a full file. `settingsManifest`
means an INI string; replace example paths with absolute paths on the game host.

- [Generated pages](#menu-pages), [menu data](#menu-data) and [slot rows](#slot-rows)
- [Page hooks](#page-hooks) and [page links](#page-links)
- [Apply notifications](#apply-notifications)
- [Presentation metadata](#presentation-metadata)
- [Missing defaults](#missing-defaults)
- [Mapped presets](#mapped-presets)

## Menu pages

ModCoreSettings is the only DMM integration. Other mods never install a DMM
extension or call DMM directly; to add generated menu pages they publish data
through `Scripts/vendor/menu_contributions.lua`. A provider is the mod/page that owns
a settings model. Copy that file unchanged into your mod's `Scripts/vendor` folder,
add the folder to `package.path`, and publish from the ordinary mod state:

```lua
local Menu=require('menu_contributions')
local pages=Menu.publisher(ModRef,{id='ExampleMod',directory='<absolute writable folder>'})
pages:publish({pages={
    {id='ExampleMod',name='Example',attach='ExampleMod'},
    {id='ExampleMod.speed',name='Speed',under='ExampleMod',
        manifest=settingsManifest,configDirectory='<absolute folder for ConfigFile>'},
}})
-- pages:withdraw() removes them; Menu.validate(id,{pages=...}) checks offline.
```

Page fields: `id` (the contributor id or `<id>.*`; it is the `providerId` in Apply
notifications), `name`, optional `author`, `version`, `description`, `visible`,
settings as [`menu` data](#menu-data) (preferred) or a `manifest`, either with
`configDirectory`, and at most one of `under` (an earlier page of the same
contributor) or `attach` (a mod folder name). `link` makes a
[slot link](#slot-rows) entry. `group='tool'` lists the page only on the ModCore
Settings page's Developer Tools tab, which opens it; the mod list does not show it.
A tool page needs settings, as any page DMM opens does. `group='module'` is accepted
and has no effect.

Placement on every menu build:

- `under`: after the parent and its earlier children, indented.
- `attach`: matched case-insensitively against a mod's name, id or detected
  folder. A detected placeholder without settings is hidden while the page is
  shown, and the page becomes that mod's entry: its name, author, version, icon
  and description come from the folder's `mod.json`, as the placeholder's would,
  and the page's own are only fallbacks. So a page that holds another mod's
  settings shows as that mod. Otherwise the page follows that mod, indented,
  unless it is a module group page. A name matching several mods rejects the
  contributor. A page with `visible=false` still hides the mod it attaches to, whether a
  detected placeholder or a mod with settings of its own; the mod returns when the page is
  withdrawn.
- Otherwise: sorted by name with other mods, so a page that returns does not move.

Contributed pages need no `mod_settings.ini` on disk; ModCoreSettings keeps
their manifest in memory and only uses `configDirectory` to resolve `ConfigFile`.

Publishing writes a new generation of files and then switches the contributor's
shared variable; the menu keeps showing the previous generation until then.
`publish` rejects structurally invalid pages. Menu data and manifests are checked
when the menu builds; any failure (menu data, manifest, id collision, ambiguous
`attach`) skips that contributor's pages and is logged once. The rest of the menu
is unaffected.

### Menu data

A page's `menu` describes its settings without DMM's manifest format;
ModCoreSettings builds the page from it on every menu build. It is plain data:
strings, finite numbers, booleans and tables.

```lua
menu={
    storage={file='config.ini',section='Settings'},   -- optional
    groups={
        {id='Layout',label='Layout'},
        {id='Advanced',heading=false,visible={field='Style',values={1}}},
    },
    fields={
        {id='Style',group='Layout',label='Style',default=0,tabs=true,
            choices={{value=0,label='Swap'},{value=1,label='Stack',note='Two rows'}}},
        {id='Size',group='Layout',label='Size',default=100,range={min=10,max=200,step=5,suffix='%'},
            relabel={field='Style',values={[1]='Stack size'}}},
        {id='Gap',group='Advanced',label='Gap',default=4,range={min=0,max=20}},
    },
}
```

- `storage`: values are saved under `section` in `file`, relative to the page's
  `configDirectory`. Without it, DMM's default storage applies.
- Groups keep their order, and fields theirs within their group; only groups with
  fields are shown. A group's heading is its `label`, else its `id`; `heading=false`
  hides it; `level` (0–6) sets its size.
- A group's `groups` are its subgroups, one level deep, shown after its own fields:
  `{id='Quickslots',label='Player Quickslots',groups={{id='Fangdango',label='Fangdango'}}}`.
  A subgroup's heading is smaller and sits at the row indent; its fields indent
  further, 3pt smaller (`mcWithin`). A group whose fields are all in subgroups still
  shows its heading, but cannot take `visible` or `relabel`.
- A field has `choices` (a picker; up to 64) or a whole-number `range`, and a
  `default` among them. One choice makes a button or, `readOnly`, a shown value.
  `tabs=true` shows up to eight choices side by side.
- `heading=true` puts a picker in the page's title row (one per page); `level` 0
  or 2–6 sets the label size.
- `visible={field=,values={...}}` shows a field or group only while that picker
  on the page holds one of the values. `relabel={field=,values={[value]='text'}}`
  names it after that picker's value.
- A choice's `note` is shown small under it. `module='<mod folder>'` notes that
  mod's name, as the mod browser shows it.
- `slot='<name>'` makes a read-only field the page's [slot](#slot-rows) for other
  contributors' rows; `slotLabel=true` lets it name the first of them, and
  `slotGroups=true` lets the rows keep their own groups (`mcSlotGroups`).
- `action=true` makes a navigation row (never stored; see [page hooks](#page-hooks));
  `link='<page id>'` or `'<provider>:<slot>'` opens that page.
- Ids are letters, digits and `_ . : -`; text has no `| ; [ ]` or control
  characters. Invalid data names the offending id.

A page with `menu` needs descriptor contract 4; ModCoreSettings builds that
predate it skip the whole contribution.

### Slot rows

A page can reserve a place for another mod's settings. Mark a read-only row as
the slot:

```ini
[Setting.MCC_Visuals_Pending]
Id=MCC_Visuals_Pending
Type=picker
Label=Quickslot templates
Group=Visuals
PresetValues=0|1
PresetLabels=Coming soon|Coming soon
mcReadOnly=1
mcSlot=visuals
```

Slot names are letters, digits and `_`, at most 64 characters, unique per page.
The page needs explicit `Id`s on every setting. Contributors address a slot as
`<provider id>:<slot>`; a `ModCore<Name>` provider may also be written as its
lowercase `<name>`, so `controls:visuals` and `ModCoreControls:visuals` are the
same slot. A contributor publishes settings from one of its own manifest pages
(which may be `visible=false`):

```lua
pages:publish({pages={...},rows={
    {page='ModCoreTemplates',slot='controls:visuals',settings={'MCT_Template','MCT_RingSize'}},
}})
```

When the page loads, the listed settings replace the slot row in place, in
contributor and list order. Each takes the slot's `Group`, so the group's
Category rule gates it. A row carries its own `VisibleWhen`/`VisibleValues`
only when they name a row the same contributor inserted earlier in that slot.
DMM ANDs that rule with the Category rule. A row without its own rule takes the
slot row's rule; a slot row with its own `VisibleWhen` rejects rows that bring
one. Source Category rules are not carried. Only core DMM fields are copied, so
inserted rows render as plain pickers, toggles or sliders. The exception is a
row label rule (`mcLabelWhen`/`mcLabels`): it is copied when `mcLabelWhen` names
a row the same contributor inserted earlier, and the row is skipped otherwise. A
row named by `mcSlotLabel=1` keeps no label rule. A picker's `mcChoiceNotes` is also
copied. Read-only rows stay shown values that store nothing. Presets, navigation and
link rows cannot be inserted. With no valid rows the slot row
shows unchanged. Each `rows` entry is all or nothing: one invalid setting skips
that entry, logged as `SLOT_ROW_SKIPPED`, and other entries still insert.

Add `mcSlotGroups=1` to the slot row to let inserted rows keep their source groups.
Each source group becomes a group of the host, `mcSlot.<slot>.<n>`, headed like any
group: DMM starts a heading wherever the group changes. One source page's entries share
its groups. The group keeps its source Category's `mcLabel` (else its name), `mcHeading`,
`mcLevel`, `mcHelp` and `mcSilent`, and takes the slot group's `VisibleWhen` rule; a
source group with its own `VisibleWhen` or `mcLabelWhen` skips that entry. A slot group
left without settings of its own is dropped. Host rows after the slot in the slot's group
would be headed again after the inserted groups, so give such a slot a group of its own.

Add `mcSlotLabel=1` to the slot row to let the host name the slot. The first
inserted row then takes the slot row's `Label`, `mcLevel` and `mcCategory`;
later rows keep their own. To make that row stand in for the group heading,
suppress the heading with `mcHeading=0` on the group's Category and give the
slot row `mcCategory=1`:

```ini
[Category.Visuals]
VisibleWhen=MCC_Page
VisibleValues=1
mcHeading=0

[Setting.MCC_Visuals_Pending]
...
Label=Quickslots Visuals
mcCategory=1
mcReadOnly=1
mcSlot=visuals
mcSlotLabel=1
```

Filled, the page shows one `Quickslots Visuals` row whose value side is the
contributed picker; with no rows, the placeholder shows under the same label.
The row stays the source's setting: storage, Apply and visibility are unchanged.
`mcHeading` itself is not transferred; a page has at most one level-one heading.

The page's model sees only its own settings: its configuration, initialization
and Apply event never include inserted rows. Inserted rows edit the source
page's model. The page's Apply commits its own settings first, then each
dirtied source, which publishes its Apply event under the source page id. A
source fails only its own commit; the host's event is still published. Restore,
Reset and the unapplied-changes guard cover both. A source whose model cannot
open leaves its rows inert. As on any page, unapplied changes are discarded
when the page closes, so the same setting on two pages never holds two pending
values.

A `visible=false` page that is a row source shows as an ordinary page, in its
declared place (`under`, `attach`), when none of its rows has an available
slot: the host page is not listed or does not declare the slot. Its rows then
work as on any page, with the same page id and storage. Build such a page to
stand alone. Availability is decided per menu build; a row entry rejected
later, while the page loads, does not bring the fallback back.

A page with `link='<provider>:<slot>'` and no manifest is a browser entry for
that slot. Selecting it opens the slot's page and sets the navigation pickers
that gate the slot so its rows show; navigation never marks the page dirty.
The entry is listed only while the host page declares the slot and the slot
has rows. Otherwise it is hidden like `visible=false`, including any detected
placeholder it claims. Link pages cannot have children.

Rows and links need descriptor contract 2, so a ModCoreSettings build that predates
slots skips the whole contribution, pages included.

### Page hooks

A page whose settings change at runtime, or that owns its own storage, names a
hooks file instead of menu data or a manifest. ModCoreSettings loads it in its own menu
state, once per session, and modules beside it can be `require`d. Every hooks
folder shares DMM's module search path, and the first module loaded under a name
wins, so give helper modules names unique to your mod (MCC's use `mc_`):

```lua
{id='ExampleMod',name='Example',attach='ExampleMod',
    hooks='<absolute path>/Scripts/mcs_page.lua',configDirectory='<absolute folder>'}
```

```lua
-- mcs_page.lua
return {contract=1,
    menu=function(context) return menuData end,                        -- every menu build
    -- or manifest=function(context) return settingsManifest end,
    load=function(context) return {[settingId]=value} end,             -- optional
    apply=function(context,values,changes) return saved,warning end,   -- with load
    action=function(context,id,value,values) end,                      -- optional
}
```

`action` runs whenever a navigation row (`mcNavigation=1`, not a page link) is
set, even to its current value. A navigation tab row whose choices share one label,
such as `PresetLabels=Play|Play` with `mcType=tab`, shows a single button that runs
it on each press. `id` and `value` are that row's; `values` holds every row's
current value by id, navigation rows included. An error is logged as
`HOOK_ACTION_FAILED` (ERROR) and the page carries on.

`menu` returns [menu data](#menu-data), `manifest` a settings manifest; a hooks
file has one of them. Both get `context.moduleName(folder)`, a mod folder's name
as the mod browser shows it.

`context` is `{page=<page id>,directory=<configDirectory>}`. With `load` and
`apply`, ModCoreSettings never reads or writes the page's config file: `load`
supplies the values (missing ids keep their defaults; a value the setting cannot
hold also keeps its default, is logged as `HOOK_VALUES_SKIPPED`, and is replaced
on the next Apply; keybinds are accepted in any form the editor normalizes), and Apply passes every
value by id and the edited ones as `{old=,new=}`. `apply` returns the values it
saved, which become committed and are published in the Apply notification, plus
an optional warning. An error from `apply` rejects the Apply and keeps the page
dirty; an error from `load` shows the page error. An error loading the file or
from `manifest` skips the contributor like any other failure. Hooks pages need
descriptor contract 3, which older ModCoreSettings builds skip.

### Page links

A navigation picker with `mcLinkPage=<page id>` opens that page instead of saving
a value. It requires `mcNavigation=1` and works in any manifest. With unapplied
changes the link is refused and the page shows a status message.
`mcLinkPage=<provider>:<slot>` opens the page that hosts that slot, sets its
navigation pickers so the slot shows, and selects the slot's first row. With
`mcType=tab`, a link shows one button labelled with its first choice. `mcLevel=5`
sets the row label in small (12pt) muted text, which suits a notice.

## Apply notifications

`Scripts/vendor/settings_api.lua` is ModCoreSettings's versioned, game-agnostic consumer API.
A mod may copy that file unchanged into its own `Scripts/vendor` folder and subscribe to its
own DMM provider ID:

```lua
local Settings=require('settings_api')
local unsubscribe=Settings.subscribe('ExampleMod',function(event)
    -- event.providerId, event.revision, event.values and event.changes
end)
```

DMM publishes only after a successful, durable Apply. Delivery is event-driven;
there is no file watcher or polling. Revisions are delivered at most once in a
Lua state. There is one active callback per provider ID; subscribing again through
the same client replaces it. Another Lua state cannot claim that provider ID.
Existing revisions are not replayed at subscription time: load startup values
from your config. Unsubscribing stops delivery but does not release the native
handler/claim; fully restart after script reloads. `values` contains the applied numeric settings (text keybinds are omitted), and
`changes` contains `{old=...,new=...}` only for changed IDs. Treat the event and
its nested tables as read-only. Reload your config to read text bindings; the
event is not their value transport. A page with no numeric stored values emits
no Apply notification through this API; its storage hook needs a separate
post-save notification for gameplay consumers.
Callback failure cannot turn a completed save
into an Apply failure. Calling the returned function stops delivery to that
callback.

## Presentation metadata

`mcType=tab` renders an ordinary picker as outlined, right-aligned choices
with a 24-pixel right inset on the same row as its label. Choices sit 4 pixels
apart; the selected choice's outline is drawn at full strength. It supports up to eight
choices and retains DMM's keyboard/controller navigation, pending model and
Apply/Restore behavior. A single choice suits a read-only row.

`mcReferenceLabel=<text>` on an `mcReadOnly=1`, `mcType=tab` picker adds a
disabled button showing that text to the left of its choices, which then take
150 pixels.

`mcType=cycle` renders a picker as one button showing only the current choice at
13pt; a click moves to the next choice, wrapping. The button is as wide as the
keybind editor's key box and sits in its key column, so it lines up under keys.
DMM's keyboard/controller navigation is retained.

`mcWrap=1` on an `mcReadOnly=1` picker shows its value as 13pt left-aligned
text in a wider column, broken after commas so no line reaches 34 characters;
the row grows to fit its lines.

`mcPlayerExists=1` on a setting or `[Category.*]` shows it only while a player is in
the world (a player controller possessing a pawn); `mcPlayerExists=0` only while
none is, as in the main menu. It works like a hidden Yes|No picker that follows the
player, combined with any `VisibleWhen`, so a row keeps its own rule; rows whose
`VisibleWhen` source it hides are hidden too. The check runs whenever DMM checks
visibility: on opening the page and on each change. Pages without it never check.

`mcSilent=1` on a setting or `[Category.*]` keeps DMM's interface sounds (hover,
select, change) off its rows, as on rows that play sounds of their own.

`mcDimValues=<value>|<value>` on a picker fades the whole row, label and value,
to 45% opacity while its own value is one of those listed, the opacity of a
disabled choice. Each value must be one of the picker's `PresetValues`. It is
presentation only: the row stays enabled and its value saves as usual.

`mcText=<source>` on an `mcReadOnly=1` picker replaces the row with a 360-pixel
scrollable text area showing a text source the host provides, newest line at the
bottom. While the row shows, the source is checked about once a second; new text
scrolls the area to its end. An unknown source shows "Unavailable." ModCore
Settings provides an `errors` source: the latest 100 error lines of
`UE4SS.log` (ModCore `ERROR`/`CRITICAL` messages, failed Lua calls, and lines
mentioning an error, exception or stack traceback, with their stack traces).

`mcTable=<code>:<text>|<code>:<text>|...` on an `mcReadOnly=1` picker replaces the
row with a static table of pairs, such as `2192:→|25CF:●`. `mcColumns=<n>` (1–6,
default 1) sets the columns, filled top to bottom. Codes are 12pt muted and texts
18pt, each centred horizontally and vertically in a cell sized for the longest code
or text plus 4 pixels of padding; each pair is centred in its column. Every line is
40 pixels high, so columns stay level and texts line up whatever the codes' widths.
A table taller than 360 pixels scrolls; 9 lines fit, such as 48 entries in 6
columns.
The code ends at the first `:`; neither part may contain `|`. Both are trimmed,
non-empty and at most 8 characters; a table has at most 256 entries. A malformed
table shows "Unavailable:" and the reason in its place; the page still loads. It
cannot be combined with `mcText`, `mcWrap` or `mcType`, and `mcColumns` requires
it. Like every read-only row it is never saved or marked dirty. Contributors can
check their values offline with `menu_contributions.textTable(value, columns)`,
which decodes them as ModCoreSettings does and raises on malformed input. A hooks
page writes the fields into the manifest its `manifest()` returns.

`mcChoiceNotes=<value>:<text>;<value>:<text>` on a picker gives choices a note,
shown small and muted on a second line under the current choice, within DMM's
40-pixel row; the choice's label moves up to make room. Each value must be one
of the picker's `PresetValues` and appear once; the text is trimmed, cannot
contain `;` and has at most 64 characters. A choice without a note shows one
line as before. The note is presentation only: saved values are unchanged. Tab,
cycle and header-tab pickers show no notes.

Set `mcNavigation=1` on a picker to use its choices only for menu navigation.
The picker can drive ordinary `VisibleWhen` / `VisibleValues` rules, but has no
config key, never marks the menu dirty, and is omitted from Apply events. Its
selected view lasts while the menu model is open. Navigation pickers use DMM's
arrow selector unless they explicitly request another presentation.

Set `mcTabsWidth` to an integer from 160 through 440 to reserve that total
width in pixels for the horizontal choices. The default grows by option count
up to 384 pixels. A two-option `mcTabsWidth=440` picker is twice the default
220-pixel width while retaining 144 pixels for its label.

`mcLevel=0` inherits the existing font. Levels 2–6 use sizes
16, 15, 14, 12 and 11 respectively. Level2/3 use the heading color;
Level4 uses normal body text; Level5/6 use
muted text, with Level5 at 85% opacity. The property applies to setting labels
and Category headings without changing control types. A setting label at level 2
is 20pt, larger than a level-2 heading, because it names the page's main choice.
`mcLevel=1` on a setting gives it the title style, like `mcHeading=true`.

Set `mcCategory=1` on a setting to make it stand in for its group's heading. Its
label takes the Category heading's look: 16pt muted, unindented, with the
heading's spacing. While it shows, the rows after it indent beneath it as they
would under a visible heading. Pair it with `mcHeading=0` on the group so the
heading does not show twice. It cannot be combined with `mcLevel` or `mcHeading`.

Set `mcHeading=true` on a setting to use the title style. That setting shares
the mod page title row above the divider, on any page. Its setting label is
hidden while the original control retains its value and navigation. Dirty
styling is omitted from this title row. This supports toggles, pickers and
sliders; at most one setting per provider may be a heading. Your mod still
implements its settings' behavior.

Categories can declare `mcHelp` to show Level5 explanatory text under
the heading. DMM's `VisibleWhen` / `VisibleValues` rules still govern the group.

`mcLabel=<text>` on a category is its heading's text in place of the category
name, so two groups can share a heading text. `mcLabelWhen`/`mcLabels` still
take precedence while their source holds a listed value.

Set `mcHeading=0` on a category to suppress only that category's heading:

```ini
[Category.Player Actions]
mcHeading=0
```

The category remains a normal DMM group: its rows retain their manifest order,
visibility rules, navigation and Apply/Restore behavior. Any shared `mcParent`
heading remains visible while the category has visible rows. `mcHelp` is not
rendered when its category heading is suppressed. `mcHeading` accepts
`false`/`true` or `0`/`1` and defaults to `true` on categories.

Set `mcWithin=<category>` on a category to make it a subgroup of that category:
its heading is 15pt in the heading color at the row indent, 10 pixels below the
rows above, with no rule, and its rows indent 10 pixels further with labels 3pt
smaller. One level only: the named category cannot itself be a subgroup. DMM takes
no category without settings, so when the named category has no rows of its own,
`mcWithinLabel=<text>` on its subgroups is its heading, drawn as a category heading
before them and hidden while they all are. It cannot be combined with `mcParent`.
Under `mcSlotGroups=1` a subgroup's `mcWithin` follows its category's slot name.

Categories can also share a parent heading without flattening that heading into
each category label:

```ini
[Category.PrimaryWheel]
mcParent=Interaction: Independent
mcParentLevel=2
mcLevel=3

[Category.SecondaryWheel]
mcParent=Interaction: Independent
mcParentLevel=2
mcLevel=3

[Category.SelectiveBindings]
mcParent=Interaction: Selective
mcParentLevel=2
mcLevel=3
```

`mcParent` is the displayed parent label. Categories with the same exact
label share one parent heading and retain their own category headings as
subgroups. `mcParentLevel` accepts levels 0–6 and defaults to 2; every
category sharing a parent must use the same level. Parent headings do not add
visibility rules. A provider that wants persistent Independent and Selective
sections should leave their categories unconditional. If every subgroup under
a parent is hidden by DMM, ModCoreSettings hides the otherwise empty parent heading.

For labels that depend on another picker or toggle, settings and categories
can declare:

```ini
mcLabelWhen=PrimaryWheel
mcLabels=0:Secondary Wheel;1:Primary Wheel
```

Unlisted source values retain the original label. Category ordering is opt-in:

```ini
mcOrderWhen=PrimaryWheel
mcOrders=0:20;1:10
```

Only opted-in categories exchange positions, in ascending rank order. Other
categories remain in their original positions. Rows retain their setting IDs,
config keys and children. Reordering occurs on a relevant value change, using
DMM's existing menu refresh; no additional timer is created.

## Missing defaults

DMM opens a page only when its config file holds every key. Whenever a page with
stored settings opens, ModCoreSettings adds each missing declared key with its
`Default`, in one file transaction, and keeps every other byte and unknown key.
There is no migration: values under retired keys are ignored, never converted. A
config that cannot be completed (for example a duplicated key) sets DMM's normal
error state and disables editing and Apply until it is corrected. No DMM source
files are modified. If a crash interrupts the transaction, the next open restores a
moved-aside original and removes leftover `.mc-init.tmp`/`.mc-init.bak` files that
are provably redundant; any other leftover file is named in the page error for you
to review and delete.

## Mapped presets

ModCoreSettings expands mapped presets inside DMM's own pending model. Declare a picker with
`CustomValue`, a pipe-separated `MappedPresetTargets` list of setting IDs, and
semicolon-separated `MappedPresetValues` entries. Each entry has the form
`presetValue:targetValue|targetValue`, in target order. For example:

```ini
MappedPresetTargets=Ability1|Ability1Mode
MappedPresetValues=1:82|0;2:49|1
CustomValue=0
```

The picker must declare values `0|1|2` in this example. Every non-Custom value
needs a complete mapping. Targets may be sliders, pickers or toggles; values must
fit their declared ranges, steps or choices. Overlapping and nested presets are
rejected, including overlap with DMM's ordinary `PresetTargets`.

Selecting a preset synchronously updates all targets before DMM refreshes or
applies. Preset-derived target changes hide their dirty indicators while retaining
the actual pending/committed differences. A manual target edit selects Custom and
marks only that target against the selected preset's visual baseline. Returning
all targets to a named preset selects it automatically. Custom cannot be chosen
directly. Apply and Restore clear the visual baseline.
Apply and Restore remain DMM operations. Opening an inconsistent saved preset
preserves its keys and changes the pending picker to Custom.

## Module categories

The Settings page's Modules tab provides Sort by (Recently Added/Categories/Alphabetical/Load Order) and, with Categories, Collections valid with # modules (No/2/3) and Modules appear in a single category (Off/On), and, with Categories or Recently Added, Modules per row (1/2/3), all under a Listing heading. Apply saves [Modules] SortBy (2/1/0/3), PreferredCategoryMinimum (0/2/3), SingleCategory (0/1) and ModulesPerRow (1/2/3) in config.ini. Defaults are Categories, 2, Off and 2. Modules per row sets the columns of every group's grid; mod names are left-aligned in every layout. With a single category, a mod whose categories span several top categories is listed only under the one holding most of them; a tie goes to the one declared first, a preferred category counting as declared first. The mod list's title line carries settings and controls links, top right, opening ModCore Settings and ModCore Controls when they are listed. The mod list's footer button (DMM's Filter Mods, Backspace) is Sort by: each press moves to the next way, saves it the same way and re-sorts the list. Inside every group mods follow load order (in Recently added, newest first), those with settings first. Load Order lists mods in load order, each with its load-order number; mods without settings fold to the end as in every list, so the numbers shown skip them.

Recently added lists mods by their latest install or update, newest first, under Last 24 hours, Last 7 days, Last 30 days and Earlier. On each boot MCS records every active mod folder's top level in `cache/folder_info.json`: its files (name, size and, with the file bridge, creation and modification times) and folders, when the folder was added and when it was last updated. A folder it has not seen is added at the boot time; one whose top-level files or folders changed is updated at the boot time. Settings files (`.ini` other than `mod_settings.ini`), logs and `cache/` or `logs/` folders written while playing are ignored. Removed folders are forgotten, so a reinstall counts as new. Folders present when the record was first made are listed as Earlier. With [UE4SSLuaFileBridge](https://github.com/jrpereira/UE4SSLuaFileBridge) installed, the file is written atomically and a folder seen for the first time takes the newest creation time of its top-level files instead, so nothing is left as Earlier only because it was already installed; an update in place keeps old creation times, so it is still dated by the boot that noticed it. Deleting the file loses only those update dates. The module browser is rebuilt with the applied values when you return to it; so it is after any page's Apply.

Browser grouping is described in [Module categories](MODULE_CATEGORIES.md#browser-behavior). Every mod, ModCore's own included, groups by the same rules. Unregistered folders and conflicting matches use Other or Specialized.

ModCore Settings' own page has a Templates tab holding one slot, `settings:templates`, which ModCore Templates fills with every loaded template, one group per category (`mcSlotGroups=1`). It also carries a generated Developer Tools tab, rebuilt with the mod list, listing the `group='tool'` pages.

# Changelog

## Unreleased

- The ModCore Settings page's tabs are Settings | Controls | Templates | Extensions |
  Developer Tools, and it opens on Settings. Controls shows ModCore Controls' page;
  Extensions shows the UE4SS Lua Extensions' page; Settings is the former Modules tab.
  Slot `settings:controls` holds ModCore Controls' page and slot `settings:extensions`
  the UE4SS Lua Extensions' page.
- The mod list's title line has one link, **settings**, which opens ModCore Settings'
  page on its Settings tab. `mod.json`'s `title_link` is no longer read.
- Slots take more kinds of rows: page links, which open their page from the host with
  Back returning to it, and ModCoreSettings' range and keybind settings. A slot among
  inserted rows is filled too (ModCore Templates' Quickslots rows inside the Controls
  tab), its rows still saved by their own page.
- A hidden page whose rows fill a slot stays in the menu, listed nowhere: its inner pages
  open, the slots it declares take rows, and a link to it opens the page that shows its
  rows. The order contributors publish in no longer matters.
- Inner pages: a contributed page with `group='inner'` and `under` is listed nowhere and
  opens through a page link. Back on any page a link opened now returns to the link's
  page with its row selected, instead of to the mod list; a chain of links unwinds in
  order. `menu_contributions.lua` is version 9.
- A page link may end in `#<row id>` (`mcLinkPage=<page id>#<row id>`): the page opens
  with that row showing and selected, so a link can open a page on one of its tabs.
- A slot whose rows keep their groups (`slotGroups`) also keeps a row that stands in for
  its group's heading (`mcCategory`), so a contributed picker can head the rows after it.
- Logging goes through the UE4SS Lua Log Bridge when it is installed: levels per mod
  and category from the bridge's settings, changeable in game. Without it, WARN and
  above go to UE4SS.log as before. `log_level.txt` is no longer read; mods that vendor
  `mc_log.lua` (version 2) need no changes to their calls.

## v1.9.1

- Options -> Use Compact Style (Off, Index or Everywhere; Off by default): in a loaded game
  the mod menu takes the pause menu's look, the game blurred behind a dark panel down the
  left and the page drawn smaller; Index on the mod list, Everywhere on every page.
- The mod menu's footer sits low, as in the game's own menus, Back on the left and the
  actions on the right, leaving more room for the page.
- The Modules tab's settings, Sort by's choices and Developer Tools rows have descriptions.
- A slot that keeps its rows' groups (`slotGroups`) and names them (`slotLabel`) heads its
  first group with its own label.
- A page's tabs are titled by the selected tab in the side panel, not by the row's label.
- A setting's title above its description is white, as the mod list names its mods.
- A picker choice may have a description: the side panel shows it after the setting's own
  while that choice is the value.
- A live preview's buttons read '<name>: <value>'. Background is On (the picture as it
  is), Blurred, Dimmed (the default) or Off (a plain dim screen instead of the picture).
- The ModCore Settings page's Previews section: Play sound in previews (Auto, On or Off)
  and Background in previews (On, Blurred, Dimmed or Off) are the live preview's buttons,
  saved in config.ini; a click on a button saves it too.
- Config reload: returning to the game window (with the UE4SS Lua Event Bridge 1.4.0 or
  later) silently reloads every module that subscribed through `settings_api` 3's
  `onReload`; any mod may trigger the same with the console command `MC_ConfigReload_v1`.
- A menu-data field may store under its own section, key and file,
  `storage={section=,key=,file=}`; two fields at one file, section and key reject the page.
- A setting may leave out `ConfigFile`, `ConfigSection` and `ConfigKey`: it is stored in
  the page's `config.ini`, in the section named by `[Mod] ConfigSection` (else, when it
  also leaves out `ConfigFile`, by `[Mod] Id`), under its own `Id`. Settings that state
  them are stored as before.
- A config file that repeats a section opens: the repeats count as one section, and
  missing keys are added at the end of its last occurrence.
- The mod list opens faster when pickers list their choices from files.
- A live preview without a background picture, or with one that cannot be read, shows
  nothing behind it instead of a white box.
- A list file's `context.head(path, count)` reads a file's first bytes in the mod folder,
  so it can leave out files it cannot use.
- Small layout fixes: the preview's sound button, page-link underlines and merged-page
  notices.

## v1.9.0

- Requires UE4SS Lua File Bridge and Sound Bridge 1.1.0 or newer. Without them MCS still
  runs, with less: no file dates or safe config writes, and no sound for a picked file.
- A live preview's sound button: Auto (the default; the page's provider decides, and
  Preymonition sounds while a sound setting is selected), On or Off. The selected setting
  is shared as `MCS.Preview.v1.focus`, the button as `MCS.Preview.v1.sound`.
- A choice's sound may be a WAV file: selecting it plays the file through UE4SS Lua Sound
  Bridge, and the next selection stops it. A list file names the file in the mod's folder
  (`sound='sounds/x.wav'`).
- A page can show a live preview: menu data with `preview={background=<picture>}` gets a
  16:9 area at the bottom of the side panel. The page's provider draws it from the page's
  values, applied or not, after every change, through the `MCS.Preview.v1` shared
  variables and the `MCS_Preview_v1` command.
- Settings rows are wider and their values roomier, so longer choice names fit; key boxes
  are wider too. The mod list keeps its widths.
- Pickers show one pip per choice up to 24 choices (was 16); more choices show a track
  and thumb.
- Left and Right move a range's markers on a row merged into another page (for example
  ModCore Controls' options); only Enter reached it before.
- A page link opens with Enter (controller: A) or a click, no longer with Left or Right.
- Category headings, notices and links line up with the values and page edge; a heading's
  first letter is no longer clipped.
- Keyed pickers can list their choices from a mod's own list file: a `{from=, root=}` entry
  among the choices is replaced, each time the menu opens and after each Apply, by what
  `<root>/Scripts/<from>` returns. Files a mod adds while the game runs show the next time
  the menu opens. A failing list keeps its last good choices and is logged once as
  `MENU_LIST_FAILED`.
- A page-hooks file whose `menu()` declares `storage` and has no `load()` is stored the
  way a menu-data page is, keyed pickers included. Its `action()` still runs.
- An error in ModCoreSettings while the menu builds a page no longer stops Dawnwalker Mod
  Menu for the session. It is logged once as `MCS_BUILD_FAILED` (ERROR), and until the game
  restarts Dawnwalker Mod Menu shows its own plain mod list, without ModCoreSettings'
  grouping, tabs or contributed pages. Settings are not changed.
- A failure while grouping the mod list keeps the list as it was instead of stopping the
  menu; it is logged as `BROWSER_GROUPS_FAILED`.

## v1.8.0

- A page link is drawn as underlined text in the value column, dimmed until hovered,
  instead of a framed button.
- Long key names are drawn smaller in the keybind editor.
- Menu data enums can be keyed: each choice has a text `key` instead of a number `value`,
  and the setting is saved, loaded and notified as that key. Adding, removing or reordering
  choices keeps every saved key that is still offered, and a key that is not falls back to
  the default. Keyed pickers also work as slot rows on another page.
- `settings_api` version 2 delivers every applied setting, text included: keyed enum keys,
  ranges as `low|high` and keybinds. Consumers re-vendor `Scripts/vendor/settings_api.lua`;
  a version 1 copy keeps receiving numeric values only until then.
- `menu_contributions` version 8 accepts keys in value lists.
- The Modules tab no longer reserves a Lua Extensions section; UE4SS Lua Extensions lists
  itself in the mod list instead.
- Slot rows from one hidden page share its groups once in the slot, and Apply saves every
  row, instead of failing with "config changed externally" after the first.
- The Modules page counts a mod enabled in `Mods/mods.txt` (`Name : 1`) as loaded, as
  UE4SS does; such mods and their settings pages are no longer dropped, nor reported as
  missing requirements.
- Load Order follows the order UE4SS starts Lua mods: `mods.txt` entries first, in file
  order, then the remaining folders by name, ignoring case, so `ModA` now precedes `Mod_X`.
- Saving a mod's settings no longer lists that mod under Recently Added.
- Keybind capture ignores the mouse wheel, as documented, and wheel names in a config
  file are not accepted.
- Resetting a selected action or link row (Delete or the footer's Reset) no longer runs the
  action or opens the link.
- A changed setting's star and italic label update as soon as it is edited.
- Config files saved with a UTF-8 byte order mark (as Notepad can) keep their first section.

## v1.7.1

- The Modules page recognises 33 more mods by their folder name, and Combat Disengage now
  appears under Movement as well as Combat.

## v1.7.0

- The mod list marks each module whose `mod.json` dependencies are not all loaded at a
  version they accept with a red `⚠` at its right. Its details show a Requirements section
  after Author listing each dependency with the version it needs and the one loaded,
  mismatches first.

## v1.6.0

- A field-type editor can declare `help`: how to use its control, shown in its own box
  between a setting's title and description. The range row uses it to explain Enter (A)
  to grab and let go of a handle.
- Clicking above a pip on an arrow picker's indicator chooses that value; clicking either
  side of the indicator still steps like the arrow there.
- A range row's handles show only while the row is hovered or selected, and while one is
  grabbed the other hides. The mouse now drags reliably: a press takes the nearer handle and
  it follows the pointer until the button is let go, even off the track.
- Pickers and sliders share one row height and value size.
- A row selected with the keyboard no longer leaves another row looking hovered.
- Fixed: A on a controller did not reach field-type editors such as the range row, and the
  footer hint did not show the Enter glyph on a keyboard.
- Fixed: Enter on a field-type editor could also press DMM's Back button, leaving the page.

## v1.5.0

- `Type=range` settings pick a low and a high value on one track, stored as one text value
  `<low>|<high>` (e.g. `70|90`), on pages with storage hooks. `Min`, `Max`, `Step` (1 to 40
  steps), `DeltaMin` and `DeltaMax` (bounds on high-low), `LowMax`, `HighMin` and `Suffix`
  declare it. Left/Right highlight a handle; Enter, or A on a controller, grabs it so
  Left/Right move it a step, and lets go again. The mouse moves the nearer handle to the
  pressed step and drags it.
- Menu data declares what a setting holds and how it shows, separately. A field's `type` is
  `enum`, `integer` or `range` (inferred from `values` when left out; a range is always
  declared), its `values` the domain, and its `widget` the view: `picker`, `tabs`, `cycler`,
  `switch`, `text` or `table` for an enum, `slider` for an integer, `range` for a range.
  `style` makes a row stand out: `title` (the page title row), `category` (stands in for its
  group's heading) or `notice` (small, muted text); a group's `style` is `category` (the
  default) or `none`. The keys `choices`, `range`, `tabs`, `cycle`, `onOff`, `readOnly`,
  `heading`, `level`, `category` and `referenceLabel`, and a group's `heading`, `level` and
  `parent.level`, are removed.
- A menu-data range takes `values={min=,max=,step=,suffix=,delta=}` with `default={low,high}`.
- A menu-data page with `storage` that holds a range or keybind row is saved by
  ModCoreSettings: every stored row under its section, missing keys added on Apply, the
  rest of the file kept.
- While a range row is selected, the footer shows `ADJUST`, or `DONE` while a handle is
  grabbed.
- Field-type editors can take a row's Left/Right, Enter and A (`navigation=true`), and
  show a footer hint.

## v1.4.0

- Each enabled module's `mod.json` `id` is shared at load as `MCS_ModuleId_v1.<folder>`,
  followed by `MCS_ModuleId_v1.ready`, so other modules (ModCore Templates) can key their
  settings by module id. An invalid id, or one two folders declare, is logged and not shared.
- `mcType=onoff` shows a picker with the choices 0 and 1 as an on/off switch, the current
  choice's label beside it; a click anywhere across the value flips it. Menu data takes it
  as `onOff=true`.
- Pickers and sliders animate to a new value.
- A click past an arrow picker's last choice wraps around to the first, and before the
  first to the last. Keys and controller still stop at the ends.
- Subgroup rows indent further and are more compact.
- A subgroup without a heading (`heading=false`, `mcHeading=0`) shows its rows as its
  parent group's own.

## v1.3.1

- The browser recognises five more mods by their folder name.

## v1.3.0

- An `mcCategory` row is ruled beneath like the heading it stands in for.
- `mcChoiceSounds=<value>:<event path>;...` gives a picker's choices their own sound,
  played instead of DMM's change sound when the row changes to them (`none` plays nothing).
  The next change, another page or closing the menu stops the previous choice's sound, so
  long sounds work as previews.
- Menu data takes a choice's `sound` (an event path or `'none'`).
- Menu data covers the rest of the presentation metadata: `silent`, `category`, `cycle`,
  `tabsWidth`, `wrap`, `table` and `referenceLabel` on fields; `help`, `silent` and `parent` on groups.
- Menu data's state-dependent rules move under `conditions`: `visible` (a picker rule,
  `playerExists`, or both), `label` (was `relabel`), `dim` and, on groups, `order`. A `label` or
  `order` key may list values sharing one entry (`[{1,2}]='text'`); `menu_contributions.unfold`
  (client version 7) expands them.

## v1.2.0

- The browser's title-line links are declared by the mods themselves: a `mod.json`
  `title_link` gives the link text.
- A crash while ModCore Settings saves a file leaves the previous file in place.
- Saving a config file keeps every other line of it as it was.
- The version lives in a `VERSION` file at the mod root, like the other ModCore modules.
- Clicking either side of a picker's value steps like the arrow on that side.
- Subgroups: a menu-data group's `groups` are its subgroups, one level deep (manifests:
  `mcWithin=<category>` on a category, with `mcWithinLabel` heading a category that has no
  rows). Menu-data fields now stay together under their group, in group order.
- Menu data puts a picker in the page title row with `heading=true` (`mcHeading=1`)
  instead of `level=1`; a field's `level` now takes 0 or 2–6.
- ModCore Settings' page has no Errors tab any more; its tabs are Modules, Templates and
  Developer Tools. The Templates tab is a slot, `settings:templates`, that ModCore Templates
  fills with its list of loaded templates.
- A slot row with `mcSlotGroups=1` (menu data `slotGroups=true`) lets inserted rows keep their
  source groups, each with its own heading.
- Menu data fields can be slots: `slot=<name>` (and `slotLabel=true`) on a read-only field,
  so a menu-data page can host other contributors' rows.
- Read-only rows can be mirrored into a slot. They stay shown values with no storage.
- ModCore Settings' Modules tab reserves two slots after Listing, `settings:extensions` and
  `settings:verifications`, for UE4SS Lua Extensions.
- Pickers with arrows show how many choices they have and which is current: a row of pips
  under the value (a track with a thumb beyond 16 choices), brighter while the row is
  hovered or selected.
- At a picker's first or last choice the arrow that has nowhere to go stays visible,
  dimmed, instead of disappearing.
- Grouped mod lists are more compact, and hovering a group heading no longer highlights it.
- Page tabs (top right) are restyled: the selected tab glows and the others are dimmed.
- A hidden page attached to a mod also hides that mod's own entry when the mod has
  settings of its own, so a contributor can replace several mods' entries with one page.
  The entry returns when the contributor withdraws or does not load.
- `mcText` rows are removed with the Errors tab.

## v1.1.0

- A key row's `DefaultControl` keys come from `Scripts/vendor/standard_keys.lua`, which
  mods vendor to bind the same keys.
- Contributed pages can describe their settings as `menu` data (groups, fields with
  choices or a range, visibility and label rules, storage) instead of a DMM manifest.
  Descriptor contract 4, client version 6. Page hooks may return `menu(context)` in place
  of `manifest(context)`, and get `context.moduleName(folder)`.
- A contributed page that takes the place of a mod's entry shows that mod's name,
  author, version and icon from its `mod.json`. `mod.json` `icon` is shown for detected
  mods too.
- `mcLabel=<text>` names a category heading in place of its category name.
- ModCore's modules group in the mod list through their `mod.json`
  (`"preferred": "ModCore"`) like any other mod. Top categories come first, then
  collections. Within a group, mods follow category then load order, and mods without
  settings fold into a final "and X more with no settings" entry.
- Group headers show the group's icon, a small line naming the group (top category,
  Collection or Author) and the title.
- The ModCore page is gone. Its Errors and Developer Tools tabs are on ModCore
  Settings' own page. The Installed, Highlighted Modules and Core Functionality tabs
  are gone, with their settings.
- ModCore Settings' own page takes its name and icon from `mod.json`. Its Modules tab
  settings keep their `config.ini` keys.
- Group modules is now Sort by: Recently Added, Categories, Alphabetical or Load Order
  (numbered). The mod list's Filter Mods button (Backspace) is now Sort by and cycles
  them. Inside every group, mods follow load order (Recently Added: newest first), those
  with settings first. Recently Added lists mods newest first by when each was installed
  or last updated.
- Modules per row (1, 2 or 3; default 2) sets how many mods each group shows per row
  in the Categories and Recently Added views. Mod names are left-aligned in every layout.
- Sort by is saved as `[Modules] SortBy`; `GroupModules` is no longer read.
- Declared categories follow taxonomy v3: the first three main categories in
  declaration order are kept and the rest are named in a warning; `niche` or `other`
  beside another category rejects the declaration; `ambiguous` is the classifier's
  alone.
- Mod folders are listed whatever their names hold; only `.bak` copies are skipped.
- Missing config keys are still added with their defaults; the migration keys
  (`DefaultFrom`, `DefaultFromMap`, `ValueMap`, `DefaultRule`) are removed.
- The menu is lighter on performance while open.
- With UE4SS Lua File Bridge installed (optional), Recently Added uses each mod's real
  install date and MCS's own files are saved safely.
- After any page's changes are applied, the mod list is rebuilt when you return to it.
- A level-one setting takes the page title row on every page, and never shows an
  unapplied-change star there.
- Module browsing uses Gameplay, Content, Presentation, Technical & Support and Other
  sections, with up to three declared categories, separate tags and inferred parents.
- `mcTable=<code>:<text>|...` with `mcColumns=1..6` shows static code and text pairs in
  aligned columns; `menu_contributions.textTable` checks them offline.
- The ModCore page has Modules | Errors | Developer Tools tabs. Errors shows the latest
  error lines of `UE4SS.log`.
- `mcText=<source>` shows a text source in a scrollable area.
- `mcSilent=1` keeps DMM's interface sounds off a row or category.
- `mcDimValues=<value>|...` fades a picker's row while its value is one of those listed.
- `mcPlayerExists=1|0` shows a row or category only while a player is, or is not,
  in the world, alongside its `VisibleWhen`.
- Page hooks may add `action(context,id,value,values)`, run when a navigation row
  is set; a one-label navigation tab row is a single button that runs it.
- A longer tab label widens its own tab.

## v1.0.1

- `mcChoiceNotes` gives picker choices a small muted second line under the
  current choice, such as the module providing a template. Slot rows keep it.
- Keybind rows sharing `mcConflictScope` that bind the same key and trigger
  show a dim red key background; the navigation picker separating the two rows shows
  its choice and arrows in red. Apply is unchanged.
- Unapplied changes show as a `*` after the page title instead of the
  "Unapplied changes" status text. Errors and failed Applies still show as text.
  Keybind rows now show the `*` when edited.
- A hooks page whose `load()` returns a value the setting cannot hold keeps the
  default and logs `HOOK_VALUES_SKIPPED`, instead of breaking the page.
- A crash while a config file was being completed no longer blocks the page: the next
  open restores it.
- A failure to start inside Dawnwalker Mod Menu is logged as `DMM_HOOKS_FAILED` with its
  cause instead of asking for a restart.
- Release packages include `enabled.txt`, so the mod is enabled when installed.
- `mcType=tab` choices are outlined.
- A page-link row (`mcNavigation=1`, `mcLinkPage`, `mcType=tab`) wraps a long label.
- `mcWrap=1` shows a read-only value as wrapped text in a wider column.
- `mcType=cycle` shows a picker as one button with only the current choice; a click
  moves to the next choice.
- The keybind editor reads Mode, key, X. Unbound with a default control, the key box
  shows the default keys dimmed under a small "default" label.
- Keybind rows name the mouse buttons Left, Right and Middle Button, and numpad
  digits NumPad 0 to NumPad 9. Saved values keep the engine key names.
- A keybind's default trigger is the first one listed in `Triggers`, instead of
  Tap whenever Tap is listed.
- Logs at levels TRACE, DEBUG, INFO, WARN, ERROR and CRITICAL, WARN and above by default;
  `log_level.txt` in the mod folder sets the level. Other mods can vendor
  `Scripts/mc_log.lua` for the same logger.
- Menu contributions: other mods publish generated pages as data through the vendorable
  `menu_contributions.lua` client instead of installing DMM extensions.
- `mcLinkPage` for navigation pickers that open another page; it replaces
  `mcLinkProvider`. It also takes a slot address (`<provider>:<slot>`).
- The installed mod folder is `1_ModCore_Settings`.
- `Type=keybind` replaces the slider-based keybind (`mcType=keybind` with `mcOptional`,
  `mcDefaultControl`, `mcMode` and `mcGroupedBy`) and `Pair=` mode pickers: one setting
  holding `none` or `<FKey>|<trigger>` as text, with key box, trigger control, clear button
  and default keys. Only `mcType=tab` remains as an `mcType`.
- ModCoreSettings no longer edits Dawnwalker Mod Menu's files: it keeps DMM's `main.lua`
  as `main.dmm.lua` and starts DMM through a small launcher, so DMM updates are picked up
  automatically.
- Runtime markers and settings prefixes are `mc` instead of `kem`.
- Slot rows: a page marks a read-only row with `mcSlot=<name>` and other contributors
  publish their own settings into it. Inserted rows stay owned, saved and applied by
  their source page. A hidden row-source page shows as an ordinary page when none of its
  rows has an available slot.
- Slot links: a contributed page with `link='<provider>:<slot>'` opens that slot's page
  with the slot showing.
- `mcSlotLabel=1`: the first inserted row takes the slot row's label and level, so a host
  can present a contributed picker as a section heading.
- `mcCategory=1`: a setting stands in for its group's heading, with the group's other
  rows indented beneath it.
- Inserted slot rows keep their label rule (`mcLabelWhen`/`mcLabels`) when it names
  a row the same contributor inserted earlier.
- `mcOptional=1` key rows with a click-to-clear control; unbound keys are dimmed.
- Key capture covers the standard keyboard, keypad, punctuation, browser, media and
  mouse-button keys; Escape cancels capture.
- A header picker's choices show as tabs hanging from the title divider.
- Page hooks: a contributed page may name a Lua file that generates its manifest on every
  menu build and optionally owns its storage (`load` and `apply`), so no mod needs its own
  DMM extension (descriptor contract 3).
- A row with invalid metadata shows only its label and a short error; the page's other
  rows still work.
- An unbound key with a `mcDefaultControl` shows the keyboard keys the game binds to that
  action.
- Release packages publish every document at the mod root.

## v0.3.1

- Preset unapplied-change marks, grouped presentation and missing-default initialization
  are refined.
- Uses the ModCoreSettings name and `_ModCore_Settings` installation folder.
- Reads `mc*` presentation metadata; older metadata names are no longer supported.

## v0.3.0

- Renamed KEngineMenu (KEM), installed under `_KEngineMenu`.
- Uses `mc*` metadata; older `amm*` metadata and settings are not read.

## v0.2.25

- Controls-page grouping, including controller settings.
- Menu levels, optional hidden headings, wider horizontal pickers and paired key and
  mode controls.
- Tap/Hold is a single toggle beside the key, with Default as a separate option.
- Better key capture, hover feedback and setting updates.

## v0.2.24

- The Tap/Hold control lines up beside its key field.

## v0.2.23

- The Tap/Hold control is softened while Default is selected.

## v0.2.22

- The Tap/Hold control is narrower.

## v0.2.21

- Tap/Hold modes are one control that toggles on click, with an optional Default mode
  beside it.

## v0.2.20

- Ordinary Mod Menu entries are left-aligned.

## v0.2.19

- Hover glow on paired pickers highlights the hovered tab only.
- The bundled Dawnwalker settings-page fixes are enabled by default.

## v0.2.18

- Paired key fields and Tap/Hold tabs keep fixed columns, with an optional Default tab.

## v0.2.17

- Empty key capture is rejected; a paired `Default` mode turns capture off.

## v0.2.16

- Three-option `Pair` tabs sit left of their key field; capture is dimmed while Default
  is selected.

## v0.2.15

- Paired tabs have a background behind them; the menu responds faster.

## v0.2.14

- Key controls in `Pair` rows show again.

## v0.2.13

- The picker that declares `Pair` owns the combined row and its label.

## v0.2.12

- Horizontal picker labels are centred in their slot.

## v0.2.11

- The template folder is `templates`.

## v0.2.10

- `ammTabsWidth` lets horizontal pickers take up to 440 pixels.

## v0.2.9

- Metadata keys use the `amm...` prefix instead of `Deco...`.

## v0.2.8

- Generated pages can ask for a smaller mod list font and a bounded indent.

## v0.2.7

- The Dawnwalker settings-page fixes are a template, `menu.fixes`.

## v0.2.6

- The Controls page shows the game's controller panel when a moved controller setting is
  selected.

## v0.2.5

- The Controls page gets a Controller Settings category after the mouse settings, holding
  Preset, Controller Sensitivity and Vibrations; the former Controller page is empty.

## v0.2.4

- `ammHeading=0` hides a category's heading while keeping its rows.
- The mod list's selector is a page header with a divider.
- The Controls page gets a Mouse Settings heading.

## v0.2.0

- Left and right Shift, Control, Alt and Windows keys are captured separately; modifier
  chords are rejected.
- Renamed Adaptive Mod Menu (AMM); an installed Mod Menu Decorator is retired.
- `enabled.txt` is left to you or your mod manager.

## v0.1.52

- Unapplied-change labels work again.

## v0.1.51

- Fixes a crash; the mod no longer needs a DLL.

## v0.1.50

- Clicks on paired pickers are more reliable.

## v0.1.49

- Picker clicks are handled differently, to avoid a startup crash.

## v0.1.48

- Pages open faster.
- `settings_api.lua` delivers notifications after a successful Apply.

## v0.1.47

- `ammParent` and `ammParentLevel` give related categories a shared parent heading.

## v0.1.46

- Changing which rows a picker shows keeps their decorations.

## v0.1.45

- Rows are matched to their settings by id, never by position or label.

## v0.1.44

- Paired, fixed-mode and unpaired keybindings line up on one grid.

## v0.1.43

- Missing configuration keys can be filled from an older file's values.

## v0.1.42

- Fixed Tap/Hold labels are dimmed without disabling key capture.

## v0.1.41

- Fixes unapplied-change marks while a page is built.

## v0.1.40

- `ammMode=Tap|Hold` shows a fixed mode for keybindings without an editable one.

## v0.1.39

- Metadata uses `ammType=tab|keybind` and `ammLevel=0–6`.
- Tab pickers, six font levels, a header toggle, category help, conditional labels and
  category ordering.
- A manual edit after a preset selects Custom.

## v0.1.38

- Presets refresh faster; unapplied-change stars sit left of the label.

## v0.1.37

- Unapplied settings show a star and an italic label.
- Mapped presets (`MappedPresetTargets`, `MappedPresetValues`) update several settings at
  once and select Custom after a manual edit.

## v0.1.36

- Missing config keys are added with their defaults at startup, keeping existing values.

## v0.1.35

- Packaging changes only.

## v0.1.34

- Fixes Restore after a failed edit and reselecting the previous key.

## v0.1.33

- The package includes the updated README.

## v0.1.32

- Broken controls stop updating instead of retrying.

## v0.1.31

- Promotes 0.1.31-rc.2.

## v0.1.31-rc.2

- Fixes recovery when a page cannot be decorated.

## v0.1.31-rc.1

- Test release of the work through 0.1.30.

## v0.1.30

- Recovers after page errors; only the selected page is updated.

## v0.1.29

- Decorations survive page switches without rescanning.

## v0.1.28

- A second mod with an already used Mod Id is skipped, as DMM does, and logged.

## v0.1.27

- Recovers an open menu whose opening was missed.

## v0.1.26

- Fixes refreshing a page whose rows were replaced.

## v0.1.25

- The menu is only watched while it is open.

## v0.1.24

- Key changes no longer wait for DMM to acknowledge them.

## v0.1.23

- A hidden or disabled menu stops being updated.

## v0.1.22

- Picker clicks are delivered without extra polling.

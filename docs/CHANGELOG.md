# Changelog

## v1.3.0

- An `mcCategory` row is ruled beneath like the heading it stands in for.
- `mcChoiceSounds=<value>:<event path>;...` gives a picker's choices their own sound,
  played instead of DMM's change sound when the row changes to them (`none` plays nothing).
  The next change, another page or closing the menu stops the previous choice's sound, so
  long sounds work as previews.
- Menu data takes a choice's `sound` (an event path or `'none'`) and writes it as `mcChoiceSounds`.
- Menu data covers the rest of the presentation metadata: `silent`, `category`, `cycle`,
  `tabsWidth`, `wrap`, `table` and `referenceLabel` on fields; `help`, `silent` and `parent` on groups.
- Menu data's state-dependent rules move under `conditions`: `visible` (a picker rule,
  `playerExists`, or both), `label` (was `relabel`), `dim` and, on groups, `order`. A `label` or
  `order` key may list values sharing one entry (`[{1,2}]='text'`); `menu_contributions.unfold`
  (client version 7) expands them.

## v1.2.0

- The browser's title-line links are declared by the mods themselves: a `mod.json`
  `title_link` gives the link text (ModCore Settings and ModCore Controls declare theirs),
  where the browser used to name those two pages itself.
- One crash-safe file reader and replacer, `safe_file.lua`, shared with the other ModCore
  modules, serves the configuration initializer, the module registry, the module browser
  data, the Sort by button and published page descriptors. A crash mid-write leaves the
  previous file in place; a `.old` copy of each replaced file is kept beside it.
- INI text is read and edited through one shared module, `mc_ini.lua`, also used by ModCore
  Templates: manifests, the configuration initializer, the Sort by button and the module
  browser preferences. Edits splice the original text, so every other byte stays as it was.
- The release version lives in a `VERSION` file at the mod root, like the other ModCore
  modules, instead of in `Scripts/main.lua`.
- The repository tools and their shared tests are owned here and listed as vendored copies
  in the other ModCore repositories, so a drifted copy is reported.
- The hidden-widget text formats MCS's two Lua states exchange are named in one file,
  `mcs_protocols.lua`.
- The player check and the text-area poll measure wall-clock time (`os.time`) instead of CPU
  time.
- Clicking the outer 40% of a picker's value, either side, steps like the arrow on that side;
  the middle 20% selects the row as before. The choice indicator under the value spans 75% of
  its width, its pips sharing it evenly.
- Subgroups: a menu-data group's `groups` are its subgroups, one level deep (manifests:
  `mcWithin=<category>` on a category, with `mcWithinLabel` heading a category that has no
  rows). A subgroup heading is smaller, at the row indent and without a rule; its rows
  indent 10 pixels further, 3pt smaller. Menu-data fields now stay together under their
  group, in group order.
- Menu data puts a picker in the page title row with `heading=true` (compiles to
  `mcHeading=1`) instead of `level=1`; a field's `level` now takes 0 or 2–6.
- ModCore Settings' page has no Errors tab any more; its tabs are Modules, Templates and
  Developer Tools. The Templates tab is a slot, `settings:templates`, that ModCore Templates
  fills with its list of loaded templates.
- A slot row with `mcSlotGroups=1` (menu data `slotGroups=true`) lets inserted rows keep their
  source groups: each becomes a group of the host page with its own heading, shown under the
  slot group's rule.
- Menu data fields can be slots: `slot=<name>` (and `slotLabel=true`) on a read-only field
  with choices compiles to `mcSlot`/`mcSlotLabel`, so a menu-data page can host other
  contributors' rows.
- Read-only rows can be mirrored into a slot. They stay shown values with no storage and never
  dirty the page. Navigation and link rows still cannot.
- ModCore Settings' Modules tab reserves two slots after Listing, `settings:extensions` and
  `settings:verifications`, which UE4SS Lua Extensions fills with its installed count and a
  startup verification switch per extension.
- A picker choice's note is 1 point smaller (10), and while it shows, the note and the value
  sit 4 pixels higher than before. An arrow picker showing no note has its indicator
  2 pixels higher.
- Pickers with arrows show how many choices they have and which is current: a row of pips
  under the value (a track with a thumb beyond 16 choices), in the row's bottom pixels below
  any choice note. It is at half strength until its row is hovered or selected. While its row
  is hovered or selected, the current pip (or the thumb) is 2 pixels taller than the others,
  centred on the same line.
- At a picker's first or last choice the arrow that has nowhere to go stays visible at 50%
  instead of disappearing. A disabled picker still hides both.
- In grouped mod lists, mod names are 2 points smaller (12, the "and N more" entry 10) and each
  grid cell or row is 3 pixels shorter above and below. Each group after the first starts 10
  pixels further down, and hovering a group heading no longer highlights it.
- Page tabs (top right): every separator line stays thin and dim, the selected tab's too. The
  selected tab glows behind its label and under it, with a 4-pixel soft band 1 pixel lower and a 1-pixel line 3 pixels below the tab, a hovered tab's background lights up, and
  the other tabs' labels are dimmed 20%. When the tab row has focus, DMM's focus highlight
  shows on the selected tab instead of across the whole title row.
- A hidden page attached to a mod now also hides that mod's own entry when the mod has
  settings of its own, not only a detected placeholder without settings. A contributor can
  therefore replace several mods' entries with one page. The entry returns when the
  contributor withdraws or does not load.
- `mcText` rows and the UE4SS.log reader are removed with the Errors tab.

## v1.1.0

- A key row's `DefaultControl` keys come from `Scripts/vendor/standard_keys.lua`, which
  mods vendor to bind the same keys. Like ModCore Controls, it prefers the game's own
  action over a same-named one elsewhere and shows nothing when that is ambiguous, and it
  reads profile entries naming the action and its mapping name together.
- Field-type editors such as the key editor are read on each menu frame only while
  their row is shown.
- Contributed pages can describe their settings as `menu` data (groups, fields with
  choices or a range, visibility and label rules, storage) instead of a DMM
  manifest; ModCoreSettings builds the page. Descriptor contract 4, client
  version 6. Page hooks may return `menu(context)` in place of `manifest(context)`,
  and get `context.moduleName(folder)`.
- A contributed page that takes the place of a mod's entry shows that mod's name,
  author, version and icon from its `mod.json`. A mod whose `mod.json` puts it in
  the `ModCore` group is listed on the Modules tab without declaring
  `group='module'`. `mod.json` `icon` is shown for detected mods too.
- `mcLabel=<text>` names a category heading in place of its category name.
- The mod browser has no ModCore special case. ModCore's modules group through
  their `mod.json` (`"preferred": "ModCore"`) like any other mod.
  Top categories come first, then collections. Within a group, mods walk by
  category then load order, and mods without settings fold into a final
  "… and X more with no settings" entry.
- Group headers show the icon in a box of their own, a small line naming the group
  (top category, Collection or Author) and the title, with a rule that fills the
  rest of the width.
- The ModCore page is gone. Its Errors and Developer Tools tabs are on ModCore
  Settings' own page. The Installed, Highlighted Modules and Core Functionality tabs
  are gone, with their settings.
- ModCore Settings' own page is contributed menu data (`Scripts/mcs_page.lua`), like
  every other ModCore page, and takes its name and icon from `mod.json`. The mod no
  longer ships a `mod_settings.ini`. Its Modules tab settings keep their
  `config.ini` keys.
- Group modules is now Sort by: Recently Added, Categories, Alphabetical or Load Order
  (numbered). The mod list's Filter Mods button (Backspace) is now Sort by and cycles
  them. Inside every group, mods follow load order (Recently added: newest
  first), those with settings first. Recently added lists mods newest first by when each was installed or last
  updated, as MCS saw its folder's top level (`cache/folder_info.json`, which also lists each folder's top-level files).
- Modules per row (1, 2 or 3; default 2) sets how many mods each group shows per row
  in the Categories and Recently Added views. Mod names are left-aligned in every layout.
  Grid cells are 7 px shorter, and a group's "and N more with no settings" entry
  (no leading ellipsis) takes a grid place like a mod.
- Sort by is saved as `[Modules] SortBy`; `GroupModules` is no longer read.
- Declared categories follow taxonomy v3: the first three main categories in
  declaration order are kept and the rest are named in a warning; `niche` or `other`
  beside another category rejects the declaration; `ambiguous` is the classifier's
  alone. Top category icons come from the taxonomy data.
- Mod folders are listed whatever their names hold; only `.bak` copies are skipped.
- The browser reads each mod's `mod.json` as JSON, once per session.
- Missing config keys are still added with their defaults; the unused migration
  rules (`DefaultFrom`, `DefaultFromMap`, `ValueMap`, `DefaultRule`) are removed.
- Lighter on an open menu: dirty labels are checked every 250 ms once a page is
  quiet (50 ms while it changes), a page's default-key lookups share one scan per
  second and stop when the game has no mapping, the player check is kept for a
  second, Apply and Sort by keep at most one previous browser page, and controller
  input no longer polls tab hover. The Errors tab first reads the last 256 KiB of
  `UE4SS.log` instead of 1 MiB.
- The cache folder is created without starting a shell when it already exists.
- A Sort by button that fails to move puts its label back and is reported once.
- With UE4SSLuaFileBridge installed (optional), Recently added uses each mod's real
  install date and MCS's cache files are written atomically. Without it, nothing changes.
- After any page's changes are applied, the mod browser is rebuilt when you return to
  it, as if the menu had been closed and opened again.
- A level-one setting takes the page title row on every page, and never shows a
  dirty star there; ModCoreSettings no longer treats ModCore Templates pages
  differently.
- Module browsing uses Gameplay, Content, Presentation, Technical & Support and
  Other sections, with up to three declared categories, separate tags and inferred
  parents. The MCS-owned file index replaces category shared variables; legacy
  caches are reclassified without category aliases.
- MCS identifies installed UE4SS mod folders at startup, caches their categories in
  `cache/modules_register.json`, and supplies category grouping to the browser.
  Identification errors leave the settings integration available.
- `mcTable=<code>:<text>|...` with `mcColumns=1..6` shows static code and text
  pairs in level, aligned columns, each part centred in an evenly padded cell;
  `menu_contributions.textTable` checks them offline.
- The ModCore page has Modules | Errors | Developer Tools tabs. Errors shows the
  latest error lines of `UE4SS.log` in a scrollable area, newest at the bottom.
- `mcText=<source>` shows a host text source in a scrollable area.
- `mcSilent=1` keeps DMM's interface sounds off a row or category.
- `mcDimValues=<value>|...` fades a picker's row while its value is one of those listed.
- `mcPlayerExists=1|0` shows a row or category only while a player is, or is not,
  in the world, alongside its `VisibleWhen`.
- Page hooks may add `action(context,id,value,values)`, run when a navigation row
  is set; a one-label navigation tab row is a single button that runs it.
- ModCore Dev Tools is listed under Foundation Modules; Lua Event Bridge stays last.
- Tabs keep at least 3 pixels between their label and each edge; a longer label
  widens its own tab. Page headers leave 12 pixels before the first entry.
- A read-only tab row whose choices share one label (such as No settings) is
  sized and placed like an Open link.

## v1.0.1

- `mcChoiceNotes` gives picker choices a small muted second line under the
  current choice, such as the module providing a template. It is copied onto
  slot rows.
- Keybind rows sharing `mcConflictScope` that bind the same key and trigger
  show a dim red key background on every edit; the navigation picker separating
  the two rows shows its choice and arrows in red. Apply is unchanged.
- Unapplied changes show as a `*` after the page title instead of the
  "Unapplied changes" status text. Errors and failed Applies still show as text.
- The dirty `*` follows each label's text, so it no longer overlaps unindented
  labels such as `mcCategory` rows. Keybind rows now show it when edited.
- The page status sits beside header tabs under the divider instead of below them.
- A hooks page whose `load()` returns a value the setting cannot hold keeps the
  default and logs `HOOK_VALUES_SKIPPED`, instead of breaking the page.
- A crash during config initialization no longer blocks the page: the next open
  restores a moved-aside original and removes redundant leftover files.
- A failure loading the DMM hooks is logged as `DMM_HOOKS_FAILED` with its cause
  instead of asking for a restart; fatal integration events log at ERROR.
- An unresolved default control is retried while its keybind row is open, and
  X and Mode act only when released over the button.
- Manifests are read by one shared reader that matches DMM, including comment
  lines in navigation metadata. The undocumented raw `mcHeader` key is ignored.
- Release packages include `enabled.txt`, so the mod is enabled when installed.
- `mcType=tab` choices are outlined and sit 4 pixels apart; the selected choice's
  outline is bright.
- A page-link row (`mcNavigation=1`, `mcLinkPage`, `mcType=tab`) wraps a long label
  within its column and grows to fit, keeping the link button right-aligned and
  vertically centred; a one-line label keeps the 40-pixel row.
- `mcWrap=1` shows a read-only value as 13pt text in a wider column, broken after
  commas below 34 characters, in a row that grows to fit.
- `mcType=cycle` shows a picker as one 13pt button with only the current choice,
  in the keybind editor's key column at the key box's width; a click moves to the
  next choice.
- The keybind editor reads Mode, key, X. A bound key is 16pt in the active tab
  yellow, in a box at full strength; Mode and X backgrounds are at 30% of a
  standard control's, 8 pixels from the key. Unbound with a default control, the
  key box shows a small gray "default" (9pt) at its top and the default keys
  (11pt, dimmed white) flush with its bottom, at half strength, replacing
  the `Default: <keys>` caption. A default control that
  cannot be resolved yet is looked up again on the next render instead of never.
  Mode is 66 pixels wide with a background 20% stronger than X's. X rests at 70%
  and lights up in the active tab yellow under the pointer. The "optional"
  placeholder is 14pt.
- Keybind rows name the mouse buttons Left, Right and Middle Button, and numpad
  digits NumPad 0 to NumPad 9. Saved values keep the engine key names.
- A keybind's default trigger is the first one listed in `Triggers`, instead of
  Tap whenever Tap is listed.
- Keybind and other field-editor rows indent like toggle rows. Their labels were
  indented twice, once on the row content and again on the label.
- Log at levels TRACE, DEBUG, INFO, WARN, ERROR and CRITICAL, writing WARN and above
  by default; `log_level.txt` in the mod folder sets the level. The vendorable
  `Scripts/mc_log.lua` provides the same logger to other mods. Row errors are now
  written as warnings; the startup notice is INFO.
- Add menu contributions: other mods publish generated pages as data through the
  vendorable `menu_contributions.lua` client instead of installing DMM extensions.
- Add `mcLinkPage` for navigation pickers that open another page; it replaces
  `mcLinkProvider`.
- Group module pages in the ModCore browser group only when they declare it.
- Remove tab-picker contours and inset all tab choices, including provider links,
  24 pixels from the right edge.
- Give every tab-style picker option a light one-pixel outline so adjacent choices remain visibly aligned.
- Rename the installed mod folder to `1_ModCore_Settings`.
- Remove the slider-based keybind (`mcType=keybind` on an integer setting, with
  `mcOptional`, `mcDefaultControl`, `mcMode` and `mcGroupedBy`) and `Pair=` mode
  pickers, with their key capture, click routing and virtual-key table, and the
  example mod that used them. `Type=keybind` replaces them. Only `mcType=tab`
  remains as an `mcType`.
- Add setting types DMM does not know, starting with `Type=keybind`: one setting
  holding `none` or `<FKey>|<trigger>` as text, whose row carries the key box, the
  trigger control, the clear button and the default keys. DMM keeps building the
  row and owning Apply, Reset and dirty state; the editor reads and fills its own
  controls.
- Stop editing Dawnwalker Mod Menu's files. ModCoreSettings keeps DMM's
  `main.lua` as `main.dmm.lua` and starts it through a small launcher that hooks
  DMM's modules first, recreating the lifecycle events from outside DMM. DMM
  updates and redeploys are picked up automatically; a failed hook never stops DMM.
- Rename runtime markers, DMM lifecycle identifiers, and initialization file prefixes from `kem` to `mc`.
- Add 20 pixels of bottom spacing beneath the page header.
- Add slot rows: a page marks a read-only row with `mcSlot=<name>` and other
  contributors publish their own settings into it (`rows` in
  `menu_contributions.lua`, descriptor contract 2). Inserted rows stay owned,
  stored and applied by their source page.
- Add slot links: a contributed page with `link='<provider>:<slot>'` opens that
  slot's page with the slot showing.
- Show a hidden row-source page as an ordinary page when none of its rows has
  an available slot.
- Add `mcSlotLabel=1`: the first inserted row takes the slot row's label and
  level, so a host can present a contributed picker as a section heading.
- Add `mcCategory=1`: a setting stands in for its group's heading, in the heading's
  style, with the group's other rows indented beneath it. `mcSlotLabel=1` passes
  it to the first inserted slot row.
- Level-styled setting labels (`mcLevel`, `mcHeading`) show their size when first
  drawn; they kept the stock size until another change reapplied the font.
- `mcLinkPage` also takes a slot address (`<provider>:<slot>`): the link opens the
  slot's host page with the slot showing.
- Inserted slot rows keep their label rule (`mcLabelWhen`/`mcLabels`) when it names
  a row the same contributor inserted earlier, so conditional labels work in slots.
- Enlarge level-two setting labels, including Control Layout and Control Map,
  and inset submodule browser highlights with their rows.
- Bind queued picker presses to the preceding hovered control sample and discard
  them when another control is hovered at delivery, avoiding cross-control clicks
  without adding native widget access to the input callback.
- Dim unbound key labels and add `mcOptional=1` key rows with a click-to-clear
  `optional [x]` control.
- Expand key capture to the standard virtual-key keyboard, keypad, punctuation,
  browser, media, and mouse-button set while keeping Escape reserved for cancellation.
- Show a header picker's choices as tabs hanging from the title divider; the
  selected tab has bright separators and a faint glow.
- Add page hooks: a contributed page may name a Lua file that generates its
  manifest on every menu build and optionally owns its storage (`load` and
  `apply`), so no mod needs its own DMM extension (descriptor contract 3).
- A row whose identity is missing, mismatched, duplicated or from another page,
  whose key decoration fails, or whose paired or grouping row has one of these
  problems shows only its label and a short error. The page's other rows still
  work; previously one such row left the whole page undecorated.
- An unbound optional key shows `optional` in italics, dim yellow when it has an
  `mcDefaultControl` and dim gray otherwise; the `Optional` marker is gone.
  With a default control, `Default: <keys>` shows beside it: every keyboard key
  bound to the action in the Settings key profile, so they show in menus and
  outside combat too. With no keyboard key bound, nothing shows beside it.
- Move the README and changelog into `docs/`; release packages publish every
  document from `docs/` at the mod root.

## v0.3.1

- Refine preset dirty-state handling, grouped presentation, and missing-default initialization.
- Consolidate developer documentation and extract release notes from this changelog.

- Use the ModCoreSettings identity and `_ModCore_Settings` installation folder.
- Read `mc*` presentation metadata; legacy decoration aliases are no longer supported.

## v0.3.0

- Rename the runtime and DMM extension to KEngineMenu (KEM), packaged under `_KEngineMenu`.
- Use `mc*` manifest metadata and `MC_` runtime markers without reading old `amm*` metadata or migrating old settings.
- Keep generated KEngineTemplates module-page title controls separate from its ordinary Templates page.

## v0.2.25

- Added native Controls-page grouping, including controller settings.
- Added provider menu levels, optional hidden headings, wider horizontal pickers, and paired key/mode controls.
- Made Tap/Hold a single toggle beside Key capture, with Default as a separate option and matching dark backgrounds, including when Default is selected.
- Added the bundled menu-fixes template under `Scripts/fixes.lua`.
- Improved key capture, hover feedback, row reconstruction, and setting updates through the DMM provider interface.

Offline Lua and Python checks and package validation passed. The new menu layout still needs live in-game acceptance.

## v0.2.24

- Align the 75-pixel paired Tap/Hold control beside its key field at the same height and match the key's active dark background; retain its hover and Default-dimmed states.

## v0.2.23

- Soften the shared Tap/Hold background while Default is selected, including its hover glow.

## v0.2.22

- Reduce the shared paired Tap/Hold control to half of its reserved 150-pixel mode column without changing key or Default placement.

## v0.2.21

- Render paired Tap/Hold modes in one full-width control that toggles on click; keep an optional Default mode in its separate reserved column.
- Preserve declared numeric mode values and standalone tab pickers.

## v0.2.20

- Move the bundled `menu.fixes` template to `Scripts/fixes.lua` for TE's module registration path, preserving its identity and enabled default.
- Use normal left alignment for ordinary Mod Menu entries; keep explicit provider indentation.
- Correct paired-row and fixes-template regression expectations without changing those runtime behaviors.

## v0.2.19

- Apply paired-picker hover glow to the hovered tab individually instead of across the full tab row.
- Enable the bundled Dawnwalker settings-page fixes template by default.

## v0.2.18

- Keep paired key fields and Tap/Hold tabs in fixed columns; render an optional third `-1` Default tab in a reserved left column.

## v0.2.17

- Remove the native empty-key prompt and reject empty key capture; use a paired `Default` mode to disable capture.

## v0.2.16

- Place three-option `Pair` tabs to the left of their key field when the third value is `-1`.
- Disable and dim key capture while that `-1` option is selected without disabling the picker.
- Restore paired-tab hover feedback, hide the native empty-key prompt, and shift ordinary Mod Menu entries left by 20 pixels.

## v0.2.15

- Keep `Pair` pickers in the original 150-pixel mode column beside their 96-pixel key control.
- Add a subtle background behind paired tabs so their shared control surface remains visible.
- Reduce active-menu selector and dirty-label refresh latency from 100 ms to 50 ms.

## v0.2.14

- Restore key controls in `Pair` rows after the setting-identity schema gained the `ammTabsWidth` field.
- Parse the paired target, tab width, values, and labels from their current schema positions.

## v0.2.13

- Make the picker that declares `Pair` own the composite row and its visible label.
- Render the paired key inside that picker only while DMM considers the key setting visible.
- Keep arbitrary picker values, including negative defaults, independent from positional tab navigation.

## v0.2.12

- Center each horizontal picker label within its allocated option slot.

## v0.2.11

- Rename the template directory from `template` to the shared `templates` convention.

## v0.2.10

- Add `ammTabsWidth` so generated horizontal pickers can reserve up to 440 pixels for their options.
- Keep existing tab widths unchanged unless a provider explicitly requests the wider layout.

## v0.2.9

- Rename every public decoration metadata key from the old `Deco...` form to the `amm...` prefix.
- Remove compatibility parsing for the old prefix so manifests have one concise schema.

## v0.2.8

- Let generated provider pages request a smaller Mod Menu browser font and a bounded left indentation.
- Preserve level-two, left-aligned styling for ordinary modules and aggregate pages.

## v0.2.7

- Move the Dawnwalker settings-page fixes out of AMM startup and into `templates/fixes.lua` under `menu.fixes`.
- Leave the template without event declarations or runtime hook registration.

## v0.2.6

- Bind native settings reconstruction through `DogwoodUI.SettingTabWidget`, whose inherited functions are hookable before the settings Blueprint is loaded.
- Track relocated controller-row selection through `RebelSettingEntryWidgetBase:SetSettingSelected` so the Controls page can display its native controller panel.
- Remove the rejected Blueprint-hook registration path that prevented the v0.2.5 controller transfer from running.

## v0.2.5

- Add a native `Controller Settings` category after the three mouse settings on the Controls page.
- Move Preset, Controller Sensitivity and Vibrations into that category using the game's own live setting descriptors and widget factory.
- Show the native controller preset panel on the right when a relocated controller setting is selected.
- Empty the former Controller page after a successful transfer and rebuild native navigation without polling or config-order assumptions.

## v0.2.4

- Add `ammHeading=0` for categories whose rows should remain visible without rendering their category heading.
- Render the mod-browser selector as a level-one page header with a themed divider, and align its level-two mod names to the same left edge.
- Add a native `Mouse Settings` category header above the first three entries on the Controls page.
- Construct native header text through Unreal's text library in UE4SS Lua states where the convenience `FText` global is unavailable.

## v0.2.0

- Capture left/right Shift, Control, Alt and Windows keys as distinct Windows virtual-key values while rejecting modifier chords.
- Remove the unused key-code support wrapper and obsolete row-state fields.
- Rename Mod Menu Decorator to Adaptive Mod Menu across the runtime, package, repository, documentation.
- Use the AdaptiveModMenu/AMM identity consistently across row metadata, DMM patch markers, configuration markers.
- Retire an enabled `ModMenuDecorator` installation during AMM bootstrap by deleting its `enabled.txt`, creating `deprecated.txt` containing `AdaptiveModMenu`, and attempting to unload it when UE4SS supports cross-mod unloading.
- Stage and verify every DMM replacement before moving the original modules to verified backups, and roll back the complete transaction if promotion fails.
- Remove unreleased legacy decoration aliases and row-marker formats; accept only the canonical AMM configuration and metadata contracts.
- Consolidate page retirement into the lifecycle close path and remove the redundant host-open event.
- Register the menu click callback lazily after DMM lifecycle installation succeeds.
- Restore ordinary provider configuration initialization through DMM's authoritative provider model.
- Recover interrupted DMM patch transactions from verified baselines and remove incomplete staging files.
- Keep failed Settings API handler registration from retaining a process-wide ownership claim.
- Leave `enabled.txt` under user or mod-manager control instead of including it in release archives.

## v0.1.52

- Fix DMM localization module loading in the standalone decorator state by
  passing only the rewritten path to `loadfile`. This restores localized dirty
  label matching without adding polling or UObject access during startup.

## v0.1.51

- Remove the process-wide `UTextBlock::SetText` hook implicated in crash AA40011448729B47EDFCB8846C95AF72.
- Observe dirty text only on bound DMM rows during the existing active-menu update; no dirty-label callback runs during gameplay.
- Add one `PAGE_TIMING` diagnostic per page build with discovery, localization, decoration, route and dirty-binding durations.
- Replace the native mapped-preset adapter with DMM extension API version 1 and ship a pure-Lua package with no DLL.

## v0.1.50

- Replace the unavailable `UButton:OnButtonClickedEvent` hook with one bounded left-mouse key callback.
- Deliver queued clicks to the hovered paired picker only from the existing menu-scoped game-thread update.
- Avoid sparse delegate access, repeated failed hook registrations and repeated pair-construction failures.
- Keep attribution of crash E880E96A4DB5418CA744558698206985 unresolved; its game-thread null dereference has a different signature from the earlier UE4SS delegate-reflection crashes.

## v0.1.49

- Remove reflected access to UButton's sparse multicast `OnClicked` property.
- Queue owned picker clicks through the hookable `UButton::OnButtonClickedEvent` function, retaining the same menu scope, receiver validation and teardown.
- Keep crash attribution unresolved: the supplied startup dump matches the delegate-reflection failure signature, while its log belongs to the following launch.

## v0.1.48

- Bind normal DMM page selections from the exact active provider `ScrollBox`, avoiding a full widget-tree traversal on first and repeated openings.
- Build refresh routes only for recognized setting and decoration controls; retain one bounded full-tree traversal for activation and unrelated-switcher recovery.
- Publish the versioned `settings_api.lua` consumer contract for event-driven notifications after successful durable Apply.

## v0.1.47

- Add reusable parent headings for related categories through `ammParent` and `ammParentLevel`.
- Keep subgroup ordering, navigation and page-ready rebinding intact beneath parent headings.
- Keep parent headings independent of picker values; providers control subgroup visibility through DMM's ordinary visibility metadata.

## v0.1.46

- Rebind decorators after a picker changes which settings rows are visible.
- Coalesce visibility and category-order changes into one deferred page-ready event.
- Reuse the active dirty-label hook across same-page rebinding instead of unregistering and registering it again.

## v0.1.45

- Bind decorations, paired Mode rows and dirty-label metadata directly by provider and setting IDs, independently of row or metadata order.
- Remove positional and label matching fallbacks; reject missing, duplicate or mixed-provider row identities.

## v0.1.44

- Attach provider and setting IDs to row-owned markers so grouped and repeated labels bind by identity.
- Align paired, fixed-mode and unpaired keybindings on the same grid, reserving blank mode space without creating controls.
- Remove per-option layout measurement when constructing mode controls.

## v0.1.43

- Add declarative numeric maps and ordered conditional source rules for migrating absent configuration keys from the original file.
- Preserve explicit destinations and original configuration bytes; validate migrated values before transactional replacement.
- Keep settings unavailable when a declared migration fails, preventing Apply from replacing legacy choices with defaults.

## v0.1.42

- Dim fixed Tap/Hold labels without disabling key capture; restore normal text contrast when the paired mode becomes editable.

## v0.1.41

- Skip dirty-label row discovery for MMD's own synchronous decoration text during page binding, preserving DMM value notifications and restoring handling after construction failures.

## v0.1.40

- Add ammMode=Tap|Hold as a fixed presentation fallback for key bindings without a logically visible paired mode.
- Follow DMM model visibility when switching between fixed labels and editable Tap/Hold controls, preserving saved modes and discarding stale clicks.
- Retain key capture, row ownership and existing menu-scoped updates without adding timers.

## v0.1.39

- Standardize metadata on ammType=tab|keybind, ammLevel=0–6 and the Deco prefix; retain legacy read compatibility.
- Add tab pickers, six font levels, a header toggle, category help, conditional labels and category ordering through metadata.
- Preserve row identity when categories move and use DMM's existing menu tick for new controls.
- Keep preset-derived keys visually clean after a manual edit; select Custom automatically and skip it during preset navigation.
- Support DefaultFrom for missing configuration values, preserving explicit values and validated legacy defaults.

## v0.1.38

- Reduce preset refresh overhead: validate the menu owner once per value callback, ignore unrelated text after binding, and skip unchanged label styling.

- Render dirty stars as separate row-owned widgets in the existing left gutter, keeping label text and position unchanged. Preserve italic styling and preset suppression.

## v0.1.37

- Display dirty settings with a left-hand star and italic label across recognized DMM sliders, pickers and toggles, replacing visible value-side stars.
- Restore original label styling when changes are applied or restored; combine key and Tap/Hold dirty presentation.
- Add panel-wide dirty-display suppression for MMD value changes, including deferred DMM refreshes, without changing Apply/Restore state.
- Expand MappedPresetTargets/MappedPresetValues synchronously in DMM's pending model; update visible keys and modes together and select Custom after a manual target edit.
- Hide preset-derived dirty indicators while preserving Apply/Restore state; reveal actual target differences when switching to Custom.
- Install the mapping adapter through UE4SS's native DMM startup callback, without editing DMM files or adding gameplay polling.

## v0.1.36

- Initialize provider INI files from metadata defaults at startup, with existing values taking precedence.
- Preserve existing configuration bytes and add missing assignments before DMM opens settings; validate with DMM and protect writes with transaction recovery.
- Include disabled direct providers and settings without decorations; add no gameplay polling.

## v0.1.35

- Reject release manifests that would place a Tools directory anywhere in the ZIP, regardless of capitalization.
- Cover nested, mixed-case and root-directory exclusions with packaging regression tests.
- Runtime behavior is unchanged from 0.1.34.

## v0.1.34

- Preserve accepted row input state before rendering, so a failed label update followed by reopening cannot overwrite Restore with an old key.
- Use a neutral capture baseline for unmapped backing values, allowing the previous key to be selected again while preserving cancellation.
- Recover failed key, mode and dirty-label writes; display unmapped values numerically.
- Report inactive DMM and invalid decoration metadata at startup; remove stale workspace notes and normalize changelog encoding.

## v0.1.33

- Include the updated developer README in the downloadable package, covering features, integration examples, known limitations and documentation links.
- Clarify that Mod Menu Decorator provides GUI upgrades and pairs with UE4SSLuaEventBridge for input behavior.
- Runtime behavior is unchanged from 0.1.32; only the version label changes.

## v0.1.32

Unreadable selected keys now count toward the existing three-failure limit, stopping updates to broken controls until the next page event. Successful reads reset consecutive failures. Deployment tooling never creates enabled.txt, including on fresh installs, and preserves existing enablement. Regression coverage verifies failure shutdown, recovery and enablement preservation. Native gameplay-impact verification remains pending.

## v0.1.31

Promote the rc.2 runtime fixes to stable. Runtime behavior is unchanged apart from the version label. Automated regression and packaging checks pass; native gameplay-impact verification remains pending.

## v0.1.31-rc.2

Fix construction failure paths: restore stock controls if initial binding bookkeeping fails; contain post-attachment receipt errors inside the transaction; restore row-owned picker metadata on rollback; and report incomplete rollback explicitly. Automated fault-injection regressions cover each case and ensure adoption failure does not dismantle existing rows. No polling, dependency or configuration changes. Native integration validation remains separate.

## v0.1.31-rc.1

Local testing release candidate including all completed work through 0.1.30: row-owned decoration state, event-driven construction, duplicate-ID handling and construction rollback improvements. Distinct RC startup/version identity; packaging validates RC suffixes. Native functional and gameplay-impact verification remain pending. No new runtime dependency or configuration migration.

## v0.1.30

Recover on the next valid page event after lifecycle callback errors. Traverse and update only the selected provider, retaining collapsed backing controls. Stop scheduling when every control is disabled. Preserve setting IDs and original construction/update errors, including the terminal disabled message. Coalesce page events and reuse discovery routes when adopting unchanged rows. Skip serialization for unchanged row state. Automated regression coverage includes each change; native gameplay impact verification remains pending.

## v0.1.29

Move persistent decoration state into a collapsed child of the decorated row. Adopt surviving controls from their subtree on page events; newly built rows decorate without any cached host/row flag. Keep WidgetTree ownership and row attachment for all created widgets. Remove periodic structural scans and discovery retries. DMM page-switch completion queues discovery after row construction; load recovery no longer depends on a specific activation callback. Construction rollback remains; periodic partial-decoration repair is removed. Native repeat-cycle validation pending.

## v0.1.28

Skip later duplicate Mod Id manifests in sorted path order, matching DMM. Duplicate settings can neither overwrite nor merge into the first provider, including when that provider has no decorations. Emit one startup diagnostic per skipped duplicate. Eight Lua suites and three package checks pass.

## v0.1.27

Recover an already-active menu owner when its reflected activation was missed. Event-triggered discovery queries only the two DMM owner classes; no live owner means no polling. In-game use was reported working for this version.

## v0.1.26

Fix post-construction route refresh when row replacement leaves the count unchanged. Remove stale diagnostic wrappers, unused press/reset/click-epoch state, suppressed discovery-log formatting and duplicate row references. Make binding state local to its host; reject missing FKey names and avoid owner searches for foreign switcher events. Refresh current documentation.

## v0.1.25

Gate polling on a fresh visible, active main/pause-menu owner. Retire removed-host and closed-session records; retain temporary Back-navigation state. Includes acknowledgement-wait removal. Eight Lua suites and three package checks pass; native integration pending.

## v0.1.24

Removed DMM acknowledgement polling, pending acknowledgement state, the 25-update timeout and its diagnostic. Key submission still writes the stock slider once. Normal slider synchronization and DMM dirty-label mirroring continue; DMM owns processing, Apply and persistence. Includes the 0.1.23 hidden/disabled-host guards.

Eight Lua syntax checks and eight regression suites pass, including stale DMM text, stock Restore/Reset synchronization without resubmission, cancellation and subsequent capture. Native interaction verification remains pending.

## v0.1.23

Adds visibility and enabled-state checks before host traversal or control updates. A host that remains activated and in the viewport but becomes hidden or disabled now invalidates the menu scope, clears pending clicks, and stops both scheduling chains. No new timer or hook is introduced. If no close event arrives, detection occurs on the next scheduled update; 100 ms is the nominal interval, not a latency guarantee.

Retains 0.1.22 queued native picker clicks and stock DMM ownership of pending/dirty/Apply state. Basic short-click, Apply and reopen persistence passed in the prior native run. This new guard is mock-tested; native shutdown and gameplay performance acceptance remain outstanding.

No debug mode is included. Native verification remains pending.

## v0.1.22

Replaces picker IsPressed sampling with queued native OnClicked delivery on MMD-owned proxy buttons. No polling frequency increase.

Each new proxy binds OnClicked to its own inherited no-argument ForceLayoutPrepass function. A temporary native-function hook checks the fresh callback receiver against registered primitive address/full-name and active host identity, then increments a Lua count. The existing game-thread update consumes that count once through the stock mode slider. This avoids entering DMM state mutation from the click callback and does not retain callback UObject wrappers.

The hook is installed only while a candidate menu scope is active. Close/load/dormancy clears pending counts and unregisters it. Native self-delegate bindings refer only to a live widget and an engine function; no pointer into a mod DLL or Lua function is bound to the delegate. Surviving widgets reuse their binding. Failed registration/attachment preserves or restores the stock mode row.

The installed UE4SS DLL has AddDelegate export and delegate GetBindings/Broadcast strings; official UE4SS docs specify multicast Add(target,FName). Actual event delivery and teardown on this native runtime remain a test gate. This candidate does not require or modify the Enhanced Input bridge. No unverified ABI offsets or synthetic UFunctions are used.

0.1.21 native results remain recorded separately: delayed provider opening, visible keys, key-only dirty/Apply/cancel passed; settings FPS observed about200–218 versus7–12 on0.1.20, not a controlled benchmark. Stock DMM Apply mouse-click reliability remains outside this patch.

Native testing remains pending.

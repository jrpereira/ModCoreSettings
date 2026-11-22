# ModCore Settings

ModCore Settings (MCS) adds keybind editors, navigation, presets and contributed
pages to Dawnwalker Mod Menu (DMM). Your mod defines settings; DMM manages pending
edits and Apply; your mod applies the saved values to gameplay.

## Features and benefits

- **Declare your menu:** add settings through metadata or generated pages; MCS
  handles their presentation inside DMM.
- **Edit keyboard and mouse bindings:** capture keys, choose Tap/Hold triggers,
  clear optional bindings and display inherited game controls. Your mod supplies
  text storage and input behavior.
- **Organize larger menus:** use tabs, cycling pickers, two-handle ranges,
  conditional rows, shared headings and navigation that does not change saved
  settings.
- **List choices from files:** a keyed picker can list its choices from a mod's
  own files, refreshed each time the menu opens; a choice may play a WAV file when
  selected.
- **Show a live preview:** a page can reserve a 16:9 preview in the side panel, which
  its provider (ModCore Templates for template pages) draws from the page's current
  values, applied or not.
- **Offer coordinated presets:** one choice updates several settings in DMM's
  pending model; individual edits can return the selection to Custom.
- **Share menu space:** contribute pages or insert settings into another mod's
  declared slot while retaining ownership of storage and Apply.
- **React to saved changes:** receive Apply notifications, numbers and text, after a
  successful save, without watching or polling configuration files.
- **Preserve configuration:** add missing numeric defaults while keeping existing
  choices and unrelated content.
- **Browse your mods:** the Modules page lists every installed mod, sorted by
  category, by when it was added, alphabetically or in load order, with collections.

## Choose the right module

| Module | Responsibility |
| --- | --- |
| ModCoreSettings (MCS) | Menu controls, pending edits and Apply |
| ModCoreControls (MCC) | Input bindings and quickslot actions |
| ModCoreTemplates (MCT) | Visual templates, settings and object lifecycle |

Start with the [developer guide](DEVELOPERS.md) to add a numeric setting and
receive Apply notifications. Keybinds need custom storage hooks; they cannot use
DMM's numeric INI writer directly.

## Requirements and installation

Use Dawnwalker, UE4SS with Lua 5.4, DMM 1.0.7.1 (the declared minimum) and the UE4SS Lua
Extensions' File Bridge and Sound Bridge, 1.1.0 or newer. Install and enable MCS under
`Mods/1_ModCore_Settings`. MCS still runs without the two bridges, with less: no file
dates for the mod browser or atomic config writes without the File Bridge, and no sound
when you pick a mod's own sound file without the Sound Bridge. It does not need the Event
Bridge.

MCS keeps DMM's `Scripts/main.lua` as `main.dmm.lua` and puts its own launcher in
its place, which starts MCS and then DMM. Restart the game after installing MCS while
DMM was already running, and after changing a mod's settings metadata. Reloading
UE4SS mods without restarting the game leaves MCS's menu integration off until the
next restart.

## Behavior and limits

- Numeric settings use ordinary DMM storage; keybind values are text such as
  `K|Tap` and need a page whose hooks save them.
- Navigation and read-only rows are omitted from persistence and Apply events.
- Apply notifications from a raw manifest page's DMM storage are numeric; menu-data and
  hooks pages also deliver text values (keys, ranges, keybinds).
- Key capture excludes modifier chords, Escape, wheel directions and gamepads.
- MCS builds on DMM's menu as it is; a DMM update that changes its layout may need an
  MCS update.

## The Modules page

Open **Mod Settings** to see the Modules page. With the UE4SS Lua Event Bridge installed,
returning to the game window after editing config files by hand reloads the settings of
every module that supports it. Its **Sort
by** button (DMM's Filter Mods, Backspace) cycles through four ways to list your mods, and
the ModCore Settings page's Settings tab sets the rest:

- **Categories:** mods are grouped under Gameplay, Content, Presentation, Auxiliary
  and Unclassified, from each mod's `mod.json` or MCS's own classification. Mods
  that share a collection, named in their `mod.json`, are listed together once
  enough of them are installed (Collections valid with # modules: No, 2 or 3).
  Modules appear in a single category lists a mod under one top category only.
- **Recently Added:** newest first, in sections from the last 24 hours to earlier.
- **Alphabetical** lists every mod by name; **Load Order** lists them in load order,
  numbered.
- **Modules per row** sets 1, 2 or 3 mods per row, in every sort.
- **Use Compact Style** (Off, Index or Everywhere) gives the mod menu the pause menu's
  look in a loaded game: the game blurred behind a dark panel down the left and the page
  drawn smaller, on the mod list only (Index) or on every page.
- Under **Previews**, **Play sound in previews** (Auto, On or Off; Auto plays a page's
  preview sounds only while the selected setting is about sound) and **Background in
  previews** (On, Blurred, Dimmed by default, or Off, a dim light blue screen) set the two buttons
  under a page's live preview, which save their clicks there too.

A module whose `mod.json` dependencies are not all loaded at a version they accept
carries a red ⚠ at the right of its row. Its details list each requirement after
Author: the version it needs and the one loaded, unmet ones first.

Mods without settings fold into a final "and N more" entry in each group.

The ModCore Settings page has five tabs and opens on **Settings**: **Settings** holds
ModCore Settings' own options below, **Controls** shows ModCore Controls' page (the
Quickslots templates, the key mappings and the behaviours), **Templates** shows ModCore
Templates' loaded templates by category, the active ones marked, **Extensions** shows the
UE4SS Lua Extensions' page (how many are installed, then each extension's settings), and
**Developer Tools** lists tool pages. ModCore Controls', ModCore Templates' and ModCore Lua
Extensions' entries in the mod list open their tabs.

## Logging

Logs appear in `UE4SS.log` at WARN and above. With the UE4SS Lua Log Bridge installed,
levels are set per mod and category in the bridge's `config.ini` (`[Levels]
ModCoreSettings=DEBUG`), and the global level on its Logs page.

## Documentation

- [Nexus description](https://github.com/jrpereira/ModCoreSettings/blob/main/docs/NEXUS.bb): condensed, paste-ready module description in BBCode.
- [Developer guide](DEVELOPERS.md): first setting, Apply and keybinds.
- [Integration reference](REFERENCE.md): metadata, pages, slots and the Modules page.
- [Changelog](CHANGELOG.md): version history.

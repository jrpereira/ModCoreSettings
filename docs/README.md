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
- **Organize larger menus:** use tabs, cycling pickers, conditional rows, shared
  headings and navigation that does not change saved settings.
- **Offer coordinated presets:** one choice updates several settings in DMM's
  pending model; individual edits can return the selection to Custom.
- **Share menu space:** contribute pages or insert settings into another mod's
  declared slot while retaining ownership of storage and Apply.
- **React to saved changes:** receive numeric Apply notifications after a
  successful save, without watching or polling configuration files.
- **Preserve configuration:** add missing numeric defaults while keeping existing
  choices and unrelated content.
- **Browse your mods:** the Modules page lists every installed mod, sorted by
  category, by when it was added, alphabetically or in load order, with collections
  and an Errors tab that gathers error lines from `UE4SS.log`.

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

Use Dawnwalker, UE4SS with Lua 5.4, and DMM 1.0.7.1 (the declared minimum).
Install and enable MCS under `Mods/1_ModCore_Settings`. MCS itself does not
require UE4SSLuaEventBridge.

MCS renames DMM's `Scripts/main.lua` to `main.dmm.lua` and installs a launcher
as `main.lua`. The launcher loads MCS inside DMM's Lua state, then runs DMM's
original entry point. If DMM already started, restart when
`DMM_RESTART_REQUIRED` is reported. Restart after metadata changes too. Reloading
UE4SS mods without restarting the game leaves MCS's menu integration off until the
next restart.

## Behavior and limits

- Numeric settings use ordinary DMM storage; keybind values are text such as
  `K|Tap` and need a page whose hooks save them.
- Navigation and read-only rows are omitted from persistence and Apply events.
- Apply notifications contain numeric values; consumers reload text bindings.
- Key capture excludes modifier chords, Escape, wheel directions and gamepads.
- MCS depends on DMM's widget layout; offline tests do not prove live UI compatibility.

## The Modules page

Open **Mod Settings** to see the Modules page. Its **Sort by** button (DMM's Filter
Mods, Backspace) cycles through four ways to list your mods, and the ModCore
Settings page sets the rest:

- **Categories:** mods are grouped under Gameplay, Content, Presentation, Auxiliary
  and Unclassified, from each mod's `mod.json` or MCS's own classification. Mods
  that share a collection, named in their `mod.json`, are listed together once
  enough of them are installed (Collections valid with # modules: No, 2 or 3).
  Modules appear in a single category lists a mod under one top category only.
- **Recently Added:** newest first, in sections from the last 24 hours to earlier.
- **Alphabetical** and **Load Order** (numbered) list one mod per line.
- **Modules per row** sets 1, 2 or 3 mods per row in Categories and Recently Added.

Mods without settings fold into a final "and N more" entry in each group. The
**Errors** tab shows the latest error lines from `UE4SS.log`; **Developer Tools**
lists tool pages.

## Logging

Logs appear in `UE4SS.log`. The default level is WARN. For more detail, put
`debug` in `Mods/1_ModCore_Settings/log_level.txt` and restart.

## Documentation

- [Nexus description](https://github.com/jrpereira/ModCoreSettings/blob/main/docs/NEXUS.bb): condensed, paste-ready module description in BBCode.
- [Developer guide](DEVELOPERS.md): first setting, Apply and keybinds.
- [Integration reference](REFERENCE.md): metadata, pages, slots and the Modules page.
- [Build guide](BUILD.md): offline tests and in-game checks.
- [Changelog](CHANGELOG.md): version history.

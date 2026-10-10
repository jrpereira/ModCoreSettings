# Module categories

MCS identifies installed UE4SS mod folders during startup and gives each one
categories from, in order: the categories its `mod.json` declares, its normalized
folder name in `data/folder_categories.lua`, or a purpose heuristic over its Lua files.
The index is rebuilt on every boot and published to `cache/modules_register.json`
for the DMM browser; nothing is cached between boots. Inspected files are read as
data and never executed. Category data does not use shared variables.

The offline classifier stages the shared taxonomy in
`work/classifier/taxonomy.json`. It generates `data/module_categories.lua` (C)
from that taxonomy and `data/folder_categories.lua` (M→C) from classified sample
folder names. Folder names are case-folded and normalized to alphanumeric
characters; conflicting labels for one normalized name are omitted. The M→C
data carries the taxonomy `version` and its own content `revision`. Classifier
research files stay outside the installed payload.

## Author declarations

Declare the listing fields at the top level of a mod folder's `mod.json`:

```json
{
  "author": "Example Author",
  "icon": "♞",
  "preferred": "author",
  "categories": ["gear", "layout"],
  "tags": ["fix"]
}
```

`"preferred": "author"` uses the declared author. Any other preferred value names
a custom group or a canonical category. Mod rows show no icon. `mod.json` is read
as JSON data only.

Select up to three top-level sections' worth of categories, in any combination.
Selecting both a parent and its child does not consume two slots. Parent
membership is derived; no primary category is needed. Tags are separate and do
not consume category slots. There are no aliases.

| Section | Categories (children) |
|---|---|
| Gameplay (`gameplay`) | `actions` (`combat`, `abilities`, `movement`); `progression` (`skills`, `levelling`, `access`, `research`); `systems` (`economy`, `survival`, `behaviour`, `services`, `stealth`, `social`) |
| Content (`content`) | `items` (`weapons`, `armour`, `gear`, `consumables`, `utility`, `collectibles`); `characters` (`bodies`, `faces`, `hair`, `eyes`, `cosmetics`, `clothing`, `creatures`); `world` (`locations`, `structures`, `quests`, `transport`) |
| Presentation (`presentation`) | `assets` (`models`, `textures`, `animations`, `effects`, `filters`); `interface` (`layout`, `style`, `features`, `camera`); `media` (`sounds`, `music`, `cues`, `voices`, `video`) |
| Auxiliary (`auxiliary`) | `development` (`libraries`, `frameworks`, `shared`); `tools`; `adjustment` (`engine`, `translations`, `performance`, `compatibility`, `replacement`) |
| Unclassified (`unclassified`) | `niche`; `ambiguous`; `other` |

Tags: `experimental`, `broad`, `adult`, `accessibility`, `cheat`, `fix`, `ai`.
An absent tag is not a verified negative.

## Identification and classification

For each active mod folder (one UE4SS starts: it holds `enabled.txt`) with
`Scripts/`, `dlls/` or a `mod.json`:

1. **Module:** categories declared in `mod.json`. Invalid ones are first passed
   through the taxonomy's optional `remap(C)` function, then dropped; the valid
   rest is used.
2. **Data:** the normalized folder name is looked up in
   `data/folder_categories.lua`.
3. **Auto:** the purpose heuristic scans the folder's Lua files. It is tentative
   and abstains to `other` when it finds no clue.

A step that leaves no valid category passes to the next. Problems such as an
unreadable `mod.json` are logged as `MODULE_IDENTIFICATION_SKIPPED` and never stop
startup. Shared-directory Pak installations are outside this folder scan.

## Index

`cache/modules_register.json` uses `schema_version: 2`, the taxonomy `version`,
and a `modules` object keyed by installed folder. Each entry records
`categories`, derived `parents`, `tags`, optional `preferred` and `icon`, its
`source` (`module`, `data` or `auto`) and `confidence`. Nothing is carried
over between boots; the file is rewritten only when its content changes, using a
temporary file followed by replacement. The DMM reader retains its
last valid snapshot if the index is temporarily absent or invalid. An index error
does not prevent the settings integration from loading.

## Browser behavior

MCS controls the index page, titled **Modules**. It lists MCS's modules: pages and
detected mods whose folder is an active module in the index, MCS's own page and the
developer tools. Disabled folders, their settings pages and packages outside `Mods/`
are not listed. There is no compatible-only filter; the title takes no input.

Every mod follows the same rules; ModCore's own modules group themselves through
their `mod.json` like any other mod.

- **Top categories** are listed in taxonomy order, each once it has a module. A
  module appears once per top category its categories belong to; placements reuse
  the same provider and settings.
- **Collections** follow, in the load order of their first module. A collection is
  a `preferred` name shared by at least Preferred Category valid with # modules
  distinct folders; `preferred: author` uses the declared author. A module in a
  valid collection is listed only there. A `preferred` value naming a category
  counts as that category declared first and forms no collection.
- **Within a group**, modules follow load order: UE4SS starts mod folders by name,
  so numbered folders (`0_` … `9_`) keep their sequence. Child pages stay with their parent. Modules with settings come first; the
  rest fold into a final "… and X more with no settings" entry, which lists them
  when selected.
- **Headers** show the group's icon in a box of its own, a small line naming the
  group (the top category, `Collection` or `Author`) and a title: the categories
  present, or the collection's name. Collections use ⁂.

Module totals, including the list's "N mods" count, and collection thresholds count
distinct folders, not placements, headings or settings pages. Mods without settings
are named without DMM's "No settings available" notice, dimmed to 50% (75% on hover,
70% when selected) without the full highlight; "… and N more" entries likewise sit at 50%
and 75% on hover. Group modules and Preferred Category valid with # modules are saved
in `config.ini` under `[Modules]`; No disables collections, and disabling module
grouping lists each page once.

`page:setCategoryFilter(ids, 'any'|'all')` and
`page:setTagFilter(ids, 'any'|'all')` filter independently. The two filters combine
with AND. These are browser
API methods; no additional filter controls or density thresholds are introduced.
Parent sections are not subdivided automatically.

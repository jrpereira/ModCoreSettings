# Module categories

Each time the game starts, MCS gives every installed UE4SS mod its categories, from the
first of these that has any: the categories its `mod.json` declares, MCS's list of known
mod folders, or a guess from the mod's Lua files. Nothing a mod ships is run to do so.

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

Declare main categories (the ids before the brackets below), categories, or both.
Each category counts as its main category, and selecting both a main category and
one of its categories does not consume two slots. Only the first three distinct
main categories, in declaration order, are kept; the rest are dropped and named in
a warning (`MODULE_IDENTIFICATION_SKIPPED`). An Unclassified main category
(`niche`, `other`) cannot be combined with any other: such a declaration is
rejected and the next step classifies the mod. `ambiguous` is set by the classifier
only; a mod cannot declare it. Parent membership is derived; no primary category is
needed. Tags are separate and do not consume category slots. There are no aliases.

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

For each active mod folder (one UE4SS starts: it holds `enabled.txt` or is
enabled in `Mods/mods.txt` as `Name : 1`) with
`Scripts/`, `dlls/` or a `mod.json`:

1. **Module:** categories declared in `mod.json`. Unknown ones are dropped; the
   valid rest is used, within the main-category rules above.
2. **Data:** the folder name, ignoring case and punctuation, is looked up in MCS's list
   of known mods.
3. **Auto:** a guess from the mod's Lua files. It is tentative and falls back to
   `other` when it finds no clue.

A step that leaves no valid category passes to the next. Problems such as an
unreadable `mod.json` are logged as `MODULE_IDENTIFICATION_SKIPPED` and never stop
startup. Shared-directory Pak installations are outside this folder scan.

## Browser behavior

MCS controls the index page, titled **Modules**. It lists every active mod, its
settings pages, and MCS's own page. Disabled folders, their settings pages and packages outside `Mods/`
are not listed. There is no compatible-only filter; the title takes no input.

Every mod follows the same rules; ModCore's own modules group themselves through
their `mod.json` like any other mod.

- **Top categories** are listed in taxonomy order, each once it has a module. A
  module appears once per top category its categories belong to, each time with the
  same settings.
- **Collections** follow, in the load order of their first module. A collection is
  a `preferred` name shared by at least Collections valid with # modules
  distinct folders; `preferred: author` uses the declared author. A module in a
  valid collection is listed only there. A `preferred` value naming a category
  counts as that category declared first and forms no collection.
- **Within a group**, modules follow load order, as UE4SS starts Lua mods: folders
  enabled in `mods.txt` first, in that file's order, then the rest by folder name,
  ignoring case (`ModA` comes before `Mod_X`). Numbered folders (`0_` … `9_`) keep
  their sequence. Mods with a native DLL start earlier, which the order does not show. Child pages stay with their parent. Modules with settings come first; the
  rest fold into a final "and X more with no settings" entry, which lists them
  when selected.
- **Headers** show the group's icon in a box of its own, a small line naming the
  group (the top category, `Collection` or `Author`) and a title: the categories
  present, or the collection's name. Collections use ⁂.

Module totals, including the list's "N mods" count, and collection thresholds count
distinct folders, not placements, headings or settings pages. Mods without settings
are named without DMM's "No settings available" notice and dimmed, as are "and N more"
entries.

ModCore Settings' Settings tab chooses the listing, saved in `config.ini` under
`[Modules]`:

- **Sort by** (`SortBy`): Categories (the default) groups as above; Recently
  Added lists mods by when they were installed or updated, newest first, in
  sections by age; Alphabetical lists every mod by name; Load Order lists
  them in load order, each with its number. The mod list's footer button (DMM's
  Filter Mods, Backspace) moves to the next way and saves it the same way.
- **Collections valid with # modules** (`PreferredCategoryMinimum`, No/2/3, with
  Categories): the folders a collection needs; No disables collections.
- **Modules appear in a single category** (`SingleCategory`, Off/On, with
  Categories): a mod whose categories span several top categories is listed only
  under the one holding most of them.
- **Modules per row** (`ModulesPerRow`, 1/2/3, default 2): the columns of every
  list's grid, in every sort.
Parent sections are not subdivided automatically.

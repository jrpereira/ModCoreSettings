# Build guide

## Requirements

Use Lua 5.4. MCS is Lua-only; no compilation is needed. Run commands from this
repository's root. Live integration requires the dependencies in the [README](README.md).

## Offline tests

Run every Lua suite from Bash:

```sh
for test in tests/*_test.lua; do
    lua5.4 "$test" || exit 1
done
```

Parser integration tests skip when `DMM_CHOICES_PATH` is unset. To include them,
set this variable before running the same loop:

```sh
export DMM_CHOICES_PATH="/path/to/DawnwalkerModMenu/Scripts/choices.lua"
```

Focused checks include `lua5.4 tests/settings_api_test.lua` for notifications
and `lua5.4 tests/page_hooks_test.lua` for custom storage.

## In-game checks

Restart after launcher installation or metadata changes. Check capture, Escape
cancellation, Apply, Restore, Reset, reopening and restart persistence. Check
slot navigation and the consuming mod's behavior separately.
Fixtures simulate the Unreal UI boundary; they do not establish native widget
behavior or compatibility with a different DMM layout.

## Module identification

`python3 work/classifier/build_catalog_data.py` generates the shared category tree
and normalized folder-to-category map from `work/classifier/taxonomy.json` and
the reviewed training records. Packaging regenerates these two data files
automatically; runtime classification does not compute fingerprints.

The `mod_registry_test.lua`, `module_patterns_test.lua` and `startup_test.lua`
suites cover normalized folder lookup, boot cache ownership, file index handoff
and failure isolation. See [Module categories](MODULE_CATEGORIES.md) for cache
and lookup behavior. Verify the first scan, cached restart and browser grouping in game.

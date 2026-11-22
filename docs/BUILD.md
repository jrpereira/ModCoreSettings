# Build guide

## Requirements

Use Lua 5.4. MCS is Lua-only; no compilation is needed. Run commands from this
repository's root. Live integration requires the dependencies in the [README](README.md).

## Offline tests

```sh
export DMM_CHOICES_PATH="/path/to/DawnwalkerModMenu/Scripts/choices.lua"
bash tools/run_lua_tests.sh
```

Some suites need Dawnwalker Mod Menu's own `Scripts/choices.lua`, which MCS cannot
redistribute; without `DMM_CHOICES_PATH` they are skipped, and the runner fails unless
`MCS_ALLOW_SKIP=1` is set.

## In-game checks

Restart after installing MCS or changing settings metadata. Check key capture, Escape
cancellation, Apply, Restore, Reset, reopening and restart persistence, slot navigation,
and the consuming mod's behavior. Offline tests do not show how pages look in game.

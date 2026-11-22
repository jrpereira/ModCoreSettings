[b]ModCore Settings[/b]

[center][b]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/b]
[size=4][b]Tested for The Blood of Dawnwalker 1.2[/b][/size]
[b]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/b][/center]

ModCore Settings (MCS) extends Dawnwalker Mod Menu (DMM) with richer controls and shared menu integration. Mod authors declare settings; DMM manages pending edits and Apply; the consuming mod implements their gameplay behavior.

[b]Features and benefits[/b]
[list]
[*]Keyboard and mouse keybind editors with Tap/Hold choices, optional clearing and inherited game-key display.
[*]Tabs, cycling pickers, two-handle ranges, conditional rows, shared headings and navigation that does not alter saved settings.
[*]Keyed pickers that list their choices from a mod's own files, refreshed each time the menu opens, optionally playing a WAV file as each choice is selected.
[*]Live previews: a page can reserve a 16:9 preview in the side panel, drawn by its provider from the page's current values, with Sound and Background buttons.
[*]Inner pages and page links: a link opens another page, optionally on one of its rows, and Back returns to the link.
[*]Mapped presets that update several pending settings together and recognize custom edits.
[*]Generated pages and shared menu slots, so related mods can present settings together while retaining their own storage.
[*]Apply notifications after successful saves, numbers and text, without configuration polling.
[*]Config reload: returning to the game window after editing config files by hand reloads every module that supports it (with the UE4SS Lua Event Bridge).
[*]Missing-default initialization that preserves existing choices and unrelated configuration.
[*]A Modules page that lists every installed mod by category, by when it was added, alphabetically or in load order, with collections and 1 to 3 mods per row. Modules whose declared requirements are missing or at the wrong version are marked, and their details list each requirement with the version loaded.
[*]One ModCore Settings page with Settings, Controls, Templates, Extensions and Developer Tools tabs, opened from the settings link on the mod list's title line: ModCore Controls', ModCore Templates' and the UE4SS Lua Extensions' settings appear in their own tabs, still saved by each module.
[*]An optional compact style that gives the mod menu the pause menu's look in a loaded game, on the mod list or on every page.
[/list]

[b]Requirements and installation[/b]

Requires The Blood of Dawnwalker, UE4SS with Lua 5.4 and Dawnwalker Mod Menu 1.0.7.1 or newer. Install and enable under Mods/1_ModCore_Settings. MCS installs a launcher in DMM's Scripts folder; restart if DMM has already loaded or after changing metadata. Also requires UE4SS Lua Extensions' File Bridge and Sound Bridge 1.1.0 or newer; without them MCS still runs, but without file dates and safe config writes, and without playing a mod's own sound files when you pick them. The Event Bridge 1.4.0 or newer is optional and enables the config reload.

Keybinds require storage hooks and input handling in the consuming mod. Modifier chords, Escape bindings, wheel directions and gamepad capture are unsupported.

[b]The ModCore modules[/b]

MCS provides menu integration; ModCore Controls handles quickslot input; ModCore Templates manages visual templates and object lifecycle.

[b]Documentation[/b]

[url=https://github.com/jrpereira/ModCoreSettings/blob/main/docs/README.md]Full README and installation details[/url]
[url=https://github.com/jrpereira/ModCoreSettings/blob/main/docs/DEVELOPERS.md]Developer guide[/url]
[url=https://github.com/jrpereira/ModCoreSettings/blob/main/docs/REFERENCE.md]Integration reference[/url]
[url=https://github.com/jrpereira/ModCoreSettings/blob/main/docs/CHANGELOG.md]Changelog[/url]

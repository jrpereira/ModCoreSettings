[b]ModCore Settings[/b]

ModCore Settings (MCS) extends Dawnwalker Mod Menu (DMM) with richer controls and shared menu integration. Mod authors declare settings; DMM manages pending edits and Apply; the consuming mod implements their gameplay behavior.

[b]Features and benefits[/b]
[list]
[*]Keyboard and mouse keybind editors with Tap/Hold choices, optional clearing and inherited game-key display.
[*]Tabs, cycling pickers, conditional rows, shared headings and navigation that does not alter saved settings.
[*]Mapped presets that update several pending settings together and recognize custom edits.
[*]Generated pages and shared menu slots, so related mods can present settings together while retaining their own storage.
[*]Numeric Apply notifications after successful saves, without configuration polling.
[*]Missing-default initialization that preserves existing choices and unrelated configuration.
[*]A Modules page that lists every installed mod by category, by when it was added, alphabetically or in load order, with collections and 1 to 3 mods per row.
[/list]

[b]Requirements and installation[/b]

Requires The Blood of Dawnwalker, UE4SS with Lua 5.4 and Dawnwalker Mod Menu 1.0.7.1 or newer. Install and enable under Mods/1_ModCore_Settings. MCS installs a launcher in DMM's Scripts folder; restart if DMM has already loaded or after changing metadata. MCS itself does not require UE4SSLuaEventBridge.

Keybinds require storage hooks and input handling in the consuming mod. Modifier chords, Escape bindings, wheel directions and gamepad capture are unsupported.

[b]The ModCore modules[/b]

MCS provides menu integration; ModCore Controls handles quickslot input; ModCore Templates manages visual templates and object lifecycle.

[b]Documentation[/b]

[url=https://github.com/jrpereira/ModCoreSettings/blob/main/docs/README.md]Full README and installation details[/url]
[url=https://github.com/jrpereira/ModCoreSettings/blob/main/docs/DEVELOPERS.md]Developer guide[/url]
[url=https://github.com/jrpereira/ModCoreSettings/blob/main/docs/REFERENCE.md]Integration reference[/url]
[url=https://github.com/jrpereira/ModCoreSettings/blob/main/docs/CHANGELOG.md]Changelog[/url]

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Forever** is a suite of World of Warcraft addons for the **WoW Forever** client (interface 16001, a Midnight/Mainline client with some `Camelot` Blizzard addons). There is no build step: each top-level addon folder *is* an addon, loaded by the game in its `.toc` order, and `scripts/link.sh "<game>/Interface/AddOns"` symlinks them into the game. README.md is the authoritative guide (the suite, each addon's modules, the `ns:NewModule` API, option fields, the "keep the addon light" rules); read it before adding or changing a module.

- **ForeverCore/**: the runtime (events, modules, saved variables, settings pages, slash commands), the suite's minimap button and Update Notice. Every other addon depends on it.
- **ForeverTweaks/**: quality-of-life modules (`/ft`), `ForeverTweaksAPI`. Its Chat and Tooltips modules adapt Forever++'s (MIT) so players have them without it; each stays idle while Forever++'s own is on (`OtherAddons.CoveredBy`).
- **ForeverCompendium/**: the creature/loot/quest journal (`/fc`), learned only from what the player sees. It does what Forever Bestiary (Arxie's addon, unlicensed: never copy its code) did: a journal built like Blizzard's Collections window (Mount Journal rows and display, Toy Box pages; Forever's side tabs: creatures by zone, items, trophies, badges; no quests page, `ns.ShowQuest` opens the quest log or the giver), export/import and backups (`Modules/Data/`: `Archive.lua` and the Bestiary Import; text from `Lib/Codec.lua`, merging through `Lib/BookMerge.lua`), quest and rare pins and creature areas on the map and minimap (through the core's `UI/MapPins.lua`, which Tweaks' Gathering Map shares; its world-map holder sits above frame level 2000, where Blizzard's map art and pins are), tooltip lines, Bestiary-style notifications (`Modules/Notifications/Banner.lua`: new creatures and what's learned of known ones, from the Recorder's `CREATURE_NEW`/`CREATURE_LEARNED` news), an import of Bestiary's saved data, sharing between players (`Lib/Transport.lua`: addon messages in `Codec.lua`'s table format, never `loadstring`) and badges. Journal pages register with `ns.Journal.AddPage`; quest titles always go through `Book.QuestName` (never a bare quest number).
- Planned: a recipe book and a pet journal, each a new member addon (README "Add a Forever addon").

## Commands

```sh
lua5.1 tests/run.lua              # all scenarios, each in a fresh Lua process
lua5.1 tests/run.lua suite        # one scenario (names: tests/run.lua GROUPS)
find . -name '*.lua' -not -path './.git/*' -print0 | xargs -0 luac5.1 -p   # syntax
grep -rnP '[^\x00-\x7F]' --include='*.lua' --include='*.toc' .            # must print nothing: ASCII only
desloppify scan --path .                                                  # CI fails below objective 100
```

CI (`.github/workflows/check.yml`) also checks that each addon's TOC lists every one of its `.lua` files (and every listed file exists) and that all TOCs share one `## Version`. In-game, a new file needs a full game restart; edits only need `/reload`.

## Architecture

- **One shared namespace, one per addon on top.** `ForeverCore/Core/Core.lua` makes the namespace and publishes it as the global `ForeverCore`. Each member addon's first file, `Part.lua`, calls `ForeverCore:NewMember(name, ns, info)` (`Core/Members.lua`), after which its own `ns` reads through to the core's: its files are written exactly like the core's (`local _, ns = ...`, `ns:NewModule`, `ns.L`). What a member sets on its `ns` stays its own; `ns.member` is its member object. Core code never reads member-set fields: it gets what it needs through `NewMember`'s info (`open`, `openLabel`, `categories`) or `ns:AddSettingsPage`. The only globals are `ForeverCore`, `ForeverTweaksAPI`, the saved variables and slash commands.
- **Core load order** (`ForeverCore.toc`): `Core/Core.lua` → `Core/Members.lua` → `Core/Module.lua` → `Locales/enUS.lua` → the rest of Core → `UI/` (Kit, Windows, Popups, EditMode, Widgets, List, MapPins, Bags) → `Changelog.lua` → `Settings/` → `Modules/Settings/` → `Core/Init.lua`. Members load after (the game loads dependencies first): `Part.lua` → `Locales/` → `Migrations.lua` → `Lib/` (the libraries several modules share, none a module) → `UI/` → modules. Each folder under a member's `Modules/` is one of its categories; a module's own helper files sit beside it.
- **All events/timers/hooks go through one shared frame in Core.lua** (module-side wrappers in `Core/Module.lua`), owned by a module, dispatched via `securecallfunction` so one failing handler can't stop others, automatically stopped when the module disables, and timed by `Core/Profiler.lua`. Modules must not create their own event frames or raw `C_Timer`/`hooksecurefunc` calls.
- **Saved variables (`Core/Store.lua`) are each member's**: `member.saved`/`member.charSaved` (e.g. `ForeverTweaksDB`/`ForeverTweaksCharDB`) hold `settings` (sparse over `defaults`) and `data` (table defaults, never cleared by Defaults); `Store.Init(member)` runs on that member's `ADDON_LOADED`. `ForeverCoreDB` holds the suite's own (`ns.db`: quiet, debug) and the core's modules. A layout change bumps the member's `layout` in its `Part.lua` and adds `ns:Migrate(version, fn(db, coreDB))` in its own migrations file (`ForeverTweaks/Migrations.lua`, `ForeverCompendium/Migrations.lua`); the `upgrade` scenario loads Tweaks 0.9.0-era data, `migrate` pre-suite data.
- **Settings UI**: the Forever window (`Settings/Window.lua`, a portrait frame listing its pages; Settings > AddOns > Forever is only a launcher page) shows `Settings/General.lua` (suite settings and every `category = "settings"` module), then one page per member (`Settings/ModulesPage.lua`, built from each module's `options`), member pages (`ns:AddSettingsPage`: Tweaks for Addons), About, Debug, Changelog. `/forever` and each member's slash (`Core/Commands.lua`) read the same option tables; a member's slash lists and helps with its own modules only.
- **Categories are per member** (`categories` in `Part.lua`; "other" and "settings" always added). Labels are `L.CATEGORY_<KEY>` in that member's `Locales/enUS.lua`.
- **Map pins** use `ns.MapPins.Both(mod, opts)` (both layers from one set of pins; `World`/`Minimap` for one alone) (`ForeverCore/UI/MapPins.lua`): the module gives specs per map, the layer keeps the frames as a module part.
- **Key bindings**: each addon's `Bindings.xml` calls `ForeverCore.RunBinding("<NAME>")`; the module registers what it does with `ns:AddBinding(owner, name, fn)` (`Core/Bindings.lua`); binding names and headers are `BINDING_*` globals in the addon's locale file. A binding that casts is a CLICK binding on a secure button.
- **Finding an item in the bags** (any member): `ns.Bags.Has(itemID)` / `ns.Bags.Find(mod, itemID)` (`ForeverCore/UI/Bags.lua`; Baganator or Blizzard's bags).
- **On-screen widgets** use `ns.Widgets.AddDisplay` (`ForeverCore/UI/Widgets.lua`), which plugs into the game's Edit Mode via `UI/EditMode.lua`.
- **`ForeverTweaks/API.lua`** exposes `ForeverTweaksAPI.v1`: read-only, returns copies, swallows errors to nil, and is append-only (never rename/remove).

## Conventions

- Every player-facing string lives in a `Locales/` file as `L.KEY`: the suite's in `ForeverCore/Locales/enUS.lua`, each member's in its own (`enUS.lua` for categories and pages, `enUS_Modules.lua` per module, Tweaks' `enUS_Shared.lua` for the modules Forever++/WilduTools/Plumber also have, `enUS_Tooltips.lua`, `enUS_Interface.lua` and `enUS_Quests.lua` for those categories' newer modules); tests fail on any missing string.
- **Secure buttons** (none at the moment) are set up, shown, hidden and moved only out of combat (`ns:AfterCombat`, or hide on `PLAYER_REGEN_DISABLED`); anything that must happen in combat is a restricted snippet. Don't anchor a protected frame to one of our ordinary frames. The test stand-in fails a run that touches a protected frame in combat.
- **Only use APIs that exist in Forever.** `docs/forever-api.md` lists what's confirmed present (and absent, e.g. `MouseIsOver`, `C_Console`) with sources; check there first, add anything newly verified, and don't write fallbacks for things Forever has. Its "Other references" section lists Wowpedia, Townlong-yak and the texture repo; those describe retail, so confirm against the `forever` sources. Under the test harness's strict mode, reading any global the stub (`tests/wow.lua`, `tests/stubs/`) doesn't define is a failure: add a stand-in (or a `W.OPTIONAL` entry if the addon intentionally probes for it), and new events to `W.EVENTS`.
- **Compendium's data** comes only from what the player sees (no QuestieDB/Questie/Bestiary code); everything learned goes through `ForeverCompendium/Lib/Book.lua`, and every game value passes `ns.Plain` (drops Midnight's secret values) before it's stored or compared. Never in chat, never touch Blizzard's quest tracker; sounds only through `ns.Sound` (`Lib/Sound.lua`), which the Journal's Sounds option turns off.
- Every release: bump `## Version` in **every** `.toc` (one suite version; `ns.version` is the core's) and add a newest-first entry to `ForeverCore/Changelog.lua` (members' `Changelog.lua` files are pre-suite history). New modules/options set `added = "<version>"` to get a NEW badge.
- Code adapted from Forever++ (MIT, see `LICENSE-ForeverPlusPlus.txt`) — keep the credit in README.

## Code health

`docs/code-health.md` has the suite's rules ("The suite") and those from two desloppify review rounds, plus the decisions that are deliberate (don't "fix" those). The ones most often broken:

- Use the shared helpers instead of hand-rolling them: `M:Soon(fn)` (redo once next frame), `M:IsPending`/`M:CancelTimer` (tickers), `M:HookCallback` (tooltip post calls, callback registries), `ns.ChargedCall` (call into a module without passing the owner), `BagButtons.RegisterWidget` (Baganator), `ns.QuestLog.Listen`, `ns:Announce` (news for `API.lua`), `M:OnNews`/`M:OnChanged` (a module hearing news or setting changes, only while on), `ns.Plain` (the only secret-value check: `issecretvalue` stays in Core.lua), `ns.MoneyText` (all money text). The `lint` scenario checks for unused header locals, `L` keys defined twice and stray `issecretvalue`. No `hooked`/`registered` flags, no probing `M.timers`.
- What an option value means lives only in `ForeverCore/Core/Options.lua` (`Parse`, `ParseNumber`, `ValueText`, `SliderText`, `Fits`).
- Don't `pcall` or nil-check APIs `docs/forever-api.md` lists as present; `pcall` only other addons' APIs and log their errors.
- Split big files by responsibility, not by trimming; update README/CLAUDE.md/file headers in the same change as a move.
- New test scenarios go in `GROUPS` in `tests/run.lua`; use `W.Advance` for delays; a bug fix gets a test that fails without it. In a test holding a member's `ns`, the core is `ForeverCore` (`ns.member` is the member's).

desloppify (`pip install "desloppify[full]==1.0"`, Python 3.11+): `desloppify scan --path .` then follow `desloppify next`; the agent workflow is in `.claude/skills/desloppify/SKILL.md`. The subjective review (`desloppify review`) launches about 20 reviewer agents, so run it after a large batch of changes, not every change.

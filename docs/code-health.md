# Code health

What two rounds of [desloppify](https://github.com/peteromallet/desloppify) review (2026-11-10/11)
found, the rules that came out of them, and the decisions that are deliberate. Read this before
refactoring; follow the rules when writing new code. CLAUDE.md has the short version.

## The two addons

Paths below are the runtime's (`Shared/Core/`, `Shared/UI/`) unless they name an addon's:
`Lib/OtherAddons.lua`, `Migrations.lua`, `Core/Plugin.lua`, `UI/BagButtons.lua`, `UI/ItemList.lua`,
`UI/Restyle.lua` and `Modules/` are Forever Gearbox'; `Lib/Book.lua`, `Settings/`, `UI/MapPins.lua`
and `Modules/Journal/` Forever Codex's.

- Each addon carries the runtime (`Shared/`) in its own namespace: edit the repository's
  `Shared/`, never an addon's copy, then `scripts/sync-shared.sh`. Runtime code never names an
  addon (`ns.name`, `ns.title`, `ns.member`) and never reads a field an addon sets on its
  namespace (`ns.Book`, `ns.Plugin`); an addon that needs to change what the runtime does replaces
  a documented hook (`Store.SettingsOf`, `ns:OpenSettings`, `ns:SetEnabled`, `ns:ResetAll` in
  Gearbox' `Core/Plugin.lua`).
- Every addon is laid out the same way: `Shared/`, `Part.lua`, `Locales/`, `Migrations.lua`,
  `Init.lua` at its root; `Lib/` for the libraries several of its modules share (none a module
  itself); `UI/` for shared on-screen pieces; `Modules/<Category>/` with one folder per category in
  its `Part.lua`, each module's helper files beside it.
- `ns.member` is the addon's one member; `ns.db` its own top-level settings.
- Forever Gearbox has no settings UI: its modules are Forever++'s (`Core/Plugin.lua`). A module
  option or notice Forever++ can't draw is translated there, never special-cased in a module; the
  `plugin` scenario registers every module against a stand-in that checks as Forever++ does.
  Forever++ owns on/off: nothing in Gearbox writes `db.enabled`.

## Rules to follow

These replaced hand-rolled copies that reviewers kept flagging. Using them keeps new code from
reintroducing the same findings.

**Modules (`Core/Module.lua`)**
- Redo something once on the next frame after a burst of events: `M:Soon(fn)`. Never probe
  `M.timers` yourself or keep a `refreshTimer` handle.
- A ticker you start and stop: `ticker = M:NewTicker(...)`, test it with `M:IsPending(ticker)`, stop
  it with `M:CancelTimer(ticker)`. Don't reset the handle in `OnDisable`; turning off cancels it.
- A hook the game has no `Hook`/`HookScript` for (tooltip post calls, callback registries such as
  `ScrollBox:RegisterCallback` or LibDBIcon): `M:HookCallback(target, key, install, fn)`. No
  `hooked`/`registered` booleans in module files.
- One handler per event per owner: registering another replaces it. Registering the same one
  again, or unregistering an event the module doesn't hear, does nothing: an event that follows an
  option is registered and unregistered in `OnSettingChanged`, with no flag of its own.
- If `OnEnable` errors, the module is turned off again (`SetActive`). Don't rely on half-enabled state.
- Event handlers are local functions passed to `RegisterEvent` (it asserts a function).

**Running callbacks (`Core/Core.lua`)**
- Three ways to call code safely, named for what they add: `ns.SafeCall(fn, ...)` only isolates
  errors (startup, before anything is profiled); `ns.ChargedCall(owner, source, fn, ...)` also
  charges the time to `owner` in the Profiler and calls `fn(...)`; `ns.ChargedHandler(owner, source,
  fn, ...)` does the same and passes the owner first, `fn(owner, ...)`, as every event handler, hook
  and timer gets it. (Renamed in 2.4.0 from `ns.Call`, `ns.RunCall` and `ns.Run`.) Anything calling into a module (Edit
  Mode, commands, notice buttons, Baganator, `OnInitialize`, `DebugLine`, widget clicks, tooltips
  and menu entries, `ItemList` callbacks via `opts.owner`, popup answers via `ns:Confirm(owner, ...)`
  / `ns:Prompt(owner, ...)`) goes through one of them, never a bare `ns.SafeCall` or `pcall`. Don't
  write a new "drop the owner" adapter: that is what `ns.ChargedCall` is for.
- To tell an error from a nil result, run `ns.ChargedCall(owner, source, ns.Succeeded, fn, ...)`: it
  answers `true, results` or nothing.
- Work for after combat: `ns:AfterCombat(owner, fn)`. Next-frame batching for code that isn't a
  module (the Settings pages): `ns:Soon(owner, fn)`; a module uses `M:Soon(fn)`.
- `ns.Profiler.Wrap` for OnUpdate scripts (it isolates errors whether or not it's recording).

**Options (`Core/Options.lua`)**
- What an option value means lives here only: `Options.Parse` (typed text, `/forever set`),
  `Options.ParseNumber` (the Settings box), `Options.SliderText` / `Options.ValueText` (display),
  `Options.Fits` (is it one of its values), `Options.FitSlider` (range and precision). The Settings
  controls and the commands call these; don't parse or format values anywhere else.
- `Options.Check` refuses at load a `requires` naming no checkbox (or looping), a `slider` pair that
  isn't a slider, a conflict naming no option, an unknown category, a dropdown default that isn't
  a choice, and a slider default out of range. A typo fails the tests, not a player.
- `notice.shown(db)` gets the module's settings, like `option.shown(db)`.
- `ns:SetOption` and friends assert the module name.

**Other seams**
- Module news for other addons: `ns:Announce(event, ...)` (Core/Core.lua). Modules never call
  into `API.lua`; it subscribes with `ns:OnNews`.
- A module hears news and setting changes with `M:OnNews(fn)` / `M:OnChanged(fn)`: like its
  events, they only reach it while it's on, so no handler checks `M.active` itself. The raw
  `ns:OnNews(owner, fn)` / `ns:OnChanged(owner, fn)` is for code that isn't a module (API.lua, the
  Settings pages) and for the rare module handler that must run while off (TooltipLines drops its
  cache), which says so in a comment.
- Baganator: `BagButtons.RegisterWidget(mod, opts)`. It registers once per id, answers true once
  Baganator accepted (false when Baganator is missing or refused, so a later call tries again),
  never shows the widget while the module is off, and runs our callbacks through `ns.ChargedCall`.
- The quest log: `ns.QuestLog` (Lib/QuestLog.lua). Call `QuestLog.Listen(mod, onChange)`
  from `OnEnable`; it owns clearing its cache.
- On-screen displays: give the anchor once, to `Widgets.DisplayDefaults(defaults, anchor)`;
  `Widgets.AddDisplay` finds it.
- Minimap buttons: `Widgets.MinimapButton(M, { angleKey = ..., icon, onClick, onEnter })`; its
  clicks, tooltip and drag run as the module's code, and the drag saves through `ns:StoreOption`.

**APIs**
- Don't `pcall` or nil-check anything `docs/forever-api.md` lists as present (`OpenAllBags`,
  `C_MerchantFrame`, `C_TooltipInfo`, ...). Call other addons' APIs (Auctionator, Baganator,
  LibDBIcon, QuestieDB, Forever++) only through `ns.OtherAddons.Call(owner, label, fn, ...)`, which
  pcalls and logs to the owner's `Debug`. Other addons' code calling into ours follows the same
  rule: the API's callbacks run through `OtherAddons.Call` (an error in them is theirs, logged,
  not reported as ours). What several modules ask of one addon is a function in
  `Lib/OtherAddons.lua` (Baganator's in `UI/BagButtons.lua`), not a lookup in each module.
- `PLAYER_REGEN_DISABLED` fires before `InCombatLockdown()` turns true: track combat from the event
  name.

**Chat**
- A module says something by itself with `M:Print(...)` (silent while its Chat Messages option is
  off or Mute All Chat Messages is on). It answers the player (a command, a button's result) with
  `M:Reply(...)`, always shown since they asked. Code that isn't a module prints with
  `ns:Print(...)` under its addon's name.

**Files**
- Split a file by responsibility when it grows past ~500 lines, never by trimming lines to get under
  a threshold. (Core.lua was trimmed twice and grew back before it was split into Core.lua and
  Module.lua.)
- `Modules/<Category>/` folders follow each module's `category`. A module file is named after its
  key (`FullBags.lua` for `FullBags`). What several modules ask of another addon
  (Auctionator's prices) is in `Lib/OtherAddons.lua`, not in one module's helper.
- A module split into files uses one of two shapes, and only these:
  - **A part** (loads after the module; most of them: `ItemPrices.lua`, `ProfessionObjects.lua`,
    `TooltipsFriends.lua`, `VendorButton.lua`): it gets its module with
    `local M = assert(ns.modules.X, "<file> loads after X.lua")` and joins it with `M:AddPart({
    Enable, Disable, Changed })`. What it needs from the module's file comes from one table that
    file names `ns.<Module>Shared`, captured as `local Shared = assert(ns.<Module>Shared, ...)`:
    functions and constants only, never state (each file keeps its own).
  - **A helper the module uses** (loads before it: `FullBagsPlan.lua`, `FishingState.lua`,
    `QuestMarkersRead.lua`): plain functions on `ns.<Name>`, captured by the module with an
    `assert`.
- A library several modules share lives in the addon's `Lib/` (Gearbox' `QuestLog.lua`,
  Codex's `Book.lua`); `Lib/` loads before every module, so it's captured bare. A table
  captured from another file under `Modules/` (Codex's `ns.JournalKit`, `ns.JournalText`,
  `ns.Journal`, by the journal's pages, the quest pins and the badges page) is captured with an
  `assert`, one per line, so a wrong TOC order fails loudly instead of indexing nil.
- Locale keys use a prefix unique to one module that isn't a category's name (`BUTTONBAG_`, not
  `BAG_`; `FULL_`, `MMB_` and `PERF_` are short but name one module each).
- Docs and comments follow a move in the same change (README layout, CLAUDE.md load order, file
  headers): stale pointers were the most common finding after each refactor.

**Tests**
- A new scenario file must be added to `GROUPS` in `tests/run.lua`; the run fails otherwise.
- Use `W.Advance(seconds)` to check delays; `W.RunTimers()` runs every pending timer at once.
- For a bug fix, write the regression test and check it fails without the fix.
- Find widgets by their label or text with `T.under(frame, test)` (tests/run.lua passes it to every
  scenario), not by position. Check a module's own timers by what they do (or by what the Profiler
  charges to it), not by counting every pending timer.

## Deliberate decisions (don't "fix" these)

Reviewers flagged each of these; each was checked and kept on purpose.

| What | Why |
|---|---|
| `LAYER_CHANGED` doesn't fire for the first layer read in a session | Public, append-only API; the layer scenario tests it; documented in the `API.lua` header (call `GetLayer` for the first). |
| `api.GetOption` returns a module's data tables (copied) | Public, append-only API; the header promises tables are copied and the api scenario reads `ButtonBag.ignored` through it. |
| Forever Codex's two "settings" modules are in `Modules/Settings/`, beside `Settings/` | Since the suite split the core's modules (Minimap Button, Update Notice) are its only ones, in its one category, `settings`; the folder follows the category like every member's. `Settings/` holds pages, `Modules/Settings/` modules. (Before the split they sat in Gearbox' Map/ and Interface/ folders.) |
| Both addons' release notes in `ForeverCodex/Changelog.lua` (Forever Gearbox has none of its own, and its pre-suite history is only in git) | One suite version, one list of releases (the Changelog page shows both). |
| Forever Gearbox' `UI/BagButtons.lua` in `UI/`, not `Modules/Bags/` | `UI/` is the home of on-screen pieces several modules share. |
| Helper files beside their module, no per-feature subfolders | A few helpers (FullBagsPlan.lua, VendorButton.lua, FishingState.lua, FishingZones.lua, DungeonJournalPages.lua, QuestMarkersRead.lua), each named for its module; subfolders add depth for no gain. |
| `ns:On(event, owner, fn)` vs `ns:After(owner, ...)` argument order | Key-first registrars (`On`, `Off`) vs owner-first ones (`After`, `OnChanged`, `OnNews`) is a consistent rule; reordering 36 call sites is churn. |
| Features other addons also have (Repair & Sell Junk, Durability Warning, Gathering Tracking; more to come) | Reverses 1.6.0's "remove what other addons do": Forever Gearbox should work for players with only it. Each such feature lists its `covers` and asks `OtherAddons.CoveredBy` when it acts, so it stays idle while Forever++/WilduTools/Plumber's own is on. Module names of removed modules (`Durability`, `CastBar`, `FiveSecondRule`, `RangeIndicator`, `ErrorMessages`, `NameplateQuests`, `GatherTracking`, ...) aren't reused: the `removed` scenario checks their old settings stay gone. Their successors' files are named after the new keys (`DurabilityWarning.lua`, `GatheringTracking.lua`). |
| The runtime in each addon (`ForeverGearbox/Shared/`, `ForeverCodex/Shared/`), copied from `Shared/` | The user wanted each addon on its own (3.0.0): no ForeverCore to install. One source of truth, copied by `scripts/sync-shared.sh`; the `lint` scenario and CI fail on a copy that differs; desloppify excludes the copies so they aren't counted as duplication. |
| Forever Gearbox' modules are Forever++ plugin modules, with Forever++'s three control kinds | Forever++ has no settings-page API; `RegisterModule` is its only way in (experimental in 1.6.x: a change there lands in `Core/Plugin.lua` only). What Forever++ can't draw is translated, not dropped silently: list panes open in windows, conflicts are notices. |
| Tracker never replaces anything of Blizzard's objective tracker: a `hooksecurefunc` after `LayoutBlock` setting alpha, and watch-list changes through `C_QuestLog` | Replacing its methods (BetterTracker's way, ours until 3.1.0) put addon code in the tracker's update, and under Midnight's secret values that tainted all of it: its scenario section failed reading auras. Zone headings, sorting, hidden objectives, scrolling and width can't be had without that, so they're gone (Forever++ sorts and filters by zone through the watch list). Never call its `MarkDirty`/`Update`. |
| Forever Gearbox draws into Forever++'s Settings page (`UI/ForeverPage.lua`): a raw `hooksecurefunc` on `Settings.RegisterCanvasLayoutCategory`, frames found by shape (`entries` stacks, the pane's `SetHeight`), rows added to Forever++'s own stacks | The user wanted Gearbox' additions on the Forever++ module they extend (Quest Tracker, Upgrade Arrows, Quest Nameplates, Fishing Cast), without changing Forever++'s files; its plugin API can only add modules. Nothing of Forever++'s is called or written but its stacks' `entries`; if its page changes shape, the section just doesn't show and the modules keep working (`Core/Attach.lua`, `/fg`). The hook isn't a module's (`M:Hook` is only live while a module is on). The `fpppage` scenario checks it on a stand-in of the page. |
| Quest Markers hides Forever++'s own mark on a Blizzard nameplate (alpha 0) where it draws its own | The user wanted Plumber/Platynator-style marks in Forever++'s Quest Nameplates; two marks on one plate would be worse. Its box is found by shape (a child of the UnitFrame with just `icon` and `text`), alpha is given back when ours goes, and Custom Nameplates Only leaves Blizzard's plates to Forever++. |
| No `added` on Forever++'s page | Forever++ compares `added` with its own version (1.6.x): a Gearbox version (3.0.0) reads as unreleased and the NEW label never goes. |
| desloppify ignores `orphaned::*` and `test_coverage::*` | The game loads every file from the `.toc`, so no file has "importers", and `tests/wow.lua` loads every file into all scenarios. Both detectors are wrong for a WoW addon. (Costs about 0.1 strict.) |

## Still open

- The fixes from review round 4 (58 issues) haven't been re-scored: the next blind review should
  raise the subjective scores. Round 4 scores: type safety 86, logic clarity 86, API coherence 87,
  authorization 87, high-level elegance 87; everything else 88-94.
- `luacheck` has never run: it isn't installed locally or in CI, so desloppify's lint detector was
  skipped. The `lint` scenario (tests/scenarios/core/lint.lua) covers the checks that mattered:
  unused header locals, locale keys defined twice, stray `issecretvalue`, and file headers.

## Score history

| | Strict | Objective (mechanical) |
|---|---|---|
| Start (after an earlier session) | 90.1 | 99.0 |
| Review round 1 (rescored, 67 issues) | 88.6 | 100 |
| Round 1 fixed, review round 2 (55 issues) | 89.7 | 100 |
| Round 2 fixed (50), not re-reviewed | 89.7 | 100 |
| Review round 3 (72 issues) | 90.1 | 100 |
| Round 3 fixed (72), review round 4 (59 issues) | 90.5 | 100 |
| Round 4 fixed (58, one false positive), not re-reviewed | 90.5 | 100 |

## Running desloppify

```sh
pip install "desloppify[full]==1.0"      # Python 3.11+
desloppify scan --path .                 # then follow: desloppify next
```

- Project settings are in `.desloppify/config.json` (committed: the ignore rules above). Everything
  else in `.desloppify/` is local state and isn't committed.
- CI runs the mechanical scan (`--profile ci`) and fails if the objective score drops below 100.
- The workflow guide for agents is `.claude/skills/desloppify/SKILL.md`. The subjective review
  (`desloppify review`) runs about 20 AI reviewer agents, one per dimension: worth it after a large
  batch of changes, not on every change. Fix what a review finds before reviewing again.

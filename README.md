# Forever

Addons for **WoW Forever** (interface 16001), as a suite: each is turned on or off in the game's
AddOns list, and they share one settings category, one minimap button and one set of slash
commands.

| Addon | What it is |
|---|---|
| **Forever Core** | Needed by the others: their settings (Settings → AddOns → Forever), `/forever`, the minimap button (click: the Compendium's journal, or Settings without it; right-click: Settings) and the Update Notice. |
| **Forever Tweaks** | Small quality-of-life tweaks, each a module you turn on or off. `/ft` |
| **Forever Compendium** | A journal of the creatures you meet, the quests and items you find, where they are on the map, and badges, learned as you play (and importable from Forever Bestiary). `/fc` |

Planned: a recipe book and a pet journal, each its own Forever addon.

Settings → AddOns → **Forever** is the suite's own page: the minimap button, the Update Notice,
Mute All Chat Messages, Show Log in Chat, resetting everything, and every slash command. Under it
each Forever addon that's on has its page of modules, then About, Debug and Changelog (every
release of the suite, then each addon's releases from before it).

## Install

Copy the `ForeverCore`, `ForeverTweaks` and `ForeverCompendium` folders into
`World of Warcraft\_forever_\Interface\AddOns\` and restart the game; turn off the ones you
don't want in the AddOns list (Forever Core stays on). Once the GitHub repository is public, an
addon manager such as WowUp can install the suite from the repository's URL and update it from its
releases; once it's on CurseForge, the CurseForge app (or WowUp's CurseForge source) can too.
Each addon saves its settings for the whole account (`ForeverCoreDB`, `ForeverTweaksDB`,
`ForeverCompendiumDB`) and what it keeps per character in its `...CharDB`. Settings from Forever
Tweaks 1.x and Forever Compendium 0.x carry over.

For development, `scripts/link.sh "<game>/Interface/AddOns"` links the three folders from this
repository into the game, replacing old links of the same name.

## Forever Tweaks

Small quality-of-life tweaks. Each tweak is a module you can turn on or off.

Open **Settings → AddOns → Forever → Tweaks**, or type `/ft`. Each Forever addon's page is laid out like Forever++'s and Plumber's control panels:

- On the left, every module under its category (Info & Display, Chat, Quests, Bags & Items, Merchant, Gathering, Map & Minimap), each with its on/off checkbox; each category shows how many of its modules are on.
- Click a module for its own page on the right: its title, what it does, then its options. Some modules add more there: the Autobuy list, Full Bags' kept items.
- A module that bundles several features (Quest Items) has a checkbox per feature on its page, and runs while any of them is ticked.
- Options have their checkbox in front of the label; sliders and dropdowns sit right of it. An option that needs another is indented under it and greyed while that's off.
- The search box narrows the list to the modules that match, by name, description or option, and highlights the matching options. The Defaults button resets the module shown.
- The position sliders have a box beside them where you can type an exact value. Press Enter to set it.
- A changed option shows an undo arrow.
- **NEW** marks modules and options that are new since you last looked.
- A gray notice row says when another addon you have installed needs a setting changed for a module to work its best (Forever++'s Fishing Cast, Baganator's icon corners), with a button where one can do it. A console variable a module needs is asked for the way Plumber asks ("You need to change these settings to make it work: - Set CVar name to value"), with a button that sets it. Each shows only while something needs doing. The Tweaks for Addons page has a section for each addon you have installed (and only those): Dungeon Journal's own options, and for Forever++, Baganator and the others every such setting, done or still to do.
- **Defaults** asks first, then puts everything back.

### Modules

Forever Tweaks works on its own. Where it does something Forever++, WilduTools or Plumber also do (every Chat and Tooltips module from Forever++, Repair & Sell Junk, Durability Warning, Gathering Tracking, Quest Nameplates, Object Names, Fishing Cast, Melee Range, Five-Second Rule, Combat Error Filter, Cast Bar, Gathering Map), it leaves the feature to them while theirs is on, and the module's page says so, so nothing happens twice.

| Module | Category | What it does |
|---|---|---|
| FPS & Latency | Info & Display | Your framerate and latency (Local, World or both), updated once a second. Hover it for details and the addons using the most CPU. |
| Chat Window | Chat | Chattynator's choices on Blizzard's chat window: Show Buttons (Always at full, On Hover, Never) with Faded Buttons and Hide Delay, Show Tabs (Always, On Hover, Never; a tab flashing for a new message stays) with Faded Tabs, Show Input Box (Always, On Hover, While Typing), Fade Messages after a time you pick, or Keep Messages so they never fade (Forever++'s Keep Chat Visible wins while it's on). Leaves Blizzard's fade constants alone, and does nothing while Chattynator is loaded. |
| Chat Arrow Keys | Chat | Up and Down bring back what you sent before, Left and Right move through the text, without holding Alt. |
| Chat Font | Chat | The chat windows (and, with Input Box, the box you type in) in another of the game's fonts; the size stays yours. Off by default. |
| Chat History | Chat | Each chat window's latest lines (25 to 125) come back after a reload or the next login, for each character; whispers and secret lines aren't kept. Off by default. |
| Chat Levels | Chat | A player's level before their name in chat, [60:Name], colored like a quest of that level; levels come from your group, guild, friends, /who and players you see, kept 60 days. Off by default. |
| Quest Links | Chat | Quests Questie players type in chat, [[34] A Grim Task (304)], become Blizzard quest links you can click. |
| Short Channel Names | Chat | [1. General] as [1], [G], [1. G] and other styles, in chat and in the chat box's header while you type; with Guild, Party & Raid also [GD], [P], [R]. Off by default. |
| Social Button | Chat | The Quick Join button moves from above the chat window into the column of chat buttons beside it. Off by default. |
| Click Timestamps | Chat | Click a chat line's timestamp (with Blizzard's timestamps on) to copy the line. Off by default. |
| Tooltips | Tooltips | Unit and item tooltips colored: borders and names by class (players) or reaction, item borders by quality, the guild (yours green), level, class and faction lines, a player's title, who the unit targets, and the friends list's tooltips. Also Anchor to Cursor, Hide Unit Tooltips in Combat, Hide Health Bar, and Quest Lines (hide them on units or objects). |
| Item Tooltips | Tooltips | Lines in item tooltips, each its own checkbox: the stack's sell price (Shift for one), repair cost, how many you own (bags and bank), what disenchanting gives (Shift: every outcome; learned from your own disenchants), stats in their colors, crafted gear compared on recipes, and the lowest auction price with its age, from scanning the auction house when you open it (`/ft scan`, `/ft resetprices`) or Auctionator's prices. |
| Profession Tooltips | Tooltips | The skill a herb, vein, skinnable beast, locked chest or lockbox needs, colored against yours like a trainer's recipes (red to gray); herbs and ore in your bags say what gathers them, skeleton keys what they open. Blizzard's own requirement lines are recolored and taught to it. |
| Layer Info | Info & Display | Which layer you're on, read from the NPCs you target, mouse over or see a nameplate of. It uses Nova World Buffs' layer number when that addon is installed. |
| Durability Warning | Info & Display | Warns once (on screen and in chat) when your most worn gear drops below the durability you pick, and again when something breaks; after a repair the next drop warns again. |
| Melee Range | Info & Display | "Too far" in red while your target is an enemy out of your melee reach (the game's own range check on a melee spell from your spellbook). Placed in Edit Mode; Only in Combat if you like. |
| Five-Second Rule | Info & Display | A spark runs along your mana bar for the five seconds after each spell that costs mana. |
| Combat Error Filter | Info & Display | Hides the red error spam of a fight, kind by kind (cooldowns, not enough rage/energy/mana, out of range, no target), in combat or always, never touching what the game hides itself. |
| Cast Bar | Info & Display | The cast timer inside the bar, a simpler look with the spell's name in the bar, and channel ticks. Size and place stay Edit Mode's. |
| Dungeon Journal | Tweaks for Addons | DungeonJournal in the look of Forever's own windows: a metal frame, Blizzard's search box, the Professions window's list art with the pet list's rows (a picked boss or quest framed in gold over a gold tint, the row under the mouse lit softly), the quest window's look on its quest page, a smaller Journey bar with room around it, Blizzard's colours in place of each dungeon's, and quality borders on loot icons. Each part has its own checkbox; turning the frame or panels off asks to reload. Does nothing without DungeonJournal. |
| Quest Items | Quests | Which quest a bag item is for: a quest mark on items a quest in your log needs, a mark on items that begin a quest, and a gray mark on quest items no quest needs any more, in Blizzard's bags and Baganator's. With QuestieDB installed it also knows the items quests need without naming them in an objective, such as a package to deliver. Full Bags uses it. (Questie's tooltips name the quest.) A leftover's tooltip says no quest needs it, the quest it was for and whether you turned that in (when QuestieDB knows), and whether to sell, keep or destroy it. |
| Quest Nameplates | Quests | A quest icon and what's left (3/8, or how many more) beside the nameplate of a creature one of your quests needs, a check once done, your group's progress added up or the lowest. Only what the game's own tooltip says about quests in your log. Left to Forever++ or Plumber while theirs is on. |
| Object Names | Quests | Under the game's icon over a chest, herb, ore or quest object near you, its name (yellow in reach, gray out of it) and the quest objective it counts for. Asks for the two game settings it needs. Left to Plumber's Soft Target Name while that's on. |
| Full Bags | Bags & Items | When you loot with full bags: a gold coin on loot worth more than something in your bags, and a numbered gold border on the bag items to delete for it, cheapest first, in Blizzard's bags or Baganator's. It can open your bags for you. Uses Auctionator's prices when it's installed. Useful kinds of items (consumables, reagents, tools, recipes), anything better than Common, quest items, items with no value, bound gear and gear in a set are never picked, by LootTriage's rules. Keep any item with Alt-click, `/ft keep` or the Kept Items list on its page. |
| Autobuy | Merchant | Buys the items on your Autobuy list at merchants until you have as many as you want: when a merchant opens (Ask First shows what and the total) or with the Restock button beside Sell All Junk. Alt-click an item at a merchant to add it; untick one on the list to pause it. The list shows how many you have. Items sold in stacks are never overbought, never more than you can pay. Shift skips it. |
| Repair & Sell Junk | Merchant | Repairs your gear (guild bank first, guild only, or your own money) and sells your gray items with the merchant's own Sell All Junk as you open a merchant. Hold Shift to skip. |
| Gathering Session | Gathering | A panel under the minimap once you gather: time, nodes, fish, items, what they're worth, per hour and skill-ups. Right-click it to pause or start again; `/ft session`. |
| Gathering Tracking | Gathering | Keeps Find Minerals or Find Herbs on after a loading screen or dying (never while casting, in combat or flying), and can swap between them every few seconds. |
| Gathering Map | Gathering | Remembers every herb, vein and chest you gather (for all your characters) and shows them on the world map and minimap: only spots you found yourself. Gathering one again counts it and moves its spot toward where you stood; Shift+right-click one on the world map to forget it. Left to Forever++'s Gathering Map while that's on. |
| Fishing | Gathering | With a fishing pole in hand, a line with your Fishing skill, the bonus from your gear, lure and food, the skill the zone's water needs (red while fish get away, yellow when only the coast needs more, green when enough) and your lure's time left. It warns when you fish without a lure while one is in your bags, once per zone when your skill is too low, and once when a lure is running out. Its Fishing Outfit (the game's equipment sets FT Fishing and FT Usual, with only the fishing pieces in the outfit) swaps on and off with `/ft outfit` or the line's right-click menu, and your usual weapons go on if combat starts with a pole in hand. Casting and lures are left to Forever++. `/ft fishing`. |
| Fishing Cast | Gathering | With a pole in hand, right-click twice on the world to cast Fishing (a right-click on the bobber still loots). Apply Lure puts a lure from your bags on a bare pole first; Louder Bobber turns the splash up while you fish; Combat Warning says when a fight starts with the pole in hand. Never armed in combat. Left to Forever++'s Fishing Cast / Auto Weapon Buff while those are on. |
| Button Bag | Map & Minimap | Gathers addons' minimap buttons, Forever Tweaks' own included, into one bag with its own button. Turning the module off puts every button back. |
| Minimap Button | Settings | The Forever Tweaks button, on the minimap, in the addon menu, or both. Click it for Settings. |
| Update Notice | Settings | Says in chat (and in the minimap button's tooltip) when a newer Forever Tweaks is out. Addons can't go online, so it learns of one from players in your guild or group who have it: each copy says its version on the addon channel. Share Your Version turns the telling off. |

**FPS & Latency and Layer Info** start just above the quest tracker, under the minimap. FPS & Latency sits left of center, Layer Info right of it, and both follow the tracker when you move it.

- **Move them in Edit Mode** (Esc → Edit Mode). Drag one to move it; it snaps to the screen's center and edges. Click it for a dialog with a size slider, and use the arrow keys to nudge it. Right-click it for Size and Reset Position.
- **Or use the options:** Horizontal Position, Vertical Position, Text Size and Outline.
- Outside Edit Mode they can't be dragged, so they never move by accident. Right-click one for its menu.

Under Forever Tweaks, the sidebar has five more pages:

- **Settings:** the addon's own settings: the Minimap Button (on or off, and where), Mute All Chat Messages (modules say nothing by themselves; replies to `/ft` commands still show), Show Log in Chat, Reset All Modules, and every slash command.
- **Tweaks for Addons:** what Forever Tweaks changes in your other addons (Dungeon Journal Skin), each with its own on/off checkbox and options, one under the other.
- **About:** the version, the game build, and how many features are on.
- **Debug:** Copy Debug Info and Reload UI. It also has a **Profiler**: press Start, play a while, then Copy Report. The report shows each module's time by event, hook and timer, and the slowest frames.
- **Changelog:** every release, with a search box and a By Module view.

### Commands

| Command | Does |
|---|---|
| `/ft` | Opens the Tweaks page. |
| `/ft <module>` | Opens the settings on that module, for example `/ft full bags`. |
| `/ft list` | Lists the modules and whether each is on. |
| `/ft options <module>` | Lists a module's options and their values. |
| `/ft toggle <module> [option]` | Turns a module, or one of its checkboxes, on or off. |
| `/ft set <module> <option> <value>` | Changes an option: `on`/`off`, a number, or a choice by name. For example, `/ft set performance latency local`. |
| `/ft reset` | Puts every module and option back to its default, after asking. |
| `/ft bag` | Opens the Button Bag. |
| `/ft autobuy` | Lists what Autobuy keeps stocked. |
| `/ft session [reset]` | Says what you've gathered this session; `reset` starts again. |
| `/ft fishing` | Says your Fishing skill, its bonus and your lure's time left. |
| `/ft outfit [save \| wear \| usual]` | Swaps your fishing outfit on and off; `save` saves the fishing pieces you wear as it; `wear` puts it on; `usual` puts your usual gear back. |
| `/ft help` | Lists the commands. |

`/forevertweaks` works too, and every subcommand also works after `/forever` (for every Forever addon's modules) and `/fc` (for Compendium's). Modules and options can be named by the start of their name or title, without spaces. All of these work in macros.

### For other addons

`ForeverTweaksAPI.v1` is read-only. It returns copies, and an error inside it returns nil rather than breaking your code. `API.lua` documents every call:

```lua
local api = ForeverTweaksAPI and ForeverTweaksAPI.v1
if api then
    local fps, localMs, worldMs = api.GetPerformance()
    api.RegisterCallback("LAYER_CHANGED", function(event, zoneUID, nwbLayer) end)
end
```

The callbacks are `READY`, `MODULE_TOGGLED`, `OPTION_CHANGED` and `LAYER_CHANGED`. `v1` only grows: nothing in it is renamed or removed. `GetErrorCount` is kept but always returns nil since the Error Catcher was removed in 1.6.0.

## Forever Compendium

Everything is learned as you play: no database is shipped and no other addon is needed. Quiet by
design: it never touches the quest tracker, says nothing in chat and plays no sounds. Open the
journal with `/fc` or a click on the minimap button; its settings are under Settings → AddOns →
Forever → Compendium. It does what Forever Bestiary did, from your own play.

| Module | Page | What it does |
| --- | --- | --- |
| Recorder | Journal | Learns each creature you target, mouse over or see the nameplate of (level, title, kind, looks, where you saw it, kills), what its corpses held (drop rates, money, items that start quests), how it fights (spells, resistances, your deaths to it, the reputation its kills give), what vendors sell, and where quests are given, turned in and done (titles, objectives, rewards, kinds, and which creatures you kill, loot or speak to for each). Five checkboxes: Creatures, Loot, Combat, Vendors, Quests. |
| Journal | Journal | The journal window (`/fc`, the minimap button, or a key bound under Key Bindings > AddOns), built like Blizzard's Collections window, with Forever's big icon tabs down its right edge: **Creatures** (Blizzard's journal rows with each creature's portrait, under a folding header per zone, pinned ones first with a gold star; search by name, loot or quest, several terms with `;`; filters by reaction, rank, kind, zone, pinned, wanted by a quest, noted, shared; sorts; right-click pins. The chosen creature as Forever Bestiary lays it out: its model on the Mount Journal's backdrop with Blizzard's turning buttons and its other looks, and beside it its portrait, name, title, kind and home over what's known of it (the quests in your log that want it, locations, abilities, resistances, best drops, encounters, kills, money, reputation); tabs below for Loot (drop chances, quality filter and sort), Wares, Rewards, Quests (with a legend of their icons) and your Notes), **Items** (every item: its own tooltip, item level, required level, sell price and how many you have, and who drops it with their portraits, levels, homes and chances, who sells it, the quests that give it or that it starts), **Trophies** (every boss, rare and elite met, by zone, defeated or not, with a progress bar per kind) and **Badges**, these on the Toy Box's page. Quests always show their titles; opening one shows it in the quest log, or on the creature that gives it. |
| Archive | Journal | The journal as text: export all of it or one creature (`/fc export`, or the gear menu at the top of the journal) and import an export back, counted and confirmed first, merged into yours without doubling counts (`/fc paste`). Backups of the whole journal, weekly by themselves (Automatic Backups) and when asked (`/fc backup`); the three latest are kept, and the gear menu puts one back. |
| Bestiary Import | Journal | Brings Forever Bestiary's creatures, quests, quest givers and turn-ins, objectives' places, notes and pins into the journal (while Forever Bestiary is enabled). `/fc import` or the button on its page; running it again counts nothing twice. |
| Quest Pins | Map & Minimap | Where your quests are, on the world map and the minimap, drawn the way Questie draws them: a yellow `!` where you were offered a quest you haven't taken or done (blue for a daily), a note where a creature dropped an item that starts one, a `?` where a quest in your log is turned in (grey until it's ready), and the objective mark where each objective still to do went up before. Quests at one spot share a pin; a continent's map shows its zones' pins; right-click opens the quest. |
| Rare Pins | Map & Minimap | The rare creatures you've met, at the spot on each map where you saw each most. Right-click one on the world map to open the journal on it. |
| Creature Areas | Map & Minimap | Where your pinned creatures, the creatures your quests want, and the one you clicked a location of in the journal live: soft patches in each one's colour on the world map and the minimap. |
| Tooltip Lines | Tooltips | On a creature's tooltip, how many you killed and looted, the abilities you've seen it use, and its quests (those in your log it counts for or takes in, those it offered you); on an item's, the creatures it dropped from and how often. |
| Sharing | Badges & Sharing | Sends a creature to your target from the journal (its places, loot, wares, abilities, quests; never your kills, deaths, money or notes) and asks before taking what others send; Group Sync (off by default) shares what you learn with your group. |
| Badges | Badges & Sharing | Badges with tiers I to VIII for creatures met, kills, loot, abilities, money, rares, elites, bosses, places, zones, quests, deaths and vendors; show three on your tooltip for the Compendium players in your group. |
| Notification Banner | Notifications | A banner in Blizzard's toast look when you meet a rare creature, defeat a rare or boss for the first time, or earn a badge tier, and if you tick them, any new creature, a new drop, or a quest's giver, turn-in or start item found. One after another, a few seconds each, no sound. Click it to open what it's about; move and size it in Edit Mode. |

## Layout

```
ForeverCore/                      the suite's runtime; every Forever addon depends on it
  Core/Core.lua                   the shared namespace (the ForeverCore global), locale, printing, the log, combat queue, events, module news, ns.Run and ns.RunCall
  Core/Members.lua                the member addons: ns:NewMember, each one's categories, saved variables, slash and pages
  Core/Module.lua                 ns:NewModule and the module object: events, hooks, timers, parts, on/off
  Locales/enUS.lua                the suite's own strings (settings pages, Edit Mode, commands) and its modules'
  Core/Store.lua                  each member's saved variables: settings, data, per-character data, how migrations run
  Core/Options.lua                what option values mean, turning modules on and off, setting options, change listeners
  Core/Profiler.lua, DebugReport.lua   the Debug page's CPU profiler and the debug report
  Core/Slash.lua, Commands.lua    slash commands: /forever and each member's, and their subcommands
  UI/                             Popups, EditMode, Widgets (minimap buttons, on-screen text), MapPins (pins on the world map and the minimap), Restyle (Blizzard's look for other addons' frames), List (a long list drawing only the rows in view), Kit (Settings page pieces and windows)
  Changelog.lua                   the suite's release notes
  Settings/                       the Forever (General.lua), About, Debug and Changelog pages; ModulesPage.lua (a member's module list and the selected module's pane), Modules.lua (registering every page), Section.lua (one module's section), Controls.lua (option controls)
  Modules/Settings/               Minimap Button, Update Notice
  Core/Init.lua                   startup (loads last; each member's saved variables load as it does)
ForeverTweaks/
  Part.lua                        joins the suite (first in its TOC)
  Locales/                        its strings: enUS.lua (categories, Tweaks for Addons, item list), enUS_Modules.lua, enUS_Shared.lua (the modules Forever++, WilduTools or Plumber also have)
  Core/Migrations.lua             its saved variables' layout steps
  Core/Chat.lua                   the chat windows, rewriting their lines, timestamps (the Chat modules)
  Core/TooltipKit.lua, ItemTooltip.lua, ItemStats.lua, Disenchant.lua, Professions.lua   what the Tooltips modules share: tooltip lines and colors, item tooltip line placement, stat lines, disenchanting rules, profession skills and nodes
  Core/OtherAddons.lua            what modules ask of other addons: loaded, Forever++'s modules on, features covered by Forever++/WilduTools/Plumber (CoveredBy, CoveredNotices), Auctionator's prices
  UI/BagButtons.lua, ItemList.lua marking bag item buttons (Blizzard's and Baganator's); an item list to edit on a module's page
  Settings/Addons.lua             the Tweaks for Addons page
  Changelog.lua                   its releases before the suite
  Modules/<Category>/<Name>.lua   one feature each, in the folder of its category (Interface, Chat, Tooltips, Quests, Bags, Merchant, Gathering, Map, Addons); a module's helper files sit beside it (FullBagsPlan.lua, VendorButton.lua, FishingState.lua, FishingOutfit.lua, FishingZones.lua, QuestNameplatesRead.lua, DungeonJournalPages.lua); QuestLog.lua, which Quest Items and Full Bags share, is in Quests/
  API.lua                         ForeverTweaksAPI
  Media/Icon.tga, Bag.tga         the addon and Button Bag icons
ForeverCompendium/
  Part.lua, Migrations.lua        joins the suite; its saved variables' layout steps
  Locales/                        its strings
  Changelog.lua                   its releases before the suite
  Bindings.xml                    the key binding that opens the journal
  Modules/Journal/                the Recorder and what it learns: Places.lua (map cells), Book.lua (the data and the only way to read it), RecorderLoot.lua, RecorderQuests.lua, RecorderCombat.lua, RecorderNpcs.lua, Recorder.lua;  the journal: JournalText.lua (wording and colours), JournalKit.lua and JournalLists.lua (its UI pieces, Blizzard's Collections ones), Journal.lua (the window and its tabs), CreatureFilter.lua, CreatureDetail.lua, CreatureOverview.lua, CreatureQuestTab.lua, CreatureTabs.lua, CreaturesPage.lua, ItemsPage.lua, TrophiesPage.lua
  Modules/Data/                   BookMerge.lua (taking in another book's creatures), Codec.lua (tables as text), the Bestiary Import (ImportCreatures.lua, ImportQuests.lua, Import.lua), the Archive (Archive.lua)
  Modules/Map/                    QuestPins.lua, RarePins.lua, CreatureAreas.lua
  Modules/Tooltips/               TooltipLines.lua
  Modules/Social/                 Transport.lua (addon messages: Codec.lua's table format, in pieces), Sharing.lua, Badges.lua, BadgesPage.lua (the journal's Badges tab)
  Modules/Notifications/          Banner.lua
docs/forever-api.md               what Forever has, with sources
docs/code-health.md               rules and deliberate decisions from the code reviews (read before refactoring)
scripts/link.sh                   links the addon folders into the game
tests/                            lua5.1 tests/run.lua; wow.lua and stubs/ are the stand-in game, scenarios/ the checks
```

## Add a module

1. Create `<Addon>/Modules/<Category>/MyFeature.lua` in the Forever addon it belongs to (its category is one of that addon's `categories` in its `Part.lua`).
2. Add it to that addon's `.toc` (in Forever Tweaks, above `API.lua`).
3. Put its text in that addon's `Locales/enUS_Modules.lua`.
4. Add a line to `ForeverCore/Changelog.lua`, and set `added = "<version>"` so it gets a NEW label.
5. Run `lua5.1 tests/run.lua`, then restart the game. A new file needs a restart; after edits, `/reload` is enough.

A module:

```lua
local M = ns:NewModule("MyFeature", {
    title = L.MY_TITLE,
    category = "interface",           -- interface, chat, quests, bags, merchant, gathering, map, addons (the
                                      -- Tweaks for Addons page), settings (the Settings page); others
                                      -- go under Other
    description = L.MY_DESC,
    added = "1.1.0",
    defaults = { enabled = true, size = 12, mode = "simple", history = {} },
    perCharacter = { history = true }, -- this table is kept per character
    options = {
        { key = "size", type = "slider", label = L.MY_SIZE, min = 8, max = 24, step = 1 },
        { key = "mode", type = "dropdown", label = L.MY_MODE, section = L.MY_LOOK,
          choices = { { "simple", L.MY_SIMPLE }, { "detailed", L.MY_DETAILED } } },
        ns.ChatOption(),              -- a Chat Messages checkbox, for a module that talks unprompted
    },
    notice = { text = L.MY_NOTICE, button = L.TURN_ON, shown = function(db) return not db.size end,
               fn = function() end },  -- shown(db) gets the module's settings, like option.shown
    -- features = { "a", "b" },      -- checkbox option keys that are each a feature: then the module
                                      -- has no on/off checkbox and runs while any is ticked
})

local function onTarget(self, event) self:Print("size", self.db.size) end

function M:OnEnable()  self:RegisterEvent("PLAYER_TARGET_CHANGED", onTarget) end
function M:OnDisable() end            -- its events, timers and hooks stop by themselves
function M:OnSettingChanged(key, value) end
function M:DebugLine() return "size " .. self.db.size end  -- optional: its line in /ft debug
```

Option fields:

- `key` is the saved setting; its default goes in `defaults`.
- `type` is `checkbox`, `slider` (`min`, `max`, `step`, `format`) or `dropdown` (`choices`). `input = true` adds a box to type an exact value in (for wide ranges where the number matters); `unit` sets the text after it (taken from `format` otherwise) and `precision` the decimals a typed value keeps (the step's by default).
- `label` and `tooltip` are the text; `section` starts a header.
- `requires = "key"` indents the option under a checkbox and greys it out while that checkbox is off.
- `shown = function(db)` hides the option when it returns false.
- `group = { label, format, tooltip }` on checkboxes: every checkbox with the same group table is drawn as one row, a dropdown that ticks each, its button counting the ticked ones with `format` ("%d hidden"). Each stays its own setting, for `/ft set` and Defaults.
- `slider = "key"` puts a slider on the same row as this checkbox.
- `conflicts = { { key = "other", when = function(db) end, text = L.WHY } }` shows a warning while `when` is true, with a button that jumps to the other option.
- `added = "<version>"` gives the option a NEW label.

Rules that keep the addon light:

- **Events, timers and hooks belong to their module.** Use `self:RegisterEvent(event, fn)` (calling it again with the same function, or `self:UnregisterEvent` for an event it doesn't hear, costs nothing, so register and unregister freely as an option changes), `self:After` and `self:NewTicker` for timers (`self:Soon(fn)` to redo something once on the next frame after a burst of events, `self:IsPending(timer)` and `self:CancelTimer(timer)` to check or stop one), `self:Hook` and `self:HookScript` for hooks (`self:HookCallback(target, key, install, fn)` for a tooltip post call or callback registry). They all run through one shared frame with `securecallfunction`, so an error in one never stops the others. They stop or go quiet when the module turns off, and the Profiler times them. A console variable a module needs is a notice instead: `notice = { requires = { { cvar = ..., value = ... } } }` asks the player to set it.
- **A module that's off costs nothing.** Make frames in `OnEnable`, not when the file loads.
- **Settings and data are kept apart.** `self.db` gives the player's setting, else the default. A table default is data the module keeps, and Defaults never clears it. When the saved layout changes, add a step in the addon's migrations file (`ForeverTweaks/Core/Migrations.lua`, `ForeverCompendium/Migrations.lua`): `ns:Migrate(version, fn)` for the account's file (bump `layout` in its `Part.lua`), `ns:MigrateChar(version, fn)` for the character's (bump `charLayout`).
- **Talk in chat only when the player asked.** Otherwise use `self:Debug`, which goes to the log, or `self:Print` with `ns.ChatOption()`, which gives the player a Chat Messages checkbox.
- **Ask with `ns:Confirm(M, key, text, onAccept)` and `ns:Prompt(M, key, text, onAccept)` (and show text to copy with `ns:ShowCopyText(key, label, text)`),** not your own windows. The answer runs as the module's code.
- **Don't open Blizzard windows from addon code, and wrap anything that might be protected in `ns:AfterCombat(fn)`.** The one exception is the bags (Full Bags' Open Bags), and only out of combat.
- **Only use APIs, templates and atlases that Forever has.** See `docs/forever-api.md`, and add anything new you check.
- **For something on screen, use `ns.Widgets.AddDisplay(M, { name, onEnter, menu })`** (`menu(add)` calls `add(text, fn)` per right-click entry) with `defaults = ns.Widgets.DisplayDefaults({ ... }, anchor)` (the anchor is given there, once) and `options = ns.Widgets.DisplayOptions({ ... })`. It shows and hides with the module and gives you Edit Mode, resizing and the position sliders for free; the module only sets its text with `display:SetLine(text)` (`display:GetLine()` reads it back).
- **New commands:** a module adds its own with `self:AddCommand(name, usage, description, fn)` (only offered while it's on; `fn(rest)` runs as the module's code); core commands use `ns:AddCommand`.

## Add a Forever addon

1. Make its folder with `<Name>.toc` (`## Dependencies: ForeverCore`, `## Version:` the suite's) and a
   `Part.lua` first in it calling `ForeverCore:NewMember(name, ns, { title, short, saved, charSaved,
   slash, categories })` (see `ForeverCore/Core/Members.lua`); its saved variables in the TOC.
2. Its category labels (`L.CATEGORY_<KEY>`) in its `Locales/enUS.lua`.
3. Add the folder to `scripts/link.sh`, the two workflows, and the `suite` scenario.

## Releasing

1. Bump `## Version` in every addon's `.toc` (they share one version) and add the release to `ForeverCore/Changelog.lua`.
2. Push a tag `v<version>` (`git tag v2.0.0 && git push origin v2.0.0`).

`.github/workflows/release.yml` then runs the tests, checks the tag matches every TOC, and publishes a GitHub release with `Forever-<version>.zip` (all three folders), a `release.json` for addon managers (WowUp reads it), and that version's changelog as its notes. It also uploads the zip to CurseForge, filed under the game version named by the `CF_GAME_VERSION` repository variable (else the newest Retail one), once two things are set up: `## X-Curse-Project-ID: <id>` in `ForeverCore.toc` and a `CF_API_KEY` repository secret (a token from https://legacy.curseforge.com/account/api-tokens). Until then that step is skipped. When the repository exists, add `## X-Website: https://github.com/<owner>/<repo>/releases` to `ForeverCore.toc`: the Update Notice then names it as where to get a new version.

## Tests

`lua5.1 tests/run.lua` loads the addons from their TOCs into a small stand-in for the game (`tests/wow.lua`; `W.LoadAddon` loads an addon's dependencies first, so a member brings Forever Core) and runs each scenario (a file in `tests/scenarios/core/`, `tweaks/`, `bags/` or `compendium/`) in its own Lua process; `lua5.1 tests/run.lua <name>` runs one. A scenario file must be listed in `tests/run.lua`'s `GROUPS` (the run fails otherwise). `W.RunTimers()` runs every pending timer; `W.Advance(seconds)` moves the clock and runs timers as they fall due:

- `suite`: Forever Core with Compendium and without Tweaks: the member API, each slash speaking for its own addon, a settings page per member, the suite's minimap button opening the journal;
- `alone`: Forever Core with no member;
- `migrate`: Tweaks 1.10.0's and Compendium 0.3.0's saved variables carried into the suite;
- `upgrade`: Tweaks 0.9.0's saved variables moved to today's layout;
- `removed`: what removed modules left behind is cleared, their CVars left alone;
- `fresh`: a fresh install of the whole suite, every page opening, every text having English, chat muting and `/ft reset`;
- `settings`: the Settings pages: option controls, requires and shown, the sidebar, the module list and pane, search, and Defaults;
- `commands`: the `/ft` subcommands;
- `recorder`, `learning`: Compendium's Recorder: creatures, loot, quests; titles and looks, spells, resistances, deaths, reputation, money, quest-start items, wares, rewards, quest titles from the log and the game, what a creature does for a quest;
- `import`: the Bestiary Import (matching creature IDs, larger counts, places, quests and their pins, running twice);
- `journal`: the journal window (side tabs, zone headers, searching by name, loot and quest, filters, sorting, pins, a creature's page and tabs, the loot grid's width, notes, the quest legend, opening a quest, the Items and Trophies pages, trophy news);
- `archive`: the Archive (exports read back and refusing changed text, an import counted, confirmed and merged, backups and restoring);
- `social`: Sharing (the wire format, sharing and taking a creature, Receive Shares, Group Sync) and Badges (tiers, news, shown on tooltips);
- `pins`: Quest Pins (givers, turn-ins grey until ready, unfinished objectives, quests sharing a pin, each checkbox, the minimap's reach, drawn above the map, dailies, quest items, continent maps), Rare Pins and Creature Areas;
- `tooltips`: Tooltip Lines on creatures (kills, abilities, quests) and items, the drop index made again after new loot;
- `banner`: the Notification Banner's choices, queue, click, Edit Mode and turning off;
- `isolation`: errors in one handler, timer or hook not stopping the others; module timers (`Soon`, `CancelTimer`), hooks and option checks;
- `store`: a failing migration step, and saved settings that don't fit their option;
- `layer`: Layer Info reading layers from GUIDs;
- `chatfeatures`: the chat modules from Forever++ (arrow keys, font, history, levels, quest links, short channel names and the input box header, social button and the chat alerts on it (a secret anchor left alone), click timestamps, Keep Messages) and leaving each to Forever++'s;
- `fpptooltips`: Item Tooltips' lines, the auction scan, Profession Tooltips on items (a lockbox's line on every tooltip of it), Tooltips on a player (the border reset once cleared, Hide in Combat back after combat), and leaving each to Forever++'s;
- `chatfade`: Chat Window's buttons (free of Blizzard's dimming, following the mouse), tabs, input box, a flashing tab, message fading, Forever++'s Keep Chat Visible and Chattynator;
- `fishing`, `outfits`: the Fishing line, the zone's skill and the warnings; the Fishing Outfit saving only fishing slots, swapping, an outfit taken off by hand, Combat Weapons, and 1.8.0's Profession Outfits moving over;
- `djskin`: Dungeon Journal Skin on a stand-in DungeonJournal: the palette swapped and put back, backdrops cleared, icon borders on pooled rows, reloading to undo;
- `djcolors`: Dungeon Journal Skin's palette following Panels (filled rows without the row art, clear over it);
- `covered`: Repair & Sell Junk, Durability Warning and Gathering Tracking working alone and leaving their feature to Forever++/WilduTools while theirs is on;
- `questplates`: Quest Nameplates' icons and counts (done, group, secret lines, left to Forever++) and Object Names (name, reach, objective);
- `fishingcast`: Fishing Cast's double right-click, Apply Lure, combat (nothing armed, the binding cleared after), Louder Bobber and leaving it to Forever++;
- `combathelpers`: Melee Range, Five-Second Rule, Combat Error Filter and Cast Bar, each left to WilduTools while its own is on;
- `gathermap`: Gathering Map's recording (merging, failed casts, secret names, instances), world map and minimap pins, forgetting, and leaving it to Forever++;
- `bag`: the Button Bag taking buttons and giving them back;
- `performance`: FPS & Latency's line for each latency choice, with and without colours, hidden with nothing chosen, read again each second;
- `editmode`: Edit Mode moves, nudges and snapping;
- `ui`: slash commands another addon has, popups, and the minimap button;
- `api`: the public API, its callbacks, and the Profiler;
- `changelog`: the release notes against the TOC version and every NEW label, and the Changelog page's search;
- `updates`: the Update Notice telling the guild and a group its version, hearing a newer one, answering an older one, and when it stays quiet;
- `hints`: each settings hint shows only while something needs doing (and, for another addon, only while it's installed), its button does it, CVars are asked for the way Plumber asks, and the Tweaks for Addons page lists what to set in each installed addon;
- `fullbags`: Full Bags' coins and numbered borders, with vendor and Auctionator prices, Open Bags, and Baganator;
- `questitems`: Quest Items' needed, quest-starting and leftover items (by name, and by ID from QuestieDB), its marks and widgets, the leftover tooltip;
- `baganator`: Full Bags' widget in Baganator next to Baganator's item level, with its corner rules (one widget per corner shows), in the order the game sets them up;
- `vendor`, `gathering`: Autobuy (bundles, pausing, Ask First, the Restock button), and Gathering Session. A protected frame (made from a Secure template) touched in combat fails the run.

It also fails if any text has no English string, or if the code uses a global or a frame method the game doesn't have. GitHub Actions (`.github/workflows/check.yml`) runs it on every push, along with a syntax check, an ASCII check and a check that each addon's TOC lists every one of its files, and that every TOC has the same version. The game is still the real test: the stand-in checks wiring and logic, not looks.

## Credits

The runtime and Forever Tweaks are adapted from [Forever++](https://github.com/xIGBClutchIx/ForeverPlusPlus) by xIGBClutchIx, MIT License (see `LICENSE-ForeverPlusPlus.txt`):

- the Settings layout and the Debug and Changelog pages;
- the Chat modules (Arrow Keys, Font, History, Levels, Quest Links, Short Channel Names, Social Button, Click Timestamps, Keep Messages) and the Tooltips modules (Tooltips, Item Tooltips with its auction scan and disenchant rules, Profession Tooltips with its herb, vein and lockbox data), adapted from Forever++'s own;
- the event, saved-variable, popup and Edit Mode approaches;
- Fishing's zone skills (`Modules/Gathering/FishingZones.lua`, from Forever++'s World Map zone info, which took them from Leatrix Maps) and its list of lures (from Forever++'s Auto Weapon Buff).

Full Bags is an idea from [LootTriage](https://github.com/Krelock/LootTriage) by Krelock, and follows its rules and defaults for what's never suggested and its Alt-click keep list; Quest Items matches quest objectives to items by name as LootTriage does (no code from it: both are written from scratch, and LootTriage's list of what quests not picked up yet ask for isn't used, since it's GPL-licensed data).

Full Bags and Quest Items mark Baganator's bags through Baganator's public corner widget API.


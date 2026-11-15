--[[
    Forever Core - Changelog.lua
    The suite's release notes, newest first: every Forever addon ships at the suite's version, so
    each release has one entry here, whichever addon it changes. Each member addon's own
    Changelog.lua keeps its releases from before the suite; the Changelog page shows both
    (Settings/ChangelogPage.lua). The release notes on GitHub are this file's entry.

    Each change: { module = "ModuleName" (or a title for a removed module), kind = "Added" |
    "Changed" | "Fixed" | "Removed", text = "..." }. Without a module it goes under General.
]]

local _, ns = ...

ns.changelog = {
    {
        version = "2.9.0",
        date = "2026-11-14",
        changes = {
            { kind = "Changed", text = "Settings text reads the way the game's own options do: each module and option says what it does (\"Shows...\", \"Warns...\"), and colors and grays are spelled as the game spells them." },
        },
    },
    {
        version = "2.8.0",
        date = "2026-11-14",
        changes = {
            { kind = "Changed", text = "Forever's settings have a window of their own, built like Blizzard's Collections window: every page down the left (Settings, Tweaks, Compendium, Tweaks for Addons, About, Debug, Changelog), a size, a Key Bindings button, and it stays where you leave it. /forever, the minimap button and the new key binding open it; Settings > AddOns > Forever has a button for it." },
            { kind = "Changed", text = "Related modules sit together under a small heading in their category: Fishing; Herbs, Ore & Chests; Combat; Windows; Nameplates; Quest Log & Givers; Quest Items." },
            { module = "Vendor", kind = "Added", text = "An Autobuy window: the Autobuy list without opening the settings. Right-click the Restock button, or type /ft autobuy window." },
            { module = "GatherSession", kind = "Added", text = "A Gathering window: this session in full, your Fishing skill, the zone's water and your lure, and every item gathered, with Pause and Start Over. From the session line's right-click menu, /ft session window or a key binding." },
            { module = "MovableWindows", kind = "Added", text = "Movable Windows: hold Shift and drag one of Blizzard's windows to move it; Ctrl+right-click puts it back. It stays there always, until logout or until it closes, as you pick. Off by default." },
            { module = "KeepWindowsOpen", kind = "Added", text = "Keep Windows Open: the character, mail, merchant and other windows stay open when another one opens, until you close them. Off by default." },
        },
    },
    {
        version = "2.7.0",
        date = "2026-11-14",
        changes = {
            { module = "ClassColors", kind = "Added", text = "Class Colors: players' health bars and names in their class color on the player, target, focus and party frames, and creatures' bars red, yellow or gray by how they stand toward you. Turning it off puts Blizzard's colors back." },
            { module = "LootSparkle", kind = "Added", text = "Loot Sparkle: quest items lying in the world sparkle, and graphics presets can't turn it off. Off by default." },
            { module = "ForeverMarks", kind = "Added", text = "New in Forever: the Forever medallion after quests that weren't in original Classic (quest log, tracker, quest givers, a quest's title), and \"New in WoW Forever\" on the tooltips of items that weren't." },
            { module = "Threat", kind = "Added", text = "Threat: your threat on your target as a line you place in Edit Mode, in Blizzard's threat colors, and a hostile creature's aggro range on its tooltip." },
            { module = "DialogueKeys", kind = "Added", text = "Dialogue Keys: 1 to 9 pick a quest, an option or a reward in Blizzard's gossip and quest windows (each row numbered), Space accepts, hands in or completes, Tab steps through rewards; the gamepad's d-pad, A and B work too." },
            { module = "Journal", kind = "Added", text = "Click an item's icon on its page (or right-click it in the list) to find it in your bags: they open with it glowing, or Baganator flashes it." },
            { kind = "Added", text = "Key bindings (Keybindings > AddOns): Open Forever Settings, Cast Fishing, Pause or Resume Gathering Session, and Rotate Minimap on or off." },
            { kind = "Fixed", text = "Map pins show over OpenMap's stitched map and follow its view." },
        },
    },
    {
        version = "2.6.0",
        date = "2026-11-14",
        changes = {
            { module = "QuestNameplates", kind = "Changed", text = "The icon and the progress are set apart: pick the icon (by objective type, the quest \"!\", or none) and its size, put the progress below, above or beside it at its own size, and place them left, right or above the name, moved with the offset sliders." },
            { module = "QuestNameplates", kind = "Removed", text = "The green check on a creature whose part of a quest is done: it looked like the quest was ready to turn in. Such a creature now shows nothing." },
            { module = "RotateMinimap", kind = "Added", text = "Rotate Minimap is back: the minimap turns with you, set again after every loading screen (Forever resets it at login). Off by default." },
            { module = "Fishing", kind = "Removed", text = "The Fishing Outfit (/ft outfit and Combat Weapons). Your equipment sets stay as they are." },
            { module = "Banner", kind = "Fixed", text = "Notification icons fill their slot: a full icon cut to its art as Blizzard's toasts draw it, with the quest \"!\" or \"?\" or the rare skull as a badge on its corner, instead of the small mark alone." },
            { module = "TooltipLines", kind = "Changed", text = "An item's tooltip lists its Drop Chance from each creature, as loot addons show it: the creature, then its chance with the counts behind it, 37% (12/32)." },
            { kind = "Fixed", text = "Map pins on the minimap sit where they belong at every zoom, indoors and out (placed by the minimap's own view radius), follow you smoothly as you move and turn, never spill past its edge (round or square: creature areas are cut at the edge), and a square minimap is understood." },
        },
    },
    {
        version = "2.5.0",
        date = "2026-11-14",
        changes = {
            { module = "Banner", kind = "Changed", text = "Notifications work the way Forever Bestiary's did: one for each creature you meet for the first time (on by default; a rare says so), and one when the journal learns something new about a creature you know: its loot, abilities, places, defenses or quests (Creature Updates, each its own checkbox). What one creature teaches at once comes as one notification. They fade in and out, stay while the mouse is on them, and wait while you fight or talk to someone (Wait in Combat)." },
            { module = "Journal", kind = "Added", text = "Sounds: the journal opens and closes like a book, its tabs and buttons click, pinning has its own sound, a notification its discovery sound and a badge one for its tier. Turn them all off with Sounds." },
            { module = "Journal", kind = "Changed", text = "A creature's page opens with what it is (Identification: its level with its rank, its type and family, how it stands toward you; a mark says when the game keeps its type hidden inside an instance), its locations grouped into zones, dungeons and raids, and each line says on mouse over how the journal learns it." },
            { module = "Journal", kind = "Changed", text = "Under a creature's model, its loot and its quests sit side by side instead of in tabs: the Loot box switches between Loot, Wares and Rewards from its header, and the Quests box (with a legend on its ?) shows when it has quests. Your note is a button on the model." },
            { module = "Journal", kind = "Changed", text = "An item's page puts its tooltip under its name and who drops, sells or gives it beside, filling the page, and the tooltip shows the item as you saw it (its \"of the Bear\" and the like)." },
            { module = "Recorder", kind = "Added", text = "The Recorder tells when a creature is seen somewhere new or turns out to have to do with another quest (for notifications)." },
            { kind = "Changed", text = "Forever Compendium plays sounds now (Journal > Sounds turns them off); it still never writes in chat." },
        },
    },
    {
        version = "2.4.0",
        date = "2026-11-14",
        changes = {
            { module = "Journal", kind = "Changed", text = "The journal is built like Blizzard's Collections window: a list of creatures with their portraits in Blizzard's journal rows (a gold star on pinned ones), the chosen one laid out as Forever Bestiary does: its model on the Mount Journal's backdrop with Blizzard's turning buttons, and beside it its portrait, name and home over what's known of it (the quests in your log that want it, locations, abilities, defenses, best drops, encounters, kills, reputation); tabs below for Loot, Wares, Rewards, Quests and Notes; the count box at the top, and Forever's big icon tabs down the window's right edge. Items, Trophies and Badges sit on the Toy Box's page. An item shows its own tooltip docked beside who drops it (with their portraits, levels and homes), sells it or gives it, and its item level, required level, sell price and how many you have." },
            { module = "Journal", kind = "Added", text = "The creature list is grouped under a header for each zone (click one to fold it; pinned creatures first under their own); a creature seen in a city district or cave counts for its zone, and the world and continent maps never make a group. Turn it off with Group by Zone." },
            { module = "Journal", kind = "Added", text = "A Trophies page: every boss, rare and elite you've met, by zone, the defeated ones in colour with how often and when first, the rest greyed, and a tile with a progress bar for each kind." },
            { module = "Journal", kind = "Added", text = "A legend under a creature's quests says what each icon means." },
            { module = "Journal", kind = "Removed", text = "The Quests page: the quest log has the quests you're on, and a creature's Quests tab every quest it has to do with. Opening a quest (from a map pin, the banner or a creature) shows it in the quest log, or on the creature that gives it." },
            { module = "Archive", kind = "Added", text = "Export the journal (all of it or one creature) as text to copy, and import one back merged into yours (/fc export, /fc paste, or the gear menu at the journal's top). Backups of the whole journal, kept weekly by themselves and whenever you ask (/fc backup), and put back from the Data menu." },
            { module = "TooltipLines", kind = "Added", text = "A creature's tooltip names the abilities you've seen it use." },
            { module = "Banner", kind = "Added", text = "A banner when you defeat a rare or a boss for the first time (Trophies)." },
            { module = "SocialButton", kind = "Fixed", text = "Chat alerts (a voice chat notification, for one) no longer cause an error each time they move." },
            { module = "QuestNameplates", kind = "Fixed", text = "Quest Nameplates shows again with a nameplate addon that draws its own plates (Platynator): the icon and count go beside the nameplate instead of on Blizzard's hidden one." },
            { module = "Vendor", kind = "Changed", text = "Ask First's question says how many of each item you have and how many Autobuy keeps, beside how many it will buy." },
            { module = "Tooltips", kind = "Fixed", text = "A tooltip's border goes back to its own colour after a coloured one (it stayed in the last player's class colour), a tooltip hidden in combat comes back when combat ends, and a target whose name the game keeps hidden no longer adds a line other addons trip on." },
            { module = "ProfessionTooltips", kind = "Fixed", text = "A lockbox's Lockpicking line shows on every tooltip of it, not just where it was first seen." },
            { kind = "Changed", text = "Scroll bars across the suite are Blizzard's modern thin ones." },
        },
    },
    {
        version = "2.3.0",
        date = "2026-11-13",
        changes = {
            { kind = "Changed", text = "Forever Compendium catches up with Forever Bestiary: a new journal, a Recorder that learns much more, quest and creature maps, importing Bestiary's data, sharing and badges." },
            { module = "Journal", kind = "Changed", text = "The journal is a new window in Blizzard's own style, with tabs for Creatures, Quests, Items and Badges. Creatures: search by name, loot or quest (several terms with ;), filter by reaction, rank, kind, zone, pinned, wanted or noted, sort by any column. Each creature shows its model (and its other looks), title, places (click to see it on the map), abilities, resistances, encounters, kills, money and reputation, and tabs for its loot (drop chances, quality filter), wares, quest rewards, quests and your notes." },
            { module = "Journal", kind = "Fixed", text = "Quests show their titles everywhere: a quest known only by its number asks the game for its title and keeps it, instead of showing \"Quest 1234\"." },
            { module = "Journal", kind = "Added", text = "A key binding to open the journal (Key Bindings > AddOns)." },
            { module = "Journal", kind = "Changed", text = "The journal's layout follows Blizzard's own windows (Legacy System, Professions, Character): 920 wide, the search box and filter at the top of each list, the count and order beside the portrait, and lists, loot grids, text and badge cards that fill their panes instead of leaving room on the right." },
            { module = "Recorder", kind = "Added", text = "Learns more: a creature's title and looks, the spells it casts, what it resists, your deaths to it, the reputation and money its kills give, an item it drops that starts a quest, what vendors sell, quest rewards, objectives and kinds, and which creatures you kill, loot or speak to for a quest." },
            { module = "QuestPins", kind = "Fixed", text = "Map pins (Quest Pins, Rare Pins, and Forever Tweaks' Gathering Map) were drawn under the world map and didn't show; they're above it now." },
            { module = "QuestPins", kind = "Added", text = "Quest Pins show quest items (where an item that starts a quest dropped), blue givers for dailies, a zone's pins on its continent's map, quest titles, and a right-click opens the quest in the journal." },
            { module = "CreatureAreas", kind = "Added", text = "Creature Areas: where your pinned creatures and the creatures your quests want live, as soft patches on the world map and the minimap." },
            { module = "Import", kind = "Added", text = "Bestiary Import: bring Forever Bestiary's creatures, quests, quest givers, notes and pins into the journal (/fc import, or the button on its settings page)." },
            { module = "Sharing", kind = "Added", text = "Sharing: send a creature to your target from the journal, and take what others send you; Group Sync shares what you learn with your group." },
            { module = "Badges", kind = "Added", text = "Badges: tiers I to VIII for creatures met, kills, loot, abilities, money, rares, elites, bosses, places, zones, quests, deaths and vendors; show three on your tooltip for your group." },
            { module = "Banner", kind = "Added", text = "The Notification Banner tells of new badge tiers and quest items too, and a click opens what it's about." },
        },
    },
    {
        version = "2.2.0",
        date = "2026-11-13",
        changes = {
            { kind = "Added", text = "Forever++'s chat features and tooltips come to Forever Tweaks, so you have them without Forever++. Each one stays idle while Forever++'s own is on, so nothing happens twice." },
            { module = "ChatArrowKeys", kind = "Added", text = "Chat Arrow Keys: Up and Down bring back what you sent, Left and Right move through the text, without Alt." },
            { module = "ChatFont", kind = "Added", text = "Chat Font: the chat windows (and the box you type in) in another of the game's fonts." },
            { module = "ChatHistory", kind = "Added", text = "Chat History: each chat window's latest lines come back after a reload or the next login (not whispers)." },
            { module = "ChatLevels", kind = "Added", text = "Chat Levels: a player's level before their name in chat, colored like a quest of that level." },
            { module = "QuestLinks", kind = "Added", text = "Quest Links: quests Questie players link in chat become quest links you can click." },
            { module = "ShortChannelNames", kind = "Added", text = "Short Channel Names: [1. General] as [1. G] or another short form, in chat and while you type; [Guild] and [Party] as [GD] and [P] too." },
            { module = "SocialButton", kind = "Added", text = "Social Button: the Quick Join button moves into the column of chat buttons." },
            { module = "ChatStamps", kind = "Added", text = "Click Timestamps: click a chat line's timestamp to copy the line." },
            { module = "ChatFade", kind = "Added", text = "Keep Messages: chat never fades out." },
            { module = "Tooltips", kind = "Added", text = "Tooltips: unit and item tooltips colored by class, reaction and quality, with titles, who a unit targets, a colored guild, level, class and faction, tooltips at the mouse, and hiding unit tooltips in combat, the health bar or quest lines." },
            { module = "ItemTooltips", kind = "Added", text = "Item Tooltips: the stack's sell price, repair cost, how many you own, what disenchanting gives, stats in their colors, crafted gear compared on recipes, and the lowest auction price from scanning the auction house (or Auctionator's)." },
            { module = "ProfessionTooltips", kind = "Added", text = "Profession Tooltips: the skill a herb, vein, skinnable beast or lockbox needs, colored against yours like a trainer's recipes." },
        },
    },
    {
        version = "2.1.0",
        date = "2026-11-13",
        changes = {
            { module = "QuestPins", kind = "Added", text = "Quest Pins: where your quests are on the world map and the minimap, from what the Recorder learned: a yellow ! where you were offered a quest, a ? where one in your log is turned in (grey until it's ready), and where its objectives went before." },
            { module = "RarePins", kind = "Added", text = "Rare Pins: the rare creatures you've met, on the world map and the minimap where you saw each most. Right-click one to open the journal on it." },
            { module = "TooltipLines", kind = "Added", text = "Tooltip Lines: on creatures, your kills and their quests; on items, which creatures drop them and how often." },
            { module = "Banner", kind = "Added", text = "Notification Banner: a banner when you meet a rare creature (and, if you like, any new creature, a new drop or a quest's place). Click it for the journal; move it in Edit Mode." },
            { module = "Forever Bestiary", kind = "Removed", text = "Forever Tweaks' Forever Bestiary skin is gone: Forever Compendium does what Forever Bestiary did." },
            { module = "GatherMap", kind = "Changed", text = "Its pins are drawn by the suite's shared map pins, as the Compendium's are." },
        },
    },
    {
        version = "2.0.0",
        date = "2026-11-13",
        changes = {
            { kind = "Added", text = "Forever is now a suite: Forever Core (needed by the rest) with Forever Tweaks and Forever Compendium, each turned on or off in the game's AddOns list. One settings page, Settings > AddOns > Forever, with a page for each addon; /forever, /ft and /fc." },
            { kind = "Changed", text = "Your Forever Tweaks and Forever Compendium settings carry over. The chat settings (Mute All Chat Messages, Show Log in Chat) are the suite's now." },
            { module = "MinimapButton", kind = "Changed", text = "One button for the suite: click opens the Compendium's journal (Settings without the Compendium), right-click opens Settings. The Compendium's own button is gone." },
            { module = "Updates", kind = "Changed", text = "Tells you of a newer Forever suite." },
        },
    },
}

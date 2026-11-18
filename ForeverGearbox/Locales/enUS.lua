--[[
    Forever Gearbox - Locales/enUS.lua
    Forever Gearbox' own player-facing strings that aren't a module's, in English: its module
    categories, the bridge to Forever++ (Core/Plugin.lua), its Modules page without Forever++ and the
    item list. The runtime's are in
    Shared/Locales/enUS_Core.lua; each module's in Locales/enUS_Modules.lua (enUS_Shared.lua for
    the modules WilduTools/Plumber also have).
]]

local _, ns = ...
local L = ns:NewLocale("enUS")

L.OPEN_FOREVERPP = "Open Forever++"
-- The bridge to Forever++ (Core/Plugin.lua).
L.PLUGIN_TOGGLE_THERE = "Forever Gearbox' modules are turned on and off on Forever++'s Modules page."
L.PLUGIN_SECTION = "Forever Gearbox" -- the heading over Forever Gearbox' rows on Forever++'s pages
L.PLUGIN_ONLY = "Gearbox"
L.PLUGIN_ONLY_TIP = "Show only Forever Gearbox' modules, and Forever++'s modules with a Forever Gearbox section on their page."
L.PLUGIN_OPEN_LIST = "Open"
L.PLUGIN_CVARS = "Find in Console Variables"
L.PLUGIN_CVARS_BUTTON = "Open"
L.PLUGIN_CVARS_TIP = "Open Forever++'s Console Variables on this setting, to change or lock it there."
L.PLUGIN_OPEN_LIST_TIP = "Open its list in a window of its own."
-- Forever++ Integration (Modules/Addons/ForeverPlusPlus.lua)
L.FPP_TITLE = "Forever++ Integration"
L.FPP_DESC = "Work together with Forever++: Upgrade Arrows in Baganator judges gear the way Forever++'s Upgrade Arrows does, Quest Markers, Fishing and Upgrade Arrows in Baganator are also on the pages of the Forever++ modules they go with (and Quest Markers hides Forever++'s own nameplate mark), Advanced Graphics is listed under Forever++ in Settings too, and a console variable a module needs can be found in Forever++'s Console Variables. Off, Forever Gearbox leaves Forever++ alone."
L.FPP_RELOAD = "Forever++'s settings pages show Forever Gearbox' sections after a /reload."
-- Forever Codex Integration (Modules/Addons/ForeverCodex.lua)
L.FCODEX_TITLE = "Forever Codex Integration"
L.FCODEX_DESC = "Work together with Forever Codex while keeping each addon's owner lines clear: Codex keeps map pins, OpenMap menu switches and its QuestieDB wrapper, and Gearbox keeps its own nameplate and minimap-button behavior. Off, Gearbox leaves Codex alone."
L.FCODEX_OWNERS = "With this on, Codex owns map pins and OpenMap menu switches; Gearbox keeps its own nameplate and minimap-button features."
L.FCODEX_NO_API = "This copy of Forever Codex has no public API yet. Update Forever Codex to use this integration."
-- Forever Gearbox' own Modules page without Forever++ (Settings/AlonePage.lua, UI/ForeverRows.lua).
L.ALONE_ENABLED = "Enabled"
L.ALONE_OPTIONS = "Options"
L.ALONE_NO_OPTIONS = "This module has no options."
L.ALONE_GO = "Go to %s" -- a conflict's button, going to the other option
L.COVERED_BY = "%s does %s, so Forever Gearbox leaves it to it. Turn it off there to use this one."
L.ITEMLIST_ADD = "Add"
L.ITEMLIST_REMOVE = "Remove"
L.ITEMLIST_ITEM = "Item"
L.ITEMLIST_AMOUNT = "Amount"
L.ITEMLIST_WANT = "Want"
L.ITEMLIST_HAVE = "Have"
L.ITEMLIST_UNKNOWN = "Unknown item. Drag it from your bags, or type its item ID or name."
L.ITEMLIST_BAD_AMOUNT = "Type an amount of 1 or more."
L.CATEGORY_INTERFACE = "Info & Display"
-- Groups of related modules inside a category (their modules' `group`).
L.GROUP_FISHING = "Fishing"
L.GROUP_COMBAT = "Combat"
L.GROUP_QUEST_WINDOWS = "Quest Log & Givers"
L.GROUP_QUEST_ITEMS = "Quest Items"
L.CATEGORY_CHAT = "Chat"
L.CATEGORY_QUESTS = "Quests"
L.CATEGORY_BAGS = "Bags & Items"
L.CATEGORY_MERCHANT = "Merchant"
L.CATEGORY_GATHERING = "Gathering"
L.CATEGORY_ADDONS = "Tweaks for Addons"
L.CMD_BAG = "open the Button Bag"


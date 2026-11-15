--[[
    Forever Tweaks - Locales/enUS.lua
    Forever Tweaks' own player-facing strings that aren't a module's, in English: its module
    categories, the Tweaks for Addons page and the item list. Forever Core's are in its own
    Locales/enUS.lua; each module's in Locales/enUS_Modules.lua (enUS_Shared.lua for the modules
    Forever++/WilduTools/Plumber also have).
]]

local _, ns = ...
local L = ns:NewLocale("enUS")

L.OPEN_FOREVERPP = "Open Forever++"
L.COVERED_BY = "%s does %s, so Forever Tweaks leaves it to it. Turn it off there to use this one."
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
L.GROUP_HERBS = "Herbs, Ore & Chests"
L.GROUP_COMBAT = "Combat"
L.GROUP_WINDOWS = "Windows"
L.GROUP_NAMEPLATES = "Nameplates"
L.GROUP_QUEST_WINDOWS = "Quest Log & Givers"
L.GROUP_QUEST_ITEMS = "Quest Items"
L.CATEGORY_CHAT = "Chat"
L.CATEGORY_QUESTS = "Quests"
L.CATEGORY_BAGS = "Bags & Items"
L.CATEGORY_MERCHANT = "Merchant"
L.CATEGORY_GATHERING = "Gathering"
L.CATEGORY_ADDONS = "Tweaks for Addons"
L.ADDONS_PAGE_INTRO = "What Forever Tweaks changes in your other addons, and what to set in them for it to work its best. Only addons you have installed are shown."
L.ADDONS_SETTINGS_IN = "Settings in %s that help Forever Tweaks."
L.ADDONS_FOR = "For %s"
L.ADDONS_FOR_OFF = "For %s, which is off"
L.CMD_BAG = "open the Button Bag"

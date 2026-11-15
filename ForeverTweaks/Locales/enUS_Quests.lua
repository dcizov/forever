--[[
    Forever Tweaks - Locales/enUS_Quests.lua
    The strings of the Quests modules added in 2.7 (Dialogue Keys, New in Forever, Loot
    Sparkle), in English. The other modules' are in Locales/enUS_Modules.lua (and
    enUS_Shared.lua, enUS_Tooltips.lua); the addon's own in enUS.lua.
]]

local _, ns = ...
local L = ns:NewLocale("enUS")

-- Dialogue Keys -----------------------------------------------------------------------------------
L.DKEYS_TITLE = "Dialogue Keys"
L.DKEYS_DESC = "Talk to quest givers with the keyboard or a gamepad: 1 to 9 pick a quest, an option or a reward, and Space accepts, completes or continues."
L.DKEYS_CONFIRM = "Confirm Key"
L.DKEYS_CONFIRM_TIP = "The key that accepts a quest, hands in its items or completes it."
L.DKEYS_CONFIRM_SPACE = "Space"
L.DKEYS_CONFIRM_INTERACT = "Interact Key"
L.DKEYS_CONFIRM_BOTH = "Space or Interact Key"
L.DKEYS_CONFIRM_OFF = "None"
L.DKEYS_NUMBERS = "Number Keys"
L.DKEYS_NUMBERS_TIP = "1 to 9 pick a quest, an option or a reward. Tab steps through reward choices."
L.DKEYS_LABELS = "Show Numbers"
L.DKEYS_LABELS_TIP = "Shows each row's number beside it."
L.DKEYS_GAMEPAD = "Gamepad"
L.DKEYS_GAMEPAD_TIP = "The d-pad moves through the list, A confirms and B closes the window."
L.DKEYS_LABEL = "%d."
L.DKEYS_DIALOGUEUI = "DialogueUI is loaded and handles these keys, so Dialogue Keys does nothing."

-- New in Forever --------------------------------------------------------------------------------
L.FMARKS_TITLE = "New in Forever"
L.FMARKS_DESC = "Marks quests and items that weren't in original Classic with the Forever medallion."
L.FMARKS_WHAT = "the Forever quest icon"
L.FMARKS_LOG = "Quest Log"
L.FMARKS_LOG_TIP = "Shows the medallion after new quests in the quest log."
L.FMARKS_TRACKER = "Objective Tracker"
L.FMARKS_TRACKER_TIP = "Shows the medallion after new quests in the objective tracker."
L.FMARKS_GIVERS = "Quest Givers"
L.FMARKS_GIVERS_TIP = "Shows the medallion after new quests in a quest giver's list."
L.FMARKS_DETAILS = "Quest Details"
L.FMARKS_DETAILS_TIP = "Shows the medallion after a new quest's title when you read it."
L.FMARKS_ITEMS = "Item Tooltips"
L.FMARKS_ITEMS_TIP = "Adds a line to the tooltip of an item that's new in WoW Forever."
L.FMARKS_ITEM_LINE = "New in WoW Forever"
L.FMARKS_SIZE = "Icon Size"
L.FMARKS_SIZE_TIP = "How big the medallion is next to the text."

-- Loot Sparkle ----------------------------------------------------------------------------------
L.SPARKLE_TITLE = "Loot Sparkle"
L.SPARKLE_DESC = "Makes quest items you can pick up in the world sparkle, so they're easy to spot. Graphics presets can't turn it off while this is on."
L.SPARKLE_WHAT = "the loot sparkle"
L.SPARKLE_RESTART = "Turning it off takes effect after you restart the game."

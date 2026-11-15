--[[
    Forever Tweaks - Locales/enUS_Interface.lua
    The strings of the Info & Display and Map modules added in 2.6 to 2.8 (Class Colors,
    Threat, Movable Windows, Keep Windows Open, Rotate Minimap), in English. The other modules' are in Locales/enUS_Modules.lua (and
    enUS_Shared.lua, enUS_Tooltips.lua); the addon's own in enUS.lua.
]]

local _, ns = ...
local L = ns:NewLocale("enUS")

-- Class Colors ----------------------------------------------------------------------------------
L.CLASSCOLORS_TITLE = "Class Colors"
L.CLASSCOLORS_DESC = "Shows players' health bars and names in their class color on the player, target, focus and party frames, and enemies' health bars red, neutral ones yellow and tapped ones gray."
L.CLASSCOLORS_WHAT = "class colors"
L.CLASSCOLORS_BARS = "Class-Colored Health Bars"
L.CLASSCOLORS_BARS_TIP = "Shows a player's health bar in their class color."
L.CLASSCOLORS_NPC_BARS = "Reaction-Colored Health Bars"
L.CLASSCOLORS_NPC_BARS_TIP = "Shows a creature's health bar red when hostile, yellow when neutral and gray when someone else tapped it. Friendly creatures stay green."
L.CLASSCOLORS_NAMES = "Names"
L.CLASSCOLORS_NAMES_TIP = "The color of names on unit frames."
L.CLASSCOLORS_NAMES_DEFAULT = "Blizzard's"
L.CLASSCOLORS_NAMES_WHITE = "White"
L.CLASSCOLORS_NAMES_CLASS = "Class Color"
L.CLASSCOLORS_NAME_BG = "Class-Colored Name Background"
L.CLASSCOLORS_NAME_BG_TIP = "Shows the bar behind a player's name on the target and focus frames in their class color."
L.CLASSCOLORS_SECTION_FRAMES = "Unit Frames"
L.CLASSCOLORS_PLAYER = "Player"
L.CLASSCOLORS_TARGET = "Target"
L.CLASSCOLORS_FOCUS = "Focus"
L.CLASSCOLORS_PARTY = "Party"
L.CLASSCOLORS_TOT = "Target of Target"
L.CLASSCOLORS_PLATES_FRIENDLY = "Class-colors friendly players' health bars on nameplates."
L.CLASSCOLORS_PLATES_ENEMY = "Class-colors enemy players' health bars on nameplates."
L.CLASSCOLORS_PLATES_NAMES = "Class-colors friendly players' names on nameplates."

-- Threat ----------------------------------------------------------------------------------------
L.THREAT_TITLE = "Threat"
L.THREAT_DESC = "Shows your threat on your target, and the aggro range of hostile creatures on their tooltips."
L.THREAT_DISPLAY = "Threat on Target"
L.THREAT_DISPLAY_TIP = "Shows your threat on your target while you have some, in Blizzard's threat colors."
L.THREAT_RAW = "Raw Threat"
L.THREAT_RAW_TIP = "Shows your share of the top threat on the creature instead of how close you are to pulling it."
L.THREAT_AGGRO = "Aggro Range"
L.THREAT_AGGRO_TIP = "Adds a hostile creature's aggro range to its tooltip: about 20 yards at your level, a yard more for each level it's above you."
L.THREAT_LINE = "Threat %s"
L.THREAT_PERCENT = "%d%%"
L.THREAT_TANKING = "Tanking"
L.THREAT_TOOLTIP = "Your threat on your target. Yellow: close to pulling it. Orange and red: it's attacking you."
L.THREAT_AGGRO_LINE = "Aggro Range: ~%d yd"

-- Movable Windows ---------------------------------------------------------------------------------
L.MOVE_TITLE = "Movable Windows"
L.MOVE_DESC = "Hold Shift and drag one of Blizzard's windows to move it. Ctrl+right-click it to put it back."
L.MOVE_WHAT = "moving windows"
L.MOVE_KEY = "Move Key"
L.MOVE_KEY_TIP = "The key you hold while dragging a window."
L.MOVE_KEY_SHIFT = "Shift"
L.MOVE_KEY_CTRL = "Ctrl"
L.MOVE_KEY_ALT = "Alt"
L.MOVE_KEY_NONE = "None"
L.MOVE_REMEMBER = "Remember Position"
L.MOVE_REMEMBER_TIP = "How long a moved window stays where you put it."
L.MOVE_REMEMBER_ALWAYS = "Always"
L.MOVE_REMEMBER_SESSION = "Until Logout"
L.MOVE_REMEMBER_NEVER = "Until It Closes"

-- Keep Windows Open -------------------------------------------------------------------------------
L.KEEPOPEN_TITLE = "Keep Windows Open"
L.KEEPOPEN_DESC = "Windows like the character, mail and merchant windows stay open when another one opens, until you close them."
L.KEEPOPEN_RELOAD = "Turning it off takes effect after you reload your interface."
L.KEEPOPEN_DEBUG = "%d windows kept open"

-- Rotate Minimap -------------------------------------------------------------------------------
L.ROTATE_TITLE = "Rotate Minimap"
L.ROTATE_DESC = "Turns the minimap with you, so the way you face is always up."

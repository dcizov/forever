--[[
    Forever Gearbox - Locales/enUS_Shared.lua
    The strings of the modules that do what WilduTools also does, for players without it (Melee
    Range, Five-Second Rule, Cast Bar), in English. The other modules' are in Locales/enUS_Modules.lua; the addon's own in enUS.lua.
]]

local _, ns = ...
local L = ns:NewLocale("enUS")

-- Five-Second Rule -----------------------------------------------------------------------------
L.FIVESEC_TITLE = "Five-Second Rule"
L.FIVESEC_DESC = "Run a spark along your mana bar for five seconds after each spell that costs mana: your mana comes back fully once it's through."
L.FIVESEC_WHAT = "the five-second rule spark"
L.FIVESEC_RUNNING = "running"
L.FIVESEC_IDLE = "waiting for a cast"

-- Cast Bar -------------------------------------------------------------------------------------
L.CASTBAR_TITLE = "Cast Bar"
L.CASTBAR_DESC = "Make small changes to your cast bar. Its size and place are Edit Mode's (Cast Bar)."
L.CASTBAR_TIMER = "Timer Inside"
L.CASTBAR_TIMER_TIP = "The cast time inside the bar's right end, outlined, instead of beside it. Turn on Show Cast Time in Edit Mode to see it."
L.CASTBAR_SIMPLE = "Simple Look"
L.CASTBAR_SIMPLE_TIP = "The spell's name in the bar instead of in the box under it."
L.CASTBAR_TICKS = "Channel Ticks"
L.CASTBAR_TICKS_TIP = "A line on the bar where each tick of a channelled spell lands (Arcane Missiles, Drain Life, Mind Flay, Blizzard, ...)."
L.CASTBAR_WHAT_TIMER = "the cast timer inside the bar"
L.CASTBAR_WHAT_SIMPLE = "a simpler cast bar"
L.CASTBAR_WHAT_TICKS = "channel ticks"

--[[
    Forever Compendium - Lib/Sound.lua
    The journal's sounds, all through ns.Sound(key): the window opening and closing (a book's),
    its tabs and buttons, pinning, something learned (a notification) and a badge earned (by its
    tier's metal). Every one is the game's own (a SOUNDKIT name, or a sound file ID; several IDs:
    one at random). They play on the SFX channel, and only while the Journal's Sounds option is on
    (on by default): one checkbox for all of them.
]]

local _, ns = ...

local type, random = type, math.random

local SOUNDS = {
    open = { kit = "IG_SPELLBOOK_OPEN" },
    close = { kit = "IG_SPELLBOOK_CLOSE" },
    tab = { kit = "IG_CHARACTER_INFO_TAB" },
    button = { kit = "IG_MAINMENU_OPTION" },
    pinOn = { file = { 6838448 } },
    pinOff = { file = { 567407 } },
    discover = { file = { 567445, 567503, 567396 } }, -- a creature or something of one learned
    badgeBronze = { file = { 915759 } },
    badgeSilver = { file = { 915759 } },
    badgeGold = { file = { 3677372, 3677374, 3677376, 3677378, 3677380 } },
    badgeViolet = { file = { 5277937 } },
}
ns.SOUNDS = SOUNDS

-- A badge tier's sound (tiers I-II bronze, III-IV silver, V-VI gold, VII-VIII violet, as Badges colours them).
local TIER_SOUND = { "badgeBronze", "badgeBronze", "badgeSilver", "badgeSilver", "badgeGold", "badgeGold",
    "badgeViolet", "badgeViolet" }
function ns.TierSound(tier) return TIER_SOUND[tier] or "badgeBronze" end

local function soundsOn()
    local journal = ns.modules.Journal
    return journal ~= nil and journal.db ~= nil and journal.db.sounds
end

-- Plays sound `key` (SOUNDS), unless sounds are off.
function ns.Sound(key)
    local sound = SOUNDS[key]
    if not (sound and soundsOn()) then return end
    if sound.kit then
        local id = SOUNDKIT[sound.kit]
        if type(id) == "number" then PlaySound(id, "SFX") end
        return
    end
    PlaySoundFile(sound.file[random(#sound.file)], "SFX")
end

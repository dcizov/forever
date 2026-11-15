--[[
    Forever Tweaks - Loot Sparkle
    The sparkle on quest items lying in the world, so they're easy to spot. Forever's client draws
    it only while its console variable says so (outlineModeShowLootEffectWhenDisabled), and a
    graphics preset can turn that back off: this keeps it on while the module is on, setting it
    again a second after anything changes it, and puts the player's own value back when it turns
    off (Lib/CVars.lua). The game keeps drawing the sparkle until it restarts, whatever the
    variable says after (a notice says so).
    Left to Forever++'s Quest Item Sparkles while that's on.
    Adapted from Forever++'s Quest Item Sparkles by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local type = type
local CVars, OtherAddons = ns.CVars, ns.OtherAddons

local CVAR = "outlineModeShowLootEffectWhenDisabled"
local LOWER = CVAR:lower()
local AGAIN_AFTER = 1 -- seconds: a graphics preset sets many variables at once, this one maybe after us
local COVERS = { { "ForeverPlusPlus", "QuestItemSparkles" } }

local M = ns:NewModule("LootSparkle", {
    title = L.SPARKLE_TITLE,
    category = "quests",
    group = L.GROUP_QUEST_ITEMS,
    description = L.SPARKLE_DESC,
    added = "2.7.0",
    defaults = { enabled = false, saved = {} },
})
M.notice = OtherAddons.CoveredNotices(M, COVERS, L.SPARKLE_WHAT, { { text = L.SPARKLE_RESTART } })

local again

local function apply()
    if OtherAddons.CoveredBy(M, COVERS) then return end
    CVars.Set(M.db.saved, CVAR, "1")
end

local function onCVarUpdate(_, _, name)
    if type(name) == "string" and name:lower() == LOWER and not M:IsPending(again) then
        again = M:After(AGAIN_AFTER, apply)
    end
end

function M:OnEnable()
    self:RegisterEvent("CVAR_UPDATE", onCVarUpdate)
    apply()
end

function M:OnDisable() CVars.Restore(self.db.saved) end

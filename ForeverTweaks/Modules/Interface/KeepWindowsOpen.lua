--[[
    Forever Tweaks - Keep Windows Open
    Blizzard closes a window when another opens in its place (the panel manager shows at most a
    left, a center and a right one). With this on, the windows below stay open until you close
    them (Escape, or their close button), side by side wherever they are: pair it with Movable
    Windows to put each where you like.

    How: a window is taken out of the panel manager's list (UIPanelWindows) and its layout
    attributes cleared, so ShowUIPanel just shows it; it's added to UISpecialFrames so Escape still
    closes it (NoAutoClose's way; none of its code). This writes to a table Blizzard's own code
    reads, which can taint it, so it's done only out of combat, only for windows that hold nothing
    protected, and the module is off by default; turning it off takes a reload (a notice says so).
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, rawget, type, format = ipairs, pairs, rawget, type, string.format

local M = ns:NewModule("KeepWindowsOpen", {
    title = L.KEEPOPEN_TITLE,
    category = "interface",
    group = L.GROUP_WINDOWS,
    description = L.KEEPOPEN_DESC,
    added = "2.8.0",
    defaults = { enabled = false },
})
M.notice = { { text = L.KEEPOPEN_RELOAD } }

-- Windows that hold nothing protected (no secure buttons: no spellbook, no action buttons).
local NAMES = {
    "CharacterFrame", "FriendsFrame", "SocialUIFrame", "CommunitiesFrame", "AchievementFrame",
    "CollectionsJournal", "EncounterJournal", "DressUpFrame", "MailFrame", "MerchantFrame", "GossipFrame",
    "QuestFrame", "QuestLogPopupDetailFrame", "TradeFrame", "BankFrame", "AuctionHouseFrame", "ClassTrainerFrame",
    "TaxiFrame", "TokenFrame", "LFGParentFrame", "PVEFrame", "CalendarFrame", "TimeManagerFrame", "ItemTextFrame",
}
local LAYOUT_ATTRIBUTES = { "UIPanelLayout-defined", "UIPanelLayout-enabled", "UIPanelLayout-area",
    "UIPanelLayout-pushable", "UIPanelLayout-whileDead" }

local freed = {} -- name -> true once taken out of the panel manager

local function free(name)
    local frame = rawget(_G, name)
    if freed[name] or type(frame) ~= "table" or not UIPanelWindows[name] then return end
    UIPanelWindows[name] = nil
    if frame.SetAttribute then
        for _, attribute in ipairs(LAYOUT_ATTRIBUTES) do frame:SetAttribute(attribute, nil) end
    end
    tinsert(UISpecialFrames, name)
    freed[name] = true
end

-- Every window there is now; ones that load later are freed as their addon loads.
local function freeAll()
    if InCombatLockdown() then return end
    for _, name in ipairs(NAMES) do free(name) end
end
M.FreeAll = freeAll -- (the tests' way in)

function M:OnEnable()
    ns:AfterCombat(self, freeAll)
    self:RegisterEvent("ADDON_LOADED", function() ns:AfterCombat(self, freeAll) end)
end

function M:DebugLine()
    local n = 0
    for _ in pairs(freed) do n = n + 1 end
    return format(L.KEEPOPEN_DEBUG, n)
end

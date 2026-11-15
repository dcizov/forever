--[[
    Forever Tweaks - Movable Windows
    Hold the move key (Shift by default) and drag one of Blizzard's windows (character,
    spellbook, friends, bags, quest log, merchant, mail and the rest below) to put it somewhere
    else; Ctrl+right-click it to put it back. It stays where you left it until it closes, for the
    session, or for good, as you pick.

    Blizzard places these windows itself (the panel manager each time one opens or closes, the bag
    stack), and both end in the window's own SetPoint: that is hooked, with OnShow, to put a moved
    window back where you left it. Only the window's anchors change: no Blizzard table, attribute
    or function is written, so the panel manager's secure code stays untainted. A window holding
    protected frames moves only out of combat; one it couldn't put back in combat goes back when
    combat ends. Windows that load later (with Blizzard's load-on-demand addons) are looked for
    again as addons load.
    Left to Forever++'s Movable Windows while that's on.
    Adapted from Forever++'s Movable Windows by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, type, setmetatable, rawget, unpack = ipairs, pairs, type, setmetatable, rawget, unpack
local OtherAddons = ns.OtherAddons

local COVERS = { { "ForeverPlusPlus", "MovableWindows" } }

local M = ns:NewModule("MovableWindows", {
    title = L.MOVE_TITLE,
    category = "interface",
    group = L.GROUP_WINDOWS,
    description = L.MOVE_DESC,
    added = "2.8.0",
    defaults = { enabled = false, moveKey = "shift", remember = "always", positions = {} },
    options = {
        { key = "moveKey", type = "dropdown", label = L.MOVE_KEY, tooltip = L.MOVE_KEY_TIP,
          choices = { { "shift", L.MOVE_KEY_SHIFT }, { "ctrl", L.MOVE_KEY_CTRL }, { "alt", L.MOVE_KEY_ALT },
              { "none", L.MOVE_KEY_NONE } } },
        { key = "remember", type = "dropdown", label = L.MOVE_REMEMBER, tooltip = L.MOVE_REMEMBER_TIP,
          choices = { { "always", L.MOVE_REMEMBER_ALWAYS }, { "session", L.MOVE_REMEMBER_SESSION },
              { "never", L.MOVE_REMEMBER_NEVER } } },
    },
})
M.notice = OtherAddons.CoveredNotices(M, COVERS, L.MOVE_WHAT)

-- The windows, by global name (Forever++'s list, checked against the forever branch): ones this
-- client doesn't have are skipped.
local NAMES = {
    "CharacterFrame", "PlayerSpellsFrame", "ProfessionsBookFrame", "ProfessionsFrame", "FriendsFrame",
    "CommunitiesFrame", "PVEFrame", "AchievementFrame", "CollectionsJournal", "EncounterJournal", "MacroFrame",
    "ClassTrainerFrame", "InspectFrame", "DressUpFrame", "MailFrame", "OpenMailFrame", "MerchantFrame", "BankFrame",
    "GuildBankFrame", "AuctionHouseFrame", "GossipFrame", "QuestFrame", "TradeFrame", "TabardFrame", "PetitionFrame",
    "ItemTextFrame", "ItemSocketingFrame", "TimeManagerFrame", "CalendarFrame", "AddonList", "LootFrame",
    "ContainerFrameCombinedBags", "SettingsPanel", "TokenFrame", "LFGParentFrame", "TaxiFrame", "FlightMapFrame",
    "ChannelFrame", "ChatConfigFrame", "QuestLogPopupDetailFrame", "HelpFrame", "SocialUIFrame", "GameMenuFrame",
    "WorldMapFrame",
}
for i = 1, 13 do NAMES[#NAMES + 1] = "ContainerFrame" .. i end
-- Windows that can fill the screen: while one does, it's left to Blizzard.
local FULL_SCREEN = { WorldMapFrame = function(frame) return frame.IsMaximized and frame:IsMaximized() end }
local HELD = { shift = IsShiftKeyDown, ctrl = IsControlKeyDown, alt = IsAltKeyDown }

local weak = { __mode = "k" }
local nameOf = setmetatable({}, weak)       -- window -> its name, once hooked
local original = setmetatable({}, weak)     -- window -> Blizzard's anchors before we moved it
local wasMovable = setmetatable({}, weak)   -- window -> whether it was movable before
local wasUserPlaced = setmetatable({}, weak) -- window -> IsUserPlaced before a drag
local session = {} -- name -> position, for "session" and "never"
local dragging     -- the window being dragged
local placing = false -- while we set a window's anchors, so the SetPoint hook keeps out

local function inCharge() return M.active and not OtherAddons.CoveredBy(M, COVERS) end

local function pointsOf(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
    return points
end

local function setPoints(frame, points)
    frame:ClearAllPoints()
    for _, p in ipairs(points) do frame:SetPoint(unpack(p)) end
end

local function positionOf(name)
    if M.db.remember == "always" then return M.db.positions[name] end
    return session[name]
end

local function canMove(frame)
    if InCombatLockdown() and frame:IsProtected() then return false end
    local full = FULL_SCREEN[nameOf[frame]]
    return not (full and full(frame))
end

-- Puts a window where you left it, if you moved it.
local function putWhereLeft(frame)
    if placing or frame == dragging or not inCharge() then return end
    local p = positionOf(nameOf[frame])
    if not (p and canMove(frame)) then return end
    if original[frame] == nil then original[frame] = pointsOf(frame) end
    placing = true
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    placing = false
end

local function putAllWhereLeft()
    for frame in pairs(nameOf) do putWhereLeft(frame) end
end

local function putBack(frame)
    if original[frame] and canMove(frame) then
        placing = true
        setPoints(frame, original[frame])
        placing = false
    end
end

local function held()
    local key = M.db.moveKey
    return key == "none" or (HELD[key] and HELD[key]()) and true or false
end

local function startDrag(frame, button)
    if dragging or not inCharge() or not canMove(frame) then return end
    -- Ctrl+right-click: back to Blizzard's place, and forgotten.
    if button == "RightButton" and IsControlKeyDown() then
        local name = nameOf[frame]
        session[name], M.db.positions[name] = nil, nil
        putBack(frame)
        return
    end
    if button ~= "LeftButton" or not held() then return end
    if original[frame] == nil then original[frame] = pointsOf(frame) end
    if wasMovable[frame] == nil then wasMovable[frame] = frame:IsMovable() and true or false end
    wasUserPlaced[frame] = frame:IsUserPlaced() and true or false
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:StartMoving()
    dragging = frame
end

local function stopDrag(frame)
    if dragging ~= frame then return end
    dragging = nil
    frame:StopMovingOrSizing()
    -- StartMoving marks the window user-placed (the client's layout cache); the place is ours.
    frame:SetUserPlaced(wasUserPlaced[frame] or false)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end
    local p = { point, relativePoint, x, y }
    session[nameOf[frame]] = p
    if M.db.remember == "always" then M.db.positions[nameOf[frame]] = p end
end

local function onHide(_, frame)
    stopDrag(frame)
    if M.db.remember == "never" and session[nameOf[frame]] then
        session[nameOf[frame]] = nil
        putBack(frame)
    end
end

-- Blizzard placing the window would undo a move: it's put back straight after.
local function onSetPoint(_, frame)
    if placing or frame == dragging then return end
    original[frame] = pointsOf(frame)
    putWhereLeft(frame)
end

local function hook(name)
    local frame = rawget(_G, name)
    if type(frame) ~= "table" or nameOf[frame] or not frame.HookScript then return end
    nameOf[frame] = name
    M:HookScript(frame, "OnMouseDown", function(_, f, button) startDrag(f, button) end)
    M:HookScript(frame, "OnMouseUp", function(_, f) stopDrag(f) end)
    M:HookScript(frame, "OnShow", function(_, f) putWhereLeft(f) end)
    M:HookScript(frame, "OnHide", onHide)
    M:Hook(frame, "SetPoint", onSetPoint)
    -- The title bar, where a window is most often grabbed, can take the click itself.
    local title = frame.TitleContainer
    if type(title) == "table" and title.HookScript then
        M:HookScript(title, "OnMouseDown", function(_, _, button) startDrag(frame, button) end)
        M:HookScript(title, "OnMouseUp", function() stopDrag(frame) end)
    end
end

local function hookAll()
    for _, name in ipairs(NAMES) do hook(name) end
    putAllWhereLeft()
end

-- The drag may have started on a frame inside the window, which gets the mouse up instead.
local function onMouseUp()
    if dragging then stopDrag(dragging) end
end

function M:OnEnable()
    hookAll()
    self:RegisterEvent("ADDON_LOADED", hookAll)
    self:RegisterEvent("GLOBAL_MOUSE_UP", onMouseUp)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", putAllWhereLeft) -- moves that waited out combat
end

-- Every window back where Blizzard had it, and as movable as it was.
function M:OnDisable()
    if dragging then stopDrag(dragging) end
    for frame in pairs(original) do putBack(frame) end
    for frame, movable in pairs(wasMovable) do
        if canMove(frame) then frame:SetMovable(movable) end
        wasMovable[frame] = nil
    end
end

function M:OnSettingChanged(key)
    -- A move made under the old choice is kept for the session, so nothing jumps now.
    if key == "remember" and M.db.remember == "always" then
        for name, p in pairs(session) do M.db.positions[name] = p end
    end
end

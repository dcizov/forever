--[[
    Forever Tweaks - Social Button
    The social (Quick Join) button sits above the chat window on its own. This puts it in the
    column of small buttons beside the window, under Blizzard's channel button (and the voice
    buttons while they show), and gives it its place back when it turns off. Blizzard moves the
    button from its own code now and then, so its SetPoint is hooked to put it back; the chat
    alerts that stack on it (ChatAlertFrame) go where it would have been. Left to Forever++'s
    Social Button while that's on. Adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local ipairs = ipairs
local OtherAddons = ns.OtherAddons

local COVERS = { { "ForeverPlusPlus", "SocialButton" } }

local M = ns:NewModule("SocialButton", {
    title = L.SOCIALBUTTON_TITLE,
    category = "chat",
    description = L.SOCIALBUTTON_DESC,
    added = "2.2.0",
    defaults = { enabled = false },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.SOCIALBUTTON_WHAT)

local original -- where Blizzard had the button: { parent, points }
local placing = false

local function inCharge() return M.active and not OtherAddons.CoveredBy(M, COVERS) end

-- The lowest of Blizzard's buttons in the column: a voice button while it shows, else the
-- channel button.
local function above()
    for _, button in ipairs({ ChatFrameToggleVoiceMuteButton, ChatFrameToggleVoiceDeafenButton }) do
        if button and button:IsShown() then return button end
    end
    return ChatFrameChannelButton
end

local function place()
    local button = QuickJoinToastButton
    if not original then original = { parent = button:GetParent(), points = ns.Points(button) } end
    placing = true
    button:SetParent(ChatFrameChannelButton:GetParent())
    button:ClearAllPoints()
    button:SetPoint("TOP", above(), "BOTTOM", 0, -2)
    placing = false
end

local function restore()
    if not original then return end
    local button = QuickJoinToastButton
    placing = true
    button:SetParent(original.parent)
    ns.SetPoints(button, original.points)
    placing = false
    original = nil
end

-- The chat alert anchored to the button goes where the button was in the stack: on the alerts'
-- own base. Only an alert whose anchor can be read is moved (a voice chat alert's can be
-- secret), and it keeps its points and offsets.
local function unchainAlerts()
    if not inCharge() then return end
    local container = ChatAlertFrame
    local base = ns.Usable(container.baseAnchorFrame) and container.baseAnchorFrame or container
    for _, system in ipairs(container.alertFrameSubSystems or {}) do
        local frame = system.anchorFrame
        if ns.Usable(frame) and frame ~= QuickJoinToastButton and frame:IsShown() then
            local points, moved = ns.Points(frame), false
            for _, p in ipairs(points) do
                if p[2] == QuickJoinToastButton then p[2], moved = base, true end
            end
            if moved then ns.SetPoints(frame, points) end
        end
    end
end

local function update()
    if inCharge() then place() else restore() end
end

-- Blizzard moved it (or a voice button came or went): back in the column.
local function onMoved()
    if not placing and inCharge() then place() end
end

function M:OnEnable()
    self:Hook(QuickJoinToastButton, "SetPoint", onMoved)
    for _, button in ipairs({ ChatFrameToggleVoiceMuteButton, ChatFrameToggleVoiceDeafenButton }) do
        self:HookScript(button, "OnShow", onMoved)
        self:HookScript(button, "OnHide", onMoved)
    end
    self:Hook(ChatAlertFrame, "UpdateAnchors", unchainAlerts)
    update()
    unchainAlerts()
end

function M:OnDisable() restore() end

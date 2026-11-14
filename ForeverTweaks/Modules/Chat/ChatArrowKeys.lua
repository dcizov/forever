--[[
    Forever Tweaks - Chat Arrow Keys
    While you type in chat, Up and Down bring back what you sent before and Left and Right move
    through the text, without holding Alt. The chat box already remembers what you sent but reads
    the arrows only with Alt held (its "alt arrow key mode"); this turns that off for each window's
    box and gives each its own mode back when it turns off. It's the game's own history and
    typing: nothing of ours writes into the box. Left to Forever++'s Chat Arrow Keys while that's
    on. Adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local ipairs, setmetatable = ipairs, setmetatable
local Chat, OtherAddons = ns.Chat, ns.OtherAddons

local COVERS = { { "ForeverPlusPlus", "ChatArrowKeys" } }

local M = ns:NewModule("ChatArrowKeys", {
    title = L.CHATARROWS_TITLE,
    category = "chat",
    description = L.CHATARROWS_DESC,
    added = "2.2.0",
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.CHATARROWS_WHAT)

local modes = setmetatable({}, { __mode = "k" }) -- edit box -> its mode before ours

local function apply(frame)
    local box = frame.editBox
    if not box then return end
    local want = M.active and not OtherAddons.CoveredBy(M, COVERS)
    if want and modes[box] == nil then
        modes[box] = box:GetAltArrowKeyMode() and true or false
        box:SetAltArrowKeyMode(false)
    elseif not want and modes[box] ~= nil then
        box:SetAltArrowKeyMode(modes[box])
        modes[box] = nil
    end
end

function M:OnEnable() Chat.EachWindow(self, apply) end

function M:OnDisable()
    for _, frame in ipairs(Chat.Frames()) do apply(frame) end
end

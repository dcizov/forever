--[[
    Forever Tweaks - Chat Font
    The chat windows (and, with Input Box, the box you type in and its "Say:") in a font from the
    game's own set. Blizzard keeps each window's size and outline; only the file changes, and each
    gets its own back when this turns off. SetFont takes one file, so the alphabets the game's chat
    font covers with fallbacks (Korean, Chinese, Cyrillic) would draw blank: on those clients it
    does nothing. Blizzard's font size menu (FCF_SetChatWindowFontSize) sets the file it reads
    back, which is ours, so it's applied again after it; that menu also copies ChatFrame1's file
    onto the GM and Communities chat, which get Blizzard's back. Left to Forever++'s Chat Font
    while that's on. Adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local ipairs, setmetatable = ipairs, setmetatable
local Chat, OtherAddons = ns.Chat, ns.OtherAddons

local COVERS = { { "ForeverPlusPlus", "ChatFont" } }
local NON_ROMAN = { koKR = true, zhCN = true, zhTW = true, ruRU = true }

local M = ns:NewModule("ChatFont", {
    title = L.CHATFONT_TITLE,
    category = "chat",
    description = L.CHATFONT_DESC,
    added = "2.2.0",
    defaults = { enabled = false, font = "Fonts\\FRIZQT__.TTF", inputBox = true },
    options = {
        { key = "font", type = "dropdown", label = L.CHATFONT_FONT, tooltip = L.CHATFONT_FONT_TIP,
          choices = {
              { "Fonts\\FRIZQT__.TTF", L.FONT_FRIZQT },
              { "Fonts\\ARIALN.TTF", L.FONT_ARIALN },
              { "Fonts\\skurri.ttf", L.FONT_SKURRI },
              { "Fonts\\MORPHEUS.TTF", L.FONT_MORPHEUS },
          } },
        { key = "inputBox", type = "checkbox", label = L.CHATFONT_INPUT, tooltip = L.CHATFONT_INPUT_TIP },
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.CHATFONT_WHAT)

local original = setmetatable({}, { __mode = "k" }) -- font string or box -> its file before ours

local function setFont(region, font)
    local file, size, flags = region:GetFont()
    if not file then return end
    if original[region] == nil then original[region] = file end
    if file ~= font then region:SetFont(font, size, flags) end
end

local function restore(region)
    local file = original[region]
    if not file then return end
    local _, size, flags = region:GetFont()
    region:SetFont(file, size, flags)
    original[region] = nil
end

-- A window's input box and the prompt beside it ("Say:").
local function inputParts(frame)
    local box = frame.editBox
    if not box then return {} end
    return { box, box.header, box.headerSuffix }
end

local function inCharge()
    return M.active and not NON_ROMAN[GetLocale()] and not OtherAddons.CoveredBy(M, COVERS)
end

local function apply(frame)
    if not inCharge() then
        restore(frame)
        for _, part in ipairs(inputParts(frame)) do restore(part) end
        return
    end
    setFont(frame, M.db.font)
    for _, part in ipairs(inputParts(frame)) do
        if M.db.inputBox then setFont(part, M.db.font) else restore(part) end
    end
end

local function applyAll()
    for _, frame in ipairs(Chat.Frames()) do apply(frame) end
end

-- The GM and Communities chat, which Blizzard's size menu gives ChatFrame1's file.
local function copiedFrames()
    local communities = CommunitiesFrame
    return { GMChatFrame, communities and communities.Chat and communities.Chat.MessageFrame }
end

function M:OnEnable()
    Chat.EachWindow(self, apply)
    self:Hook("FCF_SetChatWindowFontSize", applyAll)
end

function M:OnDisable()
    local blizzard = original[ChatFrame1]
    if blizzard then
        local frames = copiedFrames()
        for i = 1, 2 do -- either may be missing (both load on demand)
            local frame = frames[i]
            local file, size, flags
            if frame then file, size, flags = frame:GetFont() end
            if file == self.db.font then frame:SetFont(blizzard, size, flags) end
        end
    end
    applyAll()
end

function M:OnSettingChanged() applyAll() end

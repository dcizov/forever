--[[
    Forever Tweaks - Chat History
    Each chat window's latest lines come back after logging out or reloading, for each character on
    its own. The lines are read from the windows' own buffers as the game logs out (PLAYER_LOGOUT,
    which a reload sends too), so nothing runs while you play, and put back at login. Colors and
    links are kept, since the lines are saved as they were drawn. Not saved: a secret line, the
    combat log, and whispers (saved variables are plain text that players often share with a bug
    report). Windows are kept by number, so only the numbered ones (a popped-out whisper's number
    is another's after a reload). Left to Forever++'s Chat History while that's on, so lines don't
    come back twice. Adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local ipairs, type, max = ipairs, type, math.max
local Chat, OtherAddons, Plain = ns.Chat, ns.OtherAddons, ns.Plain

local COVERS = { { "ForeverPlusPlus", "ChatHistory" } }
local WHISPERS = { "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM" }

local M = ns:NewModule("ChatHistory", {
    title = L.CHATHISTORY_TITLE,
    category = "chat",
    description = L.CHATHISTORY_DESC,
    added = "2.2.0",
    defaults = {
        enabled = false, lines = 100, divider = true,
        saved = {}, -- data: window number -> { { text, r, g, b } }, each character's own
    },
    perCharacter = { saved = true },
    options = {
        -- Blizzard's windows hold 128 lines, so more could never be saved.
        { key = "lines", type = "slider", label = L.CHATHISTORY_LINES, tooltip = L.CHATHISTORY_LINES_TIP,
          min = 25, max = 125, step = 25, format = "%d" },
        { key = "divider", type = "checkbox", label = L.CHATHISTORY_DIVIDER_OPTION, tooltip = L.CHATHISTORY_DIVIDER_TIP },
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.CHATHISTORY_WHAT)

-- The chat type ids of whispers, as GetMessageInfo gives them.
local function whisperIDs()
    local ids = {}
    for _, chatType in ipairs(WHISPERS) do
        local id = GetChatTypeIndex(chatType)
        if type(id) == "number" then ids[id] = true end
    end
    return ids
end

local function isCombatLog(frame) return frame == COMBATLOG end

local function save()
    if OtherAddons.CoveredBy(M, COVERS) then return end
    local saved, whispers = {}, whisperIDs()
    for index, frame in ipairs(Chat.Frames(true)) do
        local total = isCombatLog(frame) and 0 or frame:GetNumMessages()
        local lines = {}
        for i = max(1, total - M.db.lines + 1), total do
            local text, r, g, b, chatTypeID = frame:GetMessageInfo(i)
            text, r, g, b, chatTypeID = Plain(text), Plain(r), Plain(g), Plain(b), Plain(chatTypeID)
            -- An unreadable type is left out too: it could be a whisper's.
            if chatTypeID and not whispers[chatTypeID] and type(text) == "string" and text ~= L.CHATHISTORY_DIVIDER
                and r and g and b then
                lines[#lines + 1] = { text, r, g, b }
            end
        end
        if #lines > 0 then saved[index] = lines end
    end
    M.db.saved = saved
end

local function restore(_, _, isLogin, isReload)
    if not (isLogin or isReload) or OtherAddons.CoveredBy(M, COVERS) then return end
    for index, frame in ipairs(Chat.Frames(true)) do
        local lines = not isCombatLog(frame) and M.db.saved[index]
        if lines and #lines > 0 then
            for _, line in ipairs(lines) do frame:AddMessage(line[1], line[2], line[3], line[4]) end
            if M.db.divider then frame:AddMessage(L.CHATHISTORY_DIVIDER, 0.6, 0.6, 0.6) end
        end
    end
end

function M:OnEnable()
    self:RegisterEvent("PLAYER_LOGOUT", save)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", restore)
end

function M:OnDisable() self.db.saved = {} end

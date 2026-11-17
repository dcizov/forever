--[[
    Forever Codex - Lib/Spoken.lua
    The journal beside Spoken (optional): Spoken Quests keeps the words of quests (the giver's
    offer and hand-in, read aloud) in its Azeroth's Compendium, so a quest the journal names opens
    there when Spoken has it (ns.ShowQuest, Journal.lua), as Spoken's own button on the quest
    window does (Spoken_Quests' UI/OpenInCompendium.lua): only for a quest Spoken has words for
    and would open (its QuestsTab:Has), so it never points at an empty page.

    Spoken Quests' tab is reached through its one global, `VoiceOver` (QuestsTab:Has,
    QuestsTab:Open). Every call into it is protected: a Spoken of another shape opens nothing.
]]

local _, ns = ...

local type, pcall = type, pcall

local Spoken = {}
ns.Spoken = Spoken

-- Spoken Quests' tab of Azeroth's Compendium, when it's there with the calls used here.
local function questsTab()
    local vo = _G.VoiceOver
    local tab = type(vo) == "table" and vo.QuestsTab
    if type(tab) == "table" and type(tab.Has) == "function" and type(tab.Open) == "function" then return tab end
end

-- Whether Spoken has words for quest `questID` and would open it.
function Spoken.HasLore(questID)
    local tab = questID and questsTab()
    if not tab then return false end
    local ok, has = pcall(tab.Has, tab, questID)
    return ok and has == true
end

-- Opens quest `questID` in Azeroth's Compendium.
function Spoken.Open(questID)
    local tab = questsTab()
    if tab then pcall(tab.Open, tab, questID) end
end

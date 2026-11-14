--[[
    Forever Tweaks - tests/scenarios/core/updates.lua
    Update Notice: telling the guild and a group joined, hearing a newer version (said once, and
    again at the next login until updated once two players said it; one far ahead ignored), answering an older one, the once-a-minute limit, no
    messages in combat or while the game locks them, and Share Your Version off.
    Run by tests/run.lua (lua5.1 tests/run.lua updates), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
W.inGuild = true
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local mod = ns.modules.Updates
check(mod.active, "on by default")
local here = ns.version

local function sent(channel)
    local n = 0
    for _, m in ipairs(W.addonMessages) do
        if m.channel == channel then
            eq(m.text, "v:" .. here, "it sends its version")
            n = n + 1
        end
    end
    return n
end
local function hear(version, channel, sender)
    W.Fire("CHAT_MSG_ADDON", "ForeverTweaks", "v:" .. version, channel, sender or "Someone")
end
-- Versions one major release ahead (believable) and far ahead (not).
local major = tonumber(here:match("^(%d+)"))
local next1, next2, next3 = (major + 1) .. ".0.0", (major + 1) .. ".1.0", (major + 1) .. ".2.0"
local function said(text)
    for _, line in ipairs(W.chat) do if line:find(text, 1, true) then return true end end
    return false
end

W.Advance(16)
eq(sent("GUILD"), 1, "after login the guild hears its version, once")

W.group = "party"
W.Fire("GROUP_JOINED")
W.Advance(6)
eq(sent("PARTY"), 1, "a group joined hears it too")

-- An older copy is answered, at most once a minute per channel.
hear("0.1.0", "PARTY")
eq(sent("PARTY"), 1, "an older copy within the minute: not again yet")
W.Advance(61)
hear("0.1.0", "PARTY")
eq(sent("PARTY"), 2, "after the minute it's answered")
hear("0.1.0", "WHISPER")
eq(sent("WHISPER"), 0, "a whisper isn't answered")

-- A newer version: said once; kept for the next login once two players have said it.
eq(mod:NewerVersion(), nil, "nothing newer heard yet")
hear("99.0.0", "GUILD", "Liar")
eq(mod:NewerVersion(), nil, "a version far ahead of any real one is ignored")
hear(next2, "GUILD", "Someone")
eq(mod:NewerVersion(), next2, "a newer version heard")
check(said("Forever " .. next2 .. " is out"), "it says so in chat")
eq(ForeverCoreDB.data.Updates.newest.version, nil, "one player's word: this session only")
local lines = #W.chat
hear(next2, "PARTY", "Someone")
eq(ForeverCoreDB.data.Updates.newest.version, nil, "the same player again doesn't count twice")
hear(next2, "PARTY", "Another")
eq(#W.chat, lines, "said once a session")
eq(ForeverCoreDB.data.Updates.newest.version, next2, "two players: kept for the account, said again at the next login")
hear(next1, "PARTY", "Third")
hear(next1, "PARTY", "Fourth")
eq(mod:NewerVersion(), next2, "an older one than heard before doesn't replace it")
eq(ForeverCoreDB.data.Updates.newest.version, next2, "nor the one kept")
hear("garbage", "PARTY")
W.Fire("CHAT_MSG_ADDON", "OtherAddon", "v:" .. next3, "PARTY", "Someone")
eq(mod:NewerVersion(), next2, "other prefixes and bad text are ignored")

-- No messages in combat, while locked, or with Share Your Version off.
W.Advance(61)
W.combat = true
hear("0.1.0", "PARTY")
W.combat = false
W.messagingLockdown = true
hear("0.1.0", "PARTY")
W.messagingLockdown = false
eq(sent("PARTY"), 2, "nothing in combat or while the game locks addon messages")
ns:SetOption("Updates", "share", false)
hear("0.1.0", "PARTY")
eq(sent("PARTY"), 2, "Share Your Version off: nothing sent")
hear(next3, "PARTY")
eq(mod:NewerVersion(), next3, "but newer versions are still heard")

ns:OpenSettings()
finish()

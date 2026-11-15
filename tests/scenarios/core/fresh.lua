--[[
    Forever Tweaks - tests/scenarios/core/fresh.lua
    A fresh install of the whole suite (Forever Core, Tweaks and Compendium): saved variables
    made, every page opening without an error, every text having English, Mute All Chat
    Messages, and /ft reset asking first. (The Settings pages' controls and
    layout are the settings scenario.)
    Run by tests/run.lua (lua5.1 tests/run.lua fresh), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
W.LoadAddon(root, "ForeverCompendium")
login()
eq(ForeverTweaksDB.version, ns.member.layout, "fresh layout version")
eq(ForeverTweaksDB.installed, W.metadata.Version, "installed version")
check(type(ForeverTweaksCharDB.data) == "table", "character data made")
for _, member in ipairs(ns.members) do
    eq(_G[member.saved].version, member.layout, member.name .. ": fresh layout version")
    check(type(_G[member.charSaved].data) == "table", member.name .. ": character data made")
end
local on, total = ns:CountModules()
check(total >= 7 and on >= 1, "modules counted")
openEverything(ns)

-- Every key in use has English text.
for _, path in ipairs(W.files) do
    local src = io.open(path):read("*a")
    for key in src:gmatch("L%.([A-Z][A-Z0-9_]+)") do
        check(ns.L[key] ~= key, "no English text for L." .. key .. " (" .. path .. ")")
    end
end
for _, member in ipairs(ns.members) do
    for _, key in ipairs(member.categories) do
        check(ns:CategoryLabel(key) ~= "CATEGORY_" .. key:upper(), member.name .. " category " .. key)
    end
end

-- The Settings page: Mute All Chat Messages silences what modules say by themselves only.
ForeverCore.SettingsWindow.Open(ns.title)
ns.db.quiet = true
local before = #W.chat
ns.modules.Vendor:Print("layer news")
eq(#W.chat, before, "muted: a module says nothing by itself")
W.Slash("/ft list")
check(#W.chat > before, "but /ft commands still reply")
ns.db.quiet = nil
ns.modules.Vendor:Print("layer news")
check(W.LastChat():find("layer news", 1, true) ~= nil, "unmuted: it speaks again")

-- Defaults asks first.
ns:SetOption("Performance", "size", 20)
W.Slash("/ft reset")
eq(ns.modules.Performance.db.size, 20, "nothing reset before Yes")
W.Accept()
eq(ns.modules.Performance.db.size, 12, "reset after Yes")
finish()

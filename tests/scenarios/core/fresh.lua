--[[
    Forever Gearbox - tests/scenarios/core/fresh.lua
    A fresh install of both addons: saved variables made, every page opening without an error,
    every text having English, Mute All Chat Messages, and /fg reset asking first. (The settings
    window's controls and layout are the settings scenario.)
    Run by tests/run.lua (lua5.1 tests/run.lua fresh), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverGearbox")
local fc = W.LoadAddon(root, "ForeverCodex")
login()
for _, addon in ipairs({ ns, fc }) do
    local member = addon.member
    eq(_G[member.saved].version, member.layout, member.name .. ": fresh layout version")
    eq(_G[member.saved].installed, W.metadata.Version, member.name .. ": installed version")
    check(type(_G[member.charSaved].data) == "table", member.name .. ": character data made")
    local on, total = addon:CountModules()
    check(total >= 7 and on >= 1, member.name .. ": modules counted")
end
openEverything(fc)

-- Every key in use has English text, in the addon whose file uses it.
for _, path in ipairs(W.files) do
    local addon = path:find("/ForeverCodex/", 1, true) and fc or ns
    local src = io.open(path):read("*a")
    for key in src:gmatch("L%.([A-Z][A-Z0-9_]+)") do
        check(addon.L[key] ~= key, "no English text for L." .. key .. " (" .. path .. ")")
    end
end
for _, addon in ipairs({ ns, fc }) do
    for _, key in ipairs(addon.member.categories) do
        check(addon:CategoryLabel(key) ~= "CATEGORY_" .. key:upper(), addon.member.name .. " category " .. key)
    end
end

-- Mute All Chat Messages (Gearbox' own, ns.db.quiet) silences what modules say by themselves only.
ns.db.quiet = true
local before = #W.chat
ns.modules.Vendor:Print("layer news")
eq(#W.chat, before, "muted: a module says nothing by itself")
W.Slash("/fg list")
check(#W.chat > before, "but /fg commands still reply")
ns.db.quiet = nil
ns.modules.Vendor:Print("layer news")
check(W.LastChat():find("layer news", 1, true) ~= nil, "unmuted: it speaks again")

-- Defaults asks first.
ns:SetOption("Performance", "size", 20)
W.Slash("/fg reset")
eq(ns.modules.Performance.db.size, 20, "nothing reset before Yes")
W.Accept()
eq(ns.modules.Performance.db.size, 12, "reset after Yes")
finish()

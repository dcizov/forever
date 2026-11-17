--[[
    Forever suite - tests/scenarios/core/changelog.lua
    The release notes' contract (Forever Codex's Changelog.lua, both addons' releases,
    against the TOCs and both addons' modules' `added` versions) and the Changelog page's search.
    Run by tests/run.lua (lua5.1 tests/run.lua changelog), which passes its helpers in.
]]

local T = ...
local under = T.under -- every frame under one that passes a test (tests/run.lua)
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ft = W.LoadAddon(root, "ForeverGearbox")
local ns = W.LoadAddon(root, "ForeverCodex")
login()

-- The releases: the newest is the TOCs' version, and the list is newest first.
local changelog = ns.changelog
eq(changelog[1].version, W.metadata.Version, "the newest release is the TOC's version")
for i = 2, #changelog do
    check(ns:IsNewer(changelog[i - 1].version, changelog[i].version), "release "
        .. changelog[i - 1].version .. " is newer than " .. changelog[i].version)
end

-- Every change: a known kind, some text, and a module that's a module's name (either addon's, or
-- one removed since, named as it was) or a title, never an internal key.
local KINDS = { Added = true, Changed = true, Fixed = true, Removed = true }
local versions = {}
for _, release in ipairs(changelog) do
    versions[release.version] = true
    check(release.date == nil or release.date:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil,
        release.version .. ": a date like 2026-11-11")
    for _, change in ipairs(release.changes) do
        local where = release.version .. ": " .. tostring(change.text):sub(1, 40)
        check(KINDS[change.kind], where .. ": a known kind")
        check(type(change.text) == "string" and change.text ~= "", where .. ": has text")
        if change.module and not ns.modules[change.module] and not ft.modules[change.module] then
            check(change.module:find(" ", 1, true) ~= nil or change.module:match("^%u%w+$") ~= nil, where .. ": '"
                .. change.module .. "' is neither a module's name nor a removed module's title")
        end
    end
end

-- Every NEW label points at a release that has notes (Forever Gearbox' from before the suite,
-- under 2.0.0, are only in its git history).
local function noted(version)
    return version == nil or versions[version] or ns:IsNewer("2.0.0", version)
end
for _, addon in ipairs({ ft, ns }) do
    for _, name in ipairs(addon.order) do
        local mod = addon.modules[name]
        check(noted(mod.added), name .. ": added in a release with notes")
        for _, option in ipairs(mod.options) do
            check(noted(option.added), name .. "." .. option.key .. ": added in a release with notes")
        end
    end
end

-- The page: its search narrows the list of releases, and clearing it brings them all back.
ns.SettingsWindow.Open(ns.L.CHANGELOG)
local frame = ns.SettingsWindow.Page(ns.L.CHANGELOG).frame
local search = under(frame, function(f) return f._template == "SearchBoxTemplate" end)[1]
check(search ~= nil, "the page has a search box")
-- Each release's row is the parent of the font string showing its version.
local rowOf = {}
for _, f in ipairs(under(frame, function(f) return f._kind == "FontString" end)) do
    for _, release in ipairs(changelog) do
        if f._text == release.version then rowOf[release.version] = f:GetParent() end
    end
end
local function shownReleases()
    local n = 0
    for _, release in ipairs(changelog) do
        if rowOf[release.version] and rowOf[release.version]:IsShown() then n = n + 1 end
    end
    return n
end
eq(shownReleases(), #changelog, "every release listed")
local oldest = changelog[#changelog].version
search:SetText(oldest)
search:Fire("OnTextChanged")
eq(shownReleases(), 1, "searching a release's name lists that release")
check(rowOf[oldest]:IsShown(), "the one searched for")
search:SetText("")
search:Fire("OnTextChanged")
eq(shownReleases(), #changelog, "clearing the search lists every release again")
finish()

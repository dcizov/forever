--[[
    Forever suite - tests/scenarios/core/changelog.lua
    The release notes' contract (Forever Core's Changelog.lua against the TOC, each member's
    history, and the modules' `added` versions) and the Changelog page's search.
    Run by tests/run.lua (lua5.1 tests/run.lua changelog), which passes its helpers in.
]]

local T = ...
local under = T.under -- every frame under one that passes a test (tests/run.lua)
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
W.LoadAddon(root, "ForeverCompendium")
login()

-- The suite's releases: the newest is the TOC's version. Each list (the suite's, each member's
-- history) is newest first.
eq(ForeverCore.changelog[1].version, W.metadata.Version, "the newest release is the TOC's version")
local changelog, labelOf = {}, {} -- every release, as the page lists them, and each one's label
for _, member in ipairs(ns.members) do
    local list = rawget(member.ns, "changelog") or {}
    for i = 2, #list do
        check(ns:IsNewer(list[i - 1].version, list[i].version), member.name .. ": release "
            .. list[i - 1].version .. " is newer than " .. list[i].version)
    end
    for _, release in ipairs(list) do
        changelog[#changelog + 1] = release
        labelOf[release] = member == ForeverCore.member and release.version or (member.short .. " " .. release.version)
    end
end
check(#changelog > #ForeverCore.changelog, "the members' histories are listed too")

-- Every change: a known kind, some text, and a module that's a module's name or (for a removed
-- module) a title, never an internal key.
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
        if change.module and not ns.modules[change.module] then
            check(change.module:find(" ", 1, true) ~= nil, where .. ": '" .. change.module
                .. "' is neither a module's name nor a removed module's title")
        end
    end
end

-- Every NEW label points at a release that has notes.
for _, name in ipairs(ns.order) do
    local mod = ns.modules[name]
    check(mod.added == nil or versions[mod.added], name .. ": added in a release with notes")
    for _, option in ipairs(mod.options) do
        check(option.added == nil or versions[option.added], name .. "." .. option.key .. ": added in a release with notes")
    end
end

-- The page: its search narrows the list of releases, and clearing it brings them all back.
C_SettingsUtil.OpenSettingsPanel(ns.L.CHANGELOG)
local frame = W.categories[ns.L.CHANGELOG].frame
local search = under(frame, function(f) return f._template == "SearchBoxTemplate" end)[1]
check(search ~= nil, "the page has a search box")
-- Each release's row is the parent of the font string showing its version.
local rowOf = {}
for _, f in ipairs(under(frame, function(f) return f._kind == "FontString" end)) do
    for _, release in ipairs(changelog) do
        if f._text == labelOf[release] then rowOf[labelOf[release]] = f:GetParent() end
    end
end
local function shownReleases()
    local n = 0
    for _, release in ipairs(changelog) do
        if rowOf[labelOf[release]] and rowOf[labelOf[release]]:IsShown() then n = n + 1 end
    end
    return n
end
eq(shownReleases(), #changelog, "every release listed")
local oldest = "Tweaks 0.1.0"
search:SetText(oldest)
search:Fire("OnTextChanged")
eq(shownReleases(), 1, "searching a release's name lists that release")
check(rowOf[oldest]:IsShown(), "the one searched for")
search:SetText("")
search:Fire("OnTextChanged")
eq(shownReleases(), #changelog, "clearing the search lists every release again")
finish()

--[[
    Forever Core - Core/Members.lua
    The suite's member addons. Forever Core holds the runtime (events, modules, saved variables,
    settings pages); each member (Forever Tweaks, Forever Compendium, ...) is an addon folder of
    its own that depends on it, so the game's AddOns list turns each on or off. A member's first
    file joins:

        local name, ns = ...
        ForeverCore:NewMember(name, ns, {
            title = "Forever Tweaks", short = "Tweaks",              -- chat name, Settings page name
            saved = "ForeverTweaksDB", charSaved = "ForeverTweaksCharDB", -- its saved variables
            layout = 11, charLayout = 1,                               -- their versions (Core/Store.lua)
            slash = { "/ft", "/forevertweaks" },                     -- its slash commands
            categories = { "interface", "chat", ... },               -- its modules' categories, in order
            open = function() ... end,                               -- optional: what a bare slash and
            openLabel = "JOURNAL_TITLE",                              -- the minimap button's click do,
        })                                                            -- and the locale key naming it

    After that its namespace reads through to the core's (ns:NewModule, ns.L, ns.Kit, ns.Widgets),
    so its files are written as the core's are. What it sets on its own namespace stays its own
    (Compendium's ns.Book, Tweaks' ns.ItemList); ns.member is the member. The core is a member too
    (ns.member on the core's namespace): its own settings (ns.db: quiet, debug) and modules (the
    Minimap Button, the Update Notice) are kept in ForeverCoreDB.

    A member: name (its folder), title, short, version (its TOC's), saved, charSaved, layout,
    charLayout, steps and charSteps (its migrations, ns:Migrate), order (its modules' names, in
    load order), categories and ranks (category -> place; "other" and "settings" always last),
    slash, open, openLabel, pages (its own Settings pages, ns:AddSettingsPage), ns (its namespace), and db,
    charDB once Core/Store.lua has loaded them.
]]

local addonName, ns = ...

local ipairs, type, assert, setmetatable = ipairs, type, assert, setmetatable

ns.members = {}        -- every member, the core first, then in load order
ns.membersByName = {}  -- folder name -> member

local function newMember(name, private, info)
    local member = {
        name = name, ns = private, title = info.title, short = info.short or info.title,
        version = C_AddOns.GetAddOnMetadata(name, "Version") or "0",
        saved = info.saved, charSaved = info.charSaved,
        layout = info.layout or 1, charLayout = info.charLayout or 1,
        steps = {}, charSteps = {}, order = {}, categories = {}, ranks = {},
        slash = info.slash or {}, open = info.open, openLabel = info.openLabel, pages = {},
    }
    for _, key in ipairs(info.categories or {}) do
        if key ~= "other" and key ~= "settings" then member.categories[#member.categories + 1] = key end
    end
    member.categories[#member.categories + 1] = "other"
    member.categories[#member.categories + 1] = "settings"
    for i, key in ipairs(member.categories) do member.ranks[key] = i end
    ns.members[#ns.members + 1] = member
    ns.membersByName[name] = member
    private.member = member
    return member
end

-- Joins member addon `name` (its folder) to the suite: `private` is its namespace (the `...` its
-- files get), `info` as above. Returns the member.
function ns:NewMember(name, private, info)
    assert(type(name) == "string" and type(private) == "table" and type(info) == "table",
        "NewMember: needs the addon's name, its namespace and an info table")
    assert(not ns.membersByName[name], "NewMember: " .. name .. " joined twice")
    assert(type(info.title) == "string", "NewMember: " .. name .. " needs a title")
    assert(type(info.saved) == "string" and type(info.charSaved) == "string",
        "NewMember: " .. name .. " needs saved and charSaved (its saved variables' names)")
    setmetatable(private, { __index = ns })
    return newMember(name, private, info)
end

ns.member = newMember(addonName, ns, {
    title = ns.title, saved = "ForeverCoreDB", charSaved = "ForeverCoreCharDB",
    slash = { "/forever" },
})

-- A Settings page of the calling member's own, for its modules of `category`, which its Modules
-- page then leaves out (Tweaks for Addons). build(frame) draws it, as Kit.CanvasFrame's builders do.
function ns:AddSettingsPage(category, label, build)
    local member = self.member
    assert(member.ranks[category], "AddSettingsPage: " .. member.name .. " has no category " .. tostring(category))
    member.pages[#member.pages + 1] = { category = category, label = label, build = build }
end

-- The member page `category` is shown on, or nil when its member's Modules page lists it.
function ns:PageOf(mod)
    local category = self:CategoryOf(mod)
    for _, page in ipairs(mod.member.pages) do
        if page.category == category then return page end
    end
end

--[[
    Forever runtime - Shared/Core/Members.lua
    The addon itself, as the runtime knows it: its member. Each Forever addon carries the runtime
    (Shared/) in its own namespace, so it has exactly one member, made by its Part.lua (loaded
    right after the runtime):

        local name, ns = ...
        ns:NewMember(name, ns, {
            title = "Forever Gearbox", short = "Gearbox",                -- chat name, page name
            saved = "ForeverGearboxDB", charSaved = "ForeverGearboxCharDB", -- its saved variables
            formerSaved = "ForeverTweaksDB", formerCharSaved = ...,     -- optional: its saved variables
                                                                       -- under an older name, taken over
            layout = 15, charLayout = 2,                                -- their versions (Core/Store.lua)
            slash = { "/fg", "/forevergearbox" },                      -- its slash commands
            categories = { "interface", "chat", ... },                -- its modules' categories, in order
            open = function() ... end,                                -- optional: what a bare slash and
            openLabel = "JOURNAL_TITLE",                               -- the minimap button's click do,
        })                                                             -- and the locale key naming it

    ns.member is the member; its settings (ns.db: quiet, debug, the settings window's place) are
    the addon's own saved variables' top level.

    A member: name (its folder), title, short, version (its TOC's), saved, charSaved, formerSaved,
    formerCharSaved, layout,
    charLayout, steps and charSteps (its migrations, ns:Migrate), order (its modules' names, in
    load order), categories and ranks (category -> place; "other" and "settings" always last),
    slash, open, openLabel, pages (its own Settings pages, ns:AddSettingsPage), ns (its namespace), and db,
    charDB once Core/Store.lua has loaded them.
]]

local _, ns = ...

local ipairs, type, assert = ipairs, type, assert

ns.members = {}        -- the addon's member (one)
ns.membersByName = {}  -- folder name -> member

local function newMember(name, private, info)
    local member = {
        name = name, ns = private, title = info.title, short = info.short or info.title,
        version = C_AddOns.GetAddOnMetadata(name, "Version") or "0",
        saved = info.saved, charSaved = info.charSaved, formerSaved = info.formerSaved, formerCharSaved = info.formerCharSaved,
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

-- Makes the addon's member: `name` is its folder, `private` its namespace (the `...` its files
-- get, this runtime's own), `info` as above. Returns the member.
function ns:NewMember(name, private, info)
    assert(type(name) == "string" and private == ns and type(info) == "table",
        "NewMember: needs the addon's name, its own namespace and an info table")
    assert(not ns.member, "NewMember: " .. name .. " joined twice")
    assert(type(info.title) == "string", "NewMember: " .. name .. " needs a title")
    assert(type(info.saved) == "string" and type(info.charSaved) == "string",
        "NewMember: " .. name .. " needs saved and charSaved (its saved variables' names)")
    ns.title = info.title
    return newMember(name, private, info)
end

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

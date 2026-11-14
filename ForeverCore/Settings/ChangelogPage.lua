--[[
    Forever Core - Settings/ChangelogPage.lua
    The Changelog page: releases on the left (version and date), the selected one's changes on
    the right, grouped under their modules (By Module) or as one list. The search box narrows
    both. Data: the suite's releases (Forever Core's Changelog.lua, ns.changelog), then each
    member's releases from before the suite (its own Changelog.lua, ns.changelog on its
    namespace), named after it ("Tweaks 1.10.0"), newest first.
]]

local _, ns = ...
local Kit, L = ns.Kit, ns.L

local ipairs, pairs, format, strlower = ipairs, pairs, string.format, string.lower

local LIST_WIDTH = 160
local GOLD = "|cffffd100"

local page
local releases        -- every release, newest first (allReleases)
local selected        -- index into releases
local byModule = true
local filter          -- lowercase search, or nil

local function moduleTitle(change)
    if not change.module then return L.GENERAL end
    local mod = ns.modules[change.module]
    return mod and mod.title or change.module
end

local function categoryOf(change)
    local mod = change.module and ns.modules[change.module]
    if not change.module then return "general", L.GENERAL end
    if not mod then return "other", ns:CategoryLabel("other") end
    local key = ns:CategoryOf(mod)
    return key, ns:CategoryLabel(key)
end

-- General first, then the module's member's order.
local function categoryRank(change)
    local mod = change.module and ns.modules[change.module]
    if not change.module then return 0 end
    return mod and ns:CategoryRank(mod) or 99
end

-- The suite's releases and each member's own history, newest first: by date, then version.
local function allReleases()
    local list = {}
    for _, member in ipairs(ns.members) do
        for _, release in ipairs(rawget(member.ns, "changelog") or {}) do
            local label = member == ns.member and release.version or (member.short .. " " .. release.version)
            list[#list + 1] = { version = release.version, date = release.date, changes = release.changes,
                label = label }
        end
    end
    table.sort(list, function(a, b)
        if (a.date or "") ~= (b.date or "") then return (a.date or "") > (b.date or "") end
        return ns:IsNewer(a.version, b.version)
    end)
    return list
end

local function changeMatches(release, change)
    if not filter then return true end
    if strlower(release.label):find(filter, 1, true) then return true end
    local text = strlower(change.text .. " " .. (change.kind or "") .. " " .. moduleTitle(change))
    return text:find(filter, 1, true) ~= nil
end

local function shownChanges(release)
    local list = {}
    for _, change in ipairs(release.changes) do
        if changeMatches(release, change) then list[#list + 1] = change end
    end
    return list
end

---------------------------------------------------------------------------
-- The pane: one stack of pooled rows, drawn again for each release, grouping and search.
-- Frames can't be freed, so rows are reused instead of made per view.
---------------------------------------------------------------------------

local view
local pools = { category = {}, module = {}, change = {} }
local used = { category = 0, module = 0, change = 0 }

local function newRow(kind)
    local width = view:GetWidth()
    local row = CreateFrame("Frame", nil, view)
    row:SetWidth(width)
    if kind == "category" then
        row:SetHeight(22)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.text:SetPoint("LEFT", 4, 0)
        local line = row:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 0.15)
        line:SetHeight(1)
        line:SetPoint("LEFT", row.text, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", -8, 0)
    elseif kind == "module" then
        row:SetHeight(30)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        row.text:SetPoint("TOPLEFT", 4, -4)
        local line = row:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 0.25)
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", 4, 2)
        line:SetPoint("BOTTOMRIGHT", -8, 2)
    else
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("TOPLEFT", 8, 0)
        row.text:SetWidth(width - 24)
        row.text:SetJustifyH("LEFT")
    end
    return row
end

local GAPS = { category = 14, module = 6, change = 8 }

-- Shows the next pooled row of `kind` (making one when the pool runs out) with `text`, below the last.
local function placeRow(kind, text)
    used[kind] = used[kind] + 1
    local pool = pools[kind]
    local row = pool[used[kind]]
    if not row then
        row = newRow(kind)
        pool[used[kind]] = row
    end
    row.text:SetText(text)
    if kind == "change" then row:SetHeight(row.text:GetStringHeight() + 2) end
    Kit.AddEntry(view, row, nil, GAPS[kind])
end

local function changeText(change, withModule)
    local body = change.text
    if withModule and change.module then
        body = body .. " |cff999999(" .. moduleTitle(change) .. ")|r"
    end
    return format("-  %s%s|r: %s", GOLD, L["KIND_" .. (change.kind or "Changed"):upper()], body)
end

local function draw(index)
    for kind, pool in pairs(pools) do
        for _, row in ipairs(pool) do row:Hide() end
        used[kind] = 0
    end
    wipe(view.entries)
    if not index then
        view:Hide()
        page.paneContent:SetHeight(1)
        return
    end

    local release = releases[index]
    local changes = shownChanges(release)
    view.heading:SetText(format("%s (%s)", release.label, release.date or "?"))
    view.count:SetText(format(#changes == 1 and L.CHANGES_ONE or L.CHANGES, #changes))

    if byModule then
        -- Category, then module, in category order; General first.
        local groups, order = {}, {}
        for _, change in ipairs(changes) do
            local key, label = categoryOf(change)
            local group = groups[key]
            if not group then
                group = { key = key, label = label, rank = categoryRank(change), modules = {}, moduleOrder = {} }
                groups[key] = group
                order[#order + 1] = group
            end
            local title = moduleTitle(change)
            if not group.modules[title] then
                group.modules[title] = {}
                group.moduleOrder[#group.moduleOrder + 1] = title
            end
            table.insert(group.modules[title], change)
        end
        table.sort(order, function(a, b) return a.rank < b.rank end)
        for _, group in ipairs(order) do
            placeRow("category", group.label)
            for _, title in ipairs(group.moduleOrder) do
                if group.key ~= "general" then placeRow("module", title) end
                for _, change in ipairs(group.modules[title]) do placeRow("change", changeText(change, false)) end
            end
        end
    else
        for _, change in ipairs(changes) do placeRow("change", changeText(change, true)) end
    end

    view:Show()
    Kit.Layout(view)
    page.paneContent:SetHeight(view:GetHeight())
    page.pane:SetVerticalScroll(0)
end

local function showRelease(index)
    selected = index
    for _, row in pairs(page.rows) do Kit.Paint(row) end
    draw(index)
end

local function releaseShown(index)
    return #shownChanges(releases[index]) > 0
end

local function relayout()
    page.empty.text:SetText(format(L.NO_CHANGES_MATCH, filter or ""))
    Kit.Layout(page.list)
    if not (selected and releaseShown(selected)) then
        selected = nil
        for i in ipairs(releases) do
            if releaseShown(i) then selected = i break end
        end
    end
    showRelease(selected)
end

function ns.BuildChangelogPage(frame)
    releases = allReleases()
    Kit.AddPageTitle(frame, L.CHANGELOG)
    page = Kit.NewSplit(frame, LIST_WIDTH)
    page.rows = {}

    view = Kit.NewStack(page.paneContent, page.paneWidth, 4)
    view:SetPoint("TOPLEFT")
    view.bottom = 12
    view.heading = view:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    view.heading:SetPoint("TOPLEFT", 4, -4)
    view.heading:SetText("0")
    view.count = view:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.count:SetPoint("BOTTOMLEFT", view.heading, "BOTTOMRIGHT", 10, 2)
    view.top = 4 + view.heading:GetStringHeight() + 6

    local search = Kit.AddSearchBox(frame, nil, L.SEARCH_CHANGES, function(text)
        filter = text ~= "" and strlower(text) or nil
        relayout()
    end)
    local box = Kit.AddLabeledCheck(frame, search, L.BY_MODULE, function(checked)
        byModule = checked
        showRelease(selected)
    end)
    box:SetChecked(byModule)

    page.empty = Kit.NewEmptyRow(page.list, LIST_WIDTH)
    Kit.AddEntry(page.list, page.empty, function()
        for i in ipairs(releases) do
            if releaseShown(i) then return false end
        end
        return true
    end)
    for i, release in ipairs(releases) do
        local row = Kit.NewListButton(page.list, function() return selected == i end)
        local version = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        version:SetPoint("LEFT", 8, 0)
        version:SetText(release.label)
        local date = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        date:SetPoint("RIGHT", -6, 0)
        date:SetText(release.date and release.date:sub(6) or "")
        row:SetScript("OnClick", function()
            if selected ~= i then showRelease(i) end
        end)
        page.rows[i] = row
        Kit.AddEntry(page.list, row, function() return releaseShown(i) end)
    end
    relayout()
end

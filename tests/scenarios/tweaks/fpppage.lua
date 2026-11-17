--[[
    Forever Gearbox - tests/scenarios/tweaks/fpppage.lua
    Forever Gearbox with Forever++ installed: an addon of its own (none of its modules on
    Forever++'s Modules page), Forever++ Integration off by default and Forever++ left alone then
    (no answers from it, no section on its pages); turned on, Quest Markers is a "Forever Gearbox"
    section on Quest Nameplates' page (UI/ForeverPage.lua) on a stand-in of the page as Forever++
    builds it (a canvas frame filled the first time it shows; a module's page made the first time
    it's picked, a stack of rows under its heading, the pane sized to it): its checkbox row (its
    own on/off), its options, laid out by the page's own stack; a page none of ours goes with gets
    nothing.
    Run by tests/run.lua (lua5.1 tests/run.lua fpppage), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
local Kit = ns.Kit
login()
W.RunTimers()

-- An addon of its own; the integration off by default.
eq(W.FPP.Module("QuestMarkers"), nil, "none of its modules on Forever++'s Modules page")
local fpp = ns.modules.ForeverPlusPlus
check(fpp ~= nil and not fpp.active, "Forever++ Integration: there with Forever++, off by default")
eq(ns.Plugin.Integrated(), false, "so Forever++ is left alone")
eq(ns.OtherAddons.ForeverPlusPlusOn("QuestNameplates"), nil, "nothing asked of it")
eq(ns.Attach.Target(ns.modules.QuestMarkers), nil, "no section on its pages")

ns:SetEnabled("ForeverPlusPlus", true)
W.RunTimers()
check(ns.Plugin.Integrated(), "turned on")
eq(ns.OtherAddons.ForeverPlusPlusOn("QuestNameplates"), true, "Forever++ answers now")

-- Forever++'s Modules page: built the first time it shows, as its canvasFrame does.
local page = W.NewFrame("Frame")
page:Hide()
local content
local function newView(title)
    local view = Kit.NewStack(content, 400, 4)
    view:CreateFontString():SetText(title)
    local enabledRow = W.NewFrame("Frame", nil, view)
    W.NewFrame("CheckButton", nil, enabledRow)
    Kit.AddEntry(view, enabledRow)
    Kit.Layout(view)
    content:SetHeight(view:GetHeight()) -- Forever++'s choose()
    return view
end
page:SetScript("OnShow", function(self)
    local listScroll = W.NewFrame("ScrollFrame", nil, self)
    local list = Kit.NewStack(listScroll, 186, 2)
    listScroll:SetScrollChild(list)
    local pane = W.NewFrame("ScrollFrame", nil, self)
    content = W.NewFrame("Frame", nil, pane)
    pane:SetScrollChild(content)
end)
Settings.RegisterCanvasLayoutCategory(page, "Forever++")
page:Show()

local function texts(view)
    local all = {}
    for _, entry in ipairs(view.entries) do
        for _, region in ipairs({ entry.frame:GetRegions() }) do
            if region:GetText() then all[#all + 1] = region:GetText() end
        end
    end
    return table.concat(all, "\n")
end

-- Quest Nameplates' page: our section, with Quest Markers.
local plates = newView("Quest Nameplates")
local joined = texts(plates)
check(joined:find(ns.L.PLUGIN_SECTION, 1, true) ~= nil, "a Forever Gearbox section on Quest Nameplates' page")
check(joined:find(ns.modules.QuestMarkers.title, 1, true) ~= nil, "with Quest Markers' row")
check(joined:find(ns.L.QMARK_SIDE, 1, true) ~= nil, "and its options")
check(#plates.entries > 5, "laid out in the page's own stack")
local box
for _, entry in ipairs(plates.entries) do
    for _, region in ipairs({ entry.frame:GetRegions() }) do
        if region:GetText() == ns.modules.QuestMarkers.title then
            for _, child in ipairs({ entry.frame:GetChildren() }) do
                if child._kind == "CheckButton" then box = child end
            end
        end
    end
end
check(box ~= nil, "its checkbox")
box:SetChecked(false)
box:Click()
check(not ns.modules.QuestMarkers.active, "turns Quest Markers off, its own on/off")
box:SetChecked(true)
box:Click()
check(ns.modules.QuestMarkers.active, "and on")

-- A page none of ours goes with: nothing.
local other = newView("Auto Repair")
eq(texts(other):find(ns.L.PLUGIN_SECTION, 1, true), nil, "nothing on a page none of ours goes with")
eq(#W.errors, 0, "no errors")
finish()

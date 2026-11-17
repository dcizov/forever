--[[
    Forever suite - tests/scenarios/core/suite.lua
    The two addons side by side: each carries the runtime (Shared/) in its own namespace, so
    neither reads or changes the other's (modules, saved variables, slashes, bindings), and there
    is no Forever Core. Forever Codex has the settings window and the minimap button, whose
    click opens the journal; Forever Gearbox has its own entry in Settings, with Forever++ installed
    too, and none of its modules on Forever++'s page. Also the member API's checks
    (Shared/Core/Members.lua).
    Run by tests/run.lua (lua5.1 tests/run.lua suite), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root

W.Strict()
local fc = W.LoadAddon(root, "ForeverCodex")
local ft = W.LoadAddon(root, "ForeverGearbox")
login()
check(rawget(_G, "ForeverCore") == nil, "no Forever Core")
check(fc ~= ft and fc.modules ~= ft.modules, "a namespace each")
eq(#fc.members, 1, "Codex is its own one member")
eq(fc.member.name, "ForeverCodex", "named after its folder")
eq(ft.member.name, "ForeverGearbox", "and Gearbox after its")
check(fc.modules.Journal and not ft.modules.Journal, "Codex's modules are its own")
check(ft.modules.FullBags and not fc.modules.FullBags, "and Gearbox' its own")
check(fc.modules.MinimapButton and not ft.modules.MinimapButton, "the minimap button is Codex's")
check(ForeverCodexDB.settings.Journal ~= nil, "Codex saves in its own table")
check(ForeverGearboxDB.settings.Journal == nil, "and not in Gearbox'")
check(W.FPP.Module("FullBags") == nil, "Gearbox' modules aren't on Forever++'s Modules page")
check(W.categories[ft.title] ~= nil, "Gearbox has its own entry in Settings, Forever++ installed or not")
check(W.FPP.Module("Journal") == nil, "nor Codex's")
eq(fc.title, "Forever Codex", "each says its own title")
eq(ft.title, "Forever Gearbox", "in chat")
check(ForeverGearbox_RunBinding ~= ForeverCodex_RunBinding, "a binding global each")
openEverything(fc)

-- Slashes: each speaks for its own modules.
W.chat = {}
W.Slash("/codex list")
check(W.ChatHas(fc.modules.Journal.title), "/codex list: Codex's modules")
check(not W.ChatHas(ft.modules.FullBags.title), "not Gearbox'")
check(W.chat[1]:find("Forever Codex", 1, true) ~= nil, "under Codex's name")
W.chat = {}
W.Slash("/fg list")
check(W.ChatHas("(FullBags)") and not W.ChatHas("(Journal)"), "/fg list: Gearbox' only")
W.chat = {}
W.Slash("/codex help")
check(W.ChatHas("/codex journal"), "/codex help shows Codex's commands under /codex")
W.Slash("/codex settings")
eq(fc.SettingsWindow.Current(), fc.member.short, "/codex settings opens Codex's page")
W.FPP.opened = nil
W.Slash("/fg settings")
eq(W.opened, ft.title, "/fg settings opens Gearbox' own entry")
W.Slash("/fg full bags")
eq(W.opened, ft.title, "/fg <module>: there, on that module")
eq(W.FPP.opened, nil, "never Forever++'s")

-- Codex's minimap button: click opens the journal, right-click the settings.
local button = ForeverCodexMinimapButton
check(button and button:IsShown(), "Codex's minimap button")
if rawget(_G, "ForeverCodexSettingsFrame") then ForeverCodexSettingsFrame:Hide() end
button:Fire("OnClick", "LeftButton")
check(ForeverCodexJournal and ForeverCodexJournal:IsShown(), "a click opens the journal")
eq(fc.SettingsWindow.Current(), nil, "and not the settings")
button:Fire("OnClick", "RightButton")
eq(fc.SettingsWindow.Current(), fc.title, "right-click opens the settings")
W.Slash("/codex")
check(not ForeverCodexJournal:IsShown(), "a bare /codex closes it again")

-- The member API refuses what it can't work with.
check(not pcall(fc.NewMember, fc, "ForeverCodex", fc, { title = "x", saved = "a", charSaved = "b" }),
    "an addon joins once")
check(not pcall(fc.NewMember, fc, "ForeverOther", {}, { title = "x", saved = "a", charSaved = "b" }),
    "with its own namespace")
check(not pcall(fc.NewModule, fc, "BadCategory", { category = "bags" }), "a module's category is its addon's")
finish()

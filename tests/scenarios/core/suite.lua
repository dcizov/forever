--[[
    Forever suite - tests/scenarios/core/suite.lua
    One member turned off in the game's AddOns list: Forever Core and Forever Compendium without
    Forever Tweaks. Each slash speaks for its own addon (/fc for Compendium's modules, /forever
    for all), /ft isn't there, the settings have a page for Compendium only, and the suite's
    minimap button opens the journal. Also the member API's checks (Core/Members.lua).
    Run by tests/run.lua (lua5.1 tests/run.lua suite), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local core = ForeverCore
eq(#core.members, 2, "the core and Compendium")
eq(ns.member, core.membersByName.ForeverCompendium, "a member's namespace knows its member")
eq(core.member, core.members[1], "the core is the first member")
check(rawget(ns, "NewModule") == nil and ns.NewModule == core.NewModule, "a member reads the core's namespace through its own")
check(rawget(ns, "Book") ~= nil and core.Book == nil, "what a member sets stays its own")
eq(ns.modules.Journal.member, ns.member, "a module belongs to the member that made it")
eq(core.modules.MinimapButton.member, core.member, "the core's own modules are the core's")
eq(ForeverCompendiumDB.settings.Journal ~= nil, true, "a member's module saves in the member's table")
check(ForeverCoreDB.settings.Journal == nil, "and not in the core's")
check(ForeverTweaksDB == nil, "Forever Tweaks off: none of its saved variables")
openEverything(ns)

-- Settings: a page for Compendium, none for Tweaks.
check(W.categories[ns.member.short] ~= nil, "a Compendium page")
check(W.categories.Tweaks == nil, "no Tweaks page")
ns:OpenSettings("Journal")
eq(W.opened, ns.member.short, "a Compendium module opens on its page")
ns:OpenSettings("MinimapButton")
eq(W.opened, core.title, "a core module opens on the top page")

-- Slashes: /fc lists Compendium's modules only, /forever every one; no /ft.
check(not pcall(W.Slash, "/ft list"), "no /ft without Forever Tweaks")
W.chat = {}
W.Slash("/fc list")
check(W.ChatHas(ns.modules.Journal.title), "/fc list: Compendium's modules")
check(not W.ChatHas(core.modules.MinimapButton.title), "but not the core's")
check(W.chat[1]:find("Forever Compendium", 1, true) ~= nil, "under Compendium's name")
W.chat = {}
W.Slash("/forever list")
check(W.ChatHas(ns.modules.Journal.title) and W.ChatHas(core.modules.MinimapButton.title), "/forever list: every module")
W.chat = {}
W.Slash("/fc help")
check(W.ChatHas("/fc journal"), "/fc help shows Compendium's commands under /fc")
W.Slash("/fc settings")
eq(W.opened, ns.member.short, "/fc settings opens Compendium's page")

-- The suite's minimap button: click opens the journal, right-click the settings.
local button = ForeverTweaksMinimapButton
check(button and button:IsShown(), "the suite's minimap button")
W.opened = nil
button:Fire("OnClick", "LeftButton")
check(ForeverCompendiumJournal and ForeverCompendiumJournal:IsShown(), "a click opens the journal")
eq(W.opened, nil, "and not the settings")
button:Fire("OnClick", "RightButton")
eq(W.opened, core.title, "right-click opens the settings")
W.Slash("/fc")
check(not ForeverCompendiumJournal:IsShown(), "a bare /fc closes it again")

-- The member API refuses what it can't work with.
check(not pcall(core.NewMember, core, "ForeverCompendium", {}, { title = "x", saved = "a", charSaved = "b" }),
    "a member joins once")
check(not pcall(core.NewMember, core, "ForeverOther", {}, { title = "x" }), "a member names its saved variables")
check(not pcall(ns.NewModule, ns, "BadCategory", { category = "bags" }), "a module's category is its member's")
finish()

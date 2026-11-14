--[[
    Forever Compendium - tests/scenarios/compendium/archive.lua
    The Archive: exports read back what they wrote (notes with "|" and line breaks included) as
    one paste-safe line, and refuse text that was cut or changed; an import is counted, asked
    about, and merged without doubling counts or losing your note; backups keep the three
    latest, and a restore puts the journal back as it was (after backing up the present).
    Run by tests/run.lua (lua5.1 tests/run.lua archive), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local Book, Codec, Archive, L = ns.Book, ns.Codec, ns.Archive, ns.L

-- The text: one line, nothing a chat box would eat, and checked when read back.
local wolf = Book.Meet(299, "Diseased Young Wolf")
wolf.kills, wolf.looted, wolf.loot, wolf.minLevel, wolf.maxLevel = 5, 4, { [750] = 2 }, 1, 2
wolf.note = "Watch out |cffff0000here|r\nsecond line"
wolf.pinned = true
wolf.zones = { [1429] = { cells = { [12] = 3 } } }
Book.SetItem(750, "Tough Wolf Meat", 1, 133970)
local text = Archive.Export()
check(text:find("^FC1:") ~= nil, "an export starts with its mark")
check(not text:find("|", 1, true) and not text:find("\n", 1, true), "and has no | or line break in it")
local data = Archive.Read(text)
eq(data and data.creatures[299].note, wolf.note, "a note reads back as it was")
eq(data and data.items[750].name, "Tough Wolf Meat", "with its items")
eq(Archive.Read(text:sub(1, -5)), nil, "a cut export is refused")
eq(Archive.Read(text:sub(1, 20) .. (text:sub(21, 21) == "A" and "B" or "A") .. text:sub(22)), nil, "a changed one too")
eq(Archive.Read("hello"), nil, "and anything else")
eq(Codec.Unarmor(Codec.Armor("x")), "x", "one byte round trip")
eq(Codec.Unarmor(Codec.Armor("xy")), "xy", "two bytes")
eq(Codec.Unarmor(Codec.Armor("xyz")), "xyz", "three bytes")
local one = Archive.Read(Archive.Export(299))
eq(Book.Count(one.creatures), 1, "one creature's export holds just it")

-- An import: counted, asked about, merged.
Book.Creatures()[299] = nil
local mine = Book.Meet(299, "Diseased Young Wolf")
mine.kills, mine.looted, mine.loot, mine.note = 2, 1, { [750] = 1 }, "my own note"
local other = Archive.Read(text)
other.creatures[300] = { name = "Kobold Vermin", kills = 1, zones = {}, loot = {} }
local creatures, new = Archive.Count(other)
eq(creatures .. "/" .. new, "2/1", "counted: two creatures, one new")
Archive.ShowImport()
ForeverCompendiumImport.edit:SetText(Archive.Read(text) and Codec.Armor(Codec.Encode(other)))
local popups = #W.popups
local importButton
for _, child in ipairs(rawget(ForeverCompendiumImport, "_children") or {}) do
    if child._text == L.ARCHIVE_IMPORT_BUTTON or (child.GetText and child:GetText() == L.ARCHIVE_IMPORT_BUTTON) then importButton = child end
end
check(importButton ~= nil, "an Import button")
importButton:Fire("OnClick")
eq(#W.popups, popups + 1, "asked before anything comes in")
eq(Book.Creature(300), nil, "nothing yet")
W.Accept()
eq(Book.Creature(300) and Book.Creature(300).name, "Kobold Vermin", "a new creature comes in")
eq(mine.kills, 5, "the larger kill count kept, not added")
eq(mine.looted, 4, "the loot of the book that looted more")
eq(mine.note, "my own note", "your note kept")
check(mine.pinned, "its pin")
eq(mine.zones[1429] and mine.zones[1429].cells[12], 3, "its places")
ForeverCompendiumImport.edit:SetText("not an export")
importButton:Fire("OnClick")
eq(ForeverCompendiumImport.status:GetText(), L.ARCHIVE_BAD, "bad text says so")

-- Backups: the three latest; a restore puts things back, the present backed up first.
for _ = 1, 4 do Archive.Backup() end
eq(#Archive.Backups(), 3, "three backups kept")
Archive.Backups()[1].creatures = 2
Book.Meet(301, "Kobold Laborer")
check(Archive.Restore(1), "restored")
eq(Book.Creature(301), nil, "a creature met since is gone")
check(Book.Creature(300) ~= nil, "what the backup had is back")
eq(#Archive.Backups(), 3, "still three")
eq(Archive.Backups()[1].creatures, 3, "the newest backup the journal as it was before the restore")
check(ns.modules.Archive:DebugLine():find("3 backups", 1, true) ~= nil, "Debug line")
finish()

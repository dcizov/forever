--[[
    Forever Codex - Archive
    Your journal as text, and copies of it kept in the saved variables:

      * Export: everything (or one creature) as one line of text (Codec.lua: base64 with a
        checksum, safe to paste anywhere), shown to copy. /codex export, or the gear menu at the journal's top.
      * Import: paste an export (yours from another account or install, or a friend's); what it
        holds is counted first and taken in only once you say so, merged into yours the way
        Book.MergeCreature does with `full` (counts never doubled, your notes kept). /codex paste
        (/codex import is the Bestiary Import's).
      * Backups: a copy of the whole journal, the BACKUPS latest kept: when you ask (/codex backup),
        once a week by itself at login (Automatic Backups), and before a restore. Restoring one
        puts the journal back exactly as it was then.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, format, time, table, date = pairs, ipairs, type, string.format, time, table, date
local Book, Codec, Kit = ns.Book, ns.Codec, ns.Kit

local BACKUPS = 3
local WEEK = 7 * 24 * 3600
local AUTO_WAIT = 15 -- seconds after login before the weekly backup is taken

local M = ns:NewModule("Archive", {
    title = L.ARCHIVE_TITLE,
    category = "data",
    description = L.ARCHIVE_DESC,
    added = "2.4.0",
    defaults = {
        autoBackup = true,
        backups = {}, -- data: { at, creatures, quests, items, data = Codec text }, newest first
    },
    options = {
        { key = "autoBackup", type = "checkbox", label = L.ARCHIVE_AUTO, tooltip = L.ARCHIVE_AUTO_TIP },
    },
})

local Archive = { module = M }
ns.Archive = Archive

---------------------------------------------------------------------------
-- What goes out
---------------------------------------------------------------------------

-- A creature's own part of the book: it, its quests and its items.
local function creaturePart(npcID)
    local rec = Book.Creature(npcID)
    if not rec then return nil end
    local quests, items = {}, {}
    for _, field in ipairs({ "starts", "ends", "quests" }) do
        for questID in pairs(rec[field] or {}) do quests[questID] = Book.Quest(questID) end
    end
    for _, field in ipairs({ "loot", "wares" }) do
        for itemID in pairs(rec[field] or {}) do items[itemID] = Book.Item(itemID) end
    end
    return { v = 1, creatures = { [npcID] = rec }, quests = quests, items = items }
end

local function wholeBook()
    return { v = 1, creatures = Book.Creatures(), quests = Book.Quests(), items = Book.Items() }
end

-- The export text: the whole journal, or creature `npcID`'s part of it.
function Archive.Export(npcID)
    local part = npcID and creaturePart(npcID) or wholeBook()
    return part and Codec.Armor(Codec.Encode(part))
end

-- An export read back: its tables; or nil and why: "header" (not a Codex export at all),
-- "damaged" (cut short or changed on the way), "version" (from a newer Forever Codex).
function Archive.Read(text)
    local plain, why = Codec.Unarmor(text)
    if not plain then return nil, why end
    local data = Codec.Decode(plain)
    if type(data) ~= "table" then return nil, "damaged" end
    if data.v ~= 1 then return nil, "version" end
    if type(data.creatures) ~= "table" then return nil, "damaged" end
    data.quests = type(data.quests) == "table" and data.quests or {}
    data.items = type(data.items) == "table" and data.items or {}
    return data
end

-- What an export holds: creatures, how many of them are new to you, quests, items.
function Archive.Count(data)
    local creatures, new = 0, 0
    for npcID in pairs(data.creatures) do
        creatures = creatures + 1
        if not Book.Creature(npcID) then new = new + 1 end
    end
    return creatures, new, Book.Count(data.quests), Book.Count(data.items)
end

-- Takes in an export (Archive.Read's), merged into yours. Returns how many creatures came in.
function Archive.Import(data)
    local count = 0
    for npcID, theirs in pairs(data.creatures) do
        if Book.MergeCreature(npcID, theirs, true) then count = count + 1 end
    end
    for questID, quest in pairs(data.quests) do Book.MergeQuest(questID, quest) end
    for itemID, item in pairs(data.items) do Book.MergeItem(itemID, item) end
    Book.Merged()
    return count
end

---------------------------------------------------------------------------
-- Backups
---------------------------------------------------------------------------

function Archive.Backups() return M.db.backups end

-- Keeps a copy of the whole journal now (the oldest beyond BACKUPS go).
function Archive.Backup()
    local list = M.db.backups
    table.insert(list, 1, { at = time(), creatures = Book.Count(Book.Creatures()), quests = Book.Count(Book.Quests()),
        items = Book.Count(Book.Items()), data = Codec.Encode(wholeBook()) })
    while #list > BACKUPS do table.remove(list) end
    return list[1]
end

-- Puts the journal back as backup `index` had it, after keeping a copy of how it is now.
-- Returns whether it could.
function Archive.Restore(index)
    local backup = M.db.backups[index]
    local data = backup and Codec.Decode(backup.data)
    if not data then return false end
    Archive.Backup()
    Book.Replace(data)
    Book.Merged()
    return true
end

-- "Nov 14, 2026 21:04: 211 creatures, 40 quests, 130 items"
function Archive.BackupLabel(backup)
    return format(L.ARCHIVE_BACKUP_LINE, date("%b %d, %Y %H:%M", backup.at), backup.creatures, backup.quests, backup.items)
end

local function autoBackup()
    local last = M.db.backups[1]
    if M.db.autoBackup and Book.Count(Book.Creatures()) > 0 and not (last and time() - last.at < WEEK) then
        Archive.Backup()
        M:Debug("weekly backup")
    end
end

---------------------------------------------------------------------------
-- The windows and the menu
---------------------------------------------------------------------------

function Archive.ShowExport(npcID)
    local text = Archive.Export(npcID)
    if not text then return end
    local rec = npcID and Book.Creature(npcID)
    Kit.ShowCopyWindow(rec and format(L.ARCHIVE_EXPORT_ONE, rec.name) or L.ARCHIVE_EXPORT_ALL, text)
end

local importWindow
local BAD_TEXT = { header = L.ARCHIVE_NOT_EXPORT, damaged = L.ARCHIVE_DAMAGED, version = L.ARCHIVE_NEWER }

local function tryImport()
    local text = importWindow.edit:GetText()
    local data, why = Archive.Read(text)
    if not data then
        importWindow.status:SetText(BAD_TEXT[why])
        return
    end
    local creatures, new, quests, items = Archive.Count(data)
    importWindow.status:SetText("")
    ns:Confirm(M, "FC_IMPORT", L.ARCHIVE_CONFIRM, function()
        local count = Archive.Import(data)
        importWindow:Hide()
        M:Reply(format(L.ARCHIVE_IMPORTED, count))
    end, format(L.ARCHIVE_HOLDS, creatures, new, quests, items))
end

function Archive.ShowImport()
    if not importWindow then
        local f = Kit.NewWindow("ForeverCodexImport", 560, 400)
        f:SetTitle(L.ARCHIVE_IMPORT_TITLE)
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 16, -32)
        hint:SetPoint("RIGHT", -16, 0)
        hint:SetJustifyH("LEFT")
        hint:SetText(L.ARCHIVE_IMPORT_HINT)
        local scroll, edit = Kit.NewTextBox(f, 500)
        scroll:SetPoint("TOPLEFT", 16, -56)
        scroll:SetPoint("BOTTOMRIGHT", -34, 44)
        f.edit = edit
        f.status = f:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
        f.status:SetPoint("BOTTOMLEFT", 136, 18)
        Kit.NewButton(f, L.ARCHIVE_IMPORT_BUTTON, 110, tryImport):SetPoint("BOTTOMLEFT", 12, 12)
        Kit.NewButton(f, CLOSE, 110, function() f:Hide() end):SetPoint("BOTTOMRIGHT", -12, 12)
        importWindow = f
    end
    importWindow.edit:SetText("")
    importWindow.status:SetText("")
    importWindow:Show()
    importWindow.edit:SetFocus()
end

local function confirmRestore(index)
    local backup = M.db.backups[index]
    if not backup then return end
    ns:Confirm(M, "FC_RESTORE", L.ARCHIVE_RESTORE_CONFIRM, function()
        if Archive.Restore(index) then M:Reply(L.ARCHIVE_RESTORED) end
    end, Archive.BackupLabel(backup))
end

-- The journal's gear menu (a dropdown's menu `root`; `npcID` the creature shown, or nil).
function Archive.FillMenu(root, npcID)
    root:CreateButton(L.ARCHIVE_EXPORT_ALL, function() Archive.ShowExport() end)
    if npcID and Book.Creature(npcID) then
        root:CreateButton(format(L.ARCHIVE_EXPORT_ONE, Book.Creature(npcID).name), function() Archive.ShowExport(npcID) end)
    end
    root:CreateButton(L.ARCHIVE_IMPORT_TITLE, Archive.ShowImport)
    root:CreateDivider()
    root:CreateButton(L.ARCHIVE_BACKUP_NOW, function()
        Archive.Backup()
        M:Reply(L.ARCHIVE_BACKED_UP)
    end)
    local list = root:CreateButton(L.ARCHIVE_RESTORE)
    if #M.db.backups == 0 then list:CreateTitle(L.ARCHIVE_NO_BACKUPS) end
    for i, backup in ipairs(M.db.backups) do
        list:CreateButton(Archive.BackupLabel(backup), function() confirmRestore(i) end)
    end
end

M:AddCommand("export", nil, L.CMD_EXPORT, function() Archive.ShowExport() end)
M:AddCommand("paste", nil, L.CMD_PASTE, Archive.ShowImport)
M:AddCommand("backup", nil, L.CMD_BACKUP, function()
    Archive.Backup()
    M:Reply(L.ARCHIVE_BACKED_UP)
end)

function M:OnEnable() self:After(AUTO_WAIT, autoBackup) end

function M:DebugLine()
    local last = M.db.backups[1]
    return format(L.ARCHIVE_DEBUG, #M.db.backups, last and date("%Y-%m-%d", last.at) or "-")
end

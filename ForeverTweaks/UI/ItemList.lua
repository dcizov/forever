--[[
    Forever Tweaks - UI/ItemList.lua
    A list of items to edit on a module's Settings pane (Vendor's Autobuy list, Full Bags' kept
    items): a row to add one, then a row per item with an on/off checkbox when the list has one,
    its icon and name, how many are in the bags when the list shows that, a box for its amount when
    the list keeps amounts, and a Remove button. One entry of the pane's stack that grows with the
    list, and fits however wide the pane is.

    Adding: drag an item from the bags onto the Item box (or click the box holding one), or type
    its name, its item ID, or paste its link; with amounts, type how many in the Amount box
    beside it; then Add (or Enter).

      ns.ItemList.Add(stack, opts) -> refresh()
        opts: owner (the module: its functions below run as its code, ns.RunCall), get() -> { [itemID] = amount (or true) }, add(itemID, amount), remove(itemID),
              setCount(itemID, n) (a list with amounts), defaultCount (the Amount box's start),
              have(itemID) -> count in the bags (shown red below the amount, green at or above it),
              isOn(itemID) and setOn(itemID, on) (a checkbox per row, to pause an item),
              addLabel, addTip, empty (text with no items)
    The pane lays itself out again after each change (Kit.Layout of `stack`).
]]

local _, ns = ...
local Kit, L = ns.Kit, ns.L

local ipairs, pairs, tonumber, sort = ipairs, pairs, tonumber, table.sort

local ItemList = {}
ns.ItemList = ItemList

local ROW = 30
local ICON = 22
local COUNT = 50  -- an amount box
local HAVE = 44   -- the count in the bags
local CHECK = 22  -- a row's on/off checkbox
local BUTTON = 78 -- Add and Remove
local GAP = 8

-- A whole number of at least 0 from what was typed, or nil ("20", " 20 "; not "2.5", "-1", "x").
function ItemList.ParseAmount(text)
    local digits = strtrim(text or ""):match("^%d+$")
    return digits and tonumber(digits)
end

-- An item ID from what was typed: a number, an item link or "item:123", or a name the game knows.
function ItemList.Parse(text)
    text = strtrim(text or "")
    if text == "" then return nil end
    local id = ItemList.ParseAmount(text) or tonumber(text:match("item:(%d+)"))
    if id then return id > 0 and id or nil end
    return (C_Item.GetItemInfoInstant(text))
end

local function itemName(id)
    local name = C_Item.GetItemNameByID(id)
    if name then return name end
    C_Item.RequestLoadItemDataByID(id)
    return "item:" .. id
end

local function newBox(parent, width, numeric)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    if numeric then box:SetNumeric(true) end
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

-- One item's row, made once and given an item each refresh. actions: remove(id), setCount(id, n)
-- (or nil for a list without amounts), setOn(id, on) (or nil without checkboxes); each refreshes
-- the list after. `have` is opts.have, for the count in the bags.
local function newRow(list, actions, have)
    local width = list:GetWidth()
    local row = CreateFrame("Frame", nil, list)
    row:SetSize(width, ROW)
    row:EnableMouse(true)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    if actions.setOn then
        row.on = Kit.NewCheckbox(row, CHECK, function(on) actions.setOn(row.itemID, on) end)
        row.on:SetPoint("LEFT", 2, 0)
        row.icon:SetPoint("LEFT", row.on, "RIGHT", 4, 0)
    else
        row.icon:SetPoint("LEFT", 4, 0)
    end
    local remove = Kit.NewButton(row, L.ITEMLIST_REMOVE, BUTTON, function() actions.remove(row.itemID) end)
    remove:SetPoint("RIGHT", -4, 0)
    local right = remove
    if actions.setCount then
        local box = newBox(row, COUNT, true)
        box:SetPoint("RIGHT", remove, "LEFT", -GAP - 4, 0)
        box:SetScript("OnEnterPressed", function(self)
            local n = ItemList.ParseAmount(self:GetText())
            if n and n > 0 then actions.setCount(row.itemID, n) end
            self:ClearFocus()
        end)
        row.count = box
        right = box
    end
    if have then
        row.have = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.have:SetWidth(HAVE)
        row.have:SetJustifyH("RIGHT")
        row.have:SetPoint("RIGHT", right, "LEFT", -GAP - 4, 0)
        right = row.have
    end
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", right, "LEFT", -GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

-- The row to add an item: the label over an Item box (taking a dragged item), an Amount box for a
-- list with amounts, and Add. Calls add(itemID, amount or nil).
local function newAddRow(list, opts, add)
    local top = CreateFrame("Frame", nil, list)
    top:SetSize(list:GetWidth(), 62)
    top:SetPoint("TOPLEFT")
    local label = top:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 4, -2)
    label:SetText(opts.addLabel)

    -- Add at the right, the Amount box left of it, the Item box taking the rest; small labels
    -- over the boxes.
    local function over(box, text)
        local small = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        small:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -4, 3)
        small:SetText(text)
    end
    local button = Kit.NewButton(top, L.ITEMLIST_ADD, BUTTON)
    button:SetPoint("BOTTOMRIGHT", -4, 4)
    local right, count = button, nil
    if opts.setCount then
        count = newBox(top, COUNT, true)
        count:SetPoint("RIGHT", button, "LEFT", -GAP - 4, 0)
        count:SetText(tostring(opts.defaultCount or 1))
        over(count, opts.have and L.ITEMLIST_WANT or L.ITEMLIST_AMOUNT)
        right = count
    end
    if opts.have then
        -- Over the rows' bag counts, which sit left of the amounts.
        local have = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        have:SetPoint("BOTTOMRIGHT", right, "TOPLEFT", -GAP - 4, 3)
        have:SetText(L.ITEMLIST_HAVE)
    end
    local item = newBox(top, 100, false)
    item:SetPoint("LEFT", top, "BOTTOMLEFT", 10, 15) -- level with the button's middle
    item:SetPoint("RIGHT", right, "LEFT", -GAP - 6, 0)
    over(item, L.ITEMLIST_ITEM)

    -- An item dropped on the box (or the box clicked while holding one) fills it in.
    local function takeCursorItem()
        local kind, id, link = GetCursorInfo()
        if kind ~= "item" then return end
        item:SetText(link or tostring(id))
        ClearCursor()
        if count then count:SetFocus() end
    end
    item:SetScript("OnReceiveDrag", takeCursorItem)
    item:HookScript("OnMouseDown", takeCursorItem)

    local function submit()
        local id = ItemList.Parse(item:GetText())
        if not id then
            ns:Print(L.ITEMLIST_UNKNOWN)
            return
        end
        local n
        if count then
            n = ItemList.ParseAmount(count:GetText())
            if not n or n < 1 then
                ns:Print(L.ITEMLIST_BAD_AMOUNT)
                return
            end
        end
        item:SetText("")
        item:ClearFocus()
        if count then count:ClearFocus() end
        add(id, n)
    end
    item:SetScript("OnEnterPressed", submit)
    if count then count:SetScript("OnEnterPressed", submit) end
    button:SetScript("OnClick", submit)
    Kit.AddTooltip(top, opts.addLabel, opts.addTip, item, button)
    return top
end

function ItemList.Add(stack, opts)
    local width = stack:GetWidth()
    local list = CreateFrame("Frame", nil, stack)
    list:SetWidth(width)
    local rows = {}

    local refresh
    local actions = {
        remove = function(id)
            ns.RunCall(opts.owner, "item list", opts.remove, id)
            refresh()
        end,
        setCount = opts.setCount and function(id, n)
            ns.RunCall(opts.owner, "item list", opts.setCount, id, n)
            refresh()
        end,
        setOn = opts.setOn and function(id, on)
            ns.RunCall(opts.owner, "item list", opts.setOn, id, on)
            refresh()
        end,
    }
    local top = newAddRow(list, opts, function(id, n)
        ns.RunCall(opts.owner, "item list", opts.add, id, n)
        refresh()
    end)
    local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 4, -6)
    empty:SetWidth(width - 8)
    empty:SetJustifyH("LEFT")
    empty:SetText(opts.empty)

    -- The module's readers, run as its code too: one that errors reads as nothing (the list
    -- still lays out).
    local function read(fn, ...) return ns.RunCall(opts.owner, "item list", fn, ...) end
    function refresh()
        local values = read(opts.get) or {}
        local ids = {}
        for id in pairs(values) do ids[#ids + 1] = id end
        sort(ids, function(a, b) return itemName(a) < itemName(b) end)
        for i, id in ipairs(ids) do
            local row = rows[i] or newRow(list, actions, opts.have)
            rows[i] = row
            row.itemID = id
            row.icon:SetTexture(C_Item.GetItemIconByID(id))
            row.name:SetText(itemName(id))
            if row.count and not row.count:HasFocus() then row.count:SetText(tostring(values[id])) end
            if row.on then
                -- A paused item stays listed, grayed out.
                local on = read(opts.isOn, id) and true or false
                row.on:SetChecked(on)
                row.icon:SetDesaturated(not on)
                if on then row.name:SetTextColor(1, 1, 1) else row.name:SetTextColor(0.5, 0.5, 0.5) end
            end
            if row.have then
                local n = read(opts.have, id) or 0
                row.have:SetText(tostring(n))
                local want = tonumber(values[id])
                if want and n < want then row.have:SetTextColor(1, 0.3, 0.3) else row.have:SetTextColor(0.3, 1, 0.3) end
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -(i - 1) * ROW)
            row:Show()
        end
        for i = #ids + 1, #rows do rows[i]:Hide() end
        empty:SetShown(#ids == 0)
        list:SetHeight(top:GetHeight() + math.max(#ids * ROW, empty:GetStringHeight() + 12))
        Kit.Layout(stack)
    end
    Kit.AddEntry(stack, list, nil, 6)
    refresh()
    return refresh
end

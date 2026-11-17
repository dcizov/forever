--[[
    Forever runtime - Shared/Settings/About.lua
    The About page, under the Forever page in the sidebar: the suite's icon, version and game
    build, what it is, how many modules are on (in all, and each member addon's), and links
    (LINKS below). The modules themselves are on each member's page (Shared/Settings/Modules.lua).
]]

local _, ns = ...
local Kit, L = ns.Kit, ns.L

local ipairs, pairs, format, tostring = ipairs, pairs, string.format, tostring

-- An entry without a url is left out.
local LINKS = {
    -- { label = "Website", url = "https://github.com/you/ForeverGearbox" },
}

function ns.BuildAboutPage(frame)
    local stack = Kit.NewRowPage(frame, L.ABOUT)

    -- Icon with the welcome, tagline and version lines beside it.
    local top = CreateFrame("Frame", nil, stack)
    top:SetSize(stack:GetWidth(), 84)
    local icon = top:CreateTexture(nil, "ARTWORK")
    icon:SetSize(76, 76)
    icon:SetPoint("TOPLEFT", 6, -6)
    icon:SetTexture(ns.icon)
    local welcome = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    welcome:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -2)
    welcome:SetText(format(L.ABOUT_WELCOME, ns.title))
    local notes = top:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    notes:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -6)
    notes:SetText(L.ABOUT_NOTES)
    local version, build, _, interface = GetBuildInfo()
    local info = top:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    info:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", 0, -6)
    info:SetJustifyH("LEFT")
    info:SetText(format(L.ABOUT_VERSION, ns.version, C_AddOns.GetAddOnMetadata(ns.name, "Author") or "?",
        tostring(version), tostring(build), tostring(interface)))
    Kit.AddEntry(stack, top, nil, 8)

    Kit.AddTextRow(stack, L.ABOUT_TEXT, "GameFontHighlight", 12)
    local count = Kit.AddTextRow(stack, "", "GameFontNormal", 12)
    -- Each member addon that's loaded, its version and how many of its modules are on.
    local memberRows = {}
    for _, member in ipairs(ns.members) do
        if member ~= ns.member then memberRows[member] = Kit.AddTextRow(stack, "", "GameFontHighlight", 4) end
    end

    if #LINKS > 0 then
        Kit.AddHeaderRow(stack, L.LINKS)
        for _, link in ipairs(LINKS) do
            if link.url and link.url ~= "" then Kit.AddCopyRow(stack, link.label, link.url) end
        end
    end

    local function update()
        local on, total = ns:CountModules()
        count.text:SetText(format(L.MODULES_ON, on, total))
        for member, row in pairs(memberRows) do
            local memberOn, memberTotal = ns:CountModules(member)
            row.text:SetText(format(L.ABOUT_MEMBER, member.title, member.version, memberOn, memberTotal))
        end
    end
    update()
    Kit.Layout(stack)
    frame:HookScript("OnShow", update)
end

local _, addon = ...
local M, W, T, L = addon.Appearance, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Global > Appearance: Font and Border Metal, set once for the suite, and the
-- modules that customize either, each with Back to suite.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local Refresh = function(refresh) page.refreshers[#page.refreshers + 1] = refresh end

    page:Group(L["Text Style"])
    -- The suite font in the shared font picker: its "appearance" is the global
    -- font, and a pick sets the global font.
    local owner = { suite = true }
    owner.db = setmetatable({}, { __index = function(_, key) if key == "appearance" then return M:FontAppearance() end end })
    function owner:GetFonts() return addon.Media:GetFonts() end
    function owner:CanConfigure() return not addon.InCombat() end
    function owner:SetAppearance(key, value)
        if key == "fontMedia" and type(value) == "string" and value:sub(1, 8) ~= "builtin:" then return M:SetFont("media:" .. value) end
        if key == "font" then return M:SetFont(value) end
    end
    local fontButton, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
    page.fontPicker = fontButton

    page:Group(L["Border"])
    local metals = addon.Style.EdgeMetalChoices()
    metals[1].label = L["Obsidian"]
    for _, choice in ipairs(metals) do choice.label = L[choice.label] end
    local metalRow = page:Row(L["Border Metal"], 48)
    page.metalPicker = W.Select(metalRow, nil, metals, function()
        local value = M:Metal()
        for _, choice in ipairs(metals) do if choice.id == value then return value, choice.label end end
        return value, metals[1].label
    end, function(id) M:SetMetal(id); page:Refresh() end)
    Refresh(function() page.metalPicker:Refresh() end)
    W.Tip(W.Label(page:Row("", 40), L["Every module's Font and Border Metal set to Suite follow these. A change applies after a reload."], nil, 0, -4, 420, T.muted))

    -- One row per module that could customize; shown while it does.
    page:Group(L["Customized"])
    page.customRows = {}
    local custom = {}
    Refresh(function()
        custom = {}
        for _, entry in ipairs(M:Customized()) do custom[entry.id] = entry end
    end)
    for _, id in ipairs(addon.moduleOrder) do
        local module = addon.modules[id]
        if not addon.Database.SUITE_SKIP[id] and not module.developer and id ~= "appearance" then
            local host = page:Row(module.title, 48)
            host.row.visibleWhen = function() return custom[id] ~= nil end
            local what = W.Label(host, "", nil, 0, 0, 200, T.muted)
            what:ClearAllPoints(); what:SetPoint("LEFT", 0, 0)
            local back = W.Button(host, L["Back to suite"], 120, 26, "secondary")
            back:SetPoint("RIGHT", 0, 0)
            back:SetScript("OnClick", function() M:BackToSuite(id); page:Refresh(); page:Layout() end)
            Refresh(function()
                local entry = custom[id]
                local parts = {}
                if entry and entry.font > 0 then parts[#parts + 1] = L["Font"] end
                if entry and entry.metal > 0 then parts[#parts + 1] = L["Border Metal"] end
                what:SetText(table.concat(parts, ", "))
            end)
            page.customRows[id] = { row = host.row, back = back, what = what }
        end
    end
    local none = W.Label(page:Row("", 40), L["Every module follows the suite."], nil, 0, -4, 420, T.muted)
    W.Tip(none)
    none:GetParent().row.visibleWhen = function() return next(custom) == nil end
    page.noneCustomized = none
    -- Which rows show depends on what the refresh found.
    local refresh = page.Refresh
    function page:Refresh() refresh(self); if self:IsShown() then self:Layout() end end
    page:Finish(); return page
end

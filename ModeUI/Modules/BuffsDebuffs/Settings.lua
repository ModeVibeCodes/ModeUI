local _, addon = ...
local M, W, T, L = addon.BuffsDebuffs, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of the bar being edited sits beside the tabs: Bars (which bar, what
-- it shows, how it grows), Look (icons, border, glow) and Blacklist. Pick the
-- bar at the top of Bars or Look; + New Bar adds one of your own. Bars move
-- in Edit Mode (the window header). SettingsBar.lua builds Bars and Look,
-- Blacklist.lua the Blacklist tab.

-- Control builders the settings files share. Each takes the host it fills.
function M:SettingsControls(page)
    local c = {}
    function c.Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    function c.When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    function c.Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    function c.SliderIn(host, range, get, set, suffix)
        c.Refresh(W.Slider(host, range[1], range[2], range[3], get, function(value) set(math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    function c.SelectIn(host, width, choices, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get()
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, tostring(value)
        end, set)
        c.Refresh(function() button:Refresh() end)
        return button
    end
    function c.Pills(title, list, get, set, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 96 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get, set)
        c.Refresh(refresh)
        return buttons
    end
    function c.Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do items[#items + 1] = { label = L[entry.label], get = entry.get, set = entry.set } end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    function c.Note(text, height)
        local host = page:Row("", height or 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, type(text) == "string" and L[text] or "", nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        if type(text) == "function" then c.Refresh(function() label:SetText(text()) end) end
        return W.Note(label)
    end
    return c
end

-- The bar being edited (and the preview's).
function M:EditingBar()
    if not (self.editingBar and self:HasBar(self.editingBar)) then self.editingBar = "buffs" end
    return self.editingBar
end
function M:BarChoices()
    local list = {}
    for _, id in ipairs(self:BarIds()) do list[#list + 1] = { id = id, label = self:BarLabel(id) } end
    return list
end

-- The bar picker with + New Bar, Delete and the name (custom bars), at the
-- top of a tab. Every tab's picker edits the same bar.
-- The dropdown spans its row, so the buttons sit on a row of their own (a
-- button beside it was pushed past the card's edge and clipped).
function M:BuildBarPicker(page, c)
    local select = c.SelectIn(page:Row(L["Bar"], 48), 200, function() return M:BarChoices() end,
        function() return M:EditingBar() end, page.SetEditing)
    local function Custom() return M:Custom(M:EditingBar()) ~= nil end
    local tools = page:Row("", 36)
    tools.rowLabel:Hide(); tools:ClearAllPoints(); tools:SetAllPoints(tools.row)
    local add = W.Button(tools, L["+ New Bar"], 110, 28, "secondary")
    add:SetPoint("LEFT", 0, 0)
    add:SetScript("OnClick", function()
        local id = M:AddCustomBar()
        if id then page.SetEditing(id) end
    end)
    local delete = W.Button(tools, L["Delete Bar"], 110, 28, "secondary")
    delete:SetPoint("LEFT", add, "RIGHT", 10, 0)
    delete:SetScript("OnClick", function()
        local id = M:EditingBar()
        W.Confirm(L["Delete Bar"], string.format(L["Delete %s? Its place and settings are forgotten."], M:BarLabel(id)), L["Delete"],
            function() if M:DeleteCustomBar(id) then page.SetEditing("buffs") end end)
    end)
    c.Refresh(function() add:SetEnabled(#M.db.customBars < M.MAX_CUSTOM); delete:SetShown(Custom()) end)
    c.When(Custom, function()
        local box = W.TextInput(page:Row(L["Name"], 48), 200, L["Bar name"], 40)
        box.onEnter = function(text) M:RenameCustomBar(M:EditingBar(), text); page:Refresh() end
        c.Refresh(function() if not box:HasFocus() then box:SetText(M:BarLabel(M:EditingBar())) end end)
    end)
    return select, add, delete
end

local NOTES = {
    buffs = "Stands in for Blizzard's buffs by the minimap: while it shows, Blizzard's own wait out of sight and this bar sits in their Edit Mode place. Right-click a buff to cancel it.",
    debuffs = "Stands in for Blizzard's debuffs by the minimap, private auras included.",
    playerBuffs = "Your Player frame's buffs (they moved here from Unit Frames).",
    playerDebuffs = "Your Player frame's debuffs (they moved here from Unit Frames).",
    playerImportant = "Boss and Important debuffs on you, a little bigger, just above Player Debuffs (All).",
}
function M:BarNote()
    return L[NOTES[self:EditingBar()] or "A bar of your own: pick what it shows, then place it in Edit Mode."]
end

function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local c = self:SettingsControls(page)
    function page.SetEditing(id)
        if M:HasBar(id) then M.editingBar = id; page:Refresh(); page:Layout(); M:RefreshPreview() end
    end
    page.configPreview = W.Preview(page, M, { contentHeight = 160 })
    if page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
    self:BuildBarsTab(page, c)
    self:BuildLookTab(page, c)
    self:BuildBlacklistTab(page, c)
    page:Section(L["Module"], nil, false)
    self:BuildTextGroup(page, c)
    page:Group(L["This Module"])
    local tools = page:Row(L["Settings"], 48)
    page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
    page.resetButton:SetPoint("LEFT")
    page.resetButton:SetScript("OnClick", function()
        W.Confirm(L["Reset to Defaults"], L["Put every bar, the blacklist and the text back to their defaults? Places stay."], L["Reset"],
            function() if M:ResetSettings() then page.SetEditing("buffs") end end)
    end)
    c.Note("Move a bar in Edit Mode (in the window header): drag it, nudge it, or pick Anchor To. Changes wait until you leave combat.", 48)
    W.SectionTabs(page)
    page:Finish(); return page
end

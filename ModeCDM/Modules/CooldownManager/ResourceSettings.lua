local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The resource bars' settings page, shown in the /mcdm window when a bar
-- under Resource Bars is chosen in its list; built the first time. A preview
-- of the bar (ResourcePreview.lua) above the tabs: Bar (here), Look, Text and
-- Visibility (ResourceSettingsLook.lua). Every bar keeps its own settings;
-- Group Resources is one choice shared by Power, Combo Points and Alternate
-- Mana.
function M:CreateResourcePage(parent)
    local page = W.Page(parent, 480); self.resourcePage = page
    local ui = {}
    local function Id() return M:ResourceEditing() end
    local function db() return M.db.resources[Id()] end
    ui.Id, ui.db = Id, db
    function ui.Segmented() return M.resourceSpecs[Id()].segmented == true end
    function ui.InBlock() return M:ResourceInBlock(Id()) end
    page.resourceEditing = Id
    function page.SetEditing(id)
        if not M:IsResource(id) then return end
        M.selectedResource = id
        page:Refresh(); page:Layout()
        if page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
    end
    local owner = self:ResourceAppearanceOwner(Id)
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetResourceOption(Id(), key, value) end end
    ui.Refresh, ui.Set = Refresh, Set
    function ui.When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    function ui.Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    function ui.Slider(host, key, suffix, get, set, range)
        range = range or M.resourceRanges[key]
        Refresh(W.Slider(host, range[1], range[2], range[3], get or function() return db()[key] or range[1] end,
            set or function(value) M:SetResourceOption(Id(), key, math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    function ui.Select(host, width, choices, key, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get and get() or db()[key]
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, tostring(value)
        end, set or Set(key))
        Refresh(function() button:Refresh() end)
        return button
    end
    function ui.Pills(title, list, key, width, get, set)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 110 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get or function() return db()[key] end, set or Set(key))
        Refresh(refresh)
        return buttons
    end
    function ui.Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = function() return db()[entry[2]] end, set = Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    function ui.Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    function ui.Note(text, height)
        local host = page:Row("", height or 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return W.Note(label)
    end
    function ui.Button(label, width, onClick)
        local host = page:Row("", 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local button = W.Button(host, L[label], width, 30, "secondary")
        button:SetPoint("LEFT"); button:SetScript("OnClick", onClick)
        return button
    end
    function ui.Tab(title, build)
        page:Section(L[title], nil, false)
        if title ~= "Bar" then
            ui.When(function() return not db().show end, function() W.Tip(ui.Note("This bar is off. Turn on Show Bar on the Bar tab to use it.")) end)
        end
        build()
    end
    ui.owner = owner

    W.Preview(page, self:ResourcePreviewOwner(), { contentHeight = 90 })
    -- Editing: which bar this page shows, at the top right of the preview.
    self:AddEditingCorner(page)

    ui.Tab("Bar", function()
        page.resourceShowToggles = ui.Toggles({ { "Show Bar", "show" } })
        local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        Refresh(function() status:SetText(M:ResourceStatus(Id())) end)
        page.resourceStatus = status
        -- Group Resources: one border for Power, Combo Points and Alternate Mana.
        ui.When(function() return M.resourceSpecs[Id()].group == true end, function()
            page:Group(L["Resources"])
            page.resourceLayoutPills = ui.Pills("Layout", M.resourceChoices.resourceLayout, nil, 170,
                function() return M.db.resourceLayout end, function(value) M:SetResourceLayout(value) end)
        end)
        page:Group(L["Size"])
        ui.When(function() return not ui.InBlock() end, function()
            local size = ui.Columns({ "Width" })
            page.resourceWidthSlider = ui.Slider(size[1], "width", "px")
        end)
        local tall = ui.Columns({ "Height" })
        page.resourceHeightSlider = ui.Slider(tall[1], "height", "px")
        ui.When(ui.InBlock, function() W.Tip(ui.Note("Grouped: the block takes Power's width, border and place.")) end)
        -- Combo Points: Grouped (one border, a line between points) or Separated.
        ui.When(ui.Segmented, function()
            page:Group(L["Combo Points"])
            page.resourceComboLayoutPills = ui.Pills("Layout", M.resourceChoices.layout, "layout", 120)
            ui.When(function() return db().layout == "separated" and not ui.InBlock() end, function()
                local points = ui.Columns({ "Spacing" })
                page.resourceSpacingSlider = ui.Slider(points[1], "spacing", "px")
            end)
            ui.When(function() return db().layout == "grouped" or ui.InBlock() end, function()
                local lines = ui.Columns({ "Divider Width", "Divider Color" })
                page.resourceDividerSlider = ui.Slider(lines[1], "dividerWidth", "px")
                ui.Color(lines[2], "dividerColor")
            end)
        end)
        -- Tick Marks: a line at a power value, for one power type.
        ui.When(function() return M.resourceSpecs[Id()].marks == true end, function()
            page:Group(L["Tick Marks"])
            page.resourceMarkSliders = {}
            for i = 1, M.MARK_SLOTS do
                local cells = ui.Columns({ string.format(L["Tick %d"], i), "Shows On" })
                page.resourceMarkSliders[i] = ui.Slider(cells[1], nil, nil, function() local marks = db().marks; return marks and marks[i].value or 0 end,
                    function(value) M:SetResourceMark(Id(), i, "value", math.floor(value + 0.5)) end, M.MARK_RANGE)
                ui.Select(cells[2], 160, function() return M.resourceChoices.markPower end, nil,
                    function() local marks = db().marks; return marks and marks[i].power or "any" end, function(value) M:SetResourceMark(Id(), i, "power", value) end)
            end
            local look = ui.Columns({ "Tick Width", "Tick Color" })
            ui.Slider(look[1], "markWidth", "px")
            ui.Color(look[2], "markColor")
            W.Tip(ui.Note("0 turns a tick off. A tick shows only while its power type is shown."))
        end)
        page:Group(L["Placement"])
        local edit = page:Row(L["Edit Mode"], 48)
        page.resourceEditModeButton = W.Button(edit, L["Open Edit Mode"], 160, 30, "secondary")
        page.resourceEditModeButton:SetPoint("LEFT"); page.resourceEditModeButton:SetScript("OnClick", function() addon:SetEditMode(true) end)
        page:Group(L["Reset"])
        page.resourceResetButton = ui.Button("Reset to Defaults", 150, function() M:ResetResource(Id()) end)
    end)

    self:BuildResourceLookTabs(page, ui)
    W.SectionTabs(page)
    page:Finish(); return page
end

-- One Tick Mark's value or power type.
function M:SetResourceMark(id, index, key, value)
    local marks = addon.ProfileCodec.Copy(self.db.resources[id].marks)
    if type(marks) ~= "table" or type(marks[index]) ~= "table" then return false end
    marks[index][key] = value
    return self:SetResourceOption(id, "marks", marks)
end

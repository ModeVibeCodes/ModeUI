local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The resource bars' settings page, shown in the /mcdm window when a bar
-- under Resource Bars is chosen in its list; built the first time. A preview
-- of the bar (ResourcePreview.lua) above the tabs: Bar, Look, Text and
-- Visibility. Every bar keeps its own settings.
function M:CreateResourcePage(parent)
    local page = W.Page(parent, 480); self.resourcePage = page
    local function Id() return M:ResourceEditing() end
    local function db() return M.db.resources[Id()] end
    local function Segmented() return M.resourceSpecs[Id()].segmented == true end
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
    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    local function Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    local function Slider(host, key, suffix)
        local range = M.resourceRanges[key]
        Refresh(W.Slider(host, range[1], range[2], range[3], function() return db()[key] end,
            function(value) M:SetResourceOption(Id(), key, math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    local function Select(host, width, choices, key)
        local button = W.Select(host, width, choices, function()
            local value = db()[key]
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, tostring(value)
        end, Set(key))
        Refresh(function() button:Refresh() end)
        return button
    end
    local function Pills(title, list, key, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 110 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, function() return db()[key] end, Set(key))
        Refresh(refresh)
        return buttons
    end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = function() return db()[entry[2]] end, set = Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    local function Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    local function Note(text, height)
        local host = page:Row("", height or 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return W.Note(label)
    end
    local function Button(label, width, onClick)
        local host = page:Row("", 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local button = W.Button(host, L[label], width, 30, "secondary")
        button:SetPoint("LEFT"); button:SetScript("OnClick", onClick)
        return button
    end
    local function Tab(title, build)
        page:Section(L[title], nil, false)
        if title ~= "Bar" then
            When(function() return not db().show end, function() W.Tip(Note("This bar is off. Turn on Show Bar on the Bar tab to use it.")) end)
        end
        build()
    end

    W.Preview(page, self:ResourcePreviewOwner(), { contentHeight = 90 })
    -- Editing: which bar this page shows, at the top right of the preview.
    self:AddEditingCorner(page)

    Tab("Bar", function()
        page.resourceShowToggles = Toggles({ { "Show Bar", "show" } })
        local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        Refresh(function() status:SetText(M:ResourceStatus(Id())) end)
        page.resourceStatus = status
        page:Group(L["Size"])
        local size = Columns({ "Width", "Height" })
        page.resourceWidthSlider = Slider(size[1], "width", "px")
        page.resourceHeightSlider = Slider(size[2], "height", "px")
        page.resourceMatchToggles = Toggles({ { "Match Width", "matchWidth" } })
        When(Segmented, function()
            local points = Columns({ "Spacing" })
            page.resourceSpacingSlider = Slider(points[1], "spacing", "px")
        end)
        page:Group(L["Placement"])
        local edit = page:Row(L["Edit Mode"], 48)
        page.resourceEditModeButton = W.Button(edit, L["Open Edit Mode"], 160, 30, "secondary")
        page.resourceEditModeButton:SetPoint("LEFT"); page.resourceEditModeButton:SetScript("OnClick", function() addon:SetEditMode(true) end)
        page:Group(L["Reset"])
        page.resourceResetButton = Button("Reset to Defaults", 150, function() M:ResetResource(Id()) end)
    end)

    Tab("Look", function()
        page:Group(L["Border"])
        page.resourceBorderPills = Pills("Border", M.resourceChoices.border, "border", 96)
        page:Group(L["Bar"])
        local texture = Columns({ "Bar Texture", "Bar Color" })
        page.resourceTextureSelect = Select(texture[1], 200, function() return addon.Kit.BarTextureChoices(true) end, "barTexture")
        page.resourceColorSelect = Select(texture[2], 200, function() return M:ResourceColorChoices(Id()) end, "colorMode")
        When(function() return db().colorMode == "custom" end, function()
            local custom = Columns({ "Custom Color" })
            Color(custom[1], "barColor")
        end)
        local fill = Columns({ "Bar Opacity" })
        page.resourceBarOpacitySlider = Slider(fill[1], "barOpacity", "%")
        local back = Columns({ "Bar Background", "Background Opacity" })
        page.resourceBackgroundSelect = Select(back[1], 200, function() return addon.Kit.BarTextureChoices(false) end, "barBackground")
        page.resourceBackgroundSlider = Slider(back[2], "barBackgroundOpacity", "%")
        page:Group(L["Fill"])
        page.resourceDirectionPills = Pills("Fill Direction", M.resourceChoices.reverse, "reverse", 120)
        When(function() return not Segmented() end, function()
            page.resourceFillToggles = Toggles({ { "Smooth", "smooth" }, { "Fill End Line", "fillEdge" } })
        end)
    end)

    Tab("Text", function()
        page:Group(L["Text"])
        local which = Columns({ "Text" })
        page.resourceTextSelect = Select(which[1], 220, function() return M:ResourceTextChoices(Id()) end, "text")
        When(function() return db().text ~= "none" end, function()
            page.resourceAnchorPills = Pills("Anchor", M.resourceChoices.textAnchor, "textAnchor", 90)
            local place = Columns({ "Size", "Offset X", "Offset Y" })
            page.resourceTextSizeSlider = Slider(place[1], "textSize")
            Slider(place[2], "textX", "px"); Slider(place[3], "textY", "px")
            local color = Columns({ "Text Color" })
            Color(color[1], "textColor")
        end)
        page:Group(L["Font"])
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
        page.resourceFontToggles = Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" }, { "Slug Text", "slug" } })
    end)

    Tab("Visibility", function()
        page:Group(L["Visibility"])
        local show = Columns({ "Show" })
        page.resourceVisibilitySelect = Select(show[1], 240, function() return M.resourceChoices.visibility end, "visibility")
        local opacity = Columns({ "Opacity", "Faded Opacity" })
        page.resourceOpacitySlider = Slider(opacity[1], "opacity", "%")
        Slider(opacity[2], "fadeOpacity", "%")
    end)

    W.SectionTabs(page)
    page:Finish(); return page
end

local _, addon = ...
local M, W, T, L = addon.PartyFrames, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview sits above the tabs (Layout, Bars, Text and Icons, Highlights,
-- Auras): one member by default, a party or raid sizes from its header
-- buttons, and on the Auras tab the group being edited. Clicking a part of it
-- jumps to that part's settings. Cards of related settings, side by side where
-- they fit, on the shared Mode widgets. Text and Icons and Highlights are in
-- SettingsElements.lua, the Auras tab in SettingsAuras.lua.

-- Control builders shared by the settings files. Each takes the host it
-- fills: a row, or one cell of Columns.
function M:SettingsControls(page)
    local c = {}
    local owner = self:AppearanceOwner()
    c.owner = owner
    function c.Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    function c.When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    function c.Mark(target) local row = page.rows[#page.rows]; page.jumpTargets[target] = { section = row.section, row = row } end
    function c.SliderIn(host, range, get, set, suffix)
        c.Refresh(W.Slider(host, range[1], range[2], range[3], get, function(value) set(math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    function c.Set(key) return function(value) M:SetOption(key, value) end end
    function c.Slider(host, key, suffix) return c.SliderIn(host, M.ranges[key], function() return M.db[key] end, c.Set(key), suffix) end
    function c.SelectIn(host, width, choices, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get()
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, tostring(value)
        end, set)
        c.Refresh(function() button:Refresh() end)
        return button
    end
    function c.Select(host, width, list, key) return c.SelectIn(host, width, function() return list end, function() return M.db[key] end, c.Set(key)) end
    function c.Texture(host, key, choices) return c.SelectIn(host, 200, choices, function() return M.db[key] end, c.Set(key)) end
    function c.Pills(title, list, get, set, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 96 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get, set)
        c.Refresh(refresh)
        return buttons
    end
    function c.Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            local key = entry[2]
            items[#items + 1] = { label = L[entry[1]], get = entry.get or function() return M.db[key] end, set = entry.set or c.Set(key) }
        end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    function c.Color(host, key, enabled, getOwner) W.ColorRow(page, getOwner or owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    function c.Note(text, height)
        local host = page:Row("", height or 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return label
    end
    function c.Anchor(title, get, set)
        local labels = setmetatable({}, { __index = function(_, key) return L[M.anchorLabels[key] or key] end })
        local buttons, refresh = W.AnchorPicker(page:Row(L[title], W.ANCHOR_PICKER_HEIGHT + 16), get, set, labels, { center = true })
        c.Refresh(refresh)
        return buttons
    end
    function c.Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    -- One pixel at a time: arrows that move an offset pair (owner: nudge
    -- auras, texts and icons into perfect alignment).
    function c.Nudge(getX, getY, setX, setY, range)
        return W.Nudge(page:Row(L["Nudge"], 40), getX, getY, setX, setY, range)
    end
    return c
end

function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    page.jumpTargets = {}
    local c = self:SettingsControls(page)
    local element, auraGroup, dispelType = "name", "heals", "Magic"
    page.partyElement = function() return element end
    page.partyAuraGroup = function() return auraGroup end
    page.partyDispelType = function() return dispelType end
    function page.SetElement(id) if M.elementDefaults[id] then element = id; page:Refresh(); page:Layout() end end
    function page.SetAuraGroup(id) if M.auraDefaults[id] then auraGroup = id; page:Refresh(); page:Layout() end end
    function page.SetDispelType(id) if M.dispelColorKeys[id] then dispelType = id; page:Refresh(); page:Layout() end end
    page.configPreview = W.Preview(page, M, { contentHeight = M.PREVIEW_HEIGHT })
    if page.UpdatePreviewLayout then
        page.previewHeaderButtons = M:PreviewSampleButtons(page)
        page:UpdatePreviewLayout()
    end

    page:Section(L["Layout"], nil, false)
    page:Group(L["Group"])
    page.layoutToggles = c.Toggles({ { "Show Yourself", "showPlayer" }, { "Show When Solo", "showSolo" },
        { "Reverse Order", "reverseOrder" }, { "Hide Blizzard's Party Frames", "hideBlizzard" } })
    page.sortPills = c.Pills("Sort By", M.choices.sortBy, function() return M.db.sortBy end, c.Set("sortBy"), 120)
    page.growthPills = c.Pills("Grow", M.choices.growth, function() return M.db.growth end, c.Set("growth"), 80)
    local group = c.Columns({ "Spacing", "Scale" })
    page.spacingSlider = c.Slider(group[1], "spacing", "px"); page.scaleSlider = c.Slider(group[2], "scale", "%")
    c.Note("Role sorts tanks, then healers, then damage. Party frames show in a party, not a raid. Move them with Edit Mode in the window header; resizing keeps the corner they grow from in place.", 48)
    page:Group(L["Size and Border"])
    local size = c.Columns({ "Width", "Health Height" })
    page.widthSlider = c.Slider(size[1], "width", "px"); page.healthHeightSlider = c.Slider(size[2], "healthHeight", "px")
    page.borderPills = c.Pills("Border", M.choices.borderStyle, function() return M.db.borderStyle end, c.Set("borderStyle"), 96)
    local corner = c.Columns({ "Corner Size" })
    page.cornerSlider = c.Slider(corner[1], "corner", "px")
    c.Note("Thin is the ModeUI border one pixel wide, for pixel-perfect rows: with Spacing 1 the members sit one pixel apart.", 32)
    page:Group(L["Power Bar"])
    page.powerSelect = c.Select(page:Row(L["Power Bar For"], 48), 200, M.choices.powerShown, "powerShown"); c.Mark("power")
    c.When(function() return M.db.powerShown ~= "none" end, function()
        page.powerStylePills = c.Pills("Style", M.choices.powerStyle, function() return M.db.powerStyle end, c.Set("powerStyle"), 120)
        local power = c.Columns({ "Power Height" })
        page.powerHeightSlider = c.Slider(power[1], "powerHeight", "px")
        c.When(function() return M.db.powerStyle == "inset" end, function()
            local inset = c.Columns({ "Power Width" })
            page.powerWidthSlider = c.Slider(inset[1], "powerWidth", "%")
            page.powerAlignPills = c.Pills("Alignment", M.choices.powerAlign, function() return M.db.powerAlign end, c.Set("powerAlign"), 80)
            local offset = c.Columns({ "Offset X", "Offset Y" })
            c.Slider(offset[1], "powerX", "px"); c.Slider(offset[2], "powerY", "px")
            page.powerNudge = c.Nudge(function() return M.db.powerX end, function() return M.db.powerY end,
                c.Set("powerX"), c.Set("powerY"), M.ranges.powerX)
        end)
    end)
    c.Note("Mana Users shows power only on members whose power is mana; Healer Mana only on healers with mana, hiding everyone else's. Inset sits on the health bar in a border of its own.", 48)
    page:Group(L["This Module"])
    local tools = page:Row(L["Settings"], 48)
    page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
    page.resetButton:SetPoint("LEFT"); page.resetButton:SetScript("OnClick", function() M:ResetSettings() end)

    page:Section(L["Bars"], nil, false)
    page:Group(L["Health"])
    local health = c.Columns({ "Health Color", "Custom Color" })
    page.healthColorSelect = c.Select(health[1], 200, M.choices.healthColorMode, "healthColorMode"); c.Mark("health")
    c.Color(health[2], "healthColor", function() return M.db.healthColorMode == "custom" end)
    local textures = c.Columns({ "Foreground", "Background" })
    page.foregroundSelect = c.Texture(textures[1], "foregroundTexture", function() return M.TextureChoices(true) end)
    page.backgroundSelect = c.Texture(textures[2], "backgroundTexture", function() return M.TextureChoices(false) end)
    local fade = c.Columns({ "Bar Opacity", "Background Opacity" })
    page.healthOpacitySlider = c.Slider(fade[1], "healthOpacity", "%"); page.backgroundOpacitySlider = c.Slider(fade[2], "backgroundOpacity", "%")
    page.fillPills = c.Pills("Fill", M.choices.fillDirection, function() return M.db.fillDirection end, c.Set("fillDirection"), 120)
    page.fillToggles = c.Toggles({ { "Fill End Line", "fillEdge" } })
    page:Group(L["Power"])
    local power = c.Columns({ "Power Color", "Custom Color" })
    page.powerColorSelect = c.Select(power[1], 200, M.choices.powerColorMode, "powerColorMode")
    c.Color(power[2], "powerColor", function() return M.db.powerColorMode == "custom" end)
    local powerTextures = c.Columns({ "Foreground", "Background" })
    c.Texture(powerTextures[1], "powerForegroundTexture", function() return M.TextureChoices(true) end)
    c.Texture(powerTextures[2], "powerBackgroundTexture", function() return M.TextureChoices(false) end)
    page:Group(L["Heals and Shields"])
    page.predictionToggles = c.Toggles({ { "Incoming Heals", "showHealPrediction" }, { "Shields", "showAbsorbs" },
        { "Overshields", "showOvershields" } })
    for _, row in ipairs({ { "Heal", "healTexture", "healPredictionColor", "healPredictionOpacity" },
        { "Shield", "shieldTexture", "absorbColor", "absorbOpacity" }, { "Overshield", "overshieldTexture", "overshieldColor", "overshieldOpacity" } }) do
        local cells = c.Columns({ row[1] .. " Texture", row[1] .. " Color", row[1] .. " Opacity" })
        c.Texture(cells[1], row[2], M.FillChoices); c.Color(cells[2], row[3]); c.Slider(cells[3], row[4], "%")
    end
    c.Note("Shields ride on the end of the health. Overshields fill back from full health with the whole shield, shown while it is bigger than the missing health. Mode Slate Hatch draws crisp 1px lines at any size.", 48)

    self:BuildElementsTab(page, c, function() return element end)
    self:BuildHighlightsTab(page, c, function() return dispelType end)
    self:BuildAuraTab(page, c, function() return auraGroup end)

    W.SectionTabs(page)
    -- The preview follows the open tab (the Auras tab shows its group).
    local select = page.SelectSectionTab
    function page:SelectSectionTab(...)
        select(self, ...)
        if self.configPreview and self.configPreview.Refresh then self.configPreview:Refresh() end
        self:Refresh()
    end
    page:Finish(); return page
end

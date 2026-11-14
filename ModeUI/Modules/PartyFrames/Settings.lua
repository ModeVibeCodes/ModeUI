local _, addon = ...
local M, W, T, L = addon.PartyFrames, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of the sample party sits above the tabs (Layout, Bars, Text and
-- Icons, Highlights, Auras); clicking a part of it jumps to that part's
-- settings. Cards of related settings, side by side where they fit, on the
-- shared Mode widgets. The Auras tab is in SettingsAuras.lua.

-- Control builders shared by both settings files. Each takes the host it
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
    function c.Slider(host, key, suffix)
        return c.SliderIn(host, M.ranges[key], function() return M.db[key] end, function(v) M:SetOption(key, v) end, suffix)
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
    function c.Select(host, width, list, key)
        return c.SelectIn(host, width, function() return list end, function() return M.db[key] end, function(v) M:SetOption(key, v) end)
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
        for _, entry in ipairs(entries) do
            local key = entry[2]
            items[#items + 1] = { label = L[entry[1]], get = entry.get or function() return M.db[key] end,
                set = entry.set or function(value) M:SetOption(key, value) end }
        end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    function c.Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
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
    return c
end

function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    page.jumpTargets = {}
    local c = self:SettingsControls(page)
    local element, auraGroup = "name", "buffs"
    page.partyElement = function() return element end
    page.partyAuraGroup = function() return auraGroup end
    function page.SetElement(id) if M.elementDefaults[id] then element = id; page:Refresh(); page:Layout() end end
    function page.SetAuraGroup(id) if M.auraDefaults[id] then auraGroup = id; page:Refresh(); page:Layout() end end
    page.configPreview = W.Preview(page, M, { contentHeight = M.PREVIEW_HEIGHT })

    page:Section(L["Layout"], nil, false)
    page:Group(L["Group"])
    page.layoutToggles = c.Toggles({ { "Show Yourself", "showPlayer" }, { "Show When Solo", "showSolo" },
        { "Reverse Order", "reverseOrder" }, { "Hide Blizzard's Party Frames", "hideBlizzard" } })
    page.sortPills = c.Pills("Sort By", M.choices.sortBy, function() return M.db.sortBy end, function(v) M:SetOption("sortBy", v) end, 120)
    page.growthPills = c.Pills("Grow", M.choices.growth, function() return M.db.growth end, function(v) M:SetOption("growth", v) end, 80)
    local group = c.Columns({ "Spacing", "Scale" })
    page.spacingSlider = c.Slider(group[1], "spacing", "px"); page.scaleSlider = c.Slider(group[2], "scale", "%")
    c.Note("Role sorts tanks, then healers, then damage. Party frames show in a party, not a raid. Move them with Edit Mode in the window header.", 32)
    page:Group(L["Size"])
    local size = c.Columns({ "Width", "Health Height" })
    page.widthSlider = c.Slider(size[1], "width", "px"); page.healthHeightSlider = c.Slider(size[2], "healthHeight", "px")
    page.powerPills = c.Pills("Power Bar For", M.choices.powerShown, function() return M.db.powerShown end, function(v) M:SetOption("powerShown", v) end, 100)
    c.When(function() return M.db.powerShown ~= "none" end, function()
        local power = c.Columns({ "Power Height" })
        page.powerHeightSlider = c.Slider(power[1], "powerHeight", "px")
    end)
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
    page.foregroundSelect = c.SelectIn(textures[1], 200, function() return M.TextureChoices(true) end,
        function() return M.db.foregroundTexture end, function(v) M:SetOption("foregroundTexture", v) end)
    page.backgroundSelect = c.SelectIn(textures[2], 200, function() return M.TextureChoices(false) end,
        function() return M.db.backgroundTexture end, function(v) M:SetOption("backgroundTexture", v) end)
    local fade = c.Columns({ "Bar Opacity", "Background Opacity" })
    page.healthOpacitySlider = c.Slider(fade[1], "healthOpacity", "%"); page.backgroundOpacitySlider = c.Slider(fade[2], "backgroundOpacity", "%")
    page.fillPills = c.Pills("Fill", M.choices.fillDirection, function() return M.db.fillDirection end, function(v) M:SetOption("fillDirection", v) end, 120)
    page.fillToggles = c.Toggles({ { "Fill End Line", "fillEdge" } })
    page:Group(L["Power"])
    local power = c.Columns({ "Power Color", "Custom Color" })
    page.powerColorSelect = c.Select(power[1], 200, M.choices.powerColorMode, "powerColorMode"); c.Mark("power")
    c.Color(power[2], "powerColor", function() return M.db.powerColorMode == "custom" end)
    local powerTextures = c.Columns({ "Foreground", "Background" })
    c.SelectIn(powerTextures[1], 200, function() return M.TextureChoices(true) end,
        function() return M.db.powerForegroundTexture end, function(v) M:SetOption("powerForegroundTexture", v) end)
    c.SelectIn(powerTextures[2], 200, function() return M.TextureChoices(false) end,
        function() return M.db.powerBackgroundTexture end, function(v) M:SetOption("powerBackgroundTexture", v) end)
    page:Group(L["Heals and Absorbs"])
    page.predictionToggles = c.Toggles({ { "Incoming Heals", "showHealPrediction" }, { "Absorb Shields", "showAbsorbs" } })
    local heal = c.Columns({ "Heal Color", "Heal Opacity" })
    c.Color(heal[1], "healPredictionColor"); c.Slider(heal[2], "healPredictionOpacity", "%")
    local absorb = c.Columns({ "Absorb Color", "Absorb Opacity" })
    c.Color(absorb[1], "absorbColor"); c.Slider(absorb[2], "absorbOpacity", "%")

    self:BuildElementsTab(page, c, function() return element end)

    page:Section(L["Highlights"], nil, false)
    page:Group(L["Your Target"])
    local target = c.Columns({ "Style", "Color" })
    page.targetSelect = c.Select(target[1], 200, M.choices.highlightStyle, "targetHighlight"); c.Mark("target")
    c.Color(target[2], "targetColor")
    page.hoverToggles = c.Toggles({ { "Mouse Highlight", "hoverHighlight" } })
    page:Group(L["Dispel Highlight"])
    local dispel = c.Columns({ "Style", "Which Debuffs" })
    page.dispelSelect = c.Select(dispel[1], 200, M.choices.highlightStyle, "dispelHighlight")
    page.dispelFilterSelect = c.SelectIn(dispel[2], 220, function() return M.auraFilters.dispellable end,
        function() return M.db.dispelFilter end, function(v) M:SetOption("dispelFilter", v) end)
    c.Note("The member's border (or a tint) takes the debuff's type color: Magic, Curse, Disease or Poison. It keeps working in combat.", 32)
    page:Group(L["Fading"])
    page.rangeToggles = c.Toggles({ { "Fade Out of Range", "rangeFade" } })
    local fading = c.Columns({ "Out of Range Opacity", "Dead and Offline Opacity" })
    page.rangeSlider = c.Slider(fading[1], "rangeOpacity", "%"); page.deadSlider = c.Slider(fading[2], "deadOpacity", "%")

    self:BuildAuraTab(page, c, function() return auraGroup end)

    W.SectionTabs(page)
    page:Finish(); return page
end

-- Text and Icons: pick an element, then its switch, place, offset and size.
function M:BuildElementsTab(page, c, Element)
    local function Key(suffix) return Element() .. suffix end
    local function Set(suffix) return function(value) M:SetOption(Key(suffix), value) end end
    page:Section(L["Text and Icons"], nil, false)
    page:Group(L["Elements"])
    local list = {}
    for _, id in ipairs(M.elements) do list[#list + 1] = { id = id, label = M.elementLabels[id] } end
    page.elementSelect = c.SelectIn(page:Row(L["Element"], 48), 220, function() return list end, Element, page.SetElement)
    c.Mark("element")
    page.elementToggles = c.Toggles({ { "Show", "show", get = function() return M.db[Key("Show")] end, set = Set("Show") } })
    page.elementAnchor = c.Anchor("Anchor", function() return M.db[Key("Anchor")] end, Set("Anchor"))
    page.elementPlace = c.Pills("Place", M.choices.place, function() return M.db[Key("Place")] end, Set("Place"), 96)
    local place = c.Columns({ "Offset X", "Offset Y" })
    c.SliderIn(place[1], M.elementRanges.x, function() return M.db[Key("X")] end, Set("X"), "px")
    c.SliderIn(place[2], M.elementRanges.y, function() return M.db[Key("Y")] end, Set("Y"), "px")
    -- Texts are sized in font points, icons in pixels.
    local function Text() return M.textElements[Element()] == true end
    c.When(Text, function()
        page.textSizeSlider = c.SliderIn(c.Columns({ "Text Size" })[1], M.elementSizeRanges.text,
            function() return M.db[Key("Size")] end, Set("Size"))
    end)
    c.When(function() return not Text() end, function()
        page.iconSizeSlider = c.SliderIn(c.Columns({ "Icon Size" })[1], M.elementSizeRanges.icon,
            function() return M.db[Key("Size")] end, Set("Size"), "px")
    end)
    c.Note("Inside sits on the bars at the anchor. Outside sits past the bars' edge on that side; Center always sits inside.", 32)
    c.When(function() return Element() == "name" end, function()
        local name = c.Columns({ "Name Color", "Name Width" })
        page.nameColorSelect = c.Select(name[1], 200, M.choices.nameColorMode, "nameColorMode")
        c.Slider(name[2], "nameWidth", "%")
        local custom = c.Columns({ "Custom Name Color" })
        c.Color(custom[1], "nameColor", function() return M.db.nameColorMode == "custom" end)
    end)
    c.When(function() return Element() == "healthText" end, function()
        page.healthTextPills = c.Pills("Shows", M.choices.healthText, function() return M.db.healthText end,
            function(v) M:SetOption("healthText", v) end, 130)
    end)
    c.When(function() return Element() == "role" end, function()
        page.roleToggles = c.Toggles({ { "Hide Damage Role", "hideDamagerRole" } })
    end)
    page:Group(L["Font"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), c.owner); c.Refresh(fontRefresh)
    page.textToggles = c.Toggles({ { "Outline", "outline" }, { "Slug Text", "slug" } })
    page.shadowPills = c.Pills("Text Shadow", addon.Kit.SHADOW_CHOICES, function() return addon.Kit.ShadowMode(M.db) end, function(mode)
        local shadow, lifted = addon.Kit.ShadowKeys(mode)
        M:SetOption("shadow", shadow); M:SetOption("liftedShadow", lifted)
    end)
    local color = c.Columns({ "Text Color" })
    c.Color(color[1], "textColor")
end

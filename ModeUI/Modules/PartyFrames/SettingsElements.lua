local _, addon = ...
local M, W, L = addon.PartyFrames, addon.ConfigWidgets, addon.L
if not M then return end

-- The Text and Icons tab (pick an element, then its switch, place, offset,
-- nudge and size) and the Highlights and Overlay tab (your target, the mouse,
-- the dispel overlay by type, fading). The preview shows the element, or the
-- picked dispel type, while the tab is open.

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
    page.elementNudge = c.Nudge(function() return M.db[Key("X")] end, function() return M.db[Key("Y")] end, Set("X"), Set("Y"),
        M.elementRanges.x)
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
    c.Note("Inside sits on the bars at the anchor. Outside sits past the bars' edge on that side; Center always sits inside. The arrows move it one pixel.", 32)
    c.When(function() return Element() == "name" end, function()
        local name = c.Columns({ "Name Color", "Name Width" })
        page.nameColorSelect = c.Select(name[1], 200, M.choices.nameColorMode, "nameColorMode")
        c.Slider(name[2], "nameWidth", "%")
        local custom = c.Columns({ "Custom Name Color" })
        c.Color(custom[1], "nameColor", function() return M.db.nameColorMode == "custom" end)
    end)
    c.When(function() return Element() == "healthText" end, function()
        local health = c.Columns({ "Shows", "Health Text Color" })
        page.healthTextSelect = c.Select(health[1], 200, M.choices.healthText, "healthText")
        page.healthTextColorSelect = c.Select(health[2], 200, M.choices.healthTextColor, "healthTextColor")
        page.healthTextGlowToggles = c.Toggles({ { "Health Text Glow", "healthTextGlow" } })
    end)
    c.When(function() return Element() == "role" end, function()
        -- After Name: Anchor and Place step aside; Offset X and Y count from the name's end.
        page.roleToggles = c.Toggles({ { "Hide Damage Role", "hideDamagerRole" }, { "After Name", "roleAfterName" } })
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

function M:BuildHighlightsTab(page, c, Kind)
    page:Section(L["Highlights and Overlay"], nil, false)
    page:Group(L["Your Target"])
    local target = c.Columns({ "Style", "Color" })
    page.targetSelect = c.Select(target[1], 200, M.choices.highlightStyle, "targetHighlight"); c.Mark("target")
    c.Color(target[2], "targetColor")
    page.hoverToggles = c.Toggles({ { "Mouse Highlight", "hoverHighlight" }, { "Aggro Rim", "aggroHighlight" },
        { "Preview as Your Target", "previewTarget", get = function() return page.partyShowTarget == true end,
            set = function(value) page.partyShowTarget = value or nil; page:Refresh() end } })

    -- Each dispel type can recolor the border, the health and lay a gradient.
    page:Group(L["Dispel Overlay"])
    local which = c.Columns({ "Which Debuffs", "Gradient Opacity" })
    page.dispelFilterSelect = c.SelectIn(which[1], 220, function() return M.auraFilters.dispel end,
        function() return M.db.dispelFilter end, c.Set("dispelFilter"))
    c.Slider(which[2], "dispelGradientOpacity", "%")
    local kinds = {}
    for _, kind in ipairs(M.dispelTypes) do kinds[#kinds + 1] = { id = kind, label = kind } end
    page.dispelTypePills = c.Pills("Type", kinds, Kind, page.SetDispelType, 80)
    c.Mark("dispel")
    local function Effect(key) return {
        get = function() return M.db.dispel[Kind()][key] end,
        set = function(value) M:SetDispelEffect(Kind(), key, value) end } end
    local border, health, gradient = Effect("border"), Effect("health"), Effect("gradient")
    page.dispelToggles = c.Toggles({ { "Border", "border", get = border.get, set = border.set },
        { "Health Color", "health", get = health.get, set = health.set },
        { "Gradient", "gradient", get = gradient.get, set = gradient.set } })
    -- The type's color, shared with aura rims and glows.
    for _, kind in ipairs(M.dispelTypes) do
        c.When(function() return Kind() == kind end, function()
            c.Color(c.Columns({ "Type Color" })[1], M.dispelColorKeys[kind])
        end)
    end
    c.Note("Border turns the member's border the type's color, Health Color fills the health bar with it, and Gradient fades it down over the bar. They show while the member has such a debuff (Which Debuffs), in combat too. The preview shows the picked type while this tab is open.", 48)

    page:Group(L["Fading"])
    page.rangeToggles = c.Toggles({ { "Fade Out of Range", "rangeFade" } })
    local fading = c.Columns({ "Out of Range Opacity", "Dead and Offline Opacity" })
    page.rangeSlider = c.Slider(fading[1], "rangeOpacity", "%"); page.deadSlider = c.Slider(fading[2], "deadOpacity", "%")
end

local _, addon = ...
local M, W, T, L = addon.Nameplates, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. One tab
-- per area: Plates, Health, Text, Cast Bar, Markers.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local owner = M:AppearanceOwner()
    local db = M.db
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetOption(key, value) end end
    local function Slider(label, key, suffix)
        local r = M.ranges[key]
        local row = page:Row(L[label], 48)
        Refresh(W.Slider(row, r[1], r[2], r[3], function() return db[key] end,
            function(value) M:SetOption(key, math.floor(value + 0.5)) end, suffix, true))
        return row.slider
    end
    local function Select(label, choices, key)
        local button = W.Select(page:Row(L[label], 48), 260, choices, function()
            local value = db[key]
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, addon.Media:MediaLabel(tostring(value):gsub("^media:", ""))
        end, Set(key))
        Refresh(function() button:Refresh() end)
        return button
    end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = function() return db[entry[2]] end, set = Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 2, minimumCellWidth = 210 })
    end
    local function Color(label, key, enabled) W.ColorRow(page, owner, L[label], key, enabled) end
    local function Note(title, text, height)
        local label = W.Label(page:Row(L[title], height or 52), L[text], nil, 0, -4, 420, T.muted); label:SetWordWrap(true)
        return label
    end

    page:Section(L["Plates"], nil, false)
    page.widthSlider = Slider("Width", "width", "px")
    page.healthHeightSlider = Slider("Health Height", "healthHeight", "px")
    page.textureSelect = Select("Bar Texture", function() return M:GetTextureChoices() end, "texture")
    Note("How It Works", "ModeUI draws over the game's nameplates, which still decide where plates appear and handle clicks. Friendly plates inside instances and your personal resource display keep Blizzard's look.", 70)
    local reset = W.Button(page:Row(L["Defaults"], 48), L["Reset Nameplates"], 160, 30, "secondary")
    reset:SetPoint("LEFT"); reset:SetScript("OnClick", function() M:ResetSettings() end)
    page.resetButton = reset

    page:Section(L["Health"], nil, false)
    page.colorSelect = Select("Health Color", function() return M.choices.healthColorMode end, "healthColorMode")
    page.softnessSlider = Slider("Color Softness", "softness", "%")
    Color("Custom Color", "healthColor", function() return db.healthColorMode == "custom" end)
    page.healthToggles = Toggles({ { "Threat Colors", "threatColors" } })
    Note("Threat Colors", "Red when an enemy is attacking you, orange when you're close to pulling it. Unknown while the game hides threat.", 52)
    page.healthTextSelect = Select("Health Text", function() return M.choices.healthText end, "healthText")

    page:Section(L["Text"], nil, false)
    page.textToggles = Toggles({ { "Show Name", "showName" }, { "Outline", "outline" }, { "Text Shadow", "shadow" },
        { "Lifted Shadow", "liftedShadow" } })
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 42), owner); Refresh(fontRefresh)
    page.nameSizeSlider = Slider("Name Size", "nameFontSize")
    page.healthSizeSlider = Slider("Health Text Size", "healthFontSize")
    Color("Text Color", "textColor")

    page:Section(L["Cast Bar"], nil, false)
    page.castToggles = Toggles({ { "Show Cast Bar", "showCastBar" } })
    page.castHeightSlider = Slider("Cast Bar Height", "castHeight", "px")
    page.castSizeSlider = Slider("Spell Name Size", "castFontSize")
    Color("Interruptible", "castColor")
    Color("Not Interruptible", "castLockedColor")

    page:Section(L["Markers"], nil, false)
    page.markerToggles = Toggles({ { "Raid Markers", "showRaidIcon" }, { "Target Highlight", "targetHighlight" } })
    Note("Target Highlight", "Your target's plate gets a cyan rim.", 40)

    W.PinnedSectionTabs(page)
    page:Finish(); return page
end

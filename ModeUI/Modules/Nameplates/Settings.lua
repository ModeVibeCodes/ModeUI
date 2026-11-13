local _, addon = ...
local M, W, T, L = addon.Nameplates, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of both kinds sits above the tabs (Nameplates, Text, Cast Bar, Auras,
-- Markers). Each tab starts with an Editing switch for Enemy or Friendly; the
-- choice is shared by every tab for this session.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing = "enemy"
    local function Kind() return editing end
    local function db() return M.db[editing] end
    local function Other() return editing == "enemy" and "friendly" or "enemy" end
    page.nameplateEditing = Kind
    local owner = M:AppearanceOwner(Kind)
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetOption(editing, key, value) end end
    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    local function Shown() return db().show end
    local function Slider(label, key, suffix)
        local r = M.ranges[key]
        local row = page:Row(L[label], 48)
        Refresh(W.Slider(row, r[1], r[2], r[3], function() return db()[key] end,
            function(value) M:SetOption(editing, key, math.floor(value + 0.5)) end, suffix, true))
        return row.slider
    end
    local function Select(label, choices, key)
        local button = W.Select(page:Row(L[label], 48), 260, choices, function()
            local value = db()[key]
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, addon.Media:MediaLabel(tostring(value):gsub("^media:", ""))
        end, Set(key))
        Refresh(function() button:Refresh() end)
        return button
    end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = function() return db()[entry[2]] end, set = Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 2, minimumCellWidth = 210 })
    end
    local function Color(label, key, enabled) W.ColorRow(page, owner, L[label], key, enabled) end
    local function Note(title, text, height)
        local label = W.Label(page:Row(L[title], height or 52), L[text], nil, 0, -4, 420, T.muted); label:SetWordWrap(true)
        return label
    end
    local function Action(row, text, width, callback)
        local button = W.Button(row, text, width, 30, "secondary")
        button:SetPoint("LEFT"); button:SetScript("OnClick", callback)
        return button
    end

    page.configPreview = W.Preview(page, M, { contentHeight = 150 })

    -- Every tab starts with the Editing switch; a kind left to Blizzard shows
    -- only its switch and a note.
    page.nameplateEditButtons = {}
    local function Tab(title, build, always)
        page:Section(L[title], nil, false)
        local buttons, refresh = W.Exclusive(page:Row(L["Editing"], 48, { "enemy", "friendly" }),
            { { label = L["Enemy"], value = "enemy", width = 110 }, { label = L["Friendly"], value = "friendly", width = 110 } },
            Kind, function(value) editing = value; page:Refresh(); page:Layout() end)
        Refresh(refresh)
        page.nameplateEditButtons[#page.nameplateEditButtons + 1] = buttons
        if always then always() end
        When(function() return not Shown() end, function()
            Note("Blizzard's Plates", "This kind uses Blizzard's own nameplates. Turn on Use ModeUI Plates on the Plates tab to style it.", 52)
        end)
        When(Shown, build)
    end

    Tab("Nameplates", function()
        page:Group(L["Size"])
        page.widthSlider = Slider("Width", "width", "px")
        page.healthHeightSlider = Slider("Health Height", "healthHeight", "px")
        page:Group(L["Health"])
        page.colorSelect = Select("Health Color", function() return M.choices.healthColorMode end, "healthColorMode")
        page.softnessSlider = Slider("Color Softness", "softness", "%")
        Color("Custom Color", "healthColor", function() return db().healthColorMode == "custom" end)
        page.healthTextSelect = Select("Health Text", function() return M.choices.healthText end, "healthText")
        When(function() return editing == "enemy" end, function()
            page.healthToggles = Toggles({ { "Threat Colors", "threatColors" } })
            Note("Threat Colors", "Red when an enemy is attacking you, orange when you're close to pulling it. Unknown while the game hides threat.", 52)
        end)
        page:Group(L["Style"])
        local tools = page:Row(L["This Kind"], 48)
        page.copyButton = Action(tools, "", 190, function() M:CopyStyle(editing, Other()) end)
        page.resetButton = Action(tools, L["Reset to Defaults"], 150, function() M:ResetSettings(editing) end)
        page.resetButton:ClearAllPoints(); page.resetButton:SetPoint("LEFT", page.copyButton, "RIGHT", 8, 0)
        Refresh(function()
            page.copyButton.label:SetText(L[editing == "enemy" and "Copy Style to Friendly" or "Copy Style to Enemy"])
        end)
        Note("How It Works", "ModeUI draws over the game's nameplates, which still decide where plates appear and handle clicks. Friendly plates inside instances and your personal resource display keep Blizzard's look. Every bar uses the Mode Gradient texture.", 70)
    end, function()
        page.showToggles = Toggles({ { "Use ModeUI Plates", "show" } })
    end)

    Tab("Text", function()
        page.textToggles = Toggles({ { "Show Name", "showName" }, { "Outline", "outline" }, { "Text Shadow", "shadow" },
            { "Lifted Shadow", "liftedShadow" } })
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 42), owner); Refresh(fontRefresh)
        page.nameSizeSlider = Slider("Name Size", "nameFontSize")
        page.healthSizeSlider = Slider("Health Text Size", "healthFontSize")
        Color("Text Color", "textColor")
    end)

    Tab("Cast Bar", function()
        page.castToggles = Toggles({ { "Show Cast Bar", "showCastBar" } })
        page.castHeightSlider = Slider("Cast Bar Height", "castHeight", "px")
        page.castSizeSlider = Slider("Spell Name Size", "castFontSize")
        Color("Interruptible", "castColor")
        Color("Not Interruptible", "castLockedColor")
    end)

    -- Auras: what shows, then where, then how it looks.
    Tab("Auras", function()
        page.auraToggles = Toggles({ { "Show Auras", "showAuras" } })
        When(function() return db().showAuras end, function()
            page:Group(L["What Shows"])
            page.auraCrowdControlToggles = Toggles({ { "Crowd Control", "auraCrowdControl" } })
            page.auraDebuffSelect = Select("Debuffs", function() return M.choices.auraDebuffs end, "auraDebuffs")
            page.auraBuffSelect = Select("Buffs", function() return M.choices.auraBuffs end, "auraBuffs")
            Note("Order", "Crowd control comes first (stuns, fears, polymorphs), then debuffs, then buffs. The game decides which auras match each choice.", 52)
            page:Group(L["Placement"])
            page.auraPositionSelect = Select("Position", function() return M.choices.auraPosition end, "auraPosition")
            When(function() return db().auraPosition == "above" or db().auraPosition == "below" end, function()
                page.auraAlignSelect = Select("Alignment", function() return M.choices.auraAlign end, "auraAlign")
            end)
            page.auraSizeSlider = Slider("Icon Size", "auraSize", "px")
            page.auraSpacingSlider = Slider("Spacing", "auraSpacing", "px")
            page.auraMaxSlider = Slider("Most Shown", "auraMax")
            page:Group(L["Details"])
            page.auraDetailToggles = Toggles({ { "Timer Swipe", "auraTimer" }, { "Stack Count", "auraCount" } })
        end)
    end)

    Tab("Markers", function()
        page.markerToggles = Toggles({ { "Raid Markers", "showRaidIcon" }, { "Target Highlight", "targetHighlight" } })
        Note("Target Highlight", "Your target's plate gets a cyan rim.", 40)
    end)

    W.SectionTabs(page)
    page:Finish(); return page
end

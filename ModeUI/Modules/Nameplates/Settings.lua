local _, addon = ...
local M, W, T, L = addon.Nameplates, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of the kind being edited sits above the tabs (Nameplates, Text, Cast
-- Bar, Auras, Target); clicking a part of it jumps to that part's settings.
-- Every tab starts with the Editing switch (Enemy or Friendly), shared by
-- every tab, then cards of related settings, side by side where they fit.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing, auraGroup = "enemy", "debuffs"
    local function Kind() return editing end
    local function db() return M.db[editing] end
    local function Group() return db()[auraGroup] end
    local function Other() return editing == "enemy" and "friendly" or "enemy" end
    page.nameplateEditing = Kind
    page.nameplateAuraGroup = function() return auraGroup end
    function page.SetEditing(kind) if M.styleDefaults[kind] then editing = kind; page:Refresh(); page:Layout() end end
    function page.SetAuraGroup(group) if M.auraGroupLabels[group] then auraGroup = group; page:Refresh(); page:Layout() end end
    local owner = M:AppearanceOwner(Kind)
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetOption(editing, key, value) end end
    local function SetGroup(key) return function(value) M:SetOption(editing, key, value, auraGroup) end end
    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    local function Shown() return db().show end
    local function Plate() return db().display == "plate" end
    -- The settings a preview click jumps to.
    page.jumpTargets = {}
    local function Mark(target) local row = page.rows[#page.rows]; page.jumpTargets[target] = { section = row.section, row = row } end

    -- Controls. Each takes the host it fills: a row, or one cell of Columns.
    local function SliderIn(host, range, get, set, suffix)
        Refresh(W.Slider(host, range[1], range[2], range[3], get, function(value) set(math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    local function Slider(host, key, suffix) return SliderIn(host, M.ranges[key], function() return db()[key] end, Set(key), suffix) end
    local function GroupSlider(host, key, suffix)
        return SliderIn(host, M.groupRanges[key], function() return Group()[key] end, SetGroup(key), suffix)
    end
    local function SelectIn(host, width, choices, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get()
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, tostring(value)
        end, set)
        Refresh(function() button:Refresh() end)
        return button
    end
    local function Select(host, width, list, key) return SelectIn(host, width, function() return list end, function() return db()[key] end, Set(key)) end
    local function Pills(title, list, get, set, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 96 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get, set)
        Refresh(refresh)
        return buttons
    end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = entry.get or function() return db()[entry[2]] end, set = entry.set or Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    local function Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    local function Note(text, height)
        local host = page:Row("", height or 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return label
    end
    local function Anchor(title, get, set, center)
        local labels = setmetatable({}, { __index = function(_, key) return L[M.anchorLabels[key] or key] end })
        local buttons, refresh = W.AnchorPicker(page:Row(L[title], W.ANCHOR_PICKER_HEIGHT + 16), get, set, labels, { center = center })
        Refresh(refresh)
        return buttons
    end
    local function Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end

    page.configPreview = W.Preview(page, M, { contentHeight = 150 })

    -- Every tab starts with the Editing switch; a kind left to Blizzard shows
    -- only that switch and a note.
    page.nameplateEditButtons = {}
    local function Tab(title, build, always)
        page:Section(L[title], nil, false)
        page.nameplateEditButtons[#page.nameplateEditButtons + 1] = Pills("Editing",
            { { id = "enemy", label = "Enemy" }, { id = "friendly", label = "Friendly" } }, Kind, page.SetEditing, 110)
        if always then always() end
        When(function() return not Shown() end, function()
            Note("This kind uses Blizzard's own nameplates. Turn on Use ModeUI Plates on the Nameplates tab to style it.")
        end)
        When(Shown, build)
    end

    Tab("Nameplates", function()
        page.displayPills = Pills("Style", M.choices.display, function() return db().display end, Set("display"), 110)
        When(Plate, function()
            page:Group(L["Size"])
            local size = Columns({ "Width", "Health Height" })
            page.widthSlider = Slider(size[1], "width", "px")
            page.healthHeightSlider = Slider(size[2], "healthHeight", "px")
            page:Group(L["Textures"])
            local textures = Columns({ "Foreground", "Background" })
            page.foregroundSelect = SelectIn(textures[1], 200, function() return M.TextureChoices(true) end,
                function() return db().foregroundTexture end, Set("foregroundTexture"))
            page.backgroundSelect = SelectIn(textures[2], 200, function() return M.TextureChoices(false) end,
                function() return db().backgroundTexture end, Set("backgroundTexture"))
            page:Group(L["Health"])
            local choose = Columns({ "Health Color", "Health Text" })
            page.colorSelect = Select(choose[1], 200, M.choices.healthColorMode, "healthColorMode"); Mark("health")
            page.healthTextSelect = Select(choose[2], 200, M.choices.healthText, "healthText")
            local fade = Columns({ "Health Opacity", "Background Opacity" })
            page.healthOpacitySlider = Slider(fade[1], "healthOpacity", "%")
            page.backgroundOpacitySlider = Slider(fade[2], "backgroundOpacity", "%")
            local custom = Columns({ "Custom Color" })
            Color(custom[1], "healthColor", function() return db().healthColorMode == "custom" end)
            When(function() return editing == "enemy" end, function()
                page.healthToggles = Toggles({ { "Threat Colors", "threatColors" } })
                local threat = Columns({ "Has Aggro", "Losing Aggro", "Close to Pulling" })
                local function On() return db().threatColors end
                Color(threat[1], "threatAggroColor", On)
                Color(threat[2], "threatLosingColor", On)
                Color(threat[3], "threatPullingColor", On)
                Note("Has Aggro: the enemy is attacking you. Losing Aggro: it's attacking you, but someone else is about to take it. Close to Pulling: it's attacking someone else and you're about to take it.", 48)
            end)
        end)
        When(function() return not Plate() end, function()
            Note("Name Only shows just the name in its class color (players) or reaction color, with auras and the raid marker. Size the name on the Text tab.", 48)
        end)
        page:Group(L["This Kind"])
        local tools = page:Row(L["Style"], 48)
        page.copyButton = W.Button(tools, "", 190, 30, "secondary")
        page.copyButton:SetPoint("LEFT"); page.copyButton:SetScript("OnClick", function() M:CopyStyle(editing, Other()) end)
        page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
        page.resetButton:SetPoint("LEFT", page.copyButton, "RIGHT", 8, 0); page.resetButton:SetScript("OnClick", function() M:ResetSettings(editing) end)
        Refresh(function() page.copyButton.label:SetText(L[editing == "enemy" and "Copy Style to Friendly" or "Copy Style to Enemy"]) end)
    end, function()
        page.showToggles = Toggles({ { "Use ModeUI Plates", "show" } })
    end)

    Tab("Text", function()
        page:Group(L["Name"])
        page.nameToggles = Toggles({ { "Show Name", "showName" } }); Mark("name")
        page.nameColorPills = Pills("Name Color", M.choices.nameColorMode, function() return db().nameColorMode end, Set("nameColorMode"), 150)
        When(Plate, function()
            page.nameAnchorButtons = Anchor("Name Anchor", function() return db().nameAnchor end, Set("nameAnchor"), true)
        end)
        local name = Columns({ "Offset X", "Offset Y", "Size" })
        Slider(name[1], "nameX", "px"); Slider(name[2], "nameY", "px"); page.nameSizeSlider = Slider(name[3], "nameFontSize")
        When(Plate, function()
            page:Group(L["Health Text"])
            page.healthTextAnchorButtons = Anchor("Anchor", function() return db().healthTextAnchor end, Set("healthTextAnchor"), true)
            Mark("healthText")
            local health = Columns({ "Offset X", "Offset Y", "Size" })
            Slider(health[1], "healthTextX", "px"); Slider(health[2], "healthTextY", "px"); page.healthSizeSlider = Slider(health[3], "healthFontSize")
        end)
        page:Group(L["Font"])
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
        page.textToggles = Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" }, { "Lifted Shadow", "liftedShadow" } })
        local color = Columns({ "Text Color" })
        Color(color[1], "textColor")
    end)

    Tab("Cast Bar", function()
        When(Plate, function()
            page:Group(L["Cast Bar"])
            page.castToggles = Toggles({ { "Show Cast Bar", "showCastBar" } }); Mark("cast")
            page.castPositionPills = Pills("Position", M.choices.castAnchor, function() return db().castAnchor end, Set("castAnchor"))
            local size = Columns({ "Height", "Spell Name Size" })
            page.castHeightSlider = Slider(size[1], "castHeight", "px"); page.castSizeSlider = Slider(size[2], "castFontSize")
            local offset = Columns({ "Offset X", "Offset Y" })
            Slider(offset[1], "castX", "px"); Slider(offset[2], "castY", "px")
            page:Group(L["Colors"])
            local colors = Columns({ "Interruptible", "Not Interruptible" })
            Color(colors[1], "castColor"); Color(colors[2], "castLockedColor")
        end)
        When(function() return not Plate() end, function() Note("Name Only plates have no cast bar.") end)
    end)

    -- Auras: how every icon looks, then each group's contents and place.
    Tab("Auras", function()
        page:Group(L["Auras"])
        page.auraToggles = Toggles({ { "Show Auras", "showAuras" }, { "Timer Swipe", "auraTimer" }, { "Stack Count", "auraCount" } })
        When(function() return db().showAuras end, function()
            page.auraShapePills = Pills("Icon Shape", M.choices.auraShape, function() return db().auraShape end, Set("auraShape"))
            page.auraBorderPills = Pills("Borders", M.choices.auraBorder, function() return db().auraBorder end, Set("auraBorder"))
            local spacing = Columns({ "Spacing" })
            page.auraSpacingSlider = Slider(spacing[1], "auraSpacing", "px")
            page:Group(L["Groups"])
            page.auraGroupButtons = Pills("Group", { { id = "crowdControl", label = "Crowd Control" }, { id = "debuffs", label = "Debuffs" },
                { id = "buffs", label = "Buffs" } }, function() return auraGroup end, page.SetAuraGroup, 112)
            Mark("auras")
            page.auraGroupToggles = Toggles({ { "Show This Group", "show", get = function() return Group().show end, set = SetGroup("show") } })
            When(function() return Group().show end, function()
                When(function() return M.groupFilters[auraGroup] ~= nil end, function()
                    local which = Columns({ "Which" })
                    page.auraFilterSelect = SelectIn(which[1], 220, function() return M.groupFilters[auraGroup] or {} end,
                        function() return Group().filter end, SetGroup("filter"))
                end)
                page.auraAnchorButtons = Anchor("Anchor", function() return Group().anchor end, SetGroup("anchor"))
                page.auraGrowPills = Pills("Grow", M.growChoices, function() return Group().grow end, SetGroup("grow"), 70)
                local offset = Columns({ "Offset X", "Offset Y" })
                page.auraXSlider = GroupSlider(offset[1], "x", "px"); page.auraYSlider = GroupSlider(offset[2], "y", "px")
                local size = Columns({ "Icon Size", "Most Shown" })
                page.auraSizeSlider = GroupSlider(size[1], "size", "px"); page.auraMaxSlider = GroupSlider(size[2], "max")
            end)
            When(function() return db().auraBorder == "type" end, function()
                page:Group(L["Border Colors"])
                local first = Columns({ "Magic", "Curse", "Disease" })
                Color(first[1], "auraMagicColor"); Color(first[2], "auraCurseColor"); Color(first[3], "auraDiseaseColor")
                local second = Columns({ "Poison", "Enrage" })
                Color(second[1], "auraPoisonColor"); Color(second[2], "auraEnrageColor")
                Note("Auras without a dispel type, and any aura while the game hides its details, keep the Mode rim.", 32)
            end)
        end)
    end)

    Tab("Target", function()
        page:Group(L["Target Indicator"])
        local style = Columns({ "Style", "Color" })
        page.targetStyleSelect = Select(style[1], 200, M.choices.targetStyle, "targetStyle")
        Color(style[2], "targetColor")
        local sizes = Columns({ "Border Thickness", "Arrow Size", "Arrow Gap" })
        Slider(sizes[1], "targetThickness", "px"); Slider(sizes[2], "targetArrowSize", "px"); Slider(sizes[3], "targetArrowGap", "px")
        Note("Arrows always sit outside the raid marker, the indicator and any aura row beside the bar.", 32)
    end)

    Tab("Indicators", function()
        page:Group(L["Indicator"])
        page.indicatorToggles = Toggles({ { "Show Indicator", "showIndicator" }, { "Level", "indicatorLevel" },
            { "Elite and Rare", "indicatorClassification" }, { "Quest", "indicatorQuest" } }); Mark("indicator")
        page.indicatorAnchorButtons = Anchor("Anchor", function() return db().indicatorAnchor end, Set("indicatorAnchor"), true)
        local indicator = Columns({ "Icon Size", "Level Size" })
        Slider(indicator[1], "indicatorSize", "px"); Slider(indicator[2], "indicatorFontSize")
        local offset = Columns({ "Offset X", "Offset Y" })
        Slider(offset[1], "indicatorX", "px"); Slider(offset[2], "indicatorY", "px")
        Note("Quest shows on creatures that are part of one of your quests. Level uses the game's difficulty color.", 32)
        page:Group(L["Raid Marker"])
        page.markerToggles = Toggles({ { "Show Raid Marker", "showRaidIcon" } }); Mark("markers")
        page.raidAnchorButtons = Anchor("Anchor", function() return db().raidAnchor end, Set("raidAnchor"), true)
        local raid = Columns({ "Size", "Offset X", "Offset Y" })
        Slider(raid[1], "raidSize", "px"); Slider(raid[2], "raidX", "px"); Slider(raid[3], "raidY", "px")
    end)

    W.SectionTabs(page)
    page:Finish(); return page
end

-- A preview click: show that kind (and aura group) and scroll to the setting.
function M:JumpTo(kind, target, group)
    local page = self.page
    if not page or not page.jumpTargets or not page.jumpTargets[target] then return false end
    page.SetEditing(kind)
    if group then page.SetAuraGroup(group) end
    page:Reveal(page.jumpTargets[target])
    return true
end

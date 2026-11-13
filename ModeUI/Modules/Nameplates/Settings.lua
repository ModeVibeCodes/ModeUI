local _, addon = ...
local M, W, T, L = addon.Nameplates, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of both kinds sits above the tabs (Nameplates, Text, Cast Bar, Auras,
-- Markers); clicking a part of it jumps to that part's settings. Each tab
-- starts with an Editing switch for Enemy or Friendly, shared by every tab
-- for this session.
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
    -- The settings a preview click jumps to.
    page.jumpTargets = {}
    local function Mark(target) local row = page.rows[#page.rows]; page.jumpTargets[target] = { section = row.section, row = row } end
    local function Shown() return db().show end
    local function SliderRow(label, range, get, set, suffix)
        local row = page:Row(L[label], 48)
        Refresh(W.Slider(row, range[1], range[2], range[3], get, function(value) set(math.floor(value + 0.5)) end, suffix, true))
        return row.slider
    end
    local function Slider(label, key, suffix)
        return SliderRow(label, M.ranges[key], function() return db()[key] end, Set(key), suffix)
    end
    local function GroupSlider(label, key, suffix)
        return SliderRow(label, M.groupRanges[key], function() return Group()[key] end, SetGroup(key), suffix)
    end
    local function SelectRow(label, choices, get, set)
        local button = W.Select(page:Row(L[label], 48), 260, choices, function()
            local value = get()
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, tostring(value)
        end, set)
        Refresh(function() button:Refresh() end)
        return button
    end
    local function Select(label, choices, key) return SelectRow(label, choices, function() return db()[key] end, Set(key)) end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = entry.get or function() return db()[entry[2]] end, set = entry.set or Set(entry[2]) }
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
            Kind, page.SetEditing)
        Refresh(refresh)
        page.nameplateEditButtons[#page.nameplateEditButtons + 1] = buttons
        if always then always() end
        When(function() return not Shown() end, function()
            Note("Blizzard's Plates", "This kind uses Blizzard's own nameplates. Turn on Use ModeUI Plates on the Nameplates tab to style it.", 52)
        end)
        When(Shown, build)
    end

    Tab("Nameplates", function()
        page:Group(L["Size"])
        page.widthSlider = Slider("Width", "width", "px")
        page.healthHeightSlider = Slider("Health Height", "healthHeight", "px")
        page:Group(L["Health"])
        page.colorSelect = Select("Health Color", function() return M.choices.healthColorMode end, "healthColorMode"); Mark("health")
        page.softnessSlider = Slider("Color Softness", "softness", "%")
        Color("Custom Color", "healthColor", function() return db().healthColorMode == "custom" end)
        page.healthTextSelect = Select("Health Text", function() return M.choices.healthText end, "healthText"); Mark("healthText")
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
        Mark("name")
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 42), owner); Refresh(fontRefresh)
        page.nameSizeSlider = Slider("Name Size", "nameFontSize")
        page.healthSizeSlider = Slider("Health Text Size", "healthFontSize")
        Color("Text Color", "textColor")
    end)

    Tab("Cast Bar", function()
        page.castToggles = Toggles({ { "Show Cast Bar", "showCastBar" } }); Mark("cast")
        page.castHeightSlider = Slider("Cast Bar Height", "castHeight", "px")
        page.castSizeSlider = Slider("Spell Name Size", "castFontSize")
        Color("Interruptible", "castColor")
        Color("Not Interruptible", "castLockedColor")
    end)

    -- Auras: pick a group, then what it shows and where it sits.
    Tab("Auras", function()
        page.auraToggles = Toggles({ { "Show Auras", "showAuras" } })
        When(function() return db().showAuras end, function()
            local groupButtons, groupRefresh = W.Exclusive(page:Row(L["Group"], 48, { "crowd control", "debuffs", "buffs" }), {
                { label = L["Crowd Control"], value = "crowdControl", width = 120 },
                { label = L["Debuffs"], value = "debuffs", width = 96 }, { label = L["Buffs"], value = "buffs", width = 96 } },
                function() return auraGroup end, page.SetAuraGroup)
            Refresh(groupRefresh); page.auraGroupButtons = groupButtons; Mark("auras")
            page.auraGroupToggles = Toggles({ { "Show This Group", "show",
                get = function() return Group().show end, set = SetGroup("show") } })
            When(function() return Group().show end, function()
                When(function() return M.groupFilters[auraGroup] ~= nil end, function()
                    page.auraFilterSelect = SelectRow("Which", function() return M.groupFilters[auraGroup] or {} end,
                        function() return Group().filter end, SetGroup("filter"))
                end)
                local anchorRow = page:Row(L["Anchor"], W.ANCHOR_PICKER_HEIGHT + 8)
                local anchorButtons, anchorRefresh = W.AnchorPicker(anchorRow, function() return Group().anchor end,
                    SetGroup("anchor"), setmetatable({}, { __index = function(_, key) return L[M.anchorLabels[key] or key] end }))
                Refresh(anchorRefresh); page.auraAnchorButtons = anchorButtons
                page.auraXSlider = GroupSlider("Offset X", "x", "px")
                page.auraYSlider = GroupSlider("Offset Y", "y", "px")
                page.auraSizeSlider = GroupSlider("Icon Size", "size", "px")
                page.auraMaxSlider = GroupSlider("Most Shown", "max")
            end)
            page:Group(L["Every Group"])
            page.auraSpacingSlider = Slider("Spacing", "auraSpacing", "px")
            page.auraDetailToggles = Toggles({ { "Timer Swipe", "auraTimer" }, { "Stack Count", "auraCount" } })
            Note("How Auras Work", "Crowd control means stuns, fears and polymorphs. The game decides which auras belong to each group. Top anchors sit above the name, Bottom anchors below the cast bar, Left and Right beside the health bar; groups on the same anchor stack outward.", 70)
        end)
    end)

    Tab("Markers", function()
        page.markerToggles = Toggles({ { "Raid Markers", "showRaidIcon" }, { "Target Highlight", "targetHighlight" } })
        Mark("markers")
        Note("Target Highlight", "Your target's plate gets a cyan rim.", 40)
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

local _, addon = ...
local M, W, T, L = addon.DamageMeters, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of the window being edited sits above the tabs (Window, Bars,
-- Text, Header, Frame); clicking a part of it jumps to its settings. Every
-- tab starts with the Editing choice (which window), then cards of related
-- settings, side by side where they fit.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing = "window1"
    local function Window() return editing end
    -- What the window draws with: a grouped window's shared settings are its group's.
    local function db() return M:Style(editing) end
    local function Grouped() return M:IsGrouped(editing) end
    page.windowEditing = Window
    function page.SetEditing(window) if M.windowLabels[window] then editing = window; page:Refresh(); page:Layout() end end
    local owner = M:AppearanceOwner(Window)
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetOption(editing, key, value) end end
    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    page.jumpTargets = {}
    local function Mark(target) local row = page.rows[#page.rows]; page.jumpTargets[target] = { section = row.section, row = row } end

    -- Controls. Each takes the host it fills: a row, or one cell of Columns.
    local function Slider(host, key, suffix)
        local r = M.ranges[key]
        Refresh(W.Slider(host, r[1], r[2], r[3], function() return db()[key] end,
            function(value) M:SetOption(editing, key, math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    local function SelectIn(host, width, choices, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get()
            for _, choice in ipairs(choices()) do if choice.id == value then return value, choice.label end end
            return value, tostring(value)
        end, set)
        Refresh(function() button:Refresh() end)
        return button
    end
    local function Localized(list)
        local out = {}
        for i, item in ipairs(list) do out[i] = { id = item.id, label = L[item.label] } end
        return out
    end
    local function Pills(title, list, get, set, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 96 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get, set)
        Refresh(refresh)
        return buttons
    end
    local function Choice(title, key, width) return Pills(title, M.choices[key], function() return db()[key] end, Set(key), width) end
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
    local function Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    local windowChoices = {}
    for _, window in ipairs(M.windows) do windowChoices[#windowChoices + 1] = { id = window, label = L[M.windowLabels[window]] } end

    page.configPreview = W.Preview(page, M, { contentHeight = 200 })

    -- Every tab starts with the Editing choice; a hidden window says so.
    page.windowSelects = {}
    local function Tab(title, build)
        page:Section(L[title], nil, false)
        local editRow = page:Row(L["Editing"], 48)
        page.windowSelects[#page.windowSelects + 1] = SelectIn(editRow, 200, function() return windowChoices end, Window, page.SetEditing)
        if title ~= "Window" then
            When(function() return not db().show end, function() Note("This window is off. Turn on Show Window on the Window tab to use it.") end)
        end
        When(Grouped, function()
            local note = Note("", 32)
            Refresh(function()
                local head = L[M.windowLabels[M:Leader(editing)]]
                note:SetText(string.format(L["Grouped: these settings are shared with %s, so changing them changes the whole group. Meter, Fight and Rows stay this window's own."], head))
            end)
        end)
        build()
    end

    Tab("Window", function()
        page.showToggles = Toggles({ { "Show Window", "show" } }); Mark("window")
        local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        Refresh(function() status:SetText(M:Status()) end)
        page.statusLabel = status
        page:Group(L["Meter"])
        local meter = Columns({ "Meter" })
        page.meterSelect = SelectIn(meter[1], 220, function() return Localized(M.choices.meterType) end,
            function() return db().meterType end, Set("meterType"))
        page.sessionPills = Choice("Fight", "session", 120)
        Note("Click a window's header for its meter, earlier fights and Reset All Data. Click a row for that player's spells.", 32)
        page:Group(L["Size"])
        local size = Columns({ "Width", "Rows" })
        page.widthSlider = Slider(size[1], "width", "px")
        page.rowsSlider = Slider(size[2], "rows")
        local rows = Columns({ "Row Height", "Spacing", "Padding" })
        page.rowHeightSlider = Slider(rows[1], "rowHeight", "px")
        page.spacingSlider = Slider(rows[2], "spacing", "px")
        page.paddingSlider = Slider(rows[3], "padding", "px")
        page:Group(L["When to Show"])
        local show = Columns({ "Show", "Opacity" })
        page.visibilitySelect = SelectIn(show[1], 200, function() return Localized(M.choices.visibility) end,
            function() return db().visibility end, Set("visibility"))
        page.opacitySlider = Slider(show[2], "opacity", "%")
        page.mouseToggles = Toggles({ { "Lock Window", "locked" }, { "Click Through", "clickThrough" } })
        Note("Unlocked, drag a window's header to move it and the grip in its corner to resize it (out of combat). The lock button in the header does the same as Lock Window. Hidden windows still show in Edit Mode. Click Through lets clicks and the mouse wheel pass to the game world.", 48)
        page:Group(L["Group"])
        local group = Columns({ "Group With" })
        page.groupSelect = SelectIn(group[1], 200, function() return M:GroupChoices(editing) end,
            function() return M.db[editing].group end, Set("group")); Mark("group")
        When(Grouped, function()
            page.groupSidePills = Choice("Side", "groupSide", 96)
            local gap = Columns({ "Gap" })
            page.groupGapSlider = Slider(gap[1], "groupGap", "px")
        end)
        Note("A grouped window stacks below or above the window it follows and matches its group: width, bars, text, header, frame, Show and the lock. It keeps its own meter, fight and Rows, so a group grows up or down a window at a time. Move the group by its first window.", 48)
        page:Group(L["This Window"])
        local tools = page:Row(L["Style"], 48)
        page.copyButton = W.Button(tools, L["Copy Style to All Windows"], 200, 30, "secondary")
        page.copyButton:SetPoint("LEFT"); page.copyButton:SetScript("OnClick", function() M:CopyStyleToAll(editing) end)
        page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
        page.resetButton:SetPoint("LEFT", page.copyButton, "RIGHT", 8, 0); page.resetButton:SetScript("OnClick", function() M:ResetWindow(editing) end)
        Note("Copy Style copies size, bars, text, header and frame; each window keeps its own meter, fight and show settings.", 32)
        page:Group(L["Data"])
        local data = page:Row(L["Recorded Fights"], 48)
        page.resetDataButton = W.Button(data, L["Reset All Data"], 150, 30, "secondary")
        page.resetDataButton:SetPoint("LEFT"); page.resetDataButton:SetScript("OnClick", function() M:ResetData() end)
        Note("The numbers come from the game's own damage meter, which must be on in the game's options. ModeUI never changes that option or Blizzard's meter window; hide Blizzard's window with its own Edit Mode settings if you only want ModeUI's.", 48)
    end)

    Tab("Bars", function()
        page:Group(L["Texture"])
        local textures = Columns({ "Foreground", "Background" })
        page.barTextureSelect = SelectIn(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end,
            function() return db().barTexture end, Set("barTexture")); Mark("bars")
        page.barBackgroundSelect = SelectIn(textures[2], 200, function() return addon.Kit.BarTextureChoices(false) end,
            function() return db().barBackground end, Set("barBackground"))
        local fade = Columns({ "Bar Opacity", "Background Opacity" })
        page.barOpacitySlider = Slider(fade[1], "barOpacity", "%")
        page.barBackgroundSlider = Slider(fade[2], "barBackgroundOpacity", "%")
        page:Group(L["Color"])
        page.colorPills = Choice("Bar Color", "barColorMode", 96)
        local colors = Columns({ "Custom Color", "Other Color" })
        Color(colors[1], "barColor", function() return db().barColorMode == "custom" end)
        Color(colors[2], "otherColor")
        Note("Class uses Class Colors when you've set them. Other Color is for anything without a class, like pets and creatures.", 32)
        page:Group(L["Icon and Rows"])
        page.iconPills = Choice("Icon", "icon", 110)
        page.rowToggles = Toggles({ { "Always Show Me", "alwaysShowMe" } })
        Note("Always Show Me keeps your own row in view: when you rank below the last row, you take its place.", 32)
    end)

    Tab("Text", function()
        page:Group(L["Font"])
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
        page.fontToggles = Toggles({ { "Outline", "outline" }, { "Slug Text", "slug" } }); Mark("text")
        page.shadowPills = Pills("Text Shadow", addon.Kit.SHADOW_CHOICES, function() return addon.Kit.ShadowMode(db()) end, function(mode)
            local shadow, lifted = addon.Kit.ShadowKeys(mode)
            M:SetOption(editing, "shadow", shadow); M:SetOption(editing, "liftedShadow", lifted)
        end)
        page:Group(L["Name"])
        local name = Columns({ "Name Size", "Text Inset" })
        page.nameSizeSlider = Slider(name[1], "nameSize")
        page.insetSlider = Slider(name[2], "textInset", "px")
        page.nameColorPills = Choice("Name Color", "nameColorMode", 110)
        local color = Columns({ "Text Color" })
        Color(color[1], "textColor")
        page.rankToggles = Toggles({ { "Show Rank", "showRank" } })
        page:Group(L["Numbers"])
        page.numberPills = Choice("Show", "numbers", 170)
        page.decimalPills = Pills("Decimals", { { id = 0, label = "0" }, { id = 1, label = "1" }, { id = 2, label = "2" } },
            function() return db().decimals end, Set("decimals"), 56)
        local value = Columns({ "Value Size" })
        page.valueSizeSlider = Slider(value[1], "valueSize")
        page.percentToggles = Toggles({ { "Show Percent", "showPercent" } })
        Note("Decimals sets the places after K, M and B (12.3K); numbers under a thousand and counts are whole. DPS and HPS show the per-second amount first. The game hides exact amounts from addons during combat, so Percent shows once the fight ends.", 48)
    end)

    Tab("Header", function()
        page.headerToggles = Toggles({ { "Show Header", "header" } }); Mark("header")
        When(function() return db().header end, function()
            page:Group(L["Header"])
            local size = Columns({ "Height", "Text Size" })
            page.headerHeightSlider = Slider(size[1], "headerHeight", "px")
            page.titleSizeSlider = Slider(size[2], "titleSize")
            local fill = Columns({ "Header Color", "Header Opacity" })
            Color(fill[1], "headerColor")
            page.headerOpacitySlider = Slider(fill[2], "headerOpacity", "%")
            local title = Columns({ "Title Color" })
            Color(title[1], "titleColor")
            page.titleToggles = Toggles({ { "Uppercase Title", "titleUpper" }, { "Show Fight", "showSession" }, { "Show Timer", "showTimer" } })
            page.buttonToggles = Toggles({ { "Header Buttons", "headerButtons" } })
        end)
        Note("Header Buttons: the fight (C for Current, O for Overall, a number for an earlier fight; click to switch, right-click for the list), Reset All Data and the lock. Show Fight adds the fight's full name to the header text. Without a header, pick the meter and fight on the Window tab, or right-click a row.", 48)
    end)

    Tab("Frame", function()
        page:Group(L["Border"])
        page.borderPills = Choice("Border", "border", 96); Mark("frame")
        local function Bordered() return db().border ~= "none" end
        local border = Columns({ "Border Size", "Border Color" })
        page.borderSizeSlider = Slider(border[1], "borderSize", "px")
        Color(border[2], "borderColor", Bordered)
        page:Group(L["Background"])
        local background = Columns({ "Background Color", "Background Opacity" })
        Color(background[1], "backgroundColor")
        page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
        Note("Border Size is in screen pixels. Rounded leaves out each corner's outer pixel. The header divider uses the border color.", 32)
    end)

    W.SectionTabs(page)
    page:Finish(); return page
end

-- A preview click: scroll to the setting on its tab.
function M:JumpTo(target)
    local page = self.page
    if not page or not page.jumpTargets or not page.jumpTargets[target] then return false end
    page:Reveal(page.jumpTargets[target])
    return true
end

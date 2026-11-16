local _, addon = ...
local M, W, T, L = addon.DamageMeters, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of the window being edited sits above the tabs (Window, Bars,
-- Text, Header, Frame, Copy & Apply), with Editing (which window, and its meter) at its top
-- right as on the Action Bars page. Clicking a part of the preview jumps to
-- its settings. Tabs hold cards of related settings, side by side where they
-- fit.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing, textPart = "window1", "name"
    local function Window() return editing end
    local function Part() return textPart end
    -- What the window draws with: a grouped window's shared settings are its group's.
    local function db() return M:Style(editing) end
    local function Grouped() return M:IsGrouped(editing) end
    page.windowEditing, page.textPart = Window, Part
    function page.SetEditing(window) if M.windowLabels[window] then editing = window; page:Refresh(); page:Layout() end end
    function page.SetTextPart(part) if M.textPartLabels[part] then textPart = part; page:Refresh(); page:Layout() end end
    local owner = M:AppearanceOwner(Window, Part)
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetOption(editing, key, value) end end
    local function PartKey(suffix) return textPart .. suffix end
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
    local function SliderIn(host, range, get, set, suffix)
        Refresh(W.Slider(host, range[1], range[2], range[3], get, function(value) set(math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    local function Slider(host, key, suffix) return SliderIn(host, M.ranges[key], function() return db()[key] end, Set(key), suffix) end
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
        return W.Note(label)
    end
    local function Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    -- "Window 1 - DPS": each window with the meter it shows.
    local function WindowChoices()
        local list = {}
        for _, window in ipairs(M.windows) do
            local meter = addon.Domain.DamageMeter.typeById[M.db[window].meterType]
            list[#list + 1] = { id = window, label = L[M.windowLabels[window]] .. " - " .. L[meter.label] }
        end
        return list
    end

    page.configPreview = W.Preview(page, M, { contentHeight = 140 })
    -- Editing, at the top right of the preview, is seen from every tab.
    if page.previewArea then
        local host = CreateFrame("Frame", nil, page.previewArea)
        host:SetPoint("TOPRIGHT", page.previewArea, "TOPRIGHT", 0, -4); host:SetSize(284, 28)
        page.editingLabel = W.Label(host, L["Editing"], nil, 0, 0, 60, T.muted)
        page.editingLabel:ClearAllPoints(); page.editingLabel:SetPoint("LEFT", 0, 0)
        page.windowSelect = SelectIn(host, 220, WindowChoices, Window, page.SetEditing)
        page.windowSelect:ClearAllPoints(); page.windowSelect:SetPoint("RIGHT", 0, 0)
        page.previewReserveRight = 296
        page:UpdatePreviewLayout()
    end

    -- Each tab says so when the window is off or grouped (Copy & Apply says it its own way).
    local function Tab(title, build)
        page:Section(L[title], nil, false)
        if title == "Copy & Apply" then build(); return end
        if title ~= "Window" then
            When(function() return not db().show end, function() W.Tip(Note("This window is off. Turn on Show Window on the Window tab to use it.")) end)
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
        W.Tip(Note("Click a window's header for its meter, earlier fights and Reset All Data. Click a row for that player's spells.", 32))
        page:Group(L["Size"])
        local size = Columns({ "Width", "Rows" })
        page.widthSlider = Slider(size[1], "width", "px")
        page.rowsSlider = Slider(size[2], "rows")
        local rows = Columns({ "Row Height", "Spacing", "Padding" })
        page.rowHeightSlider = Slider(rows[1], "rowHeight", "px")
        page.spacingSlider = Slider(rows[2], "spacing", "px")
        page.paddingSlider = Slider(rows[3], "padding", "px")
        -- Matched in Edit Mode: the width (and rows, with Match Height) follow the anchor.
        local function Matched() return M:Matching(editing, "Width") or M:Matching(editing, "Height") end
        When(function() return Matched() ~= nil end, function()
            local note = Note("", 32)
            Refresh(function()
                local target = Matched()
                if not target then return end
                local width, height = M:Matching(editing, "Width"), M:Matching(editing, "Height")
                local what = height and (width and L["Width and Rows"] or L["Rows"]) or L["Width"]
                note:SetText(string.format(L["%s follow %s (Match Width and Match Height in Edit Mode)."], what, addon.EditAnchor:TargetLabel(target)))
            end)
            page.matchNote = note
        end)
        page:Group(L["When to Show"])
        local show = Columns({ "Show", "Opacity" })
        page.visibilitySelect = SelectIn(show[1], 200, function() return Localized(M.choices.visibility) end,
            function() return db().visibility end, Set("visibility"))
        page.opacitySlider = Slider(show[2], "opacity", "%")
        page.mouseToggles = Toggles({ { "Lock Window", "locked" }, { "Click Through", "clickThrough" } })
        Note("Unlocked, drag a window's header to move it and the grip in its corner to resize it (out of combat); windows anchored on it with Match Width (Edit Mode, on by default) take its width. The lock button in the header does the same as Lock Window. Hidden windows still show in Edit Mode. Click Through lets clicks and the mouse wheel pass to the game world.", 48)
        page:Group(L["Group"])
        local group = Columns({ "Group With" })
        page.groupSelect = SelectIn(group[1], 200, function() return M:GroupChoices(editing) end,
            function() return M.db[editing].group end, Set("group")); Mark("group")
        When(Grouped, function()
            page.groupSidePills = Choice("Side", "groupSide", 96)
            local gap = Columns({ "Gap" })
            page.groupGapSlider = Slider(gap[1], "groupGap", "px")
        end)
        Note("A grouped window stacks above (by default) or below the window it follows and matches its group: width, bars, text, header, frame, Show and the lock. It keeps its own meter, fight and Rows, so a group grows up or down a window at a time. Move the group by its first window.", 48)
        page:Group(L["Data"])
        local data = page:Row(L["Recorded Fights"], 48)
        page.resetDataButton = W.Button(data, L["Reset All Data"], 150, 30, "secondary")
        page.resetDataButton:SetPoint("LEFT"); page.resetDataButton:SetScript("OnClick", function() M:ResetData() end)
        page.blizzardToggles = Toggles({ { "Hide Blizzard's Meter", get = function() return M.db.hideBlizzard end,
            set = function(value) M:SetHideBlizzard(value) end } })
        W.Tip(Note("The numbers come from the game's own damage meter, which must be on in the game's options; ModeUI never changes that option. Hide Blizzard's Meter tucks Blizzard's meter windows away while this module is on; they keep recording, so ModeUI's windows still fill.", 48))
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

    -- Text: pick a text (Name, Value, Title, Timer), then its own font, size,
    -- outline, shadow and color.
    Tab("Text", function()
        page:Group(L["Text"])
        local parts = {}
        for _, part in ipairs(M.textParts) do parts[#parts + 1] = { id = part, label = M.textPartLabels[part] } end
        page.textPartButtons = Pills("Text", parts, Part, page.SetTextPart, 80); Mark("text")
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
        local size = Columns({ "Size" })
        page.textSizeSlider = SliderIn(size[1], M.ranges.nameSize, function() return db()[PartKey("Size")] end,
            function(value) M:SetOption(editing, PartKey("Size"), value) end)
        local function PartToggle(label, suffix)
            return { label, suffix, get = function() return db()[PartKey(suffix)] end,
                set = function(value) M:SetOption(editing, PartKey(suffix), value) end }
        end
        page.fontToggles = Toggles({ PartToggle("Outline", "Outline"), PartToggle("Slug Text", "Slug") })
        page.shadowPills = Pills("Text Shadow", addon.Kit.SHADOW_CHOICES, function() return addon.Kit.ShadowMode(M.PartStyle(db(), textPart)) end,
            function(mode)
                local shadow, lifted = addon.Kit.ShadowKeys(mode)
                M:SetOption(editing, PartKey("Shadow"), shadow); M:SetOption(editing, PartKey("Lifted"), lifted)
            end)
        When(function() return M.classColorParts[textPart] == true end, function()
            page.textColorPills = Pills("Color", M.choices.nameColorMode, function() return db()[PartKey("ColorMode")] end,
                function(value) M:SetOption(editing, PartKey("ColorMode"), value) end, 96)
        end)
        local color = Columns({ "Text Color" })
        Color(color[1], "partColor", function() return db()[PartKey("ColorMode")] ~= "class" end)
        Note("Names and values can take the class color. Title and Timer are the header's texts.", 32)
        page:Group(L["Layout"])
        local inset = Columns({ "Text Inset" })
        page.insetSlider = Slider(inset[1], "textInset", "px")
        page.rankToggles = Toggles({ { "Show Rank", "showRank" } })
        page:Group(L["Numbers"])
        page.numberPills = Choice("Show", "numbers", 170)
        page.decimalPills = Pills("Decimals", { { id = 0, label = "None" }, { id = 1, label = "1" }, { id = 2, label = "2" }, { id = 3, label = "3" } },
            function() return db().decimals end, Set("decimals"), 56); Mark("numbers")
        page.separatorPills = Choice("Separator", "separator", 52)
        page.percentToggles = Toggles({ { "Show Percent", "showPercent" } })
        Note("Decimals sets the places after K, M and B (12.3K); None shows whole numbers. Numbers under a thousand and counts are always whole. Separator joins the amount, per second and percent: 5K (179, 61%), 5K / 179 / 61%. DPS and HPS show the per-second amount first. The game hides exact amounts from addons during combat, so Percent shows once the fight ends.", 64)
    end)

    Tab("Header", function()
        page.headerToggles = Toggles({ { "Show Header", "header" } }); Mark("header")
        When(function() return db().header end, function()
            page:Group(L["Header Bar"])
            local look = Columns({ "Texture", "Height" })
            page.headerTextureSelect = SelectIn(look[1], 200, function() return addon.Kit.BarTextureChoices(true) end,
                function() return db().headerTexture end, Set("headerTexture"))
            page.headerHeightSlider = Slider(look[2], "headerHeight", "px")
            local fill = Columns({ "Header Color", "Header Opacity" })
            Color(fill[1], "headerColor")
            page.headerOpacitySlider = Slider(fill[2], "headerOpacity", "%")
            Note("By default the header is a Mode Title strip in Graphite raised, as on every ModeUI window.", 32)
            page:Group(L["Header Text"])
            page.titleToggles = Toggles({ { "Uppercase Title", "titleUpper" }, { "Show Fight", "showSession" }, { "Show Timer", "showTimer" } })
            page.titleAlignPills = Choice("Title Position", "titleAlign", 80)
            local offset = Columns({ "Title X", "Title Y" })
            page.titleXSlider = Slider(offset[1], "titleOffsetX", "px")
            page.titleYSlider = Slider(offset[2], "titleOffsetY", "px")
            page.buttonToggles = Toggles({ { "Header Buttons", "headerButtons" } })
            local tools = page:Row(L["Fonts and Colors"], 48)
            for i, part in ipairs({ "title", "timer" }) do
                local button = W.Button(tools, L["Edit " .. M.textPartLabels[part] .. " Text"], 140, 30, "secondary")
                button:SetPoint("LEFT", (i - 1) * 148, 0)
                button:SetScript("OnClick", function() M:JumpTo("text", part) end)
                page[part .. "TextButton"] = button
            end
        end)
        Note("Title Position places the meter's name in the room left of the buttons and timer; Title X and Title Y move it from there. The timer sits at the right edge, with the fight (C for Current, O for Overall, a number for an earlier fight; click to switch, right-click for the list), Reset All Data and the lock to its left. Show Fight adds the fight's full name to the header text. Without a header, pick the meter and fight on the Window tab, or right-click a row.", 64)
    end)

    Tab("Frame", function()
        page:Group(L["Background"])
        local background = Columns({ "Background Color", "Background Opacity" }); Mark("frame")
        Color(background[1], "backgroundColor")
        page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
        Note("The edge is the Mode window edge, as on every ModeUI window, so it has no settings. A see-through window has no drop shadow. A one-pixel line sits under the header.", 32)
    end)

    -- Copy & Apply: the window in Editing is the source. Pick what to copy
    -- (All, Window, Bars or Text), tick windows, then apply.
    local SCOPE_NOTES = {
        all = "Everything: size, bars, text, header and frame. Each window keeps its own meter, fight, show settings, group and matching.",
        window = "The window itself, with its header: width, padding, opacity, background, and the header's texture, height, color, title and buttons.",
        bars = "The bars: row height, spacing, textures, opacity, colors, icon and Always Show Me.",
        text = "Every text: the name, value, title and timer fonts, sizes, outlines, shadows and colors, with Text Inset, Show Rank, numbers, Decimals, Separator and Show Percent.",
    }
    local scope = "all"
    page.copyScope = function() return scope end
    Tab("Copy & Apply", function()
        page:Group(L["Copy From"])
        local source = W.Label(page:Row(L["Window"], 32), "", nil, 0, -6, 360, T.text)
        Refresh(function()
            local labels, head = {}, M:Leader(editing)
            for _, choice in ipairs(WindowChoices()) do labels[choice.id] = choice.label end
            local text = labels[editing]
            if head ~= editing then text = text .. " " .. string.format(L["(its group's look, from %s)"], L[M.windowLabels[head]]) end
            source:SetText(text)
        end)
        page.applySource = source
        page.copyScopePills = Pills("Copy", M.copyScopeChoices, function() return scope end,
            function(value) scope = value; page:Refresh() end, 96)
        local what = Note("", 48)
        Refresh(function() what:SetText(L[SCOPE_NOTES[scope]]) end)
        page:Group(L["Apply To"])
        local targets, items = {}, {}
        for _, window in ipairs(M.windows) do
            items[#items + 1] = { label = L[M.windowLabels[window]],
                get = function() return window ~= editing and targets[window] == true end,
                set = function(on) if window ~= editing then targets[window] = on or nil end end }
        end
        page.applyTargets = targets
        -- The windows to copy to, as buttons to tick.
        page.applyChoices = page:ChoiceGrid(items)
        local apply = page:Row("", 62)
        apply.rowLabel:Hide(); apply:ClearAllPoints(); apply:SetAllPoints(apply.row)
        page.applyButton = W.Button(apply, L["Apply to Selected"], 150, 30, "secondary")
        page.applyButton:SetPoint("TOPLEFT", 0, -2)
        page.applyAllButton = W.Button(apply, L["Apply to All Windows"], 160, 30, "secondary")
        page.applyAllButton:SetPoint("LEFT", page.applyButton, "RIGHT", 8, 0)
        local result = W.Label(apply, "", nil, 0, 0, 140, T.muted)
        result:ClearAllPoints(); result:SetPoint("TOPLEFT", page.applyButton, "BOTTOMLEFT", 0, -6)
        page.applyResult = result
        local function Report(ok, count)
            result:SetText(ok and string.format(L["Applied to %d windows."], count or 0) or L["Choose windows first."])
        end
        page.applyButton:SetScript("OnClick", function()
            local chosen = false
            for window in pairs(targets) do if window ~= editing then chosen = true end end
            if not chosen then Report(false); return end
            Report(M:CopyStyleTo(editing, targets, scope))
        end)
        page.applyAllButton:SetScript("OnClick", function() Report(M:CopyStyleToAll(editing, scope)) end)
        Refresh(function() if editing ~= page.applyResultWindow then result:SetText(""); page.applyResultWindow = editing end end)
        Note("A grouped window takes the copy on its group's first window, so its whole group changes.", 32)
        page:Group(L["Reset"])
        local reset = page:Row("", 40)
        reset.rowLabel:Hide(); reset:ClearAllPoints(); reset:SetAllPoints(reset.row)
        page.resetButton = W.Button(reset, L["Reset to Defaults"], 150, 30, "secondary")
        page.resetButton:SetPoint("LEFT"); page.resetButton:SetScript("OnClick", function() M:ResetWindow(editing) end)
        Note("Puts the window in Editing (its group, when grouped) back to ModeUI's defaults; its meter, fight, show settings and group stay.", 32)
    end)

    W.SectionTabs(page)
    page:Finish(); return page
end

-- A preview click: scroll to the setting on its tab; `part` picks the text.
function M:JumpTo(target, part)
    local page = self.page
    if not page or not page.jumpTargets or not page.jumpTargets[target] then return false end
    if part then page.SetTextPart(part) end
    page:Reveal(page.jumpTargets[target])
    return true
end

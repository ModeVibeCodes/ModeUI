local _, addon = ...
local M, W, T, L = addon.DamageMeters, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of the window being edited sits above the standard tabs (General,
-- Fill, Border, Text, Behavior), with Editing (which window, and its meter)
-- at its top right as on the Action Bars page. Clicking a part of the preview
-- jumps to its settings. Copy To… and Reset… in the footer work on the window
-- in Editing (M:CopyActions, M:ResetScopes).
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing, textPart = "window1", "name"
    local function Window() return editing end
    local function Part() return textPart end
    -- What the window draws with: a grouped window's shared settings are its group's.
    local function db() return M:Style(editing) end
    local function Grouped() return M:IsGrouped(editing) end
    local function Header() return db().header end
    page.windowEditing, page.textPart = Window, Part
    function page.SetEditing(window) if M.windowLabels[window] then editing = window; page:Refresh(); page:Layout() end end
    -- The text last opened from the preview (each text has its own card).
    function page.SetTextPart(part) if M.textPartLabels[part] then textPart = part end end
    local owner = M:AppearanceOwner(Window, Part)
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
    local function Color(host, key, enabled, keyOwner)
        W.ColorRow(page, keyOwner or owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host)
    end
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
    page.configPreview = W.Preview(page, M, { contentHeight = 140 })
    -- Editing, at the top right of the preview, is seen from every tab.
    if page.previewArea then
        local host = CreateFrame("Frame", nil, page.previewArea)
        host:SetPoint("TOPRIGHT", page.previewArea, "TOPRIGHT", 0, -4); host:SetSize(284, 28)
        page.editingLabel = W.Label(host, L["Editing"], nil, 0, 0, 60, T.muted)
        page.editingLabel:ClearAllPoints(); page.editingLabel:SetPoint("LEFT", 0, 0)
        page.windowSelect = SelectIn(host, 220, function() return M:WindowChoices() end, Window, page.SetEditing)
        page.windowSelect:ClearAllPoints(); page.windowSelect:SetPoint("RIGHT", 0, 0)
        page.previewReserveRight = 296
        page:UpdatePreviewLayout()
    end

    -- Above every tab: when the window is off, or grouped.
    When(function() return not db().show end, function() W.Tip(Note("This window is off. Turn on Show Window on the General tab to use it.")) end)
    When(Grouped, function()
        local note = Note("", 32)
        Refresh(function()
            local head = L[M.windowLabels[M:Leader(editing)]]
            note:SetText(string.format(L["Grouped: these settings are shared with %s, so changing them changes the whole group. Meter, Fight and Rows stay this window's own."], head))
        end)
    end)

    page:Tab("General")
    page:Group(L["Show"])
    page.showToggles = Toggles({ { "Show Window", "show" }, { "Show Header", "header" } }); Mark("window")
    page.headerToggles = page.showToggles
    When(Header, function() page.buttonToggles = Toggles({ { "Header Buttons", "headerButtons" } }) end)
    page.iconPills = Choice("Icon", "icon", 110)
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page.blizzardToggles = Toggles({ { "Hide Blizzard's Meter", get = function() return M.db.hideBlizzard end,
        set = function(value) M:SetHideBlizzard(value) end } })
    W.Tip(Note("The numbers come from the game's own damage meter, which must be on in the game's options; ModeUI never changes that option. Hide Blizzard's Meter tucks Blizzard's meter windows away while this module is on; they keep recording, so ModeUI's windows still fill.", 48))
    page:Group(L["Meter"])
    local meter = Columns({ "Meter" })
    page.meterSelect = SelectIn(meter[1], 220, function() return Localized(M.choices.meterType) end,
        function() return db().meterType end, Set("meterType"))
    page.sessionPills = Choice("Fight", "session", 120)
    W.Tip(Note("Click a window's header for its meter, earlier fights and Reset All Data. Click a row for that player's spells.", 32))
    page:Group(L["Group"])
    local group = Columns({ "Group With" })
    page.groupSelect = SelectIn(group[1], 200, function() return M:GroupChoices(editing) end,
        function() return M.db[editing].group end, Set("group")); Mark("group")
    When(Grouped, function()
        page.groupSidePills = Choice("Side", "groupSide", 96)
        local gap = Columns({ "Spacing" })
        page.groupGapSlider = Slider(gap[1], "groupGap", "px")
    end)
    Note("A grouped window stacks above (by default) or below the window it follows and matches its group: width, bars, text, header, frame, Show and the lock. It keeps its own meter, fight and Rows, so a group grows up or down a window at a time. Move the group by its first window.", 48)
    page:Group(L["Size"])
    local size = Columns({ "Width", "Rows" })
    page.widthSlider = Slider(size[1], "width", "px")
    page.rowsSlider = Slider(size[2], "rows")
    local rows = Columns({ "Row Height", "Spacing", "Padding" })
    page.rowHeightSlider = Slider(rows[1], "rowHeight", "px")
    page.spacingSlider = Slider(rows[2], "spacing", "px")
    page.paddingSlider = Slider(rows[3], "padding", "px")
    When(Header, function()
        local header = Columns({ "Header Height" })
        page.headerHeightSlider = Slider(header[1], "headerHeight", "px")
    end)
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
    page:Group(L["Data"])
    local data = page:Row(L["Recorded Fights"], 48)
    page.resetDataButton = W.Button(data, L["Reset All Data"], 150, 30, "secondary")
    page.resetDataButton:SetPoint("LEFT"); page.resetDataButton:SetScript("OnClick", function() M:ResetData() end)

    page:Tab("Fill")
    page:Group(L["Bars"])
    local textures = Columns({ "Foreground", "Background" })
    page.barTextureSelect = SelectIn(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end,
        function() return db().barTexture end, Set("barTexture")); Mark("bars")
    page.barBackgroundSelect = SelectIn(textures[2], 200, function() return addon.Kit.BarTextureChoices(false) end,
        function() return db().barBackground end, Set("barBackground"))
    local fade = Columns({ "Bar Opacity", "Background Opacity" })
    page.barOpacitySlider = Slider(fade[1], "barOpacity", "%")
    page.barBackgroundSlider = Slider(fade[2], "barBackgroundOpacity", "%")
    page:Group(L["Bar Color"])
    page.colorPills = Choice("Bar Color", "barColorMode", 96)
    local colors = Columns({ "Custom Color", "Other Color" })
    Color(colors[1], "barColor", function() return db().barColorMode == "custom" end)
    Color(colors[2], "otherColor")
    Note("Class Color uses Class Colors when you've set them. Other Color is for anything without a class, like pets and creatures.", 32)
    When(Header, function()
        page:Group(L["Header Bar"])
        local look = Columns({ "Texture" })
        page.headerTextureSelect = SelectIn(look[1], 200, function() return addon.Kit.BarTextureChoices(true) end,
            function() return db().headerTexture end, Set("headerTexture")); Mark("header")
        local fill = Columns({ "Header Color", "Header Opacity" })
        Color(fill[1], "headerColor")
        page.headerOpacitySlider = Slider(fill[2], "headerOpacity", "%")
        Note("By default the header is a Mode Title strip in Graphite raised, as on every ModeUI window.", 32)
    end)
    page:Group(L["Background"])
    local background = Columns({ "Background Color", "Background Opacity" }); Mark("frame")
    Color(background[1], "backgroundColor")
    page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")

    page:Tab("Border")
    page:Group(L["Border"])
    page.borderStyle, page.borderMetal = W.BorderPickers(page,
        { get = function() return db().edgeStyle end, set = Set("edgeStyle") },
        { get = function() return db().edgeMetal end, set = Set("edgeMetal") })
    Note("The window's border, also on its breakdown and menu. A see-through window has no drop shadow. A one-pixel line sits under the header.", 32)

    -- Text: one card per text (Name, Value, Title, Timer), each with its own
    -- font, size, outline, shadow and color.
    page:Tab("Text")
    page:Group(L["Text Style"])
    local inset = Columns({ "Text Inset" })
    page.insetSlider = Slider(inset[1], "textInset", "px")
    local function TextCard(part, first, last)
        local partOwner = M:AppearanceOwner(Window, function() return part end)
        local function Key(suffix) return part .. suffix end
        local function SetPart(suffix) return function(value) M:SetOption(editing, Key(suffix), value) end end
        page:Group(L[M.textPartLabels[part] .. " Text"]); Mark("text:" .. part)
        if first then first() end
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), partOwner); Refresh(fontRefresh)
        local size = Columns({ "Size" })
        page[part .. "SizeSlider"] = SliderIn(size[1], M.ranges[Key("Size")], function() return db()[Key("Size")] end, SetPart("Size"))
        page[part .. "FontToggles"] = Toggles({ { "Outline", Key("Outline") }, { "Slug Text", Key("Slug") } })
        page[part .. "ShadowPills"] = Pills("Shadow", addon.Kit.SHADOW_CHOICES, function() return addon.Kit.ShadowMode(M.PartStyle(db(), part)) end,
            function(mode)
                local shadow, lifted = addon.Kit.ShadowKeys(mode)
                M:SetOption(editing, Key("Shadow"), shadow); M:SetOption(editing, Key("Lifted"), lifted)
            end)
        if M.classColorParts[part] then
            page[part .. "ColorPills"] = Pills("Color", M.choices[Key("ColorMode")], function() return db()[Key("ColorMode")] end, SetPart("ColorMode"), 96)
        end
        local color = Columns({ "Text Color" })
        Color(color[1], "partColor", function() return db()[Key("ColorMode")] ~= "class" end, partOwner)
        if last then last() end
    end
    TextCard("name", nil, function() page.rankToggles = Toggles({ { "Show Rank", "showRank" } }) end)
    TextCard("value", nil, function()
        page.numberPills = Choice("Show", "numbers", 170); Mark("numbers")
        page.decimalPills = Pills("Decimals", { { id = 0, label = "None" }, { id = 1, label = "1" }, { id = 2, label = "2" }, { id = 3, label = "3" } },
            function() return db().decimals end, Set("decimals"), 56)
        page.separatorPills = Choice("Separator", "separator", 52)
        page.percentToggles = Toggles({ { "Show Percent", "showPercent" } })
        Note("Decimals sets the places after K, M and B (12.3K); None shows whole numbers. Numbers under a thousand and counts are always whole. Separator joins the amount, per second and percent: 5K (179, 61%), 5K / 179 / 61%. DPS and HPS show the per-second amount first. The game hides exact amounts from addons during combat, so Percent shows once the fight ends.", 64)
    end)
    When(Header, function()
        TextCard("title", function()
            page.titleToggles = Toggles({ { "Show Fight", "showSession" }, { "Uppercase Title", "titleUpper" } })
            page.titleAlignPills = Choice("Title Position", "titleAlign", 80)
            local offset = Columns({ "Title X", "Title Y" })
            page.titleXSlider = Slider(offset[1], "titleOffsetX", "px")
            page.titleYSlider = Slider(offset[2], "titleOffsetY", "px")
            Note("Title Position places the meter's name in the room left of the buttons and timer; Title X and Title Y move it from there. The timer sits at the right edge, with the fight (C for Current, O for Overall, a number for an earlier fight; click to switch, right-click for the list), Reset All Data and the lock to its left. Show Fight adds the fight's full name to the header text. Without a header, pick the meter and fight on the General tab, or right-click a row.", 64)
        end)
        TextCard("timer", function() page.timerToggles = Toggles({ { "Show Timer", "showTimer" } }) end)
    end)

    page:Tab("Behavior")
    page:Group(L["When to Show"])
    local show = Columns({ "Show", "Window Opacity" })
    page.visibilitySelect = SelectIn(show[1], 200, function() return Localized(M.choices.visibility) end,
        function() return db().visibility end, Set("visibility"))
    page.opacitySlider = Slider(show[2], "opacity", "%")
    page.mouseToggles = Toggles({ { "Lock Window", "locked" }, { "Click Through", "clickThrough" } })
    Note("Unlocked, drag a window's header to move it and the grip in its corner to resize it (out of combat); windows anchored on it with Match Width (Edit Mode, on by default) take its width. The lock button in the header does the same as Lock Window. Hidden windows still show in Edit Mode. Click Through lets clicks and the mouse wheel pass to the game world.", 48)
    page:Group(L["Rows"])
    page.rowToggles = Toggles({ { "Always Show Me", "alwaysShowMe" } })
    Note("Always Show Me keeps your own row in view: when you rank below the last row, you take its place.", 32)

    W.StandardTabs(page)
    page:Finish(); return page
end

-- "Window 1 - DPS": each window with the meter it shows.
function M:WindowChoices()
    local list = {}
    for _, window in ipairs(self.windows) do
        local meter = addon.Domain.DamageMeter.typeById[self.db[window].meterType]
        list[#list + 1] = { id = window, label = L[self.windowLabels[window]] .. " - " .. L[meter.label] }
    end
    return list
end

-- The window in Editing on the settings page (the first window before it's built).
function M:EditingWindow()
    local page = self.page
    return page and page.windowEditing and page.windowEditing() or self.windows[1]
end

-- Copy To…: the window in Editing is the source (its group's look, when
-- grouped). One item per part and target: each other window that doesn't
-- already share its look, then every window. A grouped target takes the copy
-- on its group's first window, so its whole group changes.
local COPY_PARTS = {
    { scope = "all", label = "Look", what = "everything: size, bars, text, header and frame. Each window keeps its own meter, fight, show settings, group and matching." },
    { scope = "window", label = "Window and header", what = "the window itself, with its header: width, padding, opacity, background, border, and the header's texture, height, color, title and buttons." },
    { scope = "bars", label = "Bars", what = "the bars: row height, spacing, textures, opacity, colors, icon and Always Show Me." },
    { scope = "text", label = "Text", what = "every text: the name, value, title and timer fonts, sizes, outlines, shadows and colors, with Text Inset, Show Rank, numbers, Decimals, Separator and Show Percent." },
}
function M:CopyActions()
    local from = self:EditingWindow()
    local source, head = L[self.windowLabels[from]], self:Leader(from)
    local targets = {}
    for _, window in ipairs(self.windows) do
        if self:Leader(window) ~= head then targets[#targets + 1] = window end
    end
    local items = {}
    if #targets == 0 then return items end
    for _, part in ipairs(COPY_PARTS) do
        local function Prompt(where)
            return string.format(L["Copy %s's %s to %s? This copies %s A grouped window takes the copy on its group's first window, so its whole group changes."],
                source, L[part.label]:lower(), where, L[part.what])
        end
        for _, window in ipairs(targets) do
            local name = L[self.windowLabels[window]]
            items[#items + 1] = { label = string.format(L["%s to %s"], L[part.label], name), prompt = Prompt(name),
                run = function() self:CopyStyleTo(from, { [window] = true }, part.scope) end }
        end
        if #targets > 1 then
            items[#items + 1] = { label = string.format(L["%s to %s"], L[part.label], L["every window"]), prompt = Prompt(L["every window"]),
                run = function() self:CopyStyleToAll(from, part.scope) end }
        end
    end
    return items
end

-- Reset…: the window in Editing (its group, when grouped).
function M:ResetScopes()
    local window = self:EditingWindow()
    local name = L[self.windowLabels[window]]
    return { { label = self:IsGrouped(window) and string.format(L["%s and its group"], name) or name,
        run = function() self:ResetWindow(window) end,
        prompt = string.format(L["Put %s (its group, when grouped) back to ModeUI's defaults? Its meter, fight, show settings and group stay."], name) } }
end

-- A preview click: scroll to the setting on its tab; `part` picks the text's card.
function M:JumpTo(target, part)
    local page = self.page
    if not page or not page.jumpTargets then return false end
    local entry = part and page.jumpTargets[target .. ":" .. part] or page.jumpTargets[target]
    if not entry then return false end
    if part then page.SetTextPart(part) end
    page:Reveal(entry)
    return true
end

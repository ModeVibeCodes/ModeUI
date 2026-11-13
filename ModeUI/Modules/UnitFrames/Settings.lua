local _, addon = ...
local M, W, T = addon.UnitFrames, addon.ConfigWidgets, addon.InterfaceTheme
if not M then return end

-- One tab per frame element (Layout, Portrait, Name & Level, Health, Power,
-- Text); the Onyx rim and gap are locked, so there is no Border
-- tab. Each element tab edits the Player or the Target, picked by the Editing
-- switch at its top; the choice is shared by every tab for this session.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing = "player"
    local function Unit() return editing end
    local function db() return M.db[editing] end
    local owner = M:AppearanceOwner(Unit)
    page.unitFrameEditing = Unit

    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    -- Controls take the host they fill: a labeled row, or one cell of Columns.
    local function SelectIn(host, width, choices, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get()
            for _, choice in ipairs(choices()) do if choice.id == value then return value, choice.label end end
            return value, addon.Media:MediaLabel(tostring(value):gsub("^media:", ""))
        end, set)
        page.refreshers[#page.refreshers + 1] = function() button:Refresh() end
        return button
    end
    local function Select(label, choices, get, set) return SelectIn(page:Row(label, 48), 260, choices, get, set) end
    local function Set(key) return function(v) M:SetFrameOption(editing, key, v) end end
    local function SliderIn(host, key, suffix)
        local r = M.frameRanges[key]
        page.refreshers[#page.refreshers + 1] = W.Slider(host, r[1], r[2], r[3],
            function() return db()[key] end, function(v) M:SetFrameOption(editing, key, math.floor(v + 0.5)) end, suffix, true)
        return host.slider
    end
    local function Slider(text, key, suffix) return SliderIn(page:Row(text, 48), key, suffix) end
    local function Choice(text, key)
        local list = M.choices[M.choiceKeys[key]]
        Select(text, function() return list end, function() return db()[key] end, Set(key))
    end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            local key = entry[2]
            items[#items + 1] = { label = entry[1], get = entry.get or function() return db()[key] end, set = entry.set or Set(key) }
        end
        page:ToggleGrid(items, { maxColumns = 2, minimumCellWidth = 210 })
    end
    local function Color(text, key, enabled) W.ColorRow(page, owner, text, key, enabled) end
    local function Matched() return editing == "target" and db().matchPlayer end
    local function Note(title, text, height)
        local label = W.Label(page:Row(title, height or 40), text, nil, 0, -4, 420, T.muted); label:SetWordWrap(true)
        return label
    end

    -- Frames: visibility, matching, status and whole-frame tools.
    page:Section("Frames", nil, false)
    -- One line per frame: show it, and hide Blizzard's own beside it.
    local cells = {}
    for _, unit in ipairs(M.units) do
        local title = M.titles[unit]
        cells[#cells + 1] = { label = "Show " .. title, get = function() return M.db[unit].enabled end,
            set = function(v) M:SetFrameOption(unit, "enabled", v) end }
        cells[#cells + 1] = { label = "Hide Blizzard " .. title, get = function() return M.db[unit].hideBlizzard end,
            set = function(v) M:SetFrameOption(unit, "hideBlizzard", v) end }
    end
    cells[#cells + 1] = { label = "Target Matches Player", get = function() return M.db.target.matchPlayer end,
        set = function(v) M:SetFrameOption("target", "matchPlayer", v) end }
    page.unitFrameToggles = page:ToggleGrid(cells, { maxColumns = 2, minimumCellWidth = 210 })
    local status = W.Label(page:Row("Status", 56), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    page.unitFrameStatus = status
    page.refreshers[#page.refreshers + 1] = function() status:SetText(M:Status()) end
    page:Group("Style Tools")
    -- Player and Target copy their style to each other; the smaller frames
    -- copy the Player's.
    for _, unit in ipairs(M.units) do
        local title, name = M.titles[unit], M.frameNames[unit]
        local from, to, text = unit, unit == "player" and "target" or "player", nil
        if unit == "player" or unit == "target" then text = "Copy Style to " .. M.labels[to]
        else from, to, text = "player", unit, "Copy Player Style" end
        local row = page:Row(title .. " Tools", 48)
        local reset = W.Button(row, "Reset " .. title, 190, 28); reset:SetPoint("LEFT")
        reset:SetScript("OnClick", function() M:ResetFrame(unit) end)
        local copy = W.Button(row, text, 190, 28); copy:SetPoint("LEFT", 198, 0)
        copy:SetScript("OnClick", function() M:CopyStyle(from, to) end)
        page["unitFrameReset" .. name], page["unitFrameCopy" .. name] = reset, copy
    end

    -- Every element tab starts with the Editing choice (one of the five
    -- frames); a matched or hidden frame explains itself instead of showing
    -- controls that would not apply.
    local frameChoices = {}
    for _, unit in ipairs(M.units) do frameChoices[#frameChoices + 1] = { id = unit, label = M.labels[unit] } end
    function page.SetEditing(unit) if M.labels[unit] then editing = unit; page:Refresh(); page:Layout() end end
    page.unitFrameEditSelects = {}
    local function Tab(title, build)
        page:Section(title, nil, false)
        local row = page:Row("Editing", 48, { "player", "target", "focus", "frame" })
        page.unitFrameEditSelects[#page.unitFrameEditSelects + 1] = SelectIn(row, 260, function() return frameChoices end,
            Unit, page.SetEditing)
        When(function() return editing == "target" and db().enabled end, function()
            Toggles({ { "Match Player Frame", "matchPlayer" } })
        end)
        When(Matched, function()
            Toggles({ { "Mirror Player Text", "mirrorText" } })
            Note("Target Matches Player", "Uses the Player frame's look and text layout. Turn on Mirror Player Text to flip the text alignment to the other side, or turn off Match Player Frame to customize the Target separately.", 52)
        end)
        When(function() return not db().enabled end, function()
            Note("Frame Hidden", "This frame is turned off. Turn it on in the Frames tab to customize it.")
        end)
        When(function() return db().enabled and not Matched() end, build)
    end

    Tab("Layout", function()
        page:Group("Size")
        Slider("Scale", "scale", "%"); Slider("Bar Width", "barWidth")
        -- Both bars: the fill (foreground) and the empty bar (background).
        page:Group("Bar Textures")
        local textures = page:Columns({ "Foreground", "Background" })
        page.unitFrameForeground = SelectIn(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end,
            function() return db().foregroundTexture end, Set("foregroundTexture"))
        page.unitFrameBackground = SelectIn(textures[2], 200, function() return addon.Kit.BarTextureChoices(false) end,
            function() return db().backgroundTexture end, Set("backgroundTexture"))
        page:Group("Bar Opacity")
        local fade = page:Columns({ "Foreground Opacity", "Background Opacity" })
        page.unitFrameForegroundOpacity = SliderIn(fade[1], "barForegroundOpacity", "%")
        page.unitFrameBackgroundOpacity = SliderIn(fade[2], "barBackgroundOpacity", "%")
    end)

    Tab("Portrait", function()
        Toggles({ { "Show Portrait", "showPortrait" } })
        When(function() return db().showPortrait end, function()
            Choice("Portrait Style", "portraitStyle"); Choice("Portrait Side", "portraitSide")
            -- Sized against the bar block; the full ring is drawn over the bar's end.
            Slider("Portrait Size", "portraitScale", "%")
            Choice("Portrait Ring", "portraitRing")
            When(function() return db().portraitRing == "custom" end, function() Color("Portrait Ring Color", "portraitRingColor") end)
        end)
    end)

    Tab("Name & Level", function()
        page:Group("Name")
        Toggles({ { "Show Name", "showName" } })
        When(function() return db().showName end, function()
            Choice("Name Position", "namePosition"); Choice("Name Alignment", "nameAlign")
            -- Plain text: Sky by default, or Champagne, Lilac, Frost, class or custom.
            Choice("Name Color", "nameColorMode")
            When(function() return db().nameColorMode == "custom" end, function() Color("Custom Name Color", "nameColor") end)
            Slider("Name Font Size", "nameFontSize")
            Slider("Name Offset X", "nameOffsetX"); Slider("Name Offset Y", "nameOffsetY")
        end)
        -- Pastel: class-colored names, class health and the class gradient ring all use it.
        Slider("Class Color Softness", "classSoftness", "%")
        page:Group("Level")
        Toggles({ { "Show Level", "levelStyle", get = function() return db().levelStyle ~= "none" end,
            set = function(v) M:SetFrameOption(editing, "levelStyle", v and "badge" or "none") end } })
        When(function() return db().levelStyle ~= "none" end, function()
            Slider("Level Font Size", "levelFontSize"); Color("Level Color", "levelColor")
            Slider("Level Offset X", "levelOffsetX"); Slider("Level Offset Y", "levelOffsetY")
        end)
    end)

    Tab("Health", function()
        page:Group("Health Bar")
        Slider("Health Bar Height", "healthHeight")
        -- Default is Onyx #1C1E21; the empty bar and background stay Onyx.
        Choice("Health Color", "healthColorMode")
        When(function() return db().healthColorMode == "custom" end, function() Color("Custom Health Color", "healthColor") end)
        page:Group("Health Text")
        Choice("Health Text", "healthText")
        When(function() return db().healthText ~= "none" end, function()
            Choice("Health Text Position", "healthTextPosition"); Slider("Health Font Size", "healthFontSize")
            Slider("Health Text Offset X", "healthTextOffsetX"); Slider("Health Text Offset Y", "healthTextOffsetY")
        end)
    end)

    Tab("Power", function()
        page:Group("Power Bar")
        Toggles({ { "Show Power Bar", "showPower" } })
        When(function() return db().showPower end, function()
            Slider("Power Bar Height", "powerHeight")
            Choice("Power Color", "powerColorMode")
            When(function() return db().powerColorMode == "custom" end, function() Color("Custom Power Color", "powerColor") end)
            page:Group("Power Text")
            Choice("Power Text", "powerText")
            When(function() return db().powerText ~= "none" end, function()
                Choice("Power Text Position", "powerTextPosition"); Slider("Power Font Size", "powerFontSize")
                Slider("Power Text Offset X", "powerTextOffsetX"); Slider("Power Text Offset Y", "powerTextOffsetY")
            end)
        end)
    end)

    Tab("Text", function()
        local _, refresh = W.FontDropdown(page:Row("Font", 42), owner); page.refreshers[#page.refreshers + 1] = refresh
        Toggles({ { "Text Outline", "outline" } })
        -- One choice for both shadows: None, Crisp (1px) or Lifted (1px plus a lighter one under it).
        local choices = {}
        for _, choice in ipairs(addon.Kit.SHADOW_CHOICES) do choices[#choices + 1] = { label = choice.label, value = choice.id, width = 96 } end
        local _, refresh = W.Exclusive(page:Row("Text Shadow", 48), choices, function() return addon.Kit.ShadowMode(db()) end, function(mode)
            local shadow, lifted = addon.Kit.ShadowKeys(mode)
            M:SetFrameOption(editing, "shadow", shadow); M:SetFrameOption(editing, "liftedShadow", lifted)
        end)
        page.refreshers[#page.refreshers + 1] = refresh
        Color("Text Color", "textColor")
    end)

    local note = W.Label(page:Row("About Unit Frames", 170), "Each tab customizes one part of the frame; use Editing at the top of a tab to pick the Player, Target, Target of Target, Focus or Target of Focus frame. Every frame uses the Onyx skin: a round portrait with a full ring caps one rounded bar block inside a pixel-perfect slate rim and black gap, with a hairline between health and power. The rim and gap are fixed. Each bar has a foreground (fill) and background (empty bar) texture and opacity; the background is 25% by default, so the world shows through the empty part. Health is Onyx #1C1E21 by default, or the class color or a custom color. Names are plain Sky text by default (or Champagne, Lilac, Frost, the class color or a custom color). Every text has a crisp one-pixel shadow and a lifted shadow. Class Color Softness blends class and reaction colors toward white for a pastel look. A Target matching the Player copies its look and text layout, optionally mirrored. Move frames with Edit Mode. Size, visibility and position changes wait until combat ends because Blizzard protects clickable unit frames. Hiding a Blizzard frame only fades its main art and bars, so pet frames, combo points, target auras and cast bars keep working; Blizzard's Target of Target and Target of Focus fade with the Target and Focus frames they sit on. The Target of Target and Target of Focus refresh ten times a second, because the game sends no events for them.", nil, 0, -4, 420, T.muted)
    note:SetWordWrap(true); page:FooterNote(note)
    W.PinnedSectionTabs(page)
    page:Finish(); return page
end

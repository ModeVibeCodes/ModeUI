local _, addon = ...
local M, W, T, L = addon.Windows, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. Three
-- tabs, pinned above the scrolling cards: Look (Window Style, frame, text,
-- controls), Windows (one row per window: its switch, and a chevron that
-- expands its own Scale and look; all collapsed at first) and Character
-- (SettingsCharacter.lua). Changes repaint every skinned window right away.
local CHEVRON_SIZE = 16

-- Page helpers shared with SettingsCharacter.lua.
local function Helpers(page)
    local H = {}
    function H.Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    function H.Set(key) return function(value) M:SetOption(key, value) end end
    function H.When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    function H.SliderIn(host, range, get, set, suffix)
        H.Refresh(W.Slider(host, range[1], range[2], range[3], get, function(value) set(math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    function H.Slider(host, key, suffix)
        return H.SliderIn(host, M.ranges[key], function() return M.db[key] end, H.Set(key), suffix)
    end
    function H.Columns(titles)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized)
    end
    function H.Toggles(entries, columns)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = entry.get or function() return M.db[entry[2]] end, set = entry.set or H.Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = columns or 3, minimumCellWidth = 150 })
    end
    function H.Pills(title, list, get, set, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 110 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get, function(value) set(value); page:Refresh(); page:Layout() end)
        H.Refresh(refresh)
        return buttons
    end
    function H.Color(host, key, enabled) W.ColorRow(page, M:AppearanceOwner(), host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    -- A muted note as wide as its card and as tall as its lines.
    function H.Note(text)
        local host = page:Row("", 32)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        function host.row:layoutChildren(width)
            label:SetWidth(math.max(40, width))
            local lines = label:GetStringHeight()
            if addon.IsNumber(lines, 1, 400) then self:SetHeight(math.ceil(lines) + 12) end
        end
        return label
    end
    return H
end

-- One window's header: its switch (Mode look on or off), its name, and a
-- chevron that expands its own settings. The whole row toggles the chevron.
local function WindowHeader(page, H, entry, expanded)
    local id = entry.id
    local host = page:Row("", 36, nil, true)
    host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
    page.searchEntries[#page.searchEntries].label = L[entry.label]
    local toggle = W.Button(host, "", 28, 28, "checkbox")
    toggle:SetPoint("LEFT", 0, 0)
    toggle:SetScript("OnClick", function() M:SetWindow(id, not M.db.windows[id]); page:Refresh() end)
    local expand = CreateFrame("Button", nil, host)
    expand:SetPoint("TOPLEFT", toggle, "TOPRIGHT", 4, 0); expand:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    expand:RegisterForClicks("LeftButtonUp")
    local label = W.Label(expand, L[entry.label], nil, 0, 0, 260)
    label:ClearAllPoints(); label:SetPoint("LEFT", expand, "LEFT", 6, 0)
    local chevron = W.Shape(expand, "ModeChevron", "OVERLAY")
    chevron:SetSize(CHEVRON_SIZE, CHEVRON_SIZE); chevron:SetPoint("RIGHT", expand, "RIGHT", -6, 0)
    local function Paint()
        local open = expanded[id] == true
        -- Down when open; turned to point right while collapsed.
        if chevron.SetRotation then chevron:SetRotation(open and 0 or math.pi / 2) end
        local color = (open or expand.hovered) and T.primary or T.muted
        chevron:SetVertexColor(color[1], color[2], color[3], 1)
    end
    expand:SetScript("OnClick", function() expanded[id] = not expanded[id]; Paint(); page:Layout() end)
    expand:SetScript("OnEnter", function() expand.hovered = true; Paint() end)
    expand:SetScript("OnLeave", function() expand.hovered = false; Paint() end)
    H.Refresh(function() toggle:SetSelected(M.db.windows[id] == true); Paint() end)
    return { toggle = toggle, expand = expand, chevron = chevron }
end

-- A window's own settings, shown while its row is expanded.
local function WindowLook(page, H, entry, expanded)
    local id = entry.id
    local function Look() return M.db.looks[id] end
    local function SetLook(key) return function(value) M:SetLook(id, key, value) end end
    local controls = {}
    H.When(function() return expanded[id] == true end, function()
        if not entry.noScale then
            local scale = H.Columns({ "Scale" })
            controls.scale = H.SliderIn(scale[1], M.lookRanges.scale, function() return Look().scale end, SetLook("scale"), "%")
        end
        controls.custom = H.Toggles({ { "Own Look", "custom", get = function() return Look().custom end, set = SetLook("custom") } }, 2)
        H.When(function() return Look().custom end, function()
            local opacity = H.Columns({ "Background Opacity" })
            controls.opacity = H.SliderIn(opacity[1], M.lookRanges.backgroundOpacity, function() return Look().backgroundOpacity end,
                SetLook("backgroundOpacity"), "%")
            controls.toggles = H.Toggles({ { "Border", "border", get = function() return Look().border end, set = SetLook("border") },
                { "Title Bar", "titleBar", get = function() return Look().titleBar end, set = SetLook("titleBar") } }, 2)
        end)
    end)
    return controls
end

function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local owner = M:AppearanceOwner()
    local H = Helpers(page)

    page:Section(L["Look"], nil, false)
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    H.Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page:Group(L["Window Style"])
    page.stylePills = H.Pills("Style", M.choices.style, function() return M.db.style end, H.Set("style"), 120)
    H.Note("ModeUI restyles every window below; Blizzard leaves them all in Blizzard's own look (after a reload). Each window can also be kept Blizzard's on the Windows tab.")
    page:Group(L["Frame"])
    local background = H.Columns({ "Background Color", "Background Opacity" })
    H.Color(background[1], "backgroundColor")
    page.backgroundSlider = H.Slider(background[2], "backgroundOpacity", "%")
    page.frameToggles = H.Toggles({ { "Border", "border" }, { "Title Bar", "titleBar" } }, 2)
    H.When(function() return M.db.border end, function()
        local border = H.Columns({ "Border Color", "Border Size" })
        H.Color(border[1], "borderColor")
        page.borderSizeSlider = H.Slider(border[2], "borderSize", "px")
    end)
    page:Group(L["Text"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); H.Refresh(fontRefresh)
    local sizes = H.Columns({ "Title Size", "Tab Text Size" })
    page.titleSizeSlider = H.Slider(sizes[1], "titleSize")
    page.tabSizeSlider = H.Slider(sizes[2], "tabSize")
    page.textToggles = H.Toggles({ { "Window Text", "bodyFont" }, { "Outline", "outline" }, { "Text Shadow", "shadow" } })
    H.Note("Window Text puts every text in a window in the font, at the game's own sizes; titles and tabs use the sizes above.")
    page:Group(L["Controls"])
    page.controlToggles = H.Toggles({ { "Tabs", "tabs" }, { "Buttons", "buttons" }, { "Fields", "fields" },
        { "Dropdowns", "dropdowns" }, { "Scroll Bars", "scrollBars" }, { "Insets", "insets" } })
    H.Note("Turning a control or window off brings back Blizzard's look after a reload.")
    page:Group(L["Defaults"])
    local tools = page:Row(L["Window Look"], 48)
    page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
    page.resetButton:SetPoint("LEFT"); page.resetButton:SetScript("OnClick", function() M:ResetToDefaults() end)

    page:Section(L["Windows"], nil, false)
    page:Group(L["Windows"])
    H.Note("The switch keeps a window in the ModeUI look; off leaves it Blizzard's. Open a window's row for its Scale and its own look.")
    local expanded = {}
    page.windowRows, page.windowLooks, page.expandedWindows = {}, {}, expanded
    for _, entry in ipairs(M.registry) do
        page.windowRows[entry.id] = WindowHeader(page, H, entry, expanded)
        page.windowLooks[entry.id] = WindowLook(page, H, entry, expanded)
    end
    H.Note("Windows from Blizzard addons that load on demand (Collections, Achievements, Professions and others) are skinned when they first open.")

    page:Section(L["Character"], nil, false)
    M:CreateCharacterSettings(page, H)

    W.PinnedSectionTabs(page)
    page:Finish(); return page
end

local _, addon = ...
local M, W, T, L = addon.Windows, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened, on the
-- standard tabs (docs/DESIGN_LANGUAGE.md, "Standard tabs") pinned above the
-- scrolling cards: General (Window Style, the controls ModeUI restyles, one
-- row per window: its switch, and a chevron that expands its own Scale and
-- look, all collapsed at first; the Character window), Fill, Border, Text
-- (with the Character window's texts, SettingsCharacter.lua). Changes repaint
-- every skinned window right away. Reset… in the footer: M:ResetScopes.
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
            controls.toggles = H.Toggles({ { "Show Border", "border", get = function() return Look().border end, set = SetLook("border") },
                { "Title Bar", "titleBar", get = function() return Look().titleBar end, set = SetLook("titleBar") } }, 2)
        end)
    end)
    return controls
end

function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local owner = M:AppearanceOwner()
    local H = Helpers(page)

    page:Tab("General")
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    H.Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page:Group(L["Window Style"])
    page.stylePills = H.Pills("Style", M.choices.style, function() return M.db.style end, H.Set("style"), 120)
    page:Group(L["Controls"])
    page.controlToggles = H.Toggles({ { "Title Bar", "titleBar" }, { "Tabs", "tabs" }, { "Buttons", "buttons" }, { "Fields", "fields" },
        { "Dropdowns", "dropdowns" }, { "Scroll Bars", "scrollBars" }, { "Insets", "insets" } })
    page:Group(L["Windows"])
    local expanded = {}
    page.windowRows, page.windowLooks, page.expandedWindows = {}, {}, expanded
    for _, entry in ipairs(M.registry) do
        page.windowRows[entry.id] = WindowHeader(page, H, entry, expanded)
        page.windowLooks[entry.id] = WindowLook(page, H, entry, expanded)
    end

    page:Tab("Fill")
    page:Group(L["Windows"])
    local background = H.Columns({ "Background Color", "Background Opacity" })
    H.Color(background[1], "backgroundColor")
    page.backgroundSlider = H.Slider(background[2], "backgroundOpacity", "%")

    page:Tab("Border")
    page:Group(L["Border"])
    page.frameToggles = H.Toggles({ { "Show Border", "border" } }, 2)
    -- Every window's border (docs/DESIGN_LANGUAGE.md, "Choosing a border"),
    -- shown with Show Border off too: a window's Own Look can turn it back on.
    page.borderStyle, page.borderMetal = W.BorderPickers(page,
        { get = function() return M.db.edgeStyle end, set = H.Set("edgeStyle") },
        { get = function() return M.db.edgeMetal end, set = H.Set("edgeMetal") })

    page:Tab("Text")
    page:Group(L["Text Style"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); H.Refresh(fontRefresh)
    page.textToggles = H.Toggles({ { "Window Text", "bodyFont" }, { "Outline", "outline" }, { "Shadow", "shadow" } })
    page:Group(L["Title Text"])
    page.titleSizeSlider = H.Slider(H.Columns({ "Size" })[1], "titleSize")
    page:Group(L["Tab Text"])
    page.tabSizeSlider = H.Slider(H.Columns({ "Size" })[1], "tabSize")

    M:CreateCharacterSettings(page, H)

    W.StandardTabs(page, true)
    page:Finish(); return page
end

-- Reset… in the footer: the shared window look (M:ResetToDefaults).
function M:ResetScopes()
    return { { label = L["Window Look"], run = function() M:ResetToDefaults() end,
        prompt = L["Put the window look back to its defaults? Each window's switch, its own look and the Character window's settings stay."] } }
end

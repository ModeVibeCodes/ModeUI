local _, addon = ...
local M, W, T, L = addon.Windows, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. Two
-- tabs: Look (frame, text, controls) and Windows (which windows are
-- skinned). Look changes repaint every skinned window right away.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local owner = M:AppearanceOwner()
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetOption(key, value) end end
    local function Slider(host, key, suffix)
        local r = M.ranges[key]
        Refresh(W.Slider(host, r[1], r[2], r[3], function() return M.db[key] end,
            function(value) M:SetOption(key, math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    local function Columns(titles)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized)
    end
    local function Toggles(entries, columns)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = entry.get or function() return M.db[entry[2]] end, set = entry.set or Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = columns or 3, minimumCellWidth = 150 })
    end
    local function Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    local function Note(text, height)
        local host = page:Row("", height or 32)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return label
    end

    page:Section(L["Look"], nil, false)
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page:Group(L["Frame"])
    local background = Columns({ "Background Color", "Background Opacity" })
    Color(background[1], "backgroundColor")
    page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
    page.frameToggles = Toggles({ { "Border", "border" }, { "Title Bar", "titleBar" } }, 2)
    local border = Columns({ "Border Color" })
    Color(border[1], "borderColor", function() return M.db.border end)
    page:Group(L["Text"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
    local sizes = Columns({ "Title Size", "Tab Text Size" })
    page.titleSizeSlider = Slider(sizes[1], "titleSize")
    page.tabSizeSlider = Slider(sizes[2], "tabSize")
    page.textToggles = Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" } }, 2)
    Note("Titles, tabs, buttons and fields use the font; the text inside windows keeps the game's fonts.")
    page:Group(L["Controls"])
    page.controlToggles = Toggles({ { "Tabs", "tabs" }, { "Buttons", "buttons" }, { "Fields", "fields" },
        { "Scroll Bars", "scrollBars" }, { "Insets", "insets" } })
    Note("Turning a control or window off brings back Blizzard's look after a reload.")
    page:Group(L["Defaults"])
    local tools = page:Row(L["Window Look"], 48)
    page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
    page.resetButton:SetPoint("LEFT"); page.resetButton:SetScript("OnClick", function() M:ResetToDefaults() end)

    page:Section(L["Windows"], nil, false)
    page:Group(L["Skinned Windows"])
    local items = {}
    for _, entry in ipairs(M.registry) do
        local id = entry.id
        items[#items + 1] = { L[entry.label], get = function() return M.db.windows[id] end, set = function(value) M:SetWindow(id, value) end }
    end
    page.windowToggles = Toggles(items, 2)
    Note("Windows from Blizzard addons that load on demand (Collections, Achievements, Professions and others) are skinned when they first open.", 48)

    W.SectionTabs(page)
    page:Finish(); return page
end

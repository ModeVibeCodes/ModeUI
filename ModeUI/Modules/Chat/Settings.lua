local _, addon = ...
local M, W, T, L = addon.Chat, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. Three
-- tabs (Window, Tabs, Fade) of cards with controls side by side. Changes
-- show on the real chat windows right away.
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
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = function() return M.db[entry[2]] end, set = Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 2, minimumCellWidth = 200 })
    end
    local function Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    local function Note(text, height)
        local host = page:Row("", height or 32)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return label
    end

    page:Section(L["Window"], nil, false)
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page:Group(L["Text"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
    page.textToggles = Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" } })
    Note("Expressway by default. Each window keeps its own Font Size, set from its tab's right-click menu.")
    page:Group(L["Background"])
    local background = Columns({ "Background Color", "Background Opacity" })
    Color(background[1], "backgroundColor")
    page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
    page.borderToggles = Toggles({ { "Border", "border" } })
    local border = Columns({ "Border Color" })
    Color(border[1], "borderColor", function() return M.db.border end)
    page:Group(L["Buttons"])
    local buttons = {}
    for _, item in ipairs(M.choices.buttons) do buttons[#buttons + 1] = { label = L[item.label], value = item.id, width = 120 } end
    local _, pillsRefresh = W.Exclusive(page:Row(L["Chat Buttons"], 48), buttons, function() return M.db.buttons end, Set("buttons"))
    Refresh(pillsRefresh)
    page.scrollToggles = Toggles({ { "Scroll Bar", "scrollBar" } })
    Note("The compartment holds Channels, voice chat and the chat menu at the end of the tab row. Scroll to Bottom shows inside a window whenever it's scrolled up.", 48)
    page:Group(L["Defaults"])
    local tools = page:Row(L["Chat Look"], 48)
    page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
    page.resetButton:SetPoint("LEFT"); page.resetButton:SetScript("OnClick", function() M:ResetToDefaults() end)

    page:Section(L["Tabs"], nil, false)
    page:Group(L["Glass Tabs"])
    page.glassToggles = Toggles({ { "Glass Tabs", "glassTabs" } })
    local size = Columns({ "Tab Text Size" })
    page.tabSizeSlider = Slider(size[1], "tabFontSize")
    Note("Glass Tabs are frosted panes with soft, feathered edges. Off, tabs are flat dark fields.")
    page:Group(L["Tab Fade"])
    local fade = Columns({ "Other Tabs", "Tabs When Away" })
    page.unselectedSlider = Slider(fade[1], "unselectedTabOpacity", "%")
    page.awaySlider = Slider(fade[2], "awayTabOpacity", "%")
    Note("Other Tabs is how visible the tabs you're not in are while you use the chat. Tabs When Away applies to every tab and the buttons once the mouse leaves. A tab flashing for a whisper always shows.", 48)

    page:Section(L["Fade"], nil, false)
    page:Group(L["Idle Fade"])
    page.idleToggles = Toggles({ { "Idle Fade", "idleFade" }, { "Wake on Whispers", "wakeOnWhisper" } })
    local idle = Columns({ "Idle Opacity", "Idle Delay" })
    page.idleOpacitySlider = Slider(idle[1], "idleOpacity", "%")
    page.idleDelaySlider = Slider(idle[2], "idleDelay", "s")
    Note("The chat eases down to Idle Opacity after Idle Delay seconds without the mouse over it or typing. Moving the mouse over it or pressing Enter brings it back.", 48)

    W.SectionTabs(page)
    page:Finish(); return page
end

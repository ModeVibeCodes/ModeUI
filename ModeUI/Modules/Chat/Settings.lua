local _, addon = ...
local M, W, T, L = addon.Chat, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. Three
-- tabs (Window, Tabs, Fade), pinned above the scrolling cards, with controls
-- side by side. Changes show on the real chat windows right away.
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
    local function Pills(title, list, get, set, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 110 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get, function(value) set(value); page:Layout() end)
        Refresh(refresh)
        return buttons
    end
    local function Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    local function Note(text, height)
        local host = page:Row("", height or 32)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        -- As wide as the card, and as tall as its lines, so nothing clips.
        function host.row:layoutChildren(width)
            label:SetWidth(math.max(40, width))
            local lines = label:GetStringHeight()
            if addon.IsNumber(lines, 1, 400) then self:SetHeight(math.ceil(lines) + 12) end
        end
        page.notes = page.notes or {}; page.notes[#page.notes + 1] = label
        return W.Note(label)
    end

    page:Section(L["Window"], nil, false)
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page:Group(L["Text"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
    page.textToggles = Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" } })
    Note("The Mode typeface by default (Expressway when installed, else Geist). Each window keeps its own Font Size, set from its tab's right-click menu.", 48)
    page:Group(L["Background"])
    local background = Columns({ "Background Color", "Background Opacity" })
    Color(background[1], "backgroundColor")
    page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
    Note("The edge is the Mode window edge, as on every ModeUI window, so it has no settings. A see-through window has no drop shadow.", 48)
    page:Group(L["Edit Box"])
    page.editPills = Pills("Position", M.choices.editPosition, function() return M.db.editPosition end, Set("editPosition"))
    local edit = Columns({ "Edit Box Height", "Edit Gap" })
    page.editHeightSlider = Slider(edit[1], "editHeight", "px")
    page.editGapSlider = Slider(edit[2], "editGap", "px")
    Note("Bottom and Top join the edit box to the window, inside its edge, with a line that turns Ivory while you type. Below keeps it a separate field, Edit Gap under the window.", 48)
    page:Group(L["Buttons"])
    local buttons = {}
    for _, item in ipairs(M.choices.buttons) do buttons[#buttons + 1] = { label = L[item.label], value = item.id, width = 120 } end
    local _, pillsRefresh = W.Exclusive(page:Row(L["Chat Buttons"], 48), buttons, function() return M.db.buttons end, Set("buttons"))
    Refresh(pillsRefresh)
    page.scrollToggles = Toggles({ { "Scroll Bar", "scrollBar" } })
    Note("The compartment holds Channels, voice chat and the chat menu at the end of the tab row. The scroll bar shows while the mouse is over the chat; Scroll to Bottom shows whenever a window is scrolled up.", 48)
    page:Group(L["Defaults"])
    local tools = page:Row(L["Chat Look"], 48)
    page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
    page.resetButton:SetPoint("LEFT"); page.resetButton:SetScript("OnClick", function() M:ResetToDefaults() end)

    page:Section(L["Tabs"], nil, false)
    page:Group(L["Tab Style"])
    page.tabStylePills = Pills("Style", { { id = true, label = "Glass" }, { id = false, label = "Solid" } },
        function() return M.db.glassTabs end, Set("glassTabs"))
    local size = Columns({ "Tab Height", "Tab Text Size" })
    page.tabHeightSlider = Slider(size[1], "tabHeight", "px")
    page.tabSizeSlider = Slider(size[2], "tabFontSize")
    local tuck = Columns({ "Tuck Depth" })
    page.tuckSlider = Slider(tuck[1], "tuckDepth", "px")
    Note("Glass tabs are see-through Mode Glass panes; Solid tabs are Mode Button faces. Tabs rest on the window's edge: the one you're in stands full height with an Ivory label and line, the others tuck down Tuck Depth.", 48)
    page:Group(L["Tab Fade"])
    local fade = Columns({ "Other Tabs", "Tabs When Idle" })
    page.unselectedSlider = Slider(fade[1], "unselectedTabOpacity", "%")
    page.awaySlider = Slider(fade[2], "awayTabOpacity", "%")
    Note("Other Tabs is how visible the tabs you're not in are. Tabs When Idle is how visible every tab and the buttons are once the chat has gone Idle Delay seconds without use: 100 keeps them shown at full, 0 hides them. A tab flashing for a whisper always shows.", 48)

    page:Section(L["Fade"], nil, false)
    page:Group(L["Idle Fade"])
    page.idleToggles = Toggles({ { "Idle Fade", "idleFade" }, { "Wake on Whispers", "wakeOnWhisper" } })
    local idle = Columns({ "Idle Opacity", "Idle Delay" })
    page.idleOpacitySlider = Slider(idle[1], "idleOpacity", "%")
    page.idleDelaySlider = Slider(idle[2], "idleDelay", "s")
    Note("The chat eases down to Idle Opacity after Idle Delay seconds without the mouse over it or typing. Moving the mouse over it or pressing Enter brings it back.", 48)

    W.PinnedSectionTabs(page)
    page:Finish(); return page
end

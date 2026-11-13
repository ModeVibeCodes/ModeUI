local _, addon = ...
local M, W, T, L = addon.Tooltip, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. Two
-- tabs pinned above the cards: Look (frame, border, text, health bar) and
-- Position (anchor or cursor, Anchor Point, scale, combat). Changes show on
-- the next tooltip right away.
local ANCHOR_LABELS = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", CENTER = "Center",
    RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }

function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local owner = M:AppearanceOwner()
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetOption(key, value) end end
    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
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
    local function Note(text)
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

    page:Section(L["Look"], nil, false)
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page:Group(L["Frame"])
    local background = Columns({ "Background Color", "Background Opacity" })
    Color(background[1], "backgroundColor")
    page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
    page.borderToggles = Toggles({ { "Border", "border" }, { "Quality Border", "qualityBorder" }, { "Class Border", "classBorder" } })
    When(function() return M.db.border end, function()
        local border = Columns({ "Border Color", "Border Size" })
        Color(border[1], "borderColor")
        page.borderSizeSlider = Slider(border[2], "borderSize", "px")
    end)
    Note("Quality Border colors the border by an item's quality; Class Border by a player's class (when the game lets addons see it).")
    page:Group(L["Text"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
    local sizes = Columns({ "Header Size", "Text Size" })
    page.headerSizeSlider = Slider(sizes[1], "headerSize")
    page.textSizeSlider = Slider(sizes[2], "textSize")
    page.textToggles = Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" } })
    page:Group(L["Health Bar"])
    page.healthToggles = Toggles({ { "Health Bar", "healthBar" } })
    When(function() return M.db.healthBar end, function()
        local health = Columns({ "Health Color", "Health Height" })
        Color(health[1], "healthColor")
        page.healthHeightSlider = Slider(health[2], "healthHeight", "px")
    end)
    page:Group(L["Defaults"])
    local tools = page:Row(L["Tooltip Look"], 48)
    page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
    page.resetButton:SetPoint("LEFT"); page.resetButton:SetScript("OnClick", function() M:ResetToDefaults() end)

    page:Section(L["Position"], nil, false)
    page:Group(L["Position"])
    local choices = {}
    for _, item in ipairs(M.choices.position) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = 110 } end
    local pills, pillsRefresh = W.Exclusive(page:Row(L["Show At"], 48), choices, function() return M.db.position end, Set("position"))
    Refresh(pillsRefresh); page.positionPills = pills
    When(function() return M.db.position == "anchor" end, function()
        local labels = setmetatable({}, { __index = function(_, key) return L[ANCHOR_LABELS[key] or key] end })
        local buttons, refresh = W.AnchorPicker(page:Row(L["Anchor Point"], W.ANCHOR_PICKER_HEIGHT + 16),
            function() return M.db.anchorPoint end, function(value) M:SetOption("anchorPoint", value); page:Refresh() end,
            labels, { center = true })
        Refresh(refresh); page.anchorButtons = buttons
        local edit = page:Row(L["Move It"], 48)
        page.editModeButton = W.Button(edit, L["Edit Mode"], 130, 30, "secondary")
        page.editModeButton:SetPoint("LEFT")
        page.editModeButton:SetScript("OnClick", function() addon:SetEditMode(true) end)
        Note("The tooltip grows out of Anchor Point of its Edit Mode anchor. Blizzard's own tooltip spot (its Edit Mode HUD Tooltip) no longer applies.")
    end)
    local scale = Columns({ "Scale" })
    page.scaleSlider = Slider(scale[1], "scale", "%")
    page:Group(L["Combat"])
    page.combatToggles = Toggles({ { "Hide in Combat", "hideInCombat" }, { "Shift Shows It", "shiftShows" } })
    Note("Hide in Combat keeps the main tooltip (units, the world, buttons) away while you fight; with Shift Shows It, holding Shift shows it anyway. Item links you click still open.")

    W.PinnedSectionTabs(page)
    page:Finish(); return page
end

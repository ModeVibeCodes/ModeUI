local _, addon = ...
local M, W, T, L = addon.Tooltip, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened, on the
-- standard tabs (docs/DESIGN_LANGUAGE.md, "Standard tabs") pinned above the
-- cards: General (size, and anchor or cursor with Anchor Point), Fill, Border
-- (the edge, quality and class rims), Text (font, sizes and the colors of
-- names, class, level and quest lines) and Behavior (combat). Changes show on
-- the next tooltip. Reset… in the footer runs M:ResetToDefaults.
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
    local function Pills(title, key, width)
        local choices = {}
        for _, item in ipairs(M.choices[key]) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 100 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, function() return M.db[key] end, Set(key))
        Refresh(refresh)
        return buttons
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
        return W.Note(label)
    end

    page:Tab("General")
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page:Group(L["Size"])
    local size = Columns({ "Minimum Width", "Padding" })
    page.minWidthSlider = Slider(size[1], "minWidth", "px")
    page.paddingSlider = Slider(size[2], "padding", "px")
    local scale = Columns({ "Scale" })
    page.scaleSlider = Slider(scale[1], "scale", "%")
    page:Group(L["Position"])
    page.positionPills = Pills("Show At", "position", 110)
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
        Note("In Edit Mode, drag the Tooltip box or attach it to another element (action bars, meter windows, unit frames). The tooltip grows out of Anchor Point of the box, and stays on the screen near its edges. Blizzard's own tooltip spot no longer applies.")
    end)

    page:Tab("Fill")
    page:Group(L["Background"])
    local background = Columns({ "Background Color", "Background Opacity" })
    Color(background[1], "backgroundColor")
    page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
    Note("Each tooltip is a Mode window, Graphite by default. A see-through tooltip has no drop shadow.")

    page:Tab("Border")
    page:Group(L["Border"])
    page.borderToggles = Toggles({ { "Show Border", "border" } })
    -- The edge's style and metal (docs/DESIGN_LANGUAGE.md, "Choosing a border"), with Show Border on.
    When(function() return M.db.border end, function()
        page.borderStyle, page.borderMetal = W.BorderPickers(page,
            { get = function() return M.db.edgeStyle end, set = Set("edgeStyle") },
            { get = function() return M.db.edgeMetal end, set = Set("edgeMetal") })
    end)
    Note("Show Border shows the Mode window edge.")
    page:Group(L["Rim Colors"])
    page.rimToggles = Toggles({ { "Quality Border", "qualityBorder" }, { "Class Border", "classBorder" } })
    Note("Quality Border colors the rim by an item's quality; Class Border by a player's class (when the game lets addons see it).")

    page:Tab("Text")
    page:Group(L["Text Style"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
    page.textToggles = Toggles({ { "Outline", "outline" }, { "Shadow", "shadow" } })
    page:Group(L["Title Line"])
    page.headerSizeSlider = Slider(Columns({ "Size" })[1], "headerSize")
    Note("The first line: a unit's or an item's name.")
    page:Group(L["Other Lines"])
    page.textSizeSlider = Slider(Columns({ "Size" })[1], "textSize")
    page:Group(L["Names"])
    page.playerNamePills = Pills("Player Names", "playerNameColor")
    When(function() return M.db.playerNameColor == "custom" end, function() Color(Columns({ "Player Name Color" })[1], "playerNameCustom") end)
    page.npcNamePills = Pills("NPC Names", "npcNameColor")
    When(function() return M.db.npcNameColor == "custom" end, function() Color(Columns({ "NPC Name Color" })[1], "npcNameCustom") end)
    When(function() return M.db.npcNameColor == "reaction" end, function()
        local reaction = Columns({ "Hostile", "Neutral" })
        Color(reaction[1], "hostileColor"); Color(reaction[2], "neutralColor")
        Color(Columns({ "Friendly" })[1], "friendlyColor")
    end)
    Note("Players by their class color; NPCs by how they feel about you (gray once someone else has tagged them).")
    page:Group(L["Class and Level"])
    page.classTextPills = Pills("Class Text", "classTextColor")
    When(function() return M.db.classTextColor == "custom" end, function() Color(Columns({ "Class Text Color" })[1], "classTextCustom") end)
    page.levelPills = Pills("Level", "levelColor")
    When(function() return M.db.levelColor == "custom" end, function() Color(Columns({ "Level Color" })[1], "levelCustom") end)
    Note("Difficulty colors the level number: red well above you, then orange, yellow, green and gray well below. Custom colors the whole level line.")
    page:Group(L["Quests"])
    page.questToggles = Toggles({ { "Quest Text", "questText" } })
    When(function() return M.db.questText end, function() Color(Columns({ "Quest Color" })[1], "questColor") end)
    Note("Quest names and objectives (\"Defias Trapper slain: 3/10\") on units and items.")

    page:Tab("Behavior")
    page:Group(L["Combat"])
    page.combatToggles = Toggles({ { "Hide in Combat", "hideInCombat" }, { "Shift Shows It", "shiftShows" } })
    Note("Hide in Combat keeps the main tooltip (units, the world, buttons) away while you fight; with Shift Shows It, holding Shift shows it anyway. Item links you click still open.")

    W.StandardTabs(page, true)
    page:Finish(); return page
end

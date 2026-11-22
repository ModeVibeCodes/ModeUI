local _, addon = ...
local M, W, T, L = addon.Bags, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened, on the
-- standard tabs (docs/DESIGN_LANGUAGE.md, "Standard tabs") pinned above the
-- cards: General (parts, marks, grid, contents, position), Fill (window and
-- slot colors), Border (the window's border, slot rims), Text. Every change
-- shows on the open window at once; Show Bags opens it beside the settings.
-- Reset… in the footer runs M:ResetToDefaults.
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
    local function Dropdown(title, key, width)
        local function Choices()
            local out = {}
            for i, item in ipairs(M.choices[key]) do out[i] = { id = item.id, label = L[item.label] } end
            return out
        end
        local button = W.Select(page:Row(L[title], 48), width, Choices, function()
            for _, choice in ipairs(Choices()) do if choice.id == M.db[key] then return choice.id, choice.label end end
            return M.db[key], tostring(M.db[key])
        end, Set(key))
        Refresh(function() button:Refresh() end)
        return button
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
    local function Action(title, text, width, onClick)
        local row = page:Row(L[title], 48)
        local button = W.Button(row, L[text], width, 30, "secondary")
        button:SetPoint("LEFT"); button:SetScript("OnClick", onClick)
        return button
    end

    page:Tab("General")
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page.showButton = Action("Window", "Show Bags", 130, function() M:OpenBags(); page:Refresh() end)
    page:Group(L["Parts"])
    page.partToggles = Toggles({ { "Title", "showTitle" }, { "Search Box", "showSearch" }, { "Money", "showMoney" },
        { "Free Slots", "showFreeSlots" }, { "Bag Bar", "showBagBar" } })
    Note("Bag Bar shows your equipped bags in the footer with their free slots: drop a bag on one to equip it, drag a bag off to take it out, point at one to light its slots. The search box uses the game's bag search: names, types and tooltip text match, and other items fade.")
    page:Group(L["Marks"])
    page.markToggles = Toggles({ { "Quest Icon", "questIcon" }, { "Junk Coin", "junkCoin" }, { "Fade Junk", "fadeJunk" } })
    Note("Fade Junk grays out gray-quality items you can sell; Junk Coin marks them with a coin.")
    page:Group(L["Grid"])
    local grid = Columns({ "Columns", "Slot Size" })
    page.columnsSlider = Slider(grid[1], "columns")
    page.slotSizeSlider = Slider(grid[2], "slotSize", "px")
    local gaps = Columns({ "Spacing", "Padding" })
    page.spacingSlider = Slider(gaps[1], "spacing", "px")
    page.paddingSlider = Slider(gaps[2], "padding", "px")
    page.scaleSlider = Slider(Columns({ "Scale" })[1], "scale", "%")
    page:Group(L["Contents"])
    page.contentToggles = Toggles({ { "Separate Bags", "splitBags" }, { "Reagent Section", "reagentSection" }, { "Keyring", "keyring" } })
    page.sortSelect = Dropdown("Sort", "sortMode", 200)
    Note("Sort only changes the order items show in (empty slots last); the header's Sort menu sets it too. Clean Up in the header is the game's own sort, which moves the items in your bags. Separate Bags gives each bag its own block; the reagent bag and the keyring get their own sections.")
    page:Group(L["Position"])
    page.growPills = Pills("Grow From", "growFrom", 104)
    page.editModeButton = Action("Move It", "Edit Mode", 130, function() addon:SetEditMode(true) end)
    page.lockToggles = Toggles({ { "Lock Window", "locked" } })
    Note("The window stays fixed at its Grow From corner and grows away from it as bags change. In Edit Mode, drag the Bags box or attach it to another element. Unlocked, drag the header to move the window (out of combat).")

    page:Tab("Fill")
    page:Group(L["Window"])
    local background = Columns({ "Background Color", "Background Opacity" })
    Color(background[1], "backgroundColor")
    page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
    Color(Columns({ "Header Color" })[1], "headerColor")
    Note("The window is a Mode window: Graphite by default, the Mode window edge inside it and a Mode Title header. A see-through window has no drop shadow.")
    page:Group(L["Slots"])
    local slot = Columns({ "Slot Color", "Slot Opacity" })
    Color(slot[1], "slotColor")
    page.slotOpacitySlider = Slider(slot[2], "slotOpacity", "%")

    page:Tab("Border")
    page:Group(L["Border"])
    page.borderStyle, page.borderMetal = W.BorderPickers(page,
        { get = function() return M.db.edgeStyle end, set = Set("edgeStyle") },
        { get = function() return M.db.edgeMetal end, set = Set("edgeMetal") })
    Note("The window's border, also on its Sort menu. Slots keep their thin Mode edge in the item's quality color.")
    page:Group(L["Slot Borders"])
    page.borderToggles = Toggles({ { "Quality Borders", "qualityBorders" }, { "Quest Borders", "questBorders" }, { "New Items", "newItems" } })
    When(function() return M.db.qualityBorders end, function() page.qualityPills = Pills("Minimum Quality", "qualityMinimum", 84) end)
    When(function() return M.db.questBorders end, function() Color(Columns({ "Quest Color" })[1], "questColor") end)
    Note("A slot's border shows the item's quality color from Minimum Quality up, quest items in Quest Color, and new items in Ivory until you point at them. Each slot is a little wider than tall, in a thin Mode edge.")

    page:Tab("Text")
    page:Group(L["Text Style"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
    page.textToggles = Toggles({ { "Outline", "outline" } })
    page:Group(L["Title Text"])
    page.titleSizeSlider = Slider(Columns({ "Size" })[1], "titleSize")
    Note("The header, search box and footer.")
    page:Group(L["Stack Count"])
    page.countSizeSlider = Slider(Columns({ "Size" })[1], "countSize")
    page:Group(L["Item Level"])
    page.levelToggles = Toggles({ { "Show Item Level", "itemLevel" } })
    When(function() return M.db.itemLevel end, function() page.levelColorPills = Pills("Color", "itemLevelColor") end)
    page.levelSizeSlider = Slider(Columns({ "Size" })[1], "levelSize")
    Note("Item Level shows on weapons and armor.")

    W.StandardTabs(page, true)
    page:Finish(); return page
end

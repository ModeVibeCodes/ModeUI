local _, addon = ...
local M, W, T, L = addon.Bags, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. Five
-- tabs pinned above the cards: Layout (grid, contents, view order), Window
-- (fill, border, header, parts), Slots (slot look, borders, marks), Text and
-- Position. Every change shows on the open window at once; Show Bags opens
-- it beside the settings.
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
        return label
    end
    local function Action(title, text, width, onClick)
        local row = page:Row(L[title], 48)
        local button = W.Button(row, L[text], width, 30, "secondary")
        button:SetPoint("LEFT"); button:SetScript("OnClick", onClick)
        return button
    end

    page:Section(L["Layout"], nil, false)
    local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    Refresh(function() status:SetText(M:Status()) end)
    page.statusLabel = status
    page.showButton = Action("Window", "Show Bags", 130, function() M:OpenBags(); page:Refresh() end)
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
    page.sortPills = Pills("Sort", "sortMode", 96)
    Note("Sort only changes the order items show in (empty slots last); the header's Sort button switches it too. Clean Up in the header is the game's own sort, which moves the items in your bags. Separate Bags gives each bag its own block; the reagent bag and the keyring get their own sections.")
    page:Group(L["Defaults"])
    page.resetButton = Action("Bags Look", "Reset to Defaults", 150, function() M:ResetToDefaults() end)

    page:Section(L["Window"], nil, false)
    page:Group(L["Frame"])
    local background = Columns({ "Background Color", "Background Opacity" })
    Color(background[1], "backgroundColor")
    page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
    local border = Columns({ "Border Color", "Corner Radius" })
    Color(border[1], "borderColor")
    page.cornerSlider = Slider(border[2], "corner", "px")
    Color(Columns({ "Header Color" })[1], "headerColor")
    Note("The fill defaults to the unit frames' health color, inside ModeUI's 2px border; the header bar is in Mode Gradient.")
    page:Group(L["Parts"])
    page.partToggles = Toggles({ { "Title", "showTitle" }, { "Search Box", "showSearch" }, { "Money", "showMoney" },
        { "Free Slots", "showFreeSlots" }, { "Lock Window", "locked" } })
    Note("Unlocked, drag the header to move the window (out of combat). The search box uses the game's bag search: names, types and tooltip text match, and other items fade.")

    page:Section(L["Slots"], nil, false)
    page:Group(L["Slot"])
    local slot = Columns({ "Slot Color", "Slot Opacity" })
    Color(slot[1], "slotColor")
    page.slotOpacitySlider = Slider(slot[2], "slotOpacity", "%")
    local rim = Columns({ "Slot Border Color", "Slot Border Size" })
    Color(rim[1], "slotBorderColor")
    page.slotBorderSlider = Slider(rim[2], "slotBorderSize", "px")
    page:Group(L["Borders"])
    page.borderToggles = Toggles({ { "Quality Borders", "qualityBorders" }, { "Quest Borders", "questBorders" }, { "New Items", "newItems" } })
    When(function() return M.db.qualityBorders end, function() page.qualityPills = Pills("Minimum Quality", "qualityMinimum", 84) end)
    When(function() return M.db.questBorders end, function() Color(Columns({ "Quest Color" })[1], "questColor") end)
    Note("A slot's border shows the item's quality color from Minimum Quality up, quest items in Quest Color, and new items in the Mode cyan until you point at them.")
    page:Group(L["Marks"])
    page.markToggles = Toggles({ { "Fade Junk", "fadeJunk" }, { "Junk Coin", "junkCoin" }, { "Item Level", "itemLevel" } })
    When(function() return M.db.itemLevel end, function() page.levelColorPills = Pills("Item Level Color", "itemLevelColor") end)
    Note("Fade Junk grays out gray-quality items you can sell; Junk Coin marks them with a coin. Item Level shows on weapons and armor.")

    page:Section(L["Text"], nil, false)
    page:Group(L["Font"])
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
    page.titleSizeSlider = Slider(Columns({ "Title Size" })[1], "titleSize")
    local sizes = Columns({ "Count Size", "Item Level Size" })
    page.countSizeSlider = Slider(sizes[1], "countSize")
    page.levelSizeSlider = Slider(sizes[2], "levelSize")
    page.textToggles = Toggles({ { "Outline", "outline" } })
    Note("Title Size sets the header, search box and footer; Count Size the stack counts and Item Level Size the item levels.")

    page:Section(L["Position"], nil, false)
    page:Group(L["Position"])
    page.growPills = Pills("Grow From", "growFrom", 104)
    page.editModeButton = Action("Move It", "Edit Mode", 130, function() addon:SetEditMode(true) end)
    Note("The window stays fixed at its Grow From corner and grows away from it as bags change. In Edit Mode, drag the Bags box or attach it to another element.")

    W.PinnedSectionTabs(page)
    page:Finish(); return page
end

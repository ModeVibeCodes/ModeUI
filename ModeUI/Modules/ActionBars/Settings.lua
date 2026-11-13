local _, addon = ...
local M, W, T, L = addon.ActionBars, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of the bar being edited sits above the tabs (Bar, Buttons, Text,
-- Visibility); clicking a part of it jumps to its settings. Every tab starts
-- with the Editing choice (which bar), shared by every tab, then cards of
-- related settings, side by side where they fit.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing, textPart = "bar1", "hotkey"
    local function Bar() return editing end
    local function Part() return textPart end
    local function db() return M.db[editing] end
    page.barEditing, page.textPart = Bar, Part
    function page.SetEditing(bar) if M.barSpecs[bar] then editing = bar; page:Refresh(); page:Layout() end end
    function page.SetTextPart(part) if M.textPartLabels[part] then textPart = part; page:Refresh(); page:Layout() end end
    local owner = M:AppearanceOwner(Bar, Part)
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetOption(editing, key, value) end end
    local function PartKey(suffix) return textPart .. suffix end
    local function SetPart(suffix) return function(value) M:SetOption(editing, PartKey(suffix), value) end end
    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    -- The settings a preview click jumps to.
    page.jumpTargets = {}
    local function Mark(target) local row = page.rows[#page.rows]; page.jumpTargets[target] = { section = row.section, row = row } end

    -- Controls. Each takes the host it fills: a row, or one cell of Columns.
    local function SliderIn(host, range, get, set, suffix, maximum)
        Refresh(W.Slider(host, range[1], range[2], range[3], get, function(value) set(math.floor(value + 0.5)) end, suffix,
            maximum and { maximum = maximum } or true))
        return host.slider
    end
    local function Slider(host, key, suffix) return SliderIn(host, M.ranges[key], function() return db()[key] end, Set(key), suffix) end
    local function PartSlider(host, suffix, unit)
        return SliderIn(host, M.ranges["hotkey" .. suffix], function() return db()[PartKey(suffix)] end, SetPart(suffix), unit)
    end
    local function SelectIn(host, width, choices, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get()
            for _, choice in ipairs(choices()) do if choice.id == value then return value, choice.label end end
            return value, tostring(value)
        end, set)
        Refresh(function() button:Refresh() end)
        return button
    end
    local function Pills(title, list, get, set, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 96 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get, set)
        Refresh(refresh)
        return buttons
    end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = entry.get or function() return db()[entry[2]] end, set = entry.set or Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    local function Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    local function Note(text, height)
        local host = page:Row("", height or 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return label
    end
    local function Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    local barChoices = {}
    for _, bar in ipairs(M.bars) do barChoices[#barChoices + 1] = { id = bar, label = L[M.barSpecs[bar].label] } end

    page.configPreview = W.Preview(page, M, { contentHeight = 120 })
    -- Keybind Mode from every tab: a button in the preview's header.
    if page.previewCollapseButton then
        local keys = W.Button(page.previewArea, L["Keybind Mode"], 104, 24, "choice")
        keys:SetPoint("LEFT", page.previewCollapseButton, "RIGHT", 4, 0)
        keys:SetScript("OnClick", function() M:SetKeybindMode(true) end)
        page.keybindHeaderButton = keys
    end

    -- Every tab starts with the Editing choice; a hidden bar says so.
    page.barSelects = {}
    local function Tab(title, build)
        page:Section(L[title], nil, false)
        local editRow = page:Row(L["Editing"], 48)
        page.barSelects[#page.barSelects + 1] = SelectIn(editRow, 200, function() return barChoices end, Bar, page.SetEditing)
        if title ~= "Bar" then
            When(function() return not db().show end, function() Note("This bar is hidden. Turn on Show Bar on the Bar tab to use it.") end)
        end
        build()
    end

    Tab("Bar", function()
        page.showToggles = Toggles({ { "Show Bar", "show" } }); Mark("bar")
        local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        Refresh(function() status:SetText(M:Status()) end)
        page.statusLabel = status
        page:Group(L["Layout"])
        local shape = Columns({ "Buttons", "Buttons per Line" })
        local function Count() return M.barSpecs[editing].count end
        -- The pet and stance bars hold ten buttons.
        Refresh(function() if shape[1].slider then shape[1].slider:SetMinMaxValues(1, Count()) end end)
        page.buttonsSlider = SliderIn(shape[1], M.ranges.buttons, function() return db().buttons end, Set("buttons"), nil, Count)
        page.perLineSlider = Slider(shape[2], "perLine")
        page.orientationPills = Pills("Lines", M.choices.orientation, function() return db().orientation end, Set("orientation"), 110)
        page.startPills = Pills("First Button", M.choices.start, function() return db().start end, Set("start"), 100)
        page:Group(L["Size"])
        local size = Columns({ "Width", "Height", "Spacing" })
        page.widthSlider = Slider(size[1], "width", "px"); Mark("buttons")
        page.heightSlider = Slider(size[2], "height", "px")
        page.spacingSlider = Slider(size[3], "spacing", "px")
        page:Group(L["This Bar"])
        local tools = page:Row(L["Style"], 48)
        page.copyButton = W.Button(tools, L["Copy Style to All Bars"], 190, 30, "secondary")
        page.copyButton:SetPoint("LEFT"); page.copyButton:SetScript("OnClick", function() M:CopyStyleToAll(editing) end)
        page.resetButton = W.Button(tools, L["Reset to Defaults"], 150, 30, "secondary")
        page.resetButton:SetPoint("LEFT", page.copyButton, "RIGHT", 8, 0); page.resetButton:SetScript("OnClick", function() M:ResetBar(editing) end)
        Note("Copy Style copies size, borders, text and opacity; each bar keeps its own buttons, lines and show settings.", 32)
        page:Group(L["Keybinds"])
        local keys = page:Row(L["Keybind Mode"], 48)
        page.keybindButton = W.Button(keys, L["Keybind Mode"], 190, 30, "secondary")
        page.keybindButton:SetPoint("LEFT"); page.keybindButton:SetScript("OnClick", function() M:SetKeybindMode(true) end)
        Note("Or type /kb. Hover a button and press a key to bind it; Escape clears it.", 32)
        -- Paging, for bars 1-8.
        When(function() return M.pages[editing] ~= nil end, function()
            page:Group(L["Paging"])
            page.pagingToggles = Toggles({ { "Page Switching", "paging" } }); Mark("paging")
            When(function() return db().paging end, function()
                local host = page:Row(L["Page Conditions"], 48)
                local box = W.TextInput(host, 300, "[mod:shift] 2; [bonusbar:1] 7", M.MAX_CONDITIONS)
                -- Enter keeps the conditions; Escape leaves them as they were.
                box.onEnter = function(text) M:SetOption(editing, "pageConditions", text); page:Refresh() end
                Refresh(function() if not box:HasFocus() then box:SetText(db().pageConditions) end end)
                page.pageConditionsInput = box
            end)
            Note("Page Conditions pick a page by macro conditions, like \"[mod:shift] 2; [bonusbar:1] 7\" (pages 1-6 are the game's bars, 7-10 stance and form pages). When none match, the bar shows its own page. Action Bar 1 with no conditions follows the game's own paging (stances, forms, vehicles, page keys); with Page Switching off it stays on page 1.", 64)
        end)
    end)

    Tab("Buttons", function()
        page:Group(L["Border"])
        page.borderPills = Pills("Border", M.choices.border, function() return db().border end, Set("border"))
        local function Bordered() return db().border ~= "none" end
        local border = Columns({ "Border Size", "Border Color" })
        page.borderSizeSlider = Slider(border[1], "borderSize", "px")
        Color(border[2], "borderColor", Bordered)
        page:Group(L["Background"])
        local background = Columns({ "Background Color", "Background Opacity" })
        Color(background[1], "backgroundColor")
        page.backgroundSlider = Slider(background[2], "backgroundOpacity", "%")
        page.slotToggles = Toggles({ { "Show Empty Slots", "showEmpty" } })
        Note("The background shows in empty slots at Background Opacity, with a textured slot finish, and as the thin line between border and icon. Dragging a spell shows every button so it can be dropped.", 48)
    end)

    -- Text: pick a text, then its place, size and color; the font is shared.
    Tab("Text", function()
        page:Group(L["Text"])
        local parts = {}
        for _, part in ipairs(M.textParts) do parts[#parts + 1] = { id = part, label = M.textPartLabels[part] } end
        page.textPartButtons = Pills("Text", parts, Part, page.SetTextPart, 104); Mark("text")
        page.textToggles = Toggles({ { "Show This Text", "part", get = function() return db()[PartKey("Show")] end, set = SetPart("Show") } })
        local labels = setmetatable({}, { __index = function(_, key) return L[M.anchorLabels[key] or key] end })
        local anchorButtons, anchorRefresh = W.AnchorPicker(page:Row(L["Anchor"], W.ANCHOR_PICKER_HEIGHT + 16),
            function() return db()[PartKey("Anchor")] end, SetPart("Anchor"), labels, { center = true })
        Refresh(anchorRefresh); page.textAnchorButtons = anchorButtons
        local place = Columns({ "Size", "Offset X", "Offset Y" })
        page.textSizeSlider = PartSlider(place[1], "Size")
        PartSlider(place[2], "X", "px"); PartSlider(place[3], "Y", "px")
        local color = Columns({ "Color" })
        Color(color[1], "partColor")
        When(function() return textPart == "cooldown" end, function()
            Note("Cooldown numbers follow the game's own option for showing them, and use the crisp shadow.", 32)
        end)
        page:Group(L["Font"])
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
        page.fontToggles = Toggles({ { "Outline", "outline" }, { "Slug Text", "slug" } })
        page.shadowPills = Pills("Text Shadow", addon.Kit.SHADOW_CHOICES, function() return addon.Kit.ShadowMode(db()) end, function(mode)
            local shadow, lifted = addon.Kit.ShadowKeys(mode)
            M:SetOption(editing, "shadow", shadow); M:SetOption(editing, "liftedShadow", lifted)
        end)
    end)

    -- Glows: how buttons react to procs and cooldowns.
    Tab("Glows", function()
        page:Group(L["Proc Glow"])
        page.procPills = Pills("Style", M.choices.procGlow, function() return db().procGlow end, Set("procGlow"), 96); Mark("glows")
        When(function() return db().procGlow == "mode" or db().procGlow == "border" end, function()
            local proc = Columns({ "Proc Color" })
            Color(proc[1], "procColor")
            page.procToggles = Toggles({ { "Pulse", "procPulse" } })
        end)
        Note("A proc is the game lighting up a spell you should use now. Blizzard keeps the game's own animation; None shows nothing.", 32)
        page:Group(L["Cooldown Ready"])
        page.readyToggles = Toggles({ { "Glow When Ready", "readyGlow" } })
        When(function() return db().readyGlow end, function()
            page.readyPills = Pills("Style", M.choices.readyStyle, function() return db().readyStyle end, Set("readyStyle"))
            local ready = Columns({ "Glow Color", "Glow Time" })
            Color(ready[1], "readyColor")
            page.readySlider = Slider(ready[2], "readyDuration", "s")
        end)
        page:Group(L["On Cooldown"])
        local dim = Columns({ "Icon Opacity" })
        page.cooldownOpacitySlider = Slider(dim[1], "cooldownOpacity", "%")
        Note("Glow When Ready lights a button for Glow Time when a cooldown longer than the global cooldown ends. Icon Opacity fades the icon while that cooldown runs (100% keeps it as it is). Action bars 1-8 only.", 48)
    end)

    Tab("Visibility", function()
        page:Group(L["When to Show"])
        local show = Columns({ "Show" })
        page.visibilitySelect = SelectIn(show[1], 260, function() return M.choices.visibility end,
            function() return db().visibility end, Set("visibility")); Mark("visibility")
        When(function() return db().visibility == "custom" end, function()
            local host = page:Row(L["Conditions"], 48)
            local box = W.TextInput(host, 300, "[combat] show; hide", M.MAX_CONDITIONS)
            -- Enter keeps the conditions; Escape leaves them as they were.
            box.onEnter = function(text) M:SetOption(editing, "customVisibility", text); page:Refresh() end
            Refresh(function() if not box:HasFocus() then box:SetText(db().customVisibility) end end)
            page.conditionsInput = box
            Note("Macro conditions, like \"[combat][mod:shift] show; hide\". Conditions the game can't read show the bar always.", 32)
        end)
        page:Group(L["Opacity"])
        local opacity = Columns({ "Opacity" })
        page.opacitySlider = Slider(opacity[1], "opacity", "%")
        When(function() return db().visibility == "mouseover" end, function()
            local faded = Columns({ "Faded Opacity" })
            page.fadeSlider = Slider(faded[1], "fadeOpacity", "%")
        end)
        Note("Mouseover keeps the bar at Faded Opacity until the mouse is over it. Hidden bars still show in Edit Mode and Keybind Mode. Every bar hides during pet battles. Action Bar 1 hides while the game shows its own vehicle bar, and the pet and stance bars while you control a vehicle.", 48)
    end)

    -- While this page is open, each bar on screen wears a name tag (Preview.lua).
    Refresh(function() M:RenderBarTags() end)
    page:HookScript("OnShow", function() M:RenderBarTags() end)
    page:HookScript("OnHide", function() M:RenderBarTags() end)
    if addon.configWindow then
        addon.configWindow:HookScript("OnShow", function() M:RenderBarTags() end)
        addon.configWindow:HookScript("OnHide", function() M:RenderBarTags() end)
    end
    W.SectionTabs(page)
    page:Finish(); return page
end

-- A preview click: show that bar (and text) and scroll to the setting.
function M:JumpTo(target, part)
    local page = self.page
    if not page or not page.jumpTargets or not page.jumpTargets[target] then return false end
    if part then page.SetTextPart(part) end
    page:Reveal(page.jumpTargets[target])
    return true
end

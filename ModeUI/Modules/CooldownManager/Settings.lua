local _, addon = ...
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of the viewer being edited sits above the tabs (Viewer, Look,
-- Text, Glows, Spells, Visibility, Copy & Apply); clicking a spell in it opens
-- that spell's switches. Editing (which viewer) sits in the preview header,
-- shared by every tab. This file builds the page, its helpers and the Viewer
-- and Look tabs; SettingsTabs.lua the rest.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing, textPart = "essential", "cooldown"
    local function Viewer() return editing end
    local function Part() return textPart end
    local function db() return M.db[editing] end
    page.viewerEditing, page.textPart = Viewer, Part
    -- A text the new viewer doesn't have falls back to its first.
    local function FitPart()
        for _, part in ipairs(M:Parts(editing)) do if part == textPart then return end end
        textPart = M:Parts(editing)[1]
    end
    function page.SetEditing(viewer)
        if not M.viewerSpecs[viewer] then return end
        if viewer ~= editing and M.spellMenu then M.spellMenu:Hide() end
        editing = viewer
        FitPart()
        page:Refresh(); page:Layout()
    end
    function page.SetTextPart(part)
        if M.textPartLabels[part] then textPart = part; FitPart(); page:Refresh(); page:Layout() end
    end
    local ui = { page = page, Viewer = Viewer, Part = Part, db = db, owner = M:AppearanceOwner(Viewer, Part) }
    function ui.Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    function ui.Set(key) return function(value) M:SetOption(editing, key, value) end end
    function ui.PartKey(suffix) return textPart .. suffix end
    function ui.SetPart(suffix) return function(value) M:SetOption(editing, textPart .. suffix, value) end end
    function ui.Icons() return not M:IsBar(editing) end
    function ui.Bars() return M:IsBar(editing) end
    function ui.Cooldowns() return not M:IsBuff(editing) end
    function ui.When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    -- The settings a preview click jumps to.
    page.jumpTargets = {}
    function ui.Mark(target) local row = page.rows[#page.rows]; page.jumpTargets[target] = { section = row.section, row = row } end

    -- Controls. Each takes the host it fills: a row, or one cell of Columns.
    function ui.SliderIn(host, range, get, set, suffix, numeric)
        ui.Refresh(W.Slider(host, range[1], range[2], range[3], get, function(value) set(math.floor(value + 0.5)) end, suffix, numeric or true))
        return host.slider
    end
    function ui.Slider(host, key, suffix)
        return ui.SliderIn(host, M.ranges[key], function() return db()[key] end, ui.Set(key), suffix)
    end
    function ui.SelectIn(host, width, choices, get, set, options)
        local button = W.Select(host, width, choices, function()
            local value, label = get()
            if label then return value, label end
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, tostring(value)
        end, set, options)
        ui.Refresh(function() button:Refresh() end)
        return button
    end
    function ui.Pills(title, list, get, set, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 96 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get, set)
        ui.Refresh(refresh)
        return buttons
    end
    function ui.Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = entry.get or function() return db()[entry[2]] end, set = entry.set or ui.Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    function ui.Color(host, key, enabled) W.ColorRow(page, ui.owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    function ui.Note(text, height)
        local host = page:Row("", height or 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return label
    end
    function ui.Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    function ui.ViewerLabel(viewer)
        local label = L[M.viewerSpecs[viewer].label]
        return M.db[viewer].show and label or (label .. "  |cff8c8c8c" .. L["Off"] .. "|r")
    end
    function ui.ViewerChoices()
        local list = {}
        for _, viewer in ipairs(M.viewers) do list[#list + 1] = { id = viewer, label = ui.ViewerLabel(viewer) } end
        return list
    end
    -- Each tab but Viewer and Copy & Apply says so when the viewer is off.
    function ui.Tab(title, build)
        page:Section(L[title], nil, false)
        if title ~= "Viewer" and title ~= "Copy & Apply" then
            ui.When(function() return not db().show end, function() ui.Note("This viewer is off. Turn on Show Viewer on the Viewer tab to use it.") end)
        end
        build()
    end

    page.configPreview = W.Preview(page, M, { contentHeight = 120 })
    -- The preview's header, seen from every tab: Editing (the viewer being
    -- changed) at the top right.
    if page.previewArea then
        local corner = CreateFrame("Frame", nil, page.previewArea)
        corner:SetPoint("TOPRIGHT", page.previewArea, "TOPRIGHT", 0, -4); corner:SetSize(300, 28)
        page.viewerSelect = ui.SelectIn(corner, 210, ui.ViewerChoices, Viewer, page.SetEditing)
        page.viewerSelect:ClearAllPoints(); page.viewerSelect:SetPoint("RIGHT", 0, 0)
        page.editingLabel = W.Label(corner, L["Editing"], nil, 0, 0, 60, T.muted)
        page.editingLabel:ClearAllPoints(); page.editingLabel:SetPoint("RIGHT", page.viewerSelect, "LEFT", -8, 0)
        page.editingLabel:SetWidth(60); page.editingLabel:SetJustifyH("RIGHT")
        page.previewReserveRight = 312
        page:UpdatePreviewLayout()
    end

    self:BuildViewerTab(ui)
    self:BuildLookTab(ui)
    self:BuildTextTab(ui)
    self:BuildGlowTab(ui)
    self:BuildSpellsTab(ui)
    self:BuildVisibilityTab(ui)
    self:BuildCopyTab(ui)

    page:HookScript("OnHide", function() if M.spellMenu then M.spellMenu:Hide() end end)
    W.SectionTabs(page)
    page:Finish(); return page
end

-- Viewer: on or off, the game's state, the layout and size, and where
-- Blizzard's own settings still apply.
function M:BuildViewerTab(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Viewer", function()
        page.showToggles = ui.Toggles({ { "Show Viewer", "show" } })
        local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        ui.Refresh(function() status:SetText(M:Status()) end)
        page.statusLabel = status
        page:Group(L["Layout"])
        local shape = ui.Columns({ "Icons per Line", "Spacing" })
        page.perLineSlider = ui.Slider(shape[1], "perLine"); ui.Mark("layout")
        page.spacingSlider = ui.Slider(shape[2], "spacing", "px")
        page.orientationPills = ui.Pills("Lines", M.choices.orientation, function() return db().orientation end, ui.Set("orientation"), 110)
        page.startPills = ui.Pills("First Icon", M.choices.start, function() return db().start end, ui.Set("start"), 100)
        page.centerToggles = ui.Toggles({ { "Center Lines", "center" } })
        ui.Note("Tracked Buffs and Bars start at the bottom so new ones grow upward. Center Lines puts a short last line in the middle.", 32)
        page:Group(L["Size"])
        local size = ui.Columns({ "Width", "Height" })
        local function SizeSlider(host, key)
            -- Icons and bars have their own ranges.
            local function Low() return M:SizeRange(ui.Viewer(), key)[1] end
            local function High() return M:SizeRange(ui.Viewer(), key)[2] end
            -- The range changes before the slider shows the new viewer's value.
            ui.Refresh(function()
                if host.slider and host.slider.SetMinMaxValues then host.slider:SetMinMaxValues(Low(), High()) end
            end)
            return ui.SliderIn(host, M:SizeRange("essential", key), function() return db()[key] end, ui.Set(key), "px",
                { minimum = Low, maximum = High })
        end
        page.widthSlider = SizeSlider(size[1], "width")
        page.heightSlider = SizeSlider(size[2], "height")
        page:Group(L["Placement"])
        local edit = page:Row(L["Edit Mode"], 48)
        page.editModeButton = W.Button(edit, L["Open Edit Mode"], 160, 30, "secondary")
        page.editModeButton:SetPoint("LEFT"); page.editModeButton:SetScript("OnClick", function() addon:SetEditMode(true) end)
        ui.Note("Each viewer is placed in ModeUI's Edit Mode, and can attach to another viewer, the screen or your frames. Blizzard's Edit Mode box for it no longer moves it.", 40)
        page:Group(L["Blizzard's Settings"])
        local settings = page:Row(L["Tracked Spells"], 48)
        page.cooldownSettingsButton = W.Button(settings, L["Cooldown Settings"], 160, 30, "secondary")
        page.cooldownSettingsButton:SetPoint("LEFT")
        page.cooldownSettingsButton:SetScript("OnClick", function() M:OpenCooldownSettings() end)
        ui.Refresh(function() page.cooldownSettingsButton:SetEnabled(M:CanOpenCooldownSettings()) end)
        ui.Note("Which spells each viewer tracks, and their order, are set in Blizzard's Cooldown Settings. Blizzard's Edit Mode options for a viewer still decide Visibility, Hide When Inactive, Show Timer, Show Tooltips and, for bars, Bar Content; its size, padding and icon limit are ModeUI's.", 64)
    end)
end

-- Look: border and background, then the cooldown on icons or the bar on bars.
function M:BuildLookTab(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Look", function()
        page:Group(L["Border"])
        page.borderPills = ui.Pills("Border", M.choices.border, function() return db().border end, ui.Set("border")); ui.Mark("look")
        local function Bordered() return db().border ~= "none" end
        local border = ui.Columns({ "Border Size", "Border Color" })
        page.borderSizeSlider = ui.Slider(border[1], "borderSize", "px")
        ui.Color(border[2], "borderColor", Bordered)
        page:Group(L["Background"])
        local background = ui.Columns({ "Background Color", "Background Opacity" })
        ui.Color(background[1], "backgroundColor")
        page.backgroundSlider = ui.Slider(background[2], "backgroundOpacity", "%")
        ui.When(ui.Icons, function()
            page:Group(L["Cooldown"])
            local swipe = ui.Columns({ "Swipe Color", "Swipe Opacity" })
            ui.Color(swipe[1], "swipeColor")
            page.swipeSlider = ui.Slider(swipe[2], "swipeOpacity", "%")
            page.cooldownToggles = ui.Toggles({ { "Edge", "showEdge" }, { "Bling", "showBling" }, { "Ready Flash", "showFlash" } })
            ui.When(ui.Cooldowns, function() page.rangeToggles = ui.Toggles({ { "Out of Range Shade", "rangeTint" } }) end)
            ui.Note("The swipe darkens the icon while it cools down (Blizzard's gold swipe for an active aura stays). Edge is the bright line on the swipe, Bling the sparkle as it ends, Ready Flash Blizzard's flash just before.", 48)
        end)
        ui.When(ui.Bars, function()
            page:Group(L["Bar"])
            local textures = ui.Columns({ "Bar Texture", "Bar Color" })
            page.barTextureSelect = ui.SelectIn(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end,
                function() return db().barTexture end, ui.Set("barTexture"))
            ui.Color(textures[2], "barColor")
            local back = ui.Columns({ "Bar Background", "Background Opacity" })
            page.barBackgroundSelect = ui.SelectIn(back[1], 200, function() return addon.Kit.BarTextureChoices(false) end,
                function() return db().barBackground end, ui.Set("barBackground"))
            page.barBackgroundSlider = ui.Slider(back[2], "barBackgroundOpacity", "%")
            page.iconSidePills = ui.Pills("Icon Side", M.choices.iconSide, function() return db().iconSide end, ui.Set("iconSide"))
            page.barToggles = ui.Toggles({ { "Spark", "showSpark" } })
        end)
        ui.When(function() return M:IsBuff(ui.Viewer()) end, function()
            page.debuffToggles = ui.Toggles({ { "Debuff Border", "debuffBorder" } })
            ui.Note("Debuff Border is Blizzard's colored frame around a debuff you track on your target.", 32)
        end)
    end)
end

-- Blizzard's Cooldown Settings window (its spell lists), opened outside combat.
function M:CanOpenCooldownSettings()
    local settings = _G.CooldownViewerSettings
    return not addon.InCombat() and type(settings) == "table" and type(settings.TogglePanel) == "function"
end
function M:OpenCooldownSettings()
    if not self:CanOpenCooldownSettings() then return false end
    if addon.configWindow and addon.configWindow:IsShown() then addon:ToggleConfig() end
    return pcall(_G.CooldownViewerSettings.TogglePanel, _G.CooldownViewerSettings)
end

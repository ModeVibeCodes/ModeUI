local _, addon = ...
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; the module's window (Window.lua) builds it the
-- first time it opens. A live preview of the bar chosen in the window's list
-- sits above the tabs (Bar, Look, Text, Glows, Spells, Visibility, Copy &
-- Apply); clicking a spell in it opens that spell's switches, and on a
-- custom bar the + slot adds a spell. This file builds the page, its helpers
-- and the Bar and Look tabs; SettingsTabs.lua the rest.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing, textPart = "essential", "cooldown"
    local function Viewer() return editing end
    local function Part() return textPart end
    local function db() return M.db[editing] end
    page.viewerEditing, page.textPart = Viewer, Part
    -- A text the new bar doesn't have falls back to its first.
    local function FitPart()
        for _, part in ipairs(M:Parts(editing)) do if part == textPart then return end end
        textPart = M:Parts(editing)[1]
    end
    function page.SetEditing(id)
        if not M:HasBar(id) then return end
        if id ~= editing then
            if M.spellMenu then M.spellMenu:Hide() end
            if M.picker then M.picker:Hide() end
        end
        editing = id
        M.selectedBar = id
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
    function ui.Custom() return M:IsCustom(editing) end
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
    function ui.ViewerLabel(id)
        local label = M:Label(id)
        return M.db[id].show and label or (label .. "  |cff8c8c8c" .. L["Off"] .. "|r")
    end
    function ui.ViewerChoices()
        local list = {}
        for _, id in ipairs(M:BarIds()) do list[#list + 1] = { id = id, label = ui.ViewerLabel(id) } end
        return list
    end
    -- Each tab but Bar and Copy & Apply says so when the bar is off.
    function ui.Tab(title, build)
        page:Section(L[title], nil, false)
        if title ~= "Bar" and title ~= "Copy & Apply" then
            ui.When(function() return not db().show end, function() ui.Note("This bar is off. Turn on Show Bar on the Bar tab to use it.") end)
        end
        build()
    end

    page.configPreview = W.Preview(page, M, { contentHeight = 120 })
    -- Editing: which bar this page shows, at the top right of the preview.
    M:AddEditingCorner(page)
    self:BuildBarTab(ui)
    self:BuildLookTab(ui)
    self:BuildTextTab(ui)
    self:BuildGlowTab(ui)
    self:BuildSpellsTab(ui)
    self:BuildVisibilityTab(ui)
    self:BuildCopyTab(ui)

    page:HookScript("OnHide", function()
        if M.spellMenu then M.spellMenu:Hide() end
        if M.picker then M.picker:Hide() end
    end)
    W.SectionTabs(page)
    page:Finish(); return page
end

-- Bar: on or off, the game's state, a custom bar's name, the layout and
-- size, and where Blizzard's own settings still apply.
function M:BuildBarTab(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Bar", function()
        page.showToggles = ui.Toggles({ { "Show Bar", "show" } })
        local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        ui.Refresh(function() status:SetText(M:Status()) end)
        page.statusLabel = status
        ui.When(ui.Custom, function()
            page:Group(L["Custom Bar"])
            local host = page:Row(L["Name"], 48)
            local box = W.TextInput(host, 260, L["Bar name"], M.MAX_NAME)
            -- Enter keeps the name; Escape leaves it as it was.
            box.onEnter = function(text) M:RenameCustomBar(ui.Viewer(), text); page:Refresh() end
            ui.Refresh(function()
                local bar = M:Custom(ui.Viewer())
                if bar and not box:HasFocus() then box:SetText(bar.name) end
            end)
            page.nameInput = box
            local kind = W.Label(page:Row(L["Holds"], 48), "", nil, 0, -4, 420, T.muted); kind:SetWordWrap(true)
            ui.Refresh(function()
                local bar = M:Custom(ui.Viewer())
                if not bar then return end
                kind:SetText(string.format(bar.kind == "buff" and L["%d tracked buffs (from Tracked Buffs)."]
                    or L["%d cooldowns (from Essential and Utility Cooldowns)."], #bar.entries))
            end)
            page.holdsLabel = kind
            ui.Note("Click + in the preview to add a spell you track in Blizzard's Cooldown Manager (it moves here from its viewer) or, on a Cooldown Bar, any spell by its Spell ID (on an icon of ModeUI's own, shown while you know the spell). Click a spell for its switches, its order, or to send it back.", 64)
            local delete = page:Row("", 40)
            delete.rowLabel:Hide(); delete:ClearAllPoints(); delete:SetAllPoints(delete.row)
            page.deleteButton = W.Button(delete, L["Delete Bar"], 140, 30, "secondary")
            page.deleteButton:SetPoint("LEFT")
            page.deleteButton:SetScript("OnClick", function()
                if M:DeleteCustomBar(ui.Viewer()) then M:SelectBar("essential") end
            end)
        end)
        -- Racials (Racials.lua): one choice for the module, shown on the bars that can take them.
        ui.When(function() return M:TakesOwn(ui.Viewer()) end, function()
            page:Group(L["Racial Abilities"])
            local racials = ui.Columns({ "Show On" })
            page.racialsSelect = ui.SelectIn(racials[1], 240, function() return M:RacialChoices() end,
                function() return M.db.racials end, function(value) M:SetRacials(value) end)
            ui.Note("Your race's abilities (Berserking, Stoneform, Arcane Torrent...) show on their own at the end of the bar picked here; Blizzard's Cooldown Manager doesn't track them. Remove from Bar hides one; the + list adds one to another bar.", 48)
        end)
        page:Group(L["Layout"])
        local grow = ui.Columns({ "Growth" })
        page.growSelect = ui.SelectIn(grow[1], 240, function() return M.choices.grow end, function() return db().grow end, ui.Set("grow")); ui.Mark("layout")
        local function Horizontal() return M.horizontalGrowth[db().grow] == true end
        local function Lines(list)
            local out = {}
            for _, id in ipairs(list) do for _, choice in ipairs(M.choices.lineGrowth) do if choice.id == id then out[#out + 1] = choice end end end
            return out
        end
        ui.When(Horizontal, function()
            page.rowLinePills = ui.Pills("New Lines", Lines(M.lineChoices.horizontal), function() return db().lineGrowth end, ui.Set("lineGrowth"), 90)
        end)
        ui.When(function() return not Horizontal() end, function()
            page.columnLinePills = ui.Pills("New Lines", Lines(M.lineChoices.vertical), function() return db().lineGrowth end, ui.Set("lineGrowth"), 90)
        end)
        local shape = ui.Columns({ "Icons per Line", "Spacing" })
        page.perLineSlider = ui.Slider(shape[1], "perLine")
        page.spacingSlider = ui.Slider(shape[2], "spacing", "px")
        ui.Note("Centered keeps a line's icons in its middle; the others start at one end. The first line stays where the bar is placed; further lines go the New Lines way.", 40)
        page:Group(L["Size"])
        local size = ui.Columns({ "Width", "Height" })
        local function SizeSlider(host, key)
            -- Icons and bars have their own ranges; the range changes before
            -- the slider shows the new bar's value.
            local function Low() return M:SizeRange(ui.Viewer(), key)[1] end
            local function High() return M:SizeRange(ui.Viewer(), key)[2] end
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
        ui.Note("Each bar is placed in ModeUI's Edit Mode, and can attach to a viewer, the screen or your frames. Blizzard's Edit Mode box no longer moves a viewer.", 40)
        ui.When(function() return not ui.Custom() end, function()
            page:Group(L["Blizzard's Settings"])
            local settings = page:Row(L["Tracked Spells"], 48)
            page.cooldownSettingsButton = W.Button(settings, L["Open CDM"], 160, 30, "secondary")
            page.cooldownSettingsButton:SetPoint("LEFT")
            page.cooldownSettingsButton:SetScript("OnClick", function() M:OpenCooldownSettings() end)
            ui.Refresh(function() page.cooldownSettingsButton:SetEnabled(M:CanOpenCooldownSettings()) end)
            ui.Note("Which spells each viewer tracks, and their order, are set in Blizzard's Cooldown Manager. Blizzard's Edit Mode options for a viewer still decide Visibility, Hide When Inactive, Show Timer, Show Tooltips and, for bars, Bar Content; its size, padding and icon limit are ModeUI's. On Essential and Utility the + slot in the preview also takes spells from the other viewer or a custom bar, spells by ID and items.", 80)
        end)
    end)
end

-- Look: border and background, then the cooldown on icons or the bar on bars.
function M:BuildLookTab(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Look", function()
        page:Group(L["Border"])
        page.borderPills = ui.Pills("Border", M.choices.border, function() return db().border end, ui.Set("border")); ui.Mark("look")
        local function Bordered() return db().border ~= "none" end
        local border = ui.Columns({ "Border Color" })
        ui.Color(border[1], "borderColor", Bordered)
        ui.When(function() local style = db().border; return style == "rounded" or style == "square" end, function()
            local size = ui.Columns({ "Border Size" })
            page.borderSizeSlider = ui.Slider(size[1], "borderSize", "px")
        end)
        ui.Note("ModeUI is ModeUI's own border (a crisp 2px rim with round corners, as on the unit frames); Rounded and Square are the action bars' slot rim, with its own size.", 40)
        page:Group(L["Background"])
        local background = ui.Columns({ "Background Color", "Background Opacity" })
        ui.Color(background[1], "backgroundColor")
        page.backgroundSlider = ui.Slider(background[2], "backgroundOpacity", "%")
        ui.When(ui.Icons, function()
            page:Group(L["Cooldown"])
            ui.When(ui.Cooldowns, function()
                page.desaturateToggles = ui.Toggles({ { "Desaturate on Cooldown", "desaturate" }, { "Show Aura Time", "auraSwipe" } })
            end)
            local swipe = ui.Columns({ "Swipe Color", "Swipe Opacity" })
            ui.Color(swipe[1], "swipeColor")
            page.swipeSlider = ui.Slider(swipe[2], "swipeOpacity", "%")
            page.cooldownToggles = ui.Toggles({ { "Edge", "showEdge" }, { "Bling", "showBling" }, { "Ready Flash", "showFlash" } })
            ui.When(ui.Cooldowns, function() page.rangeToggles = ui.Toggles({ { "Out of Range Tint", "rangeTint" } }) end)
            ui.Note("Desaturate on Cooldown turns an icon gray while its spell cools down (not for the global cooldown). Show Aura Time shows a spell's effect time instead (Blizzard's full-color gold swipe) while it's up; off, the icon keeps its gray cooldown. The swipe darkens the icon while it cools. Edge is the bright line on the swipe, Bling the sparkle as it ends, Ready Flash Blizzard's flash just before. Out of Range Tint keeps Blizzard's red tint on a spell that's out of range.", 64)
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
    return pcall(_G.CooldownViewerSettings.TogglePanel, _G.CooldownViewerSettings)
end

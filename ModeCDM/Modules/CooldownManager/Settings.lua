local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; the module's window (Window.lua) builds it the
-- first time it opens. One scrolling page with a section index on its left
-- (owner, November 24, 2026): Layout, Look, Text, Spells & Glows and Show.
-- Above it the preview: the Layout view (Stage.lua: every bar in place, this
-- one outlined) or the Bar view (Preview.lua: this bar, to click and drag
-- its spells). Groups that can follow the Bar Style carry its chip; the
-- controls the Bar Style sets show while the group is the bar's own; rarely
-- changed ones sit under More options. This file builds the page, its
-- helpers and Layout; SettingsLook.lua Look and Text; SettingsTabs.lua the rest.
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
        return W.Note(label), label
    end
    function ui.Button(label, width, onClick)
        local host = page:Row("", 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local button = W.Button(host, L[label], width, 30, "secondary")
        button:SetPoint("LEFT"); button:SetScript("OnClick", onClick)
        return button
    end
    function ui.Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    function ui.ViewerLabel(id)
        local label = M:Label(id)
        return M.db[id].show and label or (label .. "  " .. addon.Style.ColorText(L["Off"], addon.Style.Tone.graphite.muted))
    end
    -- What a group shows while it follows the Bar Style: one line saying so.
    function ui.Summary(group, text)
        ui.When(function() return M:Follows(editing, group) end, function()
            local _, label = ui.Note("", 28)
            W.Tip(label)
            ui.Refresh(function() label:SetText(text()) end)
        end)
    end
    M:PageScaffold(page, ui, {
        follows = function(group) return M:Follows(editing, group) end,
        setFollow = function(group, on) M:FollowGroup(editing, group, on) end,
    })
    -- Each section but Layout says so while the bar is off.
    function ui.Tab(title, build)
        ui.Section(title)
        if title ~= "Layout" then
            ui.When(function() return not db().show end, function() W.Tip(ui.Note("This bar is off. Turn on Show Bar under Layout to use it.")) end)
        end
        build()
    end

    page.configPreview = W.Preview(page, M, { contentHeight = 150 })
    M:AddPreviewCorner(page, { views = true, custom = function() return M:CustomGroups(editing) end,
        useStyle = function() M:UseBarStyle(editing) end })
    self:BuildLayoutSection(ui)
    self:BuildLookSection(ui)
    self:BuildTextSection(ui)
    self:BuildSpellsSection(ui)
    self:BuildShowSection(ui)

    page:HookScript("OnHide", function()
        if M.spellMenu then M.spellMenu:Hide() end
        if M.picker then M.picker:Hide() end
    end)
    page:Finish(); return page
end

-- Layout: on or off, a custom bar's name, growth and lines, and the size.
function M:BuildLayoutSection(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Layout", function()
        page:Group(L["Bar"])
        page.showToggles = ui.Toggles({ { "Show Bar", "show" } })
        local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        ui.Refresh(function() status:SetText(M:Status()) end)
        page.statusLabel = status
        ui.When(ui.Custom, function()
            local host = page:Row(L["Name"], 48)
            local box = W.TextInput(host, 260, L["Bar name"], M.MAX_NAME)
            -- Enter keeps the name; Escape leaves it as it was.
            box.onEnter = function(text) M:RenameCustomBar(ui.Viewer(), text); page:Refresh() end
            ui.Refresh(function()
                local bar = M:Custom(ui.Viewer())
                if bar and not box:HasFocus() then box:SetText(bar.name) end
            end)
            page.nameInput = box
            local kind = W.Label(page:Row(L["Spells"], 48), "", nil, 0, -4, 420, T.muted); kind:SetWordWrap(true)
            ui.Refresh(function()
                local bar = M:Custom(ui.Viewer())
                if not bar then return end
                kind:SetText(string.format(bar.kind == "buff" and L["%d tracked buffs (from Tracked Buffs)."]
                    or L["%d cooldowns (from Essential and Utility Cooldowns)."], #bar.entries))
            end)
            page.holdsLabel = kind
            ui.More("bar", function()
                -- Delete Bar asks first, like the list's -.
                page.deleteButton = ui.Button("Delete Bar", 140, function() M:ConfirmDelete(ui.Viewer()) end)
            end)
        end)
        page:Group(L["Growth"])
        local grow = ui.Columns({ "Grow" })
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
        local perLine = ui.Columns({ "Icons per Line" })
        page.perLineSlider = ui.Slider(perLine[1], "perLine")
        -- Size: the Bar Style's Large or Small size, or the bar's own.
        page:Group(L["Size"]); ui.Chip("size")
        ui.Summary("size", function()
            local style = db()
            if ui.Bars() then return string.format(L["Bar Style: spacing %d."], style.spacing) end
            return string.format(L["Bar Style %s: %d x %d, spacing %d."], M:SizeRole(ui.Viewer()) == "small" and L["Small"] or L["Large"],
                style.width, style.height, style.spacing)
        end)
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
        -- Icons: one Icon Size (the height; the width keeps the icon's shape).
        ui.When(ui.Icons, function()
            local size = ui.Columns({ "Icon Size" })
            page.iconSizeSlider = ui.SliderIn(size[1], M.sizeRanges.icon.height, function() return db().height end, function(value)
                local style = db()
                local width = math.max(M.sizeRanges.icon.width[1], math.min(M.sizeRanges.icon.width[2], value + style.width - style.height))
                M:SetOption(ui.Viewer(), "height", value); M:SetOption(ui.Viewer(), "width", width)
            end, "px")
        end)
        ui.When(ui.Bars, function()
            local size = ui.Columns({ "Width", "Height" })
            page.widthSlider = SizeSlider(size[1], "width")
            page.heightSlider = SizeSlider(size[2], "height")
        end)
        ui.Styled("size", function()
            local spacing = ui.Columns({ "Spacing" })
            page.spacingSlider = ui.Slider(spacing[1], "spacing", "px")
        end)
        ui.When(ui.Icons, function()
            ui.More("size", function()
                local size = ui.Columns({ "Width", "Height" })
                page.widthSlider = SizeSlider(size[1], "width")
                page.heightSlider = SizeSlider(size[2], "height")
            end)
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

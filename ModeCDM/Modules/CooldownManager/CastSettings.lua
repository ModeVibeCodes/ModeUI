local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, L = addon.CooldownManager, addon.ConfigWidgets, addon.L
if not M then return end

-- The Cast Bar's page, shown in the /mcdm window when Cast Bar is chosen in
-- its list (under Resource Bars); built the first time. A preview with a
-- sample cast above four tabs: Bar, Look, Text and Visibility. Settings
-- change outside combat, checked by Initialize on a copy first.
local function Copy(value) return addon.ProfileCodec.Copy(value) end

local function Changed(self, alphaOnly)
    if self.active then
        if alphaOnly then self:UpdateCast() else self:LayoutCast(); self:RenderCastMover() end
    end
    if not alphaOnly and addon.EditMode then addon.EditMode:RefreshElements() end
    if self.castPage then
        self.castPage:Refresh()
        if not alphaOnly then self.castPage:Layout() end
    end
    if self.window then self:RefreshList() end
    return true
end

function M:SetCastOption(key, value)
    if not self:CanConfigure() or self.castDefaults[key] == nil then return false end
    local candidate = Copy(self.db)
    candidate.castBar[key] = Copy(value)
    -- Border and font values it takes from the Bar Style become its own.
    local group, follow = self.playerKeyGroup[key], candidate.castBar.follow
    if group and type(follow) == "table" and follow[group] then follow[group] = false end
    if not pcall(self.Initialize, candidate) then return false end
    self.db.castBar[key] = candidate.castBar[key]
    self.db.castBar.follow = candidate.castBar.follow
    return Changed(self, key == "opacity")
end

-- Back to the defaults; whether it shows and its size stay.
function M:ResetCast()
    if not self:CanConfigure() then return false end
    local style = Copy(self.castDefaults)
    for key in pairs(self.castIdentityKeys) do style[key] = Copy(self.db.castBar[key]) end
    style.follow = { border = true, text = true }
    local target = self.db.castBar
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(style) do target[key] = value end
    self.ApplyPlayerStyle(self.db, target)
    return Changed(self, false)
end

-- Owner for the shared font and color widgets.
function M:CastAppearanceOwner()
    local appearance = setmetatable({}, { __index = function(_, key) return M.db.castBar[key] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetCastOption(key, value) end
    return owner
end

function M:CreateCastPage(parent)
    local page = W.Page(parent, 480); self.castPage = page
    local function db() return M.db.castBar end
    local ui = self:PageHelpers(page, { db = db, set = function(key, value) M:SetCastOption(key, value) end,
        ranges = M.castRanges, owner = self:CastAppearanceOwner() })
    local When, Columns = ui.When, ui.Columns
    local function Dark() return db().barMode == "dark" end

    W.Preview(page, self:CastPreviewOwner(), { contentHeight = 90 })
    self:AddEditingCorner(page)

    ui.Tab("Bar", function()
        page.castShowToggles = ui.Toggles({ { "Show Bar", "show" } })
        page.castStatus = ui.Status(function() return M:CastStatus() end)
        page:Group(L["Size"])
        local size = Columns({ "Width", "Height" })
        page.castWidthSlider = ui.Slider(size[1], "width", "px")
        page.castHeightSlider = ui.Slider(size[2], "height", "px")
        -- The spell icon in its own border, at either end.
        page:Group(L["Icon"])
        page.castIconPills = ui.Pills("Icon", M.castChoices.icon, "icon", 96)
        When(function() return db().icon ~= "none" end, function()
            local gap = Columns({ "Icon Gap" })
            page.castIconGapSlider = ui.Slider(gap[1], "iconGap", "px")
        end)
        page:Group(L["Interrupts"])
        page.castInterruptToggles = ui.Toggles({ { "Show Interrupted", "showInterrupted" } })
        W.Tip(ui.Note("An interrupted cast stays on the bar for 1 second in the Interrupted color, then fades."))
        page:Group(L["Placement"])
        page.castEditModeButton = ui.EditModeButton()
        page:Group(L["Reset"])
        page.castResetButton = ui.Button("Reset to Defaults", 150, function() M:ResetCast() end)
    end)

    ui.Tab("Look", function()
        page:Group(L["Border"])
        page.castBorderPills = ui.Pills("Border", M.castChoices.border, "border", 96)
        -- Border Style and Rim Color, as on the resource bars.
        When(function() return db().border ~= "none" end, function()
            local cells = Columns({ "Border Style", "Rim Color" })
            page.castBorderStylePicker = ui.Select(cells[1], 180, function() return M.castChoices.edgeStyle end, "edgeStyle")
            page.castRimPicker = ui.Select(cells[2], 180, M.ResourceRimChoices, nil,
                function() return M:CastRim() end, function(value) M:SetCastRim(value) end)
            local size = Columns({ "Border Size" })
            page.castBorderSizeSelect = ui.Select(size[1], 180, function() return M.choices.edgeSize end, "edgeSize")
            When(function() return db().rimColor == "custom" end, function()
                local custom = Columns({ "Custom Rim Color" })
                ui.Color(custom[1], "rimCustom")
            end)
        end)
        page:Group(L["Bar"])
        -- Bar Mode: Color (the fill in Bar Color) or Dark (the fill dark, the
        -- Comet head alone, the text in color).
        page.castBarModePills = ui.Pills("Bar Mode", M.castChoices.barMode, "barMode", 96)
        local texture = Columns({ "Bar Texture", "Bar Color" })
        page.castTextureSelect = ui.Select(texture[1], 200, function() return addon.Kit.BarTextureChoices(true) end, "barTexture")
        page.castBarColorSelect = ui.Select(texture[2], 180, function() return M.castChoices.barColorMode end, "barColorMode")
        When(function() return db().barColorMode == "custom" end, function()
            local custom = Columns({ "Custom Bar Color" })
            ui.Color(custom[1], "barColor")
        end)
        local states = Columns({ "Not Interruptible", "Interrupted" })
        ui.Color(states[1], "lockedColor"); ui.Color(states[2], "interruptedColor")
        When(Dark, function()
            local text = Columns({ "Dark Text Color" })
            page.castDarkTextSelect = ui.Select(text[1], 200, function() return M.castChoices.darkText end, "darkText")
            When(function() return db().darkText == "custom" end, function()
                local custom = Columns({ "Custom Text Color" })
                ui.Color(custom[1], "darkTextColor")
            end)
        end)
        local back = Columns({ "Bar Background", "Background Opacity" })
        page.castBackgroundSelect = ui.Select(back[1], 200, function() return addon.Kit.BarTextureChoices(false) end, "barBackground")
        ui.Slider(back[2], "barBackgroundOpacity", "%")
        page.castSparkToggles = ui.Toggles({ { "Spark", "spark" } })
    end)

    ui.Tab("Text", function()
        -- Spell Name and Timer, each placed on its own.
        for _, part in ipairs({ { "Spell Name", "name" }, { "Timer", "timer" } }) do
            local title, key = part[1], part[2]
            page:Group(L[title])
            ui.Toggles({ { "Show " .. title, key .. "Show" } })
            When(function() return db()[key .. "Show"] end, function()
                ui.Pills("Anchor", M.castChoices[key .. "Anchor"], key .. "Anchor", 90)
                local place = Columns({ "Offset X", "Offset Y" })
                ui.Slider(place[1], key .. "X", "px"); ui.Slider(place[2], key .. "Y", "px")
            end)
        end
        page:Group(L["Text"])
        local size = Columns({ "Size" })
        page.castTextSizeSlider = ui.Slider(size[1], "textSize")
        -- In Dark mode the text takes Dark Text Color (Look tab).
        When(function() return not Dark() end, function()
            local color = Columns({ "Text Color" })
            ui.Color(color[1], "textColor")
        end)
        page:Group(L["Font"])
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), ui.owner); ui.Refresh(fontRefresh)
        page.castFontToggles = ui.Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" }, { "Slug Text", "slug" } })
    end)

    ui.Tab("Visibility", function()
        page:Group(L["Visibility"])
        local opacity = Columns({ "Opacity" })
        page.castOpacitySlider = ui.Slider(opacity[1], "opacity", "%")
        W.Tip(ui.Note("The cast bar shows while you cast, and with a sample in Edit Mode."))
    end)

    W.SectionTabs(page)
    page:Finish(); return page
end

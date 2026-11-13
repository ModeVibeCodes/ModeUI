local _, addon = ...
local M, W = addon.UnitFrames, addon.ConfigWidgets
if not M then return end

-- Text spots (TextSlots.lua): one dropdown per spot laid out like the frame
-- (left, centre, right; owner, November 13, 2026), all the same size, in the
-- tab of the bar they sit on (Health Bar: its nine spots and the border; Power
-- Bar: its three). A spot with a text gets a small color swatch and font size
-- under its dropdown. The Text tab holds the general text settings (names,
-- font). Built by CreateConfigPage (Settings.lua) with its helpers in `ui`.
local ROWS = { { "topLeft", "top", "topRight" }, { "left", "center", "right" }, { "bottomLeft", "bottom", "bottomRight" } }
local CELL_HEIGHT = 92
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Quick color icons beside a spot's size (owner, November 13, 2026): each
-- turns on a color that follows the unit, if it suits the text; clicking the
-- lit one goes back to the default. Drawn from flat stripes (and the game's
-- class icon), so they need no art of their own.
local MODE_ICONS = {
    reaction = { title = "Reaction", text = "Hostile red, neutral yellow, friendly green, tapped gray.",
        stripes = { { 255, 107, 107 }, { 255, 214, 102 }, { 120, 214, 140 } } },
    class = { title = "Class Color", text = "A player's class color; anyone else by reaction." },
    difficulty = { title = "Level Difficulty", text = "The game's color for the level against yours: gray, green, yellow, orange, red.",
        stripes = { { 157, 157, 157 }, { 64, 191, 64 }, { 255, 209, 0 }, { 255, 128, 64 }, { 255, 26, 26 } } },
}
local function Tooltip(button, title, text)
    button:HookScript("OnEnter", function()
        if not GameTooltip or not GameTooltip.SetOwner then return end
        GameTooltip:SetOwner(button, "ANCHOR_TOP"); GameTooltip:SetText(title)
        if GameTooltip.AddLine then GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
local function ModeIcon(parent, mode)
    local spec, button = MODE_ICONS[mode], W.Button(parent, "", 22, 22, "choice")
    if spec.stripes then
        local count = #spec.stripes
        for i, rgb in ipairs(spec.stripes) do
            local stripe = button:CreateTexture(nil, "OVERLAY")
            stripe:SetTexture(addon.Kit.FLAT); stripe:SetVertexColor(rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, 1)
            stripe:SetPoint("TOPLEFT", 5 + (i - 1) * 12 / count, -5); stripe:SetSize(12 / count, 12)
        end
    else
        -- Your class's icon.
        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetPoint("TOPLEFT", 4, -4); icon:SetPoint("BOTTOMRIGHT", -4, 4)
        local _, class = UnitClass("player")
        -- SetAtlas returns false for an atlas the client lacks.
        local ok, set = false, false
        if type(class) == "string" then ok, set = pcall(icon.SetAtlas, icon, "classicon-" .. class:lower()) end
        if not ok or set == false then
            icon:SetTexture(addon.Kit.FLAT); icon:SetVertexColor(1, 0.96, 0.41, 1)
        end
        button.classIcon = icon
    end
    Tooltip(button, spec.title, spec.text .. " Click again for the default color.")
    return button
end

-- The spots of one bar ("health" or "power").
function M:BuildTextSpots(ui, part)
    local page, When = ui.page, ui.When
    local function Slots() return ui.db().texts end
    local contents = M.choices.textContent
    page.unitFrameTextSelects = page.unitFrameTextSelects or {}
    page.unitFrameTextSwatches, page.unitFrameTextSizes = page.unitFrameTextSwatches or {}, page.unitFrameTextSizes or {}

    -- The color a slot's text shows: custom, a unit color (as the stand-ins
    -- show it), else its default.
    local function ShownColor(slot)
        local s, unit = Slots()[slot], ui.Editing()
        if s.colorMode == "custom" then return s.color end
        if s.colorMode ~= "default" and M.TextColorModeFits(s.content, s.colorMode) then
            local color = M:UnitTextColor({ ghost = true }, unit, s.colorMode)
            if color then return color end
        end
        if s.content == "level" then return M.palette.muted end
        if M.contentKind[s.content] == "name" then return M:NameColor(unit, M:SampleIdentity(unit, M:FrameDB(unit))) end
        return ui.db().textColor
    end
    -- The game's color picker; its live changes apply throttled, Cancel restores.
    local function PickColor(slot)
        if not M:CanConfigure() then return end
        if not ColorPickerFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_ColorPickerFrame") end
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        addon:CloseTimerColorPicker()
        local unit, s = ui.Editing(), Slots()[slot]
        local before, start = { colorMode = s.colorMode, color = Copy(s.color) }, ShownColor(slot)
        local apply, flush = W.Throttle(function(rgb) M:SetTextOptions(unit, slot, { colorMode = "custom", color = rgb }) end)
        local function Swatch() local r, g, b = ColorPickerFrame:GetColorRGB(); apply({ r, g, b }) end
        addon.timerPickerCallback = Swatch
        ColorPickerFrame:SetupColorPickerAndShow({ r = start[1], g = start[2], b = start[3], hasOpacity = false, swatchFunc = Swatch,
            cancelFunc = function() flush(); M:SetTextOptions(unit, slot, before) end })
    end

    -- One spot: its dropdown across the cell, then (with a text) the color
    -- swatch (right-click: default color), a font size stepper and the unit
    -- color icons that suit its text.
    local function Cell(host, slot)
        local select = ui.SelectIn(host, 200, function() return contents end, function() return Slots()[slot].content end,
            function(v) M:SetTextOption(ui.Editing(), slot, "content", v) end)
        select:ClearAllPoints(); select:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0); select:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
        local line = CreateFrame("Frame", nil, host)
        line:SetPoint("TOPLEFT", select, "BOTTOMLEFT", 0, -6); line:SetPoint("TOPRIGHT", select, "BOTTOMRIGHT", 0, -6); line:SetHeight(24)
        local swatch = W.Button(line, "", 24, 24)
        swatch:SetPoint("LEFT", 0, 0)
        swatch.sample = W.Shape(swatch, "ModeFlat", "OVERLAY")
        swatch.sample:SetPoint("TOPLEFT", 4, -4); swatch.sample:SetPoint("BOTTOMRIGHT", -4, 4)
        swatch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        swatch:SetScript("OnClick", function(_, button)
            if button == "RightButton" then M:SetTextOption(ui.Editing(), slot, "colorMode", "default") else PickColor(slot) end
        end)
        Tooltip(swatch, "Text Color", "Click to pick a color. Right-click for the default color.")
        local function Size(delta)
            local r = M.textRanges.size
            M:SetTextOption(ui.Editing(), slot, "size", math.max(r[1], math.min(r[2], Slots()[slot].size + delta)))
        end
        local smaller = W.Button(line, "-", 22, 24); smaller:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
        smaller:SetScript("OnClick", function() Size(-1) end)
        local size = W.NumericInput(line, function() return Slots()[slot].size end,
            function(v) M:SetTextOption(ui.Editing(), slot, "size", math.floor(v + 0.5)) end, M.textRanges.size[1], M.textRanges.size[2], 32)
        size:SetPoint("LEFT", smaller, "RIGHT", 2, 0)
        local larger = W.Button(line, "+", 22, 24); larger:SetPoint("LEFT", size, "RIGHT", 2, 0)
        larger:SetScript("OnClick", function() Size(1) end)
        local icons = {}
        for _, mode in ipairs(M.unitColorModes) do
            local icon = ModeIcon(line, mode)
            icon:SetScript("OnClick", function()
                M:SetTextOption(ui.Editing(), slot, "colorMode", Slots()[slot].colorMode == mode and "default" or mode)
            end)
            icons[mode] = icon
        end
        page.refreshers[#page.refreshers + 1] = function()
            local s = Slots()[slot]
            line:SetShown(s.content ~= "none")
            if s.content == "none" then return end
            local c = ShownColor(slot)
            swatch.sample:SetVertexColor(c[1], c[2], c[3], 1)
            size:Refresh()
            -- The icons that suit this text, from the right edge.
            local last
            for i = #M.unitColorModes, 1, -1 do
                local mode = M.unitColorModes[i]
                local icon, fits = icons[mode], M.TextColorModeFits(s.content, mode)
                icon:SetShown(fits); icon:SetSelected(fits and s.colorMode == mode)
                if fits then
                    icon:ClearAllPoints()
                    if last then icon:SetPoint("RIGHT", last, "LEFT", -3, 0) else icon:SetPoint("RIGHT", line, "RIGHT", 0, 0) end
                    last = icon
                end
            end
        end
        page.unitFrameTextSelects[slot], page.unitFrameTextSwatches[slot], page.unitFrameTextSizes[slot] = select, swatch,
            { smaller = smaller, input = size, larger = larger, icons = icons, line = line }
    end
    -- A row of spots; clicking one of its texts in the preview opens it.
    local function Spots(slots, titles)
        local hosts = page:Columns(titles, CELL_HEIGHT)
        for i, slot in ipairs(slots) do if slot then Cell(hosts[i], slot); ui.Mark("text:" .. slot) end end
        return hosts
    end

    if part == "power" then
        page:Group("Text")
        Spots(M.powerSlots, { M.textSlotLabels.powerLeft, M.textSlotLabels.powerCenter, M.textSlotLabels.powerRight })
        return
    end
    page:Group("Text")
    for _, row in ipairs(ROWS) do
        local titles = {}
        for i, slot in ipairs(row) do titles[i] = M.textSlotLabels[slot] end
        Spots(row, titles)
    end
    local border = Spots({ "border", false, false }, { M.textSlotLabels.border, "Border Alignment", "" })
    local align = ui.SelectIn(border[2], 200, function() return M.choices.textAlign end, function() return Slots().border.align end,
        function(v) M:SetTextOption(ui.Editing(), "border", "align", v) end)
    align:ClearAllPoints(); align:SetPoint("TOPLEFT", border[2], "TOPLEFT", 0, 0); align:SetPoint("TOPRIGHT", border[2], "TOPRIGHT", 0, 0)
    page.unitFrameBorderAlign = align
    page.refreshers[#page.refreshers + 1] = function()
        local on = Slots().border.content ~= "none"
        align:SetShown(on); border[2].rowLabel:SetShown(on)
    end
end

-- General text settings: name colors and the font.
function M:BuildTextTab(ui)
    local page, When = ui.page, ui.When
    ui.Tab("Text", function()
        page:Group("Names")
        -- Plain text: Sky by default, or Champagne, Lilac, Frost, class or custom.
        ui.Choice("Name Color", "nameColorMode")
        When(function() return ui.db().nameColorMode == "custom" end, function() ui.Color("Custom Name Color", "nameColor") end)
        -- Pastel: class-colored names, class health and the class gradient ring all use it.
        ui.Slider("Class Color Softness", "classSoftness", "%")
        page:Group("Font")
        local _, refresh = W.FontDropdown(page:Row("Font", 42), ui.owner); page.refreshers[#page.refreshers + 1] = refresh
        ui.Toggles({ { "Text Outline", "outline" } })
        -- One choice for both shadows: None, Crisp (1px) or Lifted (1px plus a lighter one under it).
        local choices = {}
        for _, choice in ipairs(addon.Kit.SHADOW_CHOICES) do choices[#choices + 1] = { label = choice.label, value = choice.id, width = 96 } end
        local _, shadow = W.Exclusive(page:Row("Text Shadow", 48), choices, function() return addon.Kit.ShadowMode(ui.db()) end,
            function(mode)
                local on, lifted = addon.Kit.ShadowKeys(mode)
                M:SetFrameOption(ui.Editing(), "shadow", on); M:SetFrameOption(ui.Editing(), "liftedShadow", lifted)
            end)
        page.refreshers[#page.refreshers + 1] = shadow
        -- Default for numbers; names keep the Name Color and the level stays muted.
        ui.Color("Text Color", "textColor")
    end)
end

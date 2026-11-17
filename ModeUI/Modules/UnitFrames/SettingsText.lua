local _, addon = ...
local M, W = addon.UnitFrames, addon.ConfigWidgets
if not M then return end

-- The Text tab (docs/DESIGN_LANGUAGE.md, "Settings window"): the general text
-- settings (font, names), then one tile per kind of text (Name, Level,
-- Health, Power), every tile with the same controls: what it shows, where it
-- sits (a spot on the frame, TextSlots.lua), its size, color and offset. Each
-- text sits in one spot; moving it carries its size, color and offset along.
-- Built by CreateConfigPage (Settings.lua) with its helpers in `ui`.
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- The kinds, the contents each can show, the spots it can take, and where it
-- goes when it is turned on again.
local KINDS = {
    { id = "name", title = "Name", contents = { "name", "levelName" }, home = "border" },
    { id = "level", title = "Level", contents = { "level" }, home = "bottomLeft" },
    { id = "health", title = "Health Text", contents = { "healthPercent", "healthCurrent", "healthBoth", "healthDeficit" }, home = "right" },
    { id = "power", title = "Power Text", contents = { "powerPercent", "powerCurrent", "powerBoth" }, home = "powerCenter", power = true },
}
local BAR_SPOTS = { "topLeft", "top", "topRight", "left", "center", "right", "bottomLeft", "bottom", "bottomRight" }
local function Label(list, id)
    for _, item in ipairs(list) do if item.id == id then return item.label end end
    return id
end

function M:BuildTextKinds(ui)
    local page, When = ui.page, ui.When
    local function Slots() return ui.db().texts end
    local contentKind = {}
    for _, kind in ipairs(KINDS) do for _, content in ipairs(kind.contents) do contentKind[content] = kind end end
    -- The spot holding a kind's text, or nil while it is hidden.
    local function Spot(kind)
        local slots = Slots()
        for _, slot in ipairs(M.textSlots) do if contentKind[slots[slot].content] == kind then return slot, slots[slot] end end
    end
    page.unitFrameTextKinds = {}
    for _, kind in ipairs(KINDS) do
        local controls = {}
        page.unitFrameTextKinds[kind.id] = controls
        local function Shown() return Spot(kind) ~= nil end
        local function Group()
            page:Group(kind.title)
            -- What it shows: its contents, or Hidden.
            local show = page:Row("Show")
            local choices = { { id = "none", label = "Hidden" } }
            for _, content in ipairs(kind.contents) do choices[#choices + 1] = { id = content, label = Label(M.choices.textContent, content) } end
            controls.show = ui.SelectIn(show, 160, function() return choices end, function()
                local _, s = Spot(kind)
                return s and s.content or "none", s and Label(M.choices.textContent, s.content) or "Hidden"
            end, function(content)
                local slot = Spot(kind) or kind.home
                M:SetTextOption(ui.Editing(), slot, "content", content)
            end)
            ui.Mark("text:kind:" .. kind.id)
            -- Where it sits: a spot on the frame (taking a spot clears its old one).
            local spots = {}
            for _, slot in ipairs(kind.power and M.powerSlots or BAR_SPOTS) do spots[#spots + 1] = slot end
            if not kind.power then spots[#spots + 1] = "border" end
            local where = page:Row("Position")
            where.row.visibleWhen = Shown
            controls.position = ui.SelectIn(where, 160, function()
                local list, slots = {}, Slots()
                for _, slot in ipairs(spots) do
                    local other = contentKind[slots[slot].content]
                    local taken = other and other ~= kind and ("  (" .. other.title .. ")") or ""
                    list[#list + 1] = { id = slot, label = M.textSlotLabels[slot] .. taken }
                end
                return list
            end, function()
                local slot = Spot(kind)
                return slot, slot and M.textSlotLabels[slot] or ""
            end, function(slot)
                local from, s = Spot(kind)
                if not from or from == slot then return end
                M:SetTextOptions(ui.Editing(), slot, { content = s.content, size = s.size, colorMode = s.colorMode,
                    color = Copy(s.color), x = s.x, y = s.y })
            end)
            -- On the border: its alignment.
            local align = page:Row("Alignment")
            align.row.visibleWhen = function() return Spot(kind) == "border" end
            controls.align = ui.SelectIn(align, 160, function() return M.choices.textAlign end,
                function() return Slots().border.align end, function(v) M:SetTextOption(ui.Editing(), "border", "align", v) end)
            -- Size and offsets, the spot's own.
            local function Number(title, key, range, suffix)
                local host = page:Row(title)
                host.row.visibleWhen = Shown
                local refresh = W.Slider(host, range[1], range[2], 1, function()
                    local _, s = Spot(kind); return s and s[key] or 0
                end, function(v)
                    local slot = Spot(kind)
                    if slot then M:SetTextOption(ui.Editing(), slot, key, math.floor(v + 0.5)) end
                end, suffix, true)
                page.refreshers[#page.refreshers + 1] = refresh
                return host.slider
            end
            controls.size = Number("Size", "size", M.textRanges.size, "")
            -- Color: Default, Custom or a color that follows the unit (if it suits the text).
            local color = page:Row("Color")
            color.row.visibleWhen = Shown
            controls.color = ui.SelectIn(color, 160, function()
                local list, _, s = {}, Spot(kind)
                for _, mode in ipairs(M.choices.textColorMode) do
                    if not s or M.TextColorModeFits(s.content, mode.id) then list[#list + 1] = mode end
                end
                return list
            end, function()
                local _, s = Spot(kind)
                return s and s.colorMode or "default", s and Label(M.choices.textColorMode, s.colorMode) or ""
            end, function(mode)
                local slot = Spot(kind)
                if slot then M:SetTextOption(ui.Editing(), slot, "colorMode", mode) end
            end)
            controls.custom = self:TextColorSwatch(ui, function() return Spot(kind) end, function()
                local _, s = Spot(kind); return s and s.colorMode == "custom"
            end)
            controls.x = Number("Offset X", "x", M.textRanges.x, "px")
            controls.y = Number("Offset Y", "y", M.textRanges.y, "px")
        end
        if kind.power then When(function() return ui.db().showPower end, Group) else Group() end
    end
    -- A text clicked in the preview opens the tile of the kind in that spot.
    page.refreshers[#page.refreshers + 1] = function()
        local slots = Slots()
        for _, slot in ipairs(M.textSlots) do
            local kind = contentKind[slots[slot].content]
            page.jumpTargets["text:" .. slot] = page.jumpTargets["text:kind:" .. (kind and kind.id or "name")]
        end
    end
end

-- A custom color row for the spot `spot()` returns: a swatch that opens the
-- color picker; shown while `shown()` is true.
function M:TextColorSwatch(ui, spot, shown)
    local page = ui.page
    local host = page:Row("Custom Color")
    host.row.visibleWhen = shown
    local swatch = W.Button(host, "", 64, 22, "dropdown")
    swatch:SetPoint("LEFT", 0, 0)
    swatch.sample = swatch:CreateTexture(nil, "OVERLAY")
    addon.Style.ApplyAsset(swatch.sample, "Solid")
    swatch.sample:SetPoint("TOPLEFT", 3, -3); swatch.sample:SetPoint("BOTTOMRIGHT", -3, 3)
    local function Current() local slot = spot(); return slot and ui.db().texts[slot] end
    swatch:SetScript("OnClick", function()
        local slot, s = spot(), Current()
        if not slot or not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local unit, before = ui.Editing(), { colorMode = s.colorMode, color = Copy(s.color) }
        local apply, flush = W.Throttle(function(rgb) M:SetTextOptions(unit, slot, { colorMode = "custom", color = rgb }) end)
        ColorPickerFrame:SetupColorPickerAndShow({ r = s.color[1], g = s.color[2], b = s.color[3],
            swatchFunc = function() local r, g, b = ColorPickerFrame:GetColorRGB(); apply({ r, g, b }) end,
            cancelFunc = function() flush(); M:SetTextOptions(unit, slot, before) end })
    end)
    page.refreshers[#page.refreshers + 1] = function()
        local s = Current()
        if s then addon.Style.Paint(swatch.sample, s.color) end
    end
    return swatch
end

-- General text settings: the font, name colors, health text color, then the
-- tiles for each kind of text.
function M:BuildTextTab(ui)
    local page, When = ui.page, ui.When
    ui.Tab("Text", function()
        page:Group("Font")
        local _, refresh = W.FontDropdown(page:Row("Font"), ui.owner); page.refreshers[#page.refreshers + 1] = refresh
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
        page:Group("Colors")
        ui.Choice("Name Color", "nameColorMode")
        When(function() return ui.db().nameColorMode == "custom" end, function() ui.Color("Custom Name Color", "nameColor") end)
        -- Health texts: by health (Rosewood low, Ivory, Celadon full) or the Text Color.
        ui.Choice("Health Text Color", "healthTextColor")
        -- Text glow (Style.TextHalo): each kind on its own, with its color and strength.
        page:Group("Glow")
        ui.Toggles({ { "Health Text Glow", "healthTextGlow" }, { "Name Text Glow", "nameTextGlow" } })
        When(function() return ui.db().healthTextGlow end, function()
            ui.Choice("Health Glow Color", "healthTextGlowColor"); ui.Slider("Health Glow Strength", "healthTextGlowStrength", "%")
        end)
        When(function() return ui.db().nameTextGlow end, function()
            ui.Choice("Name Glow Color", "nameTextGlowColor"); ui.Slider("Name Glow Strength", "nameTextGlowStrength", "%")
        end)
        page:Group("Colors")
        -- Pastel: class-colored names, class health and the class ring all use it.
        ui.Slider("Class Color Softness", "classSoftness", "%")
        M:BuildTextKinds(ui)
    end)
end

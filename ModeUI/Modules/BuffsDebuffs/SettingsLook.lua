local _, addon = ...
local M, W, L = addon.BuffsDebuffs, addon.ConfigWidgets, addon.L
if not M then return end

-- The Look tab: the icons (width and height, spacing, zoom) the border
-- (style, metal or a custom color, size, padding, shift and offsets, rims by
-- type) and the glow, for the bar picked at the top (owner, November 17
-- and 18, 2026). The texts have their own tab (SettingsText.lua).
local function Bar() return M.db.bars[M:EditingBar()] end
local function Set(key) return function(value) M:SetBarOption(M:EditingBar(), key, value) end end
local function Toggle(label, key) return { label = label, get = function() return Bar()[key] end, set = Set(key) } end

-- Color rows read and write the bar being edited.
local function BarOwner()
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return Bar()[key] end }) } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetBarOption(M:EditingBar(), key, value) end
    return owner
end

M.BarOwner = BarOwner

-- An offset pair as two sliders and 1px nudge arrows.
function M.Offsets(page, c, keyX, keyY, titles)
    local cells = c.Columns(titles or { "Offset X", "Offset Y" })
    c.SliderIn(cells[1], M.ranges[keyX], function() return Bar()[keyX] end, Set(keyX), "px")
    c.SliderIn(cells[2], M.ranges[keyY], function() return Bar()[keyY] end, Set(keyY), "px")
    return W.Nudge(page:Row(L["Nudge"], 40), function() return Bar()[keyX] end, function() return Bar()[keyY] end,
        Set(keyX), Set(keyY), M.ranges[keyX])
end

function M:BuildLookTab(page, c)
    page:Section(L["Look"], nil, false)
    page:Group(L["Bar"])
    page.lookBarSelect = self:BuildBarPicker(page, c)

    page:Group(L["Icons"])
    local size = c.Columns({ "Icon Width", "Icon Height" })
    page.widthSlider = c.SliderIn(size[1], M.ranges.width, function() return Bar().width end, Set("width"), "px")
    page.heightSlider = c.SliderIn(size[2], M.ranges.height, function() return Bar().height end, Set("height"), "px")
    c.Note("Height starts 4px shorter than the width, 6px from 36 wide, and follows the width until you change it.", 32)
    local fit = c.Columns({ "Spacing", "Icon Zoom" })
    page.spacingSlider = c.SliderIn(fit[1], M.ranges.spacing, function() return Bar().spacing end, Set("spacing"), "px")
    page.cropSlider = c.SliderIn(fit[2], M.ranges.crop, function() return Bar().crop end, Set("crop"), "%")
    page.iconToggles = c.Toggles({ Toggle("Timer Swipe", "swipe"), Toggle("Tooltips", "tooltip") })
    -- Right-click cancel: buff bars, not a preset that has none (Defensives).
    c.When(function()
        local preset = M:Preset(M:EditingBar())
        return Bar().kind == "buffs" and not (preset and preset.cancel ~= nil)
    end, function()
        page.cancelToggles = c.Toggles({ Toggle("Right-Click Cancels", "cancel") })
    end)

    -- Every bar's edge (docs/DESIGN_LANGUAGE.md, "Choosing a border").
    page:Group(L["Border"])
    page.borderStyleSelect, page.borderMetalSelect = W.BorderPickers(page,
        { get = function() return Bar().edgeStyle end, set = Set("edgeStyle") },
        { get = function() return Bar().edgeMetal end, set = Set("edgeMetal") })
    -- The Mode art comes in a 1 and a 2px band.
    local band = c.Columns({ "Border Size", "Border Padding" })
    page.borderSizeSlider = c.SliderIn(band[1], M.ranges.borderSize, function() return Bar().borderSize end, Set("borderSize"), "px")
    page.borderGapSlider = c.SliderIn(band[2], M.ranges.borderGap, function() return Bar().borderGap end, Set("borderGap"), "px")
    local shift = c.Columns({ "Border Shift" })
    page.borderShiftSlider = c.SliderIn(shift[1], M.ranges.borderShift, function() return Bar().borderShift end, Set("borderShift"), "px")
    c.Note("Border Shift pushes the border out from the icon (+) or in over it (-); the offsets move it.", 32)
    page.borderNudge = M.Offsets(page, c, "borderX", "borderY", { "Border Offset X", "Border Offset Y" })
    page.borderTintToggles = c.Toggles({ Toggle("Custom Border Color", "borderTint") })
    c.When(function() return Bar().borderTint end, function()
        W.ColorRow(page, BarOwner(), L["Border Color"], "borderColor")
    end)
    c.When(function() return Bar().kind == "debuffs" end, function()
        page.typeToggles = c.Toggles({ Toggle("Rim Colored by Debuff Type", "byType") })
    end)

    page:Group(L["Glow"])
    page.glowPills = c.Pills("Glow", M.choices.glow, function() return Bar().glow end, Set("glow"), 80)
    c.When(function() return Bar().glow ~= "none" end, function()
        c.When(function() return Bar().kind == "debuffs" end, function()
            page.glowColorPills = c.Pills("Glow Color", M.choices.glowColor, function() return Bar().glowColor end, Set("glowColor"), 130)
        end)
        c.When(function() return Bar().glowColor == "custom" or Bar().kind == "buffs" end, function()
            W.ColorRow(page, BarOwner(), L["Custom Color"], "glowCustomColor")
        end)
    end)
end

-- The Module tab's text: every bar's font, outline and shadow.
function M:BuildTextGroup(page, c)
    page:Group(L["Text"])
    local owner = self:TextOwner()
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); c.Refresh(fontRefresh)
    page.outlinePills = c.Pills("Outline", M.choices.outline, function() return M.db.outline end,
        function(value) M:SetOption("outline", value) end, 90)
    page.textToggles = c.Toggles({ { label = "Shadow", get = function() return M.db.shadow end,
        set = function(value) M:SetOption("shadow", value) end } })
end

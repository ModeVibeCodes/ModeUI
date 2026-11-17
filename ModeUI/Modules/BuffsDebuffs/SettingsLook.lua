local _, addon = ...
local M, W, L = addon.BuffsDebuffs, addon.ConfigWidgets, addon.L
if not M then return end

-- The Look tab: the icons (width and height, spacing, zoom), the border
-- (style, metal, size, gap, rims by type), the time text and the stack count
-- (each where it sits, its size, color and offset with 1px nudges) and the
-- glow, for the bar picked at the top (owner, November 17, 2026: text and
-- border options on every bar).
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

local POINT_LABELS = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", CENTER = "Center",
    RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }

-- An offset pair as two sliders and 1px nudge arrows.
local function Offsets(page, c, keyX, keyY)
    local cells = c.Columns({ "Offset X", "Offset Y" })
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
    c.When(function() return Bar().kind == "buffs" end, function()
        page.cancelToggles = c.Toggles({ Toggle("Right-Click Cancels", "cancel") })
    end)

    -- Every bar's edge (docs/DESIGN_LANGUAGE.md, "Choosing a border").
    page:Group(L["Border"])
    page.borderStyleSelect, page.borderMetalSelect = W.BorderPickers(page,
        { get = function() return Bar().edgeStyle end, set = Set("edgeStyle") },
        { get = function() return Bar().edgeMetal end, set = Set("edgeMetal") })
    page.borderSizePills = c.Pills("Border Size", { { id = 1, label = "1px" }, { id = 2, label = "2px" } },
        function() return Bar().borderSize end, Set("borderSize"), 70)
    local gap = c.Columns({ "Border Gap" })
    page.borderGapSlider = c.SliderIn(gap[1], M.ranges.borderGap, function() return Bar().borderGap end, Set("borderGap"), "px")
    c.When(function() return Bar().kind == "debuffs" end, function()
        page.typeToggles = c.Toggles({ Toggle("Rim Colored by Debuff Type", "byType") })
    end)

    page:Group(L["Time Text"])
    page.timerPills = c.Pills("Time Text", M.choices.timer, function() return Bar().timer end, Set("timer"), 84)
    c.When(function() return Bar().timer ~= "none" end, function()
        local look = c.Columns({ "Size" })
        page.timerSizeSlider = c.SliderIn(look[1], M.ranges.timerSize, function() return Bar().timerSize end, Set("timerSize"))
        W.ColorRow(page, BarOwner(), L["Color"], "timerColor")
        page.timerNudge = Offsets(page, c, "timerX", "timerY")
    end)

    page:Group(L["Stack Count"])
    page.countToggles = c.Toggles({ Toggle("Show Stack Count", "count") })
    c.When(function() return Bar().count end, function()
        local labels = setmetatable({}, { __index = function(_, key) return L[POINT_LABELS[key] or key] end })
        local buttons, refresh = W.AnchorPicker(page:Row(L["Corner"], W.ANCHOR_PICKER_HEIGHT + 16),
            function() return Bar().countPoint end, Set("countPoint"), labels, { center = true })
        c.Refresh(refresh); page.countCorner = buttons
        local look = c.Columns({ "Size" })
        page.countSizeSlider = c.SliderIn(look[1], M.ranges.countSize, function() return Bar().countSize end, Set("countSize"))
        W.ColorRow(page, BarOwner(), L["Color"], "countColor")
        page.countNudge = Offsets(page, c, "countX", "countY")
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

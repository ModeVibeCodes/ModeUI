local _, addon = ...
local M, W, L = addon.BuffsDebuffs, addon.ConfigWidgets, addon.L
if not M then return end

-- Auras › Icons (zoom, swipe), the Border tab (style, metal, size, padding,
-- the fine-tune knobs and a custom color, rims by type), Glow and Behavior
-- (tooltips, right-click cancel) for the bar picked above the tabs (owner,
-- November 17 and 18, 2026), and Text › Text Style. The texts' own cards are
-- in SettingsText.lua.
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

-- Padding (owner-approved, November 21, 2026): one slider from -4 to 4 over
-- the saved borderGap (0..4: the art inside the band) and borderShift (below
-- zero: the border in over the icon). A positive borderShift (Push Out) and
-- the offsets sit behind Fine-Tune Border; nothing saved changes.
M.PADDING_RANGE = { -4, 4, 1 }
function M:BorderPadding(id)
    local bar = self.db.bars[id]
    return bar.borderShift < 0 and bar.borderShift or bar.borderGap
end
function M:SetBorderPadding(id, value)
    if value < 0 then
        if self.db.bars[id].borderGap ~= 0 and not self:SetBarOption(id, "borderGap", 0) then return false end
        return self:SetBarOption(id, "borderShift", value)
    end
    if not self:SetBarOption(id, "borderGap", value) then return false end
    if self.db.bars[id].borderShift < 0 then return self:SetBarOption(id, "borderShift", 0) end
    return true
end
-- A border pushed out or moved shows its knobs whether Fine-Tune is on or not.
local function FineTuned() local bar = Bar(); return bar.borderShift > 0 or bar.borderX ~= 0 or bar.borderY ~= 0 end

local function BuildBorder(page, c)
    page:Tab("Border")
    -- Every bar's edge (docs/DESIGN_LANGUAGE.md, "Choosing a border").
    page:Group(L["Border"])
    page.borderStyleSelect, page.borderMetalSelect = W.BorderPickers(page,
        { get = function() return Bar().edgeStyle end, set = Set("edgeStyle") },
        { get = function() return Bar().edgeMetal end, set = Set("edgeMetal") })
    -- The Mode art comes in a 1 and a 2px band.
    local band = c.Columns({ "Border Size", "Padding" })
    page.borderSizeSlider = c.SliderIn(band[1], M.ranges.borderSize, function() return Bar().borderSize end, Set("borderSize"), "px")
    page.paddingSlider = c.SliderIn(band[2], M.PADDING_RANGE, function() return M:BorderPadding(M:EditingBar()) end,
        function(value) M:SetBorderPadding(M:EditingBar(), value) end, "px")
    c.Note("Below zero, Padding lays the border in over the icon.", 32)
    page.fineTuneToggles = c.Toggles({ { label = "Fine-Tune Border", get = function() return page.fineTuneBorder == true or FineTuned() end,
        set = function(on) page.fineTuneBorder = on or nil; page:Refresh(); page:Layout() end } })
    c.When(function() return page.fineTuneBorder == true or FineTuned() end, function()
        page.pushOutSlider = c.SliderIn(c.Columns({ "Push Out" })[1], { 0, M.ranges.borderShift[2], 1 },
            function() return math.max(0, Bar().borderShift) end,
            function(value)
                -- Zero leaves an inward Padding alone.
                if value == 0 and Bar().borderShift <= 0 then return end
                M:SetBarOption(M:EditingBar(), "borderShift", value)
            end, "px")
        page.borderNudge = M.Offsets(page, c, "borderX", "borderY", { "Border Offset X", "Border Offset Y" })
    end)
    page.borderTintToggles = c.Toggles({ Toggle("Custom Border Color", "borderTint") })
    c.When(function() return Bar().borderTint end, function()
        W.ColorRow(page, BarOwner(), L["Border Color"], "borderColor")
    end)
    c.When(function() return Bar().kind == "debuffs" end, function()
        page:Group(L["Rims"])
        page.typeToggles = c.Toggles({ Toggle("Rim Colored by Debuff Type", "byType") })
    end)
end

function M:BuildLookTab(page, c)
    page:Tab("Auras")
    page:Group(L["Icons"])
    page.cropSlider = c.SliderIn(c.Columns({ "Icon Zoom" })[1], M.ranges.crop, function() return Bar().crop end, Set("crop"), "%")
    page.iconToggles = c.Toggles({ Toggle("Timer Swipe", "swipe") })

    BuildBorder(page, c)

    page:Tab("Glow")
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

    page:Tab("Behavior")
    page:Group(L["Tooltips and Clicks"])
    page.behaviorToggles = c.Toggles({ Toggle("Tooltips", "tooltip") })
    -- Right-click cancel: buff bars, not a preset that has none (Defensives).
    c.When(function()
        local preset = M:Preset(M:EditingBar())
        return Bar().kind == "buffs" and not (preset and preset.cancel ~= nil)
    end, function()
        page.cancelToggles = c.Toggles({ Toggle("Right-Click Cancels", "cancel") })
    end)
end

-- Text › Text Style: every bar's font, outline and shadow.
function M:BuildTextGroup(page, c)
    page:Group(L["Text Style"])
    local owner = self:TextOwner()
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); c.Refresh(fontRefresh)
    page.outlinePills = c.Pills("Outline", M.choices.outline, function() return M.db.outline end,
        function(value) M:SetOption("outline", value) end, 90)
    page.textToggles = c.Toggles({ { label = "Shadow", get = function() return M.db.shadow end,
        set = function(value) M:SetOption("shadow", value) end } })
end

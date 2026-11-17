local _, addon = ...
local M, W, L = addon.BuffsDebuffs, addon.ConfigWidgets, addon.L
if not M then return end

-- The Bars tab (which bar, what it shows, how it fills) and the Look tab
-- (icons, time text, border, glow). Both edit the bar picked at their top.
local function Bar() return M.db.bars[M:EditingBar()] end
local function Set(key) return function(value) M:SetBarOption(M:EditingBar(), key, value) end end
local function Toggle(label, key) return { label = label, get = function() return Bar()[key] end, set = Set(key) } end

function M:BuildBarsTab(page, c)
    page:Section(L["Bars"], nil, false)
    page:Group(L["Bar"])
    page.barSelect = self:BuildBarPicker(page, c)
    page.barNote = c.Note(function() return M:BarNote() end, 48)
    page.showToggles = c.Toggles({ Toggle("Show This Bar", "show") })
    c.When(function() return M:Custom(M:EditingBar()) ~= nil end, function()
        page.kindPills = c.Pills("Shows", M.choices.kind, function() return Bar().kind end, Set("kind"), 110)
    end)

    page:Group(L["Which Auras"])
    c.Note("Any kind you pick shows, in this order; an aura shows once. All stands alone. Your own debuffs can't be hidden by spell, so a boss debuff with a type may show under both.", 64)
    page.categoryGrids = {}
    for kind, list in pairs(M.categories) do
        c.When(function() return Bar().kind == kind end, function()
            local items = {}
            for _, category in ipairs(list) do
                items[#items + 1] = { label = L[category.label], get = function() return Bar().cats[category.id] == true end,
                    set = function(on) M:SetCategory(M:EditingBar(), category.id, on) end }
            end
            page.categoryGrids[kind] = page:ChoiceGrid(items)
        end)
    end
    page.sortPills = c.Pills("Sort", M.choices.sort, function() return Bar().sort end, Set("sort"), 110)
    local count = c.Columns({ "Max Shown", "Per Row" })
    page.maxSlider = c.SliderIn(count[1], M.ranges.max, function() return Bar().max end, Set("max"))
    page.perRowSlider = c.SliderIn(count[2], M.ranges.perRow, function() return Bar().perRow end, Set("perRow"))

    page:Group(L["Growth"])
    page.growPills = c.Pills("Grow", M.choices.grow, function() return Bar().grow end, Set("grow"), 80)
    -- New rows go across the way the icons grow.
    for _, across in ipairs({ true, false }) do
        local choices = M.WrapChoices(across and "left" or "up")
        c.When(function() return (M.HORIZONTAL[Bar().grow] == true) == across end, function()
            page[across and "rowPills" or "columnPills"] = c.Pills("New Rows Go", choices, function() return Bar().wrap end, Set("wrap"), 80)
        end)
    end
end

-- Owner for the glow color row: the bar being edited.
local function GlowOwner()
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return Bar()[key] end }) } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetBarOption(M:EditingBar(), key, value) end
    return owner
end

function M:BuildLookTab(page, c)
    page:Section(L["Look"], nil, false)
    page:Group(L["Bar"])
    page.lookBarSelect = self:BuildBarPicker(page, c)

    page:Group(L["Icons"])
    local size = c.Columns({ "Icon Width", "Spacing" })
    page.widthSlider = c.SliderIn(size[1], M.ranges.width, function() return Bar().width end, Set("width"), "px")
    page.spacingSlider = c.SliderIn(size[2], M.ranges.spacing, function() return Bar().spacing end, Set("spacing"), "px")
    page.sizeNote = c.Note(function()
        local width = Bar().width
        return string.format(L["Icons are %d x %d: always 6px shorter than wide."], width, math.max(1, width - 6))
    end, 32)
    page.timerPills = c.Pills("Time Text", M.choices.timer, function() return Bar().timer end, Set("timer"), 90)
    page.iconToggles = c.Toggles({ Toggle("Timer Swipe", "swipe"), Toggle("Stack Count", "count"), Toggle("Tooltips", "tooltip") })
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
            W.ColorRow(page, GlowOwner(), L["Custom Color"], "glowCustomColor")
        end)
    end)
end

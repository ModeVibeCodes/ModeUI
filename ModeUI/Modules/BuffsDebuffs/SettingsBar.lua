local _, addon = ...
local M, W, L = addon.BuffsDebuffs, addon.ConfigWidgets, addon.L
if not M then return end

-- The Bars tab: which bar, what it shows, how it fills. The Look tab is in
-- SettingsLook.lua; both edit the bar picked at their top.
local function Bar() return M.db.bars[M:EditingBar()] end
local function Set(key) return function(value) M:SetBarOption(M:EditingBar(), key, value) end end
local function Toggle(label, key) return { label = label, get = function() return Bar()[key] end, set = Set(key) } end

function M:BuildBarsTab(page, c)
    page:Section(L["Bars"], nil, false)
    page:Group(L["Bar"])
    local select, add, delete = self:BuildBarPicker(page, c)
    page.barSelect = select
    function page.barSelectParts() return select, add, delete end
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

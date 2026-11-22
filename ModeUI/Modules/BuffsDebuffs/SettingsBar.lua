local _, addon = ...
local M, W, T, L = addon.BuffsDebuffs, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- General (whether the bar shows and what kind, its icons' size, and how it
-- arranges: sort, how many, how it grows, spacing; owner, November 18, 2026)
-- and Auras › Which Auras and Spells You Add (a buff bar's own list). Which
-- Auras sits under the live preview in the window's preview pane
-- (Preview.lua), here only when the window is too narrow for the pane. The
-- border, glow, icons and behavior are in SettingsLook.lua, the texts in
-- SettingsText.lua; every tab edits the bar picked above the tabs.
local function Bar() return M.db.bars[M:EditingBar()] end
local function Set(key) return function(value) M:SetBarOption(M:EditingBar(), key, value) end end
local function Toggle(label, key) return { label = label, get = function() return Bar()[key] end, set = Set(key) } end

local function WhichAuras(page, c)
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
end

-- Spells You Add: the picker in its bar mode, and how many the bar holds.
local function Spells(page, c)
    page:Group(L["Spells You Add"])
    c.Note("Buffs this bar always shows, picked from what's on you or added by spell ID: a defensive the game doesn't flag as Big or External, for example. Turn on Spells You Add under Which Auras.", 48)
    local row = page:Row(L["Your Spells"], 48)
    page.spellsButton = W.Button(row, L["+ Add or Remove Spells"], 190, 30, "secondary")
    page.spellsButton:SetPoint("LEFT")
    page.spellsButton:SetScript("OnClick", function() M:OpenPicker(page.spellsButton, M:EditingBar()) end)
    page.spellsCount = W.Label(row, "", nil, 200, -8, 220, T.muted)
    c.Refresh(function()
        local bar = Bar()
        local n = #bar.spells
        local text = n == 0 and L["None added"] or string.format(L["%d added"], n)
        if n > 0 and not bar.cats.tracked then text = text .. " · " .. L["Spells You Add is off"] end
        page.spellsCount:SetText(text)
    end)
end

function M:BuildBarsTab(page, c)
    page:Tab("General")
    page:Group(L["Show"])
    page.barNote = c.Note(function() return M:BarNote() end, 48)
    page.showToggles = c.Toggles({ Toggle("Show This Bar", "show") })
    c.When(function() return M:KindChangeable(M:EditingBar()) end, function()
        page.kindPills = c.Pills("Shows", M.choices.kind, function() return Bar().kind end, Set("kind"), 110)
    end)

    page:Group(L["Size"])
    local size = c.Columns({ "Icon Width", "Icon Height" })
    page.widthSlider = c.SliderIn(size[1], M.ranges.width, function() return Bar().width end, Set("width"), "px")
    page.heightSlider = c.SliderIn(size[2], M.ranges.height, function() return Bar().height end, Set("height"), "px")
    c.Note("Height starts 4px shorter than the width, 6px from 36 wide, and follows the width until you change it.", 32)

    page:Group(L["Arrange"])
    page.sortPills = c.Pills("Sort", M.choices.sort, function() return Bar().sort end, Set("sort"), 110)
    local count = c.Columns({ "Max Shown", "Per Row" })
    page.maxSlider = c.SliderIn(count[1], M.ranges.max, function() return Bar().max end, Set("max"))
    page.perRowSlider = c.SliderIn(count[2], M.ranges.perRow, function() return Bar().perRow end, Set("perRow"))
    page.growPills = c.Pills("Grow", M.choices.grow, function() return Bar().grow end, Set("grow"), 80)
    -- New rows go across the way the icons grow.
    for _, across in ipairs({ true, false }) do
        local choices = M.WrapChoices(across and "left" or "up")
        c.When(function() return (M.HORIZONTAL[Bar().grow] == true) == across end, function()
            page[across and "rowPills" or "columnPills"] = c.Pills("New Rows Go", choices, function() return Bar().wrap end, Set("wrap"), 80)
        end)
    end
    page.spacingSlider = c.SliderIn(c.Columns({ "Spacing" })[1], M.ranges.spacing, function() return Bar().spacing end, Set("spacing"), "px")
    c.Note("Move a bar in Edit Mode (in the window header): drag it, nudge it, or pick Anchor To. Changes wait until you leave combat.", 48)

    page:Tab("Auras")
    c.When(function() return not page.previewSplit end, function() WhichAuras(page, c) end)
    c.When(function() return Bar().kind == "buffs" end, function() Spells(page, c) end)
end

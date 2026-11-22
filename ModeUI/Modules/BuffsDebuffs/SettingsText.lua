local _, addon = ...
local M, W, L = addon.BuffsDebuffs, addon.ConfigWidgets, addon.L
if not M then return end

-- The Text tab (owner, November 18, 2026): Text Style (the font, outline and
-- shadow every bar shares, SettingsLook.lua), then a card per text of the bar
-- picked above the tabs: Time Text (where it sits, size, color, offsets) and
-- Stack Count (shown, corner, size, color, offsets). In the Time Text card's
-- top right a sample aura at the size it shows in game, one fixed icon with
-- both texts, follows every change.
local Kit = addon.Kit
local function Bar() return M.db.bars[M:EditingBar()] end
local function Set(key) return function(value) M:SetBarOption(M:EditingBar(), key, value) end end
local function Toggle(label, key) return { label = label, get = function() return Bar()[key] end, set = Set(key) } end

local POINT_LABELS = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", CENTER = "Center",
    RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }
local SAMPLE = { icon = "Spell_Nature_Rejuvenation", time = "12", count = "3" }
local INSET = 12 -- the card's padding

-- The sample: drawn at UIParent's scale (the bars' own), so it's as big as
-- the bar's icons in game.
local function BuildSample(page, card)
    local host = CreateFrame("Frame", nil, card.frame)
    host:SetFrameLevel(card.frame:GetFrameLevel() + 4)
    local icon = M:SampleIcon(host)
    page.textSample = { host = host, icon = icon }
    return function()
        local bar = Bar()
        local scale = UIParent:GetEffectiveScale() / card.frame:GetEffectiveScale()
        if not addon.IsNumber(scale, 0.05, 20) then scale = 1 end
        host:SetScale(scale)
        local px = Kit.PixelSize(host)
        local width, height = M:CellSize(bar, px)
        host:SetSize(width, height)
        host:ClearAllPoints(); host:SetPoint("TOPRIGHT", card.frame, "TOPRIGHT", -INSET / scale, -INSET / scale)
        M:PaintSample(icon, bar, px, SAMPLE)
        local point = M:IconPoint(bar)
        icon:ClearAllPoints(); icon:SetPoint(point, host, point, 0, 0)
        icon:Show()
    end
end


function M:BuildTextsTab(page, c)
    page:Tab("Text")
    self:BuildTextGroup(page, c)

    page:Group(L["Time Text"])
    c.Refresh(BuildSample(page, page:ActiveCard()))
    page.timerPills = c.Pills("Place", M.choices.timer, function() return Bar().timer end, Set("timer"), 84)
    c.When(function() return Bar().timer ~= "none" end, function()
        local look = c.Columns({ "Size" })
        page.timerSizeSlider = c.SliderIn(look[1], M.ranges.timerSize, function() return Bar().timerSize end, Set("timerSize"))
        W.ColorRow(page, M.BarOwner(), L["Color"], "timerColor")
        page.timerNudge = M.Offsets(page, c, "timerX", "timerY")
    end)

    page:Group(L["Stack Count"])
    page.countToggles = c.Toggles({ Toggle("Show Stack Count", "count") })
    c.When(function() return Bar().count end, function()
        local labels = setmetatable({}, { __index = function(_, key) return L[POINT_LABELS[key] or key] end })
        local buttons, refresh = W.AnchorPicker(page:Row(L["Anchor"], W.ANCHOR_PICKER_HEIGHT + 16),
            function() return Bar().countPoint end, Set("countPoint"), labels, { center = true })
        c.Refresh(refresh); page.countCorner = buttons
        local look = c.Columns({ "Size" })
        page.countSizeSlider = c.SliderIn(look[1], M.ranges.countSize, function() return Bar().countSize end, Set("countSize"))
        W.ColorRow(page, M.BarOwner(), L["Color"], "countColor")
        page.countNudge = M.Offsets(page, c, "countX", "countY")
    end)
end

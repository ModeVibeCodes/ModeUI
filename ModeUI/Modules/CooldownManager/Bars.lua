local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Tracked Bars: each item is an icon beside a status bar. The icon gets the
-- Mode slot (a square as tall as the bar) on the Icon Side; the bar sits in a
-- box of its own beside it, a border around a background (Bar Background at
-- Background Opacity) and the fill in Bar Texture and Bar Color, Mode
-- Gradient by default. Blizzard's bar art (its background and the spark) is
-- faded. Blizzard still fills the bar and writes the name and time left; its
-- Bar Content (icon and name, icon only, name only) still applies: with the
-- icon hidden the bar takes the whole width.
local Kit = addon.Kit
local GAP = 2 -- physical pixels between the icon and the bar

local function Fade(region, shown) if region and region.SetAlpha then region:SetAlpha(shown and 1 or 0) end end

-- Kit's bar painters take a table with the bar's methods and its sheen and
-- background textures; ModeUI's textures live in its own state, not on
-- Blizzard's bar.
local function Painter(bar, state)
    return { sheen = state.sheen, bg = state.bg,
        SetStatusBarTexture = function(_, path) bar:SetStatusBarTexture(path) end,
        GetStatusBarTexture = function() return bar:GetStatusBarTexture() end }
end

function M:SkinBar(item, style, g, state)
    local iconFrame, bar = item.Icon, item.Bar
    if not iconFrame or not bar then return end
    if not state.stripped then
        state.stripped = true
        self.StripArt(iconFrame, iconFrame.Icon)
        state.art = Kit.SlotArt(iconFrame)
        -- The bar's box: border and background, under Blizzard's bar.
        state.box = CreateFrame("Frame", nil, item)
        state.rim = Kit.Rim(state.box, "BORDER")
        state.bg = state.box:CreateTexture(nil, "BACKGROUND", nil, -8)
        -- Mode Gradient's sheen: over the fill (ARTWORK 0), under the texts.
        state.sheen = bar:CreateTexture(nil, "ARTWORK", nil, 7)
    end
    item:SetSize(g.w, g.h)
    -- The icon: a square as tall as the bar, in the Mode slot.
    local ig = { w = g.h, h = g.h, px = g.px, border = g.border, inset = g.inset }
    iconFrame:SetSize(g.h, g.h)
    Kit.PaintSlotArt(state.art, iconFrame, style, ig)
    if iconFrame.Icon then Kit.Inset(iconFrame.Icon, iconFrame, g.inset); Kit.CropIcon(iconFrame.Icon, ig) end
    Fade(item.DebuffBorder, style.debuffBorder)
    Fade(bar.BarBG, false)
    Fade(bar.Pip, style.showSpark)
    self:LayoutBarParts(item)
    -- The box: the slot's border and the bar's background inside it.
    local box, t = state.box, g.border
    local cut = (style.border == "rounded") and g.px or 0
    Kit.PlaceRim(state.rim, box, t, cut, style.borderColor, 1)
    Kit.Inset(state.bg, box, t)
    Kit.BarBackground({ bg = state.bg }, style.barBackground, g.w, g.h, g.px)
    Kit.Tint(state.bg, Kit.BarBackgroundColor(style.barBackground), style.barBackgroundOpacity / 100)
    -- The fill, inside the border.
    local inner = math.max(g.px, g.h - 2 * t)
    Kit.BarForeground(Painter(bar, state), style.barTexture, inner, g.px)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill and fill.ClearTextureSlice then fill:ClearTextureSlice() end
    if bar.SetStatusBarColor then
        local c = style.barColor
        bar:SetStatusBarColor(c[1], c[2], c[3], 1)
    end
    state.sheen:ClearAllPoints()
    state.sheen:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    state.sheen:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
end

-- Places the icon on its side and the bar box beside it (or over the whole
-- width while Blizzard hides the icon), the bar inside the box's border.
-- Blizzard's Bar Content re-anchors the bar; this runs after it.
function M:LayoutBarParts(item)
    local state = self.dress[item]
    local style = state and self.db[state.viewer]
    local iconFrame, bar = item.Icon, item.Bar
    if not style or not state.box or not iconFrame or not bar then return end
    local g = state.g
    local right = style.iconSide == "right"
    local side = right and "RIGHT" or "LEFT"
    iconFrame:ClearAllPoints()
    iconFrame:SetPoint(side, item, side, 0, 0)
    local shown = iconFrame:IsShown()
    local withIcon = not addon.IsPublic(shown) or shown == true
    local room = withIcon and (g.h + GAP * g.px) or 0
    local box = state.box
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", item, "TOPLEFT", right and 0 or room, 0)
    box:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", right and -room or 0, 0)
    box:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", box, "TOPLEFT", g.border, -g.border)
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -g.border, g.border)
end

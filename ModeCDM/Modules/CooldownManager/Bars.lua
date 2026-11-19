local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Tracked Bars (docs/DESIGN_LANGUAGE.md, "Cooldown icons"): each item is an
-- icon beside a timer bar. The icon, wider than tall like every Mode icon
-- (4px wider than the bar is tall; 6px from 36px), takes the Mode Button
-- face and the `frameThin` edge on the Icon Side; the bar sits in a box of
-- its own beside it, in the same edge: Bar Background (Mode BG on Slate) at
-- Background Opacity, the fill in Bar Texture (Mode Gradient: its base and
-- white lift) in your class color or Bar Color, and the Comet spark.
-- Blizzard's bar art (its background and its own spark) is faded. Blizzard
-- still fills the bar and writes the name and time left; its Bar Content
-- (icon and name, icon only, name only) still applies: with the icon hidden
-- the bar takes the whole width.
local Kit, Style = addon.Kit, addon.Style
local GAP = 2 -- physical pixels between the icon's edge and the bar's

local function Fade(region, shown) if region and region.SetAlpha then region:SetAlpha(shown and 1 or 0) end end

-- The icon's width for a bar `h` tall: 4px wider (6px from 36px).
function M.BarIconWidth(h, px)
    local w = h + 4 * px
    if w >= 36 * px then w = h + 6 * px end
    return w
end

-- Kit's bar painters take a table with the bar's methods and its sheen and
-- background textures; ModeUI's textures live in its own state, not on
-- Blizzard's bar.
local function Painter(bar, state)
    return { sheen = state.sheen, bg = state.bg,
        SetStatusBarTexture = function(_, path) addon.Style.SetBarTexture(bar, path) end,
        GetStatusBarTexture = function() return bar:GetStatusBarTexture() end }
end

-- The fill color: your class color (Class Color), else Bar Color.
function M:BarFill(style)
    local class = style.barColorMode == "class" and addon.Domain.UnitColor.PlayerClass("player")
    if class and addon.IsNumber(class.r, 0, 1) and addon.IsNumber(class.g, 0, 1) and addon.IsNumber(class.b, 0, 1) then
        return { class.r, class.g, class.b }
    end
    return style.barColor
end

function M:SkinBar(item, style, g, state)
    local iconFrame, bar = item.Icon, item.Bar
    if not iconFrame or not bar then return end
    if not state.stripped then
        state.stripped = true
        self.StripArt(iconFrame, iconFrame.Icon)
        state.art = self.IconArt(iconFrame)
        -- The bar's box: its edge and background, under Blizzard's bar.
        state.box = CreateFrame("Frame", nil, item)
        state.boxEdge = Style.Edge(state.box, M.EDGE, { pieces = true })
        state.bg = state.box:CreateTexture(nil, "BACKGROUND", nil, -8)
        -- Mode Gradient's lift: over the fill (ARTWORK 0), under the texts.
        state.sheen = bar:CreateTexture(nil, "ARTWORK", nil, 7)
        state.comet = Style.Comet(bar)
    end
    item:SetSize(g.w, g.h)
    local iw = M.BarIconWidth(g.h, g.px)
    iconFrame:SetSize(iw, g.h)
    self.PaintIconArt(state.art, iconFrame, style)
    if iconFrame.Icon then
        Kit.Inset(iconFrame.Icon, iconFrame, 0)
        Kit.CropIcon(iconFrame.Icon, { w = iw, h = g.h, px = g.px, inset = 0 })
    end
    Fade(item.DebuffBorder, style.debuffBorder)
    Fade(bar.BarBG, false)
    Fade(bar.Pip, false)
    M.StyleEdge(state.boxEdge, style)
    self:LayoutBarParts(item)
    -- The background fills the box; the fill and its lift draw over it.
    Kit.Inset(state.bg, state.box, 0)
    Kit.BarBackground({ bg = state.bg }, style.barBackground, g.w, g.h, g.px)
    Kit.Tint(state.bg, Kit.BarBackgroundColor(style.barBackground), style.barBackgroundOpacity / 100)
    Kit.BarForeground(Painter(bar, state), style.barTexture, g.h, g.px)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill and fill.ClearTextureSlice then fill:ClearTextureSlice() end
    local color = self:BarFill(style)
    if bar.SetStatusBarColor then bar:SetStatusBarColor(color[1], color[2], color[3], 1) end
    state.comet:SetColor(color)
    state.comet:Layout(false, g.px)
    state.comet:SetShown(style.showSpark)
end

-- Places the icon on its side and the bar box beside it, past both edges
-- and GAP (or over the whole width while Blizzard hides the icon), the bar
-- filling the box. Blizzard's Bar Content re-anchors the bar; this runs
-- after it.
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
    local reach = style.border == "none" and 0 or g.reach or 0
    local room = withIcon and (M.BarIconWidth(g.h, g.px) + 2 * reach + GAP * g.px) or 0
    local box = state.box
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", item, "TOPLEFT", right and 0 or room, 0)
    box:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", right and -room or 0, 0)
    box:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    state.boxEdge:Layout()
end

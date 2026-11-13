local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Pixel-perfect geometry and the placement of every region of a frame face.
local ONYX = M.onyx
local Kit = addon.Kit
local FLAT = Kit.FLAT
local CIRCLE_MASK = M.CIRCLE_MASK
local Tint, Lighten = Kit.Tint, Kit.Lighten
local Inset = Kit.Inset
M.Lighten = Lighten

-- Mirrored by portrait side: the portrait caps the outer end.
local function Sides(fdb)
    if fdb.portraitSide == "right" then return "RIGHT", "LEFT", -1 end
    return "LEFT", "RIGHT", 1
end

-- Text font: Expressway (registered by Media from an installed AyijeUI or
-- EllesmereUI copy) falls back to the bundled ModeUI Lato when unavailable.
function M:FontPath(fdb) return Kit.FontPath(fdb, self.id) end

-- One physical pixel in this frame's units (Blizzard's PixelUtil factor over
-- the frame's effective scale); 1 when the client cannot report it.
function M:PixelSize(f) return Kit.PixelSize(f) end

-- The Onyx frame: a round portrait caps the outer end of one rounded bar
-- block. Pixel perfect: every size is whole physical pixels (2px slate rim,
-- 2px black gap, 1px hairline between health and power) and the frame is an
-- even number of pixels each way, so its centre anchor stays on the grid.
-- One crisp 2px border round the whole block (owner, November 13, 2026): the
-- black gap that sat inside the rim is gone (GAP 0), so the bars meet the rim.
M.RIM, M.GAP, M.HAIRLINE = 2, 0, 1
function M:Geometry(fdb, px)
    local g, p = {}, px or 1
    local function Snap(v) return math.max(p, math.floor(v / p + 0.5) * p) end
    local function Odd(v) return math.floor(v / p + 0.5) % 2 == 1 end
    g.px = p
    g.border, g.line, g.gap = self.RIM * p, self.GAP * p, self.HAIRLINE * p
    g.pad = g.border + g.line
    g.healthHeight, g.powerHeight = Snap(fdb.healthHeight), Snap(fdb.powerHeight)
    local bars = g.healthHeight + (fdb.showPower and g.gap + g.powerHeight or 0)
    g.blockHeight = bars + 2 * g.pad
    if Odd(g.blockHeight) then g.healthHeight, g.blockHeight, bars = g.healthHeight + p, g.blockHeight + p, bars + p end
    -- The portrait is Portrait Size % of the bar block's height (150: the bars
    -- are ~2/3 of it), an even pixel count so both centre on whole pixels.
    g.portrait = fdb.showPortrait and math.floor(g.blockHeight * fdb.portraitScale / 100 / (2 * p) + 0.5) * 2 * p or 0
    g.height = math.max(g.blockHeight, g.portrait)
    g.blockY = (g.height - g.blockHeight) / 2
    g.portraitY = (g.height - g.portrait) / 2
    local r = g.portrait / 2
    g.blockStart = r -- the bar block starts under the portrait's centre
    if g.portrait > 0 then
        -- Bars start where the portrait's dark inner disc crosses their top
        -- edge (less 1px), so the circle's curve meets them with no gap.
        local disc, half = r - g.border, bars / 2
        local chord = disc > half and math.sqrt(disc * disc - half * half) or 0
        g.inset = r + math.max(0, math.floor(chord / p) * p - p)
    else
        g.inset = g.pad
    end
    -- How far the portrait's inner disc reaches over the bars at their middle;
    -- text on the portrait side is pushed in by this much.
    g.tuck = g.portrait > 0 and math.max(0, r + (r - g.border) - g.inset) or 0
    g.width = g.inset + Snap(fdb.barWidth) + g.pad
    if Odd(g.width) then g.width = g.width + p end
    g.barsTop = g.blockY + g.pad
    return g
end

-- The suite's text style (see Shared/Kit/Text.lua).
M.LIFT_PIXELS, M.LIFT_ALPHA = Kit.LIFT_PIXELS, Kit.LIFT_ALPHA

function M:ApplyLayout(f, unit)
    local fdb = self:FrameDB(unit)
    -- Scale first: the pixel size depends on the frame's effective scale.
    f:SetScale(fdb.scale / 100 * (f.previewScale or 1))
    local g = self:Geometry(fdb, self:PixelSize(f))
    f.geometry = g
    local near, far, sign = Sides(fdb)
    f:SetSize(g.width, g.height)
    local panel = f.panel
    panel:ClearAllPoints()
    panel:SetPoint("TOP" .. near, f, "TOP" .. near, sign * g.blockStart, -g.blockY)
    panel:SetPoint("BOTTOM" .. far, f, "BOTTOM" .. far, 0, g.blockY)
    -- The rim on the block's edge and the black gap one rim in, straight edges
    -- on whole pixels and a half-oval far end (the near end too without a
    -- portrait); end masks round the bars inside the gap to match.
    local depth = Kit.CapDepth(g.blockHeight, g.px)
    local rounded = { [far] = true, [near] = g.portrait == 0 }
    Kit.PlaceCapRing(panel.rim, panel, 0, g.border, M.RIM_COLOR, depth, rounded)
    if g.line > 0 then Kit.PlaceCapRing(panel.gap, panel, g.border, g.line, ONYX.inner, depth, rounded)
    else Kit.HideCapRing(panel.gap) end
    -- The bars' rounded end reaches one pixel under the rim, so their edge
    -- covers the rim's soft inner curve and no faint seam shows between them.
    local maskInset = math.max(0, g.pad - g.px)
    Kit.PlaceEndMask(panel.farMask, panel, far, depth, maskInset, true)
    Kit.PlaceEndMask(panel.nearMask, panel, near, depth, maskInset, rounded[near])
    local masks = { panel.farMask, panel.nearMask }
    panel.depth = depth
    local start = g.inset - g.blockStart
    local cap = panel.cap
    cap:ClearAllPoints()
    cap:SetPoint("TOP" .. near, panel, "TOP" .. near, sign * g.pad, -g.pad)
    cap:SetPoint("BOTTOM" .. near, panel, "BOTTOM" .. near, sign * g.pad, g.pad)
    cap:SetWidth(math.max(g.px, start - g.pad)); Tint(cap, M.RIM_COLOR, 1)
    cap:SetShown(start > g.pad)
    local level = panel:GetFrameLevel()

    local h, pw = f.health, f.power
    h:ClearAllPoints()
    h:SetPoint("TOP" .. near, f, "TOP" .. near, sign * g.inset, -g.barsTop)
    h:SetPoint("TOP" .. far, f, "TOP" .. far, -sign * g.pad, -g.barsTop)
    h:SetHeight(g.healthHeight)
    pw:ClearAllPoints()
    pw:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -g.gap); pw:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", 0, -g.gap)
    pw:SetHeight(g.powerHeight); pw:SetShown(fdb.showPower)
    -- The 1px black hairline between health and power, solid like the rim.
    local line = panel.hairline
    line:SetTexture(FLAT); Tint(line, ONYX.inner, 1)
    line:ClearAllPoints(); line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, 0); line:SetPoint("BOTTOMRIGHT", pw, "TOPRIGHT", 0, 0)
    line:SetShown(fdb.showPower)
    -- Foreground (Mode Gradient by default) over the background track, which
    -- shows the world through it at Background Opacity.
    local reverse = fdb.fillDirection == "reverse"
    for _, bar in ipairs({ h, pw }) do
        bar:SetFrameLevel(level + 1)
        if bar.SetReverseFill then bar:SetReverseFill(reverse) end
        Kit.BarForeground(bar, fdb.foregroundTexture, bar == h and g.healthHeight or g.powerHeight, g.px)
        local barHeight = bar == h and g.healthHeight or g.powerHeight
        Kit.BarBackground(bar, fdb.backgroundTexture, g.width - g.inset - g.pad, barHeight, g.px)
        Tint(bar.bg, Kit.BarBackgroundColor(fdb.backgroundTexture), fdb.barBackgroundOpacity / 100)
        Kit.AddMasks({ bar:GetStatusBarTexture(), bar.bg, bar.sheen }, masks)
    end
    -- A 1px light line where the health fill ends (owner, November 13, 2026).
    Kit.FillEdge(h, fdb.fillEdge, reverse, g.px)
    Kit.AddMasks({ h.fillEdge, line }, masks)
    -- Rim over the bars, then the portrait, then text.
    panel.edge:SetFrameLevel(h:GetFrameLevel() + 1)
    f.textLayer:SetFrameLevel(h:GetFrameLevel() + 3)

    -- Round portrait above the block: full ring, black gap, dark backing, image.
    local p = f.portrait
    p:SetShown(g.portrait > 0)
    if g.portrait > 0 then
        p:ClearAllPoints(); p:SetPoint("TOP" .. near, f, "TOP" .. near, 0, -g.portraitY); p:SetSize(g.portrait, g.portrait)
        p:SetFrameLevel(h:GetFrameLevel() + 2)
        p.ring:ClearAllPoints(); p.ring:SetAllPoints(p)
        Inset(p.innerEdge, p, g.border); Tint(p.innerEdge, ONYX.inner, 1)
        Inset(p.back, p, g.pad); Tint(p.back, ONYX.track, 1)
        p.icon:ClearAllPoints(); p.icon:SetPoint("TOPLEFT", g.pad, -g.pad); p.icon:SetPoint("BOTTOMRIGHT", -g.pad, g.pad)
        if p.mask then
            p.mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            p.mask:ClearAllPoints(); p.mask:SetAllPoints(p.icon)
        end
    end
    f.textLayer:SetFrameLevel(math.max(h:GetFrameLevel(), p:GetFrameLevel()) + 2)
    self:LayoutTexts(f, unit)
    self:PaintRing(f, unit)
    if f.combo then self:ResetComboLayout(f) end
    self:LayoutCast(f, unit)
    self:LayoutAuras(f, unit)
    self:LayoutStatus(f, unit)
end

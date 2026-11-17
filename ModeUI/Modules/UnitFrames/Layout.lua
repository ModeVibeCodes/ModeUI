local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Pixel-perfect geometry and the placement of every region of a frame face.
local Kit, Style = addon.Kit, addon.Style
local Tone = Style.Tone
local Tint, Lighten = Kit.Tint, Kit.Lighten
M.Lighten = Lighten

-- Mirrored by portrait side: the portrait caps the outer end.
local function Sides(fdb)
    if fdb.portraitSide == "right" then return "RIGHT", "LEFT", -1 end
    return "LEFT", "RIGHT", 1
end

-- Text font: the Mode typeface ("Mode": Expressway when installed, else Geist) by default, or any font the player picks.
function M:FontPath(fdb) return Kit.FontPath(fdb, self.id) end

-- One physical pixel in this frame's units (Blizzard's PixelUtil factor over
-- the frame's effective scale); 1 when the client cannot report it.
function M:PixelSize(f) return Kit.PixelSize(f) end

-- The Mode frame (docs/DESIGN_LANGUAGE.md, "Unit frames"): the bar block in
-- its Mode Frame border (2px, 1px on the smaller frames) with the portrait's
-- edge-lit Steel ring centred on its portrait-side edge. Pixel perfect: every
-- size is whole physical pixels (the rim, the 1px line between health and
-- power) and the frame is an even number of pixels each way, so its centre
-- anchor stays on the grid. The frame keeps the Onyx frame's overall size, so
-- positions and attachments carry over; the bars run under the ring.
M.RIM, M.GAP, M.HAIRLINE = 2, 0, 1
function M:Geometry(fdb, px, rim)
    local g, p = {}, px or 1
    local function Snap(v) return math.max(p, math.floor(v / p + 0.5) * p) end
    local function Odd(v) return math.floor(v / p + 0.5) % 2 == 1 end
    g.px = p
    g.border, g.line, g.gap = (rim or self.RIM) * p, self.GAP * p, self.HAIRLINE * p
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
    -- The frame's width as the Onyx frame measured it (from where the ring's
    -- inner disc crossed the bars), so frames keep their size.
    local reach = g.pad
    if g.portrait > 0 then
        local disc, half = r - 2 * p, bars / 2
        local chord = disc > half and math.sqrt(disc * disc - half * half) or 0
        reach = r + math.max(0, math.floor(chord / p) * p - p)
    end
    g.width = reach + Snap(fdb.barWidth) + g.pad
    if Odd(g.width) then g.width = g.width + p end
    -- The bars start inside the block's rim, under the ring.
    g.inset = (g.portrait > 0 and r or 0) + g.pad
    -- How far the ring reaches over the bars at their middle; text on the
    -- portrait side is pushed in by this much.
    g.tuck = g.portrait > 0 and math.max(0, 2 * r - g.inset) or 0
    g.barsTop = g.blockY + g.pad
    return g
end

-- The suite's text style (see Shared/Kit/Text.lua).
M.LIFT_PIXELS, M.LIFT_ALPHA = Kit.LIFT_PIXELS, Kit.LIFT_ALPHA

-- Edit Mode's Match Width and Match Height (owner, November 15, 2026): the
-- frame takes the width (or height) of the element picked for it, in its
-- own units (its Scale divides it out). Width sets the bars' length, so the
-- portrait stays; height sets the bar block, or with a portrait the ring
-- (Portrait Size % of the block). The saved Frame Width and Health Height
-- stay as they are for when matching stops. Sizes come from the Position
-- Manager's size listener (Build.lua) in self.matchSizes.
function M:MatchedFrame(unit, fdb)
    local own, size = self.db[unit], self.matchSizes and self.matchSizes[unit]
    local wide, tall = own.matchWidth and size and size.width, own.matchHeight and size and size.height
    if not (wide or tall) then return fdb end
    local out = setmetatable({}, { __index = fdb })
    local scale, rim = fdb.scale / 100, Style.EdgeDepth(M.EdgePreset(unit))
    local function Clamp(v, r) return math.max(r[1], math.min(r[2], math.floor(v + 0.5))) end
    local g = self:Geometry(fdb, 1, rim)
    if tall then
        local block = tall / scale * (fdb.showPortrait and 100 / fdb.portraitScale or 1)
        out.healthHeight = Clamp(block - 2 * g.pad - (fdb.showPower and g.gap + g.powerHeight or 0), self.frameRanges.healthHeight)
        g = self:Geometry(out, 1, rim)
    end
    if wide then
        local reach = g.width - math.floor(fdb.barWidth + 0.5) - g.pad
        out.barWidth = Clamp(wide / scale - reach - g.pad, self.frameRanges.barWidth)
    end
    return out
end

function M:ApplyLayout(f, unit)
    local fdb = self:MatchedFrame(unit, self:FrameDB(unit))
    -- Scale first: the pixel size depends on the frame's effective scale.
    f:SetScale(fdb.scale / 100 * (f.previewScale or 1))
    local g = self:Geometry(fdb, self:PixelSize(f), Style.EdgeDepth(M.EdgePreset(unit)))
    f.geometry = g
    f.panel.edge:SetStyle(fdb.edgeStyle, fdb.edgeMetal)
    if f.castBox then f.castBox.edge:SetStyle(fdb.edgeStyle, fdb.edgeMetal) end
    local near, far, sign = Sides(fdb)
    f:SetSize(g.width, g.height)
    local panel = f.panel
    panel:ClearAllPoints()
    panel:SetPoint("TOP" .. near, f, "TOP" .. near, sign * g.blockStart, -g.blockY)
    panel:SetPoint("BOTTOM" .. far, f, "BOTTOM" .. far, 0, g.blockY)
    -- The bars' area is one rim inside the block; the border's rim fills that
    -- band and its corners cover the bars' square corners.
    panel.inner:ClearAllPoints()
    panel.inner:SetPoint("TOPLEFT", panel, "TOPLEFT", g.border, -g.border)
    panel.inner:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -g.border, g.border)
    -- The black plate only behind solid empty bars: see-through ones show the world.
    local solid = fdb.barBackgroundOpacity >= 100 and (not fdb.showPower or fdb.powerBackgroundOpacity >= 100)
    panel.back:ClearAllPoints(); panel.back:SetAllPoints(panel.inner); Style.Paint(panel.back, Tone.shadow, solid and 1 or 0)
    local level = panel:GetFrameLevel()
    local h, pw = f.health, f.power
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", panel.inner, "TOPLEFT", 0, 0); h:SetPoint("TOPRIGHT", panel.inner, "TOPRIGHT", 0, 0)
    h:SetHeight(g.healthHeight)
    pw:ClearAllPoints()
    pw:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -g.gap); pw:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", 0, -g.gap)
    pw:SetHeight(g.powerHeight); pw:SetShown(fdb.showPower)
    -- The 1px black line between health and power.
    local line = panel.hairline
    Style.Paint(line, Tone.shadow)
    line:ClearAllPoints(); line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, 0); line:SetPoint("BOTTOMRIGHT", pw, "TOPRIGHT", 0, 0)
    line:SetShown(fdb.showPower)
    -- Each bar: its fill texture (Mode Matte health, Mode Gradient power by
    -- default) over its empty part (Mode BG on Slate).
    local reverse = fdb.fillDirection == "reverse"
    local barWidth = g.width - g.blockStart - 2 * g.border
    local looks = { { h, g.healthHeight, fdb.foregroundTexture, fdb.backgroundTexture, fdb.barBackgroundOpacity },
        { pw, g.powerHeight, fdb.powerForegroundTexture, fdb.powerBackgroundTexture, fdb.powerBackgroundOpacity } }
    for _, look in ipairs(looks) do
        local bar, barHeight, fill, back, opacity = look[1], look[2], look[3], look[4], look[5]
        bar:SetFrameLevel(level + 1)
        if bar.SetReverseFill then bar:SetReverseFill(reverse) end
        Kit.BarForeground(bar, fill, barHeight, g.px)
        Kit.BarBackground(bar, back, barWidth, barHeight, g.px)
        Tint(bar.bg, Kit.BarBackgroundColor(back), opacity / 100)
    end
    -- A 1px light line where the health fill ends.
    Kit.FillEdge(h, fdb.fillEdge, reverse, g.px)
    -- Combined shields (Style.Shield) run with the health fill.
    h.reverse = reverse
    h.shield:SetShown(fdb.showShields)
    h.shield:Layout()
    -- Border over the bars, then the ring, then text.
    panel.edge.holder:SetFrameLevel(h:GetFrameLevel() + 3)
    panel.edge:Layout()
    local p = f.portrait
    p:SetShown(g.portrait > 0)
    if g.portrait > 0 then
        p:ClearAllPoints(); p:SetPoint("TOP" .. near, f, "TOP" .. near, 0, -g.portraitY)
        Style.LayoutRing(p.ring, g.portrait, g.px)
        p:SetFrameLevel(panel.edge.holder:GetFrameLevel() + 1)
    end
    f.textLayer:SetFrameLevel(math.max(panel.edge.holder:GetFrameLevel(), p:GetFrameLevel()) + 2)
    self:LayoutTexts(f, unit)
    self:PaintRing(f, unit)
    if f.combo then self:ResetComboLayout(f) end
    self:LayoutCast(f, unit)
    self:LayoutAuras(f, unit)
    self:LayoutStatus(f, unit)
end

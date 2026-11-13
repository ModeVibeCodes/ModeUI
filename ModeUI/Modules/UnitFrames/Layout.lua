local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Pixel-perfect geometry and the placement of every region of a frame face.
local ONYX = M.onyx
local Kit = addon.Kit
local FLAT = Kit.FLAT
local CIRCLE_MASK = M.CIRCLE_MASK
local Tint, Lighten = Kit.Tint, Kit.Lighten
local Font, LayoutLift, Inset = Kit.Font, Kit.LayoutLift, Kit.Inset
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
M.RIM, M.GAP, M.HAIRLINE = 2, 2, 1
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
    f:SetScale(fdb.scale / 100)
    local g = self:Geometry(fdb, self:PixelSize(f))
    f.geometry = g
    local near, far, sign = Sides(fdb)
    f:SetSize(g.width, g.height)
    local panel = f.panel
    panel:ClearAllPoints()
    panel:SetPoint("TOP" .. near, f, "TOP" .. near, sign * g.blockStart, -g.blockY)
    panel:SetPoint("BOTTOM" .. far, f, "BOTTOM" .. far, 0, g.blockY)
    -- Hard edges, whole pixels: the rim on the block's edge, the black gap one
    -- rim in, and a black cap under the portrait's end up to the bars' start.
    Kit.PlaceEdges(panel.rim, panel, 0, g.border, ONYX.border, 1)
    Kit.PlaceEdges(panel.gap, panel, g.border, g.line, ONYX.inner, 1)
    local start = g.inset - g.blockStart
    local cap = panel.cap
    cap:ClearAllPoints()
    cap:SetPoint("TOP" .. near, panel, "TOP" .. near, sign * g.pad, -g.pad)
    cap:SetPoint("BOTTOM" .. near, panel, "BOTTOM" .. near, sign * g.pad, g.pad)
    cap:SetWidth(math.max(g.px, start - g.pad)); Tint(cap, ONYX.inner, 1)
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
    end
    -- A 1px light line where the health fill ends (owner, November 13, 2026).
    Kit.FillEdge(h, fdb.fillEdge, reverse, g.px)
    f.textLayer:SetFrameLevel(h:GetFrameLevel() + 3)

    -- Round portrait above the block: full ring, black gap, dark backing, image.
    local p = f.portrait
    p:SetShown(g.portrait > 0)
    if g.portrait > 0 then
        p:ClearAllPoints(); p:SetPoint("TOP" .. near, f, "TOP" .. near, 0, -g.portraitY); p:SetSize(g.portrait, g.portrait)
        p:SetFrameLevel(h:GetFrameLevel() + 1)
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

    -- Text never reaches the portrait (owner, November 13, 2026). A text on the
    -- portrait side stops 2px before the ring's outer edge across its own line
    -- (its font's band, at its Y offset), rounded out to whole pixels; its X
    -- offset moves it away from the portrait freely but never past that line.
    -- Returns how far in from the bars' portrait-side edge the text may start.
    local R, px = g.portrait / 2, g.px
    local function Clearance(mid, size, dy, minimum)
        minimum = minimum or 4
        if R <= 0 then return minimum end
        local half = math.ceil((size + 2) / 2 / px) * px
        local c = mid - dy - g.height / 2
        local d = (c - half <= 0 and c + half >= 0) and 0 or math.min(math.abs(c - half), math.abs(c + half))
        if d >= R then return minimum end
        local edge = R + math.sqrt(R * R - d * d) + 2 * px - g.inset
        return math.max(minimum, math.ceil(edge / px - 1e-6) * px)
    end
    local function Clamped(clear, dx) return sign * math.max(clear, clear + sign * dx) end
    local healthMid = g.barsTop + g.healthHeight / 2
    local powerMid = g.barsTop + g.healthHeight + g.gap + g.powerHeight / 2
    local function SideText(text, bar, position, dx, dy, size, mid)
        text:ClearAllPoints()
        local x = (position == "LEFT" and 4 or position == "RIGHT" and -4 or 0) + dx
        if position == near then x = Clamped(Clearance(mid, size, dy), dx) end
        text:SetPoint(position, bar, position, x, dy); text:SetJustifyH(position)
    end
    local path = self:FontPath(fdb)
    Font(f.nameText, fdb, fdb.nameFontSize, path, g.px); Font(f.levelText, fdb, fdb.levelFontSize, path, g.px)
    Font(f.healthText, fdb, fdb.healthFontSize, path, g.px); Font(f.powerText, fdb, fdb.powerFontSize, path, g.px)
    local hx, hy = fdb.healthTextOffsetX, fdb.healthTextOffsetY
    local lx, ly = fdb.levelOffsetX, fdb.levelOffsetY
    f.healthText:SetShown(fdb.healthText ~= "none")
    -- Level stays in the health bar beside the health text, read level first:
    -- "31 54%" right-aligned, "33 76%" from the left. A Target mirroring the
    -- Player reads health first ("54% 31"), the exact mirror image, so a level
    -- moved by its offset never lands on the health text. Alone, or beside
    -- centred text, the level sits at the bar's right.
    local level = fdb.levelStyle ~= "none"
    local position = fdb.healthTextPosition
    local grouped = level and fdb.healthText ~= "none" and position ~= "CENTER"
    local healthFirst = fdb.mirrored == true
    f.levelText:ClearAllPoints(); f.nameText:ClearAllPoints()
    if grouped and (position == "LEFT") ~= healthFirst then
        -- The level is the outer text, at the bar's edge; the health text sits inside it.
        SideText(f.levelText, h, position, hx + lx, hy + ly, fdb.levelFontSize, healthMid)
        f.healthText:ClearAllPoints()
        if position == "LEFT" then
            f.healthText:SetPoint("LEFT", f.levelText, "RIGHT", 6 - lx, -ly); f.healthText:SetJustifyH("LEFT")
        else
            f.healthText:SetPoint("RIGHT", f.levelText, "LEFT", -6 - lx, -ly); f.healthText:SetJustifyH("RIGHT")
        end
    else
        SideText(f.healthText, h, position, hx, hy, fdb.healthFontSize, healthMid)
        if grouped and position == "RIGHT" then
            f.levelText:SetPoint("RIGHT", f.healthText, "LEFT", -6 + lx, ly); f.levelText:SetJustifyH("RIGHT")
        elseif grouped then
            f.levelText:SetPoint("LEFT", f.healthText, "RIGHT", 6 + lx, ly); f.levelText:SetJustifyH("LEFT")
        elseif level then
            SideText(f.levelText, h, "RIGHT", lx, ly, fdb.levelFontSize, healthMid)
        end
    end
    if level then local c = fdb.levelColor; f.levelText:SetTextColor(c[1], c[2], c[3], 1) end
    f.levelText:SetShown(level)
    -- Plain name (no sheen or texture) in the accent, class or custom color.
    local nx, ny = fdb.nameOffsetX, fdb.nameOffsetY
    if fdb.namePosition == "bar" then
        local align = fdb.nameAlign
        local x = (align == "LEFT" and 4 or align == "RIGHT" and -4 or 0) + nx
        if align == near then x = Clamped(Clearance(healthMid, fdb.nameFontSize, ny), nx) end
        f.nameText:SetPoint(align, h, align, x, ny)
        f.nameText:SetJustifyH(align)
        f.nameText:SetWidth(fdb.barWidth * 0.6)
    else
        -- Above the frame, over the bars, clear of the ring at the name's own
        -- height (the ring curves away above the block, so it can sit closer).
        local line = math.ceil((fdb.nameFontSize + 2) / px) * px
        local clear = Clearance(g.barsTop - g.pad - 3 - ny - line / 2, fdb.nameFontSize, 0, 0)
        local nearX = Clamped(clear, nx)
        f.nameText:SetPoint("BOTTOMLEFT", h, "TOPLEFT", near == "LEFT" and nearX or nx, g.pad + 3 + ny)
        f.nameText:SetPoint("BOTTOMRIGHT", h, "TOPRIGHT", near == "RIGHT" and nearX or nx, g.pad + 3 + ny)
        f.nameText:SetJustifyH(fdb.nameAlign)
    end
    f.nameText:SetShown(fdb.showName)
    SideText(f.powerText, pw, fdb.powerTextPosition, fdb.powerTextOffsetX, fdb.powerTextOffsetY, fdb.powerFontSize, powerMid)
    f.powerText:SetShown(fdb.showPower and fdb.powerText ~= "none")
    LayoutLift(f.nameText, fdb, fdb.nameFontSize, path, g.px, fdb.showName, fdb.nameAlign)
    LayoutLift(f.levelText, fdb, fdb.levelFontSize, path, g.px, level, "CENTER")
    LayoutLift(f.healthText, fdb, fdb.healthFontSize, path, g.px, fdb.healthText ~= "none", position)
    LayoutLift(f.powerText, fdb, fdb.powerFontSize, path, g.px, fdb.showPower and fdb.powerText ~= "none", fdb.powerTextPosition)
    self:PaintRing(f, unit)
    if f.combo then self:ResetComboLayout(f) end
    self:LayoutCast(f, unit)
    self:LayoutAuras(f, unit)
end

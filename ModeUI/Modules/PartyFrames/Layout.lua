local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Pixel-perfect geometry and the placement of every region of a member.
-- Every size is whole physical pixels: the border's rim (2px Mode, 1px Thin),
-- the 1px hairline between health and power, and an even frame size so its
-- centre stays on the grid. The border is the box form of the ModeUI border
-- (corners Corner Size pixels deep), and content is rounded by the corners it
-- reaches (Kit.MaskToBoxBorder: never more than three masks on a texture).
local Kit = addon.Kit

local function Horizontal(anchor) return anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or "" end
local function Vertical(anchor) return anchor:find("^TOP") and "TOP" or anchor:find("^BOTTOM") and "BOTTOM" or "" end
M.Horizontal, M.Vertical = Horizontal, Vertical

-- The frame size every member shares, in its own (scaled) units.
function M:Geometry(px)
    local db, p = self.db, px or 1
    local function Snap(v) return math.max(p, math.floor(v / p + 0.5) * p) end
    local function Even(v) return math.floor(v / (2 * p) + 0.5) * 2 * p end
    local g = { px = p, border = Kit.BorderPixels(db.borderStyle) * p, line = p, thickness = Kit.BorderPixels(db.borderStyle) }
    g.healthHeight, g.powerHeight = Snap(db.healthHeight), Snap(db.powerHeight)
    -- Below Health takes a row under the health bar; Inset sits on it.
    g.powerRow = db.powerShown ~= "none" and db.powerStyle == "below"
    local bars = g.healthHeight + (g.powerRow and g.line + g.powerHeight or 0)
    g.height = math.max(4 * p, Even(bars + 2 * g.border))
    g.width = math.max(4 * p, Even(db.width))
    g.innerWidth, g.innerHeight = g.width - 2 * g.border, g.height - 2 * g.border
    -- Any odd pixel left by Even goes to the health bar.
    g.healthHeight = g.innerHeight - (g.powerRow and g.line + g.powerHeight or 0)
    g.radius = db.corner * p
    return g
end

-- Whether a member shows its power bar: everyone, healers, mana users,
-- healers with mana, or no one. Roles and power types come from the game
-- (UnitPowerType documents no secret returns).
function M:ShowsPower(f)
    local shown = self.db.powerShown
    if shown == "healers" then return f.role == "HEALER" end
    if shown == "mana" then return f.powerToken == "MANA" end
    if shown == "healerMana" then return f.role == "HEALER" and f.powerToken == "MANA" end
    return shown == "all"
end

-- The sizes and textures every member shares; called when settings change.
function M:ApplyLayout(f)
    local db = self.db
    -- Header buttons and Edit Mode stand-ins take their parent's scale.
    if not f.secure and not f.inheritScale then f:SetScale(db.scale / 100 * (f.previewScale or 1)) end
    local g = self:Geometry(Kit.PixelSize(f))
    f.geometry = g
    -- Secure buttons are sized by the header refresh, outside combat.
    if not f.secure then f:SetSize(g.width, g.height) end
    local panel = f.panel
    local level = panel:GetFrameLevel()
    Kit.LayoutModeBoxBorder(panel.border, panel, { px = g.px, radius = g.radius, thickness = g.thickness, level = level + 2 })
    local reverse = db.fillDirection == "reverse"
    for _, look in ipairs({ { f.health, db.foregroundTexture, db.backgroundTexture, g.healthHeight, db.backgroundOpacity, reverse },
        { f.power, db.powerForegroundTexture, db.powerBackgroundTexture, g.powerHeight, db.powerBackgroundOpacity,
            db.powerFillDirection == "reverse" } }) do
        local bar = look[1]
        bar:SetFrameLevel(level + 1)
        if bar.SetReverseFill then bar:SetReverseFill(look[6]) end
        Kit.BarBackground(bar, look[3], g.innerWidth, look[4], g.px)
        Kit.Tint(bar.bg, Kit.BarBackgroundColor(look[3]), look[5] / 100)
        bar.foregroundChoice = look[2]
    end
    panel.hairline:SetTexture(Kit.FLAT); Kit.Tint(panel.hairline, Kit.onyx.inner, 1)
    -- Overshields fill back from full health: the other way from the health.
    f.healPrediction:SetReverseFill(reverse); f.absorb:SetReverseFill(reverse); f.overshield:SetReverseFill(not reverse)
    if f.health.SetClipsChildren then f.health:SetClipsChildren(true) end
    f.glowLayer:SetFrameLevel(level + 3)
    f.textLayer:SetFrameLevel(level + 4)
    f.auraLayer:SetFrameLevel(level + 5)
    self:LayoutBars(f)
    self:LayoutHighlights(f)
    self:LayoutElements(f)
    self:LayoutAuras(f)
end

-- Health and power for this member. Below Health: power in a row under the
-- health (without one, the health takes the whole height). Inset: power sits
-- on the health bar, Power Width wide, at Power Alignment and its offset, in a
-- border of its own. Plain child frames, so this may run in combat when a
-- member's role or power type changes.
function M:LayoutBars(f)
    local g, db = f.geometry, self.db
    if not g then return end
    local px, b = g.px, g.border
    local power = self:ShowsPower(f)
    f.hasPower = power
    local row = g.powerRow and power
    local healthHeight = row and g.healthHeight or g.innerHeight
    local h, pw = f.health, f.power
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", f.panel, "TOPLEFT", b, -b); h:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -b, -b)
    h:SetHeight(healthHeight)
    pw:ClearAllPoints()
    local inset = db.powerStyle == "inset"
    if inset then
        local width = math.max(4 * px, math.floor(g.innerWidth * db.powerWidth / 100 / px + 0.5) * px)
        local align = db.powerAlign
        local x = (align == "LEFT" and b or align == "RIGHT" and -b or 0) + math.floor(db.powerX + 0.5) * px
        pw:SetPoint("BOTTOM" .. (align == "CENTER" and "" or align), f.panel, "BOTTOM" .. (align == "CENTER" and "" or align),
            x, b + math.floor(db.powerY + 0.5) * px)
        pw:SetSize(width, g.powerHeight)
        f.powerWidth = width
        pw:SetFrameLevel(f.panel:GetFrameLevel() + 2)
        Kit.LayoutModeBoxBorder(f.powerBorder, pw, { px = px, radius = 2 * px, thickness = g.thickness, level = pw:GetFrameLevel() + 1 })
    else
        pw:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", b, b); pw:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", -b, b)
        pw:SetHeight(g.powerHeight)
        pw:SetFrameLevel(f.panel:GetFrameLevel() + 1)
        f.powerWidth = g.innerWidth
    end
    self.ShowBorder(f.powerBorder, inset and power)
    pw:SetShown(power)
    local line = f.panel.hairline
    line:ClearAllPoints(); line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, 0); line:SetPoint("BOTTOMRIGHT", pw, "TOPRIGHT", 0, 0)
    line:SetShown(row and true or false)
    Kit.BarForeground(h, h.foregroundChoice, healthHeight, px)
    Kit.BarForeground(pw, pw.foregroundChoice, g.powerHeight, px)
    local reverse = db.fillDirection == "reverse"
    Kit.FillEdge(h, db.fillEdge, reverse, px)
    -- Heals ride on the health fill's end, shields on the heals' end; each
    -- spans the whole bar, so its value draws at the right length. The
    -- overshield spans the bar and fills from its far end.
    local near, far = reverse and "RIGHT" or "LEFT", reverse and "LEFT" or "RIGHT"
    local hp, ab, over = f.healPrediction, f.absorb, f.overshield
    local function Ride(bar, on)
        local fill = on:GetStatusBarTexture()
        bar:ClearAllPoints()
        bar:SetPoint("TOP" .. near, fill, "TOP" .. far, 0, 0); bar:SetPoint("BOTTOM" .. near, fill, "BOTTOM" .. far, 0, 0)
        bar:SetWidth(g.innerWidth)
    end
    Ride(hp, h); Ride(ab, hp)
    over:ClearAllPoints(); over:SetAllPoints(h)
    local regions = { h:GetStatusBarTexture(), h.bg, h.sheen, h.fillEdge,
        Kit.FillTexture(hp, db.healTexture, g.innerWidth, healthHeight, px, db.healPredictionColor, db.healPredictionOpacity / 100),
        Kit.FillTexture(ab, db.shieldTexture, g.innerWidth, healthHeight, px, db.absorbColor, db.absorbOpacity / 100),
        Kit.FillTexture(over, db.overshieldTexture, g.innerWidth, healthHeight, px, db.overshieldColor, db.overshieldOpacity / 100),
        f.targetFill, f.hover, f.dispel.health, f.dispel.gradient }
    f.healthRegions = regions
    local bottom = row and (g.powerHeight + g.line + b) or b
    f.healthEdges = { left = b, top = b, right = b, bottom = bottom }
    Kit.MaskToBoxBorder(f.panel.border, regions, f.healthEdges)
    local powerRegions = { pw:GetStatusBarTexture(), pw.bg, pw.sheen }
    if inset then Kit.MaskToBoxBorder(f.powerBorder, powerRegions, { left = 0, top = 0, right = 0, bottom = 0 })
    else Kit.MaskToBoxBorder(f.panel.border, powerRegions, { left = b, top = b + healthHeight + g.line, right = b, bottom = b }) end
    Kit.MaskToBoxBorder(f.panel.border, { line }, { left = b, top = b + healthHeight, right = b, bottom = b + g.powerHeight })
    self:LayoutPowerText(f)
    self:LayoutDispel(f)
end

-- The power text: on the power bar at Text Alignment and its offset.
function M:LayoutPowerText(f)
    local db, g, text = self.db, f.geometry, f.powerText
    local px = g.px
    local align = db.powerTextAlign
    local inset = align == "LEFT" and 2 * px or align == "RIGHT" and -2 * px or 0
    text:ClearAllPoints()
    text:SetPoint(align, f.power, align, inset + math.floor(db.powerTextX + 0.5) * px, math.floor(db.powerTextY + 0.5) * px)
    text:SetWidth(math.max(px, (f.powerWidth or g.innerWidth) - 4 * px))
    f.powerTextLayer:SetFrameLevel(f.power:GetFrameLevel() + 3)
    local path = Kit.FontPath(db, self.id)
    Kit.Font(text, db, db.powerTextSize, path, px)
    text:SetJustifyH(align)
    local shown = db.powerTextShow and f.hasPower
    Kit.LayoutLift(text, db, db.powerTextSize, path, px, shown, align)
    text:SetShown(shown and true or false)
    local c = db.textColor
    text:SetTextColor(c[1], c[2], c[3], 1)
end

-- Target and mouse highlights: the border again in the highlight color
-- (Border), or a soft tint over the health bar (Tint).
function M:LayoutHighlights(f)
    local g, db = f.geometry, self.db
    Kit.LayoutModeBoxBorder(f.targetRing, f.glowLayer, { px = g.px, radius = g.radius, thickness = g.thickness,
        color = db.targetColor, level = f.glowLayer:GetFrameLevel() + 1 })
    for _, fill in ipairs({ f.targetFill, f.hover }) do
        fill:ClearAllPoints(); fill:SetAllPoints(f.health)
    end
    Kit.Tint(f.targetFill, db.targetColor, 0.18)
    Kit.Tint(f.hover, { 1, 1, 1 }, 0.08)
    self:PaintTarget(f)
end

-- Places a region at an element's anchor: inside the bars, or outside past
-- the bars' edge on the anchor's side (Center always sits inside).
function M:PlaceAt(f, region, anchor, place, dx, dy)
    local g = f.geometry
    local px = g.px
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local h, v = Horizontal(anchor), Vertical(anchor)
    local x, y = Round(dx), Round(dy)
    region:ClearAllPoints()
    if place == "outside" and v ~= "" then
        local other = v == "TOP" and "BOTTOM" or "TOP"
        region:SetPoint(other .. h, f.panel, v .. h, x, y + (v == "TOP" and px or -px))
    elseif place == "outside" and h ~= "" then
        local other = h == "LEFT" and "RIGHT" or "LEFT"
        region:SetPoint(other, f.panel, h, x + (h == "LEFT" and -px or px), y)
    else
        local inset = g.border + px
        local ix = h == "LEFT" and inset or h == "RIGHT" and -inset or 0
        local iy = v == "TOP" and -inset or v == "BOTTOM" and inset or 0
        region:SetPoint(anchor, f.panel, anchor, ix + x, iy + y)
    end
end

-- Texts and icons, each by its own settings.
function M:LayoutElements(f)
    local db, g = self.db, f.geometry
    local px = g.px
    local path = Kit.FontPath(db, self.id)
    f.fontPath = path
    for element, text in pairs(f.texts) do
        local size, anchor = db[element .. "Size"], db[element .. "Anchor"]
        local h = Horizontal(anchor)
        local justify = h == "" and "CENTER" or h
        self:PlaceAt(f, text, anchor, db[element .. "Place"], db[element .. "X"], db[element .. "Y"])
        -- Widths come from settings, never from measuring (names can be secret).
        local share = element == "name" and db.nameWidth / 100 or 1
        text:SetWidth(math.max(px, math.floor(g.innerWidth * share / px) * px - 2 * px))
        Kit.Font(text, db, size, path, px)
        text:SetJustifyH(justify)
        Kit.LayoutLift(text, db, size, path, px, db[element .. "Show"], justify)
        text:SetShown(db[element .. "Show"] and true or false)
    end
    for element, icon in pairs(f.icons) do
        local size = math.max(px, math.floor(db[element .. "Size"] / px + 0.5) * px)
        icon:SetSize(size, size)
        self:PlaceAt(f, icon, db[element .. "Anchor"], db[element .. "Place"], db[element .. "X"], db[element .. "Y"])
    end
end

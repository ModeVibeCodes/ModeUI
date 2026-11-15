local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Pixel-perfect geometry and the placement of every region of a member.
-- Every size is whole physical pixels: the group edge's 1px rim, the 1px
-- black line between health and power, and an even frame size so its centre
-- stays on the grid. The rim art covers the bars' corners: no masks.
local Kit, Style = addon.Kit, addon.Style
local Tone = Style.Tone
local RIM = Style.EDGE_PRESETS.group.rim

local function Horizontal(anchor) return anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or "" end
local function Vertical(anchor) return anchor:find("^TOP") and "TOP" or anchor:find("^BOTTOM") and "BOTTOM" or "" end
M.Horizontal, M.Vertical = Horizontal, Vertical

-- The frame size every member shares, in its own (scaled) units.
function M:Geometry(px)
    local db, p = self.db, px or 1
    local function Snap(v) return math.max(p, math.floor(v / p + 0.5) * p) end
    local function Even(v) return math.floor(v / (2 * p) + 0.5) * 2 * p end
    local g = { px = p, border = RIM * p, line = p }
    g.healthHeight, g.powerHeight = Snap(db.healthHeight), Snap(db.powerHeight)
    -- Below Health takes a row under the health bar; Inset sits on it.
    g.powerRow = db.powerShown ~= "none" and db.powerStyle == "below"
    local bars = g.healthHeight + (g.powerRow and g.line + g.powerHeight or 0)
    g.height = math.max(4 * p, Even(bars + 2 * g.border))
    g.width = math.max(4 * p, Even(db.width))
    g.innerWidth, g.innerHeight = g.width - 2 * g.border, g.height - 2 * g.border
    -- Any odd pixel left by Even goes to the health bar.
    g.healthHeight = g.innerHeight - (g.powerRow and g.line + g.powerHeight or 0)
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
    -- The bars' area is one rim inside the member; the edge's rim fills that band.
    panel.inner:ClearAllPoints()
    panel.inner:SetPoint("TOPLEFT", panel, "TOPLEFT", g.border, -g.border)
    panel.inner:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -g.border, g.border)
    -- The black plate only behind solid empty bars: see-through ones show the world.
    local solid = db.backgroundOpacity >= 100 and db.powerBackgroundOpacity >= 100
    panel.back:ClearAllPoints(); panel.back:SetAllPoints(panel.inner); Style.Paint(panel.back, Tone.shadow, solid and 1 or 0)
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
    Style.Paint(panel.hairline, Tone.shadow)
    f.healPrediction:SetReverseFill(reverse)
    if f.health.SetClipsChildren then f.health:SetClipsChildren(true) end
    -- Edge over the bars; highlights, text and auras over the edge.
    panel.edge.holder:SetFrameLevel(level + 3)
    panel.edge:Layout()
    f.glowLayer:SetFrameLevel(level + 4)
    f.textLayer:SetFrameLevel(level + 5)
    f.auraLayer:SetFrameLevel(level + 6)
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
    h:SetPoint("TOPLEFT", f.panel.inner, "TOPLEFT", 0, 0); h:SetPoint("TOPRIGHT", f.panel.inner, "TOPRIGHT", 0, 0)
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
        f.powerEdge.holder:SetFrameLevel(pw:GetFrameLevel() + 1)
        f.powerEdge:Layout()
    else
        pw:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", b, b); pw:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", -b, b)
        pw:SetHeight(g.powerHeight)
        pw:SetFrameLevel(f.panel:GetFrameLevel() + 1)
        f.powerWidth = g.innerWidth
    end
    f.powerEdge:SetShown(inset and power)
    pw:SetShown(power)
    local line = f.panel.hairline
    line:ClearAllPoints(); line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, 0); line:SetPoint("BOTTOMRIGHT", pw, "TOPRIGHT", 0, 0)
    line:SetShown(row and true or false)
    Kit.BarForeground(h, h.foregroundChoice, healthHeight, px)
    Kit.BarForeground(pw, pw.foregroundChoice, g.powerHeight, px)
    local reverse = db.fillDirection == "reverse"
    Kit.FillEdge(h, db.fillEdge, reverse, px)
    -- Heals ride on the health fill's end and span the whole bar, so their
    -- value draws at the right length. Combined shields (Style.Shield) run
    -- with the health fill.
    local near, far = reverse and "RIGHT" or "LEFT", reverse and "LEFT" or "RIGHT"
    local hp, fill = f.healPrediction, h:GetStatusBarTexture()
    hp:ClearAllPoints()
    hp:SetPoint("TOP" .. near, fill, "TOP" .. far, 0, 0); hp:SetPoint("BOTTOM" .. near, fill, "BOTTOM" .. far, 0, 0)
    hp:SetWidth(g.innerWidth)
    Kit.FillTexture(hp, db.healTexture, g.innerWidth, healthHeight, px, db.healPredictionColor, db.healPredictionOpacity / 100)
    h.reverse = reverse
    h.shield:SetShown(db.showAbsorbs)
    h.shield:SetLook({ texture = db.shieldsTexture, opacity = db.shieldsOpacity / 100,
        color = db.shieldsColorMode == "custom" and db.shieldsColor or nil })
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

-- Target and mouse highlights: the rim in the highlight color (Border), or
-- a soft tint over the health bar (Tint).
function M:LayoutHighlights(f)
    local db = self.db
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
        -- Names in SemiBold and health text in Bold (Geist weights; another
        -- font keeps its one weight).
        local weighted = element == "name" and Style.Weighted(path, "semibold")
            or element == "healthText" and Style.Weighted(path, "bold") or path
        Kit.Font(text, db, size, weighted, px)
        text:SetJustifyH(justify)
        Kit.LayoutLift(text, db, size, weighted, px, db[element .. "Show"], justify)
        text:SetShown(db[element .. "Show"] and true or false)
        -- Health numbers glow (Health Text Glow); width from the format.
        if element == "healthText" then
            Style.TextGlow(text, db.healthTextShow and db.healthTextGlow
                and { size = size, chars = Style.GLOW_CHARS[db.healthText], justify = justify, px = px } or nil)
        end
    end
    for element, icon in pairs(f.icons) do
        local size = math.max(px, math.floor(db[element .. "Size"] / px + 0.5) * px)
        icon:SetSize(size, size)
        self:PlaceAt(f, icon, db[element .. "Anchor"], db[element .. "Place"], db[element .. "X"], db[element .. "Y"])
    end
end

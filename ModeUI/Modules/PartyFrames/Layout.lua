local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Pixel-perfect geometry and the placement of every region of a member.
-- Every size is whole physical pixels: the ModeUI border's 2px rim, the 1px
-- hairline between health and power, and an even frame size so its centre
-- stays on the grid. Elements sit at an anchor inside the bars, or outside
-- past the bars' edge on that side.
local Kit = addon.Kit

local function Horizontal(anchor) return anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or "" end
local function Vertical(anchor) return anchor:find("^TOP") and "TOP" or anchor:find("^BOTTOM") and "BOTTOM" or "" end
M.Horizontal, M.Vertical = Horizontal, Vertical

-- The frame size every member shares, in its own (scaled) units.
function M:Geometry(px)
    local db, p = self.db, px or 1
    local function Snap(v) return math.max(p, math.floor(v / p + 0.5) * p) end
    local function Even(v) return math.floor(v / (2 * p) + 0.5) * 2 * p end
    local g = { px = p, border = Kit.BORDER_PIXELS * p, line = p }
    g.healthHeight, g.powerHeight = Snap(db.healthHeight), Snap(db.powerHeight)
    g.withPower = db.powerShown ~= "none"
    local bars = g.healthHeight + (g.withPower and g.line + g.powerHeight or 0)
    g.height = math.max(4 * p, Even(bars + 2 * g.border))
    g.width = math.max(4 * p, Even(db.width))
    g.innerWidth, g.innerHeight = g.width - 2 * g.border, g.height - 2 * g.border
    -- Any odd pixel left by Even goes to the health bar.
    g.healthHeight = g.innerHeight - (g.withPower and g.line + g.powerHeight or 0)
    return g
end

-- Whether a member shows its power bar: everyone, healers only, or no one.
function M:ShowsPower(f)
    local shown = self.db.powerShown
    if shown == "healers" then return f.role == "HEALER" end
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
    Kit.LayoutModeBorder(panel.border, panel, { px = g.px, height = g.height, level = level + 2 })
    f.masks = { panel.border.masks.LEFT, panel.border.masks.RIGHT }
    local reverse = db.fillDirection == "reverse"
    for _, look in ipairs({ { f.health, db.foregroundTexture, db.backgroundTexture, db.backgroundOpacity },
        { f.power, db.powerForegroundTexture, db.powerBackgroundTexture, db.backgroundOpacity } }) do
        local bar = look[1]
        bar:SetFrameLevel(level + 1)
        if bar.SetReverseFill then bar:SetReverseFill(reverse) end
        Kit.BarBackground(bar, look[3], g.innerWidth, g.healthHeight, g.px)
        Kit.Tint(bar.bg, Kit.BarBackgroundColor(look[3]), look[4] / 100)
        bar.foregroundChoice = look[2]
    end
    panel.hairline:SetTexture(Kit.FLAT); Kit.Tint(panel.hairline, Kit.onyx.inner, 1)
    -- Incoming heals and absorbs: fill textures colored by the settings.
    for _, rider in ipairs({ { f.healPrediction, db.healPredictionColor, db.healPredictionOpacity },
        { f.absorb, db.absorbColor, db.absorbOpacity } }) do
        local bar = rider[1]
        bar:SetStatusBarTexture(Kit.FLAT)
        bar:SetStatusBarColor(rider[2][1], rider[2][2], rider[2][3], rider[3] / 100)
        if bar.SetReverseFill then bar:SetReverseFill(reverse) end
    end
    if f.health.SetClipsChildren then f.health:SetClipsChildren(true) end
    f.glowLayer:SetFrameLevel(level + 3)
    f.textLayer:SetFrameLevel(level + 4)
    f.auraLayer:SetFrameLevel(level + 5)
    self:LayoutBars(f)
    self:LayoutHighlights(f)
    self:LayoutElements(f)
    self:LayoutAuras(f)
end

-- Health and power for this member: without a power bar (healers only, and
-- this member isn't one) the health bar takes the whole height. Plain child
-- frames, so this may run in combat when a member's role changes.
function M:LayoutBars(f)
    local g, db = f.geometry, self.db
    if not g then return end
    local power = g.withPower and self:ShowsPower(f)
    f.hasPower = power
    local healthHeight = power and g.healthHeight or g.innerHeight
    local h, pw = f.health, f.power
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", f.panel, "TOPLEFT", g.border, -g.border)
    h:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -g.border, -g.border)
    h:SetHeight(healthHeight)
    pw:ClearAllPoints()
    pw:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", g.border, g.border)
    pw:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", -g.border, g.border)
    pw:SetHeight(g.powerHeight)
    pw:SetShown(power)
    local line = f.panel.hairline
    line:ClearAllPoints(); line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, 0); line:SetPoint("BOTTOMRIGHT", pw, "TOPRIGHT", 0, 0)
    line:SetShown(power)
    Kit.BarForeground(h, h.foregroundChoice, healthHeight, g.px)
    Kit.BarForeground(pw, pw.foregroundChoice, g.powerHeight, g.px)
    local reverse = db.fillDirection == "reverse"
    Kit.FillEdge(h, db.fillEdge, reverse, g.px)
    -- Heals ride on the health fill's end, absorbs on the heals' end; each
    -- spans the whole bar, so its value draws at the right length.
    local near, far = reverse and "RIGHT" or "LEFT", reverse and "LEFT" or "RIGHT"
    local hp, ab = f.healPrediction, f.absorb
    hp:ClearAllPoints()
    hp:SetPoint("TOP" .. near, h:GetStatusBarTexture(), "TOP" .. far, 0, 0); hp:SetPoint("BOTTOM" .. near, h:GetStatusBarTexture(), "BOTTOM" .. far, 0, 0)
    hp:SetWidth(g.innerWidth)
    ab:ClearAllPoints()
    ab:SetPoint("TOP" .. near, hp:GetStatusBarTexture(), "TOP" .. far, 0, 0); ab:SetPoint("BOTTOM" .. near, hp:GetStatusBarTexture(), "BOTTOM" .. far, 0, 0)
    ab:SetWidth(g.innerWidth)
    Kit.AddMasks({ h:GetStatusBarTexture(), h.bg, h.sheen, h.fillEdge, pw:GetStatusBarTexture(), pw.bg, pw.sheen, line,
        hp:GetStatusBarTexture(), ab:GetStatusBarTexture() }, f.masks)
end

-- Target, dispel and mouse highlights: the border shape again in their color
-- (Border), or a soft tint over the bars (Tint), rounded like the bars.
function M:LayoutHighlights(f)
    local g, db = f.geometry, self.db
    local depth = Kit.CapDepth(g.height, g.px)
    local both = { LEFT = true, RIGHT = true }
    Kit.PlaceCapRing(f.targetRing, f.glowLayer, 0, g.border, db.targetColor, depth, both)
    Kit.PlaceCapRing(f.dispelRing, f.glowLayer, 0, g.border, Kit.BORDER_COLOR, depth, both)
    for _, fill in ipairs({ f.targetFill, f.dispelFill, f.hover }) do
        Kit.Inset(fill, f.glowLayer, g.border)
        Kit.AddMasks({ fill }, f.masks)
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
        local key = element
        local size, anchor = db[key .. "Size"], db[key .. "Anchor"]
        local h = Horizontal(anchor)
        local justify = h == "" and "CENTER" or h
        self:PlaceAt(f, text, anchor, db[key .. "Place"], db[key .. "X"], db[key .. "Y"])
        -- Widths come from settings, never from measuring (names can be secret).
        local share = element == "name" and db.nameWidth / 100 or 1
        text:SetWidth(math.max(px, math.floor(g.innerWidth * share / px) * px - 2 * px))
        Kit.Font(text, db, size, path, px)
        text:SetJustifyH(justify)
        Kit.LayoutLift(text, db, size, path, px, db[key .. "Show"], justify)
        text:SetShown(db[key .. "Show"] and true or false)
    end
    for element, icon in pairs(f.icons) do
        local size = math.max(px, math.floor(db[element .. "Size"] / px + 0.5) * px)
        icon:SetSize(size, size)
        self:PlaceAt(f, icon, db[element .. "Anchor"], db[element .. "Place"], db[element .. "X"], db[element .. "Y"])
    end
end

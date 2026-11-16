local _, addon = ...
local M = addon.Minimap
if not M then return end

-- Zone, clock and coordinates. On Map: the clock above the zone, centered at
-- the bottom of the map, coordinates centered at the top (owner, November
-- 14, 2026). Bar Below: a Mode strip (a Mode Button face in Mono raised, in
-- the same `frame` edge as the map) under the map, its edge 1 px from the
-- map's: clock at the right, coordinates just left of it, the zone from the
-- left up to them (cut short when it doesn't fit, never under them).
-- The clock is Bold, the zone SemiBold. On
-- Hover: the On Map layout, shown while the pointer is over the map. Text is
-- in the module's font with ModeUI's lifted shadow. The zone name goes
-- straight to SetText (it could be secret); coordinates show only when the
-- game gives plain numbers.
local Kit, Location, Skin, Style = addon.Kit, addon.Domain.Location, addon.Skin, addon.Style
local BAR_HEIGHT, BAR_PADDING = 22, 8
local Snap = Skin.Snap

local function NewText(parent)
    local text = Kit.Text(parent, "OVERLAY")
    text.lift = Kit.Text(parent, "ARTWORK")
    return text
end

function M:BuildText()
    local bar = CreateFrame("Frame", nil, self.holder)
    bar.parts = Skin.Box(bar, "frame", { level = 2 })
    bar.overlay = CreateFrame("Frame", nil, bar)
    bar.overlay:SetAllPoints(bar)
    self.bar = bar
    self.texts = { zone = NewText(self.overlay), clock = NewText(self.overlay), coords = NewText(self.overlay) }
    self.barTexts = { zone = NewText(bar.overlay), clock = NewText(bar.overlay), coords = NewText(bar.overlay) }
end

function M:TextStyle(color)
    return { font = self.db.font, fontMedia = self.db.fontMedia, outline = false, shadow = true, liftedShadow = true,
        textColor = color or Skin.mode.text }
end

-- Lays out the bar (when shown) and the texts; returns the bar's extra height.
function M:LayoutText(width, height)
    local db, px = self.db, self.px
    local onBar = db.textLayout == "bar"
    local bar = self.bar
    local barHeight = addon.Skin.Snap(BAR_HEIGHT, px)
    bar:SetShown(onBar)
    local extra = 0
    if onBar then
        -- The two edges 1 px apart (each reaches its rim and shadow ring out).
        local reach = ((self.BORDER_PIXELS[db.border] or 2) + 1) * px
        local gap = 2 * reach + px
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", self.map, "BOTTOMLEFT", 0, -gap)
        bar:SetSize(width, barHeight)
        Skin.PaintBox(bar.parts, bar, "Button", self.TILE_FILL, 1, true)
        self:PaintEdge(bar.parts.modeEdge, db.border)
        bar.overlay:SetFrameLevel(bar:GetFrameLevel() + 4)
        extra = gap + barHeight
    end
    local path = Kit.FontPath(db, self.id)
    local size = db.textSize
    local function Place(text, point, relative, x, y, justify, shown, weight)
        local face = weight and Style.Weighted(path, weight) or path
        text:ClearAllPoints()
        text:SetPoint(point, relative, point, x, y)
        Kit.Font(text, self:TextStyle(), size, face, px)
        text:SetJustifyH(justify)
        text:SetShown(shown)
        Kit.LayoutLift(text, self:TextStyle(), size, face, px, shown, justify)
    end
    local t, b = self.texts, self.barTexts
    local inset = self.TILE_INSET + px
    Place(t.zone, "BOTTOM", self.map, 0, inset, "CENTER", not onBar, "semibold")
    Place(t.clock, "BOTTOM", self.map, 0, inset + size + 2, "CENTER", not onBar and db.clock, "bold")
    Place(t.coords, "TOP", self.map, 0, -(inset + 2), "CENTER", not onBar and db.coords)
    Place(b.zone, "LEFT", bar, BAR_PADDING, 0, "LEFT", onBar, "semibold")
    Place(b.clock, "RIGHT", bar, -BAR_PADDING, 0, "RIGHT", onBar and db.clock, "bold")
    Place(b.coords, "RIGHT", bar, -BAR_PADDING, 0, "RIGHT", onBar and db.coords)
    local gap = Snap(BAR_PADDING, px)
    if onBar and db.clock then
        b.coords:ClearAllPoints(); b.coords:SetPoint("RIGHT", b.clock, "LEFT", -gap, 0)
    end
    local limit = (onBar and db.coords and b.coords) or (onBar and db.clock and b.clock) or nil
    b.zone:SetPoint("RIGHT", limit or bar, limit and "LEFT" or "RIGHT", limit and -gap or -BAR_PADDING, 0)
    for _, text in ipairs({ b.zone, b.zone.lift }) do text:SetWordWrap(false) end
    for _, text in ipairs({ t.clock, b.clock }) do Skin.Ink(text, Style.Tone.textBright) end
    self:UpdateZone(); self:UpdateClock(true); self:UpdateCoords()
    return extra
end

local function Write(text, value) pcall(Kit.Write, text, value) end

function M:UpdateZone()
    if not self.texts then return end
    local ok, zone = Location.ZoneText()
    if not ok then zone = "" end -- the name itself is never tested (it could be secret)
    local color = self.WHITE
    if self.db.zoneColor == "pvp" then color = self.ZONE_COLORS[Location.PvPType() or ""] or Skin.mode.text end
    for _, text in ipairs({ self.texts.zone, self.barTexts.zone }) do
        Write(text, zone)
        text:SetTextColor(color[1], color[2], color[3], 1)
    end
end

function M:UpdateClock(force)
    if not self.texts or not self.db.clock then return end
    local pattern = self.db.clockFormat == "12" and "%I:%M %p" or "%H:%M"
    local value = date(pattern)
    if self.db.clockFormat == "12" then value = value:gsub("^0", "") end
    if not force and value == self.clockValue then return end
    self.clockValue = value
    Write(self.texts.clock, value); Write(self.barTexts.clock, value)
end

function M:UpdateCoords()
    if not self.texts or not self.db.coords then return end
    local x, y = Location.PlayerPosition()
    local value = x and string.format("%.1f, %.1f", x, y) or ""
    if value == self.coordsValue then return end
    self.coordsValue = value
    Write(self.texts.coords, value); Write(self.barTexts.coords, value)
end

-- On Hover: the map's texts show while the pointer is over the map.
function M:UpdateHover()
    if not self.texts then return end
    local alpha = 1
    if self.db.textLayout == "hover" then alpha = self.holder:IsMouseOver() and 1 or 0 end
    if alpha == self.textAlpha then return end
    self.textAlpha = alpha
    for _, text in pairs(self.texts) do text:SetAlpha(alpha); text.lift:SetAlpha(alpha) end
end

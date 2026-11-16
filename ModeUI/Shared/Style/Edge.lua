local _, addon = ...
-- The one border factory (docs/DESIGN_LANGUAGE.md, "Borders"). A border sits
-- outside its host: an optional 1px black gap, the rim, then an optional 1px
-- shadow ring (or the accent highlight), and an optional soft drop below the
-- host. Every piece is sliced Round 4 art on a holder frame scaled to one
-- physical pixel per unit, so offsets and slice margins are whole pixels at any
-- UI scale; the pieces keep the client's default pixel snapping, so a host on a
-- fractional pixel still gets crisp 1px rims. The rim covers its own inner
-- corner: no masks.
local Style = addon.Style
local Tone = Style.Tone

-- rim: thickness in pixels. metal: Tone metal table, or nil for a flat color.
-- light: "edge" (top edge catches light), "sheen" (band through the middle),
-- "solid". shadow: 1px dark ring. soft: drop shadow. gap: 1px black ring
-- inside the rim. color: flat rim color for line/empty.
Style.EDGE_PRESETS = {
    frame = { rim = 2, metal = "gunmetal", light = "edge", shadow = true, soft = true },
    frameThin = { rim = 1, metal = "gunmetal", light = "edge", shadow = true },
    group = { rim = 1, metal = "gunmetal", light = "solid" },
    window = { rim = 1, metal = "steel", light = "sheen", shadow = true, soft = true, gap = true },
    card = { rim = 1, metal = "steel", light = "sheen", gap = true },
    control = { rim = 1, metal = "steel", light = "sheen", shadow = true },
    line = { rim = 1, light = "solid", shadow = true, flat = true },
    empty = { rim = 1, light = "edge", shadow = true, flat = true },
}

local EDGE_LIGHT_ALPHA = 0.28
-- A 1px rim has no second row for the light to fade into, so its whole top
-- edge would read heavier than the sides; it takes half the light.
local THIN_LIGHT = 0.5

-- The sheen's base tone and the strength of its band, so the band peaks at
-- mix(light, mid, 0.7) over a base of mix(dark, mid, 0.5).
local function Sheen(metal)
    local base = Style.Mix(metal.dark, metal.mid, 0.5)
    local peak = Style.Mix(metal.light, metal.mid, 0.7)
    local alpha = 0
    for i = 1, 3 do alpha = alpha + (peak[i] - base[i]) / math.max(0.01, 1 - base[i]) end
    return base, math.max(0, math.min(1, alpha / 3))
end

local function Piece(frame, layer, sublevel, key)
    local texture = frame:CreateTexture(nil, layer, nil, sublevel)
    Style.ApplyAsset(texture, key)
    return texture
end
-- Anchors a piece `out` pixels outside the holder on every side (holder units
-- are physical pixels), shifted down by `drop`.
local function Around(texture, holder, out, drop)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", holder, "TOPLEFT", -out, out - (drop or 0))
    texture:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", out, -out - (drop or 0))
end

local Edge = {}
Edge.__index = Edge
-- Every border, so a window can re-lay them after its scale changes.
local edges = setmetatable({}, { __mode = "k" })

-- Re-lays every border on whole pixels (UI scale or a window's own scale changed).
function Style.RelayoutEdges()
    for edge in pairs(edges) do edge:Layout() end
end

-- A border of `preset` for `host`. opts: level (frame levels above the host,
-- default 2), color (flat presets), rim (override thickness, 1 or 2).
function Style.Edge(host, preset, opts)
    local def = assert(Style.EDGE_PRESETS[preset], "Style.Edge: unknown preset " .. tostring(preset))
    opts = opts or {}
    local edge = setmetatable({ host = host, preset = preset, def = def, rim = opts.rim or def.rim, color = opts.color }, Edge)
    local holder = CreateFrame("Frame", nil, host)
    holder:SetAllPoints(host)
    holder:EnableMouse(false)
    holder:SetFrameLevel(host:GetFrameLevel() + (opts.level or 2))
    edge.holder = holder
    if def.shadow then edge.shadow = Piece(holder, "BORDER", 0, "Shadow") end
    if def.gap then edge.gap = Piece(holder, "BORDER", 1, "Gap") end
    edge.rimTexture = Piece(holder, "ARTWORK", 0, edge.rim == 2 and "Rim2" or "Rim1")
    if def.light == "edge" then edge.light = Piece(holder, "ARTWORK", 1, edge.rim == 2 and "Edge2" or "Edge1")
    elseif def.light == "sheen" then edge.light = Piece(holder, "ARTWORK", 1, "Sheen1") end
    if def.soft then
        local below = CreateFrame("Frame", nil, host)
        below:SetAllPoints(host)
        below:EnableMouse(false)
        below:SetFrameLevel(math.max(0, host:GetFrameLevel() - 1))
        edge.below = below
        edge.soft = Piece(below, "BACKGROUND", -8, "Soft")
    end
    edges[edge] = true
    edge:Layout()
    edge:Paint()
    return edge
end

-- One physical pixel per unit on a holder: it ignores its parents' scale and
-- takes Blizzard's pixel factor as its own, so a host whose scale changes
-- after layout (nameplates, aura buttons a container made once) never leaves
-- the border at a stale size. Without the factor, the host's pixel size.
local function PixelGrid(frame, px)
    local factor = frame.SetIgnoreParentScale and Style.PixelFactor()
    if frame.SetIgnoreParentScale then frame:SetIgnoreParentScale(factor ~= nil) end
    frame:SetScale(factor or px)
end

-- Places every piece on whole physical pixels. Call again when the host's
-- effective scale changes without a pixel factor (the fallback only).
function Edge:Layout()
    local px = Style.Pixel(self.host)
    self.px = px
    PixelGrid(self.holder, px)
    if self.below then PixelGrid(self.below, px) end
    local gap = self.def.gap and 1 or 0
    local rim = self.rim
    if self.gap then Around(self.gap, self.holder, gap) end
    Around(self.rimTexture, self.holder, gap + rim)
    if self.light then Around(self.light, self.holder, gap + rim) end
    if self.shadow then Around(self.shadow, self.holder, gap + rim + 1) end
    if self.soft then Around(self.soft, self.below, gap + rim + 6, 1) end
    return gap + rim
end

-- How far a preset's border reaches outside its host, in physical pixels
-- (gap, rim and shadow ring; the soft drop is left out).
function Style.EdgeReach(preset)
    local def = assert(Style.EDGE_PRESETS[preset], "Style.EdgeReach: unknown preset " .. tostring(preset))
    return (def.gap and 1 or 0) + def.rim + (def.shadow and 1 or 0)
end

-- How far the border reaches outside the host, in the host's UI units.
function Edge:Outset()
    local gap = self.def.gap and 1 or 0
    return (gap + self.rim + (self.shadow and 1 or 0)) * (self.px or 1)
end

function Edge:Paint()
    local def = self.def
    local rimColor, lightAlpha
    if def.flat or self.tint then
        rimColor = self.tint or self.color or Tone.mono.rimStrong
        lightAlpha = def.light == "edge" and 0.3 * (self.rim == 1 and THIN_LIGHT or 1) or 0
    else
        local metal = Tone[def.metal]
        if def.light == "sheen" then rimColor, lightAlpha = Sheen(metal)
        else rimColor, lightAlpha = metal.mid, def.light == "edge" and EDGE_LIGHT_ALPHA * (self.rim == 1 and THIN_LIGHT or 1) or 0 end
    end
    Style.Paint(self.rimTexture, rimColor)
    if self.light then
        self.light:SetVertexColor(1, 1, 1, lightAlpha)
        self.light:SetShown(lightAlpha > 0)
    end
    if self.gap then Style.Paint(self.gap, Tone.shadow) end
    if self.shadow then
        if self.highlight then Style.Paint(self.shadow, self.highlight)
        else Style.Paint(self.shadow, Tone.shadow, Tone.shadowAlpha) end
    end
    if self.soft then Style.Paint(self.soft, Tone.shadow, Tone.softAlpha) end
end

-- A custom rim color (Mode Empty, Mode Line, or any preset's rim swapped for a
-- state such as a dispel type); nil restores the preset's metal.
function Edge:SetTint(color)
    self.tint = color
    self:Paint()
end

-- The 1px outer accent line: "accent" (Ivory), "specialty" (Rosewood), a color
-- table, or nil for none. Presets without a shadow ring take it as a tint.
function Edge:SetHighlight(kind)
    local color = kind and (type(kind) == "table" and kind or Style.Accent(kind)) or nil
    if self.shadow then self.highlight = color
    else self.tint = color end
    self:Paint()
end

-- Changes the rim's thickness (1 or 2 pixels): its art, its light and layout.
function Edge:SetRim(rim)
    rim = rim == 2 and 2 or 1
    if rim == self.rim then return end
    self.rim = rim
    Style.ApplyAsset(self.rimTexture, rim == 2 and "Rim2" or "Rim1")
    if self.def.light == "edge" and self.light then Style.ApplyAsset(self.light, rim == 2 and "Edge2" or "Edge1") end
    self:Layout()
    self:Paint()
end

-- Moves the border to `level` frame levels above its host (a host whose own
-- level changes, or whose children stack high, like Blizzard's windows).
-- The soft drop always sits under `under` (the frame the border is really
-- for; the host by default): lifted with the rim it would shade the content.
function Edge:SetLevel(level, under)
    local base = self.host:GetFrameLevel()
    if not addon.IsNumber(base) then return end
    self.holder:SetFrameLevel(math.min(9000, base + level))
    local floor = under and under:GetFrameLevel() or base
    if self.below and addon.IsNumber(floor) then self.below:SetFrameLevel(math.max(0, floor - 1)) end
end

-- The border's textures, for callers that fade them together (from a state
-- the client may keep secret, through SetAlphaFromBoolean).
function Edge:Regions()
    local list = {}
    for _, key in ipairs({ "shadow", "gap", "rimTexture", "light", "soft" }) do
        if self[key] then list[#list + 1] = self[key] end
    end
    return list
end

function Edge:SetShown(shown)
    self.holder:SetShown(shown)
    if self.below then self.below:SetShown(shown) end
end

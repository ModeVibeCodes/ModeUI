local _, addon = ...
-- The one border factory (docs/DESIGN_LANGUAGE.md, "Borders"). A border is a
-- role (a preset: which rings it has, how far it reaches) drawn in a style
-- (Mode-Blizz, Mode-BlizzEmpty, Mode-Thin, Mode-Round) and a metal. It sits
-- outside its host: the 1px shadow ring, the metal band (a base ring with up
-- to three lighting layers), the 1px black line (on frames and windows just
-- inside the host's edge), and a soft drop below. Every
-- ring is sliced art (Shared/Style/EdgeData.lua names it) on a holder frame
-- scaled to one physical pixel per unit, so offsets and slice margins are whole
-- pixels at any UI scale. The innermost ring covers its own inner corner: no
-- masks.
local Style = addon.Style
local Tone = Style.Tone
local D = Style.EDGE_DATA

Style.EDGE_PRESETS = D.PRESETS
Style.EDGE_STYLES = D.STYLES

-- Every ring's art is an asset ("Edge" .. key), sliced at its shape's margin.
for key, ring in pairs(D.AllRings()) do
    Style.ASSETS["Edge" .. key] = { file = "Borders\\" .. key, slice = D.SHAPES[ring.shape].margin }
end

-- The style choices for a Border picker ({ id, label }), with None when asked.
function Style.EdgeStyleChoices(withNone)
    local list = {}
    for _, id in ipairs(D.STYLE_ORDER) do list[#list + 1] = { id = id, label = D.STYLES[id].label } end
    if withNone then list[#list + 1] = { id = "none", label = "None" } end
    return list
end
-- The metal choices for a Border Metal picker; "default" is the style's own.
function Style.EdgeMetalChoices()
    local list = { { id = "default", label = "Default" } }
    for _, id in ipairs(D.METAL_ORDER) do list[#list + 1] = { id = id, label = D.METAL_LABELS[id] } end
    return list
end
-- A saved style id that is a real style (anything else: nil, the role's default).
function Style.EdgeStyle(id) return D.STYLES[id] and id or nil end

local function Around(texture, holder, out, drop)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", holder, "TOPLEFT", -out, out - (drop or 0))
    texture:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", out, -out - (drop or 0))
end

local Edge = {}
Edge.__index = Edge
-- Every border, so a window can re-lay them after its scale changes.
local edges = setmetatable({}, { __mode = "k" })

function Style.RelayoutEdges()
    for edge in pairs(edges) do edge:Layout() end
end

-- Snapping: a host can sit between physical pixels (a UI scale that isn't
-- pixel perfect puts most whole-unit offsets there), and its 1px rings then
-- land on half pixels: one side full, the other faint or gone, specks at the
-- cut corners. A snapped edge moves its holder onto the nearest whole pixels
-- of the host's rect. Only a surface that re-snaps as it moves uses it
-- (Style.SnapEdges: the settings window, on show, page layout, scroll and
-- drag); a host that moves by itself (a nameplate) keeps the plain anchor.
local function Under(frame, root)
    for _ = 1, 40 do
        if frame == root then return true end
        frame = frame and frame.GetParent and frame:GetParent()
        if not frame then return false end
    end
    return false
end
function Style.SnapEdges(root)
    for edge in pairs(edges) do
        if edge.snapRoot ~= root then edge.snapRoot, edge.snap = root, Under(edge.host, root) end
        if edge.snap then edge:Place() end
    end
end
-- Snaps once on the next frame, after the client has laid the frames out.
local queued = {}
function Style.QueueSnapEdges(root)
    if not root or queued[root] then return end
    if not (C_Timer and C_Timer.After) then Style.SnapEdges(root); return end
    queued[root] = true
    C_Timer.After(0, function() queued[root] = nil; Style.SnapEdges(root) end)
end

-- A border of role `preset` for `host`. opts: level (frame levels above the
-- host, default 2), style and metal (default: the role's style and that
-- style's metal), color (a flat role's color), rim (the band's width, 1 or 2).
function Style.Edge(host, preset, opts)
    local def = assert(D.PRESETS[preset], "Style.Edge: unknown preset " .. tostring(preset))
    opts = opts or {}
    local edge = setmetatable({ host = host, preset = preset, def = def, rim = opts.rim or def.rim, color = opts.color,
        styleId = Style.EdgeStyle(opts.style) or def.style, metalId = opts.metal, textures = {} }, Edge)
    local holder = CreateFrame("Frame", nil, host)
    holder:SetAllPoints(host)
    holder:EnableMouse(false)
    holder:SetFrameLevel(host:GetFrameLevel() + (opts.level or 2))
    edge.holder = holder
    if def.soft then
        local below = CreateFrame("Frame", nil, host)
        below:SetAllPoints(host)
        below:EnableMouse(false)
        below:SetFrameLevel(math.max(0, host:GetFrameLevel() - 1))
        edge.below = below
        edge.soft = below:CreateTexture(nil, "BACKGROUND", nil, -8)
        Style.ApplyAsset(edge.soft, "Soft")
    end
    edges[edge] = true
    edge:Build()
    return edge
end

-- (Re)builds the rings for the current style and band width.
function Edge:Build()
    local rings = D.Rings(self.preset, self.styleId, self.rim)
    self.rings = rings
    self.shadow, self.gap, self.rimTexture = nil, nil, nil
    local sub = { shadow = 0, gap = 1 }
    local band = -1
    for i, ring in ipairs(rings) do
        local texture = self.textures[i]
        if not texture then texture = self.holder:CreateTexture(nil, "ARTWORK"); self.textures[i] = texture end
        if ring.kind == "band" then
            band = ring.profile and band + 1 or 0
            texture:SetDrawLayer("ARTWORK", math.max(0, band))
        else
            texture:SetDrawLayer("BORDER", sub[ring.kind])
        end
        Style.ApplyAsset(texture, "Edge" .. ring.key)
        texture:Show()
        if ring.kind == "shadow" then self.shadow = texture
        elseif ring.kind == "gap" then self.gap = texture
        elseif not self.rimTexture then self.rimTexture = texture end
    end
    for i = #rings + 1, #self.textures do self.textures[i]:Hide() end
    self:Layout()
    self:Paint()
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

-- The holder over its host: on the host's rect, or (snapped) on its nearest
-- whole physical pixels. Holder offsets are in physical pixels (PixelGrid).
function Edge:Place()
    local holder, host, N = self.holder, self.host, addon.IsNumber
    holder:ClearAllPoints()
    local factor = self.snap and Style.PixelFactor()
    local scale = factor and host:GetEffectiveScale()
    local l, b, w, h
    if N(scale, 0.01, 100) then l, b, w, h = host:GetLeft(), host:GetBottom(), host:GetWidth(), host:GetHeight() end
    if not (N(l) and N(b) and N(w) and N(h)) then holder:SetAllPoints(host); return end
    local k = scale / factor
    local function Off(v) v = v * k; return math.floor(v + 0.5) - v end
    holder:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", Off(l), Off(b))
    holder:SetPoint("TOPRIGHT", host, "TOPRIGHT", Off(l + w), Off(b + h))
end

-- Places every ring on whole physical pixels. Returns how far the band and
-- black line reach outside the host (the shadow ring left out).
function Edge:Layout()
    local px = Style.Pixel(self.host)
    self.px = px
    PixelGrid(self.holder, px)
    self:Place()
    if self.below then PixelGrid(self.below, px) end
    for i, ring in ipairs(self.rings) do Around(self.textures[i], self.holder, ring.out) end
    local depth = (self.def.gap == true and 1 or 0) + self.rim
    if self.soft then Around(self.soft, self.below, depth + 6, 1) end
    return depth
end

-- How far a preset's border reaches outside its host, in physical pixels (the
-- shadow ring, band and an outside black line; the soft drop is left out).
-- Every style reaches the same in a role.
function Style.EdgeReach(preset)
    local def = assert(D.PRESETS[preset], "Style.EdgeReach: unknown preset " .. tostring(preset))
    return (def.gap == true and 1 or 0) + def.rim + (def.shadow and 1 or 0)
end
-- The band and an outside black line alone (what a frame keeps inside its own rect).
function Style.EdgeDepth(preset)
    local def = assert(D.PRESETS[preset], "Style.EdgeDepth: unknown preset " .. tostring(preset))
    return (def.gap == true and 1 or 0) + def.rim
end

-- How far the border reaches outside the host, in the host's UI units.
function Edge:Outset()
    return ((self.def.gap == true and 1 or 0) + self.rim + (self.def.shadow and 1 or 0)) * (self.px or 1)
end

-- The metal the band is painted in: the chosen one, else the style's.
function Edge:Metal()
    local metal = Tone.metal[self.metalId] or Tone.metal[D.STYLES[self.styleId].metal]
    return metal
end

function Edge:Paint()
    local metal = self:Metal()
    -- A tint, a flat role or Mode-BlizzEmpty paints the band one color: its
    -- base rings only, the lighting layers hidden.
    local flat = self.tint or (self.def.flat and (self.color or Tone.mono.rimStrong))
        or (D.STYLES[self.styleId].light == "flat" and metal.mid)
    for i, ring in ipairs(self.rings) do
        local texture = self.textures[i]
        if ring.kind == "shadow" then
            if self.highlight then Style.Paint(texture, self.highlight)
            else Style.Paint(texture, Tone.shadow, Tone.shadowAlpha) end
        elseif ring.kind == "gap" then
            Style.Paint(texture, Tone.shadow)
        elseif flat then
            texture:SetShown(not ring.profile)
            if not ring.profile then Style.Paint(texture, flat) end
        else
            texture:Show()
            Style.Paint(texture, metal[ring.tone])
        end
    end
    if self.soft then Style.Paint(self.soft, Tone.shadow, Tone.softAlpha) end
end

-- Draws the border in another style and metal (nil: the role's style, the
-- style's metal; "default" is the style's metal too). The reach never changes.
function Edge:SetStyle(styleId, metalId)
    styleId = Style.EdgeStyle(styleId) or self.def.style
    metalId = Tone.metal[metalId] and metalId or nil
    if styleId == self.styleId and metalId == self.metalId then return end
    local rebuild = styleId ~= self.styleId
    self.styleId, self.metalId = styleId, metalId
    if rebuild then self:Build() else self:Paint() end
end

-- A custom band color (a state such as a dispel type, proc or aggro); nil
-- restores the style's metal.
function Edge:SetTint(color)
    self.tint = color
    self:Paint()
end

-- The 1px outer accent line: "accent" (Ivory), "specialty" (Rosewood), a color
-- table, or nil for none. Roles without a shadow ring take it as a tint.
function Edge:SetHighlight(kind)
    local color = kind and (type(kind) == "table" and kind or Style.Accent(kind)) or nil
    if self.shadow then self.highlight = color
    else self.tint = color end
    self:Paint()
end

-- Changes the band's width (1 or 2 pixels): its lighting, rings and layout.
function Edge:SetRim(rim)
    rim = rim == 2 and 2 or 1
    if rim == self.rim then return end
    self.rim = rim
    self:Build()
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

-- Shows or hides the soft drop alone (a window whose content draws under it,
-- the World Map's, would be shaded by it).
function Edge:SetDrop(shown)
    if self.below then self.below:SetShown(shown ~= false) end
end

-- The border's textures, for callers that fade them together (from a state
-- the client may keep secret, through SetAlphaFromBoolean).
function Edge:Regions()
    local list = {}
    for i = 1, #self.rings do list[#list + 1] = self.textures[i] end
    if self.soft then list[#list + 1] = self.soft end
    return list
end

function Edge:SetShown(shown)
    self.holder:SetShown(shown)
    if self.below then self.below:SetShown(shown) end
end

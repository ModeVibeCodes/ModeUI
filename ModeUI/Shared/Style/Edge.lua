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

-- The style a saved style draws as in the theme in use: under Mode-Obsidian
-- every Mode metal style is Mode-Obsidian and Mode-BlizzEmpty is
-- Mode-ObsidianEmpty (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme").
function Style.ThemeStyle(styleId) return D.ThemeStyle(styleId, Style.Theme and Style.Theme()) end

-- The style choices ({ id, label }), with None when asked. `themed`: the
-- theme in use's own styles (what a Border picker lists); otherwise every
-- style (what a module's settings check accepts, so a style picked under
-- any theme stays valid).
function Style.EdgeStyleChoices(withNone, themed)
    local list = {}
    local obsidian = Style.Theme and Style.Theme() == "obsidian"
    local orders = not themed and { D.STYLE_ORDER, D.OBSIDIAN_ORDER } or { obsidian and D.OBSIDIAN_ORDER or D.STYLE_ORDER }
    for _, order in ipairs(orders) do
        for _, id in ipairs(order) do list[#list + 1] = { id = id, label = D.STYLES[id].label } end
    end
    if withNone then list[#list + 1] = { id = "none", label = "None" } end
    return list
end
-- The metal choices for a Border Metal picker; "default" is the style's own.
function Style.EdgeMetalChoices()
    local list = { { id = "default", label = "Default" } }
    for _, id in ipairs(D.METAL_ORDER) do list[#list + 1] = { id = id, label = D.METAL_LABELS[id] } end
    return list
end
-- True for a style that paints its band one flat color (Mode-BlizzEmpty,
-- Mode-ObsidianEmpty), in the theme in use.
function Style.IsFlatStyle(id)
    local style = D.STYLES[Style.ThemeStyle(id)]
    return style ~= nil and style.light == "flat"
end
-- A saved style id that is a real style (anything else: nil, the role's default).
function Style.EdgeStyle(id) return D.STYLES[id] and id or nil end

local function Around(texture, holder, out, drop)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", holder, "TOPLEFT", -out, out - (drop or 0))
    texture:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", out, -out - (drop or 0))
end

-- Pieces: a ring drawn as eight textures, four corners 1:1 and four edges,
-- instead of one sliced texture (what Blizzard's NineSlice frames do). The
-- client draws a sliced texture on a region shorter than its art (64 rows)
-- scaled down: corners shrink to specks and a 1px edge to a fraction of a
-- pixel (owner, in game, November 18, 2026: thin resource bars showed only
-- corner specks). A border on a thin host opts in (opts.pieces).
local function Pieces(parts, holder, out, spec)
    local m, u, v = spec.margin, spec.margin / spec.w, spec.margin / spec.h
    local tl, t, tr, l, r, bl, b, br = parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]
    for _, part in ipairs(parts) do part:ClearAllPoints() end
    tl:SetPoint("TOPLEFT", holder, "TOPLEFT", -out, out); tl:SetSize(m, m); tl:SetTexCoord(0, u, 0, v)
    tr:SetPoint("TOPRIGHT", holder, "TOPRIGHT", out, out); tr:SetSize(m, m); tr:SetTexCoord(1 - u, 1, 0, v)
    bl:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", -out, -out); bl:SetSize(m, m); bl:SetTexCoord(0, u, 1 - v, 1)
    br:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", out, -out); br:SetSize(m, m); br:SetTexCoord(1 - u, 1, 1 - v, 1)
    t:SetPoint("TOPLEFT", holder, "TOPLEFT", m - out, out); t:SetPoint("TOPRIGHT", holder, "TOPRIGHT", out - m, out)
    t:SetHeight(m); t:SetTexCoord(u, 1 - u, 0, v)
    b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", m - out, -out); b:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", out - m, -out)
    b:SetHeight(m); b:SetTexCoord(u, 1 - u, 1 - v, 1)
    l:SetPoint("TOPLEFT", holder, "TOPLEFT", -out, out - m); l:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", -out, m - out)
    l:SetWidth(m); l:SetTexCoord(0, u, v, 1 - v)
    r:SetPoint("TOPRIGHT", holder, "TOPRIGHT", out, out - m); r:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", out, m - out)
    r:SetWidth(m); r:SetTexCoord(1 - u, 1, v, 1 - v)
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
-- A host inside a frame the game forbids to addons (an aura icon on
-- Blizzard's containers) can't be walked up: GetParent errors, so the walk
-- stops there; such a host is never in the settings window.
local function Under(frame, root)
    for _ = 1, 40 do
        if frame == root then return true end
        if not (frame and frame.GetParent) then return false end
        if frame.IsForbidden then
            local okForbidden, forbidden = pcall(frame.IsForbidden, frame)
            if not okForbidden or forbidden == true then return false end
        end
        local ok, parent = pcall(frame.GetParent, frame)
        if not ok then return false end
        frame = parent
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
-- style's metal), color (a flat role's color), rim (the band's width, 1 or 2),
-- pieces (each ring as eight textures: for hosts shorter than the art).
function Style.Edge(host, preset, opts)
    local def = assert(D.PRESETS[preset], "Style.Edge: unknown preset " .. tostring(preset))
    opts = opts or {}
    local edge = setmetatable({ host = host, preset = preset, def = def, rim = opts.rim or def.rim, color = opts.color,
        styleId = Style.ThemeStyle(Style.EdgeStyle(opts.style) or def.style), metalId = opts.metal, textures = {}, parts = {},
        pieces = opts.pieces == true }, Edge)
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
    self.shadow, self.gap, self.rimTexture, self.rimParts = nil, nil, nil, nil
    local sub = { shadow = 0, gap = 1 }
    local band = -1
    for i, ring in ipairs(rings) do
        local texture = self.textures[i]
        if not texture then texture = self.holder:CreateTexture(nil, "ARTWORK"); self.textures[i] = texture end
        -- One texture, or eight (the first is the ring's own: its top left corner).
        local parts = self.parts[i] or { texture }
        self.parts[i] = parts
        for p = 2, self.pieces and 8 or 1 do parts[p] = parts[p] or self.holder:CreateTexture(nil, "ARTWORK") end
        if ring.kind == "band" then band = ring.profile and band + 1 or 0 end
        for p = 1, self.pieces and 8 or 1 do
            local part = parts[p]
            if ring.kind == "band" then part:SetDrawLayer("ARTWORK", math.max(0, band))
            else part:SetDrawLayer("BORDER", sub[ring.kind]) end
            Style.ApplyAsset(part, "Edge" .. ring.key)
            if self.pieces and part.ClearTextureSlice then part:ClearTextureSlice() end
            part:Show()
        end
        if ring.kind == "shadow" then self.shadow = texture
        elseif ring.kind == "gap" then self.gap = texture
        elseif not self.rimTexture then self.rimTexture, self.rimParts = texture, parts end
    end
    for i = #rings + 1, #self.textures do
        for _, part in ipairs(self.parts[i] or { self.textures[i] }) do part:Hide() end
    end
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
    for i, ring in ipairs(self.rings) do
        if self.pieces then Pieces(self.parts[i], self.holder, ring.out, D.SHAPES[ring.shape])
        else Around(self.textures[i], self.holder, ring.out) end
    end
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
-- The shortest host, in physical pixels, a border of `preset` in style
-- `styleId` (and band width `rim`, the role's by default) fits ("Choosing a
-- border", Height floor): each ring's corners are drawn 1:1, so a ring must be
-- at least two slice margins tall, and a ring `out` pixels outside the host is
-- the host's height plus 2 * out.
function Style.EdgeMinHeight(preset, styleId, rim)
    local floor = 1
    local style = Style.ThemeStyle(Style.EdgeStyle(styleId) or D.PRESETS[preset] and D.PRESETS[preset].style)
    for _, ring in ipairs((D.Rings(preset, style, rim))) do
        floor = math.max(floor, 2 * D.SHAPES[ring.shape].margin - 2 * ring.out)
    end
    return floor
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
    local style = D.STYLES[self.styleId]
    local flat = self.tint or (self.def.flat and (self.color or Tone.mono.rimStrong))
        or (style.light == "flat" and metal[style.flatTone or "mid"])
    for i, ring in ipairs(self.rings) do
        for _, texture in ipairs(self.parts[i]) do
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
    end
    if self.soft then Style.Paint(self.soft, Tone.shadow, Tone.softAlpha) end
end

-- Draws the border in another style and metal (nil: the role's style, the
-- style's metal; "default" is the style's metal too). The reach never changes.
function Edge:SetStyle(styleId, metalId)
    styleId = Style.ThemeStyle(Style.EdgeStyle(styleId) or self.def.style)
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

-- The band's base ring: one texture, or its eight pieces (what a caller
-- that recolors the rim itself, such as an aura container, takes).
function Edge:RimTextures()
    local list = {}
    for _, texture in ipairs(self.rimParts or { self.rimTexture }) do list[#list + 1] = texture end
    return list
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
    for i = 1, #self.rings do
        for _, texture in ipairs(self.parts[i]) do list[#list + 1] = texture end
    end
    if self.soft then list[#list + 1] = self.soft end
    return list
end

function Edge:SetShown(shown)
    self.holder:SetShown(shown)
    if self.below then self.below:SetShown(shown) end
end

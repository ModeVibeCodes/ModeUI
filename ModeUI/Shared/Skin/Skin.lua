local _, addon = ...
local Kit = addon.Kit

-- Re-skinning Blizzard's frames in the Mode look, shared by Chat and
-- Blizzard Windows. Blizzard's art is faded (alpha only) or hidden, never
-- destroyed, so its own code keeps running; ModeUI's textures go on top.
-- Nothing is stored on Blizzard's frame tables: ModeUI's pieces and state
-- live in weak tables keyed by the frame. Every helper is a plain widget
-- call or a post-hook (hooksecurefunc), so Blizzard's code path is never
-- replaced. Pixel sizes come from Kit.PixelSize.
local Skin = {}
addon.Skin = Skin
local FLAT = Kit.FLAT
local IsPublic = addon.IsPublic

-- ModeUI's pieces per Blizzard frame or region, and frames already hooked.
Skin.parts = setmetatable({}, { __mode = "k" })
Skin.hooked = setmetatable({}, { __mode = "k" })

-- The Mode colors used by skins: the window fill, rims, fields, the
-- selected segment, text and the cyan accent (Theme.lua's Mode palette).
local function RGB(r, g, b) return { r / 255, g / 255, b / 255 } end
Skin.colors = {
    window = RGB(11, 11, 13), card = RGB(18, 19, 22), cardRim = RGB(30, 32, 36), rim = Kit.onyx.border,
    field = RGB(14, 15, 17), fieldRim = RGB(42, 45, 50), selected = RGB(34, 38, 43), hover = RGB(34, 38, 43),
    heading = RGB(242, 242, 242), label = RGB(196, 200, 206), muted = RGB(138, 143, 150), disabled = RGB(102, 102, 110),
    accent = Kit.palette.accent, track = RGB(22, 24, 27), thumb = RGB(74, 79, 86),
}

-- A value rounded to whole physical pixels, at least one.
function Skin.Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end

-- Runs `fn` once per key; used to install a hook only once.
function Skin.Once(frame, key, fn)
    local done = Skin.hooked[frame]
    if not done then done = {}; Skin.hooked[frame] = done end
    if done[key] then return false end
    done[key] = true
    fn()
    return true
end

-- Fades a Blizzard region or frame to nothing. Alpha survives Show, Hide and
-- SetAtlas, so the art stays gone when Blizzard toggles it.
function Skin.Fade(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

-- Fades every texture directly on `frame` (not its children) except ModeUI's
-- own and those in `keep`.
function Skin.FadeTextures(frame, keep)
    if not frame or not frame.GetRegions then return end
    local own = Skin.parts[frame]
    for _, region in ipairs({ frame:GetRegions() }) do
        local mine = own and own.regions and own.regions[region]
        if not mine and not (keep and keep[region]) and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end
end

-- Hides a region or frame for good: Hide now, and again whenever Blizzard
-- shows it. Release lets Blizzard show it again (from the next Show).
Skin.suppressed = setmetatable({}, { __mode = "k" })
function Skin.Suppress(region)
    if not region or not region.Hide then return end
    Skin.suppressed[region] = true
    region:Hide()
    Skin.Once(region, "suppress", function()
        local function Again(shown) if Skin.suppressed[shown] then shown:Hide() end end
        hooksecurefunc(region, "Show", Again)
        if region.SetShown then hooksecurefunc(region, "SetShown", Again) end
    end)
end
function Skin.Release(region) Skin.suppressed[region] = nil end

-- Keeps a frame at the alpha `getter(frame)` returns: Blizzard's fades call
-- SetAlpha every frame, and this puts ModeUI's value back right after. A nil
-- answer leaves Blizzard's alpha alone.
local pinning = setmetatable({}, { __mode = "k" })
Skin.pins = setmetatable({}, { __mode = "k" })
function Skin.PinAlpha(frame, getter)
    Skin.pins[frame] = getter
    Skin.Once(frame, "pinAlpha", function()
        hooksecurefunc(frame, "SetAlpha", function(self)
            if pinning[self] then return end
            local pin = Skin.pins[self]
            local alpha = pin and pin(self)
            if alpha == nil then return end
            pinning[self] = true
            self:SetAlpha(alpha)
            pinning[self] = nil
        end)
    end)
    local alpha = getter and getter(frame)
    if alpha ~= nil then frame:SetAlpha(alpha) end
end
function Skin.Unpin(frame) Skin.pins[frame] = nil end

-- ModeUI's pieces for a host: a fill and a hollow one-pixel rim, created on
-- first use under the host's own art (BACKGROUND, lowest sublevels).
function Skin.Panel(host, layer, sublevel)
    local parts = Skin.parts[host]
    if parts and parts.fill then return parts end
    parts = parts or { regions = {} }
    Skin.parts[host] = parts
    parts.fill = host:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or -8)
    parts.fill:SetTexture(FLAT)
    parts.rim = Kit.Rim(host, layer or "BACKGROUND", (sublevel or -8) + 1)
    parts.regions[parts.fill] = true
    for _, edge in ipairs(parts.rim) do parts.regions[edge] = true end
    return parts
end

-- Lays a panel over `box` (any region or frame; the panel's textures can
-- belong to another frame), filled with `fill` at `alpha` inside a `rimColor`
-- rim `thickness` units thick (0 for none). The rim is hollow, so a
-- see-through fill never takes on its color.
function Skin.PaintPanel(parts, box, fill, alpha, rimColor, thickness)
    Kit.Inset(parts.fill, box, thickness)
    Kit.Tint(parts.fill, fill, alpha)
    Kit.PlaceRim(parts.rim, box, thickness, 0, rimColor or fill, 1)
end

-- Font, flags and the crisp one-pixel shadow on a Blizzard font string or
-- font instance (chat frames and edit boxes are font instances too). A size
-- of nil keeps the region's own size. FontStrings answer SetFont with
-- true or false; a chat frame's SetFont (FontableFrameMixin, Lua) answers
-- nothing, so only an explicit false falls back to the game font.
function Skin.Font(region, path, size, outline, shadow, px)
    if not region or not region.SetFont then return false end
    local _, current = region:GetFont()
    size = size or (IsPublic(current) and current) or 12
    local flags = outline and "OUTLINE" or ""
    if region:SetFont(path, size, flags) == false then region:SetFont(addon.Media.gameFont, size, flags) end
    if region.SetShadowColor then
        region:SetShadowColor(0, 0, 0, shadow and 1 or 0)
        region:SetShadowOffset(shadow and px or 0, shadow and -px or 0)
    end
    return true
end

-- Swaps only the face of a Blizzard font string: its size and flags stay
-- (the text keeps the game's sizes and outlines, in the Mode face).
function Skin.Face(region, path)
    if not region or not region.GetFont or not region.SetFont then return false end
    local current, size, flags = region:GetFont()
    if not (IsPublic(size) and type(size) == "number" and size > 0) or current == path then return false end
    flags = IsPublic(flags) and flags or ""
    return region:SetFont(path, size, flags) ~= false
end

-- A crisp border drawn on its own frame above `host`'s children (as the unit
-- frames' rim sits above their bars): four flat edges, `thickness` thick,
-- square corners. The frame never takes the mouse. `lift` raises it above
-- the host's own frame level (child art like a NineSlice can sit 500 up).
function Skin.Edge(host, lift)
    local parts = Skin.parts[host] or { regions = {} }
    Skin.parts[host] = parts
    if not parts.edge then
        local edge = CreateFrame("Frame", nil, host)
        edge:EnableMouse(false)
        edge:SetAllPoints(host)
        parts.edge, parts.edgeRim = edge, Kit.Rim(edge, "OVERLAY", 7)
    end
    local level = host:GetFrameLevel()
    if IsPublic(level) and type(level) == "number" then parts.edge:SetFrameLevel(math.min(9000, level + (lift or 1))) end
    return parts
end
function Skin.PaintEdge(parts, thickness, color, alpha)
    Kit.PlaceRim(parts.edgeRim, parts.edge, thickness, 0, color, alpha or 1)
    parts.edge:SetShown(thickness > 0)
end

-- The Mode design language ---------------------------------------------------
-- Windows and their controls (docs/DESIGN_LANGUAGE.md, "Windows and panels"):
-- Graphite surfaces with Mode textures, Style.Edge borders (`window` on a
-- window, `control` on its buttons and fields, `card` on insets), Ivory for
-- hover, focus and the chosen tab. Every color is a Style.Tone token.
-- (Skin.colors and Skin.Panel above stay for the modules not rebuilt yet.)
local Style = addon.Style
local Tone = Style.Tone
local G = Tone.graphite
Skin.mode = {
    panel = G.panel, title = G.raised, line = G.line, field = G.base, face = G.raised, chosen = G.track,
    track = G.track, thumb = G.rimStrong, heading = G.white, text = G.text, label = G.secondary, muted = G.muted,
    disabled = G.rim, accent = Tone.ivory, card = G.raised, cardRim = G.line, fieldRim = G.rim,
}
local TILED = { Panel = true, Title = true }

-- A Mode box for `host`: a face texture (on `opts.faceHost`, default the
-- host, at `opts.layer`/`opts.sublevel`) and, with `preset`, a Style.Edge on
-- a frame of its own that follows the painted box (`opts.level` levels above
-- the host). Made once; returns the host's parts.
function Skin.Box(host, preset, opts)
    opts = opts or {}
    local parts = Skin.parts[host] or { regions = {} }
    Skin.parts[host] = parts
    if not parts.face then
        local on = opts.faceHost or host
        parts.face = on:CreateTexture(nil, opts.layer or "BACKGROUND", nil, opts.sublevel or -8)
        parts.regions[parts.face] = true
        if on ~= host then
            local other = Skin.parts[on] or { regions = {} }
            Skin.parts[on] = other
            other.regions[parts.face] = true
        end
    end
    if preset and not parts.modeEdge then
        local frame = CreateFrame("Frame", nil, host)
        frame:EnableMouse(false)
        frame:SetAllPoints(host)
        parts.edgeFrame = frame
        parts.edgeLevel = opts.level or 1
        parts.modeEdge = Style.Edge(frame, preset, { level = 1 })
    end
    return parts
end

-- Paints a box over `box` (a region or frame; the host by default): the face
-- in the Mode texture `key` (Solid, Button, Matte, Panel, Title...) and
-- `color` at `alpha`; the edge shown unless `edge` is false, its outer line
-- lit with `highlight` ("accent", a color, or nil).
-- A texture with a lift draws as its base multiplied by the color plus the
-- white lift on its own texture above it (docs/DESIGN_LANGUAGE.md, "Bars",
-- Light): the single baked file would multiply its light away on Graphite.
function Skin.PaintBox(parts, box, key, color, alpha, edge, highlight)
    local face = parts.face
    local asset = Style.ASSETS[key] or {}
    local base = asset.fill or key
    if parts.faceKey ~= key then
        Style.ApplyAsset(face, base)
        parts.faceKey = key
        if asset.lift and not parts.lift then
            local layer, sublevel = face:GetDrawLayer()
            parts.lift = face:GetParent():CreateTexture(nil, layer, nil, math.min(7, (sublevel or 0) + 1))
            parts.regions[parts.lift] = true
            local owner = Skin.parts[face:GetParent()]
            if owner and owner ~= parts then owner.regions[parts.lift] = true end
        end
        if parts.lift then
            if asset.lift then Style.ApplyAsset(parts.lift, asset.lift) end
            parts.lift:SetShown(asset.lift ~= nil)
        end
    end
    face:ClearAllPoints(); face:SetAllPoints(box)
    Style.Paint(face, color, alpha)
    if parts.lift and asset.lift then
        parts.lift:ClearAllPoints(); parts.lift:SetAllPoints(box)
        Style.Paint(parts.lift, Tone.mono.white, alpha)
    end
    if TILED[base] and box.GetSize then
        local width, height = box:GetSize()
        if addon.IsNumber(width, 1) and addon.IsNumber(height, 1) then Style.TileCoords(face, base, width, height, Kit.PixelSize(box)) end
    elseif face.SetTexCoord then
        face:SetTexCoord(0, 1, 0, 1)
    end
    if parts.modeEdge then
        local frame = parts.edgeFrame
        frame:ClearAllPoints(); frame:SetAllPoints(box)
        local host = frame:GetParent()
        local level = host:GetFrameLevel()
        -- The rim rides above the host's children; its soft drop stays under the host.
        if addon.IsNumber(level) then frame:SetFrameLevel(math.min(9000, level + parts.edgeLevel)); parts.modeEdge:SetLevel(1, host) end
        parts.modeEdge:SetShown(edge ~= false)
        parts.modeEdge:Layout()
        parts.modeEdge:SetHighlight(highlight)
    end
end

-- Text in the Mode colors: `color` a Skin.mode token.
function Skin.Ink(text, color)
    if text and text.SetTextColor then text:SetTextColor(color[1], color[2], color[3], 1) end
end

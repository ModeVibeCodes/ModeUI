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

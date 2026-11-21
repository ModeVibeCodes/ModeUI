local _, addon = ...
-- The Mode texture registry (docs/DESIGN_LANGUAGE.md, "Texture library"). Every
-- texture ModeUI draws from its own art is a key here; the files are generated
-- by tools/build_mode_assets.lua. Code applies keys, never paths.
local Style = addon.Style or {}
addon.Style = Style

-- ModeUI's texture folder (Media.Textures' keys sit under it), and the Mode
-- art's folder inside it.
Style.TEXTURE_ROOT = "Interface\\AddOns\\ModeUI\\Media\\Textures\\"
local BASE = Style.TEXTURE_ROOT .. "Mode\\"
Style.ASSET_BASE = BASE

-- file: path under BASE. slice: nine-slice margins in source pixels. tile: drawn
-- 1:1 and repeated (texture coordinates follow the region's size). fill/lift:
-- how Style.Bar draws a bar texture (a fill multiplied by the bar color, plus a
-- white overlay adding light; unregistered keys like Surface are surfaces
-- only). lsm: the LibSharedMedia name, so other addons can
-- use it too (statusbar and background).
Style.ASSETS = {
    -- Borders (white, tinted): every ring's art is "Edge<key>", registered by
    -- Shared/Style/Edge.lua from Shared/Style/EdgeData.lua; the portrait
    -- ring's lighting discs are "Ring<profile>", registered by Icon.lua.
    Soft = { file = "Borders\\Soft", slice = 12 },
    -- Bars and surfaces (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme").
    -- Mode-FG: the dark glass fill (a base multiplied by the color and a
    -- white lift over it); every bar's fill and every panel, title strip,
    -- button face and card. Mode-BG: the lighter graphite empty part, tinted
    -- Slate. Solid: a flat fill. The Mode-Blizz textures (Matte, Gradient,
    -- Button, Glass, Cast, Panel, Title and the old BG) were retired on
    -- November 20, 2026 (archive/mode-blizz/).
    Solid = { file = "Bars\\Solid", lsm = "Mode Solid" },
    FG = { file = "Bars\\FG", fill = "FGBase", lift = "FGLift", lsm = "Mode-FG" },
    FGBase = { file = "Bars\\FGBase" },
    FGLift = { file = "Bars\\FGLift" },
    BG = { file = "Bars\\BG", lsm = "Mode-BG" },
    -- The surface of large panels (windows, chat, tooltips, meters, menus): a
    -- flat fill with the approved mock's soft sheen (white 4.5% at the top,
    -- gone 40% down; no top line, which would show as a band when stretched).
    Surface = { file = "Bars\\Solid", fill = "Solid", lift = "SurfaceLift" },
    SurfaceLift = { file = "Bars\\SurfaceLift" },
    Shield = { file = "Bars\\Shield", tile = true, lsm = "Mode Shield" },
    CometHead = { file = "Bars\\CometHead" },
    CometTrail = { file = "Bars\\CometTrail" },
    LineGlow = { file = "Bars\\LineGlow" },
    TextGlow = { file = "Glows\\TextGlow" },
    -- The Prism glow behind a frame on mouseover and focus (sliced).
    Prism = { file = "Glows\\Prism", slice = 14 },
    -- Controls and masks.
    Knob = { file = "Controls\\Knob", slice = 3 },
    Blade = { file = "Controls\\Blade" },
    Circle = { file = "Masks\\Circle" },
}

-- Module icons (white line glyphs, tinted): Style.ASSETS["Icon" .. name].
Style.ICONS = { "Home", "UnitFrames", "GroupFrames", "Nameplates", "ActionBars", "DamageMeters", "Chat", "Windows",
    "Tooltip", "Bags", "Minimap", "Profiles", "Optimizations", "ClassColors", "Cooldowns", "Auras", "Back" }
for _, name in ipairs(Style.ICONS) do Style.ASSETS["Icon" .. name] = { file = "Icons\\" .. name } end
-- Glyphs for controls and marks, the same white line art: Clean Up (a broom)
-- and Quest (a disc with "!" cut out).
Style.GLYPHS = { "CleanUp", "Quest" }
for _, name in ipairs(Style.GLYPHS) do Style.ASSETS["Icon" .. name] = { file = "Icons\\" .. name } end

-- The bar textures every picker offers, in menu order ("Mode" heading, short names).
Style.BAR_TEXTURES = { "FG", "BG", "Solid", "Shield" }

-- Saved texture choices from before November 20, 2026 and the choice each
-- became: empty parts Mode-BG, every fill and surface Mode-FG (the look step
-- in Shared/Runtime/DB.lua moves saved ones; until then they draw as these).
Style.OLD_MEDIA = {
    ["media:Mode BG"] = "media:Mode-BG", ["media:Mode-Obsidian Track"] = "media:Mode-BG",
    ["media:Mode-Obsidian"] = "media:Mode-FG", ["media:Mode Matte"] = "media:Mode-FG",
    ["media:Mode Gradient"] = "media:Mode-FG", ["media:Mode Button"] = "media:Mode-FG",
    ["media:Mode Glass"] = "media:Mode-FG", ["media:Mode Cast"] = "media:Mode-FG",
    ["media:Mode Panel"] = "media:Mode-FG", ["media:Mode Title"] = "media:Mode-FG",
}

-- The asset behind a bar texture choice ("media:Mode-<Name>"), and its key.
local byMedia
function Style.MediaAsset(choice)
    if type(choice) ~= "string" then return end
    choice = Style.OLD_MEDIA[choice] or choice
    if not byMedia then
        byMedia = {}
        for key, asset in pairs(Style.ASSETS) do if asset.lsm then byMedia["media:" .. asset.lsm] = key end end
    end
    local key = byMedia[choice]
    if key then return Style.ASSETS[key], key end
end

function Style.AssetPath(key)
    local asset = Style.ASSETS[key]
    return asset and (BASE .. asset.file) or nil
end

-- Sets a texture to an asset (wrap, slice margins). Returns false, leaving the
-- texture clear, if the key or the file is unknown, so a missing file shows
-- nothing rather than a solid block.
function Style.ApplyAsset(texture, key)
    local asset = Style.ASSETS[key]
    if not asset then return false end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexCoord(0, 1, 0, 1)
    local wrap = asset.tile and "REPEAT" or "CLAMP"
    local ok = texture:SetTexture(BASE .. asset.file, wrap, wrap)
    if ok == false then texture:SetTexture(nil); return false end
    if asset.slice and texture.SetTextureSliceMargins then
        local m = asset.slice
        texture:SetTextureSliceMargins(m, m, m, m)
    end
    return true
end

-- Source sizes of the tiled assets (texture coordinates map them 1:1).
local TILE_SIZE = { Shield = { 32, 32 } }
Style.TILE_SIZE = TILE_SIZE

-- Texture coordinates that draw a tiled asset 1:1 over a region `width` x
-- `height` (UI units) with `px` UI units per physical pixel.
function Style.TileCoords(texture, key, width, height, px)
    local size = TILE_SIZE[key]
    if not size or not (width and height) or width <= 0 or height <= 0 then return end
    px = px or 1
    texture:SetTexCoord(0, width / px / size[1], 0, height / px / size[2])
end

-- Registers the Mode bar textures with LibSharedMedia (statusbar and background),
-- only for files the client reports as present.
function Style.RegisterAssets(library)
    if not (library and type(library.Register) == "function") then return end
    local known = C_UIFileAsset and C_UIFileAsset.IsKnownFile
    for _, key in ipairs(Style.BAR_TEXTURES) do
        local asset = Style.ASSETS[key]
        local path = BASE .. asset.file
        local present = true
        if known then
            local ok, result = pcall(known, path .. ".tga")
            present = ok and addon.IsPublic(result) and result == true
        end
        if present and asset.lsm then
            library:Register("statusbar", asset.lsm, path)
            library:Register("background", asset.lsm, path)
        end
    end
end

local _, addon = ...
-- The Mode texture registry (docs/DESIGN_LANGUAGE.md, "Texture library"). Every
-- texture ModeUI draws from its own art is a key here; the files are generated
-- by tools/build_mode_assets.lua. Code applies keys, never paths.
local Style = addon.Style or {}
addon.Style = Style

local BASE = "Interface\\AddOns\\ModeUI\\Media\\Textures\\Mode\\"
Style.ASSET_BASE = BASE

-- file: path under BASE. slice: nine-slice margins in source pixels. tile: drawn
-- 1:1 and repeated (texture coordinates follow the region's size). fill/lift:
-- how Style.Bar draws a bar texture (a fill multiplied by the bar color, plus a
-- white overlay adding light). lsm: the LibSharedMedia name, so other addons can
-- use it too (statusbar and background).
Style.ASSETS = {
    -- Borders (white, tinted): Mode Empty rims, Mode Light lighting, shadow and gap.
    Rim1 = { file = "Borders\\Rim1", slice = 5 },
    Rim2 = { file = "Borders\\Rim2", slice = 5 },
    Edge1 = { file = "Borders\\Edge1", slice = 5 },
    Edge2 = { file = "Borders\\Edge2", slice = 5 },
    Sheen1 = { file = "Borders\\Sheen1", slice = 5 },
    Shadow = { file = "Borders\\Shadow", slice = 6 },
    Gap = { file = "Borders\\Gap", slice = 4 },
    Soft = { file = "Borders\\Soft", slice = 12 },
    RingSheen = { file = "Borders\\RingSheen" },
    -- Bars.
    Solid = { file = "Bars\\Solid", lsm = "Mode Solid" },
    Matte = { file = "Bars\\Matte", lsm = "Mode Matte" },
    BG = { file = "Bars\\BG", lsm = "Mode BG" },
    Gradient = { file = "Bars\\Gradient", fill = "Solid", lift = "GradientLift", lsm = "Mode Gradient" },
    GradientLift = { file = "Bars\\GradientLift" },
    Button = { file = "Bars\\Button", fill = "ButtonBase", lift = "ButtonLift", lsm = "Mode Button" },
    ButtonBase = { file = "Bars\\ButtonBase" },
    ButtonLift = { file = "Bars\\ButtonLift" },
    Glass = { file = "Bars\\Glass", fill = "GlassBase", lift = "GlassLift", lsm = "Mode Glass" },
    GlassBase = { file = "Bars\\GlassBase" },
    GlassLift = { file = "Bars\\GlassLift" },
    Cast = { file = "Bars\\Cast", fill = "CastBase", lift = "CastLift", lsm = "Mode Cast" },
    CastBase = { file = "Bars\\CastBase" },
    CastLift = { file = "Bars\\CastLift" },
    Panel = { file = "Bars\\Panel", tile = true, lift = "PanelLift", lsm = "Mode Panel" },
    PanelLift = { file = "Bars\\PanelLift" },
    Title = { file = "Bars\\Title", tile = true, lsm = "Mode Title" },
    Shield = { file = "Bars\\Shield", tile = true, lsm = "Mode Shield" },
    CometHead = { file = "Bars\\CometHead" },
    CometTrail = { file = "Bars\\CometTrail" },
    LineGlow = { file = "Bars\\LineGlow" },
    -- Controls and masks.
    Knob = { file = "Controls\\Knob", slice = 3 },
    Blade = { file = "Controls\\Blade" },
    Circle = { file = "Masks\\Circle" },
}

-- Module icons (white line glyphs, tinted): Style.ASSETS["Icon" .. name].
Style.ICONS = { "Home", "UnitFrames", "GroupFrames", "Nameplates", "ActionBars", "DamageMeters", "Chat", "Windows",
    "Tooltip", "Bags", "Minimap", "Profiles", "Optimizations", "ClassColors", "Cooldowns", "Back" }
for _, name in ipairs(Style.ICONS) do Style.ASSETS["Icon" .. name] = { file = "Icons\\" .. name } end

-- The bar textures every picker offers, in menu order ("Mode" heading, short names).
Style.BAR_TEXTURES = { "Solid", "Matte", "BG", "Gradient", "Button", "Glass", "Cast", "Panel", "Title", "Shield" }

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
local TILE_SIZE = { Panel = { 256, 64 }, Title = { 128, 128 }, Shield = { 32, 32 } }
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

local _, addon = ...
-- Geist, the Mode design language's one typeface (docs/DESIGN_LANGUAGE.md,
-- "Text"): four static weights, SIL OFL 1.1 (Media/Fonts/Geist/OFL.txt).
-- Geist covers Latin and Cyrillic; other locales fall back to Blizzard's font.
local Style = addon.Style or {}
addon.Style = Style

local BASE = "Interface\\AddOns\\ModeUI\\Media\\Fonts\\Geist\\Geist-"
Style.FONT_WEIGHTS = { regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold" }
-- LibSharedMedia names; "Mode Geist" is the default everywhere.
Style.FONT_NAMES = { regular = "Mode Geist", medium = "Mode Geist Medium", semibold = "Mode Geist SemiBold", bold = "Mode Geist Bold" }
Style.FONT_DEFAULT = "Mode Geist"
-- LibSharedMedia language bits: western (128) + ruRU (2).
local LANGUAGES = 130

-- Locales Geist has no glyphs for.
local function NativeOnly()
    local locale = GetLocale and GetLocale()
    return locale == "koKR" or locale == "zhCN" or locale == "zhTW"
end

function Style.FontPath(weight)
    if NativeOnly() then return STANDARD_TEXT_FONT end
    return BASE .. (Style.FONT_WEIGHTS[weight or "regular"] or "Regular") .. ".ttf"
end

-- `path` in another Geist weight when it is one of the Geist files; any other
-- font is returned unchanged (a player's own font keeps its one weight).
function Style.Weighted(path, weight)
    if type(path) == "string" and path:sub(1, #BASE) == BASE then return Style.FontPath(weight) end
    return path
end

-- Sets a font string to Geist at `size` (UI units) with `flags` ("" by
-- default; "OUTLINE" or "THICKOUTLINE" only as a player choice). Falls back
-- to Blizzard's font if the client refuses the file.
function Style.Font(fontString, size, weight, flags)
    local ok = fontString:SetFont(Style.FontPath(weight), size, flags or "")
    if not ok then fontString:SetFont(STANDARD_TEXT_FONT, size, flags or "") end
    return ok
end

function Style.RegisterFonts(library)
    if not (library and type(library.Register) == "function") or NativeOnly() then return end
    local known = C_UIFileAsset and C_UIFileAsset.IsKnownFile
    for weight, name in pairs(Style.FONT_NAMES) do
        local path = Style.FontPath(weight)
        local present = true
        if known then
            local ok, result = pcall(known, path)
            present = ok and addon.IsPublic(result) and result == true
        end
        if present then library:Register("font", name, path, LANGUAGES) end
    end
end

-- Register at load, so every addon's LibSharedMedia lists see the Mode media
-- from the start (LibSharedMedia is loaded from Libs/ before this file).
local library = LibStub and LibStub("LibSharedMedia-3.0", true)
if library then
    Style.RegisterAssets(library)
    Style.RegisterFonts(library)
end

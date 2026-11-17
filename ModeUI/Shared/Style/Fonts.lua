local _, addon = ...
-- The Mode typeface (docs/DESIGN_LANGUAGE.md, "Text"). Since November 15,
-- 2026 (owner's decision) it is Expressway when the client has it: the copy
-- an installed addon ships (EllesmereUI, AyijeUI) or any LibSharedMedia
-- "Expressway" a media pack registers (Shared/Media/Media.lua finds them).
-- ModeUI does not ship Expressway (a commercial Typodermic font; see
-- THIRD_PARTY_NOTICES.md). Without it the typeface is Geist: four static
-- weights, SIL OFL 1.1 (Media/Fonts/Geist/OFL.txt), Latin and Cyrillic.
-- Other locales fall back to Blizzard's font.
-- Modules store the LibSharedMedia name "Mode" (Style.FONT_DEFAULT), which
-- points at whichever typeface the client has (registered once media is
-- discovered: Style.RegisterTypeface).
local Style = addon.Style or {}
addon.Style = Style

local BASE = "Interface\\AddOns\\ModeUI\\Media\\Fonts\\Geist\\Geist-"
-- Mode Script (docs/DESIGN_LANGUAGE.md, "Text"; owner's pick, November 17,
-- 2026): Damion, a bold flowing script (SIL OFL 1.1, Media/Fonts/Damion/OFL.txt),
-- for the word "Mode" in ModeUI's own wordmark only, in Ivory. It draws one
-- fixed Latin word, so every locale uses it.
Style.SCRIPT_FONT = "Interface\\AddOns\\ModeUI\\Media\\Fonts\\Damion\\Damion-Regular.ttf"
Style.FONT_WEIGHTS = { regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold" }
-- LibSharedMedia names: "Mode" (the default everywhere) and Geist's weights.
Style.FONT_NAMES = { regular = "Mode Geist", medium = "Mode Geist Medium", semibold = "Mode Geist SemiBold", bold = "Mode Geist Bold" }
Style.FONT_DEFAULT = "Mode"
-- LibSharedMedia language bits: western (128) + ruRU (2).
local LANGUAGES = 130

-- Locales Geist and Expressway have no glyphs for.
local function NativeOnly()
    local locale = GetLocale and GetLocale()
    return locale == "koKR" or locale == "zhCN" or locale == "zhTW"
end

-- Installed copies of Expressway ModeUI may use (never copied or shipped),
-- in the order they are tried; Shared/Media/Media.lua registers the first
-- one the client knows under each name.
Style.PROVIDER_FONTS = {
    { name = "Expressway", paths = { "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
        "Interface\\AddOns\\AyijeUI\\Media\\Fonts\\Expressway.ttf" } },
    { name = "Expressway Bold", paths = { "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway Bold.ttf" } },
}

local function GeistPath(weight) return BASE .. (Style.FONT_WEIGHTS[weight or "regular"] or "Regular") .. ".ttf" end

-- Expressway's file for a weight (Expressway Bold for SemiBold and Bold
-- when the client has it), or nil when the client has no Expressway.
local function Expressway(weight)
    local media = addon.Media
    if not (media and media.library and media.GetFont) then return end
    local heavy = weight == "semibold" or weight == "bold"
    return heavy and media:GetFont("Expressway Bold") or media:GetFont("Expressway")
end
-- Which typeface the client has now: "Expressway" or "Geist".
function Style.Typeface() return Expressway() and "Expressway" or "Geist" end

function Style.FontPath(weight)
    if NativeOnly() then return STANDARD_TEXT_FONT end
    return Expressway(weight) or GeistPath(weight)
end

-- `path` in another weight when it is the Mode typeface (a Geist file, or
-- Expressway's); any other font is returned unchanged (a player's own font
-- keeps its one weight).
function Style.Weighted(path, weight)
    if type(path) ~= "string" then return path end
    if path:sub(1, #BASE) == BASE or path == Expressway("regular") or path == Expressway("bold") then return Style.FontPath(weight) end
    return path
end

-- Sets a font string to the Mode typeface at `size` (UI units) with `flags`
-- ("" by default; "OUTLINE" or "THICKOUTLINE" only as a player choice).
-- Falls back to Blizzard's font if the client refuses the file.
function Style.Font(fontString, size, weight, flags)
    local ok = fontString:SetFont(Style.FontPath(weight), size, flags or "")
    if not ok then fontString:SetFont(STANDARD_TEXT_FONT, size, flags or "") end
    return ok
end

local function Present(path)
    local known = C_UIFileAsset and C_UIFileAsset.IsKnownFile
    if not known then return true end
    local ok, result = pcall(known, path)
    return ok and addon.IsPublic(result) and result == true
end

-- Geist's weights under their own names, at load.
function Style.RegisterFonts(library)
    if not (library and type(library.Register) == "function") or NativeOnly() then return end
    for weight, name in pairs(Style.FONT_NAMES) do
        local path = GeistPath(weight)
        if Present(path) then library:Register("font", name, path, LANGUAGES) end
    end
end

-- "Mode": the typeface the client has, registered once media is discovered
-- (an installed addon's Expressway is only known then). LibSharedMedia keeps
-- the first registration of a name, so this runs once.
function Style.RegisterTypeface(library)
    if Style.typefaceRegistered or not (library and type(library.Register) == "function") or NativeOnly() then return end
    local path = Style.FontPath("regular")
    if not Present(path) then return end
    Style.typefaceRegistered = true
    library:Register("font", Style.FONT_DEFAULT, path, LANGUAGES)
end

-- Register at load, so every addon's LibSharedMedia lists see the Mode media
-- from the start (LibSharedMedia is loaded from Libs/ before this file).
local library = LibStub and LibStub("LibSharedMedia-3.0", true)
if library then
    Style.RegisterAssets(library)
    Style.RegisterFonts(library)
end

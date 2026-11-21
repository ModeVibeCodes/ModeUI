local _, addon = ...
-- The Mode typeface (docs/DESIGN_LANGUAGE.md, "Text"). Since November 20,
-- 2026 (owner's decision) it is Urbanist (Mode-Urbanist) everywhere: four
-- static weights, SIL OFL 1.1 (Media/Fonts/Urbanist/OFL.txt), Latin only.
-- Geist, the typeface before it, was retired (kept outside the addon in
-- archive/mode-blizz/). Locales Urbanist has no glyphs for (ruRU, koKR,
-- zhCN, zhTW) use Blizzard's font.
-- Modules store the LibSharedMedia name "Mode" (Style.FONT_DEFAULT), which
-- points at the Mode typeface (registered once media is discovered:
-- Style.RegisterTypeface).
local Style = addon.Style or {}
addon.Style = Style

local BASE = "Interface\\AddOns\\ModeUI\\Media\\Fonts\\Urbanist\\Urbanist-"
-- Mode Script (docs/DESIGN_LANGUAGE.md, "Text"; owner's pick, November 17,
-- 2026): Damion, a bold flowing script (SIL OFL 1.1, Media/Fonts/Damion/OFL.txt),
-- for the word "Mode" in ModeUI's own wordmark only, in Ivory. It draws one
-- fixed Latin word, so every locale uses it.
Style.SCRIPT_FONT = "Interface\\AddOns\\ModeUI\\Media\\Fonts\\Damion\\Damion-Regular.ttf"
Style.FONT_WEIGHTS = { regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold" }
-- LibSharedMedia names: "Mode" (the default everywhere) and Urbanist's weights.
Style.FONT_NAMES = { regular = "Mode-Urbanist", medium = "Mode-Urbanist Medium", semibold = "Mode-Urbanist SemiBold",
    bold = "Mode-Urbanist Bold" }
Style.URBANIST_NAMES = Style.FONT_NAMES
Style.FONT_DEFAULT = "Mode"
-- LibSharedMedia language bits: western only (Urbanist has no Cyrillic).
local LANGUAGES = 128

-- Locales Urbanist has no glyphs for.
local function NativeOnly()
    local locale = GetLocale and GetLocale()
    return locale == "ruRU" or locale == "koKR" or locale == "zhCN" or locale == "zhTW"
end

-- Installed copies of Expressway a player may pick (never copied or
-- shipped), in the order they are tried; Shared/Media/Media.lua registers
-- the first one the client knows under each name. The Mode typeface never
-- uses them.
Style.PROVIDER_FONTS = {
    { name = "Expressway", paths = { "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
        "Interface\\AddOns\\AyijeUI\\Media\\Fonts\\Expressway.ttf" } },
    { name = "Expressway Bold", paths = { "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway Bold.ttf" } },
}

local function UrbanistPath(weight) return BASE .. (Style.FONT_WEIGHTS[weight or "regular"] or "Regular") .. ".ttf" end

-- An installed Expressway's file for a weight (Expressway Bold for SemiBold
-- and Bold when the client has it), or nil.
local function Expressway(weight)
    local media = addon.Media
    if not (media and media.library and media.GetFont) then return end
    local heavy = weight == "semibold" or weight == "bold"
    return heavy and media:GetFont("Expressway Bold") or media:GetFont("Expressway")
end
-- The typeface the client draws as "Mode": "Urbanist", or "Blizzard" in a
-- locale Urbanist has no glyphs for.
function Style.Typeface() return NativeOnly() and "Blizzard" or "Urbanist" end

function Style.FontPath(weight)
    if NativeOnly() then return STANDARD_TEXT_FONT end
    return UrbanistPath(weight)
end

-- `path` in another weight when it is the Mode typeface (an Urbanist file)
-- or an installed Expressway (its Bold for the heavy weights); any other font
-- is returned unchanged (a player's own font keeps its one weight).
function Style.Weighted(path, weight)
    if type(path) ~= "string" then return path end
    if path:sub(1, #BASE) == BASE then return Style.FontPath(weight) end
    local regular, bold = Expressway("regular"), Expressway("bold")
    if regular and (path == regular or path == bold) then return Expressway(weight) or path end
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

-- Urbanist's weights under their own names, at load.
function Style.RegisterFonts(library)
    if not (library and type(library.Register) == "function") or NativeOnly() then return end
    for weight, name in pairs(Style.FONT_NAMES) do
        local path = UrbanistPath(weight)
        if Present(path) then library:Register("font", name, path, LANGUAGES) end
    end
end

-- "Mode": the Mode typeface, registered once media is discovered.
-- LibSharedMedia keeps the first registration of a name, so this runs once.
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

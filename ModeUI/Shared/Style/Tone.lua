local _, addon = ...
-- Every color in the Mode design language (docs/DESIGN_LANGUAGE.md, "Color
-- tokens"). Colors are { r, g, b } in 0-1. Code reads tokens, never numbers.
local Style = addon.Style or {}
addon.Style = Style

local function Hex(hex)
    hex = hex:gsub("#", "")
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end
Style.Hex = Hex

-- a * t + b * (1 - t), channel by channel.
function Style.Mix(a, b, t)
    return { a[1] * t + b[1] * (1 - t), a[2] * t + b[2] * (1 - t), a[3] * t + b[3] * (1 - t) }
end

local ROLES = { "void", "base", "panel", "raised", "track", "line", "rim", "rimStrong", "muted", "secondary", "text", "white" }
Style.ROLES = ROLES
local function Ramp(list)
    local ramp = {}
    for i, role in ipairs(ROLES) do ramp[role] = Hex(list[i]) end
    return ramp
end

local Tone = {
    -- Frames and buttons.
    mono = Ramp({ "000000", "050505", "0E0E0E", "161616", "1E1E1E", "282828", "383838", "555555", "808080", "A6A6A6", "DADADA", "FFFFFF" }),
    -- Windows and panels.
    graphite = Ramp({ "000000", "0A0A0B", "121213", "1A1A1C", "222224", "2C2C2F", "3D3D41", "5A5A5F", "85858B", "A9A9AE", "D8D8DB", "F5F5F6" }),
    darkFill = Hex("1C1D1C"),
    darkFillGraphite = Hex("1D1D1F"),
    slate = Hex("474747"),
    ivory = Hex("EFE6D2"),
    celadon = Hex("B4CDB6"),
    rosewood = Hex("CF6A6F"),
    rosewoodDeep = Hex("743B3E"),
    celadonInk = Hex("0E1510"),
    gunmetal = { light = Hex("5B5E63"), mid = Hex("46494D"), dark = Hex("33363A") },
    steel = { light = Hex("8C8F95"), mid = Hex("74777D"), dark = Hex("5B5E63") },
    shadow = { 0, 0, 0 },
    shadowAlpha = 0.82,
    softAlpha = 0.55,
    -- Health and power empty parts: Slate, semi-transparent (no plate behind).
    emptyAlpha = 0.6,
    -- Gameplay meanings, never softened.
    reaction = { hostile = Hex("E5484D"), neutral = Hex("F2C744"), friendly = Hex("46C46B"), tapped = Hex("8C8C8C") },
    cast = { casting = Hex("F2B13C"), channeling = Hex("3FBF7F"), shielded = Hex("7D838C"), interrupted = Hex("E5484D") },
    dispel = { Magic = Hex("3399FF"), Curse = Hex("9900FF"), Disease = Hex("996600"), Poison = Hex("009900") },
    quality = { [0] = Hex("9D9D9D"), [1] = Hex("FFFFFF"), [2] = Hex("1EFF00"), [3] = Hex("0070DD"), [4] = Hex("A335EE"), [5] = Hex("FF8000") },
    cooldown = Hex("FFB12F"),
    power = Hex("3A6FB8"),
    -- Text.
    text = Hex("DADADA"),
    textBright = Hex("F2F2F2"),
    textShadow = { 0, 0, 0, 0.95 },
}
Style.Tone = Tone

-- The main accent and the specialty accent (Ivory and Rosewood by default).
Style.ACCENTS = { ivory = Tone.ivory, celadon = Tone.celadon, rosewood = Tone.rosewood }
function Style.Accent(kind)
    if kind == "specialty" then return Tone.rosewood end
    if kind == "on" then return Tone.celadon end
    if kind == "off" then return Tone.rosewood end
    return Tone.ivory
end

-- Lighter by `amount` toward white (the Comet trail uses 0.45).
function Style.Lighten(color, amount) return Style.Mix({ 1, 1, 1 }, color, amount) end

-- Names: subtle Gradient end (74% color + 26% white) and Soft class (55% + 45%).
function Style.GradientEnd(color) return Style.Mix(color, Tone.mono.white, 0.5) end
function Style.Soft(color) return Style.Mix(color, { 1, 1, 1 }, 0.55) end

-- Defaults from before the Mode design language, kept only so migrations can
-- recognize a saved color that was never changed (Style.SameColor).
Style.LEGACY = { nameplateFocus = Hex("FFB547") }

-- True when `color` is (within rounding) `reference`: migrations move saved
-- colors that still equal an old default, and keep anything the player chose.
function Style.SameColor(color, reference)
    if type(color) ~= "table" or type(reference) ~= "table" then return false end
    for i = 1, 3 do
        local value = color[i]
        if not (addon.IsNumber(value) and math.abs(value - reference[i]) < 1 / 512) then return false end
    end
    return true
end

-- Sets a region's vertex color from a token, with an optional alpha.
function Style.Paint(region, color, alpha)
    region:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

-- One physical pixel in `frame`'s UI units (Blizzard's PixelUtil factor over the
-- frame's effective scale); 1 when the client can't report it.
function Style.Pixel(frame)
    local Plain, Number = addon.Domain.Query.Plain, addon.IsNumber
    local factor = PixelUtil and Plain(PixelUtil.GetPixelToUIUnitFactor)
    local scale = frame and Plain(frame.GetEffectiveScale, frame)
    if not (Number(factor, 0.01, 10) and Number(scale, 0.01, 100)) then return 1 end
    return factor / scale
end

-- `n` physical pixels in `frame`'s units, rounded to whole pixels.
function Style.Pixels(frame, n)
    return math.floor(n + 0.5) * Style.Pixel(frame)
end

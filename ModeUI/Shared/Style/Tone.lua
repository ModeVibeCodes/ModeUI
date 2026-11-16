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
    slate = Hex("575757"),
    ivory = Hex("EFE6D2"),
    celadon = Hex("B4CDB6"),
    rosewood = Hex("CF6A6F"),
    rosewoodDeep = Hex("743B3E"),
    -- "Mode" in the ModeUI wordmark (Ivory reads white in bold button text).
    brand = Hex("E2B866"),
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
    -- Quest titles and objectives in tooltips.
    quest = Hex("FFB12F"),
    -- Power bars by power type (Domain.Power; no dependency on Blizzard's
    -- PowerBarColor), and the color for any other type.
    powerType = { MANA = Hex("4096FF"), RAGE = { 0.86, 0.30, 0.30 }, ENERGY = { 0.95, 0.82, 0.35 },
        FOCUS = { 0.95, 0.58, 0.30 }, HAPPINESS = { 0.35, 0.80, 0.70 }, default = { 0.55, 0.55, 0.60 } },
    -- Threat on nameplates: the enemy is on you, or you're losing or about to
    -- pull it.
    threat = { aggro = Hex("FF4848"), warning = Hex("FFA040") },
    -- Lit combo points (nameplates, the Target frame).
    comboPoint = Hex("F05454"),
    -- Aura rims and glows by debuff type on nameplates and group frames (a
    -- brighter cut of Blizzard's family; Tone.dispel is Blizzard's own), and
    -- crowd control without a type.
    debuffType = { Magic = Hex("3399FF"), Curse = Hex("AA55FF"), Disease = Hex("CC8833"), Poison = Hex("55BB55"),
        Enrage = Hex("FF5555"), Bleed = Hex("C82D2D"), crowdControl = Hex("FF5948") },
    -- A custom aura glow (group frames).
    auraGlow = Hex("FFD15C"),
    -- Incoming heals on group frames.
    healPrediction = Hex("5CD684"),
    -- The unit frames' plain-text name colors (owner's picks; Sky the default).
    nameAccent = { sky = Hex("91C6FF"), champagne = Hex("F2DFB8"), lilac = Hex("C9BBFF"), frost = Hex("EAF1F8") },
    -- The portrait's combat ring.
    combatRing = Hex("FF6B6B"),
    -- Macro names on action buttons.
    macro = Hex("69A5B9"),
    -- Character stats by stat (Windows): the attributes in their usual colors,
    -- the rest by family (physical orange, spell violet, healing and regen
    -- green, crit red, hit amber, haste light blue, avoidance pale blue).
    stat = { strength = Hex("E85C50"), agility = Hex("FFD140"), stamina = Hex("E8B04B"), intellect = Hex("4096FF"),
        spirit = Hex("7FDB97"), armor = Hex("B9B9B9"), attackPower = Hex("FF8A3D"), rangedAttackPower = Hex("FF8A3D"),
        spellPower = Hex("B07CFF"), healing = Hex("7FDB97"), crit = Hex("FF6B6B"), spellCrit = Hex("FF6B6B"),
        rangedCrit = Hex("FF6B6B"), hit = Hex("FFB12F"), spellHit = Hex("FFB12F"), haste = Hex("7FDBFF"),
        spellHaste = Hex("7FDBFF"), expertise = Hex("E8B04B"), dodge = Hex("9AD0EC"), parry = Hex("9AD0EC"),
        block = Hex("9AD0EC"), manaRegen = Hex("4096FF") },
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
Style.LEGACY = { nameplateFocus = Hex("FFB547"),
    -- Cooldown Manager before version 5: the Rounded slot rim (version 2), the
    -- slot background, gold procs and the combo point red.
    slotRim = Hex("101010"), slotBackground = Hex("040404"), procGold = Hex("FFD25A"), comboRed = Hex("F05454"),
    -- Windows before version 3: the near-black window fill.
    windowFill = Hex("0B0B0D"),
    -- Damage Meters before version 9: version 4's background and the bar
    -- for anything without a class.
    meterFill = Hex("040404"), meterOther = Hex("78808C"),
    -- Tooltip before version 5: the neutral reaction yellow.
    tooltipNeutral = Hex("FFD140"),
    -- Bags before version 3: the near-black slot fill.
    bagSlot = Hex("040404"),
    -- The pre-Mode palettes (Kit.palette and Kit.onyx alias these): defaults
    -- that saved settings still hold or that migrations recognize. The Onyx
    -- health fill was #1C1E21 until November 13, 2026 (oldOnyxHealth).
    palette = { text = Hex("D4D4D4"), accent = Hex("00F0FF"), green = Hex("7FDB97"), hostile = Hex("E06666"),
        neutral = Hex("E8B04B"), tapped = Hex("8C8C8C"), mana = Hex("4096FF"), muted = Hex("B9B9B9"), cooldown = Hex("FFB12F") },
    onyx = { health = Hex("131212"), track = Hex("0A0B0C"), border = Hex("25282C"),
        slate = Hex("44464A"), slateHatch = Hex("55585D"), frameRim = Hex("40454C") },
    oldOnyxHealth = Hex("1C1E21") }

-- "|cffRRGGBB<text>|r": text in a token's color, for strings (menus, labels).
function Style.ColorText(text, color)
    return string.format("|cff%02x%02x%02x%s|r", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5),
        math.floor(color[3] * 255 + 0.5), text)
end

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

-- Blizzard's pixel factor (one physical pixel in UI units at scale 1), or nil
-- when the client can't report it.
function Style.PixelFactor()
    local factor = PixelUtil and addon.Domain.Query.Plain(PixelUtil.GetPixelToUIUnitFactor)
    if addon.IsNumber(factor, 0.01, 10) then return factor end
end

-- `n` physical pixels in `frame`'s units, rounded to whole pixels.
function Style.Pixels(frame, n)
    return math.floor(n + 0.5) * Style.Pixel(frame)
end

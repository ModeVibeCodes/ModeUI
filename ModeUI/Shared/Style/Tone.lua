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
    -- Border metals (Style.Edge), five tones each from the border study.
    metal = {
        silver = { hi = Hex("F2F4F6"), light = Hex("D9DCE0"), mid = Hex("9A9EA4"), dark = Hex("5C6066"), deep = Hex("3A3D41") },
        steel = { hi = Hex("D4D7DC"), light = Hex("A3A6AB"), mid = Hex("6E7176"), dark = Hex("3D4044"), deep = Hex("26282B") },
        gunmetal = { hi = Hex("A5A9AF"), light = Hex("7C8086"), mid = Hex("4E5156"), dark = Hex("2C2E31"), deep = Hex("1A1B1D") },
        -- Mode-Obsidian's own (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"):
        -- deep is the dark glass of the band, hi its lit top row, light the
        -- warm champagne row along the bottom.
        -- (deep lifted from #0F0F11, owner, November 20, 2026: the border's
        -- edge read too black.)
        obsidian = { hi = Hex("6E6E74"), light = Hex("8C806A"), mid = Hex("2A2A2D"), dark = Hex("18181A"), deep = Hex("19191C") },
    },
    -- Mode-Obsidian's fill-end line: ice white (owner, November 20, 2026).
    fillEnd = Hex("D6EBFF"),
    -- The shield's finish line and the spark end line (Style.EndSpark).
    finishLine = Hex("F6F8FB"),
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
    -- The Mode-Default layout's Cooldown Manager numbers (owner, November 18, 2026).
    cooldownHot = Hex("FF3948"),
    -- Mode-Empty's neutral, darker rim: the Cooldown Manager's icons in the
    -- Mode-DPS/TANK and Mode-Healer layouts (owner, November 20, 2026).
    emptyRim = Hex("343438"),
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
    -- The totem bar's element rims (owner, November 20, 2026): Earth, Fire,
    -- Water and Air, the hint in place of Blizzard's colored totem frames.
    totem = { earth = Hex("C9924F"), fire = Hex("E8664F"), water = Hex("4FA8E8"), air = Hex("A98FE6") },
    -- Aura rims and glows by debuff type on nameplates and group frames (a
    -- brighter cut of Blizzard's family; Tone.dispel is Blizzard's own), and
    -- crowd control without a type.
    debuffType = { Magic = Hex("3399FF"), Curse = Hex("AA55FF"), Disease = Hex("CC8833"), Poison = Hex("55BB55"),
        Enrage = Hex("FF5555"), Bleed = Hex("C82D2D"), crowdControl = Hex("FF5948") },
    -- A custom aura glow (group frames).
    auraGlow = Hex("FFD15C"),
    -- Stack counts on Buffs & Debuffs bars (owner, November 18, 2026); their
    -- time text is mono.white.
    auraStack = Hex("53F24F"),
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
    -- Edit Mode (docs/DESIGN_LANGUAGE.md, "Edit Mode"): the selected element's
    -- outline and the guides (select), an idle outline, element names (name,
    -- readable on any scene), the grid's lines and the hover outline.
    edit = { select = Hex("80EF80"), idle = Hex("85858B"), name = Hex("CCFF00"), grid = Hex("DADADA"), hover = Hex("EFE6D2") },
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

-- The Deep glow color (docs/DESIGN_LANGUAGE.md, "Text glow"): the same hue,
-- saturation x 1.25 + 0.12 (at most 1), lightness halved.
function Style.Deep(color)
    local r, g, b = color[1], color[2], color[3]
    local high, low = math.max(r, g, b), math.min(r, g, b)
    local l = (high + low) / 2
    local h, s = 0, 0
    if high ~= low then
        local d = high - low
        s = l > 0.5 and d / (2 - high - low) or d / (high + low)
        if high == r then h = (g - b) / d + (g < b and 6 or 0)
        elseif high == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    s, l = math.min(1, s * 1.25 + 0.12), l * 0.5
    if s == 0 then return { l, l, l } end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    local function Channel(t)
        t = t % 1
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    return { Channel(h + 1 / 3), Channel(h), Channel(h - 1 / 3) }
end

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

-- The look (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"). Since November
-- 20, 2026 Mode-Obsidian is the only look: the Mode-Blizz look was retired
-- (its art is in archive/mode-blizz/). The surface tokens above are
-- Mode-Blizz's; Style.ApplyTheme sets Mode-Obsidian's in place at load (so
-- defaults copied from tokens at load are already Mode-Obsidian's) and again
-- once the profile is checked (Shared/Runtime/DB.lua). The Mode-Blizz values
-- are kept so migrations can tell a saved color that is still an old default
-- (Style.BlizzTone).
Style.THEMES = { obsidian = "Mode-Obsidian" }
Style.THEME_ORDER = { "obsidian" }
Style.DEFAULT_THEME = "obsidian"
Style.OBSIDIAN = {
    graphite = { base = "070708", panel = "0B0B0C", raised = "131314", track = "1A1A1C", line = "232325", rim = "343438",
        rimStrong = "4E4E54", muted = "8A857C", secondary = "ADA79C", text = "E6E1D7", white = "F6F2EA" },
    mono = { base = "040405", panel = "09090A", raised = "111112", track = "19191B", line = "222224", rim = "333336",
        rimStrong = "4D4D52" },
    text = "E8E3D9", textBright = "F7F3EA", darkFill = "161618", darkFillGraphite = "161618", slate = "46464B",
    -- The 1px shadow ring outside every border, softened from 0.9 (owner,
    -- November 20, 2026: the edge read too black).
    emptyAlpha = 0.85, shadowAlpha = 0.65,
}

local function Set(color, hex)
    local value = Hex(hex)
    color[1], color[2], color[3] = value[1], value[2], value[3]
end
-- A copy of every token the look changes, as Mode-Blizz had it.
local blizz
local function Snapshot()
    if blizz then return end
    blizz = { graphite = {}, mono = {}, numbers = {} }
    for _, ramp in ipairs({ "graphite", "mono" }) do
        for role, color in pairs(Tone[ramp]) do blizz[ramp][role] = { color[1], color[2], color[3] } end
    end
    for _, key in ipairs({ "text", "textBright", "darkFill", "darkFillGraphite", "slate" }) do
        blizz[key] = { Tone[key][1], Tone[key][2], Tone[key][3] }
    end
    blizz.numbers.emptyAlpha, blizz.numbers.shadowAlpha = Tone.emptyAlpha, Tone.shadowAlpha
end

-- The look in use: always "obsidian".
function Style.Theme() return Style.DEFAULT_THEME end
function Style.IsObsidian() return true end

-- Code that keeps its own copies of token colors (the settings window's
-- palette) refreshes them when the look is applied: fn(theme).
Style.themeListeners = {}
function Style.OnThemeApplied(fn) Style.themeListeners[#Style.themeListeners + 1] = fn end

-- Sets the Mode-Obsidian tokens (in place) and tells the listeners.
function Style.ApplyTheme()
    Snapshot()
    local O = Style.OBSIDIAN
    for _, ramp in ipairs({ "graphite", "mono" }) do
        for role, hex in pairs(O[ramp]) do Set(Tone[ramp][role], hex) end
    end
    for _, key in ipairs({ "text", "textBright", "darkFill", "darkFillGraphite", "slate" }) do Set(Tone[key], O[key]) end
    Tone.emptyAlpha, Tone.shadowAlpha = O.emptyAlpha, O.shadowAlpha
    Style.activeTheme = Style.DEFAULT_THEME
    for _, fn in ipairs(Style.themeListeners) do fn(Style.DEFAULT_THEME) end
    return Style.DEFAULT_THEME
end

-- A token's Mode-Obsidian color (theme parts write these into saved
-- settings): Style.ObsidianTone("graphite", "panel").
function Style.ObsidianTone(group, role)
    local O = Style.OBSIDIAN
    local hex = role and O[group] and O[group][role] or (not role and O[group])
    return type(hex) == "string" and Hex(hex) or nil
end
-- A token's Mode-Blizz color (what a theme part compares a saved color with).
function Style.BlizzTone(group, role)
    Snapshot()
    local value = role and blizz[group] and blizz[group][role] or (not role and blizz[group])
    return type(value) == "table" and { value[1], value[2], value[3] } or nil
end

Style.ApplyTheme()

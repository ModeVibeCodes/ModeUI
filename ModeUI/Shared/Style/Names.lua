local _, addon = ...
-- Name text (docs/DESIGN_LANGUAGE.md, "Text"): subtle Gradient is standard, Soft
-- class and White are options; names sit on the top border opposite the
-- portrait. Names Forever returns as secret can't be split into letters, so they
-- fall back to Soft class.
local Style = addon.Style
local Tone = Style.Tone

Style.NAME_STYLES = { "gradient", "soft", "white" }

local function Hex2(value) return string.format("%02x", math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)) end
local function Code(color) return "|cff" .. Hex2(color[1]) .. Hex2(color[2]) .. Hex2(color[3]) end

-- Text for a name in a style: per-letter color codes for Gradient (UTF-8 safe),
-- or nil when the name can't be colored that way (secret).
function Style.GradientText(name, color)
    if not addon.IsPublic(name) or type(name) ~= "string" or name == "" then return nil end
    local letters = {}
    for char in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do letters[#letters + 1] = char end
    local n, finish, parts = #letters, Style.GradientEnd(color), {}
    for i, char in ipairs(letters) do
        -- The square root moves the letters toward the end color sooner.
        local t = n > 1 and math.sqrt((i - 1) / (n - 1)) or 0
        parts[#parts + 1] = Code(Style.Mix(finish, color, t)) .. char
    end
    return table.concat(parts) .. "|r"
end

-- Sets `fontString` to `name` in `style` with `color` (class or reaction). The
-- name may be secret: SetText accepts it, and the color is then set whole.
function Style.SetName(fontString, name, color, style)
    style = style or "gradient"
    if not color or style == "white" then
        fontString:SetTextColor(Tone.textBright[1], Tone.textBright[2], Tone.textBright[3])
        fontString:SetText(name)
        return
    end
    if style == "gradient" then
        local text = Style.GradientText(name, color)
        if text then
            fontString:SetTextColor(1, 1, 1)
            fontString:SetText(text)
            return
        end
    end
    local soft = Style.Soft(color)
    fontString:SetTextColor(soft[1], soft[2], soft[3])
    fontString:SetText(name)
end

-- Health text by the unit's health (docs/DESIGN_LANGUAGE.md, "Text"):
-- Rosewood at 30% and under, through Ivory, to Celadon at full. The health
-- percent is secret, so the client evaluates a color curve
-- (UnitHealthPercent with a LuaColorCurveObject) and the result only reaches
-- SetTextColor, which accepts secret values.
local HEALTH_POINTS = { { 0, Tone.rosewood }, { 0.3, Tone.rosewood }, { 0.65, Tone.ivory }, { 1, Tone.celadon } }
local healthCurve
local function HealthCurve()
    if healthCurve ~= nil then return healthCurve or nil end
    healthCurve = false
    local util = C_CurveUtil
    if type(util) == "table" and type(util.CreateColorCurve) == "function" and type(CreateColor) == "function" then
        local ok, curve = pcall(util.CreateColorCurve)
        if ok and curve then
            if curve.SetType and Enum and Enum.LuaCurveType then pcall(curve.SetType, curve, Enum.LuaCurveType.Linear) end
            for _, point in ipairs(HEALTH_POINTS) do
                local c = point[2]
                pcall(curve.AddPoint, curve, point[1], CreateColor(c[1], c[2], c[3], 1))
            end
            healthCurve = curve
        end
    end
    return healthCurve or nil
end
Style.HEALTH_TEXT_FULL = Tone.celadon
-- The same colors for a plain fraction `p` (0-1): samples and previews, whose
-- health is a known number.
function Style.HealthTextColorAt(p)
    p = math.max(0, math.min(1, p or 1))
    for i = 2, #HEALTH_POINTS do
        local a, b = HEALTH_POINTS[i - 1], HEALTH_POINTS[i]
        if p <= b[1] then return Style.Mix(b[2], a[2], (p - a[1]) / math.max(0.0001, b[1] - a[1])) end
    end
    return HEALTH_POINTS[#HEALTH_POINTS][2]
end
-- Paints `fontString` by `unit`'s health; false when the client can't (then
-- the caller keeps its own color).
function Style.PaintHealthText(fontString, unit)
    local curve = HealthCurve()
    if not curve or not unit then return false end
    local ok = pcall(function()
        local color = UnitHealthPercent(unit, false, curve)
        fontString:SetTextColor(color:GetRGB())
    end)
    return ok
end

-- The Mode text shadow: 1px offset (1, -1) at 95% black.
function Style.Shadow(fontString, px)
    local shadow = Tone.textShadow
    fontString:SetShadowColor(shadow[1], shadow[2], shadow[3], shadow[4])
    fontString:SetShadowOffset(px or 1, -(px or 1))
end

-- Places a name on the host's top border, `inset` pixels in from `side` (the side
-- away from any portrait), lifted so the rim runs near its baseline.
function Style.PlaceName(fontString, host, side, size, px)
    px = px or Style.Pixel(host)
    side = side or "LEFT"
    local lift = math.floor(size * 0.82 + 0.5) * px
    fontString:ClearAllPoints()
    fontString:SetPoint("BOTTOM" .. side, host, "TOP" .. side, (side == "LEFT" and 9 or -9) * px, -size * px + lift)
    fontString:SetJustifyH(side)
end

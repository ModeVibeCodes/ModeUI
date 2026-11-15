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
        local t = n > 1 and (i - 1) / (n - 1) or 0
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

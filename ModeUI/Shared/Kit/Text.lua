local _, addon = ...
local Kit = addon.Kit

-- Text in the suite's style. Each text has an opaque shadow one screen pixel
-- down-right and, under it, a lifted shadow: one black copy 2px down-right at
-- 45%. Whole pixels and no blur, so text stays crisp with a slight pop.
-- `style` tables carry: outline, shadow, liftedShadow (booleans) and
-- textColor ({ r, g, b }).
Kit.LIFT_PIXELS, Kit.LIFT_ALPHA = 2, 0.45

-- A single-line font string. Give it a `lift` (another Kit.Text on the
-- ARTWORK layer) to use Write, Formatted and LayoutLift.
function Kit.Text(layer, drawLayer)
    local text = layer:CreateFontString(nil, drawLayer or "OVERLAY", "GameFontHighlight")
    text:SetWordWrap(false)
    return text
end

-- Writes go to the text and its lift alike; secret values are passed straight
-- to SetText/SetFormattedText on both.
function Kit.Write(text, value)
    text:SetText(value); text.lift:SetText(value)
end
function Kit.Formatted(text, pattern, ...)
    text:SetFormattedText(pattern, ...); text.lift:SetFormattedText(pattern, ...)
end

-- Font, color and the 1px shadow; px is one physical pixel.
function Kit.Font(text, style, size, path, px)
    local flags = style.outline and "OUTLINE" or ""
    if not text:SetFont(path, size, flags) then text:SetFont(addon.Media.gameFont, size, flags) end
    local c = style.textColor
    text:SetTextColor(c[1], c[2], c[3], 1)
    text:SetShadowColor(0, 0, 0, style.shadow and 1 or 0)
    text:SetShadowOffset(style.shadow and px or 0, style.shadow and -px or 0)
end

-- The lift covers its text's box moved 2px down-right; it needs the shadow on.
function Kit.LayoutLift(text, style, size, path, px, shown, justify)
    local lift = text.lift
    local on = shown and style.shadow and style.liftedShadow
    lift:SetShown(on)
    if not on then return end
    local flags = style.outline and "OUTLINE" or ""
    if not lift:SetFont(path, size, flags) then lift:SetFont(addon.Media.gameFont, size, flags) end
    lift:SetTextColor(0, 0, 0, Kit.LIFT_ALPHA)
    lift:SetShadowColor(0, 0, 0, 0); lift:SetShadowOffset(0, 0)
    lift:SetJustifyH(justify)
    local d = Kit.LIFT_PIXELS * px
    lift:ClearAllPoints()
    lift:SetPoint("TOPLEFT", text, "TOPLEFT", d, -d)
    lift:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", d, -d)
end

-- Value text for health or power: mode is "none", "percent", "current" or
-- "both". percentFn(unit, curve) returns ok, percent through Blizzard's 0-100
-- curve; current may be secret and is only given to AbbreviateNumbers and the
-- FontString setters.
function Kit.ValueText(text, mode, percentFn, unit, hasCurrent, current)
    if mode == "none" then return end
    local Call = addon.Domain.Query.Call
    local curve = CurveConstants and CurveConstants.ScaleTo100
    local hasPercent, percent = false, nil
    if curve then hasPercent, percent = percentFn(unit, curve) end
    local hasValue, value = false, nil
    if mode ~= "percent" and hasCurrent then hasValue, value = Call(AbbreviateNumbers, current) end
    if mode == "both" and hasValue and hasPercent then
        if pcall(Kit.Formatted, text, "%s · %.0f%%", value, percent) then return end
    end
    if mode ~= "percent" and hasValue and pcall(Kit.Write, text, value) then return end
    if hasPercent and pcall(Kit.Formatted, text, "%.0f%%", percent) then return end
    Kit.Write(text, "")
end

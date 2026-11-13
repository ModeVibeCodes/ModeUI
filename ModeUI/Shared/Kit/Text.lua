local _, addon = ...
local Kit = addon.Kit

-- Text in the suite's style. Each text has an opaque shadow one screen pixel
-- down-right and, under it, a lifted shadow: one black copy 2px down-right at
-- 45%. Whole pixels and no blur, so text stays crisp with a slight pop.
-- `style` tables carry: outline, shadow, liftedShadow (booleans) and
-- textColor ({ r, g, b }).
Kit.LIFT_PIXELS, Kit.LIFT_ALPHA = 2, 0.45

-- One Text Shadow choice for the two saved keys: None (no shadow), Crisp (the
-- 1px shadow) or Lifted (the 1px shadow plus the lifted shadow).
Kit.SHADOW_CHOICES = { { id = "none", label = "None" }, { id = "crisp", label = "Crisp" }, { id = "lifted", label = "Lifted" } }
function Kit.ShadowMode(style)
    if not style.shadow then return "none" end
    return style.liftedShadow and "lifted" or "crisp"
end
-- The shadow and liftedShadow values for a choice.
function Kit.ShadowKeys(mode) return mode ~= "none", mode == "lifted" end

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

-- Slug text: the client draws slug fonts from their glyph outlines, so they
-- stay sharp at any size and scale. Only XML can mark a font slug (Font
-- slug="true"); there is no Lua setter. Fonts.xml defines two slug templates,
-- and each face, size and outline gets its own font object made from one with
-- CreateFont and CopyFontObject, then SetFont for the face. That SetFont keeps
-- the slug flag is assumed, not documented; if anything fails the text uses
-- its plain font. `style.slug` turns it on.
local slugFonts, slugCount = {}, 0
function Kit.SlugFont(path, size, flags)
    local key = path .. "|" .. size .. "|" .. flags
    local cached = slugFonts[key]
    if cached ~= nil then return cached or nil end
    local template = flags ~= "" and _G.ModeUISlugFontOutline or _G.ModeUISlugFont
    local font = false
    if template and type(CreateFont) == "function" then
        slugCount = slugCount + 1
        local ok, made = pcall(CreateFont, "ModeUISlugFont" .. slugCount)
        if ok and made and made.CopyFontObject then
            made:CopyFontObject(template)
            -- Font:SetFont documents no return value; check the face took.
            if pcall(made.SetFont, made, path, size, flags) and made:GetFont() then font = made end
        end
    end
    slugFonts[key] = font
    return font or nil
end

local function ApplyFont(text, style, path, size, flags)
    local slug = style.slug and Kit.SlugFont(path, size, flags)
    if slug then text:SetFontObject(slug); return end
    if not text:SetFont(path, size, flags) then text:SetFont(addon.Media.gameFont, size, flags) end
end

-- Font, color and the 1px shadow; px is one physical pixel.
function Kit.Font(text, style, size, path, px)
    local flags = style.outline and "OUTLINE" or ""
    ApplyFont(text, style, path, size, flags)
    local c = style.textColor
    text:SetTextColor(c[1], c[2], c[3], 1)
    text:SetShadowColor(0, 0, 0, style.shadow and 1 or 0)
    text:SetShadowOffset(style.shadow and px or 0, style.shadow and -px or 0)
end

-- The lift covers its text's box moved 2px down-right; it needs the shadow on.
-- `lift` defaults to text.lift; pass it for text ModeUI doesn't own (Blizzard's).
function Kit.LayoutLift(text, style, size, path, px, shown, justify, lift)
    lift = lift or text.lift
    local on = shown and style.shadow and style.liftedShadow
    lift:SetShown(on)
    if not on then return end
    local flags = style.outline and "OUTLINE" or ""
    ApplyFont(lift, style, path, size, flags)
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

-- The font file for a style's font/fontMedia choice. Expressway (registered by
-- Media from an installed AyijeUI or EllesmereUI copy) falls back to the
-- bundled ModeUI Lato when unavailable. scope is the module ID.
function Kit.FontPath(style, scope)
    local media = addon.Media
    if style.fontMedia == "Expressway" and not media:GetFont("Expressway") then
        return media:GetFont("ModeUI Lato") or media.gameFont
    end
    return media:GetDisplayFont({ font = style.font, fontMedia = style.fontMedia }, false, scope)
end

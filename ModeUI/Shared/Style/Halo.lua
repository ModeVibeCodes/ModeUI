local _, addon = ...
-- Text glow, Halo (docs/DESIGN_LANGUAGE.md, "Text glow"): eight copies of a
-- text under it, 1px out in every direction, in the glow color at the glow
-- strength, so the light hugs the letters. WoW has no blur for text and its
-- outline is always black, so copies are the way to light text. While a text
-- glows, the glow takes the place of its drop shadow: the shadow is part of the
-- text and would draw over the copies on one side, so the glow read as a
-- second shadow (owner, in game, November 17, 2026).
-- A copy takes every write the text takes (hooks on SetText and
-- SetFormattedText; secret values pass straight through), with color codes
-- removed from public strings so per-letter colors don't tint the glow.
-- Glow colors: Deep (the text's hue, richer and darker; Style.Deep), Ink
-- (Tone.shadow) and Match Text. A secret text color can't be changed in Lua:
-- health texts get Deep from a second color curve (Style.PaintHealthText), and
-- Deep on another secret color keeps its last color until a public one comes.
local Style = addon.Style
local Tone = Style.Tone
local IsPublic = addon.IsPublic

Style.GLOW_COLORS = { { id = "deep", label = "Deep" }, { id = "ink", label = "Ink" }, { id = "match", label = "Match Text" } }
-- Each copy's offset in pixels (x right, y down) and its share of the
-- strength. A second ring 2px out was tried and read as blur at 11px.
Style.HALO_TAPS = { { 1, 0, 1 }, { 1, 1, 1 }, { 0, 1, 1 }, { -1, 1, 1 }, { -1, 0, 1 }, { -1, -1, 1 }, { 0, -1, 1 }, { 1, -1, 1 } }

-- A public string without its color codes; anything else unchanged.
local function Plain(value)
    if type(value) ~= "string" or not IsPublic(value) then return value end
    return (value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Tint(halo, r, g, b)
    for _, copy in ipairs(halo) do copy:SetTextColor(r, g, b) end
end
-- Sets the glow's color outright (r, g, b may be secret).
function Style.SetHaloColor(text, r, g, b)
    local halo = text.halo
    if halo and halo.on then Tint(halo, r, g, b) end
end
-- Colors the glow from a text color by its mode. Names whose letters carry
-- color codes pass their base color here (the text itself is white).
function Style.TintHalo(text, r, g, b)
    local halo = text.halo
    if not (halo and halo.on) then return end
    if halo.mode == "ink" then
        local c = Tone.shadow
        Tint(halo, c[1], c[2], c[3])
    elseif halo.mode == "match" then Tint(halo, r, g, b)
    elseif IsPublic(r) and IsPublic(g) and IsPublic(b) then
        local d = Style.Deep({ r, g, b })
        Tint(halo, d[1], d[2], d[3])
    end
end

local function Write(text, value)
    local halo = text.halo
    if not (halo and halo.on) then return end
    value = Plain(value)
    for _, copy in ipairs(halo) do copy:SetText(value) end
end
local function WriteFormatted(text, pattern, ...)
    local halo = text.halo
    if not (halo and halo.on) then return end
    pattern = Plain(pattern)
    for _, copy in ipairs(halo) do copy:SetFormattedText(pattern, ...) end
end
local function Sync(text)
    local halo = text.halo
    if not halo then return end
    local shown = text:IsShown()
    if not IsPublic(shown) then return end
    shown = halo.on and shown and true or false
    for _, copy in ipairs(halo) do copy:SetShown(shown) end
end
local function FollowColor(text, r, g, b)
    local halo = text.halo
    if halo and halo.on then Style.TintHalo(text, r, g, b) end
end

-- opts: color ("deep", "ink" or "match"), strength (0-1), px; nil turns it
-- off. Call it after the text's font, shadow, justification and anchors are
-- set: turning it on clears the shadow, and the caller's next font pass (its
-- layout) brings the shadow back once the glow is off.
function Style.TextHalo(text, opts)
    local halo = text.halo
    if not opts then
        if halo then halo.on = false; Sync(text) end
        return
    end
    if not halo then
        halo = {}
        local layer, sublevel = text:GetDrawLayer()
        layer = layer or "OVERLAY"
        local parent = text:GetParent()
        for i = 1, #Style.HALO_TAPS do
            local copy = parent:CreateFontString(nil, layer)
            copy:SetDrawLayer(layer, math.max(-8, (sublevel or 0) - 1))
            copy:SetWordWrap(false)
            copy:Hide()
            halo[i] = copy
        end
        text.halo = halo
        if hooksecurefunc then
            hooksecurefunc(text, "SetText", Write)
            hooksecurefunc(text, "SetFormattedText", WriteFormatted)
            hooksecurefunc(text, "SetTextColor", FollowColor)
            for _, method in ipairs({ "Show", "Hide", "SetShown" }) do hooksecurefunc(text, method, Sync) end
        end
    end
    halo.on, halo.mode = true, opts.color or "deep"
    local strength = opts.strength or 0.15
    local px = opts.px or Style.Pixel(text)
    -- The copies draw without outline (it would be black) and without shadow.
    local path, size = text:GetFont()
    local justify = text:GetJustifyH()
    for i, copy in ipairs(halo) do
        local tap = Style.HALO_TAPS[i]
        if path then copy:SetFont(path, size, "") end
        copy:SetShadowColor(0, 0, 0, 0); copy:SetShadowOffset(0, 0)
        copy:SetJustifyH(justify)
        copy:SetAlpha(strength * tap[3])
        copy:ClearAllPoints()
        copy:SetPoint("TOPLEFT", text, "TOPLEFT", tap[1] * px, -tap[2] * px)
        copy:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", tap[1] * px, -tap[2] * px)
    end
    text:SetShadowColor(0, 0, 0, 0)
    Write(text, text:GetText())
    Style.TintHalo(text, text:GetTextColor())
    Sync(text)
end

local _, addon = ...
-- The Prism glow (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"): a soft
-- light around a frame in the unit's class or reaction color, added light,
-- for mouseover and focus only (owner, November 20, 2026: "a supplemental
-- element, not a main one"). The Mode-Prism art is sliced: the frame's edge
-- sits 8 physical pixels in from the art's border, so the light fades out 8px
-- outside the frame and a few pixels inside it. It sits on a holder under the
-- host (one frame level below, like a border's soft drop), on a grid of one
-- physical pixel per unit, so its corners stay crisp at any scale.
local Style = addon.Style
local Tone = Style.Tone

Style.GLOW_OUTSET = 8 -- physical pixels the light reaches past the frame
Style.GLOW_ALPHA = 0.55

local Glow = {}
Glow.__index = Glow

-- A glow for `host`. opts: alpha (the light's strength, default 55%),
-- outset (physical pixels past the frame, default 8).
function Style.Glow(host, opts)
    opts = opts or {}
    local glow = setmetatable({ host = host, alpha = opts.alpha or Style.GLOW_ALPHA, outset = opts.outset or Style.GLOW_OUTSET,
        color = Tone.ivory }, Glow)
    local holder = CreateFrame("Frame", nil, host)
    holder:EnableMouse(false)
    holder:SetAllPoints(host)
    glow.holder = holder
    local texture = holder:CreateTexture(nil, "BACKGROUND", nil, -7)
    Style.ApplyAsset(texture, "Prism")
    texture:SetBlendMode("ADD")
    glow.texture = texture
    glow:Layout()
    glow:SetShown(false)
    return glow
end

-- Re-lays the glow on whole physical pixels (after the host's scale changes).
function Glow:Layout()
    local holder, host = self.holder, self.host
    local base = host:GetFrameLevel()
    if addon.IsNumber(base) then holder:SetFrameLevel(math.max(0, base - 1)) end
    local factor = Style.PixelFactor()
    if holder.SetIgnoreParentScale then holder:SetIgnoreParentScale(factor ~= nil) end
    holder:SetScale(factor or Style.Pixel(host))
    local out = self.outset
    self.texture:ClearAllPoints()
    self.texture:SetPoint("TOPLEFT", holder, "TOPLEFT", -out, out)
    self.texture:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", out, -out)
end

-- The light's color (a token or any { r, g, b }) and, optionally, strength.
function Glow:SetColor(color, alpha)
    if color then self.color = color end
    if alpha then self.alpha = alpha end
    Style.Paint(self.texture, self.color, self.alpha)
end

function Glow:SetShown(shown)
    self.holder:SetShown(shown and true or false)
    if shown then self.texture:SetAlpha(1); self:SetColor() end
end
function Glow:IsShown() return self.holder:IsShown() end

-- Shown from a state the client may keep secret (focus, mouseover on a
-- secure unit): the holder stays shown and the light fades through
-- SetAlphaFromBoolean, so the value is never compared.
function Glow:SetShownFromBoolean(value)
    if addon.IsPublic(value) then return self:SetShown(value) end
    self.holder:Show()
    Style.Paint(self.texture, self.color, 1)
    if self.texture.SetAlphaFromBoolean then self.texture:SetAlphaFromBoolean(value, self.alpha, 0)
    else self.texture:SetAlpha(0) end
end

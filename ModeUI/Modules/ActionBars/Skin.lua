local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- The Mode button skin, built like an aura icon: a rounded 1px rim in the
-- border color, a 1px black gap, then the icon cropped (never stretched) to
-- the button's shape. Blizzard's slot art and frame are faded; the highlight,
-- pushed, checked and flash states become flat Mode overlays on the icon.
-- The same code skins Blizzard's buttons, the empty slots, the Edit Mode
-- stand-ins and the settings preview, so they always match.
--
-- ModeUI never stores anything on Blizzard's button tables: its textures and
-- state live in weak tables keyed by the button.
local Kit = addon.Kit
local ONYX, FLAT = Kit.onyx, Kit.FLAT
M.art = setmetatable({}, { __mode = "k" })
M.skinState = setmetatable({}, { __mode = "k" })

local function Shape(texture, key, rounded)
    if rounded and addon.Media:ApplyTexture(texture, key) then return end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexture(FLAT)
end

-- The rim and gap (and, for an empty slot, the dark well inside them).
function M:Art(host, well)
    local art = self.art[host]
    if art then return art end
    art = { rim = host:CreateTexture(nil, "BACKGROUND", nil, -8), gap = host:CreateTexture(nil, "BACKGROUND", nil, -7) }
    if well then art.well = host:CreateTexture(nil, "BACKGROUND", nil, -6) end
    self.art[host] = art
    return art
end

function M.PaintArt(art, host, style, g)
    local on = style.border ~= "none"
    local rounded = on and style.border == "rounded" and g.w >= 8 and g.h >= 8
    art.rim:SetShown(on)
    if on then
        art.rim:ClearAllPoints(); art.rim:SetAllPoints(host)
        Shape(art.rim, "NameplateRim", rounded); Kit.Tint(art.rim, style.borderColor, 1)
    end
    Kit.Inset(art.gap, host, on and g.px or 0)
    Shape(art.gap, "NameplateGap", rounded); Kit.Tint(art.gap, ONYX.inner, 1)
    if art.well then
        Kit.Inset(art.well, host, g.inset)
        Shape(art.well, "NameplateGap", rounded); Kit.Tint(art.well, ONYX.track, 1)
    end
end

-- An empty slot: what shows where a button has no action.
function M:BuildSlot(parent)
    local slot = CreateFrame("Frame", nil, parent)
    self:Art(slot, true)
    slot:Hide()
    return slot
end
function M:PaintSlot(slot, style, g) M.PaintArt(self:Art(slot, true), slot, style, g) end

-- Crops the icon to the button's shape: 8% off its edges, then the long side
-- cut to the inner aspect, so a 42 by 38 button shows the icon unstretched.
function M.CropIcon(icon, g)
    local iw, ih = math.max(g.px, g.w - 2 * g.inset), math.max(g.px, g.h - 2 * g.inset)
    if iw >= ih then
        local span = 0.84 * ih / iw
        icon:SetTexCoord(0.08, 0.92, 0.5 - span / 2, 0.5 + span / 2)
    else
        local span = 0.84 * iw / ih
        icon:SetTexCoord(0.5 - span / 2, 0.5 + span / 2, 0.08, 0.92)
    end
end

local function Overlay(texture, host, inset, color, alpha)
    if not texture then return end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexture(FLAT)
    texture:SetTexCoord(0, 1, 0, 1)
    Kit.Inset(texture, host, inset)
    texture:SetVertexColor(color[1], color[2], color[3], alpha)
end
local function Fade(region) if region and region.SetAlpha then region:SetAlpha(0) end end

-- Blizzard redraws the frame and pushed art when its bar settings change
-- (UpdateButtonArt); this puts the Mode look back. In combat only the fading
-- happens now; re-placing waits for the refresh after combat.
function M:RestyleArt(button)
    local state = self.skinState[button]
    if not state then return end
    local inset = state.g.inset
    Fade(button.NormalTexture or (button.GetNormalTexture and button:GetNormalTexture()))
    Fade(button.SlotArt); Fade(button.SlotBackground); Fade(button.Border)
    if addon.InCombat() then self:Refresh(); return end
    Overlay(button.PushedTexture, button, inset, ONYX.inner, 0.45)
    Overlay(button.HighlightTexture, button, inset, { 1, 1, 1 }, 0.16)
    Overlay(button.CheckedTexture, button, inset, Kit.palette.accent, 0.28)
    Overlay(button.Flash, button, inset, Kit.palette.hostile, 0.35)
    Overlay(button.NewActionTexture, button, inset, Kit.palette.accent, 0.22)
    Overlay(button.SpellHighlightTexture, button, inset, Kit.palette.accent, 0.3)
end

-- Skins one button (Blizzard's, or a sample) for a bar's style and geometry.
-- Size and anchors of Blizzard's buttons change only outside combat. `sample`
-- marks a ModeUI-made button (preview, stand-in) that carries its own lifts.
function M:SkinButton(button, style, g, sample)
    local state = self.skinState[button] or {}
    self.skinState[button] = state
    state.style, state.g = style, g
    button:SetSize(g.w, g.h)
    M.PaintArt(self:Art(button), button, style, g)
    local icon = button.icon
    if icon then
        if button.IconMask and icon.RemoveMaskTexture and not state.unmasked then
            state.unmasked = pcall(icon.RemoveMaskTexture, icon, button.IconMask)
        end
        Kit.Inset(icon, button, g.inset)
        M.CropIcon(icon, g)
    end
    for _, key in ipairs({ "cooldown", "chargeCooldown", "lossOfControlCooldown", "AutoCastOverlay" }) do
        local frame = button[key]
        if frame and frame.SetPoint then Kit.Inset(frame, button, g.inset) end
    end
    if not state.hooked and button.UpdateButtonArt and hooksecurefunc then
        state.hooked = true
        hooksecurefunc(button, "UpdateButtonArt", function(hooked) M:RestyleArt(hooked) end)
    end
    self:RestyleArt(button)
    self:StyleTexts(button, style, g, sample)
end

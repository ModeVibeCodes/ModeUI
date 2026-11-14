local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- The Mode button skin: a hollow border (Border Size, 2px by default, in the
-- Border Color) around the background (Background Color with the
-- ActionBarSlot texture lightening it), then the icon one pixel further in,
-- cropped (never stretched) to the button's shape. Blizzard's slot art and
-- frame are faded; the highlight, pushed, checked and flash states become
-- flat Mode overlays on the icon. The same code skins Blizzard's buttons, the
-- empty slots, the Edit Mode stand-ins and the settings preview, so they
-- always match.
--
-- ModeUI never stores anything on Blizzard's button tables: its textures and
-- state live in weak tables keyed by the button.
local Kit = addon.Kit
local ONYX = Kit.onyx
M.art = setmetatable({}, { __mode = "k" })
M.skinState = setmetatable({}, { __mode = "k" })

-- The border's four edges, the background fill and its texture (Kit.SlotArt,
-- shared with the Cooldown Manager). The background shows at Background
-- Opacity everywhere: in ModeUI's empty slots and in Blizzard's own empty
-- buttons (shown by the game's Always Show Buttons, or while a spell is
-- dragged), so every bar looks alike.
function M:Art(host)
    local art = self.art[host]
    if art then return art end
    art = Kit.SlotArt(host)
    self.art[host] = art
    return art
end
M.PaintArt = Kit.PaintSlotArt
-- An empty slot: what shows where a button has no action.
function M:BuildSlot(parent)
    local slot = CreateFrame("Frame", nil, parent)
    self:Art(slot)
    slot:Hide()
    return slot
end
function M:PaintSlot(slot, style, g) M.PaintArt(self:Art(slot), slot, style, g) end

-- Crops the icon to the button's shape (Kit.CropIcon).
M.CropIcon = Kit.CropIcon

local Overlay = Kit.SlotOverlay
local function Fade(region) if region and region.SetAlpha then region:SetAlpha(0) end end
M.Overlay, M.Fade = Overlay, Fade

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

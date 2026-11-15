local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- The Mode button (docs/DESIGN_LANGUAGE.md, "Action buttons"): a Mode Button
-- face in the Background Color behind the icon, the icon filling the button
-- (cropped, never stretched), and the `frame` edge outside it (2px Gunmetal,
-- edge-lit, shadow and soft drop). Hover lights the edge's outer line Ivory;
-- a Border proc or ready glow swaps its rim color (Glow.lua). Blizzard's slot
-- art and frame are faded; pushed, checked and flash become flat overlays on
-- the icon. The icon takes the Mode tints for no power, unusable and out of
-- range. The same code skins Blizzard's buttons, the empty slots, the Edit
-- Mode stand-ins and the settings preview, so they always match.
--
-- ModeUI never stores anything on Blizzard's button tables: its textures and
-- state live in weak tables keyed by the button.
local Kit, Style, Public = addon.Kit, addon.Style, addon.IsPublic
local Tone = Style.Tone
M.art = setmetatable({}, { __mode = "k" })
M.skinState = setmetatable({}, { __mode = "k" })

-- The face and the edge. The face shows at Background Opacity everywhere: in
-- ModeUI's empty slots and in Blizzard's own empty buttons, so every bar
-- looks alike.
function M:Art(host)
    local art = self.art[host]
    if art then return art end
    art = { face = host:CreateTexture(nil, "BACKGROUND", nil, -7), edge = Style.Edge(host, "frame") }
    Style.ApplyAsset(art.face, "Button")
    self.art[host] = art
    return art
end
function M.PaintArt(art, host, style)
    art.face:ClearAllPoints(); art.face:SetAllPoints(host)
    Style.Paint(art.face, style.backgroundColor, style.backgroundOpacity / 100)
    art.edge:SetShown(style.border ~= "none")
    art.edge:Layout()
end
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
-- happens now; re-placing waits for the refresh after combat. Hover is the
-- edge's Ivory line, so Blizzard's highlight is faded too.
function M:RestyleArt(button)
    local state = self.skinState[button]
    if not state then return end
    local inset = state.g.inset
    Fade(button.NormalTexture or (button.GetNormalTexture and button:GetNormalTexture()))
    Fade(button.SlotArt); Fade(button.SlotBackground); Fade(button.Border); Fade(button.HighlightTexture)
    if addon.InCombat() then self:Refresh(); return end
    Overlay(button.PushedTexture, button, inset, Tone.shadow, 0.45)
    Overlay(button.CheckedTexture, button, inset, Tone.ivory, 0.28)
    Overlay(button.Flash, button, inset, Tone.rosewood, 0.35)
    Overlay(button.NewActionTexture, button, inset, Tone.ivory, 0.22)
    Overlay(button.SpellHighlightTexture, button, inset, Tone.ivory, 0.3)
end

-- Icon tints. Blizzard colors the icon white (usable), (0.5, 0.5, 1) (not
-- enough power) or 0.4 gray (unusable), and tints the keybind red out of
-- range (Text.lua reports it here); the icon takes the Mode tint instead.
M.iconState = setmetatable({}, { __mode = "k" })
M.iconButton = setmetatable({}, { __mode = "k" })
M.POWER_TINT = Style.Mix(Tone.power, Tone.mono.white, 0.7)
local tinting = false
local function Near(a, b) return math.abs(a - b) < 0.01 end
function M:PaintIcon(button)
    local state, icon = self.iconState[button], button.icon
    if not state or not icon then return end
    if not self.active then return end
    local color = state.range and Tone.rosewood or state.usable == "power" and M.POWER_TINT
        or state.usable == "unusable" and Tone.graphite.muted or Tone.mono.white
    tinting = true; Style.Paint(icon, color); tinting = false
end
local function Usable(r, g, b)
    if not (Public(r) and Public(g) and Public(b) and type(r) == "number") then return end
    return (Near(r, 0.5) and Near(g, 0.5) and Near(b, 1)) and "power"
        or (Near(r, 0.4) and Near(g, 0.4) and Near(b, 0.4)) and "unusable" or "usable"
end
local function IconColor(icon, r, g, b)
    if tinting then return end
    local button = M.iconButton[icon]
    local state, usable = button and M.iconState[button], Usable(r, g, b)
    if not state or not usable then return end
    state.usable = usable
    M:PaintIcon(button)
end
function M:SetOutOfRange(button, out)
    local state = self.iconState[button]
    if not state or state.range == out then return end
    state.range = out
    self:PaintIcon(button)
end
local function WatchIcon(button)
    local icon = button.icon
    if not icon or M.iconState[button] or not hooksecurefunc then return end
    -- The state Blizzard has drawn so far, read from the icon's color.
    local usable = icon.GetVertexColor and Usable(icon:GetVertexColor()) or "usable"
    M.iconState[button], M.iconButton[icon] = { usable = usable, range = false }, button
    hooksecurefunc(icon, "SetVertexColor", IconColor)
end

-- Hover: the edge's outer line in Ivory while the mouse is over the button.
local function Hover(button) local art = M.art[button]; if art then art.edge:SetHighlight("accent") end end
local function Leave(button) local art = M.art[button]; if art then art.edge:SetHighlight(nil) end end

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
    if not sample and not state.hovered and button.HookScript then
        state.hovered = true
        button:HookScript("OnEnter", Hover); button:HookScript("OnLeave", Leave)
    end
    if not sample then WatchIcon(button); self:PaintIcon(button) end
    self:RestyleArt(button)
    self:StyleTexts(button, style, g, sample)
end

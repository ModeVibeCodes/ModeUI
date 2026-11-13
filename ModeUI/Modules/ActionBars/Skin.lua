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
local ONYX, FLAT = Kit.onyx, Kit.FLAT
M.art = setmetatable({}, { __mode = "k" })
M.skinState = setmetatable({}, { __mode = "k" })

-- The border's four edges, the background fill and its texture. The border
-- is hollow, so a see-through background never takes on its color.
function M:Art(host)
    local art = self.art[host]
    if art then return art end
    art = { edges = {}, fill = host:CreateTexture(nil, "BACKGROUND", nil, -7), grain = host:CreateTexture(nil, "BACKGROUND", nil, -6) }
    for i = 1, 4 do art.edges[i] = host:CreateTexture(nil, "BACKGROUND", nil, -8) end
    self.art[host] = art
    return art
end

local function Edge(edge, host, point, x1, y1, relative, x2, y2)
    edge:ClearAllPoints()
    edge:SetPoint("TOPLEFT", host, point, x1, y1)
    edge:SetPoint("BOTTOMRIGHT", host, relative, x2, y2)
end

-- Rounded leaves out each corner's outermost pixel, so the edges meet in a
-- soft corner; Square fills it. The background shows at Background Opacity
-- everywhere: in ModeUI's empty slots and in Blizzard's own empty buttons
-- (shown by the game's Always Show Buttons, or while a spell is dragged), so
-- every bar looks alike. The slot texture adds its bevel and grain (ADD), so
-- the Background Color stays the base.
function M.PaintArt(art, host, style, g)
    local on = style.border ~= "none"
    local t, cut = g.border, (on and style.border == "rounded") and g.px or 0
    local top, bottom, left, right = art.edges[1], art.edges[2], art.edges[3], art.edges[4]
    Edge(top, host, "TOPLEFT", cut, 0, "TOPRIGHT", -cut, -t)
    Edge(bottom, host, "BOTTOMLEFT", cut, t, "BOTTOMRIGHT", -cut, 0)
    Edge(left, host, "TOPLEFT", 0, -cut, "BOTTOMLEFT", t, cut)
    Edge(right, host, "TOPRIGHT", -t, -cut, "BOTTOMRIGHT", 0, cut)
    for _, edge in ipairs(art.edges) do
        edge:SetTexture(FLAT); Kit.Tint(edge, style.borderColor, 1); edge:SetShown(on)
    end
    local alpha = style.backgroundOpacity / 100
    Kit.Inset(art.fill, host, t)
    art.fill:SetTexture(FLAT); Kit.Tint(art.fill, style.backgroundColor, alpha)
    Kit.Inset(art.grain, host, t)
    if not addon.Media:ApplyTexture(art.grain, "ActionBarSlot") then art.grain:SetTexture(FLAT) end
    if art.grain.SetBlendMode then art.grain:SetBlendMode("ADD") end
    art.grain:SetVertexColor(1, 1, 1, alpha)
end
-- An empty slot: what shows where a button has no action.
function M:BuildSlot(parent)
    local slot = CreateFrame("Frame", nil, parent)
    self:Art(slot)
    slot:Hide()
    return slot
end
function M:PaintSlot(slot, style, g) M.PaintArt(self:Art(slot), slot, style, g) end

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

local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- The totem bar (docs/DESIGN_LANGUAGE.md, "Action buttons", Totem bar; owner,
-- November 20, 2026): Blizzard's multi-cast bar (MultiCastActionBarFrame,
-- Blizzard_ActionBar/Shared/MultiCastActionBarFrame.lua in Forever) in the
-- Mode look. A reskin only: Blizzard keeps every button, its size, its
-- places and its Edit Mode system; ModeUI paints over them.
--   * the totem buttons, Call of the Elements and Totemic Recall: Mode
--     buttons in Action Bar 1's look (SkinButton), at Blizzard's 30 x 30;
--   * each element slot's rim in that element's color, flat (Tone.totem),
--     where Blizzard drew its colored totem frames (faded), on the totem
--     button and on the empty slot behind it;
--   * the totem picker (flyout): a Surface panel in Mode-Border, Mode buttons,
--     the Mode chevron in Ivory for Blizzard's arrows.
-- Blizzard re-sets only the texture coordinates of the art it swaps, so
-- faded art stays faded; the buttons are sized and skinned outside combat
-- (Apply), and the hooks only repaint.
local Style, Kit = addon.Style, addon.Kit
local Tone = Style.Tone
local SIZE = 30
local function Fade(region) if region and region.SetAlpha then region:SetAlpha(0) end end

-- The element of a totem slot (Blizzard's slot numbers), and its rim color.
local function Element(slot)
    if slot == _G.EARTH_TOTEM_SLOT then return Tone.totem.earth end
    if slot == _G.FIRE_TOTEM_SLOT then return Tone.totem.fire end
    if slot == _G.WATER_TOTEM_SLOT then return Tone.totem.water end
    if slot == _G.AIR_TOTEM_SLOT then return Tone.totem.air end
end
local function SlotOf(button)
    local slotButton = button and button.slotButton
    local ok, slot = pcall(function() return (slotButton or button):GetID() end)
    return ok and slot or nil
end

-- Action Bar 1's look at the totem bar's size.
function M:TotemStyle()
    local style = setmetatable({ width = SIZE, height = SIZE, spacing = 0, perLine = 1, orientation = "horizontal",
        start = "TOPLEFT" }, { __index = self.db.bar1 })
    return style, self.Geometry(style, 1, self.PixelSize(_G.MultiCastActionBarFrame or UIParent))
end

local function Tint(button, color)
    local art = M.art[button]
    if art then art.edge:SetTint(color) end
end

-- An empty element slot: the face and the element's rim; Blizzard's art faded.
function M:PaintTotemSlot(slot)
    if not (self.active and slot) then return end
    local style, g = self:TotemStyle()
    Fade(slot.background); Fade(slot.overlayTex); Fade(slot.GetHighlightTexture and slot:GetHighlightTexture())
    local art = self:Art(slot)
    M.PaintArt(art, slot, style, g)
    art.face:Show()
    Tint(slot, Element(SlotOf(slot)))
end

-- A totem button's element rim (Blizzard repaints its frame each update).
function M:PaintTotemButton(button)
    if not (self.active and button) then return end
    Fade(button.overlayTex)
    Tint(button, Element(SlotOf(button)))
end

-- A Mode chevron over one of Blizzard's flyout arrows (its art faded).
M.totemChevrons = setmetatable({}, { __mode = "k" })
local function Chevron(button, up)
    if not button then return end
    Fade(button.normalTexture or (button.GetNormalTexture and button:GetNormalTexture()))
    local chevron = M.totemChevrons[button]
    if not chevron then
        chevron = button:CreateTexture(nil, "ARTWORK")
        chevron:SetSize(12, 12); chevron:SetPoint("CENTER")
        addon.Media:ApplyTexture(chevron, "ModeChevron")
        M.totemChevrons[button] = chevron
    end
    chevron:SetRotation(up and math.pi or 0)
    Style.Paint(chevron, Tone.ivory)
    chevron:Show()
end

-- The totem picker: a Surface panel in Mode-Border and Mode buttons.
function M:SkinTotemFlyout(flyout)
    if not (self.active and flyout) then return end
    Fade(flyout.top); Fade(flyout.middle)
    if not self.totemPanel then
        local panel = { face = flyout:CreateTexture(nil, "BACKGROUND", nil, -8), edge = Style.Edge(flyout, "control") }
        Style.ApplyAsset(panel.face, "Solid")
        panel.face:SetAllPoints(flyout)
        self.totemPanel = panel
    end
    Style.Paint(self.totemPanel.face, Tone.graphite.panel, 0.95)
    self.totemPanel.edge:Layout()
    self.totemPanel.edge:SetShown(true)
    -- The buttons sit 2px apart: the panel's edge frames them, each icon
    -- cropped like a Mode icon.
    for _, button in ipairs(flyout.buttons or {}) do
        local w, h = button:GetWidth(), button:GetHeight()
        if button.icon and addon.IsNumber(w, 1) and addon.IsNumber(h, 1) then
            Kit.Inset(button.icon, button, 0)
            M.CropIcon(button.icon, { px = 1, w = w, h = h, inset = 0 })
        end
    end
    Chevron(_G.MultiCastFlyoutFrameCloseButton, false)
end

-- Every part, outside combat (Driver.lua, Apply).
function M:ApplyTotemBar()
    local bar = _G.MultiCastActionBarFrame
    if not (self.active and bar) or addon.InCombat() then return end
    local style, g = self:TotemStyle()
    local buttons = { _G.MultiCastSummonSpellButton, _G.MultiCastRecallSpellButton }
    for i = 1, 12 do buttons[#buttons + 1] = _G["MultiCastActionButton" .. i] end
    for _, button in ipairs(buttons) do
        if button then
            self:SkinButton(button, style, g)
            self:Art(button).face:Show()
            Fade(_G[(button:GetName() or "") .. "Highlight"])
            self:PaintTotemButton(button)
        end
    end
    for i = 1, 4 do self:PaintTotemSlot(_G["MultiCastSlotButton" .. i]) end
    Chevron(_G.MultiCastFlyoutFrameOpenButton, true)
    local summon = _G.MultiCastSummonSpellButton
    Chevron(summon and summon.flyoutButton, true)
    if not self.totemHooked and hooksecurefunc then
        self.totemHooked = true
        local function Hook(name, fn) if type(_G[name]) == "function" then hooksecurefunc(_G, name, fn) end end
        Hook("MultiCastSlotButton_Update", function(slot) M:PaintTotemSlot(slot) end)
        Hook("MultiCastActionButton_Update", function(button) M:PaintTotemButton(button) end)
        Hook("MultiCastFlyoutFrame_ToggleFlyout", function(flyout) M:SkinTotemFlyout(flyout) end)
        Hook("MultiCastFlyoutFrameOpenButton_Show", function(open) if M.active then Chevron(open, true) end end)
    end
end

-- Switched off: Blizzard's own art back, ModeUI's hidden (the buttons'
-- size and icon crop come back with the reload Action Bars asks for).
function M:RestoreTotemBar()
    if not _G.MultiCastActionBarFrame then return end
    local function Show(region) if region and region.SetAlpha then region:SetAlpha(1) end end
    for i = 1, 12 do local b = _G["MultiCastActionButton" .. i]; if b then Show(b.overlayTex) end end
    for i = 1, 4 do
        local slot = _G["MultiCastSlotButton" .. i]
        if slot then Show(slot.background); Show(slot.overlayTex); Show(slot.GetHighlightTexture and slot:GetHighlightTexture()) end
    end
    local flyout = _G.MultiCastFlyoutFrame
    if flyout then Show(flyout.top); Show(flyout.middle) end
    for button, chevron in pairs(self.totemChevrons) do
        chevron:Hide(); Show(button.normalTexture or (button.GetNormalTexture and button:GetNormalTexture()))
    end
    for host, art in pairs(self.art) do
        if host.overlayTex or host.background then art.edge:SetShown(false); art.face:SetShown(false) end
    end
    if self.totemPanel then self.totemPanel.face:SetShown(false); self.totemPanel.edge:SetShown(false) end
end

local _, addon = ...
local M = addon.Chat
if not M then return end

-- The button compartment: one capsule at the right end of the main window's
-- tab row, holding Blizzard's chat buttons as equal cells with one-pixel
-- dividers: Channels (cyan while a voice channel is active), Voice Deafen and
-- Voice Mute (only while voice chat shows them) and the Chat Menu. Each
-- button is Blizzard's own, moved into the compartment, so its clicks,
-- menus, tooltips and keybindings stay Blizzard's; its round art is faded and
-- a Mode glyph drawn instead. Blizzard's chat alerts (Social and Text to
-- Speech) stack just above the compartment. Buttons: Hidden hides it all.
local Skin, Kit = addon.Skin, addon.Kit
local C = Skin.colors
local Snap = Skin.Snap
local CELL_WIDTH = 22
-- Glyphs: ModeUI's for Channels and the menu; voice buttons keep their own
-- icons (their art shows the voice state), shrunk into the cell.
local GLYPHS = { ChatFrameChannelButton = "ChatChannels", ChatFrameMenuButton = "ChatMenu" }

function M:CompartmentButtons()
    local list = {}
    for _, name in ipairs({ "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
        "ChatFrameToggleVoiceMuteButton", "ChatFrameMenuButton" }) do
        local button = _G[name]
        if button and button.GetObjectType then list[#list + 1] = { name = name, button = button } end
    end
    return list
end

function M:BuildCompartment()
    if self.compartment then return self.compartment end
    local box = CreateFrame("Frame", "ModeUIChatButtons", UIParent)
    box:SetFrameStrata("MEDIUM")
    box.parts = Skin.Panel(box, "BACKGROUND", -8)
    box.dividers = {}
    self.compartment = box
    for _, entry in ipairs(self:CompartmentButtons()) do
        local button = entry.button
        -- Shown or hidden by voice chat: the row closes up around it.
        if button.HookScript then
            button:HookScript("OnShow", function() if self.active then self:PaintCompartment() end end)
            button:HookScript("OnHide", function() if self.active then self:PaintCompartment() end end)
            button:HookScript("OnEnter", function() self:PaintCell(button, true) end)
            button:HookScript("OnLeave", function() self:PaintCell(button, false) end)
        end
    end
    return box
end

-- A cell: Blizzard's art faded (or, for voice buttons, kept as the icon),
-- a hover fill and the glyph.
local function CellParts(button)
    local parts = Skin.parts[button]
    if parts and parts.hover then return parts end
    parts = parts or { regions = {} }
    Skin.parts[button] = parts
    parts.hover = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    parts.hover:SetTexture(Kit.FLAT)
    parts.regions[parts.hover] = true
    return parts
end

function M:PaintCell(button, hovered)
    local parts = Skin.parts[button]
    if not parts or not parts.hover then return end
    parts.hover:SetShown(hovered and self.active == true)
    if parts.glyph then
        local active = button == ChatFrameChannelButton and C_VoiceChat and C_VoiceChat.GetActiveChannelID
            and C_VoiceChat.GetActiveChannelID() ~= nil
        Kit.Tint(parts.glyph, (hovered or active) and C.accent or C.label, 1)
    end
end

local function SkinCell(self, entry, px, size, width)
    local button = entry.button
    local parts = CellParts(button)
    parts.hover:ClearAllPoints(); parts.hover:SetAllPoints(button)
    Kit.Tint(parts.hover, C.hover, 1)
    parts.hover:Hide()
    local glyph = GLYPHS[entry.name]
    if glyph then
        for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            if button[key] then Skin.Fade(button[key](button)) end
        end
        Skin.Fade(button.Icon)
        if not parts.glyph then
            parts.glyph = button:CreateTexture(nil, "OVERLAY")
            parts.regions[parts.glyph] = true
            addon.Media:ApplyTexture(parts.glyph, glyph)
        end
        local icon = Snap(16, px)
        parts.glyph:ClearAllPoints(); parts.glyph:SetPoint("CENTER")
        parts.glyph:SetSize(icon, icon)
    end
    button:SetSize(width, size)
    self:PaintCell(button, false)
end

-- Lays the shown buttons out left to right with one-pixel dividers, right
-- aligned to the main window's box, one pixel above it (so it sits centered
-- on the tab row).
function M:PaintCompartment()
    if not self.active then return end
    local main = ChatFrame1
    local anchor = main and self:Box(main)
    if not anchor then return end
    local box = self:BuildCompartment()
    if self.db.buttons == "hidden" then box:Hide(); return end
    local px = Kit.PixelSize(box)
    local size, width = Snap(self.BUTTON_SIZE, px), Snap(CELL_WIDTH, px)
    local x, shown = px, 0
    for _, divider in ipairs(box.dividers) do divider:Hide() end
    for _, entry in ipairs(self:CompartmentButtons()) do
        local button = entry.button
        if button:GetParent() ~= box then button:SetParent(box) end
        button:SetFrameStrata("MEDIUM")
        SkinCell(self, entry, px, size - 2 * px, width)
        local visible = button:IsShown()
        if addon.IsPublic(visible) and visible then
            if shown > 0 then
                local divider = box.dividers[shown]
                if not divider then
                    divider = box:CreateTexture(nil, "ARTWORK")
                    divider:SetTexture(Kit.FLAT)
                    box.dividers[shown] = divider
                end
                divider:ClearAllPoints()
                divider:SetPoint("TOPLEFT", box, "TOPLEFT", x, -px)
                divider:SetSize(px, size - 2 * px)
                Kit.Tint(divider, C.fieldRim, 1)
                divider:Show()
                x = x + px
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", box, "TOPLEFT", x, -px)
            x, shown = x + width, shown + 1
        end
    end
    box:SetSize(math.max(x + px, 2 * px), size)
    box:ClearAllPoints()
    box:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, px)
    Skin.PaintPanel(box.parts, box, C.field, 0.85, C.fieldRim, px)
    box:SetShown(shown > 0)
    -- Social and Text to Speech: Blizzard's alert column, above the compartment.
    if ChatAlertFrame and ChatAlertFrame.ClearAllPoints then
        ChatAlertFrame:ClearAllPoints()
        ChatAlertFrame:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, Snap(2, px))
    end
end

local _, addon = ...
local M = addon.Chat
if not M then return end

-- The button compartment: one Mode control (a Graphite base, the `control`
-- edge inside it) at the right end of the main window's tab row, holding
-- Blizzard's chat buttons as cells with one-pixel Graphite dividers: Friends
-- (the online count beside its glyph), Text to Speech and Voice Deafen / Mute
-- (only while the game shows them), Channels (Ivory while a voice channel is
-- active) and the Chat Menu. Each button is Blizzard's own,
-- moved into the compartment, so its clicks, menus, tooltips, toasts and
-- keybindings stay Blizzard's; its round art is hidden and a Mode glyph drawn
-- instead (the voice and speech buttons keep their own state icons, shrunk).
-- Friends is one of Blizzard's chat alerts: the alert column places it again
-- whenever it updates, so ModeUI puts it back right after (post-hook). The
-- other alerts (Battle.net toasts, voice notices) stack above the
-- compartment. Buttons: Hidden hides it all.
local Skin, Kit, Style = addon.Skin, addon.Kit, addon.Style
local C = Skin.mode
local Snap = Skin.Snap
-- The cells sit inside the compartment's edge.
local CONTROL = Style.EdgeReach("control")
local CELL_WIDTH, FRIENDS_WIDTH = 22, 34
-- Glyphs: ModeUI's for Friends, Channels and the menu.
local GLYPHS = { QuickJoinToastButton = "ChatFriends", ChatFrameChannelButton = "ChatChannels", ChatFrameMenuButton = "ChatMenu" }
local ORDER = { "QuickJoinToastButton", "TextToSpeechButton", "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton", "ChatFrameChannelButton", "ChatFrameMenuButton" }
-- The friends button's own art: hidden for good (its toast animations
-- fade these in and out, so alpha alone wouldn't hold).
local FRIENDS_ART = { "FriendsButton", "QueueButton", "FlashingLayer" }

function M:CompartmentButtons()
    local list = {}
    for _, name in ipairs(ORDER) do
        local button = _G[name]
        if button and button.GetObjectType then
            list[#list + 1] = { name = name, button = button, width = name == "QuickJoinToastButton" and FRIENDS_WIDTH or CELL_WIDTH }
        end
    end
    return list
end

function M:BuildCompartment()
    if self.compartment then return self.compartment end
    local box = CreateFrame("Frame", "ModeUIChatButtons", UIParent)
    box:SetFrameStrata("MEDIUM")
    box.parts = Skin.Box(box, "control", { inset = CONTROL })
    box.dividers = {}
    self.compartment = box
    for _, entry in ipairs(self:CompartmentButtons()) do
        local button = entry.button
        -- Shown or hidden by the game: the row closes up around it.
        if button.HookScript then
            button:HookScript("OnShow", function() if self.active then self:PaintCompartment() end end)
            button:HookScript("OnHide", function() if self.active then self:PaintCompartment() end end)
            button:HookScript("OnEnter", function() self:PaintCell(button, true) end)
            button:HookScript("OnLeave", function() self:PaintCell(button, false) end)
        end
    end
    -- The alert column places Friends again whenever it updates.
    if ChatAlertFrame and ChatAlertFrame.UpdateAnchors and hooksecurefunc then
        hooksecurefunc(ChatAlertFrame, "UpdateAnchors", function()
            if self.active and not self.placingButtons then self:PaintCompartment() end
        end)
    end
    return box
end

-- A cell: Blizzard's art hidden (or, for voice and speech, kept as the
-- icon), a hover fill and the glyph.
local function CellParts(button)
    local parts = Skin.parts[button]
    if parts and parts.hover then return parts end
    parts = parts or { regions = {} }
    Skin.parts[button] = parts
    parts.hover = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    Style.ApplyAsset(parts.hover, "Solid")
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

local function SkinCell(self, entry, px, height)
    local button = entry.button
    local parts = CellParts(button)
    local width = Snap(entry.width, px)
    parts.hover:ClearAllPoints(); parts.hover:SetAllPoints(button)
    Style.Paint(parts.hover, C.chosen)
    parts.hover:Hide()
    local glyph = GLYPHS[entry.name]
    if glyph then
        for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            if button[key] then Skin.Fade(button[key](button)) end
        end
        Skin.Fade(button.Icon)
        for _, key in ipairs(FRIENDS_ART) do if button[key] then Skin.Suppress(button[key]) end end
        if not parts.glyph then
            parts.glyph = button:CreateTexture(nil, "OVERLAY")
            parts.regions[parts.glyph] = true
            addon.Media:ApplyTexture(parts.glyph, glyph)
        end
        local icon = Snap(16, px)
        parts.glyph:ClearAllPoints()
        if entry.name == "QuickJoinToastButton" then parts.glyph:SetPoint("LEFT", button, "LEFT", Snap(3, px), 0)
        else parts.glyph:SetPoint("CENTER") end
        parts.glyph:SetSize(icon, icon)
    end
    -- The friends count (and the quick join count it swaps with) beside the glyph.
    for _, key in ipairs({ "FriendCount", "QueueCount" }) do
        local count = button[key]
        if count and count.SetPoint then
            count:ClearAllPoints()
            count:SetPoint("RIGHT", button, "RIGHT", -Snap(4, px), 0)
            Skin.Font(count, self:FontPath(), 10, self.db.outline, true, px)
            count:SetTextColor(C.label[1], C.label[2], C.label[3], 1)
        end
    end
    button:SetSize(width, height)
    self:PaintCell(button, false)
    return width
end

-- Lays the shown buttons out left to right with one-pixel dividers inside
-- the edge, right aligned to the main window's box, one pixel above it (so
-- it sits centered on the tab row).
function M:PaintCompartment()
    if not self.active then return end
    local main = ChatFrame1
    local anchor = main and self:Box(main)
    if not anchor then return end
    local box = self:BuildCompartment()
    if self.db.buttons == "hidden" then box:Hide(); return end
    self.placingButtons = true
    local px = Kit.PixelSize(box)
    -- The cells keep their 18px; the box grows by the edge's reach past 1px.
    local edge = CONTROL * px
    local size = Snap(self.BUTTON_SIZE, px) + 2 * (edge - px)
    local x, shown = edge, 0
    for _, divider in ipairs(box.dividers) do divider:Hide() end
    for _, entry in ipairs(self:CompartmentButtons()) do
        local button = entry.button
        if button:GetParent() ~= box then button:SetParent(box) end
        button:SetFrameStrata("MEDIUM")
        local width = SkinCell(self, entry, px, size - 2 * edge)
        local visible = button:IsShown()
        if addon.IsPublic(visible) and visible then
            if shown > 0 then
                local divider = box.dividers[shown]
                if not divider then
                    divider = box:CreateTexture(nil, "ARTWORK")
                    Style.ApplyAsset(divider, "Solid")
                    box.dividers[shown] = divider
                end
                divider:ClearAllPoints()
                divider:SetPoint("TOPLEFT", box, "TOPLEFT", x, -edge)
                divider:SetSize(px, size - 2 * edge)
                Style.Paint(divider, C.line)
                divider:Show()
                x = x + px
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", box, "TOPLEFT", x, -edge)
            x, shown = x + width, shown + 1
        end
    end
    box:SetSize(math.max(x + edge, 2 * edge), size)
    box:ClearAllPoints()
    box:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, px)
    Skin.PaintBox(box.parts, box, "Solid", C.field, 0.85, true)
    box:SetShown(shown > 0)
    -- The other chat alerts: Blizzard's alert column, above the compartment.
    if ChatAlertFrame and ChatAlertFrame.ClearAllPoints then
        ChatAlertFrame:ClearAllPoints()
        ChatAlertFrame:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, Snap(2, px))
    end
    self.placingButtons = false
end

local _, addon = ...
local M = addon.Chat
if not M then return end

-- Glass tabs. Blizzard's tab art (the left, middle and right pieces, their
-- active and highlight copies) is faded; ModeUI draws a frosted glass pane
-- across the tab's bottom Tab Height, feathered at its sides and top, with a
-- soft light sheen over its top half and a faint one-pixel top line. The
-- selected tab has white text and a two-pixel cyan bar along the bottom;
-- the others use the label gray. Whisper tabs keep Blizzard's whisper color.
-- With Glass Tabs off, the pane is a flat dark field instead.
-- How visible each tab is (selected, others, away) is Fade.lua's job.
-- The tab's text is never measured: whisper tab names can be secret.
local Skin, Kit = addon.Skin, addon.Kit
local C = Skin.colors
local Snap = Skin.Snap
local ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight" }

local function Parts(tab)
    local parts = Skin.parts[tab]
    if parts and parts.glass then return parts end
    parts = parts or { regions = {} }
    Skin.parts[tab] = parts
    local function Own(region) parts.regions[region] = true; return region end
    parts.glass = Own(tab:CreateTexture(nil, "BACKGROUND", nil, -8))
    parts.sheen = Own(tab:CreateTexture(nil, "BACKGROUND", nil, -7))
    parts.line = Own(tab:CreateTexture(nil, "BACKGROUND", nil, -6))
    parts.bar = Own(tab:CreateTexture(nil, "ARTWORK", nil, 7))
    for _, key in ipairs({ "sheen", "line", "bar" }) do parts[key]:SetTexture(Kit.FLAT) end
    return parts
end

-- Whether a tab's window is the one showing: not docked, or the dock's pick.
function M:IsSelected(tab, frame)
    frame = frame or _G["ChatFrame" .. (tab.GetID and tab:GetID() or 0)]
    if not frame then return false end
    if not frame.isDocked then return true end
    local dock = GENERAL_CHAT_DOCK
    if dock and FCFDock_GetSelectedWindow then
        local ok, selected = pcall(FCFDock_GetSelectedWindow, dock)
        return ok and selected == frame
    end
    return false
end

function M:SkinTab(tab, frame)
    for _, key in ipairs(ART) do Skin.Fade(tab[key]) end
    local parts = Parts(tab)
    local px = Kit.PixelSize(tab)
    parts.px = px
    local height, gap = Snap(self.TAB_HEIGHT, px), Snap(self.TAB_GAP / 2, px)
    -- The pane: the tab's full width less half the gap on each side, and
    -- Tab Height tall from the tab's bottom (the window's top edge).
    local glass = parts.glass
    glass:ClearAllPoints()
    glass:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", gap, 0)
    glass:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -gap, 0)
    glass:SetHeight(height)
    if self.db.glassTabs then
        addon.Media:ApplyTexture(glass, "ModeGlass")
        Kit.Unsnap(glass)
        Kit.Tint(glass, self.GLASS_COLOR, 0.62)
    else
        if glass.ClearTextureSlice then glass:ClearTextureSlice() end
        glass:SetTexture(Kit.FLAT); glass:SetTexCoord(0, 1, 0, 1)
        Kit.Tint(glass, C.field, 0.9)
    end
    -- The sheen: a soft white wash over the top half, clear at the middle.
    local inner = Snap(2, px)
    local sheen = parts.sheen
    sheen:ClearAllPoints()
    sheen:SetPoint("TOPLEFT", glass, "TOPLEFT", inner, -px)
    sheen:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -inner, -px)
    sheen:SetHeight(Snap(self.TAB_HEIGHT / 2, px))
    Kit.Gradient(sheen, { 1, 1, 1, 0.07 }, { 1, 1, 1, 0 }, 0.04)
    sheen:SetShown(self.db.glassTabs)
    -- A faint light line along the top, inside the feathered corners.
    local line = parts.line
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", glass, "TOPLEFT", Snap(3, px), -px)
    line:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -Snap(3, px), -px)
    line:SetHeight(px)
    Kit.Tint(line, { 1, 1, 1 }, 0.08)
    line:SetShown(self.db.glassTabs)
    -- The selected tab's cyan bar, Tab Padding in from the pane's sides.
    local bar, pad = parts.bar, Snap(self.TAB_PADDING / 2, px)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", glass, "BOTTOMLEFT", pad, 0)
    bar:SetPoint("BOTTOMRIGHT", glass, "BOTTOMRIGHT", -pad, 0)
    bar:SetHeight(Snap(2, px))
    Kit.Tint(bar, C.accent, 1)
    -- Text: the chat face at Tab Text Size. Blizzard centers it 5 px under
    -- the middle of its 32 px tab, which is the middle of a 22 px pane, and
    -- places the whisper icon beside it, so its anchors stay Blizzard's.
    local text = tab.Text or (tab.GetFontString and tab:GetFontString())
    if text then Skin.Font(text, self:FontPath(), self.db.tabFontSize, self.db.outline, self.db.shadow, px) end
    self:PaintTabState(tab, self:IsSelected(tab, frame))
    Skin.PinAlpha(tab, function(target) return self:TabAlpha(target) end)
end

-- Selected or not: the cyan bar and the text color. Runs after Blizzard's
-- FCFTab_UpdateColors, which colors the text first.
function M:PaintTabState(tab, selected)
    local parts = Skin.parts[tab]
    if not parts or not parts.bar then return end
    selected = selected and true or false
    parts.bar:SetShown(selected)
    local text = tab.Text or (tab.GetFontString and tab:GetFontString())
    -- Whisper tabs carry their chat type's color; the rest are Mode gray.
    if text and not tab.selectedColorTable then
        local color = selected and C.heading or C.label
        text:SetTextColor(color[1], color[2], color[3], 1)
    end
end

local _, addon = ...
local M = addon.Chat
if not M then return end

-- Glass tabs. Blizzard's tab art (the left, middle and right pieces, their
-- active and highlight copies) is faded; ModeUI draws a pane resting on the
-- window's border (Blizzard anchors each tab's bottom to the box's top):
--   Glass  the ModeGlass texture (feathered sides and top), a soft white
--          wash over its top half, a diagonal glint (ModeSheen, added light)
--          and a faint one-pixel top line
--   Solid  a flat dark field
-- The selected tab stands Tab Height tall with white text and a two-pixel
-- cyan bar; the others are tucked down Tuck Depth with label-gray text.
-- Whisper tabs keep Blizzard's whisper color. How visible each tab is
-- (selected, others, idle) is Fade.lua's job.
-- Tab text is measured only for General, Combat Log and other named windows,
-- to size the tab to the Mode face; whisper tab names can be secret and are
-- never measured.
local Skin, Kit = addon.Skin, addon.Kit
local C = Skin.colors
local Snap = Skin.Snap
local ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight" }
-- PanelTemplates_TabResize's side padding (SharedUIPanelTemplates).
local TAB_SIDES_PADDING = 20

local function Parts(tab)
    local parts = Skin.parts[tab]
    if parts and parts.glass then return parts end
    parts = parts or { regions = {} }
    Skin.parts[tab] = parts
    local function Own(region) parts.regions[region] = true; return region end
    parts.glass = Own(tab:CreateTexture(nil, "BACKGROUND", nil, -8))
    parts.sheen = Own(tab:CreateTexture(nil, "BACKGROUND", nil, -7))
    parts.glint = Own(tab:CreateTexture(nil, "BACKGROUND", nil, -6))
    parts.line = Own(tab:CreateTexture(nil, "BACKGROUND", nil, -5))
    parts.bar = Own(tab:CreateTexture(nil, "ARTWORK", nil, 7))
    for _, key in ipairs({ "sheen", "line", "bar" }) do parts[key]:SetTexture(Kit.FLAT) end
    addon.Media:ApplyTexture(parts.glint, "ModeSheen")
    parts.glint:SetBlendMode("ADD")
    return parts
end

local function TextOf(tab) return tab.Text or (tab.GetFontString and tab:GetFontString()) end
local function FrameOf(tab) return _G["ChatFrame" .. (tab.GetID and tab:GetID() or 0)] end

-- Whether a tab's window is the one showing: not docked, or the dock's pick.
function M:IsSelected(tab, frame)
    frame = frame or FrameOf(tab)
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
    parts.px = Kit.PixelSize(tab)
    local text = TextOf(tab)
    if text then Skin.Font(text, self:FontPath(), self.db.tabFontSize, self.db.outline, self.db.shadow, parts.px) end
    self:SizeTab(tab, frame)
    self:PaintTabState(tab, self:IsSelected(tab, frame))
    Skin.PinAlpha(tab, function(target) return self:TabAlpha(target) end)
end

-- Sizes a tab to its text in the Mode face, as Blizzard's
-- PanelTemplates_TabResize does with its own font: General, Combat Log and
-- other named windows docked in a fixed place or undocked. Dynamic docked
-- tabs keep the dock's width, and whisper tabs Blizzard's fixed width.
function M:SizeTab(tab, frame, padding, minWidth, maxWidth)
    frame = frame or FrameOf(tab)
    local text = TextOf(tab)
    if not (frame and text and text.SetWidth and tab.SetWidth) then return false end
    if frame.chatType == "WHISPER" or frame.chatType == "BN_WHISPER" then return false end
    if frame.isDocked and not frame.isStaticDocked then return false end
    text:SetWidth(0)
    local width = text:GetStringWidth()
    if not (addon.IsPublic(width) and addon.IsNumber(width, 0, 2000)) then return false end
    width = math.ceil(width)
    local pad = addon.IsNumber(padding) and padding or (addon.IsNumber(tab.sizePadding) and tab.sizePadding or 0)
    local total = width + TAB_SIDES_PADDING + pad
    if addon.IsNumber(maxWidth) and total > maxWidth then total = maxWidth; width = total - TAB_SIDES_PADDING - pad end
    if addon.IsNumber(minWidth) and total < minWidth then total = minWidth end
    text:SetWidth(width)
    tab:SetWidth(total)
    return true
end

-- The pane: the tab's width less half the gap each side, resting on the
-- border; Tab Height tall when selected, tucked Tuck Depth lower otherwise.
-- The text sits on the pane's middle.
function M:PaintPane(tab, selected)
    local parts = Skin.parts[tab]
    if not parts or not parts.glass then return end
    local px = parts.px or 1
    local full = Snap(self.db.tabHeight, px)
    -- (Snap never answers less than a pixel, so a Tuck Depth of 0 is checked first.)
    local tuck = (selected or self.db.tuckDepth == 0) and 0 or math.min(full - Snap(12, px), Snap(self.db.tuckDepth, px))
    local height, gap = full - tuck, Snap(self.TAB_GAP / 2, px)
    local glass = parts.glass
    glass:ClearAllPoints()
    glass:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", gap, 0)
    glass:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -gap, 0)
    glass:SetHeight(height)
    local glassy = self.db.glassTabs
    if glassy then
        addon.Media:ApplyTexture(glass, "ModeGlass")
        Kit.Unsnap(glass)
        Kit.Tint(glass, self.GLASS_COLOR, selected and 0.62 or 0.5)
    else
        if glass.ClearTextureSlice then glass:ClearTextureSlice() end
        glass:SetTexture(Kit.FLAT); glass:SetTexCoord(0, 1, 0, 1)
        Kit.Tint(glass, selected and C.selected or C.field, 0.92)
    end
    -- The wash: a soft white gradient over the top half, clear at the middle.
    local inner = Snap(2, px)
    local sheen = parts.sheen
    sheen:ClearAllPoints()
    sheen:SetPoint("TOPLEFT", glass, "TOPLEFT", inner, -px)
    sheen:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -inner, -px)
    sheen:SetHeight(Snap(height / 2, px))
    Kit.Gradient(sheen, { 1, 1, 1, 0.1 }, { 1, 1, 1, 0 }, 0.05)
    -- The glint: a diagonal band of added light across the pane.
    local glint = parts.glint
    glint:ClearAllPoints()
    glint:SetPoint("TOPLEFT", glass, "TOPLEFT", inner, -px)
    glint:SetPoint("BOTTOMRIGHT", glass, "BOTTOMRIGHT", -inner, 0)
    glint:SetVertexColor(1, 1, 1, selected and 0.16 or 0.1)
    -- A faint light line along the top, inside the feathered corners.
    local line = parts.line
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", glass, "TOPLEFT", Snap(3, px), -px)
    line:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -Snap(3, px), -px)
    line:SetHeight(px)
    Kit.Tint(line, { 1, 1, 1 }, 0.1)
    sheen:SetShown(glassy); glint:SetShown(glassy); line:SetShown(glassy)
    -- The selected tab's cyan bar, half Tab Padding in from the pane's sides.
    local bar, pad = parts.bar, Snap(self.TAB_PADDING / 2, px)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", glass, "BOTTOMLEFT", pad, 0)
    bar:SetPoint("BOTTOMRIGHT", glass, "BOTTOMRIGHT", -pad, 0)
    bar:SetHeight(Snap(2, px))
    Kit.Tint(bar, C.accent, 1)
    bar:SetShown(selected)
    -- Text on the pane's middle; the whisper icon, anchored to the text, follows.
    local text = TextOf(tab)
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", glass, "CENTER", 0, 0)
    end
end

-- Selected or not: the pane, the cyan bar and the text color. Runs after
-- Blizzard's FCFTab_UpdateColors, which colors the text first.
function M:PaintTabState(tab, selected)
    local parts = Skin.parts[tab]
    if not parts or not parts.bar then return end
    selected = selected and true or false
    self:PaintPane(tab, selected)
    local text = TextOf(tab)
    -- Whisper tabs carry their chat type's color; the rest are Mode gray.
    if text and not tab.selectedColorTable then
        local color = selected and C.heading or C.label
        text:SetTextColor(color[1], color[2], color[3], 1)
    end
end

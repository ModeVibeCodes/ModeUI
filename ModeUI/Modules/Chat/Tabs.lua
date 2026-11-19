local _, addon = ...
local M = addon.Chat
if not M then return end

-- Mode tabs (the approved Phase 7 probe). Blizzard's tab art (the left,
-- middle and right pieces, their active and highlight copies) is faded;
-- ModeUI draws a pane resting on the window's edge (Blizzard anchors each
-- tab's bottom to the box's top): a Mode control, its `control` edge inside
-- it (Mode-Thin, each ring in pieces: a pane is shorter than the sliced art,
-- which the client would shrink to square corners), in Graphite raised:
--   Glass  Mode Glass (its base and lift) at 75%, so the world shows through
--   Solid  the Mode Button face
-- The selected tab stands Tab Height tall in the chosen tone, its label and
-- its edge's outer line Ivory; the others are tucked down Tuck Depth with
-- Graphite secondary text.
-- Whisper tabs keep Blizzard's whisper color. How visible each tab is
-- (selected, others, idle) is Fade.lua's job.
-- Tab text is measured only for General, Combat Log and other named windows,
-- to size the tab to the Mode face; whisper tab names can be secret and are
-- never measured. A whisper tab's name (Blizzard's fixed width, justified
-- left, its conversation icon to its left) sits left on the pane, clear of the
-- icon; the other names sit on the pane's middle.
local Skin, Kit, Style = addon.Skin, addon.Kit, addon.Style
local C = Skin.mode
local CONTROL = Style.EdgeReach("control")
local Snap = Skin.Snap
local ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight" }
-- PanelTemplates_TabResize's side padding (SharedUIPanelTemplates).
local TAB_SIDES_PADDING = 20
-- A whisper tab's inset from the pane's left, before its icon.
local WHISPER_INSET = 6

local function Parts(tab)
    local parts = Skin.parts[tab]
    if parts and parts.pane then return parts end
    parts = Skin.Box(tab, "control", { inset = CONTROL, style = "thin", pieces = true })
    -- The pane's place (an empty texture the face and edge follow).
    parts.pane = tab:CreateTexture(nil, "BACKGROUND", nil, -8)
    parts.pane:SetAlpha(0)
    parts.regions[parts.pane] = true
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
    if text then Skin.Font(text, Style.Weighted(self:FontPath(), "semibold"), self.db.tabFontSize, self.db.outline, self.db.shadow, parts.px) end
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
-- edge; Tab Height tall when selected, tucked Tuck Depth lower otherwise.
-- The text sits on the pane's middle, a whisper tab's on its left.
function M:PaintPane(tab, selected)
    local parts = Skin.parts[tab]
    if not parts or not parts.pane then return end
    local px = parts.px or 1
    local full = Snap(self.db.tabHeight, px)
    -- (Snap never answers less than a pixel, so a Tuck Depth of 0 is checked first.)
    local tuck = (selected or self.db.tuckDepth == 0) and 0 or math.min(full - Snap(12, px), Snap(self.db.tuckDepth, px))
    local height, gap = full - tuck, Snap(self.TAB_GAP / 2, px)
    local pane = parts.pane
    pane:ClearAllPoints()
    pane:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", gap, 0)
    pane:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -gap, 0)
    pane:SetHeight(height)
    local glass = self.db.glassTabs
    Skin.PaintBox(parts, pane, glass and "Glass" or "Button", selected and C.chosen or C.face, glass and 0.75 or 1, true,
        selected and "accent" or nil)
    -- The text; the conversation icon, anchored to its left, follows. Only
    -- Blizzard's temporary (whisper) tabs have one.
    local text = TextOf(tab)
    if text then
        text:ClearAllPoints()
        local icon = tab.conversationIcon
        if icon then
            local width = icon.IsShown and icon:IsShown() and icon:GetWidth()
            width = addon.IsNumber(width, 1, 64) and Snap(width, px) or 0
            if text.SetJustifyH then text:SetJustifyH("LEFT") end
            text:SetPoint("LEFT", pane, "LEFT", Snap(WHISPER_INSET, px) + width, 0)
        else
            text:SetPoint("CENTER", pane, "CENTER", 0, 0)
        end
    end
end

-- Selected or not: the pane, its Ivory line and the text color. Runs after
-- Blizzard's FCFTab_UpdateColors, which colors the text first.
function M:PaintTabState(tab, selected)
    local parts = Skin.parts[tab]
    if not parts or not parts.pane then return end
    selected = selected and true or false
    self:PaintPane(tab, selected)
    local text = TextOf(tab)
    -- Whisper tabs carry their chat type's color; the rest are Ivory when
    -- selected, Graphite secondary otherwise.
    if text and not tab.selectedColorTable then
        local color = selected and C.accent or C.label
        text:SetTextColor(color[1], color[2], color[3], 1)
    end
end

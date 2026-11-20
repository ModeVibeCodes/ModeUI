local _, addon = ...
local M = addon.Chat
if not M then return end

-- One chat window in the Mode look. Blizzard's background and border
-- textures (CHAT_FRAME_TEXTURES) are hidden, so its fades skip them.
-- Blizzard's Background region stays as the window's box: ModeUI moves it to
-- Text Inset around the messages (plus the border, the edit box when it sits
-- inside, and the scroll bar's gutter), and the tabs, dock, button frame and
-- alerts that Blizzard anchors to it follow. On the box, the Mode window
-- (docs/DESIGN_LANGUAGE.md, "Windows and panels"): Mode Panel in Background
-- Color at Background Opacity, and the `window` edge inside the box on its
-- own frame above the window (no masks; the rim covers its own corners). A
-- see-through window has no soft drop, which would only darken it. The edit
-- box is a field in the `control` edge drawn Mode-Blizz, its outer line Ivory
-- while typing: inside the edge at the bottom or top, see-through on a band
-- shaded a little darker than the window, EDIT_PAD in from its sides; or
-- Below, Edit Gap under the window on a Graphite base. Sizes are whole
-- physical pixels.
local Skin, Kit, Style = addon.Skin, addon.Kit, addon.Style
local C = Skin.mode
local REACH, CONTROL = Style.EdgeReach("window"), Style.EdgeReach("control")
local Snap = Skin.Snap
local TEXTURES = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture", "ButtonFrameBackground", "ButtonFrameTopLeftTexture",
    "ButtonFrameBottomLeftTexture", "ButtonFrameTopRightTexture", "ButtonFrameBottomRightTexture", "ButtonFrameLeftTexture",
    "ButtonFrameRightTexture", "ButtonFrameBottomTexture", "ButtonFrameTopTexture" }
-- The edit field's border style; the band's padding round the field and how
-- much it darkens the window (black over the window's face).
local EDIT_STYLE, EDIT_PAD, BAND_SHADE = "obsidian", 3, 0.15

-- The suffixes of Blizzard's window art: its own list when it has one.
local function TextureNames() return type(CHAT_FRAME_TEXTURES) == "table" and CHAT_FRAME_TEXTURES or TEXTURES end

-- The window's box: Blizzard's Background region (hidden, still anchored).
function M:Box(frame) return frame.Background or _G[(frame:GetName() or "") .. "Background"] end

-- How far the window edge reaches into the box (gap, rim and shadow ring).
function M:Rim(px) return REACH * px end

-- How far in from the box's sides things sit clear of the edge's round
-- corner (Round 4).
function M:Corner(px) return self:Rim(px) + Snap(4, px) end
function M:CornerClear(px) return self:Corner(px) end

-- Room the edit box takes inside the box (the field and the band's padding
-- round it): top, bottom.
function M:EditSpace(px)
    local height = Snap(self.db.editHeight, px) + 2 * Snap(EDIT_PAD, px)
    if self.db.editPosition == "top" then return height, 0 end
    if self.db.editPosition == "bottom" then return 0, height end
    return 0, 0
end

function M:SkinWindow(frame)
    local name = frame:GetName()
    if not name then return end
    for _, suffix in ipairs(TextureNames()) do
        local region = _G[name .. suffix]
        if region then Skin.Suppress(region) end
    end
    local box = self:Box(frame)
    if not box then return end
    local px = Kit.PixelSize(frame)
    self:WindowParts(frame, box)
    -- The text face; the size stays the window's own (its tab menu's Font Size).
    Skin.Font(frame, self:FontPath(), nil, self.db.outline, self.db.shadow, px)
    self:LayoutWindow(frame)
    self:SkinScrollBar(frame)
    self:SkinScrollButton(frame, px)
    self:SkinEditBox(frame, px)
end

-- The window's own pieces, made once: the face and the edge (laid round the
-- box but belonging to the window, so the idle fade dims them with it), and
-- the edit band.
function M:WindowParts(frame, box)
    local parts = Skin.parts[frame]
    if parts and parts.band then return parts end
    parts = Skin.Box(frame, "window", { inset = REACH })
    parts.band = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    Style.ApplyAsset(parts.band, "Solid")
    parts.regions[parts.band] = true
    return parts
end

-- Places the box around the messages (more on top for the combat log's
-- quick buttons, which Blizzard measures the same way), the border on it,
-- and the edit box.
function M:LayoutWindow(frame)
    local box = self:Box(frame)
    local parts = Skin.parts[frame]
    if not box or not self.active or not parts or not parts.band then return end
    local px = Kit.PixelSize(frame)
    local rim = self:Rim(px)
    local inset = Snap(self.TEXT_INSET, px) + rim
    local top = inset
    local quick = frame.CombatLogQuickButtonFrame
    if quick and quick.GetHeight then
        local height = quick:GetHeight()
        if addon.IsNumber(height, 0, 200) then top = top + Snap(height, px) end
    end
    local editTop, editBottom = self:EditSpace(px)
    local right = inset + (self.db.scrollBar and Snap(self.SCROLL_GUTTER, px) or 0)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, top + editTop)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, -(inset + editBottom))
    parts.boxOffsets = { left = -inset, top = top + editTop, right = right, bottom = -(inset + editBottom) }
    -- The Mode window on the box; no soft drop under a see-through fill.
    local alpha = self.db.backgroundOpacity / 100
    Skin.PaintBox(parts, box, "Surface", self.db.backgroundColor, alpha, true)
    -- Border Style and Border Metal; every style has the same reach.
    parts.modeEdge:SetStyle(self.db.edgeStyle, self.db.edgeMetal)
    parts.modeEdge:SetDrop(alpha >= 1)
    self:LayoutEditBox(frame, box, px, rim)
    self:PlaceScrollBar(frame)
    self:PlaceSelection(frame)
end

-- Blizzard's Edit Mode selection (ChatFrame1 is an Edit Mode system, its
-- `Selection` a plain child frame): Blizzard anchors it 32 units left of and
-- below the window (room for the button column ModeUI moves into the
-- compartment) and 60 above. ModeUI lays it over the Mode box and the tab
-- row instead, so the highlight shows the window and snapping puts the box
-- right on a screen edge or corner. Blizzard measures snaps from the
-- selection's two points less 2 units of padding
-- (EditModeSystemMixin:GetLeftOffset and the rest), so the selection reaches
-- those 2 units past the box; the clamp keeps the box itself on screen. Its
-- AnchorSelectionFrame sets the clamp from the selection again, so ModeUI
-- puts its own back right after (post-hook).
local SELECTION_PADDING = 2
function M:PlaceSelection(frame)
    local selection, parts = frame.Selection, Skin.parts[frame]
    if not (self.active and selection and selection.SetPoint and frame.system ~= nil and parts and parts.boxOffsets) then return end
    local px = Kit.PixelSize(frame)
    local o = parts.boxOffsets
    local tabs = Snap(self.db.tabHeight, px)
    local below = 0
    if self.db.editPosition == "below" then
        below = Snap(self.db.editHeight, px) + (self.db.editGap > 0 and Snap(self.db.editGap, px) or 0)
    end
    local left, top, right, bottom = o.left, o.top + tabs, o.right, o.bottom - below
    selection:ClearAllPoints()
    selection:SetPoint("TOPLEFT", frame, "TOPLEFT", left - SELECTION_PADDING, top + SELECTION_PADDING)
    selection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right + SELECTION_PADDING, bottom - SELECTION_PADDING)
    if frame.SetClampRectInsets then frame:SetClampRectInsets(left, right, top, bottom) end
    Skin.Once(frame, "chatSelection", function()
        if type(frame.AnchorSelectionFrame) == "function" then
            hooksecurefunc(frame, "AnchorSelectionFrame", function() if self.active then self:PlaceSelection(frame) end end)
        end
    end)
end

-- The edit box and, inside the border, its band.
function M:LayoutEditBox(frame, box, px, rim)
    local edit, parts = frame.editBox, Skin.parts[frame]
    local position, height = self.db.editPosition, Snap(self.db.editHeight, px)
    local band, pad = parts.band, Snap(EDIT_PAD, px)
    band:ClearAllPoints()
    local inside = position ~= "below"
    band:SetShown(inside)
    if inside then
        local edge = position == "top" and "TOP" or "BOTTOM"
        local sign = position == "top" and -1 or 1
        band:SetPoint(edge .. "LEFT", box, edge .. "LEFT", rim, sign * rim)
        band:SetPoint(edge .. "RIGHT", box, edge .. "RIGHT", -rim, sign * rim)
        band:SetHeight(height + 2 * pad)
        -- The window a little darker under the field, as one piece with it.
        Style.Paint(band, Style.Tone.shadow, BAND_SHADE)
    end
    if not edit then return end
    edit:ClearAllPoints()
    if inside then
        edit:SetPoint("TOPLEFT", band, "TOPLEFT", pad, -pad)
        edit:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", -pad, pad)
    else
        local gap = self.db.editGap > 0 and Snap(self.db.editGap, px) or 0
        edit:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -gap)
        edit:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -gap)
        edit:SetHeight(height)
    end
end

-- Blizzard's MinimalScrollBar: a slim Mode track and thumb in the gutter at
-- the box's right, shown with the tabs while the chat is in use (Fade.lua).
-- Scroll Bar off hides it for good.
function M:SkinScrollBar(frame)
    local bar = frame.ScrollBar
    if not bar then return end
    if bar.Track and bar.Track.Thumb and bar.Back and bar.Forward then Skin.ScrollBar(bar) end
    if self.db.scrollBar then Skin.Release(bar) else Skin.Suppress(bar) end
    self:PlaceScrollBar(frame)
    Skin.PinAlpha(bar, function() return self:ScrollBarAlpha() end)
end

-- In the gutter, between the border's top (below the round corner) and the
-- Scroll to Bottom button. Runs again after Blizzard's FCF_UpdateScrollbarAnchors.
function M:PlaceScrollBar(frame)
    local bar, box = frame.ScrollBar, self:Box(frame)
    if not (bar and box and self.active and self.db.scrollBar) then return end
    local px = Kit.PixelSize(frame)
    local rim = self:Rim(px)
    local editTop, editBottom = self:EditSpace(px)
    local gap = Snap(4, px)
    local top = editTop > 0 and rim + editTop + gap or math.max(rim + gap, self:Corner(px))
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", box, "TOPRIGHT", -(rim + px), -top)
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -(rim + px), rim + editBottom + 2 * gap + Snap(16, px))
end

-- Scroll to Bottom: a 16 px Mode control (Mode Button face, the `control`
-- edge inside it) with a chevron, in the box's bottom-right corner, above the
-- edit band (clear of the round corner without one); the chevron and the
-- edge's outer line turn Ivory on hover. It shows whenever the window is
-- scrolled up (Fade.lua); Blizzard's flashing arrow is hidden for good.
function M:PaintScrollButton(button)
    local parts = Skin.parts[button]
    if not parts or not parts.icon then return end
    Skin.PaintBox(parts, button, "FG", C.face, 1, true, parts.hovered and "accent" or nil)
    Style.Paint(parts.icon, parts.hovered and C.accent or C.label)
end
function M:SkinScrollButton(frame, px)
    local button = frame.ScrollToBottomButton
    if not button then return end
    for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        if button[key] then Skin.Fade(button[key](button)) end
    end
    if button.Flash then Skin.Suppress(button.Flash) end
    local parts = Skin.Box(button, "control", { inset = CONTROL, pieces = true })
    if not parts.icon then
        parts.icon = button:CreateTexture(nil, "ARTWORK")
        parts.regions[parts.icon] = true
        addon.Media:ApplyTexture(parts.icon, "ModeChevron")
        button:HookScript("OnEnter", function() if self.active then parts.hovered = true; self:PaintScrollButton(button) end end)
        button:HookScript("OnLeave", function() if self.active then parts.hovered = false; self:PaintScrollButton(button) end end)
    end
    local rim = self:Rim(px)
    local _, editBottom = self:EditSpace(px)
    local size, inset = Snap(16, px), Snap(3, px)
    local x, y = rim + px, rim + editBottom + inset
    if editBottom == 0 then
        local clear = self:CornerClear(px)
        x, y = math.max(x, clear), math.max(y, clear)
    end
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", self:Box(frame), "BOTTOMRIGHT", -x, y)
    button:SetSize(size, size)
    parts.icon:ClearAllPoints(); parts.icon:SetPoint("CENTER")
    parts.icon:SetSize(Snap(12, px), Snap(12, px))
    self:PaintScrollButton(button)
    Skin.PinAlpha(button, function(target) return self:ScrollButtonAlpha(target) end)
end

-- The edit box: Blizzard's left, middle, right and focus art faded. A field
-- in the `control` edge (inside it) drawn Mode-Blizz, Ivory while it has
-- focus: see-through on the window's band inside the edge, on a Graphite base
-- Below. Its text, header and prompt use the chat face at the window's text
-- size.
function M:SkinEditBox(frame, px)
    local edit = frame.editBox
    if not edit then return end
    local parts = Skin.Box(edit, "control", { inset = CONTROL, style = EDIT_STYLE, pieces = true })
    Skin.FadeTextures(edit)
    for _, key in ipairs({ "focusLeft", "focusMid", "focusRight" }) do Skin.Fade(edit[key]) end
    local function Paint()
        if self.active then self:PaintEditBox(edit) end
    end
    Skin.Once(edit, "chatFocus", function()
        edit:HookScript("OnEditFocusGained", Paint)
        edit:HookScript("OnEditFocusLost", Paint)
    end)
    parts.px = px
    local _, size = frame:GetFont()
    size = addon.IsNumber(size, 6, 64) and size or 14
    local path = self:FontPath()
    Skin.Font(edit, path, size, self.db.outline, self.db.shadow, px)
    for _, key in ipairs({ "header", "headerSuffix", "languageHeader", "prompt", "NewcomerHint" }) do
        Skin.Font(edit[key], path, size, self.db.outline, self.db.shadow, px)
    end
    self:PaintEditBox(edit)
end

function M:PaintEditBox(edit)
    local parts = Skin.parts[edit]
    if not parts or not parts.face then return end
    local below = self.db.editPosition == "below"
    local focused = edit.HasFocus and edit:HasFocus() == true
    Skin.PaintBox(parts, edit, "Solid", C.field, below and 1 or 0, true, focused and "accent" or nil)
end

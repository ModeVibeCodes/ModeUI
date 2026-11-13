local _, addon = ...
local M = addon.Chat
if not M then return end

-- One chat window in the Mode look. Blizzard's background and border
-- textures (CHAT_FRAME_TEXTURES) are hidden, so its fades skip them.
-- Blizzard's Background region stays as the window's box: ModeUI moves it to
-- Text Inset around the messages (plus the border, the edit box when it sits
-- inside, and the scroll bar's gutter), and the tabs, dock, button frame and
-- alerts that Blizzard anchors to it follow. On the box: a fill (Background
-- Color at Background Opacity) and a crisp square border drawn on its own
-- layer above the window (as the unit frames' rim). The edit box joins the
-- window: inside the border at the bottom or top, on a darker band with a
-- one-pixel divider that turns cyan while typing; or Below, as its own
-- bordered field Edit Gap under the window. Sizes are whole physical pixels.
local Skin, Kit = addon.Skin, addon.Kit
local C = Skin.colors
local Snap = Skin.Snap
local TEXTURES = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture", "ButtonFrameBackground", "ButtonFrameTopLeftTexture",
    "ButtonFrameBottomLeftTexture", "ButtonFrameTopRightTexture", "ButtonFrameBottomRightTexture", "ButtonFrameLeftTexture",
    "ButtonFrameRightTexture", "ButtonFrameBottomTexture", "ButtonFrameTopTexture" }
-- Each edit box's window, for repainting the band when focus changes.
local owners = setmetatable({}, { __mode = "k" })

-- The suffixes of Blizzard's window art: its own list when it has one.
local function TextureNames() return type(CHAT_FRAME_TEXTURES) == "table" and CHAT_FRAME_TEXTURES or TEXTURES end

-- The window's box: Blizzard's Background region (hidden, still anchored).
function M:Box(frame) return frame.Background or _G[(frame:GetName() or "") .. "Background"] end

-- The border's thickness, in the window's units (0 with Border off).
function M:Rim(px) return self.db.border and Snap(self.db.borderSize, px) or 0 end

-- Room the edit box takes inside the box: top, bottom.
function M:EditSpace(px)
    local height = Snap(self.db.editHeight, px)
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
    local parts = Skin.Panel(frame, "BACKGROUND", -8)
    if not parts.band then
        parts.band = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        parts.bandLine = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        parts.band:SetTexture(Kit.FLAT); parts.bandLine:SetTexture(Kit.FLAT)
        parts.regions[parts.band], parts.regions[parts.bandLine] = true, true
    end
    Skin.Edge(frame, 2)
    -- The text face; the size stays the window's own (its tab menu's Font Size).
    Skin.Font(frame, self:FontPath(), nil, self.db.outline, self.db.shadow, px)
    self:LayoutWindow(frame)
    self:SkinScrollBar(frame)
    self:SkinScrollButton(frame, px)
    self:SkinEditBox(frame, px)
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
    Skin.PaintPanel(parts, box, self.db.backgroundColor, self.db.backgroundOpacity / 100, self.db.borderColor, 0)
    parts.edge:ClearAllPoints()
    parts.edge:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0); parts.edge:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    Skin.PaintEdge(parts, rim, self.db.borderColor, 1)
    self:LayoutEditBox(frame, box, px, rim)
    self:PlaceScrollBar(frame)
end

-- The edit box and, inside the border, its band and divider.
function M:LayoutEditBox(frame, box, px, rim)
    local edit, parts = frame.editBox, Skin.parts[frame]
    local position, height = self.db.editPosition, Snap(self.db.editHeight, px)
    local band, line = parts.band, parts.bandLine
    band:ClearAllPoints(); line:ClearAllPoints()
    local inside = position ~= "below"
    band:SetShown(inside); line:SetShown(inside)
    if inside then
        local edge = position == "top" and "TOP" or "BOTTOM"
        local sign = position == "top" and -1 or 1
        band:SetPoint(edge .. "LEFT", box, edge .. "LEFT", rim, sign * rim)
        band:SetPoint(edge .. "RIGHT", box, edge .. "RIGHT", -rim, sign * rim)
        band:SetHeight(height)
        local facing = position == "top" and "BOTTOM" or "TOP"
        line:SetPoint(facing .. "LEFT", band, facing .. "LEFT", 0, 0)
        line:SetPoint(facing .. "RIGHT", band, facing .. "RIGHT", 0, 0)
        line:SetHeight(px)
        -- A little darker than the window, as one piece with it.
        Kit.Tint(band, C.field, math.min(1, self.db.backgroundOpacity / 100 + 0.15))
        self:PaintBand(frame)
    end
    if not edit then return end
    owners[edit] = frame
    edit:ClearAllPoints()
    if inside then
        edit:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
        edit:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", 0, 0)
    else
        local gap = self.db.editGap > 0 and Snap(self.db.editGap, px) or 0
        edit:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -gap)
        edit:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -gap)
        edit:SetHeight(height)
    end
end

-- The band's divider: cyan while its edit box has focus.
function M:PaintBand(frame)
    local parts = Skin.parts[frame]
    if not parts or not parts.bandLine then return end
    local edit = frame.editBox
    local focused = edit and edit.HasFocus and edit:HasFocus() == true
    Kit.Tint(parts.bandLine, focused and C.accent or C.fieldRim, 1)
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

-- In the gutter, between the border's top and the Scroll to Bottom button.
-- Runs again after Blizzard's FCF_UpdateScrollbarAnchors.
function M:PlaceScrollBar(frame)
    local bar, box = frame.ScrollBar, self:Box(frame)
    if not (bar and box and self.active and self.db.scrollBar) then return end
    local px = Kit.PixelSize(frame)
    local rim = self:Rim(px)
    local editTop, editBottom = self:EditSpace(px)
    local gap = Snap(4, px)
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", box, "TOPRIGHT", -(rim + px), -(rim + editTop + gap))
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -(rim + px), rim + editBottom + 2 * gap + Snap(16, px))
end

-- Scroll to Bottom: a 16 px field with a chevron in the box's bottom-right
-- corner, above the edit band. It shows whenever the window is scrolled up
-- (Fade.lua); Blizzard's flashing arrow is hidden for good.
function M:SkinScrollButton(frame, px)
    local button = frame.ScrollToBottomButton
    if not button then return end
    for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        if button[key] then Skin.Fade(button[key](button)) end
    end
    if button.Flash then Skin.Suppress(button.Flash) end
    local parts = Skin.Panel(button, "BACKGROUND", -8)
    if not parts.icon then
        parts.icon = button:CreateTexture(nil, "ARTWORK")
        parts.regions[parts.icon] = true
        addon.Media:ApplyTexture(parts.icon, "ModeChevron")
        button:HookScript("OnEnter", function() if self.active then Kit.Tint(parts.icon, C.accent, 1) end end)
        button:HookScript("OnLeave", function() if self.active then Kit.Tint(parts.icon, C.label, 1) end end)
    end
    Skin.PaintPanel(parts, button, C.field, 0.9, C.fieldRim, px)
    local rim = self:Rim(px)
    local _, editBottom = self:EditSpace(px)
    local size, inset = Snap(16, px), Snap(3, px)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", self:Box(frame), "BOTTOMRIGHT", -(rim + px), rim + editBottom + inset)
    button:SetSize(size, size)
    parts.icon:ClearAllPoints(); parts.icon:SetPoint("CENTER")
    parts.icon:SetSize(size, size)
    Kit.Tint(parts.icon, C.label, 1)
    Skin.PinAlpha(button, function(target) return self:ScrollButtonAlpha(target) end)
end

-- The edit box: Blizzard's left, middle, right and focus art faded. Inside
-- the border it is see-through on the window's band; Below, it is its own
-- field with the window's border, cyan while it has focus. Its text,
-- header and prompt use the chat face at the window's text size.
function M:SkinEditBox(frame, px)
    local edit = frame.editBox
    if not edit then return end
    local parts = Skin.Panel(edit, "BACKGROUND", -8)
    Skin.Edge(edit, 2)
    Skin.FadeTextures(edit)
    for _, key in ipairs({ "focusLeft", "focusMid", "focusRight" }) do Skin.Fade(edit[key]) end
    local function Paint()
        if not self.active then return end
        self:PaintEditBox(edit)
        local window = owners[edit]
        if window then self:PaintBand(window) end
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
    if not parts or not parts.fill then return end
    local px = parts.px or 1
    local below = self.db.editPosition == "below"
    local focused = edit.HasFocus and edit:HasFocus() == true
    Skin.PaintPanel(parts, edit, C.field, below and 0.9 or 0, C.fieldRim, 0)
    Skin.PaintEdge(parts, below and self:Rim(px) or 0, focused and C.accent or self.db.borderColor, 1)
end

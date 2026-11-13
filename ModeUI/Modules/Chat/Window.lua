local _, addon = ...
local M = addon.Chat
if not M then return end

-- One chat window in the Mode look. Blizzard's background and border
-- textures (CHAT_FRAME_TEXTURES) are hidden, so its fades skip them, and
-- ModeUI's fill and one-pixel rim are drawn on the window under the text.
-- Blizzard's Background region stays as the window's box: ModeUI moves it to
-- an even Text Inset around the messages, and the tabs, button frame and
-- alerts that Blizzard anchors to it follow. The edit box hangs Edit Gap
-- below the box, as wide as it, as a Mode field whose rim turns cyan while
-- typing. Sizes are whole physical pixels.
local Skin, Kit = addon.Skin, addon.Kit
local C = Skin.colors
local Snap = Skin.Snap
local TEXTURES = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture", "ButtonFrameBackground", "ButtonFrameTopLeftTexture",
    "ButtonFrameBottomLeftTexture", "ButtonFrameTopRightTexture", "ButtonFrameBottomRightTexture", "ButtonFrameLeftTexture",
    "ButtonFrameRightTexture", "ButtonFrameBottomTexture", "ButtonFrameTopTexture" }

-- The suffixes of Blizzard's window art: its own list when it has one.
local function TextureNames() return type(CHAT_FRAME_TEXTURES) == "table" and CHAT_FRAME_TEXTURES or TEXTURES end

-- The window's box: Blizzard's Background region (hidden, still anchored).
function M:Box(frame) return frame.Background or _G[(frame:GetName() or "") .. "Background"] end

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
    Skin.PaintPanel(parts, box, self.db.backgroundColor, self.db.backgroundOpacity / 100,
        self.db.borderColor, self.db.border and px or 0)
    -- The text face; the size stays the window's own (its tab menu's Font Size).
    Skin.Font(frame, self:FontPath(), nil, self.db.outline, self.db.shadow, px)
    self:LayoutWindow(frame)
    self:SkinScrollBar(frame)
    self:SkinScrollButton(frame, px)
    self:SkinEditBox(frame, px)
end

-- Places the box Text Inset around the messages (more on top for the combat
-- log's quick buttons, which Blizzard measures the same way).
function M:LayoutWindow(frame)
    local box = self:Box(frame)
    if not box or not self.active then return end
    local px = Kit.PixelSize(frame)
    local inset = Snap(self.TEXT_INSET, px)
    local top = inset
    local quick = frame.CombatLogQuickButtonFrame
    if quick and quick.GetHeight then
        local height = quick:GetHeight()
        if addon.IsNumber(height, 0, 200) then top = top + Snap(height, px) end
    end
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, top)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset, -inset)
    local edit = frame.editBox
    if edit then
        local gap = Snap(self.EDIT_GAP, px)
        edit:ClearAllPoints()
        edit:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -gap)
        edit:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -gap)
        edit:SetHeight(Snap(self.EDIT_HEIGHT, px))
    end
end

-- Blizzard's thin scroll bar: hidden unless Scroll Bar is on. Blizzard shows
-- it again from its own scroll update when allowed.
function M:SkinScrollBar(frame)
    local bar = frame.ScrollBar
    if not bar then return end
    if self.db.scrollBar then Skin.Release(bar) else Skin.Suppress(bar) end
end

-- Scroll to Bottom: a 16 px field with a chevron in the box's bottom-right
-- corner. It shows whenever the window is scrolled up (Fade.lua).
function M:SkinScrollButton(frame, px)
    local button = frame.ScrollToBottomButton
    if not button then return end
    for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        if button[key] then Skin.Fade(button[key](button)) end
    end
    Skin.Fade(button.Flash)
    local parts = Skin.Panel(button, "BACKGROUND", -8)
    if not parts.icon then
        parts.icon = button:CreateTexture(nil, "ARTWORK")
        parts.regions[parts.icon] = true
        addon.Media:ApplyTexture(parts.icon, "ModeChevron")
        button:HookScript("OnEnter", function() if self.active then Kit.Tint(parts.icon, C.accent, 1) end end)
        button:HookScript("OnLeave", function() if self.active then Kit.Tint(parts.icon, C.label, 1) end end)
    end
    Skin.PaintPanel(parts, button, C.field, 0.9, C.fieldRim, px)
    local size, inset = Snap(16, px), Snap(4, px)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", self:Box(frame), "BOTTOMRIGHT", -inset, inset)
    button:SetSize(size, size)
    parts.icon:ClearAllPoints(); parts.icon:SetPoint("CENTER")
    parts.icon:SetSize(size, size)
    Kit.Tint(parts.icon, C.label, 1)
    Skin.PinAlpha(button, function(target) return self:ScrollButtonAlpha(target) end)
end

-- The edit box: Blizzard's left, middle, right and focus art faded; a field
-- fill with a rim that turns cyan while it has focus. Its text, header and
-- prompt use the chat face at the window's text size.
function M:SkinEditBox(frame, px)
    local edit = frame.editBox
    if not edit then return end
    local parts = Skin.Panel(edit, "BACKGROUND", -8)
    Skin.FadeTextures(edit)
    for _, key in ipairs({ "focusLeft", "focusMid", "focusRight" }) do Skin.Fade(edit[key]) end
    local function Paint() if self.active then self:PaintEditBox(edit) end end
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
    local focused = edit.HasFocus and edit:HasFocus() == true
    Skin.PaintPanel(parts, edit, C.field, 0.9, focused and C.accent or C.fieldRim, parts.px or 1)
end

local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- The header buttons and arranging windows by hand.
--   Fight button: C (Current Fight), O (Overall) or an earlier fight's number,
--     just the character, in the Mode cyan.
--     Click switches Current and Overall; right-click opens the menu.
--   Reset: Reset All Data.   Lock: Lock Window on and off.
-- Unlocked, dragging a header moves the window (a group moves together) and
-- the grip in the corner resizes it: width for the group, Rows for that
-- window. Both work out of combat and outside Edit Mode, and save exactly
-- what Edit Mode would. The glyphs are 16 physical pixels when the header
-- has room, so they draw one to one at any UI scale.
local Kit, L, T = addon.Kit, addon.L, addon.InterfaceTheme
local DM, Number = addon.Domain.DamageMeter, addon.IsNumber
local PM, P = addon.PositionManager, addon.Positioning
local GLYPH, GAP = 16, 2

local function Tip(owner, title, line)
    if not (GameTooltip and GameTooltip.SetOwner) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title, 1, 1, 1)
    if line then GameTooltip:AddLine(line, nil, nil, nil, true) end
    GameTooltip:Show()
end
local function HideTip() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end

local function IconButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button:SetScript("OnEnter", function()
        button.hovered = true; M:PaintButtons(button.frame)
        if button.tip then Tip(button, button.tip()) end
    end)
    button:SetScript("OnLeave", function() button.hovered = false; M:PaintButtons(button.frame); HideTip() end)
    return button
end

-- The buttons and grip on a window shell (real windows and the preview).
function M:BuildControls(frame)
    local header = frame.header
    local session, reset, lock = IconButton(header), IconButton(header), IconButton(header)
    session.icon:Hide()
    session.text = Kit.Text(session)
    session.text:SetPoint("CENTER", session, "CENTER", 0, 0)
    addon.Media:ApplyTexture(reset.icon, "DamageMeterReset")
    frame.buttons = { session = session, reset = reset, lock = lock }
    for _, button in pairs(frame.buttons) do button.frame = frame end
    local grip = CreateFrame("Button", nil, frame)
    grip.icon = grip:CreateTexture(nil, "OVERLAY")
    grip.icon:SetAllPoints()
    addon.Media:ApplyTexture(grip.icon, "DamageMeterGrip")
    grip:SetScript("OnEnter", function() grip.icon:SetAlpha(1) end)
    grip:SetScript("OnLeave", function() grip.icon:SetAlpha(0.45) end)
    grip:Hide()
    frame.grip = grip
end

-- What the fight button reads: C, O, or the earlier fight's place in the list.
function M:SessionShort(session)
    if session == "current" then return L["C"] end
    if session == "overall" then return L["O"] end
    for index, item in ipairs(DM.Sessions()) do if item.id == session then return tostring(index) end end
    return "#"
end

-- Places the buttons right to left from the header's right edge (the
-- timer sits left of them) and the grip in the corner that grows.
function M:LayoutControls(frame, style, g, window)
    local buttons = frame.buttons
    if not buttons then return end
    local px = g.px
    local glyph = math.max(4, math.min(GLYPH, math.floor(g.header / px + 0.5) - 4)) * px
    local top = math.floor((g.header - glyph) / 2 / px + 0.5) * px
    local shown = style.header and style.headerButtons
    local x = -g.inset
    for _, key in ipairs({ "lock", "reset", "session" }) do
        local button = buttons[key]
        button:ClearAllPoints()
        button:SetPoint("TOPRIGHT", frame.header, "TOPRIGHT", x, -top)
        button:SetSize(glyph, glyph)
        button:SetShown(shown)
        button:EnableMouse(shown and not style.clickThrough)
        x = x - glyph - GAP * px
    end
    local letter = self.PartStyle(style, "title")
    letter.outline = true
    Kit.Font(buttons.session.text, letter, math.max(6, math.floor(glyph / px * 0.75 + 0.5)), frame.fontPath, px)
    local info = frame.header.info
    info:ClearAllPoints()
    if shown then info:SetPoint("RIGHT", buttons.session, "LEFT", -g.inset, 0)
    else info:SetPoint("RIGHT", frame.header, "RIGHT", -g.inset, 0) end
    -- The grip: bottom-right, or top-right under the header for a window
    -- grouped above another (it grows upward).
    local grip, up = frame.grip, window and self.db[window].group ~= "none" and self.db[window].groupSide == "above"
    grip:ClearAllPoints()
    grip:SetSize(GLYPH * px, GLYPH * px)
    if up then
        grip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -g.border, -(g.border + g.header + g.divider))
        grip.icon:SetTexCoord(0, 1, 1, 0)
    else
        grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -g.border, g.border)
        grip.icon:SetTexCoord(0, 1, 0, 1)
    end
    grip.up = up
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    Kit.Tint(grip.icon, style.nameColor, 1)
    grip.icon:SetAlpha(0.45)
    grip:SetShown(window ~= nil and self:CanArrange(window))
    self:PaintButtons(frame)
end

-- Colors and the lock glyph: text color, the accent under the mouse.
function M:PaintButtons(frame)
    local buttons = frame and frame.buttons
    if not buttons or not frame.style then return end
    local style = frame.style
    local function Color(button) return button.hovered and Kit.palette.accent or style.timerColor end
    local lockKey = style.locked and "DamageMeterLock" or "DamageMeterUnlock"
    if buttons.lock.glyph ~= lockKey then addon.Media:ApplyTexture(buttons.lock.icon, lockKey); buttons.lock.glyph = lockKey end
    for _, key in ipairs({ "lock", "reset" }) do
        local button = buttons[key]
        Kit.Tint(button.icon, Color(button), button.hovered and 1 or 0.8)
    end
    -- The fight letter is Mode cyan; white under the mouse.
    local session = buttons.session
    local c = session.hovered and { 1, 1, 1 } or Kit.palette.accent
    session.text:SetTextColor(c[1], c[2], c[3], 1)
end

-- Real windows: what the buttons do, and the header drag and grip.
function M:BindControls(window)
    local frame = self.frames[window]
    local b = frame.buttons
    b.session:SetScript("OnClick", function(_, button)
        if button == "RightButton" then self:ToggleMenu(window, frame.header); return end
        self:SetSession(window, self:SessionOf(window) == "current" and "overall" or "current")
    end)
    b.session.tip = function()
        return self:SessionLabel(self:SessionOf(window)), L["Click: Current Fight or Overall. Right-click: earlier fights."]
    end
    b.reset:SetScript("OnClick", function() self:ResetData() end)
    b.reset.tip = function() return L["Reset All Data"], L["Clears every recorded fight."] end
    b.lock:SetScript("OnClick", function() self:SetOption(window, "locked", not self:Style(window).locked) end)
    b.lock.tip = function()
        return self:Style(window).locked and L["Locked"] or L["Unlocked"], L["Unlocked, drag the header to move and the corner to resize."]
    end
    frame:SetMovable(true)
    frame.header:RegisterForDrag("LeftButton")
    frame.header:SetScript("OnDragStart", function() self:StartMove(window) end)
    frame.header:SetScript("OnDragStop", function() self:StopMove() end)
    frame.grip:SetScript("OnMouseDown", function() self:StartResize(window) end)
    frame.grip:SetScript("OnMouseUp", function() self:StopResize() end)
end

-- Moving and resizing by hand: unlocked, out of combat, not in Edit Mode.
function M:CanArrange(window)
    local style = self:Style(window)
    return self.active == true and not style.locked and not style.clickThrough and not self.editing and not self.testing
        and not addon.InCombat()
end

-- Grips show only while windows can be arranged; combat hides them.
function M:UpdateGrips()
    if not self.built then return end
    for _, window in ipairs(self.windows) do self.frames[window].grip:SetShown(self:CanArrange(window)) end
end

local function Cursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not Number(x) or not Number(y) or not Number(scale) or scale <= 0 then return end
    return x / scale, y / scale
end

-- Keeps the window's top-left corner where it is while it resizes: its
-- place becomes the screen's top-left corner plus an offset.
function M:PinTopLeft(window)
    local id, mover = self.elementIds[window], self.movers[window]
    local position = PM:GetPosition(id)
    if not position then return false end
    if position.target == "screen" and position.point == "TOPLEFT" and position.relativePoint == "TOPLEFT" then return true end
    local left, top = mover:GetLeft(), mover:GetTop()
    local uiLeft, uiTop = UIParent:GetLeft(), UIParent:GetTop()
    if not (Number(left) and Number(top) and Number(uiLeft) and Number(uiTop)) then return false end
    local px = Kit.PixelSize(mover)
    local function Snap(v) return math.floor(v / px + 0.5) * px end
    return PM:SetPosition(id, { target = "screen", placement = "center", point = "TOPLEFT", relativePoint = "TOPLEFT",
        x = Snap(left - uiLeft), y = Snap(top - uiTop) })
end

-- Where a frame's top-left corner is, as a point on UIParent's bottom left.
local function Corner(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (Number(left) and Number(top)) then return end
    return left - (UIParent:GetLeft() or 0), top - (UIParent:GetBottom() or 0)
end

-- The head of the group moves. Its stand-in rides along on its corner, so
-- windows anchored on it in Edit Mode follow the drag as it happens (grouped
-- windows hang from the head itself).
function M:StartMove(window)
    local frame = self.frames[window]
    if not self:CanArrange(window) then return end
    local head = self:Leader(window)
    local moved, mover = self.frames[head], self.movers[head]
    frame.dragged = true
    self.moving = head
    local x, y = Corner(moved)
    if x then
        moved:ClearAllPoints(); moved:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        mover:ClearAllPoints(); mover:SetPoint("TOPLEFT", moved, "TOPLEFT", 0, 0)
    end
    moved:StartMoving()
end

-- Saves where the head of the group was dropped, the way Edit Mode does:
-- an offset from its anchor, on whole pixels.
function M:StopMove()
    local head = self.moving
    if not head then return end
    self.moving = nil
    local frame, mover = self.frames[head], self.movers[head]
    frame:StopMovingOrSizing()
    if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, false) end
    local x, y = Corner(frame)
    local id = self.elementIds[head]
    local element = PM:Element(id)
    -- The stand-in lets go of the window first (the window hangs from it again below).
    mover:ClearAllPoints()
    if x then mover:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y) end
    if element then element.subject.appliedAnchor = nil end
    if element and x and not addon.InCombat() then
        local ox, oy = P:ReadFrame(element.subject)
        local px = Kit.PixelSize(mover)
        if Number(ox) and Number(oy) then PM:SetOffsets(id, math.floor(ox / px + 0.5) * px, math.floor(oy / px + 0.5) * px) end
        PM:ApplyPosition(id, true)
    elseif not x then PM:ApplyPosition(id, true) end
    self:AnchorWindow(head, frame.g)
end

function M:StartResize(window)
    if not self:CanArrange(window) then return end
    local x, y = Cursor()
    if not x then return end
    self:PinTopLeft(self:Leader(window))
    local style, grip = self:Style(window), self.frames[window].grip
    self.resizing = { window = window, x = x, y = y, width = style.width, rows = self.db[window].rows, up = grip.up }
    grip:SetScript("OnUpdate", function() self:UpdateResize() end)
end

-- Width follows the cursor; Rows change a whole row at a time.
function M:UpdateResize()
    local r = self.resizing
    if not r or addon.InCombat() then self:StopResize(); return end
    local x, y = Cursor()
    if not x then return end
    local style = self:Style(r.window)
    local function Clamp(value, range) return math.max(range[1], math.min(range[2], value)) end
    local width = Clamp(math.floor(r.width + (x - r.x) + 0.5), self.ranges.width)
    local down = r.up and (y - r.y) or (r.y - y)
    local rows = Clamp(r.rows + math.floor(down / (style.rowHeight + style.spacing) + 0.5), self.ranges.rows)
    -- Grouped windows share the width; windows anchored on this one with
    -- Match Width take it on the refresh. A matched window's own width (or
    -- rows, with Match Height) stays its anchor's.
    local head = self:Leader(r.window)
    if width ~= style.width and not self:Matching(head, "Width") then self:SetOption(r.window, "width", width) end
    if rows ~= self.db[r.window].rows and not self:Matching(r.window, "Height") then self:SetOption(r.window, "rows", rows) end
end

function M:StopResize()
    local r = self.resizing
    self.resizing = nil
    if r and self.frames[r.window] then self.frames[r.window].grip:SetScript("OnUpdate", nil) end
end

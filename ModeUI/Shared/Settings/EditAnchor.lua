local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
local PM, P, F = addon.PositionManager, addon.Positioning, addon.FrameAnchors

-- Edit Mode's Anchor To: click it, then click the element (or frame) the
-- selected element should hang from. It goes onto the side of that element
-- it already sits on, flush against it, without jumping (PM:AnchorNear), and
-- a small window then offers the other sides: a compass of
-- Above, Below, Left, Right and Center, with the corners lining up edges
-- (Above, left edges together...). Undo puts it back where it was.
-- While it waits for the click nothing can be dragged, but every element
-- (and its name handle) still takes the mouse, so the click picks it and
-- never reaches what's under it, like a bar's buttons. Escape or a
-- right-click cancels, and so does combat.
local A = {}
addon.EditAnchor = A
local Combat, Plain = addon.InCombat, addon.IsPublic
local THROTTLE = 0.05

-- Compass point -> placement, and the element's and target's points for the
-- corners (edges lined up). Every side starts at X and Y 0.
A.sides = {
    TOP = { "above" }, BOTTOM = { "below" }, LEFT = { "left" }, RIGHT = { "right" }, CENTER = { "center" },
    TOPLEFT = { "above", "BOTTOMLEFT", "TOPLEFT" }, TOPRIGHT = { "above", "BOTTOMRIGHT", "TOPRIGHT" },
    BOTTOMLEFT = { "below", "TOPLEFT", "BOTTOMLEFT" }, BOTTOMRIGHT = { "below", "TOPRIGHT", "BOTTOMRIGHT" },
}
A.sideLabels = { TOP = "Above", BOTTOM = "Below", LEFT = "Left", RIGHT = "Right", CENTER = "Center",
    TOPLEFT = "Above, left edges", TOPRIGHT = "Above, right edges",
    BOTTOMLEFT = "Below, left edges", BOTTOMRIGHT = "Below, right edges" }
local PLACEMENT_SIDE = { above = "TOP", below = "BOTTOM", left = "LEFT", right = "RIGHT", center = "CENTER" }

-- The compass point a saved position stands for (nil for other custom points).
function A:Side(position)
    if not position then return end
    if position.point then
        for side, spec in pairs(self.sides) do
            if spec[2] == position.point and spec[3] == position.relativePoint then return side end
        end
        return
    end
    return PLACEMENT_SIDE[position.placement]
end

function A:SetSide(id, target, side)
    local spec = self.sides[side]
    if not spec then return false, "invalid-side" end
    return PM:AnchorTo(id, target, spec[1], spec[2], spec[3])
end

function A:TargetLabel(target)
    for _, item in ipairs(P.targets) do if item.id == target then return item.label end end
    if F:ValidID(target) then return target:sub(7) end
    return tostring(target)
end

-- Whether the element has anything but the screen to hang from.
function A:CanPick(element)
    if not element or not element.supportsAnchoring then return false end
    if element.allowedTargets.selected then return true end
    for id in pairs(element.allowedTargets) do if id ~= "screen" and id ~= "selected" then return true end end
    return false
end

-- The cursor, in UIParent units.
local function Cursor()
    if type(GetCursorPosition) ~= "function" then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not Plain(x) or not Plain(y) or type(x) ~= "number" or type(y) ~= "number" or not scale or scale <= 0 then return end
    return x / scale, y / scale
end
local function Visible(frame)
    local ok, shown = pcall(frame.IsVisible or frame.IsShown, frame)
    return ok and Plain(shown) and shown == true
end
local function Under(frame, cx, cy)
    local x, y, width, height = P:Geometry(frame)
    if x and math.abs(cx - x) <= width / 2 and math.abs(cy - y) <= height / 2 then return width * height end
end

-- What under the cursor the element may hang from: the smallest listed
-- frame there (other ModeUI elements, the Player Frame...), else a named
-- frame when the element takes any. Never itself, never a loop, and never
-- through the Edit Mode window. Another element's name handle picks it too
-- (and first). The third result, when nothing can be picked, is the label of
-- a listed frame under the cursor that would close a loop.
function A:Candidate(element)
    local cx, cy = Cursor()
    if not cx or not element then return end
    if addon.editWindow and Visible(addon.editWindow) and Under(addon.editWindow, cx, cy) then return end
    local best, frame, area, looped
    for _, item in ipairs(P.targets) do
        if item.id ~= "screen" and element.allowedTargets[item.id] then
            local target = P:Resolve(item.id)
            local owner = target and PM.frames[target]
            local handle = owner and PM.elements[owner].decoration and PM.elements[owner].decoration.handle
            local size = target and target ~= element.frame and Visible(target)
                and (handle and Visible(handle) and Under(handle, cx, cy) and 0 or Under(target, cx, cy))
            if size and PM:WouldLoop(element.id, item.id) then looped = looped or item.label
            elseif size and (not area or size < area) then best, frame, area = item.id, target, size end
        end
    end
    if not best and element.allowedTargets.selected then best, frame = F:PickCandidate() end
    return best, frame, not best and looped or nil
end

local function Outline(parent)
    local outline = CreateFrame("Frame", nil, parent)
    outline:EnableMouse(false)
    for i, points in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = outline:CreateTexture(nil, "OVERLAY")
        edge:SetPoint(points[1]); edge:SetPoint(points[2]); edge:SetColorTexture(unpack(addon.Theme.primary))
        if i <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
    end
    return outline
end

function A:BuildOverlay()
    local overlay = CreateFrame("Frame", "ModeUIAnchorToOverlay", UIParent)
    overlay:SetAllPoints(UIParent); overlay:SetFrameStrata("TOOLTIP"); overlay:EnableMouse(false); overlay:Hide()
    overlay:EnableKeyboard(true); overlay:SetPropagateKeyboardInput(true)
    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOP", UIParent, "TOP", 0, -50)
    addon.Media:BindInterfaceFont(text, GameFontHighlight, 16)
    text:SetTextColor(unpack(addon.Theme.primary))
    overlay.text, overlay.outline = text, Outline(overlay)
    overlay:SetScript("OnKeyDown", function(_, key)
        overlay:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then self:Stop() end
    end)
    overlay:SetScript("OnEvent", function(_, event, button)
        if event == "PLAYER_REGEN_DISABLED" or button == "RightButton" then self:Stop(); return end
        if button ~= "LeftButton" then return end
        local target = self:Candidate(PM:Element(self.elementId))
        if target then self:Pick(self.elementId, target) end
    end)
    local elapsed = 0
    overlay:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < THROTTLE then return end
        elapsed = 0
        self:Track()
    end)
    self.overlay = overlay
end

-- Outlines what a click would pick and says what it is.
function A:Track()
    local element = PM:Element(self.elementId)
    if Combat() or not element or not addon.editMode then self:Stop(); return end
    local overlay = self.overlay
    local target, frame, looped = self:Candidate(element)
    overlay.outline:Hide()
    local name = element.label or element.module.title
    if looped then
        overlay.text:SetText(looped .. " already hangs from " .. name .. ", so it can't hold it. Escape cancels.")
        return
    end
    if not target then overlay.text:SetText("Anchor " .. name .. ": click the element to anchor it to. Escape cancels."); return end
    local x, y, width, height = P:Geometry(frame)
    if x then
        local cx, cy = UIParent:GetCenter()
        overlay.outline:ClearAllPoints()
        overlay.outline:SetPoint("CENTER", UIParent, "CENTER", x - cx, y - cy)
        overlay.outline:SetSize(width, height); overlay.outline:Show()
    end
    overlay.text:SetText("Anchor " .. name .. " to " .. self:TargetLabel(target) .. ": click to choose it. Escape cancels.")
end

function A:Active() return self.elementId ~= nil end

function A:Start(id)
    local element = PM:Element(id)
    if Combat() or not addon.editMode or not self:CanPick(element) then return false, "unavailable" end
    self:Stop(); self:CloseSides()
    PM:FinishDrags()
    if not self.overlay then self:BuildOverlay() end
    self.elementId = id
    PM.picking = true
    PM:RefreshSelection()
    self.overlay:SetPropagateKeyboardInput(true)
    self.overlay:RegisterEvent("GLOBAL_MOUSE_DOWN"); self.overlay:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.overlay:Show()
    self:Track()
    if addon.RefreshEditWindow then addon:RefreshEditWindow() end
    return true
end

function A:Stop()
    if not self.elementId then return end
    self.elementId = nil
    local overlay = self.overlay
    overlay:UnregisterAllEvents(); overlay:Hide(); overlay.outline:Hide()
    PM.picking = false
    PM:RefreshSelection()
end

-- Anchors the element to the side of the clicked target it sits on, then offers the sides.
function A:Pick(id, target)
    local before = PM:GetPosition(id)
    local ok, reason = PM:AnchorNear(id, target)
    self:Stop()
    if not ok then
        print("ModeUI: that can't be anchored there (" .. tostring(reason) .. ").")
        return false, reason
    end
    PM:SelectElement(id)
    self:OpenSides(id, target, before)
    return true
end

function A:BuildSides()
    local frame = CreateFrame("Frame", "ModeUIAnchorSides", UIParent)
    frame:Hide(); frame:SetSize(300, 190)
    frame:SetFrameStrata("DIALOG"); frame:SetFrameLevel(120)
    frame:SetClampedToScreen(true); frame:EnableMouse(true)
    W.Texture(frame, "Window"); W.Texture(frame, "BorderSilver", "BORDER")
    frame.heading = W.Heading(frame, "", T.fontSize.section, 16, -12, 268, T.text)
    frame.note = W.Label(frame, "", nil, 16, -40, 268, T.muted)
    local host = CreateFrame("Frame", nil, frame)
    host:SetPoint("TOPLEFT", 16, -66); host:SetSize(268, W.ANCHOR_PICKER_HEIGHT)
    frame.compass, frame.refresh = W.AnchorPicker(host, function() return self:Side(PM:GetPosition(self.sideId)) end,
        function(side) self:SetSide(self.sideId, self.sideTarget, side); frame.refresh() end, self.sideLabels, { center = true })
    local done = W.Button(frame, "Done", 130, 28)
    done:SetPoint("BOTTOMLEFT", 16, 14); done:SetSelected(true)
    done:SetScript("OnClick", function() self:CloseSides() end)
    local undo = W.Button(frame, "Undo", 130, 28, "secondary")
    undo:SetPoint("BOTTOMRIGHT", -16, 14)
    undo:SetScript("OnClick", function()
        local id, before = self.sideId, self.sideBefore
        self:CloseSides()
        if id and before and not Combat() then PM:SetPosition(id, before, true) end
    end)
    frame.done, frame.undo = done, undo
    frame:SetScript("OnEvent", function() self:CloseSides() end)
    self.sidesFrame = frame
end

function A:OpenSides(id, target, before)
    if not self.sidesFrame then self:BuildSides() end
    local frame, element = self.sidesFrame, PM:Element(id)
    self.sideId, self.sideTarget, self.sideBefore = id, target, before
    frame.heading:SetText("Anchor " .. (element.label or element.module.title))
    frame.note:SetText("To " .. self:TargetLabel(target) .. ", on the side it was on. Pick another side; X and Y then start at 0.")
    frame:ClearAllPoints()
    local cx, cy = Cursor()
    if cx then frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx + 16, cy + 16)
    else frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:Show(); frame.refresh()
end

function A:CloseSides()
    local frame = self.sidesFrame
    self.sideId, self.sideTarget, self.sideBefore = nil, nil, nil
    if frame then frame:UnregisterAllEvents(); frame:Hide() end
end

-- Leaving Edit Mode ends both.
function A:Finish() self:Stop(); self:CloseSides() end

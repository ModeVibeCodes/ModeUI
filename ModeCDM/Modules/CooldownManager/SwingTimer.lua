local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- The Swing Timer's frames, layout, paint and events (SwingInit.lua has its
-- settings). Forever only: nothing is built without C_SwingTimer. Each lane
-- is a status bar in the Mode edge on whole pixels (ResourceSnap.lua); the
-- fill runs from 0 to 1 over the swing's duration, read from PLAYER_SWING.
-- A duration the client doesn't give as a plain number leaves the lane full.
-- It shows while a swing runs (and briefly after), and with a sample in
-- Edit Mode and Test on Screen.
local L, Kit, Style = addon.L, addon.Kit, addon.Style
local Tone, UnitColor, Number = Style.Tone, addon.Domain.UnitColor, addon.IsNumber
local PM = addon.PositionManager
local LANE_GAP, LINGER, OFF_HAND_FOR = 1, 1.5, 8 -- px between lanes; seconds shown after a swing ends; off-hand lane life

local function Now() return GetTime and GetTime() or 0 end

local function NewLane(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.bar = Kit.Bar(box)
    box.edge = Style.Edge(box, M.EDGE, { pieces = true })
    box.text = Kit.Text(box.bar)
    box.text.lift = Kit.Text(box.bar, "ARTWORK")
    return box
end

-- Built with the module's other frames on first enable, where the client has the API.
function M:BuildSwing()
    if self.swingFrame or not self.caps.swingTimer then return end
    local style = self.db.swing
    local mover = CreateFrame("Frame", self.SWING_FRAME, UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(style.width, style.height)
    mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
    mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT); Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
    mover:SetPoint("CENTER", UIParent, "CENTER", 0, -60)
    self.swingMover = mover
    local ok, reason = PM:RegisterElement(self.SWING_ELEMENT, mover, { moduleId = self.id,
        defaultPosition = self.swingPosition, anyTarget = true, gapPixels = 1,
        canDrag = function() return self.active == true and self.db.swing.show end,
        label = L[self.SWING_LABEL] })
    assert(ok, "ModeUI: swing timer position registration failed: " .. tostring(reason))
    PM:SetSizeMatch(self.SWING_ELEMENT, {
        axes = { width = true },
        get = function() return self.db.swing.matchWidth end,
        set = function(_, on) return self:SetSwingOption("matchWidth", on == true) end,
    })
    PM:SetAnchorSizeListener(self.SWING_ELEMENT, function(_, width)
        self.swingAnchorWidth = Number(width, 1, 10000) and width or nil
        if self.active then self:LayoutSwing() end
    end)
    mover:Hide()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame.lanes = { NewLane(frame), NewLane(frame) }
    frame:Hide()
    self.swingFrame = frame
    self.swings = { main = {}, off = {} }
end

-- The per-frame update runs only while a swing is under way (and its linger);
-- otherwise the lanes keep their last paint and nothing runs each frame.
local function OnUpdate() M:TickSwing() end
function M:SetSwingTicking(on)
    local frame = self.swingFrame
    if not frame or (self.swingTicking == true) == (on == true) then return end
    self.swingTicking = on == true or nil
    frame:SetScript("OnUpdate", on and OnUpdate or nil)
end

function M:SwingWidth(px)
    local style = self.db.swing
    local width = style.width
    if style.matchWidth then
        if not addon.InCombat() then
            local live = PM:GetAnchorWidth(self.SWING_ELEMENT)
            self.swingAnchorWidth = Number(live, 1, 10000) and live or nil
        end
        width = self.swingAnchorWidth or width
    end
    return math.max(px, math.floor(width / px + 0.5) * px)
end

-- Lanes: the main hand (or ranged) always; the off hand while it swings.
function M:SwingLanes()
    local style, swings = self.db.swing, self.swings or {}
    local off = style.offHand and swings.off and swings.off.at and Now() - swings.off.at < OFF_HAND_FOR
    return (off or self.swingSample) and 2 or 1
end

-- The height `lanes` lanes take, `px` a physical pixel.
function M:SwingHeight(lanes, px)
    local style = self.db.swing
    local laneHeight = M.ResourceBarHeight(style, px) + 2 * M.ResourceReach(style, px)
    return lanes * laneHeight + (lanes - 1) * LANE_GAP * px
end

function M:LayoutSwing()
    local frame, mover = self.swingFrame, self.swingMover
    if not frame then return end
    local px = Kit.PixelSize(mover)
    local width, lanes = self:SwingWidth(px), self:SwingLanes()
    mover:SetSize(width, self:SwingHeight(lanes, px))
    self:PlaceResourceFrame(frame, mover)
    self.swingColor = self:SwingColor()
    self:LayoutSwingLanes(frame, width, px, lanes)
    self:TickSwing()
end

-- Lays out `frame`'s lanes (the Swing Timer's, or its page preview's) at
-- `width`, the first `lanes` shown.
function M:LayoutSwingLanes(frame, width, px, lanes)
    local style = self.db.swing
    local h, reach = M.ResourceBarHeight(style, px), M.ResourceReach(style, px)
    local laneHeight = h + 2 * reach
    local look = { outline = style.outline, shadow = style.shadow, slug = style.slug, textColor = style.textColor }
    local path = Style.Weighted(Kit.FontPath(style, self.id), "bold")
    for index, box in ipairs(frame.lanes) do
        local shown = index <= lanes
        box:SetShown(shown)
        if shown then
            local y = (index - 1) * (laneHeight + LANE_GAP * px) + reach
            box:ClearAllPoints(); box:SetPoint("TOPLEFT", frame, "TOPLEFT", reach, -y); box:SetSize(width - 2 * reach, h)
            box:SetFrameLevel(frame:GetFrameLevel() + 1)
            local bar = box.bar
            bar:ClearAllPoints(); bar:SetAllPoints(box); bar:SetFrameLevel(box:GetFrameLevel() + 1)
            bar:SetMinMaxValues(0, 1)
            Kit.BarForeground(bar, style.barTexture, h, px)
            Kit.BarBackground(bar, style.barBackground, width - 2 * reach, h, px)
            local back = Kit.BarBackgroundColor(style.barBackground)
            if bar.bg and back then Kit.Tint(bar.bg, back, style.barBackgroundOpacity / 100) end
            box.edge:SetRim(style.edgeSize); box.edge:SetStyle(style.edgeStyle, style.edgeMetal)
            box.edge:SetShown(style.border ~= "none"); box.edge:Layout(); box.edge:SetLevel(3)
            local tint = (style.rimColor == "custom" and style.rimCustom) or (style.rimColor == "bar" and self:SwingColor()) or nil
            box.edge:SetTint(tint)
            Kit.Font(box.text, look, style.textSize, path, px)
            box.text:ClearAllPoints(); box.text:SetPoint("RIGHT", box, "RIGHT", -4 * px, 0)
            box.text:SetShown(style.timerShow)
            Kit.LayoutLift(box.text, look, style.textSize, path, px, false, "RIGHT")
        end
    end
end

-- The sample swing (Edit Mode, Test on Screen and the page's preview): each
-- lane's fill and seconds left. PaintSwingSample paints it on the preview.
local SAMPLE = { { value = 0.6, left = 1.4 }, { value = 0.25, left = 2.1 } }
function M:PaintSwingSample(frame)
    local style, color = self.db.swing, self:SwingColor()
    for index, box in ipairs(frame.lanes) do
        box.bar:SetValue(SAMPLE[index].value)
        local texture = box.bar:GetStatusBarTexture()
        if texture then Kit.Tint(texture, color, 1) end
        Kit.Write(box.text, style.timerShow and string.format("%.1f", SAMPLE[index].left) or "")
    end
end
M.NewSwingLane = NewLane

function M:SwingColor()
    local style = self.db.swing
    -- Class colors come as { r, g, b }; the tint takes { 1, 2, 3 }.
    local class = style.barColorMode == "class" and UnitColor.PlayerClass("player")
    return class and { class.r, class.g, class.b } or style.barColor
end

-- Each frame while a swing runs, and on every change: every lane's fill, its
-- out-of-range tint and timer. The color comes from the last layout, so a
-- frame's paint makes no new tables.
local NO_SWING = {}
function M:TickSwing()
    local frame = self.swingFrame
    if not frame then return end
    local style, now, swings = self.db.swing, Now(), self.swings
    local color = self.swingColor or self:SwingColor()
    local live = false
    for index, box in ipairs(frame.lanes) do
        local swing, value, left = (index == 1 and swings.main or swings.off) or NO_SWING, 1, nil
        if self.swingSample then value, left = SAMPLE[index].value, SAMPLE[index].left
        elseif swing.at and swing.duration then
            local elapsed = now - swing.at
            value = math.min(1, elapsed / swing.duration)
            left = math.max(0, swing.duration - elapsed)
            if elapsed < swing.duration + LINGER then live = true end
        end
        box.bar:SetValue(value)
        local out = style.rangeTint and swing.outOfRange
        local fill = out and Tone.rosewood or color
        local texture = box.bar:GetStatusBarTexture()
        if texture then Kit.Tint(texture, fill, 1) end
        Kit.Write(box.text, (style.timerShow and left) and string.format("%.1f", left) or "")
    end
    local show = style.show and self.active and (live or self.swingSample)
    frame:SetAlpha(show and style.opacity / 100 or 0)
    self:SetSwingTicking(style.show and self.active and live and not self.swingSample)
end

-- PLAYER_SWING: (swingDuration, swingType); the range update: (swingType, inRange, checksRange).
function M:OnSwingEvent(event, a, b, c)
    local swings = self.swings
    if not swings then return end
    if event == "PLAYER_SWING" then
        local kind = (b == self.SWING_TYPES.off and "off") or ((b == self.SWING_TYPES.ranged and not self.db.swing.ranged) and nil) or "main"
        if not kind then return end
        local lanes = self:SwingLanes()
        swings[kind].at = Now()
        self.swingSeen = { public = Number(a, 0, 600) }
        swings[kind].duration = Number(a, 0.05, 60) and a or nil
        if self:SwingLanes() ~= lanes then self:LayoutSwing() end
    elseif event == "PLAYER_SWING_RANGE_UPDATE" then
        local kind = a == self.SWING_TYPES.off and "off" or "main"
        swings[kind].outOfRange = c == true and b == false
    end
    self:TickSwing()
end

function M:SetSwingEvents(on)
    if not self.caps.swingTimer then return end
    local frame = self.swingEvents
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...) M:OnSwingEvent(event, ...) end)
        self.swingEvents = frame
    end
    for _, event in ipairs({ "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE" }) do
        if on then pcall(frame.RegisterEvent, frame, event) else pcall(frame.UnregisterEvent, frame, event) end
    end
    for _, kind in ipairs({ "main", "ranged" }) do
        pcall(_G.C_SwingTimer.EnableRangeCheck, self.SWING_TYPES[kind], on and self.db.swing.rangeTint or false)
    end
end

-- In Edit Mode the stand-in shows while the bar is on, with a sample.
function M:RenderSwingMover()
    local mover = self.swingMover
    if not mover then return end
    local show = self.editing == true and self.active == true and self.db.swing.show
    PM:SetEditable(self.SWING_ELEMENT, show)
    mover:SetShown(show)
    self.swingSample = (show or self.testDisplay) and true or nil
    self:LayoutSwing()
end

function M:RefreshSwing()
    if not self.swingFrame then return end
    self.swingFrame:SetShown(self.active == true)
    if self.active then self:LayoutSwing() end
    self:RenderSwingMover()
end

function M:SwingStatus()
    if not self.caps.swingTimer then return L["This client has no swing timer."] end
    if not self.active then return L["Off. Turn the Cooldown Manager on (the switch at the top) to use the swing timer."] end
    if not self.db.swing.show then return L["This bar is off."] end
    return L["Shows your auto-attack swings. Move it in Edit Mode."]
end

-- Settings ---------------------------------------------------------------------

function M:SetSwingOption(key, value)
    if not self:CanConfigure() or self.swingDefaults[key] == nil then return false end
    local candidate = addon.ProfileCodec.Copy(self.db)
    candidate.swing[key] = addon.ProfileCodec.Copy(value)
    local group, follow = self.playerKeyGroup[key], candidate.swing.follow
    if group and type(follow) == "table" and follow[group] then follow[group] = false end
    if not pcall(self.Initialize, candidate) then return false end
    self.db.swing[key] = candidate.swing[key]
    self.db.swing.follow = candidate.swing.follow
    if key == "rangeTint" and self.active then self:SetSwingEvents(true) end
    self:RefreshSwing()
    if self.swingPage then self.swingPage:Refresh() end
    if self.window then self:RefreshList() end
    return true
end
function M:ResetSwing()
    if not self:CanConfigure() then return false end
    local style = addon.ProfileCodec.Copy(self.swingDefaults)
    for key in pairs(self.swingIdentityKeys) do style[key] = self.db.swing[key] end
    style.follow = { border = true, text = true }
    local target = self.db.swing
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(style) do target[key] = value end
    self.ApplyPlayerStyle(self.db, target)
    self:RefreshSwing()
    if self.swingPage then self.swingPage:Refresh() end
    return true
end

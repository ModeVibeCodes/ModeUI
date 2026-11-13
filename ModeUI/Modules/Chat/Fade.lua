local _, addon = ...
local M = addon.Chat
if not M then return end

-- Three eased levels drive every alpha:
--   useLevel  1 while the chat is in use, 0 when it isn't: the scroll bar.
--   tabLevel  1 while the chat was used in the last Idle Delay seconds, 0
--             once it's idle: tabs and the compartment move between Tabs
--             When Idle (100 keeps them full) and their own level (selected
--             full, the others Other Tabs). Not tied to the window fade.
--   fadeLevel 1 while the chat was used in the last Idle Delay seconds, then
--             Idle Opacity: the windows (text, fill, border, edit band).
-- "In use" means the mouse is over a window (with its tab row and edit box),
-- a tab or the compartment, the edit box has focus, the chat menu or the tab
-- overflow list is open, or a window is being moved. A whisper also counts
-- when Wake on Whispers is on. Levels ease in quickly and out slowly.
-- Blizzard fades tabs with SetAlpha every frame; Skin.PinAlpha puts ModeUI's
-- value back after each call, so its own tab constants are never touched.
local Skin, Kit = addon.Skin, addon.Kit
local Snap = Skin.Snap
local FADE_IN = 0.15

local function Visible(region)
    if not region or not region.IsVisible then return false end
    local visible = region:IsVisible()
    return addon.IsPublic(visible) and visible == true
end
local function Over(region, ...)
    if not Visible(region) or not region.IsMouseOver then return false end
    local ok, over = pcall(region.IsMouseOver, region, ...)
    return ok and addon.IsPublic(over) and over == true
end

function M:InUse()
    if MOVING_CHATFRAME then return true end
    for _, frame in ipairs(self:ChatFrames()) do
        local edit = frame.editBox
        if edit and edit.HasFocus and edit:HasFocus() == true then return true end
        if Visible(frame) then
            local px = Kit.PixelSize(frame)
            local inset, quick = Snap(self.TEXT_INSET, px), frame.CombatLogQuickButtonFrame
            local height = quick and quick.GetHeight and quick:GetHeight()
            inset = inset + self:Rim(px)
            local editTop, editBottom = self:EditSpace(px)
            local top = inset + editTop + Snap(self.db.tabHeight, px) + (addon.IsNumber(height, 0, 200) and height or 0)
            local bottom = inset + editBottom
            local right = inset + (self.db.scrollBar and Snap(self.SCROLL_GUTTER, px) or 0)
            if Over(frame, top, -bottom, -inset, right) then return true end
        end
        if Over(self:TabOf(frame)) or Over(edit) then return true end
    end
    if Over(self.compartment) then return true end
    local dock = GENERAL_CHAT_DOCK
    local list = dock and dock.overflowButton and dock.overflowButton.list
    if Visible(list) then return true end
    local menu = ChatFrameMenuButton
    if menu and menu.IsMenuOpen then
        local ok, open = pcall(menu.IsMenuOpen, menu)
        if ok and open == true then return true end
    end
    return false
end

-- Marks the chat as used now (a whisper with Wake on Whispers).
function M:Wake() self.lastUse = GetTime() end

function M:StartFade()
    if not self.fader then
        local fader = CreateFrame("Frame")
        fader:SetScript("OnUpdate", function(_, elapsed) self:FadeStep(elapsed) end)
        self.fader = fader
    end
    self.tabLevel = self.tabLevel or 1
    self.useLevel = self.useLevel or 0
    self.fadeLevel = self.fadeLevel or 1
    self.lastUse = self.lastUse or GetTime()
    self.clock = self.TICK_SECONDS
    self.fader:Show()
end

function M:StopFade()
    if self.fader then self.fader:Hide() end
    self.tabLevel, self.useLevel, self.fadeLevel = 1, 1, 1
    for _, frame in ipairs(self:ChatFrames()) do
        frame:SetAlpha(1)
        local tab = self:TabOf(frame)
        if tab then Skin.Unpin(tab) end
        if frame.ScrollToBottomButton then Skin.Unpin(frame.ScrollToBottomButton) end
        if frame.ScrollBar then Skin.Unpin(frame.ScrollBar) end
    end
    local overflow = GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.overflowButton
    if overflow then Skin.Unpin(overflow) end
    if self.compartment then self.compartment:SetAlpha(1) end
end

-- Whether the chat has gone unused for Idle Delay seconds.
function M:IsIdle(now) return now - (self.lastUse or now) >= self.db.idleDelay end

-- The idle target: full while recently used (or with Idle Fade off).
function M:IdleTarget(now)
    if not self.db.idleFade or not self:IsIdle(now) then return 1 end
    return self.db.idleOpacity / 100
end

local function Ease(current, target, elapsed)
    if current == target then return current end
    local step = elapsed / (target > current and FADE_IN or M.FADE_SECONDS)
    if target > current then return math.min(target, current + step) end
    return math.max(target, current - step)
end

function M:FadeStep(elapsed)
    if not self.active then return end
    self.clock = (self.clock or 0) + elapsed
    if self.clock >= self.TICK_SECONDS then
        self.clock = 0
        local now = GetTime()
        local using = self:InUse()
        if using then self.lastUse = now end
        self.useTarget, self.fadeTarget = using and 1 or 0, self:IdleTarget(now)
        self.tabTarget = self:IsIdle(now) and 0 or 1
        self:ApplyScrollButtons()
    end
    local use = Ease(self.useLevel, self.useTarget or self.useLevel, elapsed)
    local tab = Ease(self.tabLevel, self.tabTarget or self.tabLevel, elapsed)
    local fade = Ease(self.fadeLevel, self.fadeTarget or self.fadeLevel, elapsed)
    if tab ~= self.tabLevel or fade ~= self.fadeLevel or use ~= self.useLevel then
        self.tabLevel, self.fadeLevel, self.useLevel = tab, fade, use
        self:ApplyAlpha()
    end
end

-- A tab: full when selected, Other Tabs otherwise, easing to Tabs When Idle
-- once the chat is idle; a tab flashing for a new whisper stays full.
function M:TabAlpha(tab)
    if not self.active then return nil end
    local near = self:IsSelected(tab) and 1 or self.db.unselectedTabOpacity / 100
    local alerting = false
    if ChatFrameUtil and ChatFrameUtil.IsTabAlerting then
        local ok, value = pcall(ChatFrameUtil.IsTabAlerting, tab)
        alerting = ok and value == true
    end
    if alerting then near = 1 end
    if alerting then return 1 end
    -- Tabs When Idle scales the tab's own level: 100 keeps it as it is.
    local idle = self.db.awayTabOpacity / 100
    local level = self.tabLevel or 1
    return near * (idle + (1 - idle) * level)
end

-- The scroll bar: with the mouse over the chat (it's in the window, which
-- the idle fade dims too).
function M:ScrollBarAlpha()
    if not self.active then return nil end
    if not self.db.scrollBar then return 0 end
    return self.useLevel or 0
end

-- Scroll to Bottom shows while its window is scrolled up.
function M:ScrollButtonAlpha(button)
    if not self.active then return nil end
    local frame = button:GetParent()
    if frame and frame.AtBottom then
        local ok, bottom = pcall(frame.AtBottom, frame)
        if ok and bottom == false then return 1 end
    end
    return 0
end
function M:ApplyScrollButtons()
    for _, frame in ipairs(self:ChatFrames()) do
        local button = frame.ScrollToBottomButton
        if button and Skin.pins[button] then button:SetAlpha(self:ScrollButtonAlpha(button) or 0) end
    end
end

-- Pushes both levels out: window alpha, tabs (through their pins), the tab
-- overflow button and the compartment.
function M:ApplyAlpha()
    if not self.active then return end
    local fade, level = self.fadeLevel or 1, self.tabLevel or 1
    for _, frame in ipairs(self:ChatFrames()) do
        frame:SetAlpha(fade)
        local tab = self:TabOf(frame)
        if tab and Skin.pins[tab] then tab:SetAlpha(self:TabAlpha(tab)) end
        if frame.ScrollBar and Skin.pins[frame.ScrollBar] then frame.ScrollBar:SetAlpha(self:ScrollBarAlpha() or 0) end
    end
    local idle = self.db.awayTabOpacity / 100
    local chrome = idle + (1 - idle) * level
    local overflow = GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.overflowButton
    if overflow and overflow.SetAlpha then Skin.PinAlpha(overflow, function() return self.active and chrome or nil end) end
    if self.compartment then self.compartment:SetAlpha(chrome) end
end

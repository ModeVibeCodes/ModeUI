local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- Groups: a window with Group With set stacks on that window (Above it by
-- default, or Below, Gap apart) and takes every shared setting from the
-- window at the head of its group: width, bars, text, header, frame, Show, opacity and the
-- lock. It keeps its own meter, fight and Rows, so a group can grow up or
-- down one window at a time. Groups can chain (3 on 2 on 1) but never loop.
-- A grouped window has no place of its own: it hangs from the window it
-- follows, so moving the head moves the group. Its saved place is kept for
-- when it leaves the group.
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- The window at the head of a window's group (the window itself when it isn't grouped).
function M:Leader(window)
    local current, steps = window, 0
    while self.db[current].group ~= "none" and steps < #self.windows do
        current, steps = self.db[current].group, steps + 1
    end
    return current
end

function M:IsGrouped(window) return self.db[window].group ~= "none" end

-- The settings a window draws with: its own keys, the rest from its head.
-- Cached until the next settings change.
function M:Style(window)
    self.styles = self.styles or {}
    local style = self.styles[window]
    if style then return style end
    local leader = self:Leader(window)
    if leader == window then style = self.db[window]
    else
        style = Copy(self.db[leader])
        for key in pairs(self.ownKeys) do style[key] = Copy(self.db[window][key]) end
    end
    self.styles[window] = style
    return style
end
function M:ClearStyles() self.styles = nil end

-- Which window a setting is saved on: shared settings of a grouped window
-- belong to the head of its group.
function M:OwnerOf(window, key)
    if self.ownKeys[key] then return window end
    return self:Leader(window)
end

-- Windows that can be grouped with `window` without a loop: not itself, and
-- not a window that already follows it.
function M:GroupChoices(window)
    local list = { { id = "none", label = addon.L["None"] } }
    for _, other in ipairs(self.windows) do
        local loops, current, steps = other == window, other, 0
        while not loops and self.db[current].group ~= "none" and steps < #self.windows do
            current, steps = self.db[current].group, steps + 1
            if current == window then loops = true end
        end
        if not loops then list[#list + 1] = { id = other, label = addon.L[self.windowLabels[other]] } end
    end
    return list
end

-- Edit Mode's Match Width and Match Height. A window (not grouped) takes the
-- width of the element picked for Match Width, or as many rows as fit the
-- height of the one picked for Match Height (without a pick, what it's
-- anchored on: PositionManager:GetSizeMatchTarget), so a stack keeps together
-- however the window it follows changes: by its grip, its settings or Copy &
-- Apply. Rows never change for Match Width alone.
-- On another meter window it reads that window's settings, so the change
-- lands on the same refresh; on anything else, its size on screen (outside
-- combat), watched through Position Manager's anchor size listener.
local PM, P, Kit = addon.PositionManager, addon.Positioning, addon.Kit

-- The anchor a match applies to now, or nil. axis: "Width" or "Height".
function M:Matching(window, axis)
    local own = self.db[window]
    if self:IsGrouped(window) or not own["match" .. axis] then return end
    return (PM:GetSizeMatchTarget(self.elementIds[window], axis:lower()))
end

local function TargetSize(self, target, px)
    for _, other in ipairs(self.windows) do
        if self.elementIds[other] == target then
            local g = self.Geometry(self:Style(other), px)
            return g.width, g.height
        end
    end
    local frame = P:Resolve(target)
    if not frame then return end
    local _, _, width, height = P:Geometry(frame)
    return width, height
end

-- Applies every match (windows anchor only on windows listed before them, so
-- one pass in order settles a stack). Returns whether anything changed.
function M:MatchAnchored()
    local changed = false
    for _, window in ipairs(self.windows) do
        local own = self.db[window]
        local wide, tall = self:Matching(window, "Width"), self:Matching(window, "Height")
        local px = Kit.PixelSize(self.frames[window] or UIParent)
        local width, height
        if wide then width = TargetSize(self, wide, px) end
        if tall then local _, h = TargetSize(self, tall, px); height = h end
        if width and self:Matching(window, "Width") then
            local range = self.ranges.width
            local fit = math.max(range[1], math.min(range[2], math.floor(width + 0.5)))
            if fit ~= own.width then own.width, changed = fit, true end
        end
        if height and self:Matching(window, "Height") then
            local range, rows = self.ranges.rows, self.ranges.rows[1]
            for count = range[1], range[2] do
                if self.Geometry(own, px, count).height <= height + px / 2 then rows = count end
            end
            if rows ~= own.rows then own.rows, changed = rows, true end
        end
        if changed then self:ClearStyles() end
    end
    return changed
end

-- Edit Mode's Match Width and Match Height switches for a window's stand-in.
function M:SizeMatchHandlers(window)
    return {
        axes = { width = true, height = true },
        get = function(axis) return self.db[window][axis == "width" and "matchWidth" or "matchHeight"] end,
        set = function(axis, on) return self:SetOption(window, axis == "width" and "matchWidth" or "matchHeight", on == true) end,
        available = function() return not self:IsGrouped(window) end,
    }
end

-- Hangs a window from its stand-in, or from the window it follows.
function M:AnchorWindow(window, g)
    local frame, own = self.frames[window], self.db[window]
    frame:ClearAllPoints()
    if own.group == "none" then
        frame:SetPoint("TOPLEFT", self.movers[window], "TOPLEFT", 0, 0)
        return
    end
    local leader = self.frames[own.group]
    local gap = math.floor(own.groupGap / g.px + 0.5) * g.px
    if own.groupSide == "above" then frame:SetPoint("BOTTOMLEFT", leader, "TOPLEFT", 0, gap)
    else frame:SetPoint("TOPLEFT", leader, "BOTTOMLEFT", 0, -gap) end
end

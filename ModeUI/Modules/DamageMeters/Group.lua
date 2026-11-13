local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- Groups: a window with Group With set stacks on that window (Below or
-- Above it, Gap apart) and takes every shared setting from the window at the
-- head of its group: width, bars, text, header, frame, Show, opacity and the
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

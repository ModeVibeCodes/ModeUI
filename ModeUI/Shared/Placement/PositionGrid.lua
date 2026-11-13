local _, addon = ...
local PM, E = addon.PositionManager, addon.EditMode

-- Edit Mode's screen overlay: Center Lines (one vertical and one horizontal
-- line through the screen's center, where the X and Y readout is 0) and an
-- optional Grid, counted out from the center. Both are click-through and
-- drawn under every element. They're session choices in the Edit Mode
-- window, like Show Highlights: Center Lines start on, Grid off.
E.centerLines, E.grid = true, false
PM.GRID_SPACING = 32 -- UI units between grid lines
local GRID_ALPHA, CENTER_ALPHA = 0.14, 0.7

local function Line(frame, layer)
    local line = frame:CreateTexture(nil, layer)
    line:Hide()
    return line
end

-- A full-height (vertical) or full-width line at `offset` UI units from the
-- screen's center, one physical pixel thick.
local function Place(line, vertical, offset, px, color, alpha)
    line:SetColorTexture(color[1], color[2], color[3], alpha)
    line:ClearAllPoints()
    if vertical then
        line:SetPoint("TOP", UIParent, "TOP", offset, 0); line:SetPoint("BOTTOM", UIParent, "BOTTOM", offset, 0)
        line:SetWidth(px)
    else
        line:SetPoint("LEFT", UIParent, "LEFT", 0, offset); line:SetPoint("RIGHT", UIParent, "RIGHT", 0, offset)
        line:SetHeight(px)
    end
    line:Show()
end

function PM:RenderGrid()
    local lines, grid = addon.editMode and E.centerLines, addon.editMode and E.grid
    local g = self.grid
    if not lines and not grid then
        if g then g.frame:Hide() end
        return
    end
    if not g then
        local frame = CreateFrame("Frame", "ModeUIEditGrid", UIParent)
        frame:SetAllPoints(UIParent); frame:SetFrameStrata("BACKGROUND"); frame:EnableMouse(false)
        g = { frame = frame, lines = {}, centerX = Line(frame, "ARTWORK"), centerY = Line(frame, "ARTWORK") }
        self.grid = g
    end
    g.frame:Show()
    local px = addon.Kit.PixelSize(UIParent)
    local function Snap(value) return math.floor(value / px + 0.5) * px end
    local used = 0
    if grid then
        local spacing, white = self.GRID_SPACING, addon.Theme.text
        local halfWidth, halfHeight = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
        local function Add(vertical, offset)
            used = used + 1
            g.lines[used] = g.lines[used] or Line(g.frame, "BACKGROUND")
            Place(g.lines[used], vertical, Snap(offset), px, white, GRID_ALPHA)
        end
        for i = 1, math.floor(halfWidth / spacing) do Add(true, i * spacing); Add(true, -i * spacing) end
        for i = 1, math.floor(halfHeight / spacing) do Add(false, i * spacing); Add(false, -i * spacing) end
        -- Without Center Lines the grid still marks the center, faintly.
        if not lines then Add(true, 0); Add(false, 0) end
    end
    for i = used + 1, #g.lines do g.lines[i]:Hide() end
    local primary = addon.Theme.primary
    if lines then
        Place(g.centerX, true, 0, px, primary, CENTER_ALPHA)
        Place(g.centerY, false, 0, px, primary, CENTER_ALPHA)
    else g.centerX:Hide(); g.centerY:Hide() end
end

function E:SetCenterLines(show)
    self.centerLines = show == true
    addon.PositionManager:RenderGrid()
end

function E:SetGrid(show)
    self.grid = show == true
    addon.PositionManager:RenderGrid()
end

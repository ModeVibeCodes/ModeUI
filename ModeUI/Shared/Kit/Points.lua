local _, addon = ...
local Kit = addon.Kit

-- Class resource points (combo points): one round socket per point, a rim in
-- the ModeUI border color, a dark socket and a fill. The count may be secret,
-- so each point is its own StatusBar spanning (index - 1, index):
-- SetValue(count) fills it or leaves it empty without the count ever being
-- compared. Used by the Target frame (Unit Frames) and the target's nameplate.

-- One point on `parent`, the index-th of a row or arc.
function Kit.ResourcePoint(parent, index)
    local point = CreateFrame("Frame", nil, parent)
    point.rim = Kit.Circle(point, "BACKGROUND", 0)
    point.socket = Kit.Circle(point, "BACKGROUND", 1)
    point.bar = CreateFrame("StatusBar", nil, point)
    point.bar:SetMinMaxValues(index - 1, index)
    point.bar:SetValue(index - 1)
    return point
end

-- Sizes and colors a point: `size` square, a 1px rim, the fill 2px in.
function Kit.LayoutResourcePoint(point, size, px, emptyColor, activeColor)
    point:SetSize(size, size)
    point.rim:ClearAllPoints(); point.rim:SetAllPoints(point); Kit.Tint(point.rim, Kit.BORDER_COLOR, 1)
    Kit.Inset(point.socket, point, px); Kit.Tint(point.socket, emptyColor, 1)
    local bar = point.bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", point, "TOPLEFT", 2 * px, -2 * px)
    bar:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -2 * px, 2 * px)
    addon.Style.SetBarTexture(bar, addon.Media:GetTexture("UnitFrameCircle"))
    bar:SetStatusBarColor(activeColor[1], activeColor[2], activeColor[3], 1)
end

-- The point size as a whole, even pixel count, so a point's centre sits on
-- the pixel grid.
function Kit.ResourcePointSize(size, px) return math.max(2 * px, math.floor(size / (2 * px) + 0.5) * 2 * px) end

-- Fills the first `count` points from a read: `ok` and a possibly secret
-- `value` (Domain.ClassResource.Read). An unreadable count shows them empty.
function Kit.FillResourcePoints(points, count, ok, value)
    for i = 1, count do
        local bar = points[i].bar
        if ok then pcall(bar.SetValue, bar, value) else bar:SetValue(i - 1) end
    end
end

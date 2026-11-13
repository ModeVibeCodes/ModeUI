local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- Pixel-perfect bar geometry: where each button sits and how big the bar is.
-- Buttons fill lines (rows, or columns) of Buttons per Line from the First
-- Button corner. Every size is whole physical pixels and the bar is an even
-- number of pixels each way, so a centered bar stays on the pixel grid.
local Kit = addon.Kit

-- style: a bar's settings; count: buttons to place; px: one physical pixel.
-- Returns { width, height, button = { w, h }, inset, px, points = { { point, x, y } } }.
function M.Geometry(style, count, px)
    px = px or 1
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local w, h, gap = Snap(style.width), Snap(style.height), Round(style.spacing)
    count = math.max(1, count)
    local perLine = math.max(1, math.min(style.perLine, count))
    local lines = math.ceil(count / perLine)
    local horizontal = style.orientation == "horizontal"
    local columns, rows = horizontal and perLine or lines, horizontal and lines or perLine
    local g = { px = px, w = w, h = h, points = {}, columns = columns, rows = rows }
    -- The rim (1px) and black gap (1px) sit inside the button; the icon fills the rest.
    g.inset = style.border == "none" and 0 or 2 * px
    g.width = columns * w + (columns - 1) * gap
    g.height = rows * h + (rows - 1) * gap
    local function Odd(v) return math.floor(v / px + 0.5) % 2 == 1 end
    if Odd(g.width) then g.width = g.width + px end
    if Odd(g.height) then g.height = g.height + px end
    local point = style.start
    local sx = point:find("RIGHT") and -1 or 1
    local sy = point:find("BOTTOM") and 1 or -1
    for i = 1, count do
        local along, across = (i - 1) % perLine, math.floor((i - 1) / perLine)
        local column, row = horizontal and along or across, horizontal and across or along
        g.points[i] = { point, sx * column * (w + gap), sy * row * (h + gap) }
    end
    return g
end

-- Places a frame at one of the geometry's points inside `bar`.
function M.Place(frame, bar, g, index)
    local p = g.points[index]
    frame:ClearAllPoints()
    frame:SetPoint(p[1], bar, p[1], p[2], p[3])
    frame:SetSize(g.w, g.h)
end

-- The pixel size of a bar's frame, for its geometry.
function M.PixelSize(frame) return Kit.PixelSize(frame) end

-- How many buttons a bar shows: its Buttons setting, and for the stance bar
-- no more than the stances the character has (0 hides the bar).
function M:ButtonCount(bar)
    local style = self.db[bar]
    if not self.barSpecs[bar].stance then return style.buttons end
    local ok, forms = addon.Domain.Query.Call(GetNumShapeshiftForms)
    if not ok or not addon.IsNumber(forms, 0, 100) then return 0 end
    return math.min(style.buttons, math.floor(forms))
end

-- The count drawn by stand-ins and previews: never zero, so an empty stance
-- bar can still be placed.
function M:SampleCount(bar)
    local count = self:ButtonCount(bar)
    return count > 0 and count or self.db[bar].buttons
end

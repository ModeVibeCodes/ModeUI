local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Where each viewer sits and how its icons are laid out. Each viewer has a
-- stand-in (its Edit Mode element, named for the viewer) that ModeUI's Edit
-- Mode moves, and a holder on it that the icons hang from. The icons stay
-- Blizzard's children (so Blizzard still shows and hides them), but ModeUI
-- anchors them to the holder in lines of Icons per Line from the First Icon
-- corner, a short last line centered when Center Lines is on. Blizzard's own
-- viewer frames are never moved: they sit in the game's managed layout, and
-- moving them from addon code could taint it.
local Kit, L = addon.Kit, addon.L
local Cooldowns = addon.Domain.Cooldowns

-- style: a viewer's settings; count: icons to place; px: one physical pixel.
-- Returns { width, height, w, h, px, border, inset, points = { { point, x, y } } }.
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
    g.border, g.inset = Kit.SlotInsets(style, px)
    g.width = columns * w + (columns - 1) * gap
    g.height = rows * h + (rows - 1) * gap
    local function Odd(v) return math.floor(v / px + 0.5) % 2 == 1 end
    if Odd(g.width) then g.width = g.width + px end
    if Odd(g.height) then g.height = g.height + px end
    local point = style.start
    local sx = point:find("RIGHT") and -1 or 1
    local sy = point:find("BOTTOM") and 1 or -1
    local step = horizontal and (w + gap) or (h + gap)
    for i = 1, count do
        local along, across = (i - 1) % perLine, math.floor((i - 1) / perLine)
        -- A short last line moves half its missing icons along, to the middle.
        local inLine = math.min(perLine, count - across * perLine)
        local shift = style.center and Round((perLine - inLine) * step / 2) or 0
        local x, y
        if horizontal then x, y = along * (w + gap) + shift, across * (h + gap)
        else x, y = across * (w + gap), along * (h + gap) + shift end
        g.points[i] = { point, sx * x, sy * y }
    end
    return g
end

function M.Place(frame, holder, g, index)
    local p = g.points[index]
    frame:ClearAllPoints()
    frame:SetPoint(p[1], holder, p[1], p[2], p[3])
    frame:SetSize(g.w, g.h)
end

-- The stand-ins and holders, built on first enable.
function M:Build()
    if self.built then return end
    self.built = true
    self.movers, self.holders = {}, {}
    for _, viewer in ipairs(self.viewers) do
        local mover = CreateFrame("Frame", self.frameNames[viewer], UIParent)
        mover:SetFrameStrata("HIGH")
        mover:SetSize(self.db[viewer].width, self.db[viewer].height)
        mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
        mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT); Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
        mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self.movers[viewer] = mover
        local ok, reason = addon.PositionManager:RegisterElement(self.elementIds[viewer], mover, { moduleId = self.id,
            defaultPosition = self.defaultPositions[viewer], allowedTargets = self.allowedTargets[viewer],
            canDrag = function() return self.active == true and self.db[viewer].show end,
            label = L[self.viewerSpecs[viewer].label] })
        assert(ok, "ModeUI: cooldown manager position registration failed: " .. tostring(reason))
        mover:Hide()
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:SetAllPoints(mover)
        self.holders[viewer] = holder
    end
end

-- In ModeUI's Edit Mode each viewer that's on shows its stand-in: a cyan
-- box the size of its icons, with its name on Edit Mode's handle.
function M:RenderMovers()
    if not self.built then return end
    for _, viewer in ipairs(self.viewers) do
        local show = self.editing == true and self.active == true and self.db[viewer].show
        addon.PositionManager:SetEditable(self.elementIds[viewer], show)
        self.movers[viewer]:SetShown(show)
    end
end

-- The icons a viewer lays out now: those tracking a spell, minus spells
-- switched off here and items Blizzard hides (an inactive buff with Hide
-- When Inactive). A shown state the game keeps secret counts as shown.
-- Blizzard's own Edit Mode fills empty items with sample icons; those count.
function M:Placed(viewer)
    local placed, parked = {}, {}
    for _, item in ipairs(self:Items(viewer)) do
        local key = self:SpellKey(item)
        local shown = Cooldowns.Shown(item)
        if key and self:SpellSwitch(viewer, key, "hide") then parked[#parked + 1] = item
        elseif shown ~= false and (key or shown == true) then placed[#placed + 1] = item end
    end
    return placed, parked
end

-- Places a viewer's icons and sizes its stand-in to fit them (at least one
-- icon, so an empty viewer can still be placed).
function M:LayoutViewer(viewer)
    if not self.built or not self.active then return end
    local style, holder, mover = self.db[viewer], self.holders[viewer], self.movers[viewer]
    local placed, parked = self:Placed(viewer)
    local g = self.Geometry(style, #placed, self.PixelSize(holder))
    mover:SetSize(g.width, g.height)
    for index, item in ipairs(placed) do
        if item.SetScale then item:SetScale(1) end
        self.Place(item, holder, g, index)
        self:DressItem(viewer, item, g)
    end
    -- Spells switched off here wait, unseen, in the middle of the viewer.
    for _, item in ipairs(parked) do
        item:ClearAllPoints(); item:SetPoint("CENTER", holder, "CENTER", 0, 0)
        self:DressItem(viewer, item, g)
    end
    self.placedCount = self.placedCount or {}
    self.placedCount[viewer] = #placed
    self:UpdateAlpha(viewer)
    self:QueuePreview(viewer)
end

function M.PixelSize(frame) return Kit.PixelSize(frame) end

function M:LayoutAll()
    for _, viewer in ipairs(self.viewers) do self:LayoutViewer(viewer) end
end

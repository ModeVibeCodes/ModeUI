local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- Where each bar sits. A bar's mover (named, so other elements can anchor to
-- it) is its Edit Mode element, sized for every icon the bar can hold so its
-- edges stay put as auras come and go; the holder follows the mover and holds
-- the container (the game resizes a container as auras change, and forbids
-- anchoring other frames to it). Bars anchor to anything: the screen,
-- Blizzard's Buff Frame (its Edit Mode place), ModeUI's frames, each other.
local Kit, L = addon.Kit, addon.L
M.TEXT_GAP = 2 -- between an icon and time text under or over it

-- Icon width and height in whole physical pixels (each its own setting; the
-- height starts 4 or 6px shorter, Style.IconHeight).
function M:IconSize(bar, px)
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    return Snap(bar.width), Snap(bar.height)
end
-- Room for time text under or over the icon.
function M:TextRoom(bar, px)
    if bar.timer ~= "below" and bar.timer ~= "above" then return 0 end
    return (bar.timerSize + self.TEXT_GAP) * px
end
-- One icon's cell (the icon and its time text's room).
function M:CellSize(bar, px)
    local width, height = self:IconSize(bar, px)
    return width, height + self:TextRoom(bar, px)
end
-- Columns and rows a full bar takes.
function M:Grid(bar)
    local across = math.min(bar.max, bar.perRow)
    local lines = math.ceil(bar.max / bar.perRow)
    if self.HORIZONTAL[bar.grow] then return across, lines end
    return lines, across
end
function M:BarSize(bar, px)
    local cw, ch = self:CellSize(bar, px)
    local columns, rows = self:Grid(bar)
    local spacing = bar.spacing * px
    return columns * cw + (columns - 1) * spacing, rows * ch + (rows - 1) * spacing
end
-- The corner the first icon sits in: away from where the icons grow and
-- where new rows go.
function M:StartCorner(bar)
    local x, y
    if self.HORIZONTAL[bar.grow] then
        x = bar.grow == "left" and "RIGHT" or "LEFT"
        y = bar.wrap == "up" and "BOTTOM" or "TOP"
    else
        y = bar.grow == "up" and "BOTTOM" or "TOP"
        x = bar.wrap == "left" and "RIGHT" or "LEFT"
    end
    return y .. x
end

function M:DefaultPosition(id)
    if self.defaultPositions[id] then return self.defaultPositions[id] end
    local _, index = self:Custom(id)
    if id == "custom1" then return self.firstCustomPosition end
    return self.CustomPosition(index or 1)
end

-- Other bars may anchor to a new custom bar.
function M:AllowBarTarget(id)
    local PM = addon.PositionManager
    for _, other in ipairs(self:BarIds()) do
        if other ~= id and PM:Element(self.ElementId(other)) then PM:AllowTarget(self.ElementId(other), self.ElementId(id)) end
    end
end

local function BuildMover(self, id)
    local mover = CreateFrame("Frame", self.FrameName(id), UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(32, 26)
    mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
    mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT); Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
    mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.movers[id] = mover
    local PM, eid = addon.PositionManager, self.ElementId(id)
    -- Anchors to any ModeUI element and to frames picked with Anchor To.
    local ok, reason = PM:RegisterElement(eid, mover, { moduleId = self.id, defaultPosition = self:DefaultPosition(id),
        anyTarget = true, canDrag = function() return self.active == true and self:HasBar(id) and self.db.bars[id].show end,
        label = self:BarLabel(id), onPositionChanged = function() self:RenderSamples(id) end })
    assert(ok, "ModeUI: buffs and debuffs position registration failed: " .. tostring(reason))
    mover:Hide()
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetAllPoints(mover)
    holder:SetFrameStrata("MEDIUM")
    self.holders[id] = holder
end

-- Movers for the bars there are, none for deleted ones.
function M:SyncMovers()
    if not self.active and not self.built then return end
    self.built = true
    for _, id in ipairs(self:BarIds()) do
        if not self.movers[id] then BuildMover(self, id) end
    end
    for id, mover in pairs(self.movers) do
        if not self:HasBar(id) then
            addon.PositionManager:UnregisterElement(self.ElementId(id))
            mover:Hide(); self.holders[id]:Hide()
            local container = self.containers[id]
            if container then container:SetEnabled(false); container:Hide() end
            self.movers[id], self.holders[id], self.containers[id] = nil, nil, nil
        end
    end
    -- Each mover takes its bar's full size.
    for id, mover in pairs(self.movers) do
        local px = Kit.PixelSize(mover)
        mover:SetSize(self:BarSize(self.db.bars[id], px))
    end
    for id in pairs(self.movers) do addon.PositionManager:ApplyPosition(self.ElementId(id)) end
end

-- In ModeUI's Edit Mode every bar that's on shows its stand-in (a cyan box
-- the size of the full bar, its name on Edit Mode's handle) over sample icons.
function M:RenderMovers()
    if not self.built then return end
    for id, mover in pairs(self.movers) do
        local show = self.editing == true and self.active == true and self.db.bars[id].show
        addon.PositionManager:SetEditable(self.ElementId(id), show)
        mover:SetShown(show)
        self:RenderSamples(id)
    end
end

-- Edit Mode's panel (and Open Page) shows the page on the selected bar.
function M:OpenElementSettings(eid)
    for id in pairs(self.db.bars) do
        if self.ElementId(id) == eid and self.page and self.page.SetEditing then self.page.SetEditing(id); return end
    end
end

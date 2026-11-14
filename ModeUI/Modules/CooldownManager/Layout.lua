local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Where each bar sits and how its icons are laid out. Each bar has a
-- stand-in (its Edit Mode element, named for the bar) the size of one full
-- line, and a holder on it that the icons hang from. Growth picks how a line
-- fills: Centered Horizontal and Centered Vertical keep the icons in the
-- middle of the line, the others start at one end; New Lines picks which
-- way further lines go, outside the stand-in, so the first line never moves.
-- The icons stay Blizzard's children (so Blizzard still shows and hides
-- them), but ModeUI anchors them to the holder. Blizzard's own viewer frames
-- are never moved: they sit in the game's managed layout, and moving them
-- from addon code could taint it.
local Kit, L = addon.Kit, addon.L
local Cooldowns = addon.Domain.Cooldowns

-- style: a bar's settings; count: icons to place; px: one physical pixel.
-- Returns { width, height (the first line), w, h, px, border, inset,
-- extent = { width, height, x, y } (every line, and where the first sits in
-- it), points = { { "TOPLEFT", x, y } } (from the holder's top left) }.
function M.Geometry(style, count, px)
    px = px or 1
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local w, h, gap = Snap(style.width), Snap(style.height), Round(style.spacing)
    count = math.max(0, count)
    local per = math.max(1, style.perLine)
    local horizontal = M.horizontalGrowth[style.grow] == true
    local g = { px = px, w = w, h = h, points = {} }
    -- The ModeUI border is 2px; the content starts at its inner edge.
    if style.border == "mode" then g.border = Kit.BORDER_PIXELS * px; g.inset = g.border
    else g.border, g.inset = Kit.SlotInsets(style, px) end
    local long = per * (horizontal and w or h) + (per - 1) * gap
    g.width, g.height = horizontal and long or w, horizontal and h or long
    local function Even(v) return math.floor(v / px + 0.5) % 2 == 1 and v + px or v end
    g.width, g.height = Even(g.width), Even(g.height)
    local lines = math.max(1, math.ceil(count / per))
    local back = style.lineGrowth == "up" or style.lineGrowth == "left"
    local across = (lines - 1) * ((horizontal and h or w) + gap)
    g.extent = { width = g.width + (horizontal and 0 or across), height = g.height + (horizontal and across or 0),
        x = (not horizontal and back) and across or 0, y = (horizontal and back) and across or 0 }
    local step = (horizontal and w or h) + gap
    local size = horizontal and w or h
    for i = 1, count do
        local along, line = (i - 1) % per, math.floor((i - 1) / per)
        local inLine = math.min(per, count - line * per)
        local offset
        if style.grow == "right" or style.grow == "down" then offset = along * step
        elseif style.grow == "left" or style.grow == "up" then offset = long - size - along * step
        else offset = Round((per - inLine) * step / 2) + along * step end
        local cross = line * ((horizontal and h or w) + gap) * (back and -1 or 1)
        if horizontal then g.points[i] = { "TOPLEFT", offset, -cross }
        else g.points[i] = { "TOPLEFT", cross, -offset } end
    end
    return g
end

function M.Place(frame, holder, g, index)
    local p = g.points[index]
    frame:ClearAllPoints()
    frame:SetPoint(p[1], holder, p[1], p[2], p[3])
    frame:SetSize(g.w, g.h)
end

-- The stand-ins and holders, built on first enable, and a custom bar's when
-- it's added. A deleted custom bar's are put away.
function M:Build()
    if self.built then return end
    self.built = true
    self.movers, self.holders = {}, {}
    self:SyncBarFrames()
end

function M:EnsureBarFrames(id)
    if self.movers[id] then return end
    local style = self.db[id]
    local mover = CreateFrame("Frame", self.FrameName(id), UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(style.width, style.height)
    mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
    mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT); Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
    mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.movers[id] = mover
    local custom, index = self:Custom(id)
    local ok, reason = addon.PositionManager:RegisterElement(self.ElementId(id), mover, { moduleId = self.id,
        defaultPosition = custom and self.CustomPosition(index) or self.defaultPositions[id],
        allowedTargets = custom and self.customTargets or self.allowedTargets[id],
        canDrag = function() return self.active == true and self:HasBar(id) and self.db[id].show end,
        label = custom and custom.name or L[self.viewerSpecs[id].label] })
    assert(ok, "ModeUI: cooldown manager position registration failed: " .. tostring(reason))
    mover:Hide()
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetAllPoints(mover)
    self.holders[id] = holder
end

function M:SyncBarFrames()
    if not self.built then return end
    for _, id in ipairs(self:BarIds()) do self:EnsureBarFrames(id) end
    for id, mover in pairs(self.movers) do
        if not self:HasBar(id) then
            addon.PositionManager:UnregisterElement(self.ElementId(id))
            mover:Hide()
            self.movers[id], self.holders[id] = nil, nil
        end
    end
end

-- In ModeUI's Edit Mode each bar that's on shows its stand-in: a cyan box
-- the size of one line of its icons, with its name on Edit Mode's handle.
function M:RenderMovers()
    if not self.built then return end
    for id, mover in pairs(self.movers) do
        local show = self.editing == true and self.active == true and self.db[id].show
        addon.PositionManager:SetEditable(self.ElementId(id), show)
        mover:SetShown(show)
    end
end

-- The icons a bar lays out now, in order: those tracking a spell that shows
-- on this bar, minus spells switched off here and items Blizzard hides (an
-- inactive buff with Hide When Inactive). A shown state the game keeps
-- secret counts as shown. Blizzard's own Edit Mode fills empty items with
-- sample icons; those count on its viewers.
function M:Placed(id)
    local placed, parked = {}, {}
    local custom = self:Custom(id)
    local order = {}
    if custom then for index, key in ipairs(custom.entries) do order[key] = index end end
    for _, viewer in ipairs(self:Sources(id)) do
        for _, item in ipairs(self:Items(viewer)) do
            local key = self:SpellKey(item)
            local shown = Cooldowns.Shown(item)
            if (key and self:Owner(item) == id) or (not key and not custom and shown == true) then
                if key and self:SpellSwitch(id, key, "hide") then parked[#parked + 1] = item
                elseif shown ~= false then placed[#placed + 1] = item end
            end
        end
    end
    if custom then
        table.sort(placed, function(a, b) return (order[self:SpellKey(a)] or 0) < (order[self:SpellKey(b)] or 0) end)
    end
    return placed, parked
end

-- Places a bar's icons; the stand-in keeps the size of one full line.
function M:LayoutViewer(id)
    if not self.built or not self.active or not self.holders[id] then return end
    local style, holder, mover = self.db[id], self.holders[id], self.movers[id]
    local placed, parked = self:Placed(id)
    local g = self.Geometry(style, #placed, self.PixelSize(holder))
    mover:SetSize(g.width, g.height)
    for index, item in ipairs(placed) do
        if item.SetScale then item:SetScale(1) end
        self.Place(item, holder, g, index)
        self:DressItem(id, item, g)
    end
    -- Spells switched off here wait, unseen, in the middle of the bar.
    for _, item in ipairs(parked) do
        item:ClearAllPoints(); item:SetPoint("CENTER", holder, "CENTER", 0, 0)
        self:DressItem(id, item, g)
    end
    self.placedCount = self.placedCount or {}
    self.placedCount[id] = #placed
    self:QueuePreview(id)
end

function M.PixelSize(frame) return Kit.PixelSize(frame) end

function M:LayoutAll()
    for _, id in ipairs(self:BarIds()) do self:LayoutViewer(id) end
end

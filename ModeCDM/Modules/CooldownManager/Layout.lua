local _, ns = ...
local addon = ns.ModeUI or {}
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

-- style: a bar's settings; count: icons to place; px: one physical pixel;
-- match: { width, height } to take from what the bar hangs from (Match
-- Width / Match Height), or nil. Returns { width, height (the first line),
-- w, h (an icon's size), px, border, inset, extent = { width, height, x, y }
-- (every line, and where the first sits in it), points = { { "TOPLEFT", x, y } }
-- (from the holder's top left), sizes = { { w, h } } (each icon's own) }.
--
-- A line is cut into Icons per Line slots on whole pixels: slot s runs from
-- Round(s * (line + gap) / per) to the next slot's start less the gap. With
-- the icons' own size that's exactly icon, gap, icon...; matched to a length
-- it stays pixel perfect, the icons differing by a pixel at most. Centered
-- lines shift a short line by half a slot per missing icon.
--
-- The `frameThin` edge sits outside each icon (docs/DESIGN_LANGUAGE.md,
-- "Cooldown icons"): every slot is the icon plus the edge's reach on each
-- side, so the line holds the edges and Spacing counts between their shadows.
-- The icon fills its slot inside the reach (no inset). Border Size widens
-- the band, and the reach with it (frameThin: the 1px shadow ring plus the band).
--
-- Every UI scale (owner, November 24, 2026: 1080p and 1440p): sizes are UI
-- units rounded to whole pixels, so at the pixel-perfect scales (1 unit, 1
-- pixel) they are exact and elsewhere a pixel off at most. The edge's reach
-- is physical pixels, and so is a negative Spacing: it overlaps the edges'
-- shadow rings, which are pixels, so -1 shares one shadow pixel and -2 makes
-- the bands touch at any scale (as UI units, -1 overlapped two pixels at
-- 1440p on Blizzard's default scale).
M.EDGE = "frameThin"
M.EDGE_REACH = addon.Style.EdgeReach(M.EDGE)
function M.IconReach(style)
    if style.border == "none" then return 0 end
    return M.EDGE_REACH + (style.edgeSize or 1) - 1
end
function M.Geometry(style, count, px, match)
    px = px or 1
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local horizontal = M.horizontalGrowth[style.grow] == true
    local w, h = Snap(style.width), Snap(style.height)
    local gap = style.spacing < 0 and style.spacing * px or Round(style.spacing)
    local reach = M.IconReach(style) * px
    count = math.max(0, count)
    local per = math.max(1, style.perLine)
    local alongKey, crossKey = horizontal and "width" or "height", horizontal and "height" or "width"
    local along, cross = horizontal and w or h, horizontal and h or w
    -- Outer sizes: the icon with its edge.
    local long = per * (along + 2 * reach) + (per - 1) * gap
    local outer = cross + 2 * reach
    if match and match[alongKey] then long = math.max(per * (px + 2 * reach), Snap(match[alongKey])) end
    if match and match[crossKey] then outer = math.max(px + 2 * reach, Snap(match[crossKey])); cross = outer - 2 * reach end
    local slot = (long + gap) / per
    along = math.max(px, Round(slot - gap) - 2 * reach)
    if horizontal then w, h = along, cross else w, h = cross, along end
    local g = { px = px, w = w, h = h, reach = reach, border = 0, inset = 0, points = {}, sizes = {} }
    g.width, g.height = horizontal and long or outer, horizontal and outer or long
    local function Even(v) return math.floor(v / px + 0.5) % 2 == 1 and v + px or v end
    if not (match and match.width) then g.width = Even(g.width) end
    if not (match and match.height) then g.height = Even(g.height) end
    local lines = math.max(1, math.ceil(count / per))
    local back = style.lineGrowth == "up" or style.lineGrowth == "left"
    local across = (lines - 1) * (outer + gap)
    g.extent = { width = g.width + (horizontal and 0 or across), height = g.height + (horizontal and across or 0),
        x = (not horizontal and back) and across or 0, y = (horizontal and back) and across or 0 }
    local function Start(at) return Round(at * slot) end
    for i = 1, count do
        local index, line = (i - 1) % per, math.floor((i - 1) / per)
        local inLine = math.min(per, count - line * per)
        local at
        if style.grow == "right" or style.grow == "down" then at = index
        elseif style.grow == "left" or style.grow == "up" then at = per - 1 - index
        else at = index + (per - inLine) / 2 end
        local offset, size = Start(at) + reach, Start(at + 1) - gap - Start(at) - 2 * reach
        local shift = line * (outer + gap) * (back and -1 or 1) + reach
        if horizontal then g.points[i], g.sizes[i] = { "TOPLEFT", offset, -shift }, { size, cross }
        else g.points[i], g.sizes[i] = { "TOPLEFT", shift, -offset }, { cross, size } end
    end
    return g
end

-- Places a frame at one of the geometry's points inside `holder`, at that
-- icon's own size. Returns the geometry for that icon (its own w and h).
function M.Place(frame, holder, g, index)
    local p, size = g.points[index], g.sizes and g.sizes[index]
    frame:ClearAllPoints()
    frame:SetPoint(p[1], holder, p[1], p[2], p[3])
    local w, h = size and size[1] or g.w, size and size[2] or g.h
    frame:SetSize(w, h)
    if w == g.w and h == g.h then return g end
    return setmetatable({ w = w, h = h }, { __index = g })
end

-- The stand-ins and holders, built on first enable, and a custom bar's when
-- it's added. A deleted custom bar's are put away.
function M:Build()
    if self.built then return end
    self.built = true
    self.movers, self.holders, self.anchorSizes = {}, {}, {}
    self:SyncBarFrames()
    self:BuildResources()
    self:BuildCast()
    self:BuildSwing()
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
    local PM, eid = addon.PositionManager, self.ElementId(id)
    -- A default bar has its own place (Presets.lua); other custom bars
    -- start in the middle of the screen.
    local place = custom and (self.PresetPosition(custom.preset) or self.CustomPosition(index)) or self.defaultPositions[id]
    -- Anchors to any ModeUI element (the other bars, resource bars, unit
    -- frames, action bars...) and to frames picked with Anchor To, 1 physical
    -- pixel off the side it hangs from.
    local ok, reason = PM:RegisterElement(eid, mover, { moduleId = self.id,
        defaultPosition = place,
        anyTarget = true, gapPixels = 1,
        canDrag = function() return self.active == true and self:HasBar(id) and self.db[id].show end,
        label = custom and custom.name or L[self.viewerSpecs[id].label] })
    assert(ok, "ModeUI: cooldown manager position registration failed: " .. tostring(reason))
    -- Match Width / Match Height in the Edit Mode window: the bar takes the
    -- width (or height) of the element picked for it (by default, what it
    -- hangs from), its icons resizing to fill it, and follows it when that
    -- changes size (the target's own OnSizeChanged, no polling). Each axis is
    -- told on its own.
    local function Key(axis) return axis == "width" and "matchWidth" or "matchHeight" end
    PM:SetSizeMatch(eid, { axes = { width = true, height = true },
        get = function(axis) return self:HasBar(id) and self.db[id][Key(axis)] == true end,
        set = function(axis, on) return self:SetOption(id, Key(axis), on == true) end })
    PM:SetAnchorSizeListener(eid, function(_, width, height)
        if not self:HasBar(id) then return end
        local Number = addon.IsNumber
        local size = { width = Number(width, 1, 10000) and width or nil, height = Number(height, 1, 10000) and height or nil }
        self.anchorSizes[id] = (size.width or size.height) and size or nil
        if self.active and (self.db[id].matchWidth or self.db[id].matchHeight) then self:LayoutViewer(id) end
    end)
    mover:Hide()
    -- The icons hang from the holder, the stand-in's size and on whole
    -- pixels (ResourceSnap.lua), so their 1px edges stay sharp at a UI scale
    -- that isn't pixel perfect.
    local holder = CreateFrame("Frame", nil, UIParent)
    self:PlaceResourceFrame(holder, mover)
    self.holders[id] = holder
end

function M:SyncBarFrames()
    if not self.built then return end
    for _, id in ipairs(self:BarIds()) do self:EnsureBarFrames(id) end
    for id, mover in pairs(self.movers) do
        if not self:HasBar(id) then
            self.anchorSizes[id] = nil
            addon.PositionManager:UnregisterElement(self.ElementId(id))
            mover:Hide()
            local holder = self.holders[id]
            if holder then self:UnsnapResourceFrame(holder); holder:Hide() end
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
-- sample icons; those count on its viewers. A viewer's own spells come
-- first, in Blizzard's order, then the bar's own list in its order (all of
-- a custom bar's spells).
function M:Placed(id)
    local placed, listed, parked = {}, {}, {}
    local order = {}
    for index, key in ipairs(self:Entries(id)) do order[key] = index end
    for _, viewer in ipairs(self:Sources(id)) do
        for _, item in ipairs(self:Items(viewer)) do
            local key = self:SpellKey(item)
            local shown = Cooldowns.Shown(item)
            if (key and self:Owner(item) == id) or (not key and viewer == id and shown == true) then
                if key and self:SpellSwitch(id, key, "hide") then parked[#parked + 1] = item
                elseif shown ~= false then
                    local list = key and order[key] and listed or placed
                    list[#list + 1] = item
                end
            end
        end
    end
    -- Spells by ID and items, on ModeUI's own icons.
    for _, icon in ipairs(self:SpellIcons(id)) do
        if self:SpellSwitch(id, self:SpellKey(icon), "hide") then parked[#parked + 1] = icon else listed[#listed + 1] = icon end
    end
    table.sort(listed, function(a, b) return (order[self:SpellKey(a)] or 0) < (order[self:SpellKey(b)] or 0) end)
    for _, item in ipairs(listed) do placed[#placed + 1] = item end
    -- A viewer's spells in the order you dragged them.
    if not self:IsCustom(id) then self:Ordered(id, placed, function(item) return self:SpellKey(item) end) end
    return placed, parked
end

-- Places a bar's icons; the stand-in keeps the size of one full line.
function M:LayoutViewer(id)
    if not self.built or not self.active or not self.holders[id] then return end
    local style, holder, mover = self.db[id], self.holders[id], self.movers[id]
    local placed, parked = self:Placed(id)
    local g = self.Geometry(style, #placed, self.PixelSize(holder), self:MatchSize(id))
    mover:SetSize(g.width, g.height)
    -- The new size can put the holder between pixels: back onto whole ones.
    self:PlaceResourceFrame(holder, mover)
    for index, item in ipairs(placed) do
        if self:IsOwnIcon(item) then item:Show() end
        if item.SetScale then item:SetScale(1) end
        self:DressItem(id, item, self.Place(item, holder, g, index))
    end
    -- Spells switched off here wait, unseen, in the middle of the bar.
    for _, item in ipairs(parked) do
        if self:IsOwnIcon(item) then item:Show() end
        item:ClearAllPoints(); item:SetPoint("CENTER", holder, "CENTER", 0, 0)
        self:DressItem(id, item, g)
    end
    self.placedCount = self.placedCount or {}
    self.placedCount[id] = #placed
    for _, item in ipairs(placed) do if self:IsOwnIcon(item) then self:UpdateSpellIcon(item) end end
    self:QueuePreview(id)
end

-- The size a bar takes from what it hangs from, on the axes it matches.
function M:MatchSize(id)
    local style, size = self.db[id], self.anchorSizes and self.anchorSizes[id]
    if not size or not (style.matchWidth or style.matchHeight) then return nil end
    return { width = style.matchWidth and size.width or nil, height = style.matchHeight and size.height or nil }
end

function M.PixelSize(frame) return Kit.PixelSize(frame) end

function M:LayoutAll()
    for _, id in ipairs(self:BarIds()) do self:LayoutViewer(id) end
end

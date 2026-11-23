local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Stacks (docs/NAMEPLATES.md, "Placement"): past the spine (Layout.lua), each
-- anchor point holds an aura row and a row of the parts placed there (the raid
-- marker, the indicators, the combo points), in a fixed order. With Auras
-- First (the default) the aura row sits nearest the bar and the part row
-- follows the row's last icon; Indicators First swaps them. A part that is
-- missing takes no room, so the rest close up toward the bar. Target arrows
-- are always the outermost part on each side.
--
-- Aura rows can be secret: in the world, Blizzard's aura containers size
-- themselves to what they show and ModeUI may not read that size. So each row
-- keeps an edge mark, a 1x1 frame anchored to the container's far edge
-- (AuraContainers.lua) or placed at the last icon (the reader, Auras.lua), and
-- whatever follows a row is anchored to its mark: the game moves it as the
-- row fills, and nothing is measured. Marks anchored to a container are made
-- from Blizzard's DisableUntrustedLayoutScriptsTemplate, as Blizzard asks of
-- frames anchored to one (ForbiddenAspectTemplates.xml).
local Horizontal = M.Horizontal

local function Round(value, px) return math.floor(value / px + 0.5) * px end

M.FOLLOWER_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"
local hasFollower
function M.HasFollowerTemplate()
    if hasFollower == nil then
        local ok, info = pcall(function() return C_XMLUtil and C_XMLUtil.GetTemplateInfo(M.FOLLOWER_TEMPLATE) end)
        hasFollower = (ok and info ~= nil) and true or false
    end
    return hasFollower
end

-- A mark (1x1 frame) in plate[store][key], made on demand.
function M:Mark(plate, store, key)
    plate[store] = plate[store] or {}
    local mark = plate[store][key]
    if not mark then
        local template = (not plate.sample and self:UsesAuraContainers() and M.HasFollowerTemplate()) and M.FOLLOWER_TEMPLATE or nil
        mark = CreateFrame("Frame", nil, plate.textLayer, template)
        mark:SetSize(1, 1)
        plate[store][key] = mark
    end
    return mark
end

-- The point of a row's edge mark that sits on the edge: rows and arrows that
-- follow the row anchor to this same point of the mark.
function M.EdgePoint(key)
    if key == "LEFT" then return "RIGHT" elseif key == "RIGHT" then return "LEFT" end
    local h = Horizontal(key)
    return (key:find("^TOP") and "BOTTOM" or "TOP") .. h
end

-- Aura groups by row key: the anchor, with ":border" for a Top or Bottom
-- group set to Sit on Border (it sits on the border line, not in a stack).
function M:GroupKey(style, group)
    local settings = style[group]
    local anchor = settings.anchor
    if settings.attach and (anchor:find("^TOP") or anchor:find("^BOTTOM")) then return anchor .. ":border" end
    return anchor
end
function M:GroupShown(plate, group)
    local style = self:Style(plate)
    return style.showAuras and style[group].show and not plate.nameOnly
end
function M:HasGroups(plate, key)
    local style = self:Style(plate)
    for _, group in ipairs(M.auraGroups) do
        if self:GroupShown(plate, group) and self:GroupKey(style, group) == key then return true end
    end
    return false
end

-- Which stack a part joins: Center sits inside the bar; Left and Right inside
-- it when the part's Inside switch is on.
local function PartKey(anchor, inside)
    if anchor == "CENTER" then return "IN-CENTER" end
    if inside and (anchor == "LEFT" or anchor == "RIGHT") then return "IN-" .. anchor end
    return anchor
end
-- Order in a row, from the bar outward (inside: from the bar's edge inward,
-- so the level is always the leftmost of what sits inside on the left).
local OUT_ORDER = { raid = 1, quest = 2, classification = 3, level = 4, combo = 5 }
local IN_ORDER = { level = 1, classification = 2, quest = 3, raid = 4, combo = 5 }

-- Every part showing now, by stack key: { id, region, w, h, dx, dy }.
function M:StackParts(plate)
    local style, px = self:Style(plate), plate.px or 1
    local parts = {}
    local function Put(id, region, w, h, anchor, inside, dx, dy)
        local key = PartKey(anchor, inside)
        parts[key] = parts[key] or {}
        table.insert(parts[key], { id = id, region = region, w = w, h = h, dx = Round(dx or 0, px), dy = Round(dy or 0, px) })
    end
    if style.showRaidIcon and plate.raidIcon:IsShown() then
        Put("raid", plate.raidIcon, plate.markSize, plate.markSize, style.raidAnchor, style.raidInside, style.raidX, style.raidY)
    end
    for _, part in ipairs(M.indicatorParts) do
        local region, size = plate.indicatorParts[part], plate.indicatorSizes and plate.indicatorSizes[part]
        if region:IsShown() and size then
            Put(part, region, size[1], size[2], style[part .. "Anchor"], style[part .. "Inside"], style[part .. "X"], style[part .. "Y"])
        end
    end
    local combo = plate.combo
    if combo and combo.count > 0 then Put("combo", combo, combo.width, combo.size, style.comboAnchor, false, style.comboX, style.comboY) end
    for key, list in pairs(parts) do
        local order = key:find("^IN%-") and IN_ORDER or OUT_ORDER
        table.sort(list, function(a, b) return order[a.id] < order[b.id] end)
    end
    return parts
end

-- Where members start in a row and which way they go.
local START = { LEFT = "RIGHT", TOPRIGHT = "RIGHT", BOTTOMRIGHT = "RIGHT", ["IN-RIGHT"] = "RIGHT" }

function M:StackRow(plate, key)
    plate.stackRows = plate.stackRows or {}
    local row = plate.stackRows[key]
    if not row then
        row = CreateFrame("Frame", nil, plate.textLayer)
        row:SetFrameLevel(plate.textLayer:GetFrameLevel() + 1)
        plate.stackRows[key] = row
    end
    return row
end

-- Combo points set to Move Up While Not Casting sit right under the bar's
-- border line until a cast shows (CastBar.lua places the stacks again).
function M:StackBelow(plate, key, list)
    local style = self:Style(plate)
    if key:find("^BOTTOM") and style.comboFollowCast and not plate.castBox:IsShown() then
        for _, part in ipairs(list or {}) do if part.id == "combo" then return plate.belowNoCast or plate.below end end
    end
    return plate.below
end

-- Places one row: inside the bar, beside it, or past the spine on Top and
-- Bottom; with Auras First a row on an anchor that has aura groups follows
-- the aura row's edge mark.
function M:PlaceRow(plate, key, row, width, height, list)
    local px = plate.px or 1
    local gap, box = 2 * px, plate.healthBox
    row:SetSize(math.max(px, width), math.max(px, height))
    row:ClearAllPoints()
    if key == "IN-LEFT" then row:SetPoint("LEFT", plate.health, "LEFT", gap, 0)
    elseif key == "IN-RIGHT" then row:SetPoint("RIGHT", plate.health, "RIGHT", -gap, 0)
    elseif key == "IN-CENTER" then row:SetPoint("CENTER", plate.health, "CENTER", 0, 0)
    else
        local follow = self:AurasFirst(plate) and self:HasGroups(plate, key)
        -- In the world a row can't anchor to an aura row's mark (its parts
        -- can't carry the forbidden aspect: Plate.lua BuildPlate), so it sits
        -- past the aura row's full reach instead; the preview follows the mark.
        local fixed = follow and self:InWorld(plate)
        local edge = M.EdgePoint(key)
        if key == "LEFT" or key == "RIGHT" then
            local sign = key == "LEFT" and -1 or 1
            if fixed then row:SetPoint(edge, box, key, sign * (gap + self:RowReach(plate, key) + gap), 0)
            elseif follow then row:SetPoint(edge, self:Mark(plate, "auraEnds", key), edge, sign * gap, 0)
            else row:SetPoint(edge, box, key, sign * 3 * px, 0) end
        else
            local top, h = key:find("^TOP") ~= nil, Horizontal(key)
            local sign = top and 1 or -1
            local past = top and plate.above or self:StackBelow(plate, key, list)
            if fixed then row:SetPoint(edge, box, (top and "TOP" or "BOTTOM") .. h, 0, sign * (gap + past + self:RowReach(plate, key) + gap))
            elseif follow then row:SetPoint(edge, self:Mark(plate, "auraEnds", key), edge, 0, sign * gap)
            else row:SetPoint(edge, box, (top and "TOP" or "BOTTOM") .. h, 0, sign * (gap + past)) end
        end
    end
end

-- Plates in the world, whose aura rows are Blizzard's containers.
function M:InWorld(plate) return not plate.sample and self:UsesAuraContainers() end

-- How far the aura row on `key` can reach away from the bar with every group
-- at Most Shown: along its growth beside the bar, across it on Top and Bottom
-- (one line's height: known, only a row's length is secret).
function M:RowReach(plate, key)
    local style, px = self:Style(plate), plate.px or 1
    local spacing, along, across, vertical = style.auraSpacing * px, 0, 0, false
    for _, group in ipairs(M.auraGroups) do
        if self:GroupShown(plate, group) and self:GroupKey(style, group) == key then
            local settings, width, height = style[group], self:AuraSize(plate, group)
            vertical = settings.grow == "up" or settings.grow == "down" or (settings.grow == "center" and (key == "LEFT" or key == "RIGHT"))
            along = along + settings.max * ((vertical and height or width) + spacing)
            across = math.max(across, vertical and width or height)
        end
    end
    along = math.max(0, along - spacing)
    if key == "LEFT" or key == "RIGHT" then return vertical and across or along end
    return vertical and along or across
end

-- Anchors `region` to a mark that may sit on an aura container: in the world
-- the game can refuse it (forbidden aspects); then `fallback` places it.
function M:FollowMark(region, point, mark, markPoint, x, y, fallback)
    if pcall(region.SetPoint, region, point, mark, markPoint, x, y) then return true end
    region:ClearAllPoints()
    fallback()
    return false
end

-- Lays out every stack row and what depends on it: the room inside the bar
-- for text, the aura rows (Indicators First), the arrows and the soft-target
-- icon. Runs on every layout and whenever a part shows, hides or resizes.
function M:PlaceStacks(plate)
    if not plate.healthBox then return end
    local px = plate.px or 1
    local gap = 2 * px
    local parts = self:StackParts(plate)
    plate.rowSize = {}
    for key, row in pairs(plate.stackRows or {}) do
        if not parts[key] then row:SetSize(px, px) end
    end
    for key, list in pairs(parts) do
        local row = self:StackRow(plate, key)
        local start = START[key] or "LEFT"
        local sign = start == "LEFT" and 1 or -1
        local width, height = -gap, 0
        for _, part in ipairs(list) do width, height = width + part.w + gap, math.max(height, part.h) end
        local along = 0
        for _, part in ipairs(list) do
            part.region:ClearAllPoints()
            part.region:SetPoint(start, row, start, sign * along + part.dx, part.dy)
            along = along + part.w + gap
        end
        plate.rowSize[key] = { width, height }
        self:PlaceRow(plate, key, row, width, height, list)
    end
    -- Inside the bar, text starts past the parts on its side.
    local inside = { LEFT = 0, RIGHT = 0 }
    for side in pairs(inside) do
        local size = plate.rowSize["IN-" .. side]
        if size then inside[side] = size[1] + gap end
    end
    local moved = not plate.insideRoom or plate.insideRoom.LEFT ~= inside.LEFT or plate.insideRoom.RIGHT ~= inside.RIGHT
    plate.insideRoom = inside
    if moved then self:PlaceInsideTexts(plate) end
    -- Indicators First: aura rows start past the part rows, so a change in a
    -- row's size moves them.
    local room = {}
    if not self:AurasFirst(plate) then
        for key, size in pairs(plate.rowSize) do
            if key == "LEFT" or key == "RIGHT" then room[key] = size[1] + 3 * px
            elseif not key:find("^IN%-") then room[key] = size[2] + gap end
        end
    end
    local changed = false
    for key, value in pairs(room) do if (plate.rowRoom or {})[key] ~= value then changed = true end end
    for key in pairs(plate.rowRoom or {}) do if room[key] == nil then changed = true end end
    plate.rowRoom = room
    if changed and plate.auraIcons then self:LayoutAuras(plate) end
    self:PlaceArrows(plate)
    self:LayoutSoftTarget(plate)
end

function M:PlaceInsideTexts(plate)
    local style = self:Style(plate)
    if plate.nameOnly then return end
    for _, entry in ipairs({ { plate.healthText, style.healthTextAnchor, style.healthTextX, style.healthTextY },
        { plate.name, style.nameAnchor, style.nameX, style.nameY } }) do
        local anchor = entry[2]
        if not (anchor:find("^TOP") or anchor:find("^BOTTOM")) then self:PlaceInsideText(plate, entry[1], anchor, entry[3], entry[4]) end
    end
end

-- Room the part row takes beside the bar on one side, with a 3px gap.
function M:IndicatorRoom(plate, side)
    local size = plate.rowSize and plate.rowSize[side]
    return size and size[1] + 3 * (plate.px or 1) or 0
end

-- The outermost part on a side ("LEFT" or "RIGHT") and its edge point: the
-- part row or the aura row's mark, whichever comes last; else the bar.
function M:SideEdge(plate, side)
    local hasRow = plate.rowSize and plate.rowSize[side] ~= nil
    local hasAuras = self:HasGroups(plate, side)
    local rowFrame = hasRow and self:StackRow(plate, side)
    local mark = hasAuras and self:Mark(plate, "auraEnds", side)
    local last
    if self:AurasFirst(plate) then last = rowFrame or mark else last = mark or rowFrame end
    -- A row's outer edge is its own side; a mark's is its edge point.
    if last == rowFrame and rowFrame then return rowFrame, side end
    if last then return last, M.EdgePoint(side) end
end

-- Target arrows: always the outermost part on each side, anchored to it, so
-- they move in and out with what shows there.
function M:PlaceArrows(plate)
    local db, px = self:Style(plate), plate.px or 1
    local host = plate.nameOnly and plate.name or plate.healthBox
    local size = math.max(px, math.floor(db.targetArrowSize / px + 0.5) * px)
    local gapPixels = db.targetArrowGap * px
    -- Each arrow sits in its own frame (Plate.lua): in the world that frame
    -- carries the forbidden aspect, so it may follow an aura row's mark.
    for side, frame in pairs(plate.arrowFrames) do
        local key = side == "left" and "LEFT" or "RIGHT"
        local sign = key == "LEFT" and -1 or 1
        frame:SetSize(size, size)
        frame:ClearAllPoints()
        local edge, point = nil, nil
        if not plate.nameOnly then edge, point = self:SideEdge(plate, key) end
        local inner = key == "LEFT" and "RIGHT" or "LEFT"
        if edge then
            self:FollowMark(frame, inner, edge, point, sign * gapPixels, 0, function()
                -- Refused: past everything on that side at its full reach.
                local reach = 2 * px + ((plate.rowRoom or {})[key] or 0) + self:RowReach(plate, key)
                if self:AurasFirst(plate) and plate.rowSize and plate.rowSize[key] then reach = reach + 2 * px + plate.rowSize[key][1] end
                frame:SetPoint(inner, host, key, sign * (reach + gapPixels), 0)
            end)
        else frame:SetPoint(inner, host, key, sign * gapPixels, 0) end
    end
end

-- How far the stacks on the Top band reach above the spine: the tallest of
-- Top Left, Top and Top Right, each its aura row (its icons' height: the
-- height is known, only the length is secret) and its part row. The
-- soft-target icon sits past it, so it never covers them.
function M:TopStackRoom(plate)
    local style, px = self:Style(plate), plate.px or 1
    local gap, room = 2 * px, 0
    for _, key in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT" }) do
        local height = 0
        for _, group in ipairs(M.auraGroups) do
            if self:GroupShown(plate, group) and self:GroupKey(style, group) == key then
                local _, h = self:AuraSize(plate, group)
                height = math.max(height, h + math.max(0, style[group].y))
            end
        end
        if height > 0 then height = height + gap end
        local size = plate.rowSize and plate.rowSize[key]
        if size then height = height + size[2] + gap end
        room = math.max(room, height)
    end
    return room
end

-- Where a name On Border stops: the inner edge of the aura row set to Sit on
-- Border on the same line. A name on the left stops at a row on Top or Top
-- Right, one on the right at a row on Top or Top Left. The mark's own point
-- (BOTTOMRIGHT for a name on the left of a top row) sits on the row's edge
-- (AuraContainers.lua, Auras.lua); the name anchors to that same point.
function M:NameStopKey(plate, side, h)
    local wanted = h == "LEFT" and { side .. "RIGHT", side } or h == "RIGHT" and { side .. "LEFT", side } or {}
    for _, anchor in ipairs(wanted) do
        if self:HasGroups(plate, anchor .. ":border") then return anchor .. ":border" end
    end
end
function M:NameStop(plate, side, h)
    local key = self:NameStopKey(plate, side, h)
    if key then return self:Mark(plate, "nameStops", key .. "|" .. h), key end
end
-- The point of a name stop that sits on the row's inner edge, and the row's
-- point it sits on (a name on the left: the row's left edge).
function M.StopPoints(key, h)
    local v = key:find("^TOP") and "BOTTOM" or "TOP"
    if h == "LEFT" then return v .. "RIGHT", v .. "LEFT" end
    return v .. "LEFT", v .. "RIGHT"
end

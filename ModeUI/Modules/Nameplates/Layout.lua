local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Placing a plate, pixel perfect (docs/NAMEPLATES.md, "Placement"). Every
-- part has an anchor, read like a compass around the health bar, and the
-- plate is built outward from the bar:
--   1. the spine: the border line (aura groups set to Sit on Border and an On
--      Border name share one line right on the bar's edge), the cast bar
--      (below or above) with its outside texts, and one text line for a name
--      or health text placed outside on Top or Bottom;
--   2. stacks (Stacks.lua): past the spine, every anchor point holds its aura
--      row and a row of markers, indicators and combo points; with Auras
--      First the aura row is nearest the bar and the rest follows its last
--      icon; target arrows are always the outermost part on each side.
-- Text on Left, Center or Right sits inside the bar. Name Only draws just the
-- name, centered, with no bars.
local Kit, Style = addon.Kit, addon.Style

local function Horizontal(anchor) return anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or "" end
M.Horizontal = Horizontal

-- Frame levels, from the plate's own (docs/NAMEPLATES.md, "Layers"). Both
-- boxes sit one level up; each box's bar, Comet clip and rim take the next
-- three (Plate.lua LayoutBox). Text, markers, indicators and combo points go
-- on the text layer and auras on the aura layer, well above every rim, so a
-- part inside the bar never ties with a rim and drops behind it (owner,
-- November 23, 2026: parts inside the bar sometimes drew behind it). Set
-- again on every layout, so a plate the game re-levels comes back in order.
M.LAYER_TEXT, M.LAYER_AURA = 10, 12
function M.SetLayers(plate)
    local base = plate:GetFrameLevel()
    if not addon.IsNumber(base) then return end
    plate.healthBox:SetFrameLevel(base + 1)
    plate.castBox:SetFrameLevel(base + 1)
    plate.textLayer:SetFrameLevel(base + M.LAYER_TEXT)
    plate.auraLayer:SetFrameLevel(base + M.LAYER_AURA)
    for _, row in pairs(plate.stackRows or {}) do row:SetFrameLevel(base + M.LAYER_TEXT + 1) end
end

-- Whether the name sits On Border on `side` ("TOP" or "BOTTOM"; nil: either).
function M:NameOnBorder(plate, side)
    local style = self:Style(plate)
    if plate.nameOnly or not style.showName or not style.nameOnBorder then return false end
    local anchor = style.nameAnchor
    if side then return anchor:find("^" .. side) ~= nil end
    return anchor:find("^TOP") ~= nil or anchor:find("^BOTTOM") ~= nil
end

-- The border line's room on one side: the tallest group set to Sit on Border
-- there and an On Border name, plus a 2px gap; 0 when nothing sits on it.
function M:BorderRoom(plate, side)
    local style, px = self:Style(plate), plate.px or 1
    if plate.nameOnly then return 0 end
    local tallest = 0
    if style.showAuras then
        for _, group in ipairs(M.auraGroups) do
            local settings = style[group]
            if settings.show and settings.attach and settings.anchor:find("^" .. side) then
                local _, height = self:AuraSize(plate, group)
                tallest = math.max(tallest, height)
            end
        end
    end
    if self:NameOnBorder(plate, side) then tallest = math.max(tallest, math.max(px, math.floor((style.nameFontSize + 2) / px + 0.5) * px)) end
    return tallest > 0 and tallest + 2 * px or 0
end

function M:LayoutPlate(plate)
    local db, px = self:Style(plate), Kit.PixelSize(plate)
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local nameOnly = db.display == "name"
    local width, gap = Snap(db.width), 2 * px
    plate.px, plate.nameOnly = px, nameOnly
    -- Frame levels first (the boxes' bars and rims are placed relative to them).
    M.SetLayers(plate)
    local healthHeight = M.LayoutBox(plate.healthBox, width, Snap(db.healthHeight), px, db.backgroundOpacity / 100, db)
    local castHeight = M.LayoutBox(plate.castBox, width, Snap(db.castHeight), px, nil, db, db.castTexture)
    plate.castBarHeight = castHeight
    plate:SetSize(width, healthHeight)
    plate.healthBox:ClearAllPoints(); plate.healthBox:SetPoint("TOPLEFT", plate, "TOPLEFT", 0, 0)
    plate.healthBox:SetShown(not nameOnly)

    -- The border line on each side, then the cast bar below (or above) the
    -- health bar past it, then its offset. Cast texts outside the cast bar take
    -- a line on their side of it (CastBar.lua).
    local onTop, onBottom = self:BorderRoom(plate, "TOP"), self:BorderRoom(plate, "BOTTOM")
    local castAbove, cx, cy = db.castAnchor == "TOP", Round(db.castX), Round(db.castY)
    local castNear, castFar = self:CastTextRoom(plate)
    plate.castBox:ClearAllPoints()
    if castAbove then plate.castBox:SetPoint("BOTTOMLEFT", plate.healthBox, "TOPLEFT", cx, gap + onTop + castNear + cy)
    else plate.castBox:SetPoint("TOPLEFT", plate.healthBox, "BOTTOMLEFT", cx, -gap - onBottom - castNear + cy) end
    local castRoom = (not nameOnly and db.showCastBar) and castHeight + gap + castNear + castFar or 0

    local path = Kit.FontPath(db, self.id)
    plate.fontPath = path
    local nameHeight = Snap(db.nameFontSize + 2)
    local nameShown = db.showName or nameOnly
    local nameLine = nameShown and not nameOnly and not db.nameOnBorder
    local nameAbove = nameLine and db.nameAnchor:find("^TOP") ~= nil
    local nameBelow = nameLine and db.nameAnchor:find("^BOTTOM") ~= nil
    -- Room taken above and below the health bar, where the stacks start.
    -- belowNoCast: the same without the cast bar, for combo points set to
    -- Move Up While Not Casting.
    plate.above = onTop + (castAbove and castRoom or 0) + (nameAbove and nameHeight + gap or 0)
    plate.below = onBottom + (castAbove and 0 or castRoom) + (nameBelow and nameHeight + gap or 0)
    plate.belowNoCast = plate.below - (castAbove and 0 or castRoom)
    plate.borderRoom = { TOP = onTop, BOTTOM = onBottom }
    if nameOnly then
        -- The name is centered on the bar's place; room for any overhang.
        local overhang = math.max(0, Snap((nameHeight - healthHeight) / 2))
        plate.above, plate.below, plate.belowNoCast = overhang, overhang, overhang
    end

    -- Text: on the border line, outside the bar for Top and Bottom anchors,
    -- inside it otherwise.
    local function PlaceText(text, anchor, size, shown, dx, dy, border)
        local h = Horizontal(anchor)
        local justify = h == "" and "CENTER" or h
        text:ClearAllPoints()
        if border then
            self:PlaceBorderText(plate, text, anchor, Round(dx), Round(dy), width)
        elseif anchor:find("^TOP") then
            text:SetPoint("BOTTOM" .. h, plate.healthBox, "TOP" .. h, Round(dx), gap + onTop + (castAbove and castRoom or 0) + Round(dy))
            text:SetWidth(width)
        elseif anchor:find("^BOTTOM") then
            text:SetPoint("TOP" .. h, plate.healthBox, "BOTTOM" .. h, Round(dx), -gap - onBottom - (castAbove and 0 or castRoom) + Round(dy))
            text:SetWidth(width)
        else
            self:PlaceInsideText(plate, text, anchor, dx, dy)
        end
        -- Names in SemiBold, health text in Bold (Urbanist weights).
        local weighted = Style.Weighted(path, text == plate.name and "semibold" or "bold")
        Kit.Font(text, db, size, weighted, px)
        text:SetJustifyH(justify)
        Kit.LayoutLift(text, db, size, weighted, px, shown, justify)
        text:SetShown(shown)
    end
    if nameOnly then
        plate.name:ClearAllPoints()
        plate.name:SetPoint("CENTER", plate.healthBox, "CENTER", Round(db.nameX), Round(db.nameY))
        plate.name:SetWidth(width)
        local semibold = Style.Weighted(path, "semibold")
        Kit.Font(plate.name, db, db.nameFontSize, semibold, px)
        plate.name:SetJustifyH("CENTER")
        Kit.LayoutLift(plate.name, db, db.nameFontSize, semibold, px, true, "CENTER")
        plate.name:SetShown(true)
    else
        PlaceText(plate.name, db.nameAnchor, db.nameFontSize, db.showName, db.nameX, db.nameY, self:NameOnBorder(plate))
    end
    local healthShown = not nameOnly and db.healthText ~= "none"
    PlaceText(plate.healthText, db.healthTextAnchor, db.healthFontSize, healthShown, db.healthTextX, db.healthTextY)
    -- Health numbers glow (Health Text Glow); width from the format.
    local glowSide = Horizontal(db.healthTextAnchor)
    Style.TextGlow(plate.healthText, healthShown and db.healthTextGlow and { size = db.healthFontSize,
        chars = Style.GLOW_CHARS[db.healthText], justify = glowSide == "" and "CENTER" or glowSide, px = px } or nil)
    self:LayoutCast(plate)

    -- Markers, indicators and combo points are sized here and placed by the
    -- stacks (Stacks.lua), with the target arrows and the soft-target icon.
    plate.markSize = Snap(db.raidSize)
    plate.raidIcon:SetSize(plate.markSize, plate.markSize)
    self:LayoutIndicator(plate)
    self:SizeCombo(plate)
    self:LayoutTarget(plate)
    self:LayoutFocus(plate)
    plate.containerDirty = true
    for group, pool in pairs(plate.auraIcons) do
        for _, auraIcon in ipairs(pool) do self:LayoutAuraIcon(plate, auraIcon, group) end
    end
    self:PlaceStacks(plate)
end

-- Text inside the bar at Left, Center or Right, past any markers or
-- indicators inside on that side (plate.insideRoom, from the stacks).
function M:PlaceInsideText(plate, text, anchor, dx, dy)
    local px = plate.px or 1
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local h = Horizontal(anchor)
    local point = h == "" and "CENTER" or h
    local room = h ~= "" and plate.insideRoom and plate.insideRoom[h] or 0
    local x = h == "LEFT" and 2 * px + room or h == "RIGHT" and -2 * px - room or 0
    text:ClearAllPoints()
    text:SetPoint(point, plate.health, point, x + Round(dx), Round(dy))
    text:SetWidth(math.max(px, plate.healthBox:GetWidth() - 4 * px - room))
end

-- A name On Border: it rests on the bar's edge (Offset Y nudges it into the
-- rim) and, beside an aura group set to Sit on Border, stops where that row's
-- live edge is (a mark the aura code keeps on the row: Stacks.lua), so the
-- game shortens it with "…" only while auras need the room.
function M:PlaceBorderText(plate, text, anchor, dx, dy, width)
    local px = plate.px or 1
    local h = Horizontal(anchor)
    local top = anchor:find("^TOP") ~= nil
    local v = top and "BOTTOM" or "TOP"
    local side = top and "TOP" or "BOTTOM"
    text:SetPoint(v .. h, plate.healthBox, side .. h, dx, dy)
    local stop = self:NameStop(plate, side, h)
    if stop then
        -- The stop marks the row's inner edge at its own bottom (top), which sits
        -- 2px past the bar's edge: the name lines up on the bar's edge again.
        local edge = h == "RIGHT" and "LEFT" or "RIGHT"
        text:SetWidth(0)
        text:SetPoint(v .. edge, stop, v .. edge, edge == "RIGHT" and -3 * px or 3 * px, top and (dy - 2 * px) or (dy + 2 * px))
    else
        text:SetWidth(width)
    end
end

-- Room the stack rows take beside the bar on one side ("LEFT" or "RIGHT")
-- before the aura row there, with Indicators First (a 3px gap); with Auras
-- First the aura row is nearest the bar and nothing comes before it.
function M:SideRoom(plate, side)
    if self:AurasFirst(plate) then return 0 end
    return self:IndicatorRoom(plate, side)
end
function M:AurasFirst(plate) return self:Style(plate).auraOrder ~= "indicators" end

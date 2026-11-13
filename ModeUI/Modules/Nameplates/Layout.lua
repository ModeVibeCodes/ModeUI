local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Placing every element of a plate by its anchor and offset, pixel perfect.
-- Anchors read like a compass around the health bar:
--   Top Left / Top / Top Right       above the bar (above the cast bar when it's on top)
--   Left / Center / Right            text: inside the bar; the raid marker: beside it
--   Bottom Left / Bottom / Bottom Right  below the bar (below the cast bar when it's below)
-- Name Only draws just the name, centered, with no bars.
local Kit = addon.Kit

local function Horizontal(anchor) return anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or "" end

function M:LayoutPlate(plate)
    local db, px = self:Style(plate), Kit.PixelSize(plate)
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local nameOnly = db.display == "name"
    local width, gap = Snap(db.width), 2 * px
    local healthHeight = M.LayoutBox(plate.healthBox, width, Snap(db.healthHeight), px, db.backgroundOpacity / 100, db)
    local castHeight = M.LayoutBox(plate.castBox, width, Snap(db.castHeight), px, nil, db)
    plate.castBarHeight, plate.px, plate.nameOnly = castHeight, px, nameOnly
    plate:SetSize(width, healthHeight)
    plate.healthBox:ClearAllPoints(); plate.healthBox:SetPoint("TOPLEFT", plate, "TOPLEFT", 0, 0)
    plate.healthBox:SetShown(not nameOnly)
    plate.textLayer:SetFrameLevel(plate.healthBox:GetFrameLevel() + 3)
    plate.auraLayer:SetFrameLevel(plate.healthBox:GetFrameLevel() + 4)

    -- The cast bar sits below (or above) the health bar, then its offset.
    local castAbove, cx, cy = db.castAnchor == "TOP", Round(db.castX), Round(db.castY)
    plate.castBox:ClearAllPoints()
    if castAbove then plate.castBox:SetPoint("BOTTOMLEFT", plate.healthBox, "TOPLEFT", cx, gap + cy)
    else plate.castBox:SetPoint("TOPLEFT", plate.healthBox, "BOTTOMLEFT", cx, -gap + cy) end
    local castRoom = (not nameOnly and db.showCastBar) and castHeight + gap + self:CastTargetHeight(plate) or 0

    local path = Kit.FontPath(db, self.id)
    plate.fontPath = path
    local nameHeight = Snap(db.nameFontSize + 2)
    local nameShown = db.showName or nameOnly
    local nameAbove = nameShown and not nameOnly and db.nameAnchor:find("^TOP") ~= nil
    local nameBelow = nameShown and not nameOnly and db.nameAnchor:find("^BOTTOM") ~= nil
    -- Room taken above and below the health bar, for markers and auras.
    plate.above = (castAbove and castRoom or 0) + (nameAbove and nameHeight + gap or 0)
    plate.below = (castAbove and 0 or castRoom) + (nameBelow and nameHeight + gap or 0)
    if nameOnly then
        -- The name is centered on the bar's place; room for any overhang.
        local overhang = math.max(0, Snap((nameHeight - healthHeight) / 2))
        plate.above, plate.below = overhang, overhang
    end

    -- Text: outside the bar for Top and Bottom anchors, inside it otherwise.
    local function PlaceText(text, anchor, size, shown, dx, dy)
        local h = Horizontal(anchor)
        local justify = h == "" and "CENTER" or h
        text:ClearAllPoints()
        if anchor:find("^TOP") then
            text:SetPoint("BOTTOM" .. h, plate.healthBox, "TOP" .. h, Round(dx), gap + (castAbove and castRoom or 0) + Round(dy))
            text:SetWidth(width)
        elseif anchor:find("^BOTTOM") then
            text:SetPoint("TOP" .. h, plate.healthBox, "BOTTOM" .. h, Round(dx), -gap - (castAbove and 0 or castRoom) + Round(dy))
            text:SetWidth(width)
        else
            local point = h == "" and "CENTER" or h
            local x = h == "LEFT" and 2 * px or h == "RIGHT" and -2 * px or 0
            text:SetPoint(point, plate.health, point, x + Round(dx), Round(dy))
            text:SetWidth(math.max(px, width - 4 * px))
        end
        Kit.Font(text, db, size, path, px)
        text:SetJustifyH(justify)
        Kit.LayoutLift(text, db, size, path, px, shown, justify)
        text:SetShown(shown)
    end
    if nameOnly then
        plate.name:ClearAllPoints()
        plate.name:SetPoint("CENTER", plate.healthBox, "CENTER", Round(db.nameX), Round(db.nameY))
        plate.name:SetWidth(width)
        Kit.Font(plate.name, db, db.nameFontSize, path, px)
        plate.name:SetJustifyH("CENTER")
        Kit.LayoutLift(plate.name, db, db.nameFontSize, path, px, true, "CENTER")
        plate.name:SetShown(true)
    else
        PlaceText(plate.name, db.nameAnchor, db.nameFontSize, db.showName, db.nameX, db.nameY)
    end
    PlaceText(plate.healthText, db.healthTextAnchor, db.healthFontSize, not nameOnly and db.healthText ~= "none", db.healthTextX, db.healthTextY)
    self:LayoutCast(plate)

    -- The raid marker: around the bar, or in its middle.
    plate.markSize = Snap(db.raidSize)
    self:PlaceIcon(plate, plate.raidIcon, db.raidAnchor, plate.markSize, plate.markSize, db.raidX, db.raidY)
    self:LayoutIndicator(plate)

    self:LayoutTarget(plate)
    for group, pool in pairs(plate.auraIcons) do
        for _, auraIcon in ipairs(pool) do self:LayoutAuraIcon(plate, auraIcon, group) end
    end
end

-- Room taken beside the bar on one side ("LEFT" or "RIGHT") by the raid
-- marker and the indicator, each with a 3px gap. Aura rows start past it and
-- the target arrows past the aura rows (Auras.lua, Target.lua).
function M:SideRoom(plate, side)
    local db, px = self:Style(plate), plate.px or 1
    local room = (db.showRaidIcon and db.raidAnchor == side) and (plate.markSize or 0) + 3 * px or 0
    return room + self:IndicatorRoom(plate, side)
end

-- Places an icon-like region (raid marker) by anchor: Top and Bottom anchors
-- sit past whatever is above or below the bar, Left and Right beside the bar,
-- Center in its middle.
function M:PlaceIcon(plate, region, anchor, w, h, dx, dy)
    local px = plate.px or 1
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local gap, side = 2 * px, Horizontal(anchor)
    region:ClearAllPoints()
    region:SetSize(w, h)
    if anchor:find("^TOP") then
        region:SetPoint("BOTTOM" .. side, plate.healthBox, "TOP" .. side, Round(dx), gap + plate.above + Round(dy))
    elseif anchor:find("^BOTTOM") then
        region:SetPoint("TOP" .. side, plate.healthBox, "BOTTOM" .. side, Round(dx), -gap - plate.below + Round(dy))
    elseif anchor == "LEFT" then
        region:SetPoint("RIGHT", plate.healthBox, "LEFT", -3 * px + Round(dx), Round(dy))
    elseif anchor == "RIGHT" then
        region:SetPoint("LEFT", plate.healthBox, "RIGHT", 3 * px + Round(dx), Round(dy))
    else
        region:SetPoint("CENTER", plate.healthBox, "CENTER", Round(dx), Round(dy))
    end
end

local _, addon = ...
local M = addon.Tooltip
if not M then return end

-- One tooltip in the Mode look:
--   Frame   Blizzard's NineSlice (border and background) faded: its style
--           function re-applies atlases and colors, never alpha, so it stays
--           gone. Azerite/corrupted overlays faded. Rounded (default): a
--           rounded box (ModeRound) in Background Color at Background
--           Opacity, and over it a hollow rounded rim Border Size thick
--           (ModeRing1-4), so the see-through fill never takes the rim's
--           color; the rim sits on its own frame above the lines. Square: a
--           flat fill and a crisp square border. Mode Gradient lays a soft
--           white wash over the top of the fill, as on every Mode bar.
--   Border  the item's quality color (Quality Border), a player's class
--           color (Class Border), else Border Color (Colors.lua).
--   Text    every line in the Mode face, the first at Header Size, the rest
--           at Text Size. Lines can hold secret text; only their font and
--           color are set.
--   Size    Minimum Width and Padding (Blizzard resets both as it restyles a
--           tooltip, so they're set again each time it fills).
--   Screen  kept on the screen, border and all (the border is inside it).
--   Health  Blizzard's bar under unit tooltips is hidden for good.
local Kit, Skin = addon.Kit, addon.Skin
local MAX_LINES = 60

-- The tooltip's pieces: a fill and wash on the tooltip, the rim on a frame above.
local function Parts(tooltip)
    local parts = Skin.parts[tooltip]
    if parts and parts.round then return parts end
    parts = Skin.Panel(tooltip, "BACKGROUND", -8)
    parts.round = tooltip:CreateTexture(nil, "BACKGROUND", nil, -8)
    parts.wash = tooltip:CreateTexture(nil, "BACKGROUND", nil, -6)
    parts.wash:SetTexture(Kit.FLAT)
    parts.regions[parts.round], parts.regions[parts.wash] = true, true
    Skin.Edge(tooltip, 2)
    parts.ring = parts.edge:CreateTexture(nil, "OVERLAY", nil, 7)
    return parts
end

function M:Skin(tooltip)
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if tooltip.NineSlice then tooltip.NineSlice:SetAlpha(0) end
    Skin.Fade(tooltip.TopOverlay); Skin.Fade(tooltip.BottomOverlay)
    local parts = Parts(tooltip)
    parts.px = Kit.PixelSize(tooltip)
    if tooltip.SetClampedToScreen then
        tooltip:SetClampedToScreen(true)
        if tooltip.SetClampRectInsets then tooltip:SetClampRectInsets(0, 0, 0, 0) end
    end
    self:Paint(tooltip)
    if tooltip.StatusBar then Skin.Suppress(tooltip.StatusBar) end
end

-- Fill, wash, rim (with the color for what it shows) and scale.
function M:Paint(tooltip, borderColor)
    local parts = Skin.parts[tooltip]
    if not parts or not parts.round then return end
    local db, px = self.db, parts.px or 1
    local alpha = db.backgroundOpacity / 100
    local thickness = db.border and math.max(1, math.min(4, db.borderSize)) or 0
    local rim = thickness > 0 and Skin.Snap(thickness, px) or 0
    local color = borderColor or db.borderColor
    if db.rounded then
        -- The rounded box under, the hollow ring over.
        Kit.Rounded(parts.round, "ModeRound")
        parts.round:ClearAllPoints(); parts.round:SetAllPoints(tooltip)
        Kit.Tint(parts.round, db.backgroundColor, alpha)
        parts.round:Show()
        Kit.Rounded(parts.ring, "ModeRing" .. math.max(1, thickness))
        parts.ring:ClearAllPoints(); parts.ring:SetAllPoints(tooltip)
        Kit.Tint(parts.ring, color, 1)
        parts.ring:SetShown(thickness > 0)
        Skin.PaintPanel(parts, tooltip, db.backgroundColor, 0, color, 0)
        Skin.PaintEdge(parts, 0, color, 1)
        parts.edge:Show()
    else
        parts.round:Hide(); parts.ring:Hide()
        Skin.PaintPanel(parts, tooltip, db.backgroundColor, alpha, color, 0)
        Skin.PaintEdge(parts, rim, color, 1)
    end
    -- Mode Gradient: a soft white wash over the top, inside the rim (and
    -- clear of the rounded corners).
    local wash = parts.wash
    local side = rim + (db.rounded and Skin.Snap(2, px) or 0)
    wash:ClearAllPoints()
    wash:SetPoint("TOPLEFT", tooltip, "TOPLEFT", side, -rim)
    wash:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -side, -rim)
    wash:SetHeight(Skin.Snap(14, px))
    Kit.Gradient(wash, { 1, 1, 1, 0.08 * alpha }, { 1, 1, 1, 0 }, 0.04 * alpha)
    wash:SetShown(db.gradient)
    if tooltip.SetScale and tooltip == GameTooltip and (db.scale ~= 100 or self.scaled) then
        self.scaled = true
        tooltip:SetScale(db.scale / 100)
    end
end

-- Minimum Width and Padding, set every time (Blizzard resets them).
function M:ApplySize(tooltip)
    local db = self.db
    if tooltip.SetMinimumWidth then tooltip:SetMinimumWidth(db.minWidth) end
    if tooltip.SetPadding then tooltip:SetPadding(db.padding, db.padding, db.padding, db.padding) end
end

-- The lines in the Mode face. Answers whether any line changed (the tooltip
-- is then sized again).
function M:ApplyFonts(tooltip)
    local db, px = self.db, Kit.PixelSize(tooltip)
    local path = Kit.FontPath(db, self.id)
    local flags = db.outline and "OUTLINE" or ""
    local changed = false
    for index, pair in ipairs(self:Lines(tooltip)) do
        local size = index == 1 and db.headerSize or db.textSize
        for _, line in ipairs({ pair.left, pair.right }) do
            if line and line.GetFont then
                local current, height, currentFlags = line:GetFont()
                if current ~= path or height ~= size or currentFlags ~= flags then
                    Skin.Font(line, path, size, db.outline, db.shadow, px)
                    changed = true
                end
            end
        end
    end
    return changed
end

-- The tooltip's text lines, left and right, in order.
function M:Lines(tooltip)
    local name = tooltip.GetName and tooltip:GetName()
    local list = {}
    if not name then return list end
    for index = 1, MAX_LINES do
        local left = _G[name .. "TextLeft" .. index]
        if not left then break end
        list[#list + 1] = { left = left, right = _G[name .. "TextRight" .. index] }
    end
    return list
end

local _, addon = ...
local M = addon.Tooltip
if not M then return end

-- One tooltip in the Mode design language (docs/DESIGN_LANGUAGE.md,
-- "Windows and panels"):
--   Frame   Blizzard's NineSlice (border and background) faded: its style
--           function re-applies atlases and colors, never alpha, so it stays
--           gone. Azerite/corrupted overlays faded. A Mode window: Mode Panel
--           in Background Color at Background Opacity, the `window` edge
--           inside the tooltip on its own frame above the lines (Border off
--           hides it). No soft drop under a see-through tooltip.
--   Border  the edge's rim in the item's quality color (Quality Border) or a
--           player's class color (Class Border), else the edge's own metal
--           (Colors.lua), in the Border Style and Border Metal.
--   Text    every line in the Mode face, the first at Header Size in
--           SemiBold, the rest at Text Size. Lines can hold secret text;
--           only their font and color are set.
--   Size    Minimum Width and Padding (Blizzard resets both as it restyles a
--           tooltip, so they're set again each time it fills).
--   Screen  kept on the screen, edge and all (the edge is inside it).
--   Health  Blizzard's bar under unit tooltips is hidden for good.
local Kit, Skin, Style = addon.Kit, addon.Skin, addon.Style
local MAX_LINES = 60
local REACH = Style.EdgeReach("window")

-- The tooltip's face and edge.
local function Parts(tooltip)
    local parts = Skin.parts[tooltip]
    if parts and parts.modeEdge then return parts end
    return Skin.Box(tooltip, "window", { inset = REACH, level = 2 })
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

-- Face, edge (its rim in `rimColor`, what the tooltip shows; the steel
-- without one) and scale.
function M:Paint(tooltip, rimColor)
    local parts = Skin.parts[tooltip]
    if not parts or not parts.modeEdge then return end
    local db = self.db
    local alpha = db.backgroundOpacity / 100
    Skin.PaintBox(parts, tooltip, "Panel", db.backgroundColor, alpha, db.border)
    parts.modeEdge:SetDrop(db.border and alpha >= 1)
    -- Border Style and Border Metal; a quality or class rim tints it flat.
    parts.modeEdge:SetStyle(db.edgeStyle, db.edgeMetal)
    parts.modeEdge:SetTint(db.border and rimColor or nil)
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

-- The lines in the Mode face, the first in SemiBold. Answers whether any
-- line changed (the tooltip is then sized again).
function M:ApplyFonts(tooltip)
    local db, px = self.db, Kit.PixelSize(tooltip)
    local body = Kit.FontPath(db, self.id)
    local header = Style.Weighted(body, "semibold")
    local flags = db.outline and "OUTLINE" or ""
    local changed = false
    for index, pair in ipairs(self:Lines(tooltip)) do
        local size, path = index == 1 and db.headerSize or db.textSize, index == 1 and header or body
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

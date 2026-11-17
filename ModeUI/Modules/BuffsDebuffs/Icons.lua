local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- One icon in its bar's look: a Kit.AuraIconParts frame (the container's
-- buttons carry one on a child; Edit Mode and the preview use Kit.AuraIcon)
-- sized Width x Height, in the bar's Border Style, Metal and Size, the art
-- a Border Gap inside the band and cropped by Icon Zoom, with the bar's
-- time text and stack count (each its own size, color, place and offset).
local Kit, Style = addon.Kit, addon.Style

function M.TypeColor(name)
    if name == "none" then return Style.Tone.metal.gunmetal.mid end
    return Style.Tone.debuffType[name] or Style.Tone.metal.gunmetal.mid
end
local function Metal(bar) return bar.edgeMetal ~= "default" and bar.edgeMetal or nil end

-- A style for Kit.Font: the module's font, outline and shadow, in `color`.
function M:TextStyle(bar, color)
    local db = self.db
    return setmetatable({ auraTimerText = bar.timer == "center", auraBorderSize = bar.borderSize,
        auraTimerColor = bar.timerColor, textColor = color or db.textColor, outline = db.outline }, { __index = db })
end
function M:FontPath() return Kit.FontPath(self.db, self.id) end

-- Where the icon sits in its cell: under its time text when that's above.
function M:IconPoint(bar) return bar.timer == "above" and "BOTTOM" or "TOP" end

-- The art, cropped by size rather than texture coordinates (the game sets
-- each aura's texture itself, so coordinates set here may not last): a
-- square `crop`% wider than the visible part on each side, centered in a
-- frame that clips it, a Border Gap inside the band.
local function LayoutArt(icon, bar, px, width, height)
    if not icon.clip then
        icon.clip = CreateFrame("Frame", nil, icon)
        icon.clip:SetClipsChildren(true)
        icon.art = icon.clip:CreateTexture(nil, "ARTWORK")
        icon.icon:Hide()
    end
    local inset = (icon.edge.rim + bar.borderGap) * px
    icon.clip:ClearAllPoints()
    icon.clip:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)
    icon.clip:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)
    local visible = math.max(width, height) - 2 * inset
    local side = math.max(px, visible / (1 - 2 * bar.crop / 100))
    icon.art:ClearAllPoints()
    icon.art:SetPoint("CENTER", icon.clip, "CENTER", 0, 0)
    icon.art:SetSize(side, side)
    icon.art:SetTexCoord(0, 1, 0, 1)
    icon.cooldown:ClearAllPoints(); icon.cooldown:SetAllPoints(icon.clip)
    -- Layers, bottom up: the icon frame's black back, the art, the swipe
    -- and GCD flash, the border, the texts. The art's frame must sit above
    -- the icon frame: at the same level the back drew over it (owner's
    -- in-game report, November 17, 2026: every icon black).
    local level = icon:GetFrameLevel()
    icon.clip:SetFrameLevel(level + 1)
    icon.cooldown:SetFrameLevel(level + 2)
    icon.flashLayer:SetFrameLevel(level + 2)
    icon.edge.holder:SetFrameLevel(level + 3)
    icon.textLayer:SetFrameLevel(level + 4)
end

-- Stacks in their corner and the time text on the icon, in the bar's sizes,
-- colors and offsets (1px in from the sides they're on).
local function LayoutTexts(self, icon, bar, px, path)
    local bold = Style.Weighted(path, "bold")
    local point = bar.countPoint
    Kit.Font(icon.count, self:TextStyle(bar, bar.countColor), bar.countSize, bold, px)
    local x = (point:find("LEFT") and 1) or (point:find("RIGHT") and -1) or 0
    local y = (point:find("TOP") and -1) or (point:find("BOTTOM") and 1) or 0
    icon.count:ClearAllPoints()
    icon.count:SetPoint(point, icon, point, (x + bar.countX) * px, (y + bar.countY) * px)
    icon.count:SetJustifyH(point:find("LEFT") and "LEFT" or point:find("RIGHT") and "RIGHT" or "CENTER")
    icon.count:SetShown(bar.count)
    Kit.Font(icon.timer, self:TextStyle(bar, bar.timerColor), bar.timerSize, bold, px)
    icon.timer:ClearAllPoints()
    icon.timer:SetPoint("CENTER", icon, "CENTER", bar.timerX * px, bar.timerY * px)
    icon.timer:SetJustifyH("CENTER")
    icon.timer:SetShown(bar.timer == "center")
    icon.count.lift:Hide(); icon.timer.lift:Hide()
end

-- Lays one icon out in the bar's look. Returns its width, height and font.
function M:LayoutIcon(icon, bar, px)
    local width, height = self:IconSize(bar, px)
    local path = self:FontPath()
    Kit.LayoutAuraIcon(icon, width, height, px, self:TextStyle(bar), path)
    Kit.AuraBorderStyle(icon, bar.edgeStyle, Metal(bar))
    LayoutArt(icon, bar, px, width, height)
    icon.cooldown:SetShown(bar.swipe)
    LayoutTexts(self, icon, bar, px, path)
    return width, height, path
end

-- Time text under or over the icon, centered, with the bar's offsets.
function M:LayoutOutside(text, bar, px, path, icon)
    Kit.Font(text, self:TextStyle(bar, bar.timerColor), bar.timerSize, Style.Weighted(path, "bold"), px)
    local gap = self.TEXT_GAP * px
    text:ClearAllPoints()
    if bar.timer == "above" then text:SetPoint("BOTTOM", icon, "TOP", bar.timerX * px, gap + bar.timerY * px)
    else text:SetPoint("TOP", icon, "BOTTOM", bar.timerX * px, -gap + bar.timerY * px) end
    text:SetJustifyH("CENTER")
    text:SetShown(bar.timer == "below" or bar.timer == "above")
end

local function Hex(c) return string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3]) end
-- What only changes where icons go, not how they look (set in place).
local LIVE = { show = true, cats = true, sort = true, max = true, perRow = true, grow = true, wrap = true, spacing = true }
-- Everything a bar's buttons bake in when they're made.
function M:LookKey(id, px)
    local bar, db = self.db.bars[id], self.db
    local keys = {}
    for key in pairs(bar) do if not LIVE[key] then keys[#keys + 1] = key end end
    table.sort(keys)
    local parts = { tostring(bar.cats.enchant), px, db.fontMedia, db.font, tostring(db.outline), tostring(db.shadow) }
    for _, key in ipairs(keys) do
        local value = bar[key]
        parts[#parts + 1] = key .. "=" .. (type(value) == "table" and Hex(value) or tostring(value))
    end
    return table.concat(parts, "|")
end

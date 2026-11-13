local _, addon = ...
local M = addon.Tooltip
if not M then return end

-- One tooltip in the Mode look:
--   Frame   Blizzard's NineSlice (border and background) faded: its style
--           function re-applies atlases and colors, never alpha, so it stays
--           gone. Azerite/corrupted overlays faded. A fill (Background Color
--           at Background Opacity) and a crisp square border, Border Size
--           thick, on its own frame above the lines.
--   Border  the item's quality color (Quality Border), a player's class
--           color (Class Border), else Border Color. Unit names and tokens
--           can be secret: a secret unit simply keeps Border Color.
--   Text    every line in the Mode face, the first at Header Size, the rest
--           at Text Size. Lines can hold secret text; only their font is set,
--           nothing is read or measured.
--   Health  Blizzard's bar under unit tooltips (its value is secret and
--           Blizzard's own): flat, Health Color, a soft sheen, a dark track
--           and the border, Health Height tall, hanging under the tooltip.
local Kit, Skin = addon.Kit, addon.Skin
local Public, Number = addon.IsPublic, addon.IsNumber
local MAX_LINES = 60

-- fn(...) under pcall, all its returns kept (nils between them too; Lua 5.1).
local function Pack(...) return { n = select("#", ...), ... } end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = Pack(pcall(fn, ...))
    if not results[1] then return nil end
    return unpack(results, 2, results.n)
end

function M:Skin(tooltip)
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if tooltip.NineSlice then tooltip.NineSlice:SetAlpha(0) end
    Skin.Fade(tooltip.TopOverlay); Skin.Fade(tooltip.BottomOverlay)
    local parts = Skin.Panel(tooltip, "BACKGROUND", -8)
    Skin.Edge(tooltip, 2)
    parts.px = Kit.PixelSize(tooltip)
    self:Paint(tooltip)
    self:SkinHealth(tooltip)
end

-- Fill, border (with the color for what it shows) and scale.
function M:Paint(tooltip, borderColor)
    local parts = Skin.parts[tooltip]
    if not parts or not parts.fill then return end
    local db, px = self.db, parts.px or 1
    Skin.PaintPanel(parts, tooltip, db.backgroundColor, db.backgroundOpacity / 100, db.borderColor, 0)
    Skin.PaintEdge(parts, db.border and Skin.Snap(db.borderSize, px) or 0, borderColor or db.borderColor, 1)
    if tooltip.SetScale and tooltip == GameTooltip and (db.scale ~= 100 or self.scaled) then
        self.scaled = true
        tooltip:SetScale(db.scale / 100)
    end
end

-- The border color for what the tooltip shows, or nil for Border Color.
function M:ContentColor(tooltip)
    local db = self.db
    if db.qualityBorder and tooltip.GetItem then
        local _, link, id = Call(tooltip.GetItem, tooltip)
        local quality
        if Number(id) then quality = Call(C_Item and C_Item.GetItemQualityByID, id) end
        if not Number(quality) and Public(link) and type(link) == "string" then
            quality = select(3, Call(C_Item and C_Item.GetItemInfo or GetItemInfo, link))
        end
        if Number(quality, 1, 20) then
            local r, g, b = Call(C_Item and C_Item.GetItemQualityColor, quality)
            if Number(r) and Number(g) and Number(b) then return { r, g, b } end
        end
    end
    if db.classBorder and tooltip.GetUnit then
        local _, unit = Call(tooltip.GetUnit, tooltip)
        if unit ~= nil and Public(unit) and type(unit) == "string" and Call(UnitIsPlayer, unit) == true then
            local _, class = Call(UnitClass, unit)
            if Public(class) and type(class) == "string" then
                local color = (C_ClassColor and Call(C_ClassColor.GetClassColor, class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
                if color and Number(color.r) then return { color.r, color.g, color.b } end
            end
        end
    end
    return nil
end

-- The lines in the Mode face. Answers whether any line changed (the tooltip
-- is then sized again).
function M:ApplyFonts(tooltip)
    local name = tooltip.GetName and tooltip:GetName()
    if not name then return false end
    local db, px = self.db, Kit.PixelSize(tooltip)
    local path = Kit.FontPath(db, self.id)
    local flags = db.outline and "OUTLINE" or ""
    local changed = false
    for index = 1, MAX_LINES do
        local left = _G[name .. "TextLeft" .. index]
        if not left then break end
        local size = index == 1 and db.headerSize or db.textSize
        for _, line in ipairs({ left, _G[name .. "TextRight" .. index] }) do
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

-- The health bar: Blizzard's StatusBar, restyled; Blizzard sets its value.
function M:SkinHealth(tooltip)
    local bar = tooltip.StatusBar
    if not bar or not bar.SetStatusBarTexture then return end
    local db = self.db
    local parts = Skin.parts[bar] or { regions = {} }
    Skin.parts[bar] = parts
    if not parts.track then
        parts.track = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        parts.track:SetTexture(Kit.FLAT); parts.track:SetAllPoints(bar)
        parts.sheen = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        parts.sheen:SetTexture(Kit.FLAT)
        parts.regions[parts.track], parts.regions[parts.sheen] = true, true
        -- Blizzard colors the bar green on every value change; ours follows.
        bar:HookScript("OnValueChanged", function(self) if M.active then M:ColorHealth(self) end end)
    end
    Skin.Edge(bar, 2)
    local px = Kit.PixelSize(bar)
    local rim = db.border and Skin.Snap(math.min(db.borderSize, 2), px) or 0
    local height = Skin.Snap(db.healthHeight, px)
    bar:SetStatusBarTexture(Kit.FLAT)
    bar:ClearAllPoints()
    -- Under the tooltip, sharing its border line.
    bar:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", rim, rim > 0 and 0 or -px)
    bar:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", -rim, rim > 0 and 0 or -px)
    bar:SetHeight(height)
    Kit.Tint(parts.track, Kit.onyx.track, 0.9)
    parts.sheen:ClearAllPoints()
    parts.sheen:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0); parts.sheen:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    parts.sheen:SetHeight(math.max(px, Skin.Snap(height / 2, px)))
    Kit.Gradient(parts.sheen, { 1, 1, 1, 0.12 }, { 1, 1, 1, 0 }, 0.06)
    parts.edge:ClearAllPoints()
    -- Its top edge lies on the tooltip's bottom border: one line, not two.
    parts.edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -rim, rim)
    parts.edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", rim, -rim)
    Skin.PaintEdge(parts, rim, db.borderColor, 1)
    if db.healthBar then Skin.Release(bar) else Skin.Suppress(bar) end
    self:ColorHealth(bar)
end

function M:ColorHealth(bar)
    local c = self.db.healthColor
    bar:SetStatusBarColor(c[1], c[2], c[3], 1)
end

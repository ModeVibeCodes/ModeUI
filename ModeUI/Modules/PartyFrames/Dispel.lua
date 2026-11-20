local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- What a debuff does to the member that has it, by dispel type (Highlights
-- tab): Border (the member's rim in the type's color), Health Color (the
-- health fill in the type's color) and Gradient (docs/DESIGN_LANGUAGE.md: the
-- color from the top edge at Gradient Opacity, 56% by default, fading out over
-- 72% of the health), each on or off per type. Gradient is the default.
--
-- In the world each type is one aura slot (AddAuraSlot) on a container, kept
-- to that type by the game (candidateFilters.includeDispelTypes) and to the
-- Which Debuffs filter. The slot's one button covers the member and holds that
-- type's effects in its color; the game shows the button only while the
-- member has such a debuff, so this works while auras are secret. Samples and
-- clients without containers paint the same effects from a public type.
local Kit, Style = addon.Kit, addon.Style
local TEMPLATE = Kit.AURA_CONTAINER_TEMPLATE
-- The Gradient covers this share of the health bar, from its top edge.
M.DISPEL_GRADIENT_REACH = 0.72

-- Lays the health overlay and the gradient of an effect set.
local function LayoutEffects(self, f, set, color)
    local db = self.db
    set.health:ClearAllPoints(); set.health:SetAllPoints(f.health:GetStatusBarTexture())
    -- From the top edge, or rising from the bottom (Backlit, Mode-Obsidian).
    local side = db.dispelFrom == "bottom" and "BOTTOM" or "TOP"
    set.gradient:ClearAllPoints()
    set.gradient:SetPoint(side .. "LEFT", f.health, side .. "LEFT", 0, 0); set.gradient:SetPoint(side .. "RIGHT", f.health, side .. "RIGHT", 0, 0)
    set.gradient:SetHeight(math.max(f.geometry.px, f.health:GetHeight() * M.DISPEL_GRADIENT_REACH))
    if color then
        Kit.Tint(set.health, color, 1)
        local strong, clear = { color[1], color[2], color[3], db.dispelGradientOpacity / 100 }, { color[1], color[2], color[3], 0 }
        if side == "BOTTOM" then Kit.Gradient(set.gradient, clear, strong) else Kit.Gradient(set.gradient, strong, clear) end
    end
end

function M:LayoutDispel(f)
    LayoutEffects(self, f, f.dispel)
    self:PaintDispel(f, f.dispelSample)
end

-- Samples and the reader: the effects of one public dispel type, or none.
function M:PaintDispel(f, dispelType)
    f.dispelSample = dispelType
    local effects = dispelType and self.db.dispel[dispelType]
    local color = effects and self.db[self.dispelColorKeys[dispelType]]
    if color then LayoutEffects(self, f, f.dispel, color) end
    f.dispelRim = effects and effects.border and color or nil
    self:PaintRim(f)
    f.dispel.health:SetShown(effects and effects.health or false)
    f.dispel.gradient:SetShown(effects and effects.gradient or false)
end

-- Everything the slots' buttons bake in when they're made.
local function SlotKey(self, f)
    local db, g = self.db, f.geometry
    local parts = { db.dispelFilter, g.width, g.height, g.px, g.healthHeight, db.dispelGradientOpacity, db.edgeStyle, db.edgeMetal,
        db.dispelFrom }
    for _, kind in ipairs(self.dispelTypes) do
        local e, c = db.dispel[kind], db[self.dispelColorKeys[kind]]
        parts[#parts + 1] = string.format("%s%s%s%.3f,%.3f,%.3f", tostring(e.border), tostring(e.health), tostring(e.gradient), c[1], c[2], c[3])
    end
    return table.concat(parts, "|")
end

local function SlotInitializer(self, f, kind)
    local color = self.db[self.dispelColorKeys[kind]]
    local effects = self.db.dispel[kind]
    return function(button)
        button:ClearAllPoints(); button:SetAllPoints(f.panel)
        button:SetFrameLevel(f.glowLayer:GetFrameLevel() + 1)
        if button.EnableMouse then pcall(button.EnableMouse, button, false) end
        local set = { health = button:CreateTexture(nil, "ARTWORK", nil, 1), gradient = button:CreateTexture(nil, "ARTWORK", nil, 2) }
        Style.ApplyAsset(set.health, "Solid"); Style.ApplyAsset(set.gradient, "Solid")
        -- Border: a flat rim in the type's color over the member's own,
        -- on the same band (the button covers the member), in its Border Style.
        set.inner = CreateFrame("Frame", nil, button)
        local b = f.geometry.border
        set.inner:SetPoint("TOPLEFT", f.panel, "TOPLEFT", b, -b); set.inner:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", -b, b)
        set.rim = Style.Edge(set.inner, "group", { level = 3, style = self.db.edgeStyle, pieces = true })
        set.rim:SetStyle(self.db.edgeStyle, self.db.edgeMetal)
        set.rim:SetTint(color)
        set.rim:SetShown(effects.border)
        LayoutEffects(self, f, set, color)
        set.health:SetShown(effects.health); set.gradient:SetShown(effects.gradient)
        button.dispelEffects, button.dispelType = set, kind
    end
end

local function AnyEffect(effects) return effects.border or effects.health or effects.gradient end

-- Makes (or keeps) the member's slot container and points it at the unit.
-- `check`: settings may have changed, so the look is compared; `reread`: read
-- the auras again (the same unit is someone else now).
function M:AttachDispel(f, unit, check, reread)
    local current = f.dispelContainer
    local key = (check or not current) and SlotKey(self, f) or current.lookKey
    if not (current and current.lookKey == key) then
        reread = true
        if current then current:SetEnabled(false); current:Hide(); f.dispelContainer = nil end
        local filter = self:GroupFilters("dispel", self.db.dispelFilter)[1]
        local ok, container = pcall(function()
            local made = CreateFrame("AuraContainer", nil, f.glowLayer, TEMPLATE)
            made:SetSize(1, 1); made:SetPoint("CENTER", f.panel, "CENTER", 0, 0)
            for _, kind in ipairs(self.dispelTypes) do
                if AnyEffect(self.db.dispel[kind]) then
                    made:AddAuraSlot(kind, filter, { initializeFrame = SlotInitializer(self, f, kind),
                        candidateFilters = { includeDispelTypes = { [kind] = true } } })
                end
            end
            return made
        end)
        if not ok then return end
        container.lookKey = key
        f.dispelContainer = container
        current = container
    end
    if unit then
        current:SetEnabled(true); current:SetUnit(unit); current:Show()
        if reread then current:UpdateAllAuras() end
    else current:SetEnabled(false); current:Hide() end
end

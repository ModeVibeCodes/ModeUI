local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- What a debuff does to the member that has it, by dispel type (Highlights
-- tab): Border (the member's border in the type's color), Health Color (the
-- health fill in the type's color) and Gradient (the color fading down over
-- the health bar), each on or off per type.
--
-- In the world each type is one aura slot (AddAuraSlot) on a container, kept
-- to that type by the game (candidateFilters.includeDispelTypes) and to the
-- Which Debuffs filter. The slot's one button covers the member and holds that
-- type's effects in its color; the game shows the button only while the
-- member has such a debuff, so this works while auras are secret. Samples and
-- clients without containers paint the same effects from a public type.
local Kit = addon.Kit
local TEMPLATE = Kit.AURA_CONTAINER_TEMPLATE

-- Lays an effect set (ring, health overlay, gradient) on `host`.
local function LayoutEffects(self, f, set, host, color)
    local g, db = f.geometry, self.db
    Kit.LayoutModeBoxBorder(set.ring, host, { px = g.px, radius = g.radius, thickness = g.thickness, color = color or Kit.BORDER_COLOR,
        level = host:GetFrameLevel() + 2 })
    set.health:ClearAllPoints(); set.health:SetAllPoints(f.health:GetStatusBarTexture())
    set.gradient:ClearAllPoints(); set.gradient:SetAllPoints(f.health)
    if color then
        Kit.Tint(set.health, color, 1)
        Kit.Gradient(set.gradient, { color[1], color[2], color[3], db.dispelGradientOpacity / 100 }, { color[1], color[2], color[3], 0 })
    end
end

function M:LayoutDispel(f)
    LayoutEffects(self, f, f.dispel, f.glowLayer)
    self:PaintDispel(f, f.dispelSample)
end

-- Samples and the reader: the effects of one public dispel type, or none.
function M:PaintDispel(f, dispelType)
    f.dispelSample = dispelType
    local effects = dispelType and self.db.dispel[dispelType]
    local color = effects and self.db[self.dispelColorKeys[dispelType]]
    if color then LayoutEffects(self, f, f.dispel, f.glowLayer, color) end
    self.ShowBorder(f.dispel.ring, effects and effects.border)
    f.dispel.health:SetShown(effects and effects.health or false)
    f.dispel.gradient:SetShown(effects and effects.gradient or false)
end

-- Everything the slots' buttons bake in when they're made.
local function SlotKey(self, f)
    local db, g = self.db, f.geometry
    local parts = { db.dispelFilter, g.width, g.height, g.px, g.radius, g.thickness, db.dispelGradientOpacity }
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
        local set = { ring = Kit.ModeBoxBorder(button), health = button:CreateTexture(nil, "ARTWORK", nil, 1),
            gradient = button:CreateTexture(nil, "ARTWORK", nil, 2) }
        set.health:SetTexture(Kit.FLAT); set.gradient:SetTexture(Kit.FLAT)
        LayoutEffects(self, f, set, button, color)
        -- Rounded by the button's own border masks, never ModeUI's frames' ones.
        Kit.MaskToBoxBorder(set.ring, { set.health, set.gradient }, f.healthEdges)
        self.ShowBorder(set.ring, effects.border)
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

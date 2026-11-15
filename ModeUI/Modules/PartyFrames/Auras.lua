local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The aura manager on each member. Each group (healing buffs, group buffs,
-- defensives, one per debuff type, other debuffs, crowd control) shows the
-- auras of its filters at its anchor: inside the bars at that point, or
-- outside past their edge, growing Right, Left, Up or Down and wrapping after
-- Per Row. Groups on the same anchor and place continue in one row, in group
-- order, placed and grown by the first shown one. In the world, Blizzard's aura
-- containers draw them (AuraContainers.lua), so they keep working while auras
-- are secret; clients without containers and the settings preview use the
-- reader here (Domain.Auras), which needs readable auras.
local Kit, Auras = addon.Kit, addon.Domain.Auras

function M:GroupFilters(group, choice)
    for _, item in ipairs(self.auraFilters[group]) do if item.id == choice then return item.filters end end
    return {}
end

-- Icon width and height in whole pixels.
function M:AuraSize(adb, px)
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    return Snap(adb.width), Snap(adb.height)
end

-- The groups sharing each anchor and place, in group order:
-- buckets[key] = { group, ... }, order = { key, ... }; and each bucket's lead
-- (the first shown group, which places and grows the row).
function M:AuraBuckets()
    local buckets, order, lead = {}, {}, {}
    for _, group in ipairs(self.auraGroups) do
        local adb = self.db.auras[group]
        local key = adb.anchor .. "|" .. (adb.anchor == "CENTER" and "inside" or adb.place)
        if not buckets[key] then buckets[key] = {}; order[#order + 1] = key end
        table.insert(buckets[key], group)
        if adb.show and not lead[key] then lead[key] = group end
    end
    for key, groups in pairs(buckets) do lead[key] = lead[key] or groups[1] end
    return buckets, order, lead
end

-- Where a row's first icon sits and which way the rest go. Returns the
-- icons' corner, the point on the bars it joins, the offset, whether rows
-- run across, and the step directions along a row (dx) and between rows (dy).
function M:AuraPlacement(f, adb, width, height)
    local g = f.geometry
    local px = g.px
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local anchor, grow = adb.anchor, adb.grow
    local h, v = self.Horizontal(anchor), self.Vertical(anchor)
    local across = grow == "left" or grow == "right"
    local outside = adb.place == "outside" and anchor ~= "CENTER"
    local cornerH, cornerV, x, y = h, v, Round(adb.x), Round(adb.y)
    if outside and v ~= "" then
        cornerV = v == "TOP" and "BOTTOM" or "TOP"
        y = y + (v == "TOP" and px or -px)
    elseif outside then
        cornerH = h == "LEFT" and "RIGHT" or "LEFT"
        x = x + (h == "LEFT" and -px or px)
    else
        local inset = g.border + px
        x = x + (h == "LEFT" and inset or h == "RIGHT" and -inset or 0)
        y = y + (v == "TOP" and -inset or v == "BOTTOM" and inset or 0)
    end
    -- A middle anchor starts its first icon centered on it.
    if cornerH == "" and across then
        cornerH = grow == "left" and "RIGHT" or "LEFT"
        x = x + (grow == "left" and 1 or -1) * Round(width / 2)
    end
    if cornerV == "" and not across then
        cornerV = grow == "down" and "TOP" or "BOTTOM"
        y = y + (grow == "down" and 1 or -1) * Round(height / 2)
    end
    local corner = (cornerV .. cornerH) ~= "" and (cornerV .. cornerH) or "CENTER"
    local dx, dy
    if across then dx, dy = grow == "left" and -1 or 1, cornerV == "BOTTOM" and 1 or -1
    else dx, dy = cornerH == "RIGHT" and -1 or 1, grow == "up" and 1 or -1 end
    return corner, anchor, x, y, across, dx, dy
end

-- A per-group style for Kit.LayoutAuraIcon: the module's text settings plus
-- the group's own border size (0 without a border) and timer text.
function M:AuraStyle(adb)
    local db = self.db
    return setmetatable({ auraTimerText = adb.timerText, auraBorderSize = adb.border == "none" and 0 or adb.borderSize,
        auraCorners = "sharp", auraTimerColor = db.auraTimerColor }, { __index = db })
end

-- A dispel type's color (no type and Enrage take the No Type color).
function M:TypeColor(dispelType)
    local key = dispelType and self.dispelColorKeys[dispelType]
    return key and self.db[key] or self.db.auraNoTypeColor
end
-- The rim's tint: by type or the group's own color; nil keeps the Gunmetal
-- metal (Mode). Border None hides the edge (PaintAuraLook).
function M:AuraRimColor(adb, dispelType)
    if adb.border == "type" then return self:TypeColor(dispelType) end
    if adb.border == "custom" then return adb.borderColor end
end
-- The glow: off (nil), by type, or the group's own color.
function M:AuraGlowColor(adb, dispelType)
    if adb.glow == "none" then return nil end
    return adb.glowColor == "custom" and adb.glowCustomColor or self:TypeColor(dispelType)
end

-- Paints an icon's rim and glow (reader path and samples).
function M:PaintAuraLook(icon, adb, dispelType)
    Kit.ShowAuraRim(icon, adb.border ~= "none")
    Kit.TintAuraRim(icon, self:AuraRimColor(adb, dispelType))
    Kit.GlowAura(icon, self:AuraGlowColor(adb, dispelType), adb.glow)
end

local TOOLTIP = { [true] = "SetUnitBuffByAuraInstanceID", [false] = "SetUnitDebuffByAuraInstanceID" }
local function ShowTooltip(icon)
    local tip, method = GameTooltip, TOOLTIP[M.HELPFUL[icon.auraGroup] == true]
    if not tip or not icon.auraUnit or icon.auraID == nil or not tip[method] then return end
    tip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
    if pcall(tip[method], tip, icon.auraUnit, icon.auraID, icon.auraFilter) then tip:Show() else tip:Hide() end
end
local function HideTooltip(icon)
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == icon then GameTooltip:Hide() end
end

function M:ReaderIcon(f, group, index)
    local pool = f.auraIcons[group]
    if not pool[index] then
        local icon = Kit.AuraIcon(f.auraLayer)
        icon.auraGroup = group
        icon:SetScript("OnEnter", ShowTooltip)
        icon:SetScript("OnLeave", HideTooltip)
        pool[index] = icon
    end
    return pool[index]
end

-- Sizes and places every shown reader icon, row by row: the groups of one
-- anchor continue where the previous one stopped.
function M:LayoutReader(f)
    local g = f.geometry
    if not g then return end
    local buckets, order, lead = self:AuraBuckets()
    for _, key in ipairs(order) do
        local first = self.db.auras[lead[key]]
        local fw, fh = self:AuraSize(first, g.px)
        local corner, point, x, y, across, dx, dy = self:AuraPlacement(f, first, fw, fh)
        local spacing = first.spacing * g.px
        local n, along, line = 0, 0, 0
        for _, group in ipairs(buckets[key]) do
            local adb = self.db.auras[group]
            local width, height = self:AuraSize(adb, g.px)
            local style = self:AuraStyle(adb)
            for index = 1, f.auraShown[group] do
                local icon = f.auraIcons[group][index]
                Kit.LayoutAuraIcon(icon, width, height, g.px, style, f.fontPath)
                -- Icons take the mouse only for tooltips; clicks fall through to the
                -- member. Preview samples take clicks: they open the group's settings.
                if f.sample then icon:EnableMouse(true)
                elseif icon.SetMouseMotionEnabled and icon.SetMouseClickEnabled then
                    icon:SetMouseMotionEnabled(adb.tooltip); icon:SetMouseClickEnabled(false)
                else icon:EnableMouse(adb.tooltip) end
                if n > 0 and n % first.perRow == 0 then along, line = 0, line + 1 end
                local ox = across and along or line * (fw + spacing)
                local oy = across and line * (fh + spacing) or along
                icon:ClearAllPoints()
                icon:SetPoint(corner, f.panel, point, x + dx * ox, y + dy * oy)
                along = along + (across and width or height) + spacing
                n = n + 1
            end
        end
    end
end

local function HideFrom(f, group, from)
    local pool = f.auraIcons[group]
    for index = from, #pool do pool[index]:Hide() end
    f.auraShown[group] = from - 1
end

function M:LayoutAuras(f)
    if self:UsesContainers(f) then self:AttachAuras(f); return end
    self:LayoutReader(f)
end

-- A tracked group's spells as a set, and every shown tracked group's spells
-- together (the ones the other buff groups leave out).
function M:SpellSet(group)
    local set, any = {}, false
    for _, id in ipairs(self.db.auras[group].spells or {}) do set[id] = true; any = true end
    return set, any
end
function M:TrackedSpells()
    local set, any = {}, false
    for group in pairs(self.TRACKED) do
        if self.db.auras[group].show then
            for _, id in ipairs(self.db.auras[group].spells) do set[id] = true; any = true end
        end
    end
    return set, any
end

-- Whether a readable aura belongs to a group by its dispel type or spell.
local function Belongs(self, group, dispelType, spell)
    local wanted = self.groupDispelType[group]
    if wanted then return dispelType == wanted end
    if group == "otherDebuffs" then return not (dispelType and self.dispelColorKeys[dispelType]) end
    if self.TRACKED[group] then return spell ~= nil and self:SpellSet(group)[spell] == true end
    if self.HELPFUL[group] then return spell == nil or not self:TrackedSpells()[spell] end
    return true
end

-- Reader path: every group's auras, and the debuff effects from the first
-- debuff of the Which Debuffs filter whose type the game shows.
function M:UpdateAuras(f)
    if self:UsesContainers(f) or not self:Live(f) then return end
    for _, group in ipairs(self.auraGroups) do
        local adb, count = self.db.auras[group], 0
        local filters = self:GroupFilters(group, adb.filter)
        if adb.show then
            for _, aura in ipairs(Auras.Collect(f.unit, filters, 40)) do
                if count >= adb.max then break end
                local name, id = Auras.Field(aura, "dispelName"), Auras.Field(aura, "spellId")
                local dispel = (addon.IsPublic(name) and type(name) == "string") and name or nil
                local spell = addon.IsNumber(id) and id or nil
                if Belongs(self, group, dispel, spell) then
                    count = count + 1
                    local icon = self:ReaderIcon(f, group, count)
                    Auras.Apply(icon, f.unit, aura, adb.timer, adb.count)
                    icon.auraUnit, icon.auraID, icon.auraFilter = f.unit, Auras.Field(aura, "auraInstanceID"), filters[1]
                    self:PaintAuraLook(icon, adb, dispel)
                    icon:Show()
                end
            end
        end
        HideFrom(f, group, count + 1)
    end
    self:LayoutReader(f)
    local dispel
    for _, aura in ipairs(Auras.Collect(f.unit, self:GroupFilters("dispel", self.db.dispelFilter), 40)) do
        local name = Auras.Field(aura, "dispelName")
        if addon.IsPublic(name) and self.dispelColorKeys[name] then dispel = name; break end
    end
    self:PaintDispel(f, dispel)
end

-- Stand-ins and the preview: sample icons in every group that is on, or
-- only in `only` (the group the Auras tab is editing).
M.SAMPLE_AURAS = { heals = "Interface\\Icons\\Spell_Holy_Renew", buffs = "Interface\\Icons\\Spell_Holy_WordFortitude",
    defensives = "Interface\\Icons\\Spell_Holy_PowerWordShield", magic = "Interface\\Icons\\Spell_Frost_FrostNova",
    curse = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", disease = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
    poison = "Interface\\Icons\\Ability_Rogue_DualWeild", bleed = "Interface\\Icons\\Ability_Gouge",
    otherDebuffs = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", crowdControl = "Interface\\Icons\\Spell_Nature_Polymorph" }
M.SAMPLE_COUNTS = { heals = 2, buffs = 2, defensives = 1, tracked1 = 2, tracked2 = 2, tracked3 = 2, dispellable = 1, magic = 1,
    curse = 0, disease = 0, poison = 1, bleed = 0, otherDebuffs = 1, crowdControl = 1 }
M.SAMPLE_AURAS.dispellable = "Interface\\Icons\\Spell_Holy_DispelMagic"
function M:PaintAuraSample(f, index, only)
    for _, group in ipairs(self.auraGroups) do
        local adb = self.db.auras[group]
        -- The edited group shows as many as it may; otherwise a few per group.
        local count = 0
        if only then count = group == only and adb.max or 0
        elseif adb.show and self.TRACKED[group] then count = math.min(adb.max, #adb.spells)
        elseif adb.show then count = math.min(adb.max, self.SAMPLE_COUNTS[group] or 1) end
        local dispel = self.groupDispelType[group] or (group == "dispellable" and "Magic" or nil)
        for i = 1, count do
            local icon = self:ReaderIcon(f, group, i)
            icon.auraUnit, icon.auraID = nil, nil
            local tracked = self.TRACKED[group] and adb.spells[i]
            icon.icon:SetTexture(tracked and addon.Domain.Cooldowns.SpellIcon(tracked) or self.SAMPLE_AURAS[group] or self.SAMPLE_AURAS.buffs)
            Kit.Write(icon.count, adb.count and i == 1 and "2" or "")
            Kit.Write(icon.timer, adb.timerText and tostring(4 + 3 * i) or "")
            icon.cooldown:Hide()
            self:PaintAuraLook(icon, adb, dispel)
            icon:Show()
        end
        HideFrom(f, group, count + 1)
    end
    self:LayoutReader(f)
    self:PaintDispel(f, not only and index == 2 and "Magic" or nil)
end

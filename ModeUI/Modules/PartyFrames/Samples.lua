local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Sample members for the settings preview, Edit Mode and Test on Screen,
-- drawn by the same code as the members in the world. Preview states show
-- what a member rarely shows on its own (owner, November 13, 2026: dead,
-- ready checks, the dispel overlay, overshields ...): the ones picked under
-- Show in the preview header apply to every sample, and the open tab's own
-- element (Preview.lua, M:PreviewFocus) shows on the first one, so each page
-- previews what it edits and stops when you leave it.
local Kit, UnitColor = addon.Kit, addon.Domain.UnitColor
local L = addon.L

-- Five sample members: class, health %, power %, and what each shows.
M.SAMPLES = {
    { class = "WARRIOR", health = 82, power = 40, powerToken = "RAGE", aggro = true },
    { class = "PRIEST", health = 64, power = 75, powerToken = "MANA", absorb = 12 },
    { class = "MAGE", health = 100, power = 90, powerToken = "MANA", target = true, overshield = 18 },
    { class = "ROGUE", health = 38, power = 60, powerToken = "ENERGY", heal = 22, faded = true },
    { class = "HUNTER", health = 0, power = 0, powerToken = "MANA", state = "Dead" },
}
M.SAMPLE_CLASS_NAMES = { WARRIOR = "Warrior", PRIEST = "Priest", MAGE = "Mage", ROGUE = "Rogue", HUNTER = "Hunter" }

-- States the preview can show (Show in the preview header), session only.
M.previewStateList = { { id = "dead", label = "Dead" }, { id = "offline", label = "Offline" },
    { id = "range", label = "Out of Range" }, { id = "target", label = "Your Target" }, { id = "dispel", label = "Dispel Overlay" },
    { id = "readyCheck", label = "Ready Check" }, { id = "summon", label = "Summon" }, { id = "raidIcon", label = "Raid Marker" },
    { id = "heals", label = "Incoming Heals" }, { id = "shields", label = "Shields" }, { id = "overshield", label = "Overshield" } }
M.previewStates = {}
function M:TogglePreviewState(id)
    for _, item in ipairs(self.previewStateList) do
        if item.id == id then
            self.previewStates[id] = not self.previewStates[id] or nil
            if self.page then self.page:Refresh() end
            return true
        end
    end
    return false
end

-- One sample's data with the states laid over it.
local function Sample(self, index, states)
    local s = {}
    for key, value in pairs(self.SAMPLES[index]) do s[key] = value end
    if states.dead then s.state, s.health = "Dead", 0 end
    if states.offline then s.state = "Offline" end
    if states.range then s.faded = true end
    if states.target then s.target = true end
    if states.heals then s.heal = 22; s.health = math.min(s.health, 70) end
    if states.shields then s.absorb = 14; s.health = math.min(s.health, 72) end
    if states.overshield then s.health, s.absorb, s.overshield = 100, nil, 24 end
    -- The Power Bars and Resources tab: a healer with mana, so every Power Bar For choice shows it.
    if states.power then s.powerToken, s.role, s.power = "MANA", "HEALER", 70 end
    return s
end

-- Paints one sample member (raid samples repeat the five). `auraGroup` shows
-- only that aura group; `states` lays preview states over it.
function M:PaintSample(f, index, auraGroup, states)
    index = (index - 1) % #self.SAMPLES + 1
    states = states or {}
    local db = self.db
    local s = Sample(self, index, states)
    f.role, f.powerToken = s.role or self.SAMPLE_ICONS.role[index], s.powerToken
    self:LayoutBars(f)
    local class = UnitColor.Class(s.class)
    local classColor = class and { class.r, class.g, class.b }
    local color = self:HealthColor(nil, classColor)
    f.health:SetMinMaxValues(0, 100); f.health:SetValue(s.health)
    self.PaintHealth(f.health, color, db.healthOpacity / 100)
    local power = db.powerColorMode == "custom" and db.powerColor or addon.Domain.Power.Color(s.powerToken)
    f.power:SetMinMaxValues(0, 100); f.power:SetValue(s.power)
    f.power:SetStatusBarColor(power[1], power[2], power[3], db.powerOpacity / 100)
    local powerTexts = { percent = s.power .. "%", percentPlain = tostring(s.power), current = tostring(s.power * 30) }
    Kit.Write(f.powerText, db.powerTextShow and powerTexts[db.powerText] or "")
    local heal = f.healPrediction
    heal:SetMinMaxValues(0, 100); heal:SetValue(s.heal or 0); heal:SetShown(db.showHealPrediction and true or false)
    -- Combined shields: attached below full health; the whole shield back
    -- from max at full health (the overshield state).
    local shield, amount = f.health.shield, s.overshield or s.absorb or 0
    shield:SetShown(db.showAbsorbs)
    shield:Update(nil, { max = 100, shield = math.min(amount, 100 - s.health), total = amount })
    shield.full:SetAlpha((s.health >= 100 and amount > 0 and db.showOvershields) and 1 or 0)
    local name, style = self:NameColor(nil, classColor)
    self:WriteName(f.texts.name, L[self.SAMPLE_CLASS_NAMES[s.class]], name, style)
    local texts = { percent = s.health .. "%", percentPlain = tostring(s.health), current = tostring(s.health * 120),
        deficit = s.health < 100 and ("-" .. (100 - s.health) * 120) or "" }
    Kit.Write(f.texts.healthText, (db.healthTextShow and not s.state) and texts[db.healthText] or "")
    Kit.Write(f.texts.status, s.state and L[s.state] or "")
    for _, key in ipairs({ "healthText", "status" }) do
        local c = db.textColor
        if key == "healthText" and db.healthTextColor == "health" then c = addon.Style.HealthTextColorAt(s.health / 100) end
        f.texts[key]:SetTextColor(c[1], c[2], c[3], 1)
    end
    f:SetAlpha(s.state and db.deadOpacity / 100 or (s.faded and db.rangeFade) and db.rangeOpacity / 100 or 1)
    f.isTarget = s.target == true
    f.hasAggro = s.aggro or nil
    self:PaintTarget(f)
    self:PaintIconSample(f, index, states)
    self:PaintAuraSample(f, index, auraGroup)
    if states.dispel then self:PaintDispel(f, type(states.dispel) == "string" and states.dispel or "Magic") end
end

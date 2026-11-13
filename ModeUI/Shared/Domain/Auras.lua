local _, addon = ...
local Number = addon.IsNumber

-- Unit auras. Which auras show is decided by the game through filter strings
-- (AuraUtil.AuraFilters), so no secret aura field is ever compared here. Aura
-- data is secret while the game restricts unit auras
-- (SecretWhenUnitAuraRestricted): the icon then goes only to SetTexture, the
-- stack text only to SetText, and a timer is drawn only when it can be.
local Auras = {}
addon.Domain.Auras = Auras

local NAMEPLATE = "INCLUDE_NAME_PLATE_ONLY"
-- Filter strings for each choice; nil means "none".
Auras.debuffFilters = { mine = "HARMFUL|PLAYER|" .. NAMEPLATE, dispellable = "HARMFUL|RAID", all = "HARMFUL|" .. NAMEPLATE }
Auras.buffFilters = { dispellable = "HELPFUL|DISPELLABLE", important = "HELPFUL|IMPORTANT", mine = "HELPFUL|PLAYER", all = "HELPFUL" }
Auras.crowdControlFilter = "HARMFUL|CROWD_CONTROL|" .. NAMEPLATE
-- Debuffs leave out crowd control when it has its own group.
Auras.WITHOUT_CROWD_CONTROL = "|!CROWD_CONTROL"

-- Up to `max` auras matching `filter`; an empty list when unavailable.
function Auras.List(unit, filter, max)
    if not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then return {} end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter, max)
    if not ok or type(list) ~= "table" or (issecrettable and issecrettable(list)) then return {}, not ok end
    return list
end

-- Reads one aura field; nil when the aura table can't be read.
local function Field(aura, key)
    local ok, value = pcall(function() return aura[key] end)
    if ok then return value end
end
Auras.Field = Field

-- Text and its lift copy (Kit's text style) get the same, possibly secret, text.
local function Write(text, value)
    text:SetText(value)
    if text.lift then text.lift:SetText(value) end
end

-- Fills an icon from Kit.AuraIcon with an aura.
function Auras.Apply(icon, unit, aura, showTimer, showCount)
    if not pcall(icon.icon.SetTexture, icon.icon, Field(aura, "icon")) then icon.icon:SetTexture(nil) end
    local id = Field(aura, "auraInstanceID")
    local text = ""
    if showCount and C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount then
        local ok, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, id, 2)
        if ok then text = count end
    end
    if not pcall(Write, icon.count, text) then Write(icon.count, "") end
    Auras.ApplyTimer(icon, showTimer and unit, id, Field(aura, "duration"), Field(aura, "expirationTime"))
end

-- The cooldown swipe: from the game's duration object when the client allows
-- it, else from public times; hidden when neither works or the aura is permanent.
function Auras.ApplyTimer(icon, unit, id, duration, expiration)
    local cooldown = icon.cooldown
    if not unit then cooldown:Hide(); return false end
    if C_UnitAuras and C_UnitAuras.GetAuraDuration and cooldown.SetCooldownFromDurationObject then
        local ok, object = pcall(C_UnitAuras.GetAuraDuration, unit, id)
        if ok and object and pcall(cooldown.SetCooldownFromDurationObject, cooldown, object) then cooldown:Show(); return true end
    end
    if Number(duration, 0.01) and Number(expiration) then
        cooldown:SetCooldown(expiration - duration, duration)
        cooldown:Show()
        return true
    end
    cooldown:Hide()
    return false
end

-- The groups to show, in order, for a style's aura choices.
function Auras.Filters(crowdControl, debuffs, buffs)
    local filters = {}
    if crowdControl then filters[#filters + 1] = Auras.crowdControlFilter end
    local debuff = Auras.debuffFilters[debuffs]
    if debuff then filters[#filters + 1] = crowdControl and debuff .. Auras.WITHOUT_CROWD_CONTROL or debuff end
    local buff = Auras.buffFilters[buffs]
    if buff then filters[#filters + 1] = buff end
    return filters
end

-- Every aura for the filters, in order, up to max. A filter the client rejects
-- (for example a negation it doesn't know) is retried without the negation.
function Auras.Collect(unit, filters, max)
    local result = {}
    for _, filter in ipairs(filters) do
        local remaining = max - #result
        if remaining <= 0 then break end
        local list, failed = Auras.List(unit, filter, remaining)
        if failed and filter:find(Auras.WITHOUT_CROWD_CONTROL, 1, true) then
            list = Auras.List(unit, (filter:gsub("|!CROWD_CONTROL", "")), remaining)
        end
        for _, aura in ipairs(list) do
            if #result >= max then break end
            result[#result + 1] = aura
        end
    end
    return result
end

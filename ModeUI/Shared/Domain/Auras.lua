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
-- Unit frames show every aura of a kind, not just the nameplate ones.
Auras.frameFilters = {
    buffs = { all = "HELPFUL", mine = "HELPFUL|PLAYER", dispellable = "HELPFUL|DISPELLABLE" },
    debuffs = { all = "HARMFUL", mine = "HARMFUL|PLAYER", dispellable = "HARMFUL|RAID" },
}
-- Debuffs leave out crowd control when it has its own group.
Auras.WITHOUT_CROWD_CONTROL = "|!CROWD_CONTROL"

-- Whether a possibly secret value is there at all. Comparing a secret value
-- can raise an error; a secret is never nil, so an error means present.
local function Present(value)
    local ok, present = pcall(function() return value ~= nil end)
    return not ok or present
end

-- Up to `max` auras matching `filter`; an empty list when unavailable.
-- While unit auras are restricted (in combat), GetUnitAuras still returns the
-- list but marks its contents secret (ConditionalSecretContents), so
-- issecrettable is true for it. Its auras still show: each field is read
-- under pcall and only passed to widgets that accept secrets (an icon to
-- SetTexture), as Blizzard's own nameplates do. Only an aura whose icon can't
-- be read at all is left out.
function Auras.List(unit, filter, max)
    if not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then return {} end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter, max)
    if not ok or type(list) ~= "table" then return {}, not ok end
    local result = {}
    pcall(function()
        for _, aura in ipairs(list) do
            local readable, icon = pcall(function() return aura.icon end)
            if readable and Present(icon) then result[#result + 1] = aura end
        end
    end)
    return result
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
    -- The dispel type colors the rim when it's public ("Magic", "Curse", ...).
    local dispel = Field(aura, "dispelName")
    icon.dispelType = (addon.IsPublic(dispel) and type(dispel) == "string") and dispel or nil
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

-- The filter string for one group: "crowdControl", or "debuffs"/"buffs" with
-- a choice from debuffFilters/buffFilters. Debuffs leave out crowd control
-- when that has its own group.
function Auras.GroupFilter(group, choice, crowdControlShown)
    if group == "crowdControl" then return Auras.crowdControlFilter end
    if group == "debuffs" then
        local filter = Auras.debuffFilters[choice]
        return filter and crowdControlShown and filter .. Auras.WITHOUT_CROWD_CONTROL or filter
    end
    return Auras.buffFilters[choice]
end

-- Whether the game never keeps a spell's aura secret
-- (C_Secrets.GetSpellAuraSecrecy == Enum.SecrecyLevel.NeverSecret;
-- SecretPredicateAPIDocumentation.lua). Aura containers filter a debuff on a
-- friendly unit by spell ID only then (AuraContainerUtil.
-- CanApplyIdentityCandidateFilters). True, false, or nil when the client
-- can't say.
function Auras.NeverSecret(spellID)
    if not (C_Secrets and C_Secrets.GetSpellAuraSecrecy and Enum and Enum.SecrecyLevel) then return nil end
    local ok, secrecy = pcall(C_Secrets.GetSpellAuraSecrecy, spellID)
    if not ok or not addon.IsPublic(secrecy) then return nil end
    return secrecy == Enum.SecrecyLevel.NeverSecret
end

-- The auras on a unit now with public spell IDs (out of combat), each once:
-- { id, icon, harmful }. For pickers.
function Auras.Spells(unit)
    local list, seen = {}, {}
    for _, kind in ipairs({ "HELPFUL", "HARMFUL" }) do
        for _, aura in ipairs(Auras.List(unit, kind, 40)) do
            local id, icon = Field(aura, "spellId"), Field(aura, "icon")
            if addon.IsNumber(id) and not seen[id] then
                seen[id] = true
                list[#list + 1] = { id = id, icon = addon.IsPublic(icon) and icon or nil, harmful = kind == "HARMFUL" }
            end
        end
    end
    return list
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

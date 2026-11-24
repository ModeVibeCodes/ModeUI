local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Racial abilities, added on their own (owner, November 14, 2026). Blizzard's
-- Cooldown Manager doesn't track them, so they show on ModeUI's own icons,
-- like spells added by ID ("s<spell ID>", Spells.lua), at the end of one bar:
-- Utility by default, or Essential, a custom Cooldown Bar, or none (Racial
-- Abilities on the Bar tab; db.racials). Nothing is saved per racial: the
-- bar lists the ones your character knows, each time spells change, so a
-- new race or class shows its own. Remove from Bar hides one there; it can
-- be dragged like any spell (on a custom bar it then joins the bar's list).
--
-- The spell IDs are Blizzard's own table of racial cooldowns
-- (Blizzard_CooldownBroadcaster/TrackedCooldowns.lua, RacialCooldowns, with
-- each class's Arcane Torrent and Gift of the Naaru), plus Blood Fury's
-- class versions. A racial counts only when C_SpellBook.IsSpellKnown says
-- so, never when the client can't tell, and when it has a slot in your
-- spellbook: IsSpellKnown can say true for another class's version (an orc
-- showed Blood Fury twice, one of them dim and unusable).
-- One racial per name shows, the first in the list.
local L, Cooldowns = addon.L, addon.Domain.Cooldowns
local function Copy(value) return addon.ProfileCodec.Copy(value) end

M.RACIALS = {
    20572, 33697, 33702, -- Blood Fury (Orc)
    26297,               -- Berserking (Troll)
    7744,                -- Will of the Forsaken (Undead)
    20549,               -- War Stomp (Tauren)
    50613, 202719, 80483, 28730, 129597, 155145, 232633, 25046, 69179, -- Arcane Torrent (Blood Elf)
    69070,               -- Rocket Jump (Goblin)
    59752,               -- Will to Survive (Human)
    20594,               -- Stoneform (Dwarf)
    58984,               -- Shadowmeld (Night Elf)
    20589,               -- Escape Artist (Gnome)
    59545, 59543, 59548, 121093, 59542, 59544, 370626, 59547, 416250, 28880, -- Gift of the Naaru (Draenei)
    68992,               -- Darkflight (Worgen)
    107079,              -- Quaking Palm (Pandaren)
    368970, 357214,      -- Tail Swipe, Wing Buffet (Dracthyr)
    260364,              -- Arcane Pulse (Nightborne)
    255654,              -- Bull Rush (Highmountain Tauren)
    274738,              -- Ancestral Call (Mag'har Orc)
    291944,              -- Regeneratin' (Zandalari Troll)
    312411,              -- Bag of Tricks (Vulpera)
    256948,              -- Spatial Rift (Void Elf)
    255647,              -- Light's Judgment (Lightforged Draenei)
    265221,              -- Fireblood (Dark Iron Dwarf)
    287712,              -- Haymaker (Kul Tiran)
    312924,              -- Hyper Organic Light Originator (Mechagnome)
    436344,              -- Azerite Surge (Earthen)
    1237885,             -- Thorn Bloom (Haranir)
}

-- The racials you know, as keys ("s26297"), in the list's order. Worked out
-- again after each Refresh (spells changing refreshes the module).
function M:RacialKeys()
    if self.racialKeys then return self.racialKeys end
    local keys, names, layout = {}, {}, self:BlizzardLayout()
    for _, spellID in ipairs(self.RACIALS) do
        -- One Blizzard's Cooldown Manager shows itself stays Blizzard's.
        if Cooldowns.SurelyKnown(spellID) and Cooldowns.InSpellBook(spellID) ~= false and not self:BlizzardTracksSpell(spellID, layout) then
            local name = Cooldowns.SpellName(spellID) or spellID
            if not names[name] then names[name] = true; keys[#keys + 1] = "s" .. spellID end
        end
    end
    self.racialKeys = keys
    return keys
end
function M:ForgetRacials() self.racialKeys, self.racialLists = nil, nil end

-- Whether a key is a racial the bar shows on its own.
function M:IsRacialHere(id, key)
    if self.db.racials ~= id then return false end
    for _, racial in ipairs(self:RacialKeys()) do if racial == key then return true end end
    return false
end

-- A bar's list with the racials it shows on its own after it (each once).
-- Kept until the list or the racials change.
function M:WithRacials(id, stored)
    local racials = self:RacialKeys()
    if #racials == 0 then return stored end
    self.racialLists = self.racialLists or {}
    local cached = self.racialLists[id]
    if cached and cached.stored == stored and cached.count == #stored and cached.racials == racials then return cached.list end
    local list, here = {}, {}
    for _, key in ipairs(stored) do list[#list + 1] = key; here[key] = true end
    for _, key in ipairs(racials) do if not here[key] then list[#list + 1] = key end end
    self.racialLists[id] = { stored = stored, count = #stored, racials = racials, list = list }
    return list
end

-- The bars racials can go on: Essential, Utility and custom Cooldown Bars.
function M:RacialChoices()
    local list = { { id = "none", label = L["Off"] } }
    for _, viewer in ipairs(self.viewers) do
        if self.entryViewers[viewer] then list[#list + 1] = { id = viewer, label = self:Label(viewer) } end
    end
    for _, bar in ipairs(self.db.customBars) do
        if bar.kind == "cooldown" then list[#list + 1] = { id = bar.id, label = bar.name } end
    end
    return list
end

-- Picks the bar racials show on ("none" for none).
function M:SetRacials(target)
    if not self:CanConfigure() then return false end
    local ok = false
    for _, choice in ipairs(self:RacialChoices()) do if choice.id == target then ok = true end end
    if not ok then return false end
    local candidate = Copy(self.db)
    candidate.racials = target
    return self.CommitBars(self, candidate)
end

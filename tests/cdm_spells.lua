-- ModeCDM spells after the November 24, 2026 rework: equipped trinkets
-- ("t13", "t14", whatever is in the slot), a Ready Sound for the spells
-- ModeUI tracks itself, Own Bar from a spell's menu, and racials standing
-- aside when Blizzard's Cooldown Manager shows them itself.
-- Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua") .. [[
    equipped = { [13] = 5512 }
    GetInventoryItemID = function(unit, slot) return equipped[slot] end
    played = {}
    PlaySound = function(kit, channel) played[#played + 1] = { kit = kit, channel = channel } end
    PlaySoundFile = function(path, channel) played[#played + 1] = { path = path, channel = channel } end
    SOUNDKIT = SOUNDKIT or {}
    SOUNDKIT.RAID_WARNING = SOUNDKIT.RAID_WARNING or 8959
]]

local world = H.Load({ before = STUBS .. "\nMakeViewers()" })
world.run([==[
    local M = addon.CooldownManager
    addon:SetModuleEnabled('cooldownManager', true)
    local bar = M:AddCustomBar('cooldown')

    -- Trinkets: the slot, listed first in the + list while it has a Use: effect.
    local items = M:ItemCandidates(bar)
    assert(items[1].key == 't13' and items[1].id == 5512 and items[1].name == 'Trinket 1 · Healthstone', 'the trinket slot, first')
    for _, item in ipairs(items) do assert(item.key ~= 't14', 'an empty slot is not offered') end
    assert(M:AddCustomItem(bar, 't13') and M:Entries(bar)[1] == 't13' and not M:AddCustomItem(bar, 't13'), 'added once')
    local icon = M.spellIcons[bar] and M.spellIcons[bar].t13
    assert(icon and icon:IsShown() and icon.Icon.texture == 'item:5512' and icon.ChargeCount.Current.text == '', "the slot's item, no count")
    equipped[13] = 191380; FireEvent('PLAYER_EQUIPMENT_CHANGED')
    assert(icon.Icon.texture == 'item:191380' and M:ItemLabel('t13') == 'Trinket 1 · Healing Potion', 'follows what is equipped')
    equipped[13] = nil; FireEvent('PLAYER_EQUIPMENT_CHANGED')
    assert(M:ItemLabel('t13') == 'Trinket 1 · empty' and icon.Icon.desaturated, 'an empty slot stays, gray')
    equipped[13] = 5512; FireEvent('PLAYER_EQUIPMENT_CHANGED')

    -- Ready Sound: only for the spells ModeUI tracks itself; it plays as set and when the cooldown ends.
    assert(M:TakesReadySound('t13') and M:TakesReadySound('s9001') and not M:TakesReadySound('101'), 'own entries only')
    local choices = M:AlertSoundChoices()
    assert(choices[1].id == 'none' and choices[2].id == 'default', 'No Sound, then Blizzard Warning')
    assert(M:SetSpellAlert(bar, 't13', 'default') and M:SpellAlert(bar, 't13') == 'default' and played[#played].kit == 8959, 'set, with a preview')
    assert(not M:SetSpellAlert(bar, '101', 'default'), "a spell Blizzard tracks takes Blizzard's alerts")
    local before = #played
    M:SpellReady(bar, 't13')
    assert(#played == before + 1, 'plays when it comes off cooldown')
    assert(M:SetSpellAlert(bar, 't13', 'none') and M:SpellAlert(bar, 't13') == nil, 'No Sound clears it')

    -- Own Bar: a spell from its menu onto a one-icon bar of its own.
    local count = #M.db.customBars
    local new = M:AddSingleBar('essential', '102')
    assert(new and #M.db.customBars == count + 1 and M:Entries(new)[1] == '102' and M.db[new].perLine == 1, 'a one-icon bar with the spell')
    assert(M:Custom(new).name ~= '' and M:Follows(new, 'border'), 'named after it, in the Bar Style')
    assert(not M:CanOwnBar('utility', 's26297'), "not for a racial: it shows where Racial Abilities picks")

    -- Racials: one Blizzard's Cooldown Manager shows itself stays Blizzard's.
    M:ForgetRacials()
    assert(M:RacialKeys()[1] == 's26297', 'Berserking on its own icon')
    local layout, spellID = M.BlizzardLayout, addon.Domain.Cooldowns.SpellID
    M.BlizzardLayout = function() return { category = { [9999] = 'Utility' }, Utility = { 9999 } } end
    addon.Domain.Cooldowns.SpellID = function(id) if id == 9999 then return 26297 end return spellID(id) end
    M:ForgetRacials()
    assert(#M:RacialKeys() == 0, 'Blizzard tracks it: no second icon')
    M.BlizzardLayout, addon.Domain.Cooldowns.SpellID = layout, spellID
    M:ForgetRacials()
]==], "cdm spells")

-- Bad alert data stops startup rather than being reset.
local function Refused(change, label)
    local saved = world.saved()
    change(saved.profiles.Default.modules.cooldownManager)
    assert(not pcall(H.Load, { before = STUBS, saved = saved }), "invalid alerts are refused: " .. label)
end
Refused(function(db) db.essential.alerts = { ['101'] = 'default' } end, "a spell Blizzard tracks")
Refused(function(db) db.essential.alerts = { s9001 = 'loud' } end, "a sound")
Refused(function(db) db.extras.essential = { 't15' } end, "a slot that isn't a trinket")
print("cdm spells: ok")

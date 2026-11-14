local _, addon = ...
local Public, Number = addon.IsPublic, addon.IsNumber

-- The game's Cooldown Manager (Blizzard_CooldownViewer, which Forever loads
-- for its "camelot" game type too): its four viewer frames, the item frames
-- in them, what each item tracks and whether a spell is cooling down.
--
-- The viewers and items are plain frames (no secure template), but Blizzard's
-- code in them works on secret aura and cooldown values, which it can only do
-- while it runs untainted. So this only reads: it calls Blizzard's getters,
-- never writes a field and never calls a method that refreshes or lays out.
-- Cooldown IDs come from C_CooldownViewer and are public; anything else read
-- from an item is checked and counts as unknown when secret.
local CD = {}
addon.Domain.Cooldowns = CD
local Call = addon.Domain.Query.Call

-- Blizzard's viewers by the IDs ModeUI saves, in sidebar order.
CD.VIEWERS = { essential = "EssentialCooldownViewer", utility = "UtilityCooldownViewer",
    buffIcon = "BuffIconCooldownViewer", buffBar = "BuffBarCooldownViewer" }
CD.ADDON = "Blizzard_CooldownViewer"
CD.CVAR = "cooldownViewerEnabled"

function CD.Viewer(id)
    local frame = CD.VIEWERS[id] and _G[CD.VIEWERS[id]]
    if type(frame) == "table" and type(frame.GetObjectType) == "function" then return frame end
end

-- The game's Cooldown Manager option (Options > Gameplay Enhancements): true,
-- false, or nil when the client can't say.
function CD.Enabled()
    local api = C_CVar and C_CVar.GetCVarBool
    local ok, on = Call(api, CD.CVAR)
    if ok and Public(on) and type(on) == "boolean" then return on end
end

-- Whether the client offers the Cooldown Manager at all, and why not.
function CD.Available()
    local api = C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable
    local ok, available, reason = Call(api)
    if not ok or not Public(available) then return nil end
    return available == true, Public(reason) and reason or nil
end

-- An item's cooldown ID (public), or nil while it tracks nothing.
function CD.ItemCooldownID(item)
    if type(item) ~= "table" or type(item.GetCooldownID) ~= "function" then return nil end
    local ok, id = pcall(item.GetCooldownID, item)
    if ok and Number(id) then return id end
end

-- The game's record for a cooldown ID: { spellID, overrideSpellID, charges,
-- category, ... } (public), or nil.
function CD.Info(cooldownID)
    local api = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
    if not Number(cooldownID) then return nil end
    local ok, info = Call(api, cooldownID)
    if ok and Public(info) and type(info) == "table" then return info end
end

-- The spell an entry casts now: its override, else its own.
function CD.SpellID(cooldownID)
    local info = CD.Info(cooldownID)
    if not info then return nil end
    local spell = info.overrideSpellID or info.spellID
    if Number(spell) then return spell end
end

function CD.SpellName(spellID)
    local api = C_Spell and C_Spell.GetSpellName
    local ok, name = Call(api, spellID)
    if ok and Public(name) and type(name) == "string" then return name end
end

function CD.SpellIcon(spellID)
    local api = C_Spell and C_Spell.GetSpellTexture
    local ok, icon = Call(api, spellID)
    if ok and Public(icon) and (type(icon) == "number" or type(icon) == "string") then return icon end
end

-- Whether a spell is on a real cooldown (not the global cooldown): true,
-- false, or nil when unknown. isActive and isOnGCD are never secret.
function CD.Cooling(spellID)
    local api = C_Spell and C_Spell.GetSpellCooldown
    if not Number(spellID) then return nil end
    local ok, info = Call(api, spellID)
    if not ok or type(info) ~= "table" then return nil end
    local active, gcd = info.isActive, info.isOnGCD
    if not Public(active) or not Public(gcd) then return nil end
    return active == true and gcd ~= true
end

-- Whether a region shows: true, false, or nil when the game keeps it secret
-- (an item's shown state can come from secret aura data in combat).
function CD.Shown(region)
    if type(region) ~= "table" or type(region.IsShown) ~= "function" then return false end
    local shown = region:IsShown()
    if Public(shown) then return shown == true end
end

-- A viewer's active item frames, in Blizzard's order (layoutIndex).
function CD.Items(viewer)
    local list = {}
    local pool = type(viewer) == "table" and viewer.itemFramePool
    if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then return list end
    local ok = pcall(function() for item in pool:EnumerateActive() do list[#list + 1] = item end end)
    if not ok then return {} end
    local function Index(item)
        local index = item.layoutIndex
        return Number(index) and index or math.huge
    end
    table.sort(list, function(a, b) return Index(a) < Index(b) end)
    return list
end

-- Spells by ID (custom spells on ModeUI's own icons) -------------------------
-- Arguments are always public spell IDs. Cooldown and charge times come back
-- as duration objects, which go straight to Cooldown:SetCooldownFromDurationObject;
-- charge counts may be secret and only go to FontString:SetText.

-- Whether a spell ID names a spell at all (learned or not).
function CD.SpellExists(spellID)
    local api = C_Spell and C_Spell.DoesSpellExist
    if not Number(spellID, 1, 99999999) then return false end
    local ok, exists = Call(api, spellID)
    return ok and Public(exists) and exists == true
end

-- The spell a talent or form puts in its place now, else itself.
function CD.Override(spellID)
    local api = C_Spell and C_Spell.GetOverrideSpell
    local ok, override = Call(api, spellID)
    if ok and Number(override, 1, 99999999) then return override end
    return spellID
end

-- Whether you know the spell (or what overrides it): true, false, or true
-- when the client can't say.
function CD.Known(spellID)
    local api = C_SpellBook and C_SpellBook.IsSpellKnown
    if type(api) ~= "function" then return true end
    for _, id in ipairs({ spellID, CD.Override(spellID) }) do
        local ok, known = Call(api, id)
        if not ok or not Public(known) or known == true then return true end
    end
    return false
end

-- The spell's cooldown (global cooldown left out) and recharge as duration
-- objects, or nil.
function CD.CooldownDuration(spellID)
    local api = C_Spell and C_Spell.GetSpellCooldownDuration
    local ok, duration = Call(api, spellID, true)
    if ok and duration ~= nil then return duration end
end
function CD.ChargeDuration(spellID)
    local api = C_Spell and C_Spell.GetSpellChargeDuration
    local ok, duration = Call(api, spellID)
    if ok and duration ~= nil then return duration end
end

-- A charge spell's charges: current (may be secret), max and whether one is
-- recharging (both never secret); nil for a spell without charges.
function CD.Charges(spellID)
    local api = C_Spell and C_Spell.GetSpellCharges
    local ok, info = Call(api, spellID)
    if not ok or not Public(info) or type(info) ~= "table" then return nil end
    local max, recharging = info.maxCharges, info.isActive
    if not Number(max) or max <= 1 then return nil end
    return info.currentCharges, max, Public(recharging) and recharging == true
end

-- Whether the spell can be cast now, and whether only its power is short;
-- nil when the game won't say.
function CD.Usable(spellID)
    local api = C_Spell and C_Spell.IsSpellUsable
    local ok, usable, noPower = Call(api, spellID)
    if not ok or not Public(usable) or not Public(noPower) then return nil end
    return usable == true, noPower == true
end

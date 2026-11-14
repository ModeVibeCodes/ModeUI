local _, addon = ...
local Public, Number = addon.IsPublic, addon.IsNumber

-- The game's own damage meter data (C_DamageMeter, from Blizzard_DamageMeter,
-- which Forever loads too). Every call is guarded: a missing API, an error or
-- a malformed answer counts as "no data".
--
-- In combat the game makes amounts and names secret. They are returned only
-- so they can go straight to StatusBar SetMinMaxValues/SetValue,
-- AbbreviateNumbers and FontString SetText/SetFormattedText; nothing here
-- compares, sorts or adds them. The game already ranks sources and spells.
-- classFilename, isLocalPlayer and deathRecapID are never secret. On Forever
-- specIconID is always secret, so meters use class icons. Arguments are always
-- public: these functions refuse secret arguments from addon code.
local DM = {}
addon.Domain.DamageMeter = DM

DM.EVENTS = { "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET" }

-- The meter types Blizzard's own meter offers, in its menu order, keyed by
-- the IDs ModeUI saves. perSecond types lead with the per-second amount;
-- count types (interrupts, dispels) have none; deaths show when someone died.
DM.types = {
    { id = "damageDone", enum = "DamageDone", label = "Damage Done", group = "Damage" },
    { id = "dps", enum = "Dps", label = "DPS", group = "Damage", perSecond = true },
    { id = "damageTaken", enum = "DamageTaken", label = "Damage Taken", group = "Damage" },
    { id = "avoidable", enum = "AvoidableDamageTaken", label = "Avoidable Damage Taken", group = "Damage" },
    { id = "enemyDamageTaken", enum = "EnemyDamageTaken", label = "Enemy Damage Taken", group = "Damage", noIcon = true },
    { id = "healingDone", enum = "HealingDone", label = "Healing Done", group = "Healing" },
    { id = "hps", enum = "Hps", label = "HPS", group = "Healing", perSecond = true },
    { id = "interrupts", enum = "Interrupts", label = "Interrupts", group = "Actions", count = true },
    { id = "dispels", enum = "Dispels", label = "Dispels", group = "Actions", count = true },
    { id = "deaths", enum = "Deaths", label = "Deaths", group = "Actions", deaths = true },
}
DM.typeById = {}
for _, info in ipairs(DM.types) do DM.typeById[info.id] = info end

local function Api(name) return type(C_DamageMeter) == "table" and type(C_DamageMeter[name]) == "function" and C_DamageMeter[name] or nil end
local function Call(name, ...)
    local fn = Api(name)
    if not fn then return false end
    return pcall(fn, ...)
end

-- Whether this client has the meter API at all.
function DM.Supported()
    return Api("GetCombatSessionFromType") ~= nil and type(Enum) == "table"
        and type(Enum.DamageMeterType) == "table" and type(Enum.DamageMeterSessionType) == "table"
end

-- ok, reason: whether the game lets this character use the meter, and why not.
function DM.Available()
    if not DM.Supported() then return false, nil end
    local ok, available, reason = Call("IsDamageMeterAvailable")
    if not ok or not Public(available) then return false, nil end
    if not Public(reason) or type(reason) ~= "string" or reason == "" then reason = nil end
    return available == true, reason
end

-- The game's own Damage Meter option (Blizzard's damageMeterEnabled): true,
-- false, or nil when unknown. ModeUI only reads it.
function DM.GameMeterOn()
    local get = type(C_CVar) == "table" and C_CVar.GetCVarBool
    if type(get) ~= "function" then return nil end
    local ok, on = pcall(get, "damageMeterEnabled")
    if ok and Public(on) and type(on) == "boolean" then return on end
    return nil
end

local function TypeEnum(id)
    local info = DM.typeById[id]
    local value = info and DM.Supported() and Enum.DamageMeterType[info.enum]
    if Number(value) then return value end
end
local SESSION_ENUMS = { current = "Current", overall = "Overall" }
local function SessionEnum(key)
    local name = SESSION_ENUMS[key]
    local value = name and DM.Supported() and Enum.DamageMeterSessionType[name]
    if Number(value) then return value end
end

-- A session is "current", "overall" or an earlier fight's public session ID.
-- Returns { sources, max, total, duration } or nil. sources is the game's
-- ranked list; max, total and the source fields may be secret.
function DM.Session(session, typeId)
    local meterType = TypeEnum(typeId)
    if not meterType then return nil end
    local ok, data
    if type(session) == "number" then
        if not Number(session) then return nil end
        ok, data = Call("GetCombatSessionFromID", session, meterType)
    else
        local sessionType = SessionEnum(session)
        if sessionType == nil then return nil end
        ok, data = Call("GetCombatSessionFromType", sessionType, meterType)
    end
    if not ok or not Public(data) or type(data) ~= "table" then return nil end
    local sources = data.combatSources
    if not Public(sources) or type(sources) ~= "table" then sources = {} end
    return { sources = sources, max = data.maxAmount, total = data.totalAmount, duration = data.durationSeconds }
end

-- One source's spells: { spells, max, total } or nil. The source is named by
-- its GUID or creature ID, which must be public (the game refuses secret ones).
function DM.Source(session, typeId, guid, creatureID)
    local meterType = TypeEnum(typeId)
    if not meterType or not Public(guid) or not Public(creatureID) then return nil end
    if guid ~= nil and (type(guid) ~= "string" or guid == "") then return nil end
    if creatureID ~= nil and not Number(creatureID) then return nil end
    if guid == nil and creatureID == nil then return nil end
    local ok, data
    if type(session) == "number" then
        ok, data = Call("GetCombatSessionSourceFromID", session, meterType, guid, creatureID)
    else
        local sessionType = SessionEnum(session)
        if sessionType == nil then return nil end
        ok, data = Call("GetCombatSessionSourceFromType", sessionType, meterType, guid, creatureID)
    end
    if not ok or not Public(data) or type(data) ~= "table" then return nil end
    local spells = data.combatSpells
    if not Public(spells) or type(spells) ~= "table" then spells = {} end
    return { spells = spells, max = data.maxAmount, total = data.totalAmount }
end

-- Earlier fights the game still holds: { id, name, duration } with public
-- values only (name and duration may be nil).
function DM.Sessions()
    local list = {}
    local ok, sessions = Call("GetAvailableCombatSessions")
    if not ok or not Public(sessions) or type(sessions) ~= "table" then return list end
    for _, item in ipairs(sessions) do
        if Public(item) and type(item) == "table" and Number(item.sessionID) then
            local name = item.name
            if not Public(name) or type(name) ~= "string" or name == "" then name = nil end
            local duration = Number(item.durationSeconds, 0) and item.durationSeconds or nil
            list[#list + 1] = { id = item.sessionID, name = name, duration = duration }
        end
    end
    return list
end

-- Seconds a session has lasted, while public; nil otherwise.
function DM.Duration(session)
    if type(session) == "number" then
        for _, item in ipairs(DM.Sessions()) do if item.id == session then return item.duration end end
        return nil
    end
    local sessionType = SessionEnum(session)
    if sessionType == nil then return nil end
    local ok, seconds = Call("GetSessionDurationSeconds", sessionType)
    if ok and Number(seconds, 0) then return seconds end
end

-- Clears every session the game holds (Blizzard's own Reset).
function DM.Reset() return (Call("ResetAllCombatSessions")) end

-- A spell's name and icon. spellID may be secret; C_Spell accepts it and the
-- results go only to SetText and SetTexture.
-- Missing is tested only on public values: a secret one is never compared.
local function Missing(value) return Public(value) and value == nil end
function DM.SpellName(spellID)
    local get = type(C_Spell) == "table" and C_Spell.GetSpellName
    if type(get) ~= "function" or Missing(spellID) then return "" end
    local ok, name = pcall(get, spellID)
    if not ok or Missing(name) then return "" end
    return name
end
function DM.SpellIcon(spellID)
    local get = type(C_Spell) == "table" and C_Spell.GetSpellTexture
    if type(get) ~= "function" or Missing(spellID) then return nil end
    local ok, icon = pcall(get, spellID)
    if ok then return icon end
end

-- A class's icon atlas, when the client confirms it has one; else nil.
local atlases = {}
function DM.ClassAtlas(class)
    if not Public(class) or type(class) ~= "string" or class == "" then return nil end
    if atlases[class] ~= nil then return atlases[class] or nil end
    local Q = addon.Domain.Query
    local atlas = Q.Plain(GetClassAtlas, class)
    local known = type(atlas) == "string" and type(C_Texture) == "table" and Q.Plain(C_Texture.GetAtlasInfo, atlas)
    atlases[class] = known and atlas or false
    return atlases[class] or nil
end

-- "1:05" for 65 seconds; "" for anything that isn't a public number.
function DM.Clock(seconds)
    if not Number(seconds, 0) then return "" end
    seconds = math.floor(seconds + 0.5)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

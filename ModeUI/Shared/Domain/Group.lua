local _, addon = ...
local Q, Public = addon.Domain.Query, addon.IsPublic

-- Group members: role, leader, ready check, summons and resurrections, range
-- and heal prediction. Forever's API docs (as mainline 12.1.5):
-- UnitGroupRolesAssigned, UnitIsGroupLeader and UnitPhaseReason are secret
-- while a unit's identity is restricted, so a secret answer counts as
-- "unknown" here. UnitInRange, UnitGetIncomingHeals and UnitGetTotalAbsorbs
-- always return secrets: they are handed back only for
-- Region:SetAlphaFromBoolean and StatusBar:SetValue. GetReadyCheckStatus,
-- UnitHasIncomingResurrection, C_IncomingSummon and UnitIsConnected document
-- no secret returns; they are still read through Query.Plain.
local Group = {}
addon.Domain.Group = Group

-- Blizzard's own party frame art (PartyMemberFrame.lua, CompactUnitFrame.lua,
-- ReadyCheck.lua on the Forever branch).
Group.ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
Group.LEADER_ATLAS, Group.GUIDE_ATLAS = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "UI-HUD-UnitFrame-Player-Group-GuideIcon"
Group.READY_ATLAS = { ready = "UI-LFG-ReadyMark", notready = "UI-LFG-DeclineMark", waiting = "UI-LFG-PendingMark" }
Group.INCOMING_ATLAS = { resurrect = "RaidFrame-Icon-Rez", summonPending = "RaidFrame-Icon-SummonPending",
    summonAccepted = "RaidFrame-Icon-SummonAccepted", summonDeclined = "RaidFrame-Icon-SummonDeclined",
    phased = "RaidFrame-Icon-Phasing" }

-- "TANK", "HEALER", "DAMAGER", or nil (none, unknown or secret).
function Group.Role(unit)
    local role = Q.Plain(UnitGroupRolesAssigned, unit)
    if Group.ROLE_ATLAS[role] then return role end
end

-- The leader's crown (a guide's in a Dungeon Finder group), or nil.
function Group.LeaderAtlas(unit)
    if not Q.Truthy(UnitIsGroupLeader, unit) then return end
    return Q.Truthy(HasLFGRestrictions) and Group.GUIDE_ATLAS or Group.LEADER_ATLAS
end

-- "ready", "notready", "waiting", or nil when no ready check is running.
function Group.ReadyCheck(unit)
    local status = Q.Plain(GetReadyCheckStatus, unit)
    if Group.READY_ATLAS[status] then return status end
end

-- Summon, resurrection or another phase, in Blizzard's order of importance
-- (CompactUnitFrame_GetCenterStatusIconState): a key of INCOMING_ATLAS or nil.
function Group.Incoming(unit)
    local summon = C_IncomingSummon
    if type(summon) == "table" and Q.Truthy(summon.HasIncomingSummon, unit) then
        local status, statuses = Q.Plain(summon.IncomingSummonStatus, unit), Enum and Enum.SummonStatus
        if statuses and status == statuses.Pending then return "summonPending" end
        if statuses and status == statuses.Accepted then return "summonAccepted" end
        if statuses and status == statuses.Declined then return "summonDeclined" end
    end
    if Q.Truthy(UnitHasIncomingResurrection, unit) then return "resurrect" end
    if Q.Truthy(UnitIsConnected, unit) and Q.Plain(UnitPhaseReason, unit) ~= nil then return "phased" end
end

-- ok, inRange: inRange is secret and goes only to SetAlphaFromBoolean. ok is
-- false when the game can't tell (the API is missing or failed).
function Group.InRange(unit)
    local ok, inRange = Q.Call(UnitInRange, unit)
    if not ok or (Public(inRange) and inRange == nil) then return false end
    return true, inRange
end

-- ok, amount for each: incoming heals from everyone, and absorb shields. The
-- amounts are secret and go only to StatusBar:SetValue.
function Group.IncomingHeals(unit)
    local ok, amount = Q.Call(UnitGetIncomingHeals, unit)
    if not ok or (Public(amount) and amount == nil) then return false end
    return true, amount
end
function Group.Absorbs(unit)
    local ok, amount = Q.Call(UnitGetTotalAbsorbs, unit)
    if not ok or (Public(amount) and amount == nil) then return false end
    return true, amount
end

-- A heal prediction calculator (CreateUnitHealPredictionCalculator), or nil.
-- Its default clamp modes are MissingHealth: heals up to the missing health,
-- and shields up to what's left after them, with a "clamped" flag when the
-- shield is bigger (an overshield).
function Group.NewCalculator()
    local ok, calculator = Q.Call(CreateUnitHealPredictionCalculator)
    if ok and calculator then return calculator end
end

-- Heals, shields and the overshield for a unit, every amount possibly secret
-- (for StatusBar:SetValue) and `overflow` a possibly secret boolean (for
-- SetAlphaFromBoolean). With a calculator (UnitGetDetailedHealPrediction):
-- heals and the shield clamped to the missing health, the total shield for
-- the overshield and whether it overflows. Without one: the plain amounts,
-- and no overshield (overflow false).
function Group.Prediction(unit, calculator)
    local result = {}
    if calculator and Q.Call(UnitGetDetailedHealPrediction, unit, "player", calculator) then
        local ok, max = Q.Call(calculator.GetMaximumHealth, calculator)
        local okHeals, heals = Q.Call(calculator.GetIncomingHeals, calculator)
        local okShield, shield, clamped = Q.Call(calculator.GetDamageAbsorbs, calculator)
        local okTotal, total = Q.Call(calculator.GetTotalDamageAbsorbs, calculator)
        if ok and okHeals and okShield and okTotal then
            result.max, result.heals, result.shield, result.total, result.overflow = max, heals, shield, total, clamped
            result.calculated = true
            return result
        end
    end
    local okMax, max = Q.Call(UnitHealthMax, unit)
    if okMax then result.max = max end
    result.heals = select(2, Group.IncomingHeals(unit))
    result.shield = select(2, Group.Absorbs(unit))
    result.overflow = false
    return result
end

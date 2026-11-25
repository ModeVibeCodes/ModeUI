local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Hide Blizzard's Combat Icon (owner, November 23, 2026; off by default): the
-- game draws its own soft-target icons (the sword on your soft enemy, a mark
-- on your soft friend) on the plates ModeUI leaves to Blizzard. They follow
-- the Accessibility interact-icon CVars, so this sets SoftTargetIconEnemy and
-- SoftTargetIconFriend to 0, remembering what they were (db.savedIconCVars),
-- and puts them back when it is turned off or the module is. Loot and
-- interact icons (SoftTargetIconInteract) stay. It changes a game setting, so
-- it happens only while the switch is on, and only outside combat (a change
-- asked for in combat waits for combat to end).
local Call, Public = addon.Domain.Query.Call, addon.IsPublic
M.combatIconCVars = { "SoftTargetIconEnemy", "SoftTargetIconFriend" }

-- db.savedIconCVars: nil, or the remembered value (a string) of each CVar.
function M.ValidateSavedCVars(db)
    local saved = db.savedIconCVars
    if saved == nil then return end
    assert(Public(saved) and type(saved) == "table", "Invalid nameplate setting: savedIconCVars")
    for _, name in ipairs(M.combatIconCVars) do
        assert(saved[name] == nil or (Public(saved[name]) and type(saved[name]) == "string"), "Invalid nameplate setting: savedIconCVars." .. name)
    end
end

local function Get(name)
    local ok, value = Call(C_CVar and C_CVar.GetCVar, name)
    if not ok then ok, value = Call(GetCVar, name) end
    if ok and Public(value) and type(value) == "string" then return value end
end
local function Set(name, value)
    local ok = Call(C_CVar and C_CVar.SetCVar, name, value)
    if not ok then Call(SetCVar, name, value) end
end

-- Applies the switch: on while the module runs, else the saved values return.
-- In combat it waits for the end of combat (addon.Defer), then applies
-- whatever the switch and the module say by then.
local function Apply(self)
    local db = self.db
    if not db then return end
    if db.hideBlizzardCombatIcon and self.active then
        if type(db.savedIconCVars) ~= "table" then
            local saved = {}
            for _, name in ipairs(self.combatIconCVars) do saved[name] = Get(name) end
            db.savedIconCVars = saved
        end
        for _, name in ipairs(self.combatIconCVars) do if Get(name) ~= "0" then Set(name, "0") end end
    elseif type(db.savedIconCVars) == "table" then
        for _, name in ipairs(self.combatIconCVars) do
            local value = db.savedIconCVars[name]
            if value ~= nil then Set(name, value) end
        end
        db.savedIconCVars = nil
    end
end
function M:ApplyBlizzardIcons()
    if not self.db then return end
    addon.Defer:Run("nameplates:blizzardIcons", function() Apply(self) end)
end

function M:SetHideBlizzardCombatIcon(hidden)
    if not self:CanConfigure() or type(hidden) ~= "boolean" then return false end
    self.db.hideBlizzardCombatIcon = hidden
    self:ApplyBlizzardIcons()
    if self.page then self.page:Refresh() end
    return true
end

local addonName, addon = ...

-- The first Shared file: client identification and the secret-safe value
-- checks every other file uses. Identification is deliberately independent of
-- feature/capability detection.

-- Unit and UI values can be secret on Forever. A secret value may only be
-- passed to widgets documented as accepting one, never compared or inspected.
function addon.IsPublic(value) return not (issecretvalue and issecretvalue(value)) end
local Public = addon.IsPublic

-- A finite, public number, optionally inside [low, high].
function addon.IsNumber(value, low, high)
    if not Public(value) or type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return false end
    return (low == nil or value >= low) and (high == nil or value <= high)
end

-- Combat as the restrictions see it: lockdown, or the player already fighting.
function addon.InCombat() return InCombatLockdown() or UnitAffectingCombat("player") end

local E = {}
addon.Edition = E
local ok, name = false, nil
if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
    ok, name = pcall(C_AddOns.GetAddOnMetadata, addonName, "X-ModeUI-Edition")
end
if ok and Public(name) and (name == "Retail" or name == "Forever") then E.name = name end

function E:CheckClient()
    local expected = self.name == "Forever" and WOW_PROJECT_CAMELOT or
        self.name == "Retail" and WOW_PROJECT_MAINLINE
    -- Never accept nil == nil or infer a client from a broad version range.
    local valid = self.name ~= nil and Public(expected) and type(expected) == "number"
        and Public(WOW_PROJECT_ID) and type(WOW_PROJECT_ID) == "number"
        and WOW_PROJECT_ID == expected
    if valid then return true end
    self.diagnostic = "ModeUI: " .. (self.name or "unidentified") ..
        " package/client mismatch or unavailable project constants; startup blocked before settings migration."
    if not self.reported then
        self.reported = true
        print(self.diagnostic)
    end
    return false
end

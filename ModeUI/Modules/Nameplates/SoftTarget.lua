local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The soft-target icon: the cursor the game would show over the unit (the
-- sword on your soft enemy, the loot bag or gear on your soft interact target),
-- drawn above the plate. Blizzard draws the same icon on its own plates
-- (Blizzard_NamePlates NamePlateDriverMixin:UpdateSoftTargetIconInternal, in
-- UnitFrame.SoftTargetFrame); ModeUI fades that frame with the rest of
-- Blizzard's art, so a ModeUI plate draws its own. Which kinds of soft target
-- get an icon stays the game's choice: the same CVars Blizzard reads
-- (Accessibility's interact icon setting). The soft target is found by
-- comparing nameplate frames, never by a secret unit comparison.
local Kit, NP = addon.Kit, addon.Domain.Nameplate
local Call, Public = addon.Domain.Query.Call, addon.IsPublic

-- Each soft-target unit token and the CVar that turns its icon on.
-- The sword on your soft enemy and the mark on your soft friend are combat
-- icons, shown only with Show Combat Icons (owner, November 23, 2026); loot
-- and interact icons always follow the game's setting.
M.softTargets = { { unit = "softenemy", cvar = "SoftTargetIconEnemy", combat = true },
    { unit = "softfriend", cvar = "SoftTargetIconFriend", combat = true }, { unit = "softinteract", cvar = "SoftTargetIconInteract" } }
M.SOFT_TARGET_SIZE_CVAR = "SoftTargetNameplateSize" -- 0 turns every nameplate icon off
local WATCHED = { [M.SOFT_TARGET_SIZE_CVAR:lower()] = true }
for _, soft in ipairs(M.softTargets) do WATCHED[soft.cvar:lower()] = true end
local EVENTS = { "PLAYER_SOFT_ENEMY_CHANGED", "PLAYER_SOFT_FRIEND_CHANGED", "PLAYER_SOFT_INTERACT_CHANGED" }
local GAMEPAD = "Gamepad.PreferredGamepadInteractTargetChanged"

local function CVar(name)
    local ok, value = Call(C_CVar and C_CVar.GetCVar, name)
    if not ok then ok, value = Call(GetCVar, name) end
    if ok and Public(value) then return value end
end
local function On(name) local value = CVar(name); return value ~= nil and value ~= "0" end

function M:BuildSoftTarget(plate)
    plate.softTarget = plate.textLayer:CreateTexture(nil, "OVERLAY")
    plate.softTarget:Hide()
end

-- Centered above everything on the plate's top edge (the tallest Top stack:
-- Stacks.lua TopStackRoom), then its offset.
function M:LayoutSoftTarget(plate)
    local style, px = self:Style(plate), plate.px or 1
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local size = math.max(px, Round(style.softTargetSize))
    local icon = plate.softTarget
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    local bottom = 2 * px + (plate.above or 0) + Round(self:TopStackRoom(plate)) + Round(style.softTargetY)
    icon:SetPoint("BOTTOM", plate.healthBox, "TOP", Round(style.softTargetX), bottom)
    -- How far the icon reaches above the bar, for the settings preview.
    plate.softTargetTop = bottom + size
end

-- The nameplate frames of the soft targets that get an icon now: each frame
-- maps to "interact" or "combat" (interact wins when a unit is both).
function M:SoftTargetPlates()
    local found = {}
    local size = tonumber(CVar(M.SOFT_TARGET_SIZE_CVAR) or "")
    if not size or size <= 0 then return found end
    for _, soft in ipairs(M.softTargets) do
        if On(soft.cvar) then
            local nameplate = NP.ForUnit(soft.unit)
            if nameplate and found[nameplate] ~= "interact" then found[nameplate] = soft.combat and "combat" or "interact" end
        end
    end
    return found
end

-- The game picks the cursor art (SetUnitCursorTexture) and says whether the
-- unit has one; only a plain true shows the icon.
function M:UpdateSoftTarget(plate, found)
    local icon = plate.softTarget
    if not icon then return end
    found = found or self:SoftTargetPlates()
    local shown = false
    local style, kind = self:Style(plate), found[plate.nameplate]
    if plate.unit and style.showSoftTarget and (kind == "interact" or (kind == "combat" and style.softTargetCombat)) then
        local ok, has = Call(SetUnitCursorTexture, icon, plate.unit, nil, nil, true)
        shown = ok and Public(has) and has == true
    end
    icon:SetShown(shown)
end

function M:UpdateSoftTargets()
    local found = self:SoftTargetPlates()
    for _, plate in pairs(self.byUnit) do self:UpdateSoftTarget(plate, found) end
end

function M:SetSoftTargetEvents(on)
    local registry = type(EventRegistry) == "table" and EventRegistry
    if not on then
        if registry and registry.UnregisterCallback then pcall(registry.UnregisterCallback, registry, GAMEPAD, self) end
        return -- Events:OffAll drops the game events
    end
    local function Update() self:UpdateSoftTargets() end
    for _, event in ipairs(EVENTS) do addon.Events:On(self, event, Update) end
    addon.Events:On(self, "CVAR_UPDATE", function(_, name)
        if Public(name) and type(name) == "string" and WATCHED[name:lower()] then Update() end
    end)
    if registry and registry.RegisterCallback then pcall(registry.RegisterCallback, registry, GAMEPAD, Update, self) end
end

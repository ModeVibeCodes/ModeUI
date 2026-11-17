local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- Blizzard's buff frames by the minimap (Blizzard_BuffFrame, BuffFrame.lua on
-- the Forever branch). While the Buffs bar shows, BuffFrame stops listening
-- (UnregisterAllEvents) and its AuraContainer (every aura button, the weapon
-- enchants), collapse button and consolidated buffs are hidden and kept
-- hidden (Skin.Suppress: hidden again whenever Blizzard shows them); the same
-- for DebuffFrame and the Debuffs bar (its private aura anchors live in its
-- AuraContainer). The parts keep their parents: Blizzard's layout calls
-- AuraContainer:GetParent():UpdateSize(...) (AuraContainerMixin:
-- UpdateGridLayout), from its own updates and from Edit Mode, so moving the
-- container to another parent broke it (owner's in-game report, November 17,
-- 2026: "BuffFrame.lua:177: attempt to call a nil value"). The frames stay
-- where Blizzard's Edit Mode puts them, so the bars can anchor to them. A
-- plain Hide doesn't last: the frames show themselves again on combat
-- changes. Only method calls and post-hooks; no Blizzard method replaced.
-- They come back with a reload.
local L, Skin = addon.L, addon.Skin
M.BLIZZARD_FRAMES = { buffs = "BuffFrame", debuffs = "DebuffFrame" }
local PARTS = { "AuraContainer", "CollapseAndExpandButton", "ConsolidatedBuffs" }

local function Park(self, frame)
    if self.parked[frame] then return end
    pcall(frame.UnregisterAllEvents, frame)
    for _, key in ipairs(PARTS) do
        local part = frame[key]
        if type(part) == "table" and part.Hide then Skin.Suppress(part) end
    end
    self.parked[frame] = true
    self.blizzardParked = true
end

-- Steps Blizzard's frames aside for the bars that show; a frame stepped
-- aside earlier comes back with a reload.
function M:StandIn()
    self.parked = self.parked or {}
    for id, name in pairs(self.BLIZZARD_FRAMES) do
        local frame = _G[name]
        if type(frame) == "table" and frame.UnregisterAllEvents then
            local standIn = self.active == true and self.db.bars[id].show and addon.Kit.HasAuraContainers()
            if standIn then Park(self, frame)
            elseif self.parked[frame] then
                addon.ReloadManager:Request("buffsDebuffs", L["Buffs & Debuffs: reload to give Blizzard's buffs and debuffs back."])
            end
        end
    end
end

local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- Blizzard's buff frames by the minimap (Blizzard_BuffFrame, BuffFrame.lua on
-- the Forever branch). While the Buffs bar shows, BuffFrame stops listening
-- (UnregisterAllEvents) and its AuraContainer (every aura button, the weapon
-- enchants) and the collapse button wait on a hidden frame; the same for
-- DebuffFrame and the Debuffs bar (its private aura anchors live in its
-- AuraContainer). The frames themselves stay where Blizzard's Edit Mode puts
-- them, so the bars can anchor to them. A plain Hide doesn't last: the frames
-- show themselves again on combat changes and the status tray moves
-- BuffFrame. Only method calls; nothing is written to Blizzard's tables, and
-- no Blizzard method is replaced. They come back with a reload.
local L = addon.L
M.BLIZZARD_FRAMES = { buffs = "BuffFrame", debuffs = "DebuffFrame" }
local PARTS = { "AuraContainer", "CollapseAndExpandButton", "ConsolidatedBuffs" }

local function Park(self, frame)
    if self.parked[frame] then return end
    self.hidden = self.hidden or CreateFrame("Frame")
    self.hidden:Hide()
    pcall(frame.UnregisterAllEvents, frame)
    for _, key in ipairs(PARTS) do
        local part = frame[key]
        if type(part) == "table" and part.SetParent then pcall(part.SetParent, part, self.hidden) end
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

local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- Blizzard's own meter. While the module is on with Hide Blizzard's Meter
-- set (the default), Blizzard's meter frame (DamageMeter, which holds its
-- session windows and their spell breakdowns: Blizzard_DamageMeter
-- SetupSessionWindow) goes under a hidden ModeUI frame, so it neither shows
-- nor takes clicks. It keeps running and recording: the game's Damage Meter
-- option (the damageMeterEnabled CVar) is never changed, since ModeUI's
-- windows read the same data. Switching the module or the setting off puts
-- it back where it was. Nothing of Blizzard's is written to, and the frame
-- isn't protected, so this works in combat too.
function M:SyncBlizzard()
    local frame = _G.DamageMeter
    if type(frame) ~= "table" or type(frame.SetParent) ~= "function" or type(frame.GetParent) ~= "function" then return end
    if frame.IsProtected then
        local protected = frame:IsProtected()
        if not addon.IsPublic(protected) or (protected and addon.InCombat()) then self.blizzardPending = true; return end
    end
    self.blizzardPending = nil
    local hide = self.active == true and self.db.hideBlizzard == true
    if hide then
        if not self.hider then self.hider = CreateFrame("Frame", nil, UIParent); self.hider:Hide() end
        if frame:GetParent() ~= self.hider then
            self.blizzardParent = frame:GetParent()
            frame:SetParent(self.hider)
        end
    elseif self.hider and frame:GetParent() == self.hider then
        frame:SetParent(self.blizzardParent or UIParent)
        self.blizzardParent = nil
    end
end

function M:BlizzardHidden()
    local frame = _G.DamageMeter
    return self.hider ~= nil and type(frame) == "table" and frame.GetParent and frame:GetParent() == self.hider or false
end

function M:SetHideBlizzard(hide)
    if type(hide) ~= "boolean" then return false end
    self.db.hideBlizzard = hide
    self:SyncBlizzard()
    if self.page then self.page:Refresh() end
    return true
end

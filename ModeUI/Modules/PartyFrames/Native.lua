local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Blizzard's party frames. On Forever, PartyFrame (an Edit Mode system)
-- holds the pooled member buttons (PartyMemberFrameTemplate, secure), and
-- CompactPartyFrame, the raid-style party frames, is its child
-- (Blizzard_UnitFrame/Shared/PartyFrame.lua, CompactPartyFrame.lua). While
-- ModeUI's party frames are on with Hide Blizzard's Party Frames set,
-- PartyFrame is moved under a hidden frame, outside combat, which hides both
-- styles at once: no Blizzard method is called, no Blizzard table written and
-- no event unregistered, so Edit Mode and the frames keep running unseen.
-- Fading wouldn't do: the members are secure buttons and would keep taking
-- clicks. Turning it off puts PartyFrame back on its own parent.

local function Native() local frame = _G.PartyFrame; return type(frame) == "table" and frame.SetParent and frame or nil end

function M:BlizzardHidden() return self.nativeParent ~= nil end

function M:SyncNative()
    local frame = Native()
    if not frame then return end
    if addon.InCombat() then self.pending = true; return end
    local hide = self.active == true and self.db.hideBlizzard == true
    if hide then
        if not self.hiddenParent then
            self.hiddenParent = CreateFrame("Frame", "ModeUIPartyFramesHiddenParent", UIParent)
            self.hiddenParent:Hide()
        end
        local parent = frame:GetParent()
        if parent == self.hiddenParent then return end
        if not addon.IsPublic(parent) or not parent then parent = UIParent end
        if pcall(frame.SetParent, frame, self.hiddenParent) then self.nativeParent = parent end
    elseif self.nativeParent then
        local parent = self.nativeParent
        self.nativeParent = nil
        if frame:GetParent() == self.hiddenParent then pcall(frame.SetParent, frame, parent) end
    end
end

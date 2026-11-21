local _, addon = ...
local PM, P = addon.PositionManager, addon.Positioning

-- The profile's places win over the client's own layout cache (owner,
-- November 20, 2026: after a profile switch the Cooldown Manager's bars sat at
-- the old profile's places until Edit Mode, and the Player and Target frames
-- away from their Edit Mode stand-ins).
--
-- The client keeps the place of every named frame moved with StartMoving
-- ("user placed") in WTF\...\layout-local.txt and puts it back at the next
-- login, after ModeUI has placed it. Edit Mode drags ModeUI's movers and
-- stand-ins that way, so each one it had ever moved came back at its old
-- place, and the anchor cache in Positioning.ApplyFrame kept ModeUI from
-- placing it again. So:
--   * an element's frame is never saved by the client (SetDontSavePosition,
--     and user placed cleared at registration and after each drag);
--   * once the client has finished restoring frames (the first frame after
--     PLAYER_ENTERING_WORLD, and once more a moment later), every element is
--     placed again from the profile and its module told, so the secure frames
--     that copy their stand-in's anchor (unit frames, party frames, action
--     bars) copy the profile's.
local Combat = addon.InCombat

function PM:KeepOutOfLayoutCache(frame)
    if type(frame) ~= "table" then return end
    if frame.SetDontSavePosition then pcall(frame.SetDontSavePosition, frame, true) end
    if frame.SetUserPlaced and frame.IsMovable and frame:IsMovable() then pcall(frame.SetUserPlaced, frame, false) end
end

local register = PM.RegisterElement
function PM:RegisterElement(id, frame, options)
    local ok, element = register(self, id, frame, options)
    if ok then self:KeepOutOfLayoutCache(frame) end
    return ok, element
end

-- Places every element again from its saved position (whatever moved its
-- frame since) and tells each module, out of combat.
function PM:Reassert()
    if Combat() then self.pending = true; P.pending = true; return false end
    for _, id in ipairs(self.order) do
        local element = self.elements[id]
        if element and not element.legacy and not element.dragging then
            self:KeepOutOfLayoutCache(element.frame)
            element.subject.appliedAnchor = nil
            self:ApplyPosition(id, true)
            if element.onPositionChanged and not element.notifying then
                element.notifying = true
                local ok, message = pcall(element.onPositionChanged, element, self:GetPosition(id))
                element.notifying = false
                if not ok then print("ModeUI: position callback failed: " .. tostring(message)) end
            end
        end
    end
    self:NotifyPosition()
    return true
end

local function Later(delay)
    if C_Timer and C_Timer.After then C_Timer.After(delay, function() PM:Reassert() end) else PM:Reassert() end
end
addon.Events:On(PM, "PLAYER_ENTERING_WORLD", function()
    if not addon.initialized then return end
    Later(0)
    Later(1)
end)

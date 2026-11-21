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
    if ok then
        self:KeepOutOfLayoutCache(frame)
        -- A size change moves its edges: what hangs from them follows (below).
        if not frame.modeSizeWatch and frame.HookScript then
            frame.modeSizeWatch = true
            frame:HookScript("OnSizeChanged", function(f)
                local watched = self.frames[f]
                if watched and not self.cascading then self:Cascade(watched) end
            end)
        end
    end
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

-- An element hung from another (the healer party column from the Player
-- frame's bar block) follows it on screen through its anchor, but a module
-- that copies its stand-in onto a secure frame only hears about its own
-- moves. So a move tells the elements anchored to it as well (and theirs).
local notify = PM.NotifyPosition
function PM:NotifyPosition(id, changed)
    notify(self, id, changed)
    if changed and id then self:Cascade(id) end
end
-- Each element anchored to `id` (or to its bar block), and theirs: placed
-- again from its saved position, then its module told. Outside combat.
function PM:Cascade(id)
    if self.cascading or Combat() then return end
    self.cascading = true
    local seen, queue = { [id] = true }, { id }
    while #queue > 0 do
        local moved = table.remove(queue, 1)
        for _, other in ipairs(self.order) do
            local element = self.elements[other]
            -- A Unit Frames element and its bar block share one stand-in.
            local target = element and element.position.target
            if element and not seen[other] and (target == moved or (target and target:find("^" .. moved .. "Bars$"))) then
                seen[other] = true
                queue[#queue + 1] = other
                element.subject.appliedAnchor = nil
                self:ApplyPosition(other, true)
                if element.onPositionChanged and not element.notifying then
                    element.notifying = true
                    local ok, message = pcall(element.onPositionChanged, element, self:GetPosition(other))
                    element.notifying = false
                    if not ok then print("ModeUI: position callback failed: " .. tostring(message)) end
                end
            end
        end
    end
    self.cascading = false
end

local function Later(delay)
    if C_Timer and C_Timer.After then C_Timer.After(delay, function() PM:Reassert() end) else PM:Reassert() end
end
addon.Events:On(PM, "PLAYER_ENTERING_WORLD", function()
    if not addon.initialized then return end
    Later(0)
    Later(1)
end)

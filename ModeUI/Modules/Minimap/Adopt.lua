local _, addon = ...
local M = addon.Minimap
if not M then return end

-- Moving Blizzard's frames onto ModeUI's. Adopt reparents a frame and places
-- it now, and again right after Blizzard re-anchors, reparents or rescales
-- it (post-hooks, installed once per frame). Stash puts a frame under a
-- hidden ModeUI frame the same way, so Blizzard's own code keeps running on
-- it unseen. Where each frame goes lives in weak tables here; nothing else
-- is written on Blizzard's frames. Protected frames wait for the end of
-- combat (none of the minimap's are protected on Forever, but the check is
-- cheap).
local places = setmetatable({}, { __mode = "k" })
local busy = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })

local function Protected(frame)
    if not frame.IsProtected then return false end
    local protected = frame:IsProtected()
    return not addon.IsPublic(protected) or protected == true
end

local function Apply(frame)
    local place = places[frame]
    if not place or busy[frame] or not M.active then return end
    if Protected(frame) and addon.InCombat() then
        addon.Defer:Run("minimap:adopt", function() M:ApplyAdopted() end)
        return
    end
    busy[frame] = true
    if frame:GetParent() ~= place.parent then frame:SetParent(place.parent) end
    frame:ClearAllPoints()
    place.place(frame)
    if place.scale and frame:GetScale() ~= place.scale then frame:SetScale(place.scale) end
    busy[frame] = nil
end

-- place(frame) sets the frame's points; scale (optional) is kept too.
function M:Adopt(frame, parent, place, scale)
    if not frame or not parent then return false end
    places[frame] = { parent = parent, place = place, scale = scale }
    if not hooked[frame] then
        hooked[frame] = true
        for _, method in ipairs({ "SetPoint", "SetParent", "SetScale" }) do
            if frame[method] then hooksecurefunc(frame, method, Apply) end
        end
    end
    Apply(frame)
    return true
end

-- Places an adopted frame again (after its parent or scale changes).
function M:Replace(frame, place, scale)
    local entry = places[frame]
    if not entry then return end
    entry.place = place or entry.place
    entry.scale = scale or entry.scale
    Apply(frame)
end

function M:ApplyAdopted()
    for frame in pairs(places) do Apply(frame) end
end

function M:Adopted(frame) return places[frame] ~= nil end

function M:HiddenParent()
    if not self.hiddenParent then
        self.hiddenParent = CreateFrame("Frame", nil, UIParent)
        self.hiddenParent:Hide()
    end
    return self.hiddenParent
end

function M:Stash(frame)
    return self:Adopt(frame, self:HiddenParent(), function(f) f:SetPoint("CENTER") end)
end

-- Calls fn(source) whenever Blizzard shows or hides `source` (method
-- post-hooks, so it runs even while an ancestor is hidden).
local followed = setmetatable({}, { __mode = "k" })
function M:FollowShown(source, fn)
    if not source or followed[source] then return end
    followed[source] = true
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        if source[method] then hooksecurefunc(source, method, function() if M.active then fn(source) end end) end
    end
end

local _, addon = ...
local M = addon.Bags
if not M then return end

-- Blizzard's bag frames. Blizzard keeps deciding when bags open and close:
-- the B key, the bag bar, vendors, mail, the bank and Esc all call its own
-- functions (OpenAllBags, ToggleAllBags, CloseAllBags...), which show and
-- hide its frames (ContainerFrameCombinedBags and ContainerFrame1-N). While
-- the module is on, every one of those frames that holds the backpack, an
-- equipped bag, the reagent bag or the keyring waits under a hidden ModeUI
-- frame, so it never draws or takes clicks, and ModeUI's window shows while
-- any of them is shown. A frame Blizzard reuses for another container (a
-- bank bag) goes back under its own parent. Blizzard moves its bag frames
-- under the fullscreen frame of the moment (ContainerFrame_SetFullScreenFrame
-- and _ClearFullScreenFrame); ModeUI takes them back after it does. Every
-- hook is a post-hook and nothing is written to Blizzard's tables: the old
-- parents live in a weak table keyed by the frame. The frames aren't
-- protected (Blizzard's source), so this works in combat too; a frame the
-- client reports as protected waits for the end of combat.
local Containers = addon.Domain.Containers
M.parents = setmetatable({}, { __mode = "k" })

-- Blizzard's bag frames that exist on this client.
function M:BlizzardFrames()
    local list = {}
    local combined = _G.ContainerFrameCombinedBags
    if type(combined) == "table" and combined.SetParent then list[#list + 1] = combined end
    for i = 1, 20 do
        local frame = _G["ContainerFrame" .. i]
        if type(frame) ~= "table" then break end
        if frame.SetParent then list[#list + 1] = frame end
    end
    return list
end

-- Whether a Blizzard frame holds one of the bags ModeUI's window shows. The
-- combined frame only ever holds them; the others carry their bag's ID.
function M:HoldsBag(frame)
    if frame == _G.ContainerFrameCombinedBags then return true end
    local ok, id = pcall(frame.GetID, frame)
    return ok and Containers.IsHeld(id)
end

local function Shown(frame)
    local shown = frame:IsShown()
    return addon.IsPublic(shown) and shown == true
end
local function Blocked(frame)
    if not frame.IsProtected then return false end
    local protected = frame:IsProtected()
    return not addon.IsPublic(protected) or (protected and addon.InCombat())
end

-- Puts each Blizzard frame under ModeUI's hidden frame or back under its own.
function M:Capture()
    local pending = false
    for _, frame in ipairs(self:BlizzardFrames()) do
        local hide = self.active == true and self:HoldsBag(frame)
        local parent = frame:GetParent()
        if hide and parent ~= self.hider then
            if Blocked(frame) then pending = true else
                if not self.hider then self.hider = CreateFrame("Frame", nil, UIParent); self.hider:Hide() end
                self.parents[frame] = parent
                frame:SetParent(self.hider)
            end
        elseif not hide and self.hider and parent == self.hider then
            if Blocked(frame) then pending = true else
                frame:SetParent(self.parents[frame] or UIParent)
                self.parents[frame] = nil
            end
        end
    end
    self.capturePending = pending or nil
end

-- Whether Blizzard has any of the shown bags open.
function M:BlizzardOpen()
    for _, frame in ipairs(self:BlizzardFrames()) do
        if Shown(frame) and self:HoldsBag(frame) then return true end
    end
    return false
end

-- Blizzard showed or hid a bag frame: take it, then show or hide the window.
function M:BlizzardChanged()
    if not self.active then return end
    self:Capture()
    self:SetOpen(self:BlizzardOpen())
end

-- Post-hooks, installed once; each does nothing while the module is off.
function M:HookBlizzard()
    if self.blizzardHooked or not hooksecurefunc then return end
    self.blizzardHooked = true
    local function Changed() M:BlizzardChanged() end
    for _, frame in ipairs(self:BlizzardFrames()) do
        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
            if type(frame[method]) == "function" then hooksecurefunc(frame, method, Changed) end
        end
    end
    for _, name in ipairs({ "ContainerFrame_SetFullScreenFrame", "ContainerFrame_ClearFullScreenFrame" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, Changed) end
    end
end

-- The window's close button and Close All: Blizzard closes its bags, and
-- the window follows.
function M:CloseBags()
    if type(CloseAllBags) == "function" then CloseAllBags() end
    -- In case Blizzard's frames were already closed (or missing).
    self:SetOpen(self:BlizzardOpen())
end

-- The settings page's Show Bags button: Blizzard opens its bags (out of
-- combat; Blizzard refuses while bags can't open).
function M:OpenBags()
    if addon.InCombat() then return false end
    if type(OpenAllBags) == "function" then OpenAllBags() end
    self:BlizzardChanged()
    return self.open == true
end

local _, addon = ...
local PM, P = addon.PositionManager, addon.Positioning

-- Anchor width tracking: elements that size themselves to the frame they are
-- anchored to (matched width) are told when that frame's width changes.
local Combat = addon.InCombat
local function Lookup(self, id) return self:Element(id) end

-- Width in UIParent units. Screen/missing/restricted targets have no matched width.
function PM:GetAnchorWidth(id)
    local element = Lookup(self, id)
    if not element then return nil, "unknown-element" end
    if Combat() then return nil, "combat" end
    if element.position.target == "screen" then return nil, "screen" end
    local target = P:Resolve(element.position.target)
    if element.sizeCallback and element.sizeObserver and element.sizeTarget ~= target then return nil, "observer-unavailable" end
    local _, _, width = P:Geometry(target)
    return width
end

-- A hidden, addon-owned two-point frame receives native size changes. Never hook
-- or resize the target. No polling; inaccessible geometry defers/falls back.
function PM:SetAnchorSizeListener(id, callback)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if Combat() then return false, "combat" end
    if callback ~= nil and type(callback) ~= "function" then return false, "invalid-callback" end
    element.sizeCallback = callback
    self:RefreshAnchorSize(id)
    return true
end

function PM:RefreshAnchorSize(id)
    local element = Lookup(self, id)
    if not element then return end
    if Combat() then self.pending = true; return end
    local target = element.sizeCallback and element.position.target ~= "screen" and P:Resolve(element.position.target) or nil
    if not element.sizeObserver and target then
        local observer = CreateFrame("Frame", nil, UIParent)
        observer:EnableMouse(false); observer:Hide()
        element.sizeObserver = observer
        observer:SetScript("OnSizeChanged", function() self:RefreshAnchorSize(id) end)
    end
    if element.sizeObserver and element.sizeTarget ~= target then
        element.sizeTarget = target
        local observer = element.sizeObserver
        observer:ClearAllPoints()
        if target then
            local ok = pcall(function()
                observer:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
                observer:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
            end)
            if not ok then observer:ClearAllPoints(); element.sizeTarget = nil end
        end
    end
    local width = target and self:GetAnchorWidth(id) or nil
    if element.lastAnchorWidth ~= width then
        element.lastAnchorWidth = width
        if element.sizeCallback then
            local ok, message = pcall(element.sizeCallback, element, width)
            if not ok then print("ModeUI: anchor size callback failed: " .. tostring(message)) end
        end
    end
end

-- The element a target id stands for, when it is another ModeUI element's
-- frame (a target added with Positioning:AddTarget).
local function ElementOf(self, target)
    for _, item in ipairs(P.targets) do
        if item.id == target then
            local frame = _G[item.name]
            return frame and self.frames[frame]
        end
    end
end

-- Whether anchoring `id` to `target` would close a loop: the target, or
-- something it hangs from, already hangs from `id`.
function PM:WouldLoop(id, target)
    local current = target
    for _ = 1, 32 do
        local other = ElementOf(self, current)
        if not other then return false end
        if other == id then return true end
        current = self.elements[other] and self.elements[other].position.target
    end
    return true
end

-- Anchoring to another element (Edit Mode's target list, Anchor To and its
-- side choices): the element goes onto the chosen side of the target with
-- X and Y back at 0, so it sits right there whatever its old offsets were.
-- Without a side it goes Above a new target (or keeps its side on the same
-- one). Choosing the Screen from another target keeps it where it is.
-- point/relativePoint (both or neither) line up edges, e.g. Above with the
-- left edges together.
function PM:AnchorTo(id, target, placement, point, relativePoint)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if Combat() then return false, "combat" end
    local position, reason = self:GetPosition(id)
    if not position then return false, reason end
    if placement == nil then
        if target == position.target then return true, "unchanged" end
        if target == "screen" then return self:DetachAnchor(id) end
        placement = "above"
    end
    if target ~= "screen" and self:WouldLoop(id, target) then return false, "anchor-loop" end
    position.target, position.placement, position.point, position.relativePoint = target, placement, point, relativePoint
    position.x, position.y = 0, 0
    return self:SetPosition(id, position, true)
end

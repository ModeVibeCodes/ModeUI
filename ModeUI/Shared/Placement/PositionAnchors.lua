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

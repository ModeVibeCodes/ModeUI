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

-- Match Width and Match Height in the Edit Mode window, for elements whose
-- module can size them to what they're anchored on. handlers: axes
-- ({ width = true, height = true }), get(axis), set(axis, on), and optionally
-- available() (false hides the choice for now). The module does the sizing.
function PM:SetSizeMatch(id, handlers)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if handlers ~= nil and (type(handlers) ~= "table" or type(handlers.axes) ~= "table"
        or type(handlers.get) ~= "function" or type(handlers.set) ~= "function") then return false, "invalid-handlers" end
    element.sizeMatch = handlers
    return true
end

-- Whether the element can match its anchor's size on an axis right now: the
-- module offers it and the element hangs from something other than the screen.
function PM:CanMatchSize(id, axis)
    local element = Lookup(self, id)
    local match = element and element.sizeMatch
    if not match or not match.axes[axis] or element.position.target == "screen" then return false end
    if match.available then
        local ok, available = pcall(match.available)
        if not ok or available ~= true then return false end
    end
    return true
end

function PM:GetSizeMatch(id, axis)
    if not self:CanMatchSize(id, axis) then return false end
    local ok, on = pcall(self.elements[id].sizeMatch.get, axis)
    return ok and on == true
end

function PM:SetSizeMatchValue(id, axis, on)
    if Combat() then return false, "combat" end
    if not self:CanMatchSize(id, axis) then return false, "unavailable" end
    local ok, result = pcall(self.elements[id].sizeMatch.set, axis, on == true)
    self:NotifyPosition(id, false)
    return ok and result ~= false
end

-- Anchored chains stay on screen. When an element (or what it hangs from)
-- moves, each element anchored Above, Below, Left or Right of another is
-- checked where its side would put it: off the screen, or over the frame its
-- parent hangs from (a stack folding back onto itself). If the opposite side
-- is clear, the element switches to it (its offset on that axis mirrored),
-- overriding the side it had. Then the same check runs down the chain, so a
-- stack moved to the bottom edge grows upward instead of piling up there.
local FLIP = { above = "below", below = "above", left = "right", right = "left" }
local VERTICAL = { above = true, below = true }
local SWAP = {
    v = { TOP = "BOTTOM", BOTTOM = "TOP", TOPLEFT = "BOTTOMLEFT", BOTTOMLEFT = "TOPLEFT", TOPRIGHT = "BOTTOMRIGHT", BOTTOMRIGHT = "TOPRIGHT" },
    h = { LEFT = "RIGHT", RIGHT = "LEFT", TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT" },
}
local SLACK = 0.5 -- UI units of rounding allowed at an edge or overlap

-- Where the element's center would be for a position, in UIParent units.
local function Placed(element, position, parent)
    local tx, ty, tw, th = P:Geometry(parent)
    local _, _, width, height = P:Geometry(element.frame)
    if not tx or not width then return end
    local point, relative = P:Attachment(position, element.subject.originPoint)
    local a, b = P.vectors[point], P.vectors[relative]
    if not a or not b then return end
    return tx + b[1] * tw - a[1] * width + (position.x or 0), ty + b[2] * th - a[2] * height + (position.y or 0), width, height
end

local function Clear(element, position, parent, avoid)
    local x, y, width, height = Placed(element, position, parent)
    if not x then return nil end
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if x - width / 2 < -SLACK or x + width / 2 > sw + SLACK or y - height / 2 < -SLACK or y + height / 2 > sh + SLACK then return false end
    local ax, ay, aw, ah = P:Geometry(avoid)
    if ax and math.abs(x - ax) < (width + aw) / 2 - SLACK and math.abs(y - ay) < (height + ah) / 2 - SLACK then return false end
    return true
end

local function Flipped(position)
    local flipped = {}
    for key, value in pairs(position) do flipped[key] = value end
    local vertical = VERTICAL[position.placement]
    flipped.placement = FLIP[position.placement]
    local swap = vertical and SWAP.v or SWAP.h
    if flipped.point then flipped.point, flipped.relativePoint = swap[flipped.point] or flipped.point, swap[flipped.relativePoint] or flipped.relativePoint end
    if vertical then flipped.y = -(flipped.y or 0) else flipped.x = -(flipped.x or 0) end
    return flipped
end

function PM:FitAnchored(id, depth)
    depth = depth or 0
    local element = Lookup(self, id)
    if not element or element.legacy or depth > 32 or Combat() then return end
    local position = element.position
    local parent = position.target ~= "screen" and FLIP[position.placement] and P:Resolve(position.target)
    if parent then
        local parentId = ElementOf(self, position.target)
        local grand = parentId and self.elements[parentId].position.target
        local avoid = grand and grand ~= "screen" and P:Resolve(grand) or nil
        if Clear(element, position, parent, avoid) == false then
            local flipped = Flipped(position)
            if Clear(element, flipped, parent, avoid) then
                for _, key in ipairs({ "x", "y", "placement", "point", "relativePoint" }) do position[key] = flipped[key] end
                self:ApplyPosition(id, true)
                self:NotifyPosition(id, true)
            end
        end
    end
    for _, other in ipairs(self.order) do
        if other ~= id and ElementOf(self, self.elements[other].position.target) == id then self:FitAnchored(other, depth + 1) end
    end
end

local _, addon = ...
local PM, P = addon.PositionManager, addon.Positioning

-- Match Width and Match Height (Edit Mode). A module that can size an element
-- offers them (SetSizeMatch) and does the sizing; Position Manager says which
-- element each axis follows and tells the module whenever that element's size
-- changes (SetAnchorSizeListener: callback(element, width, height), from the
-- followed frames' own OnSizeChanged through observer frames, never polling).
-- Each axis follows the element picked for it in Edit Mode (click Match
-- Width, then the element), whatever the element hangs from, saved in the
-- profile's sizeMatches ({ [id] = { width = target, height = target } }).
-- Without a pick (matches made before November 15, 2026, and a module's own
-- Match switch) an axis follows what the element hangs from, as before.
local Combat = addon.InCombat
local AXES = { "width", "height" }
local function Lookup(self, id) return self:Element(id) end
local function Saved(id)
    local all = addon.db and addon.db.sizeMatches
    return type(all) == "table" and type(all[id]) == "table" and all[id] or nil
end

-- The target id an axis follows, and whether it was picked (true) or is the
-- element's anchor (false); nil when there's nothing to follow.
function PM:GetSizeMatchTarget(id, axis)
    local element = Lookup(self, id)
    if not element then return end
    local saved = Saved(id)
    if saved and type(saved[axis]) == "string" then return saved[axis], true end
    if element.position.target ~= "screen" then return element.position.target, false end
end

local function Followed(self, id, axis)
    local target = self:GetSizeMatchTarget(id, axis)
    local frame = target and P:Resolve(target)
    local element = Lookup(self, id)
    if frame and element and frame ~= element.frame then return frame end
end

-- The width an element would match, in UIParent units (nil in combat, or
-- with nothing to follow). The name is older than picked targets.
function PM:GetAnchorWidth(id)
    local element = Lookup(self, id)
    if not element then return nil, "unknown-element" end
    if Combat() then return nil, "combat" end
    local frame = Followed(self, id, "width")
    if not frame then return nil, "no-target" end
    local observer = element.sizeObservers and element.sizeObservers.width
    if element.sizeCallback and observer and observer.followed ~= frame then return nil, "observer-unavailable" end
    local _, _, width = P:Geometry(frame)
    return width
end

-- Hidden, addon-owned two-point frames receive the followed frames' native
-- size changes. Never hook or resize the target.
function PM:SetAnchorSizeListener(id, callback)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if Combat() then return false, "combat" end
    if callback ~= nil and type(callback) ~= "function" then return false, "invalid-callback" end
    element.sizeCallback = callback
    self:RefreshAnchorSize(id)
    return true
end

local function Observe(self, id, element, axis, frame)
    element.sizeObservers = element.sizeObservers or {}
    local observer = element.sizeObservers[axis]
    if not observer and frame then
        observer = CreateFrame("Frame", nil, UIParent)
        observer:EnableMouse(false); observer:Hide()
        observer:SetScript("OnSizeChanged", function() self:RefreshAnchorSize(id) end)
        element.sizeObservers[axis] = observer
    end
    if observer and observer.followed ~= frame then
        observer.followed = frame
        observer:ClearAllPoints()
        if frame and not pcall(function()
            observer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            observer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        end) then observer:ClearAllPoints(); observer.followed = nil end
    end
    return observer and observer.followed == frame and frame ~= nil
end

function PM:RefreshAnchorSize(id)
    local element = Lookup(self, id)
    if not element then return end
    if Combat() then self.pending = true; return end
    local size = {}
    for _, axis in ipairs(AXES) do
        local frame = element.sizeCallback and Followed(self, id, axis) or nil
        if Observe(self, id, element, axis, frame) then
            local _, _, width, height = P:Geometry(frame)
            size[axis] = axis == "width" and width or height
        end
    end
    if element.lastAnchorWidth ~= size.width or element.lastAnchorHeight ~= size.height then
        element.lastAnchorWidth, element.lastAnchorHeight = size.width, size.height
        if element.sizeCallback then
            local ok, message = pcall(element.sizeCallback, element, size.width, size.height)
            if not ok then print("ModeUI: anchor size callback failed: " .. tostring(message)) end
        end
    end
end

-- handlers: axes ({ width = true, height = true }), get(axis), set(axis, on),
-- and optionally available() (false hides the choice for now).
function PM:SetSizeMatch(id, handlers)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if handlers ~= nil and (type(handlers) ~= "table" or type(handlers.axes) ~= "table"
        or type(handlers.get) ~= "function" or type(handlers.set) ~= "function") then return false, "invalid-handlers" end
    element.sizeMatch = handlers
    return true
end

-- Whether the module offers matching on an axis right now.
function PM:CanMatchSize(id, axis)
    local element = Lookup(self, id)
    local match = element and element.sizeMatch
    if not match or not match.axes[axis] then return false end
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

local function Store(id, axis, target)
    local db = addon.db
    db.sizeMatches = type(db.sizeMatches) == "table" and db.sizeMatches or {}
    local saved = db.sizeMatches[id] or {}
    saved[axis] = target
    db.sizeMatches[id] = next(saved) and saved or nil
end

-- Switches matching on an axis on or off. Off forgets the picked target.
function PM:SetSizeMatchValue(id, axis, on)
    if Combat() then return false, "combat" end
    if not self:CanMatchSize(id, axis) then return false, "unavailable" end
    if not on then Store(id, axis, nil) end
    local ok, result = pcall(self.elements[id].sizeMatch.set, axis, on == true)
    self:RefreshAnchorSize(id)
    self:NotifyPosition(id, false)
    return ok and result ~= false
end

-- The id of the element whose frame a target stands for, if any.
local function Owner(self, target)
    local frame = P:Resolve(target)
    return frame and self.frames[frame]
end

-- Edit Mode's pick: the axis follows `target` (any ModeUI element, even for
-- an element that can't hang from it, or a frame the element may hang from)
-- and matching goes on. Two elements following
-- each other on one axis would chase each other, so that's refused.
function PM:SetSizeMatchTarget(id, axis, target)
    if Combat() then return false, "combat" end
    local element = Lookup(self, id)
    if not element or not self:CanMatchSize(id, axis) then return false, "unavailable" end
    local listed = false
    for _, item in ipairs(P.targets) do if item.id == target then listed = true end end
    local allowed = listed or element.allowedTargets[target] or (element.allowedTargets.selected and addon.FrameAnchors:ValidID(target))
    local frame = type(target) == "string" and target ~= "screen" and allowed and P:Resolve(target)
    if not frame or frame == element.frame then return false, "invalid-target" end
    local owner = Owner(self, target)
    if owner and self:GetSizeMatch(owner, axis) and self:GetSizeMatchTarget(owner, axis) == id then return false, "loop" end
    Store(id, axis, target)
    local ok, result = pcall(element.sizeMatch.set, axis, true)
    if not ok or result == false then Store(id, axis, nil) end
    self:RefreshAnchorSize(id)
    self:NotifyPosition(id, false)
    return ok and result ~= false, not ok and "rejected" or nil
end

-- Profile check: sizeMatches holds { width, height } target ids per element.
function PM.ValidSizeMatches(value)
    if type(value) ~= "table" then return false end
    for id, axes in pairs(value) do
        if type(id) ~= "string" or #id > 200 or type(axes) ~= "table" then return false end
        for axis, target in pairs(axes) do
            if (axis ~= "width" and axis ~= "height") or type(target) ~= "string" or target == "" or #target > 200 then return false end
        end
    end
    return true
end

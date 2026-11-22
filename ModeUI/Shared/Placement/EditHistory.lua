local _, addon = ...
local PM, E = addon.PositionManager, addon.EditMode

-- Undo and Redo in Edit Mode (docs/DESIGN_LANGUAGE.md, "Edit Mode"): every
-- element's place (target, side, offsets) and Match Width/Height picks, as
-- they were before each change made while Edit Mode is open (drags, nudges,
-- typed offsets, Place changes, Anchor To, matches). The history starts
-- empty each time Edit Mode opens and lasts until it closes. Positions are
-- restored through PositionManager, so they're validated and saved as usual.
local H = { undo = {}, redo = {}, LIMIT = 100 }
E.history = H
local Copy = addon.ProfileCodec.Copy
local AXES = { "width", "height" }

-- A canonical text of a value, to compare snapshots.
local function Text(value)
    if type(value) ~= "table" then return tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. Text(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- Every element's place and matches now: { [id] = { position, width, height } }.
local function Capture()
    local snapshot = {}
    for id, element in pairs(PM.elements) do
        if not element.legacy then
            local entry = { position = Copy(element.position) }
            for _, axis in ipairs(AXES) do
                if PM:CanMatchSize(id, axis) then
                    local target, picked = PM:GetSizeMatchTarget(id, axis)
                    entry[axis] = { on = PM:GetSizeMatch(id, axis), target = picked and target or nil }
                end
            end
            snapshot[id] = entry
        end
    end
    return snapshot, Text(snapshot)
end

local function Dragging()
    for _, element in pairs(PM.elements) do if element.dragging then return true end end
    return false
end

-- Starts a fresh history (Edit Mode opening).
function H:Begin()
    self.undo, self.redo = {}, {}
    self.last, self.lastText = Capture()
end

-- After any position notification: a change since the last snapshot goes on
-- the undo stack (a drag counts once, when it's dropped).
function H:Track()
    if not addon.editMode or self.restoring or not self.last or Dragging() then return end
    local snapshot, text = Capture()
    if text == self.lastText then return end
    self.undo[#self.undo + 1] = self.last
    if #self.undo > self.LIMIT then table.remove(self.undo, 1) end
    self.redo = {}
    self.last, self.lastText = snapshot, text
    -- Undo and Redo light up.
    if addon.RefreshEditWindow then addon:RefreshEditWindow() end
end

-- Puts every element back as in `snapshot`.
local function Restore(snapshot)
    for id, entry in pairs(snapshot) do
        local element = PM.elements[id]
        if element and not element.legacy then
            if Text(entry.position) ~= Text(element.position) then PM:SetPosition(id, entry.position, true) end
            for _, axis in ipairs(AXES) do
                local match = entry[axis]
                if match then
                    local target, picked = PM:GetSizeMatchTarget(id, axis)
                    local on = PM:GetSizeMatch(id, axis)
                    if match.on and match.target and (not on or not picked or target ~= match.target) then
                        PM:SetSizeMatchTarget(id, axis, match.target)
                    elseif match.on ~= on and not match.target then PM:SetSizeMatchValue(id, axis, match.on)
                    elseif not match.on and on then PM:SetSizeMatchValue(id, axis, false) end
                end
            end
        end
    end
end

local function Step(self, from, to)
    if addon.InCombat() or not addon.editMode or #from == 0 then return false end
    local snapshot = table.remove(from)
    to[#to + 1] = self.last
    self.restoring = true
    local ok, message = pcall(Restore, snapshot)
    self.restoring = false
    if not ok then print("ModeUI: undo failed: " .. tostring(message)) end
    -- What actually took (a target that went away stays where it is).
    self.last, self.lastText = Capture()
    addon.PositionManager:RefreshSelection()
    return ok
end
function H:Undo() return Step(self, self.undo, self.redo) end
function H:Redo() return Step(self, self.redo, self.undo) end
function H:CanUndo() return #self.undo > 0 end
function H:CanRedo() return #self.redo > 0 end

-- Every position notification is a chance to record a change.
local notify = PM.NotifyPosition
function PM:NotifyPosition(id, changed)
    notify(self, id, changed)
    H:Track()
end

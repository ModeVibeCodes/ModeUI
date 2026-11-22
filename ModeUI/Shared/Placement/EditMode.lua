local _, addon = ...
local E = { highlights = true }
addon.EditMode = E
-- Switching a module on or off adds or removes its movable frames.
addon.RegisterMessage(E, addon.Messages.MODULE_TOGGLED, function() E:RefreshElements() end)

function E:RegisterElement(module, frame)
    -- Compatibility for consumers of the earlier module-owned position contract.
    return addon.PositionManager:RegisterElement(module.id, frame, { moduleId = module.id,
        legacyPosition = true, legacy = true, anchoring = false,
        defaultPosition = module.db.position or { x = 0, y = 0 } })
end

function E:Selected()
    return addon.PositionManager:GetSelectedElement()
end

function E:Select(id)
    return addon.PositionManager:SelectElement(id)
end

function E:RefreshElements()
    addon.PositionManager:RefreshSelection()
end

function E:NotifyPosition()
    addon.PositionManager:NotifyPosition()
end

function E:SetHighlights(show)
    self.highlights = show
    self:RefreshElements()
end

-- Names and Focus (docs/DESIGN_LANGUAGE.md, "Edit Mode"), saved for the
-- account (ModeUIDB.editMode). Names: inside each element, where they fit
-- (EditLabels.lua), only under the mouse, or off. Focus: the dim around the
-- selected element (EditFocus.lua). An unknown saved value reads as the default.
E.NAMES = { { id = "inside", label = "Inside" }, { id = "fit", label = "Fit" }, { id = "hover", label = "On Hover" },
    { id = "none", label = "Off" } }
E.FOCUS = { { id = "off", label = "Off" }, { id = "dim", label = "Dim" }, { id = "strong", label = "Strong" } }
local function Choice(list, id)
    for _, choice in ipairs(list) do if choice.id == id then return choice end end
end
local function Saved() return addon.root and addon.root.editMode end
function E:Names()
    local saved = Saved()
    return saved and Choice(self.NAMES, saved.names) and saved.names or "inside"
end
function E:Focus()
    local saved = Saved()
    return saved and Choice(self.FOCUS, saved.focus) and saved.focus or "strong"
end
function E:ChoiceLabel(list, id) local choice = Choice(list, id); return choice and choice.label or "" end
function E:SetNames(id)
    if not Choice(self.NAMES, id) then return false end
    local saved = Saved()
    if saved then saved.names = id end
    self:RefreshElements()
    return true
end
function E:SetFocus(id)
    if not Choice(self.FOCUS, id) then return false end
    local saved = Saved()
    if saved then saved.focus = id end
    self:RefreshElements()
    return true
end

function E:Bounds(element)
    return addon.PositionManager:GetScreenBounds(element.id)
end

function E:SetCoordinate(axis, value)
    local element = self:Selected()
    if not addon.editMode or not element then return false end
    if InCombatLockdown() or UnitAffectingCombat("player") then
        print("ModeUI: position elements outside combat.")
        return false
    end
    return addon.PositionManager:SetCoordinate(element.id, axis, value)
end

function E:CoordinateBounds(element)
    return addon.PositionManager:GetCoordinateBounds(element.id)
end

function E:SetAnchor(target, placement)
    local element = self:Selected()
    if not addon.editMode or not element or not element.supportsAnchoring then return false end
    return addon.PositionManager:SetAnchor(element.id, target, placement)
end

local function Anchorable()
    local element = E:Selected()
    return addon.editMode and element and element.supportsAnchoring and element or nil
end

-- A new target, side or Reset Offset puts X and Y back at 0 (see PM:AnchorTo).
function E:SetTarget(target)
    local element = Anchorable()
    if not element then return false end
    return addon.PositionManager:AnchorTo(element.id, target)
end

function E:SetPlacement(placement)
    local element = Anchorable()
    if not element then return false end
    return addon.PositionManager:AnchorTo(element.id, element.position.target or "screen", placement)
end

function E:ResetOffset()
    local element = Anchorable()
    if not element then return false end
    return addon.PositionManager:SetOffsets(element.id, 0, 0)
end

function E:FinishDrags()
    addon.PositionManager:FinishDrags()
end

function E:ViewportChanged()
    if not addon.editMode or InCombatLockdown() or UnitAffectingCombat("player") then return end
    self:FinishDrags()
    addon.Positioning:Refresh()
    addon.PositionManager:RenderGrid()
    if addon.UpdateEditWindowBounds then addon:UpdateEditWindowBounds() end
    self:NotifyPosition()
end

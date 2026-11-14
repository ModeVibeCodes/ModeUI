local _, addon = ...
local PM, P = addon.PositionManager, addon.Positioning

-- Dragging elements in Edit Mode and the selected element. Positions are
-- stored and validated in PositionManager.lua.
local Combat, Plain = addon.InCombat, addon.IsPublic
local function Lookup(self, id) return self:Element(id) end

function PM:CanDrag(element)
    -- While Anchor To waits for a click, nothing can be dragged or selected.
    if self.picking then return false end
    if Combat() or not addon.editMode or not element.editMode or not element.module.enabled or not element.draggable then return false end
    if not element.canDrag then return true end
    local ok, allowed = pcall(element.canDrag, element)
    return ok and Plain(allowed) and allowed == true
end

function PM:StartDragging(id)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if not self:CanDrag(element) then return false, "drag-not-allowed" end
    if element.dragging then return true, "unchanged" end
    if element.frame:GetScript("OnUpdate") then return false, "update-in-use" end
    if not P:Resolve(element.position.target) then return false, "target-unavailable" end
    self:FinishDrags()
    self:SelectElement(id)
    element.subject.appliedAnchor = nil
    element.dragging, element.module.dragging = true, true
    element.frame:StartMoving()
    element.frame:SetScript("OnUpdate", element.dragUpdate)
    return true
end

function PM:StopDragging(id)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if element.legacy then element.module:StopDragging(); return true end
    if not element.dragging then return true, "unchanged" end
    element.frame:StopMovingOrSizing()
    if element.frame:GetScript("OnUpdate") == element.dragUpdate then element.frame:SetScript("OnUpdate", nil) end
    element.dragging, element.module.dragging = false, false
    if self.HideGuides then self:HideGuides() end
    local changed
    if not Combat() then
        local x, y = P:ReadFrame(element.subject)
        -- Dropped near a guide (an offset of 0, the screen's center or another
        -- element's center): snap onto it.
        if self.GuideSnap then x, y = self:GuideSnap(element, x, y) end
        changed = x ~= element.position.x or y ~= element.position.y
        element.position.x, element.position.y = x, y
        self:ApplyPosition(id, true)
    else self.pending = true; P.pending = true end
    self:NotifyPosition(id, changed)
    if changed and self.FitAnchored then self:FitAnchored(id) end
    return true
end

function PM:FinishDrags()
    for _, id in ipairs(self.order) do self:StopDragging(id) end
end

-- Whether an element takes part in Edit Mode, for modules with several
-- elements that are each switched on and off (one per action bar).
function PM:SetEditable(id, editable)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    editable = editable == true
    if element.editMode == editable then return true, "unchanged" end
    element.editMode = editable
    if not editable then self:StopDragging(id) end
    return true
end

-- While Anchor To waits for a click, every shown element still takes the
-- mouse (without dragging), so a click picks it and never reaches what's
-- under it, like a full bar's buttons.
function PM:Pickable(element)
    return self.picking == true and addon.editMode and element.editMode and element.module.enabled and true or false
end

function PM:GetSelectedElement()
    local element = self.elements[self.selected]
    return element and element.editMode and element.module.enabled and element or nil
end

function PM:SelectElement(id)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if Combat() or not addon.editMode or not element.editMode or not element.module.enabled then return false, "selection-not-allowed" end
    self.selected = id
    self:RefreshSelection()
    return true
end

function PM:RefreshSelection()
    if addon.editMode and not self:GetSelectedElement() then
        self.selected = nil
        for _, id in ipairs(self.order) do
            local element = self.elements[id]
            if element.editMode and element.module.enabled then self.selected = id; break end
        end
    elseif not addon.editMode then self.selected = nil end
    addon.EditMode.selected = self.selected -- compatibility view, not another selector
    for id, element in pairs(self.elements) do
        if not addon.editMode or not element.module.enabled then self:StopDragging(id) end
        if element.draggable then element.frame:EnableMouse(self:CanDrag(element) == true or self:Pickable(element)) end
        local selected = id == self.selected
        local show = addon.editMode and element.editMode and element.module.enabled and addon.EditMode.highlights
        if self.UpdateEditDecoration then self:UpdateEditDecoration(element, selected, show) end
        if element.onHighlight then element.onHighlight(element, selected, show)
        elseif (element.legacy or element.frame == element.module.frame) and element.module.SetEditHighlight then
            element.module:SetEditHighlight(selected, show)
        end
    end
    if self.RenderGrid then self:RenderGrid() end
    self:NotifyPosition()
end

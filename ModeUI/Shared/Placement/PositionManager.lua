local _, addon = ...
local PM = { elements = {}, order = {}, frames = setmetatable({}, { __mode = "k" }) }
addon.PositionManager = PM
addon.EditMode.elements, addon.EditMode.order = PM.elements, PM.order
local P = addon.Positioning
local Combat = addon.InCombat
local Plain = addon.IsPublic
local function Number(value)
    return Plain(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function Copy(position)
    return { target = position.target or "screen", placement = position.placement or "center",
        x = position.x, y = position.y, fallbackX = position.fallbackX, fallbackY = position.fallbackY,
        point = position.point, relativePoint = position.relativePoint }
end
local function Known(items, id)
    if not Plain(id) or type(id) ~= "string" then return false end
    for _, item in ipairs(items) do if item.id == id then return true end end
    return false
end
local function Lookup(self, id)
    if not Plain(id) or type(id) ~= "string" then return nil end
    return self.elements[id]
end
function PM:Element(id) return Lookup(self, id) end
local function Target(id) return Known(P.targets,id) or (addon.FrameAnchors and addon.FrameAnchors:ValidID(id)) end
local function Allowed(element,id)
    return element.allowedTargets[id] or (element.allowedTargets.selected and addon.FrameAnchors and addon.FrameAnchors:ValidID(id))
end

function PM:ValidatePosition(position, saved)
    if not Plain(position) or type(position) ~= "table" then return false, "invalid-position" end
    if not Number(position.x) or not Number(position.y) then return false, "invalid-offsets" end
    if not Target(position.target or "screen") and not (saved and Plain(position.target) and type(position.target)=="string" and position.target~="") then return false, "invalid-target" end
    if not Known(P.placements, position.placement or "center") and not (saved and Plain(position.placement) and type(position.placement)=="string" and position.placement~="") then return false, "invalid-placement" end
    if position.point~=nil or position.relativePoint~=nil then
        if not Plain(position.point) or not Plain(position.relativePoint) or not P.vectors[position.point] or not P.vectors[position.relativePoint] then return false,"invalid-points" end
    end
    for _, key in ipairs({ "fallbackX", "fallbackY" }) do
        local value = position[key]
        if not Plain(value) or (value ~= nil and not Number(value)) then return false, "invalid-fallback" end
    end
    return true
end

function PM:RegisterElement(id, frame, options)
    if not Plain(id) or type(id) ~= "string" or id == "" then return false, "invalid-id" end
    if self.elements[id] then return false, "duplicate-id" end
    options = options or {}
    if not Plain(options) or type(options) ~= "table" then return false, "invalid-options" end
    if not Plain(options.originPoint) or (options.originPoint~=nil and options.originPoint~="TOP" and options.originPoint~="BOTTOM") then return false,"invalid-origin" end
    if not Plain(frame) or not frame or not frame.GetScript or not frame.SetScript or not P:Geometry(frame) then return false, "invalid-frame" end
    if self.frames[frame] then return false, "duplicate-frame" end
    for _, target in ipairs(P.targets) do
        local external = not target.owned and _G[target.name]
        if Plain(external) and frame == external then return false, "external-frame" end
    end
    if frame.IsProtected then
        local protected = frame:IsProtected()
        if not Plain(protected) or protected then return false, "protected-frame" end
    end
    -- owner: an addon-owned table with id/title/db/enabled that has no module page.
    if options.owner == nil and (not Plain(options.moduleId) or type(options.moduleId) ~= "string") then return false, "unknown-module" end
    local module = options.owner or addon.modules[options.moduleId]
    if not module or not module.db or not addon.db then return false, "unknown-module" end
    for _, key in ipairs({ "draggable", "editMode", "anchoring", "legacyPosition" }) do
        if options[key] ~= nil and type(options[key]) ~= "boolean" then return false, "invalid-options" end
    end
    if options.label ~= nil and (not Plain(options.label) or type(options.label) ~= "string") then return false, "invalid-options" end
    for _, key in ipairs({ "canDrag", "onPositionChanged", "onHighlight" }) do
        if options[key] ~= nil and type(options[key]) ~= "function" then return false, "invalid-options" end
    end
    local defaults = options.defaultPosition or { target = "screen", placement = "center", x = 0, y = 0 }
    local valid, reason = self:ValidatePosition(defaults)
    if not valid then return false, reason end
    local allowed = { selected = options.allowedTargets == nil or options.anyTarget == true } -- anyTarget: every target known now, and picked frames
    if options.allowedTargets ~= nil and type(options.allowedTargets) ~= "table" then return false, "invalid-targets" end
    local list = options.anyTarget and {} or options.allowedTargets or { "screen", "player", "target", "focus", "minimap", "party" }
    if options.anyTarget then for _, t in ipairs(P.targets) do if t.id ~= id then list[#list + 1] = t.id end end end
    for _, target in ipairs(list) do
        if not Known(P.targets, target) then return false, "invalid-targets" end
        allowed[target] = true
    end
    if not allowed.screen or not (allowed[defaults.target or "screen"] or (allowed.selected and addon.FrameAnchors and addon.FrameAnchors:ValidID(defaults.target))) then return false, "invalid-targets" end
    local draggable = options.draggable ~= false and not options.legacy
    if draggable and (frame:GetScript("OnDragStart") or frame:GetScript("OnDragStop")) then return false, "drag-handlers-owned" end
    local position
    if options.legacyPosition then
        position = module.db.position
    else
        if addon.db.positions ~= nil and type(addon.db.positions) ~= "table" then return false, "invalid-storage" end
        position = addon.db.positions and addon.db.positions[id]
    end
    if position == nil then position = Copy(defaults) end
    valid, reason = self:ValidatePosition(position, true)
    if not valid then return false, reason end -- Never replace malformed saved data.
    position.target, position.placement = position.target or "screen", position.placement or "center"
    if options.legacyPosition then module.db.position = position
    else addon.db.positions = addon.db.positions or {}; addon.db.positions[id] = position end
    local element = { id = id, label = options.label, module = module, frame = frame, position = position, defaults = Copy(defaults),
        allowedTargets = allowed, draggable = draggable, editMode = options.editMode ~= false,
        supportsAnchoring = options.anchoring ~= false, legacy = options.legacy,
        canDrag = options.canDrag, onPositionChanged = options.onPositionChanged, onHighlight = options.onHighlight,
        scripts = {}, handlers = {} }
    element.subject = { frame = frame, db = { position = position } }
    element.subject.originPoint,element.subject.gapPixels=options.originPoint,type(options.gapPixels)=="number" and options.gapPixels or nil
    element.subject.allowedTargets = allowed
    self.elements[id], self.frames[frame] = element, id
    self.order[#self.order + 1] = id
    if draggable then
        frame:SetMovable(true); frame:SetClampedToScreen(true); frame:RegisterForDrag("LeftButton")
        local function Bind(name, handler)
            local prior = frame:GetScript(name)
            element.scripts[name] = prior
            local wrapped = function(...)
                if prior then prior(...) end
                if self.elements[id] == element then handler(...) end
            end
            element.handlers[name] = wrapped
            frame:SetScript(name, wrapped)
        end
        Bind("OnDragStart", function() self:StartDragging(id) end)
        Bind("OnDragStop", function() self:StopDragging(id) end)
        Bind("OnMouseDown", function() if self:CanDrag(element) then self:SelectElement(id) end end)
        Bind("OnHide", function() self:StopDragging(id) end)
        element.dragUpdate = function() self:NotifyPosition(id, false); if self.ShowGuides then self:ShowGuides(element) end end
    end
    if not element.legacy then self:ApplyPosition(id) end
    return true, element
end
function PM:SetOriginPoint(id,point)
    local element=Lookup(self,id)
    if not element then return false,"unknown-element" end
    if Combat() then return false,"combat" end
    if not Plain(point) or (point~="TOP" and point~="BOTTOM") then return false,"invalid-origin" end
    element.subject.originPoint=point
    return true
end

function PM:UnregisterElement(id)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if Combat() then return false, "combat" end
    self:StopDragging(id)
    if self.ReleaseEditDecoration then self:ReleaseEditDecoration(element) end
    if element.sizeObserver then
        element.sizeObserver:SetScript("OnSizeChanged", nil)
        element.sizeObserver:ClearAllPoints(); element.sizeObserver:Hide()
    end
    for name, handler in pairs(element.handlers) do
        if element.frame:GetScript(name) == handler then element.frame:SetScript(name, element.scripts[name]) end
    end
    if element.onHighlight then element.onHighlight(element, false, false) end
    self.frames[element.frame], self.elements[id] = nil, nil
    for index, key in ipairs(self.order) do if key == id then table.remove(self.order, index); break end end
    if self.selected == id then self.selected = nil end
    -- The caller retains ownership of its frame and saved record; all runtime closures are released.
    self:RefreshSelection()
    for key in pairs(element) do element[key] = nil end
    return true
end

function PM:GetPosition(id)
    local element = Lookup(self, id)
    if not element then return nil, "unknown-element" end
    local valid, reason = self:ValidatePosition(element.position, true)
    if not valid then return nil, reason end
    return Copy(element.position)
end

-- Opt-in runtime target for provider-owned/anonymous frames. Saved positions
-- remain untouched; only addon-owned elements are moved by ApplyPosition.
function PM:SetRuntimeAnchor(id,frame,point,relativePoint,x,y)
    local element=Lookup(self,id)
    if not element or element.legacy then return false,"unknown-element" end
    if Combat() then return false,"combat" end
    if not Plain(frame) then return false,"unsafe-frame" end
    if frame==nil then
        element.subject.runtimeAnchor=nil
        return self:ApplyPosition(id)
    end
    if not Plain(frame) or P.rejected[frame] or not addon.FrameAnchors:SafeFrame(frame) then return false,"unsafe-frame" end
    if not Plain(point) or not Plain(relativePoint) or not P.vectors[point] or not P.vectors[relativePoint]
        or not Number(x) or not Number(y) then return false,"invalid-anchor" end
    local previous=element.subject.runtimeAnchor
    element.subject.runtimeAnchor={frame=frame,target="screen",point=point,relativePoint=relativePoint,placement="center",x=x,y=y}
    local ok,reason=self:ApplyPosition(id)
    if not ok then element.subject.runtimeAnchor=previous;self:ApplyPosition(id) end
    return ok,reason
end

function PM:GetOffsets(id)
    local element = Lookup(self, id)
    if not element then return nil, nil, "unknown-element" end
    if element.legacy then return element.module:GetEditPosition() end
    if element.dragging then return P:ReadFrame(element.subject) end
    return element.position.x, element.position.y
end

function PM:ApplyPosition(id, force)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if Combat() then self.pending = true; P.pending = true; return false, "combat" end
    if element.legacy then return true, "legacy" end
    local valid, reason = self:ValidatePosition(element.position, true)
    if not valid then return false, reason end
    local ok, status = P:ApplyFrame(element.subject, force)
    self:RefreshAnchorSize(id)
    return ok, status
end

function PM:SetPosition(id, position, allowUnavailable)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if element.notifying then return false, "notification-in-progress" end
    if Combat() then return false, "combat" end
    local valid, reason = self:ValidatePosition(position, true)
    if not valid then return false, reason end
    if not Target(position.target or "screen") and position.target~=element.position.target then return false,"invalid-target" end
    if not Known(P.placements,position.placement or "center") and position.placement~=element.position.placement then return false,"invalid-placement" end
    local nextPosition = Copy(position)
    local retainedUnknown=nextPosition.target==element.position.target and not Target(nextPosition.target)
    if (not Allowed(element,nextPosition.target) and not retainedUnknown) or (not element.supportsAnchoring and nextPosition.target ~= "screen") then return false, "target-not-allowed" end
    if addon.FrameAnchors and addon.FrameAnchors:ValidID(nextPosition.target) and nextPosition.target~=element.position.target then
        local frame=_G[nextPosition.target:sub(7)]
        if Plain(frame) and frame and not addon.FrameAnchors:SafeFrame(frame) then return false,"unsafe-frame" end
    end
    if not P:Resolve(nextPosition.target) and not allowUnavailable then return false, "target-unavailable" end
    if nextPosition.target ~= "screen" and self.WouldLoop and self:WouldLoop(id, nextPosition.target) then return false, "anchor-loop" end
    self:StopDragging(id)
    local previous = Copy(element.position)
    if previous.x == nextPosition.x and previous.y == nextPosition.y and previous.target == nextPosition.target
        and previous.placement == nextPosition.placement and previous.point==nextPosition.point and previous.relativePoint==nextPosition.relativePoint then return true, "unchanged" end
    if element.legacy then
        if element.module:SetEditPosition(nextPosition.x, nextPosition.y) == false then return false, "rejected" end
    else
        for _, key in ipairs({ "x", "y", "target", "placement", "point", "relativePoint" }) do element.position[key] = nextPosition[key] end
        local applied, status = self:ApplyPosition(id)
        if not applied then
            for _, key in ipairs({ "x", "y", "target", "placement", "point", "relativePoint" }) do element.position[key] = previous[key] end
            self:ApplyPosition(id)
            self:NotifyPosition(id, false)
            return false, status or "anchor-rejected"
        end
    end
    self:NotifyPosition(id, true)
    if self.FitAnchored then self:FitAnchored(id) end
    return true
end

function PM:SetOffsets(id, x, y)
    local position, reason = self:GetPosition(id)
    if not position then return false, reason end
    position.x, position.y = x, y
    return self:SetPosition(id, position)
end

function PM:SetCoordinate(id, axis, value)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    if not Plain(axis) or (axis ~= "x" and axis ~= "y") or not Number(value) then return false, "invalid-coordinate" end
    if Combat() then return false, "combat" end
    if not P:Resolve(element.position.target) then return false, "target-unavailable" end
    self:StopDragging(id)
    local x, y = self:GetOffsets(id)
    local lowX, highX, lowY, highY = self:GetCoordinateBounds(id)
    if axis == "x" then x = math.max(lowX, math.min(highX, value))
    else y = math.max(lowY, math.min(highY, value)) end
    return self:SetOffsets(id, x, y)
end

function PM:SetAnchor(id, target, placement, allowUnavailable)
    if not Lookup(self, id) then return false, "unknown-element" end
    if not Target(target) then return false, "invalid-target" end
    if not Known(P.placements, placement) then return false, "invalid-placement" end
    local position, reason = self:GetPosition(id)
    if not position then return false, reason end
    local item, sign = P:Placement(placement), target == "screen" and -1 or 1
    position.target, position.placement = target, placement
    position.point, position.relativePoint = nil,nil -- retain legacy outside-edge semantics
    position.x, position.y = item.x * sign, item.y * sign
    return self:SetPosition(id, position, allowUnavailable)
end

-- New UI operations preserve offsets. Legacy SetAnchor remains compatible.
function PM:ChangeTarget(id,target)
    local position,reason=self:GetPosition(id)
    if not position then return false,reason end
    position.target=target
    return self:SetPosition(id,position,true)
end
-- The gap a placement applies with no user nudge; custom points define their own.
local function PlacementOffsets(position)
    if position.point then return 0,0 end
    local item,sign=P:Placement(position.placement),position.target=="screen" and -1 or 1
    return item.x*sign,item.y*sign
end
-- A preset replaces custom points (they would override it) and carries nudges across.
function PM:SetPlacement(id,placement)
    if not Known(P.placements,placement) then return false,"invalid-placement" end
    local position,reason=self:GetPosition(id)
    if not position then return false,reason end
    local oldX,oldY=PlacementOffsets(position)
    position.placement,position.point,position.relativePoint=placement,nil,nil
    local newX,newY=PlacementOffsets(position)
    position.x,position.y=position.x-oldX+newX,position.y-oldY+newY
    return self:SetPosition(id,position)
end
function PM:ResetOffsets(id)
    local position,reason=self:GetPosition(id)
    if not position then return false,reason end
    position.x,position.y=PlacementOffsets(position)
    return self:SetPosition(id,position)
end
function PM:SetAttachment(id,point,relativePoint)
    local position,reason=self:GetPosition(id)
    if not position then return false,reason end
    position.point,position.relativePoint=point,relativePoint
    return self:SetPosition(id,position,true)
end
function PM:SetAlignment(id,point,outside)
    local opposite={TOP="BOTTOM",BOTTOM="TOP",LEFT="RIGHT",RIGHT="LEFT",TOPLEFT="BOTTOMRIGHT",TOPRIGHT="BOTTOMLEFT",BOTTOMLEFT="TOPRIGHT",BOTTOMRIGHT="TOPLEFT",CENTER="CENTER"}
    if not Plain(point) or not opposite[point] then return false,"invalid-points" end
    return self:SetAttachment(id,outside and opposite[point] or point,point)
end
function PM:DetachAnchor(id)
    local element=Lookup(self,id)
    if not element then return false,"unknown-element" end
    if Combat() then return false,"combat" end
    local x,y,_,height=P:Geometry(element.frame)
    local px,py=P:Geometry(UIParent)
    if not x or not px then return false,"unavailable-geometry" end
    local position=self:GetPosition(id)
    position.target,position.placement="screen","center"
    position.point,position.relativePoint=nil,nil
    position.x,position.y=x-px,y-py
    if element.subject.originPoint then position.y=position.y+(element.subject.originPoint=="TOP" and height/2 or -height/2) end
    return self:SetPosition(id,position)
end

function PM:ResetPosition(id)
    local element = Lookup(self, id)
    if not element then return false, "unknown-element" end
    return self:SetPosition(id, element.defaults)
end

function PM:NotifyPosition(id, changed)
    local element = Lookup(self, id)
    if changed and element and element.onPositionChanged and not element.notifying then
        element.notifying = true
        local ok, message = pcall(element.onPositionChanged, element, Copy(element.position))
        element.notifying = false
        if not ok then print("ModeUI: position callback failed: " .. tostring(message)) end
    end
    P:UpdateHighlight()
    if addon.RefreshEditWindow then addon:RefreshEditWindow() end
end

function PM:GetCoordinateBounds(id)
    local element = Lookup(self, id)
    if not element then return nil, nil, nil, nil, "unknown-element" end
    return P:LimitsFrame(element.subject)
end

function PM:GetScreenBounds(id)
    local element = Lookup(self, id)
    if not element then return nil, nil, "unknown-element" end
    local _, _, width, height = P:Geometry(element.frame)
    if not width then return 0, 0 end
    return math.floor(math.max(0, (UIParent:GetWidth() - width) / 2)),
        math.floor(math.max(0, (UIParent:GetHeight() - height) / 2))
end

function PM:GetAllowedTargets(id)
    local element = Lookup(self, id)
    if not element then return {} end
    local targets = {}
    for _, target in ipairs(P:AvailableTargets()) do
        if element.allowedTargets[target.id] and (element.supportsAnchoring or target.id == "screen")
            and not (self.WouldLoop and self:WouldLoop(id, target.id)) then targets[#targets + 1] = target end
    end
    if element.allowedTargets.selected and addon.FrameAnchors and addon.FrameAnchors:ValidID(element.position.target) then
        targets[#targets+1]={id=element.position.target,label=element.position.target:sub(7)}
    end
    return targets
end

function PM:Refresh(discover)
    if Combat() then self.pending = true; P.pending = true; return end
    self.pending, P.pending = false, false
    local changed = not discover
    for _, element in pairs(self.elements) do
        if not element.legacy and not element.dragging then
            local target = P:Resolve(element.position.target)
            if not discover or target ~= element.subject.positionTargetFrame then self:ApplyPosition(element.id); changed = true end
            self:RefreshAnchorSize(element.id)
        end
    end
    if changed then self:NotifyPosition() end
end

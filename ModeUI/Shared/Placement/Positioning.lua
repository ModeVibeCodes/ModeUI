local _, addon = ...
local P = { rejected = setmetatable({}, { __mode = "k" }) }
addon.Positioning = P

-- Stable IDs only: never save frame objects or addon-provided arbitrary globals.
P.targets = {
    { id = "screen", label = "Screen / UIParent", name = "UIParent" },
    { id = "player", label = "Player Frame", name = "PlayerFrame" },
    { id = "target", label = "Target Frame", name = "TargetFrame" },
    { id = "focus", label = "Focus Frame", name = "FocusFrame" },
    { id = "minimap", label = "Minimap", name = "Minimap" },
    { id = "party", label = "Party Frames", name = "PartyFrame" },
}
-- External placements join opposite edges. Screen placements stay inside its edge.
P.placements = {
    { id = "above", label = "Above", point = "BOTTOM", relative = "TOP", x = 0, y = 8 },
    { id = "below", label = "Below", point = "TOP", relative = "BOTTOM", x = 0, y = -8 },
    { id = "left", label = "Left", point = "RIGHT", relative = "LEFT", x = -8, y = 0 },
    { id = "right", label = "Right", point = "LEFT", relative = "RIGHT", x = 8, y = 0 },
    { id = "center", label = "Center", point = "CENTER", relative = "CENTER", x = 0, y = 0 },
}
local vectors = { CENTER = {0, 0}, TOP = {0, 0.5}, BOTTOM = {0, -0.5}, LEFT = {-0.5, 0}, RIGHT = {0.5, 0} }
vectors.TOPLEFT,vectors.TOPRIGHT,vectors.BOTTOMLEFT,vectors.BOTTOMRIGHT={-0.5,0.5},{0.5,0.5},{-0.5,-0.5},{0.5,-0.5}
P.points = {"TOPLEFT","TOP","TOPRIGHT","LEFT","CENTER","RIGHT","BOTTOMLEFT","BOTTOM","BOTTOMRIGHT"}
P.vectors = vectors
local Combat = addon.InCombat
local Plain = addon.IsPublic
local function Number(value)
    return Plain(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- A target ModeUI owns (another element's frame), added by a module before it
-- registers elements. `name` is the frame's global name; `owned` lets that
-- frame also be an element.
function P:AddTarget(id, label, name)
    assert(type(id) == "string" and type(label) == "string" and type(name) == "string" and name:find("^ModeUI"),
        "ModeUI: AddTarget(id, label, ModeUI frame name).")
    for _, item in ipairs(self.targets) do assert(item.id ~= id, "ModeUI: duplicate position target " .. id) end
    self.targets[#self.targets + 1] = { id = id, label = label, name = name, owned = true }
end

function P:Placement(id)
    for _, item in ipairs(self.placements) do if item.id == id then return item end end
    return self.placements[5]
end

function P:Geometry(frame)
    if not Plain(frame) or not frame then return end
    -- Reject forbidden/restricted/secret anchoring before querying its rectangle.
    for _, name in ipairs({ "IsForbidden", "IsAnchoringRestricted", "IsAnchoringSecret", "HasAnyForbiddenAspects" }) do
        if frame[name] then
            local value = frame[name](frame)
            if not Plain(value) or value then return end
        end
    end
    if frame.CanBeAccessedInContext then
        local value = frame:CanBeAccessedInContext()
        if not Plain(value) or not value then return end
    end
    if not frame.GetCenter or not frame.GetEffectiveScale or not frame.GetWidth or not frame.GetHeight then return end
    local x, y = frame:GetCenter()
    local scale, width, height = frame:GetEffectiveScale(), frame:GetWidth(), frame:GetHeight()
    if not Number(x) or not Number(y) or not Number(scale) or not Number(width) or not Number(height)
        or scale <= 0 or width <= 0 or height <= 0 then return end
    local ratio = scale / UIParent:GetEffectiveScale()
    return x * ratio, y * ratio, width * ratio, height * ratio
end

function P:Resolve(id)
    if id ~= "screen" and Combat() then return end
    if addon.FrameAnchors and addon.FrameAnchors:ValidID(id) then return addon.FrameAnchors:Resolve(id) end
    for _, item in ipairs(self.targets) do
        if item.id == id then
            local frame = _G[item.name]
            if not Plain(frame) then return end
            if frame and self.rejected[frame] then return end
            if id == "party" and frame and frame.IsShown then
                local shown = frame:IsShown()
                if not Plain(shown) or not shown then return end
            end
            if self:Geometry(frame) then return frame, item end
        end
    end
end

function P:AvailableTargets()
    local result = {}
    for _, item in ipairs(self.targets) do
        if self:Resolve(item.id) then result[#result + 1] = item end
    end
    return result
end

-- Base center for zero offsets, expressed in UIParent units.
function P:Attachment(position,originPoint)
    local placement=self:Placement(position.placement)
    local point=position.point or ((position.target or "screen")=="screen" and placement.relative or placement.point)
    if not position.point and originPoint then point=originPoint..((point=="LEFT" or point=="RIGHT") and point or "") end
    return point,position.relativePoint or placement.relative
end
function P:Base(module)
    local element = addon.PositionManager and addon.PositionManager.elements[module.positionElementId or module.id]
    if element then module = element.subject end
    local position = module.runtimeAnchor or module.db.position
    if module.allowedTargets and not module.allowedTargets[position.target or "screen"]
        and not (module.allowedTargets.selected and addon.FrameAnchors and addon.FrameAnchors:ValidID(position.target)) then return end
    local target = module.runtimeAnchor and position.frame or self:Resolve(position.target or "screen")
    if not target then return end
    local point,relative=self:Attachment(position,module.originPoint)
    local tx, ty, tw, th = self:Geometry(target)
    local _, _, width, height = self:Geometry(module.frame)
    if not tx or not width then return end
    local a, b = vectors[point], vectors[relative]
    return tx + b[1] * tw - a[1] * width, ty + b[2] * th - a[2] * height,
        target, point, relative
end
function P:FallbackPoint(module)
    if module.db.position.point then return "CENTER" end
    if not module.originPoint then return "CENTER" end
    local p=self:Placement(module.db.position.placement)
    local point=module.db.position.target=="screen" and p.relative or p.point
    return module.originPoint..((point=="LEFT" or point=="RIGHT") and point or "")
end

-- An element registered with gapPixels sits that many physical pixels off
-- the side of what it's anchored to (Above, Below, Left, Right), on top of
-- its offsets, so an anchored stack keeps a pixel-perfect gap.
function P:Gap(module, position)
    local pixels = module.gapPixels
    if not pixels or (position.target or "screen") == "screen" or position.point then return 0, 0 end
    local item = self:Placement(position.placement)
    local px = addon.Kit and addon.Kit.PixelSize(UIParent) or 1
    local function Sign(v) return v > 0 and 1 or v < 0 and -1 or 0 end
    return Sign(item.x) * pixels * px, Sign(item.y) * pixels * px
end
function P:ApplyFrame(module, force)
    if Combat() then self.pending = true; return false end
    local position, frame = module.runtimeAnchor or module.db.position, module.frame
    local bx, by, target, point, relative = self:Base(module)
    local scale, parentScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not Number(scale) or not Number(parentScale) or scale <= 0 or parentScale <= 0 then return false, "unavailable-geometry" end
    local ratio = scale / parentScale
    if not Number(position.x / ratio) or not Number(position.y / ratio) then return false, "invalid-offsets" end
    local function Anchor(pointName, targetFrame, relativePoint, x, y)
        local _, _, width, height = self:Geometry(frame)
        local nextAnchor = { pointName, targetFrame, relativePoint, x, y, ratio, width, height }
        local same = not force and module.appliedAnchor ~= nil
        if same then
            for index = 1, 8 do if nextAnchor[index] ~= module.appliedAnchor[index] then same = false; break end end
        end
        -- Something else moved the frame since (the client's layout cache):
        -- the remembered anchor no longer holds.
        if same and frame:GetNumPoints() == 1 then
            local p, to, rp, x, y = frame:GetPoint(1)
            same = p == pointName and to == targetFrame and rp == relativePoint and x == x and y == y
                and math.abs((x or 0) - nextAnchor[4]) < 0.01 and math.abs((y or 0) - nextAnchor[5]) < 0.01
        elseif same then same = false end
        if same then return true end
        frame:ClearAllPoints()
        local ok = pcall(frame.SetPoint, frame, pointName, targetFrame, relativePoint, x, y)
        module.appliedAnchor = ok and nextAnchor or nil
        return ok
    end
    if target then
        local gx, gy = self:Gap(module, position)
        local ok = Anchor(point, target, relative, (position.x + gx) / ratio, (position.y + gy) / ratio)
        if ok then
            module.positionTargetFrame = target
            local px, py = UIParent:GetCenter()
            local _,_,width,height=self:Geometry(frame)
            local origin=not position.point and module.originPoint and vectors[point] or {0,0}
            position.fallbackX, position.fallbackY = bx + position.x + origin[1]*width - px, by + position.y + origin[2]*height - py
            return true
        end
        -- A rejected native anchor is unsupported. Do not retry or bypass it.
        self.rejected[target] = true
        print("ModeUI: this UI anchor is unavailable; using the saved screen position.")
    end
    -- Preserve the missing target and its offsets; use last known screen center.
    module.positionTargetFrame = nil
    local fallback = Anchor(self:FallbackPoint(module), UIParent, "CENTER", (position.fallbackX or position.x) / ratio,
        (position.fallbackY or position.y) / ratio)
    return fallback and target == nil, target and "anchor-rejected" or "fallback"
end

function P:ReadFrame(module)
    local position = module.db.position
    if Combat() then return position.x, position.y end
    local x, y = self:Geometry(module.frame)
    local bx, by = self:Base(module)
    if x and bx then return x - bx, y - by end
    return position.x, position.y
end

function P:LimitsFrame(module)
    local bx, by = self:Base(module)
    local _, _, width, height = self:Geometry(module.frame)
    local cx, cy = UIParent:GetCenter()
    if not bx or not width then return -UIParent:GetWidth(), UIParent:GetWidth(), -UIParent:GetHeight(), UIParent:GetHeight() end
    local halfX = math.max(0, (UIParent:GetWidth() - width) / 2)
    local halfY = math.max(0, (UIParent:GetHeight() - height) / 2)
    return math.ceil(cx - halfX - bx), math.floor(cx + halfX - bx),
        math.ceil(cy - halfY - by), math.floor(cy + halfY - by)
end

function P:Change(module, target, placement)
    return addon.PositionManager:SetAnchor(module.positionElementId or module.id, target, placement)
end

function P:Refresh()
    return addon.PositionManager:Refresh()
end

-- Shared ADDON_LOADED discovery only reapplies an anchor when its frame changes.
function P:Discover()
    return addon.PositionManager:Refresh(true)
end

-- Compatibility methods delegate registration/storage/updates to the manager.
-- Removes a target added with AddTarget (an element that's gone, such as a
-- deleted custom bar): elements hanging from it move to the screen where
-- they are, and no element can pick it any more.
function P:RemoveTarget(id)
    local PM = addon.PositionManager
    for eid, element in pairs(PM.elements) do
        if element.position.target == id then PM:DetachAnchor(eid) end
        element.allowedTargets[id] = nil
    end
    for index, item in ipairs(self.targets) do
        if item.id == id then table.remove(self.targets, index); return true end
    end
    return false
end
-- Renames a target (a custom bar renamed).
function P:SetTargetLabel(id, label)
    for _, item in ipairs(self.targets) do if item.id == id then item.label = label; return true end end
    return false
end
function P:Apply(module) return addon.PositionManager:ApplyPosition(module.positionElementId or module.id) end
function P:Read(module) return addon.PositionManager:GetOffsets(module.positionElementId or module.id) end
function P:Limits(module) return addon.PositionManager:GetCoordinateBounds(module.positionElementId or module.id) end

-- Snapshot decoration on our own UIParent child, with no external anchor/parent.
function P:UpdateHighlight()
    if self.highlight then self.highlight:Hide() end
    local E = addon.EditMode
    local element = E:Selected()
    if Combat() or not addon.editMode or not E.highlights or not element or not element.supportsAnchoring then return end
    local id = element.position.target or "screen"
    if id == "screen" then return end
    local target = self:Resolve(id)
    if not target then return end
    local shown = target:IsShown()
    if not Plain(shown) or not shown then return end
    local x, y, width, height = self:Geometry(target)
    if not x then return end
    if not self.highlight then
        local outline = CreateFrame("Frame", nil, UIParent)
        outline:SetFrameStrata("DIALOG")
        outline:EnableMouse(false)
        for index, points in ipairs({ {"TOPLEFT", "TOPRIGHT"}, {"BOTTOMLEFT", "BOTTOMRIGHT"},
            {"TOPLEFT", "BOTTOMLEFT"}, {"TOPRIGHT", "BOTTOMRIGHT"} }) do
            local edge = outline:CreateTexture(nil, "OVERLAY")
            edge:SetPoint(points[1]); edge:SetPoint(points[2])
            if index <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
            local color = addon.Style.Tone.edit.idle
            edge:SetColorTexture(color[1], color[2], color[3], 0.5)
        end
        self.highlight = outline
    end
    local cx, cy = UIParent:GetCenter()
    self.highlight:ClearAllPoints()
    self.highlight:SetPoint("CENTER", UIParent, "CENTER", x - cx, y - cy)
    self.highlight:SetSize(width, height)
    self.highlight:Show()
end

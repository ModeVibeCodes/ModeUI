local _, addon = ...
local PM, P = addon.PositionManager, addon.Positioning
-- Where Edit Mode's names go (docs/DESIGN_LANGUAGE.md, "Edit Mode").
-- Fit: each name tries a few spots around its element (above, below, inside
-- its top-left corner, left, right) and takes the first one on screen and
-- clear of other names, other elements, the top bar and the panel; the
-- smallest elements choose first. A name with no clear spot waits for the
-- mouse. The selected element's chip (its name and size, or X and Y while it
-- moves) goes above it, else below, else inside. A watcher tracks the element
-- under the mouse and lays the names out again after a change, at most every
-- TICK seconds.
local L = { HEIGHT = 18, GAP = 3, TICK = 0.05, MOVED = 1.5 }
addon.EditLabels = L
local Plain = addon.IsPublic

local function Hit(a, b, pad)
    return a.x < b.x + b.w + pad and b.x < a.x + a.w + pad and a.y < b.y + b.h + pad and b.y < a.y + a.h + pad
end
L.Hit = Hit

-- A frame's rectangle in UIParent units (left, bottom, width, height).
function L.FrameRect(frame)
    local x, y, w, h = P:Geometry(frame)
    if not x then return end
    return { x = x - w / 2, y = y - h / 2, w = w, h = h }
end

-- The spots a name of width w tries around rectangle r, in order.
function L.Candidates(r, w, h, gap)
    local cx, cy = r.x + r.w / 2 - w / 2, r.y + r.h / 2 - h / 2
    local top, bottom = r.y + r.h + gap, r.y - h - gap
    local list = { { cx, top }, { r.x, top }, { r.x + r.w - w, top }, { cx, bottom }, { r.x, bottom } }
    if w <= r.w - 6 and h <= r.h - 6 then list[#list + 1] = { r.x + 3, r.y + r.h - h - 3 } end
    list[#list + 1] = { r.x - w - 4, cy }
    list[#list + 1] = { r.x + r.w + 4, cy }
    return list
end

local function Clear(r, width, height, placed, obstacles, items, own)
    if r.x < 2 or r.y < 2 or r.x + r.w > width - 2 or r.y + r.h > height - 2 then return false end
    for _, p in ipairs(placed) do if Hit(r, p, 2) then return false end end
    for _, o in ipairs(obstacles) do if Hit(r, o, 2) then return false end end
    for _, item in ipairs(items) do if item ~= own and Hit(r, item.rect, 1) then return false end end
    return true
end

-- items: { id, rect, w } (w: the name's width). Returns id -> { x, y }, the
-- bottom-left of each name that found a clear spot.
function L.Place(items, obstacles, width, height)
    local order = {}
    for i, item in ipairs(items) do order[i] = item end
    table.sort(order, function(a, b)
        local A, B = a.rect.w * a.rect.h, b.rect.w * b.rect.h
        if A ~= B then return A < B end
        return a.id < b.id
    end)
    local placed, spots = {}, {}
    for _, item in ipairs(order) do
        for _, c in ipairs(L.Candidates(item.rect, item.w, L.HEIGHT, L.GAP)) do
            local r = { x = c[1], y = c[2], w = item.w, h = L.HEIGHT }
            if Clear(r, width, height, placed, obstacles, items, item) then
                placed[#placed + 1] = r; spots[item.id] = { x = r.x, y = r.y }
                break
            end
        end
    end
    return spots
end

-- One chip that must show (the selected or hovered element's): above, below
-- or inside, the first clear of the obstacles; above if none is.
function L.Spot(rect, w, obstacles, width, height)
    local x = math.max(4, math.min(width - w - 4, rect.x + rect.w / 2 - w / 2))
    local tries = { rect.y + rect.h + L.GAP, rect.y - L.HEIGHT - L.GAP, rect.y + rect.h - L.HEIGHT - 3 }
    for _, y in ipairs(tries) do
        local r = { x = x, y = y, w = w, h = L.HEIGHT }
        if Clear(r, width, height, {}, obstacles, {}, nil) then return { x = x, y = y } end
    end
    return { x = x, y = math.min(height - L.HEIGHT - 2, tries[1]) }
end

-- Whether an element shows in Edit Mode now.
function L.Active(element)
    local E = addon.EditMode
    return addon.editMode and element.editMode and element.module.enabled and E.highlights
        and element.draggable and element.decoration ~= nil and element.decoration.active == true or false
end

-- The selected chip's second part: X and Y while it moves, else its size.
function L:SubText(element)
    local moving = element.dragging or (self.movedId == element.id and GetTime() - (self.movedAt or 0) < self.MOVED)
    if moving then
        local x, y = PM:ScreenOffset(element)
        if x then return "X " .. x .. "  Y " .. y end
    end
    local _, _, w, h = P:Geometry(element.frame)
    if not w then return "" end
    return math.floor(w + 0.5) .. "×" .. math.floor(h + 0.5)
end

local function Obstacles()
    local list = {}
    for _, frame in ipairs({ addon.editWindow, addon.editPanel }) do
        if frame and frame:IsShown() then
            local r = L.FrameRect(frame)
            if r then list[#list + 1] = r end
        end
    end
    return list
end

-- Lays out every name and redraws them (not the outlines).
function L:Layout()
    self.dirty = false
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local obstacles, items = Obstacles(), {}
    local selected = addon.editMode and addon.EditMode:Selected()
    self.selectedSpot, self.spots, self.rects = nil, {}, {}
    for id, element in pairs(PM.elements) do
        if L.Active(element) then
            local rect = L.FrameRect(element.frame)
            if rect then
                self.rects[id] = rect
                if element ~= selected then items[#items + 1] = { id = id, rect = rect, w = PM:ChipWidth(element) } end
            end
        end
    end
    if selected and self.rects[selected.id] then
        local w = PM:ChipWidth(selected, self:SubText(selected))
        self.selectedSpot = L.Spot(self.rects[selected.id], w, obstacles, width, height)
        obstacles[#obstacles + 1] = { x = self.selectedSpot.x, y = self.selectedSpot.y, w = w, h = L.HEIGHT }
    end
    self.obstacles = obstacles
    if addon.EditMode:Names() == "fit" then self.spots = L.Place(items, obstacles, width, height) end
    for _, element in pairs(PM.elements) do if element.decoration then PM:UpdateEditName(element) end end
    if addon.EditFocus then addon.EditFocus:Update() end
end

-- The chip for the element under the mouse.
function L:HoverSpot(element)
    local rect = self.rects and self.rects[element.id] or L.FrameRect(element.frame)
    if not rect then return end
    return L.Spot(rect, PM:ChipWidth(element), self.obstacles or {}, UIParent:GetWidth(), UIParent:GetHeight())
end

-- The cursor in UIParent units, or nil.
local function Cursor()
    if type(GetCursorPosition) ~= "function" then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not Plain(x) or not Plain(y) or type(x) ~= "number" or type(y) ~= "number" or not scale or scale <= 0 then return end
    return x / scale, y / scale
end
local function Inside(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- The smallest element under the cursor (none over the top bar or panel).
function L:Under()
    local x, y = Cursor()
    if not x then return end
    for _, frame in ipairs({ addon.editWindow, addon.editPanel }) do
        if frame and frame:IsShown() and Inside(L.FrameRect(frame), x, y) then return end
    end
    local best, area
    for id, element in pairs(PM.elements) do
        local r = L.Active(element) and L.FrameRect(element.frame)
        if Inside(r, x, y) and (not area or r.w * r.h < area) then best, area = id, r.w * r.h end
    end
    return best
end

function L:Tick()
    if not addon.editMode then return end
    local hovered = PM.picking ~= true and self:Under() or nil
    if hovered ~= PM.hovered then
        local before = PM.elements[PM.hovered]
        PM.hovered = hovered
        if before then PM:Decorate(before) end
        if PM.elements[hovered] then PM:Decorate(PM.elements[hovered]) end
    end
    if self.dirty then self:Layout() end
    -- The selected chip's size, or X and Y while it moves.
    local selected = addon.EditMode:Selected()
    local d = selected and selected.decoration
    if d and d.selected and d.chip:IsShown() then
        local text = self:SubText(selected)
        if text ~= d.sub:GetText() then d.sub:SetText(text); d.chip:SetWidth(PM:ChipWidth(selected, text)) end
    end
end

local watcher = CreateFrame("Frame", nil, UIParent)
watcher:Hide()
local elapsed = 0
watcher:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed < L.TICK then return end
    elapsed = 0
    L:Tick()
end)
L.watcher = watcher

-- After the selection refreshes, the names follow; any position change lays
-- them out again on the next tick (the selected element's change shows X and Y).
local refresh = PM.RefreshSelection
function PM:RefreshSelection(...)
    if not addon.editMode then self.hovered = nil end
    local results = { refresh(self, ...) }
    watcher:SetShown(addon.editMode == true)
    L:Layout()
    return unpack(results)
end
local notify = PM.NotifyPosition
function PM:NotifyPosition(id, changed, ...)
    local results = { notify(self, id, changed, ...) }
    if changed and id then L.movedId, L.movedAt = id, GetTime() end
    L.dirty = true
    return unpack(results)
end

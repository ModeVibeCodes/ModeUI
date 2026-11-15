local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Dragging a spell in the settings preview moves it on its bar: press on a
-- spell and drag; a copy of its icon follows the cursor, the spell's own
-- slot fades, and the slot under the cursor lights up; let go there and the
-- spell takes that place (MoveSpell, Custom.lua). A plain click still opens
-- the spell's menu. Only ModeUI's preview samples take the mouse: Blizzard's
-- icons on screen are never made draggable. The cursor is followed by an
-- OnUpdate that runs only while a drag is under way.
local W, T, Public = addon.ConfigWidgets, addon.InterfaceTheme, addon.IsPublic
local GHOST_ALPHA, SOURCE_ALPHA = 0.85, 0.3

local function Over(frame)
    if not frame:IsShown() then return false end
    local over = frame:IsMouseOver()
    return Public(over) and over == true
end

-- The copy of the icon that follows the cursor.
local function Ghost(view)
    if view.ghost then return view.ghost end
    local ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP"); ghost:SetFrameLevel(250)
    ghost:EnableMouse(false); ghost:Hide()
    ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
    ghost.icon:SetAllPoints(); ghost.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ghost.rim = W.Fill(ghost, T.primary, "OVERLAY", 0, 0.25)
    view.ghost = ghost
    return ghost
end

local function FollowCursor(ghost)
    if not GetCursorPosition then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not (Public(x) and Public(y)) or type(x) ~= "number" or type(y) ~= "number" then return end
    ghost:ClearAllPoints()
    ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

-- The spells being shown now (icons or bars), by their place.
local function Samples(view)
    return view.dragList or {}
end

-- Each frame of a drag: the ghost follows the cursor and the slot under it
-- lights up (the last one lit stays the target between slots).
local function Track(view)
    local drag = view.drag
    if not drag then return end
    FollowCursor(view.ghost)
    for index, sample in ipairs(Samples(view)) do
        if sample.key and index <= drag.count and Over(sample) then drag.to = index end
    end
    for index, sample in ipairs(Samples(view)) do
        if sample.highlight then sample.highlight:SetShown(index == drag.to and index ~= drag.from) end
    end
end

function M:StartSampleDrag(view, sample)
    if not sample.key or not sample.index or not self:CanConfigure() then return false end
    view.dragged = true
    if self.spellMenu then self.spellMenu:Hide() end
    if self.picker then self.picker:Hide() end
    local id = self:PreviewViewer()
    view.dragList = self:IsBar(id) and view.bars or view.icons
    view.drag = { key = sample.key, from = sample.index, to = sample.index, id = id, count = #self:SpellOrder(id) }
    local ghost = Ghost(view)
    local ratio = sample:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local size = math.max(16, math.min(sample:GetWidth(), sample:GetHeight()) * ratio)
    ghost:SetSize(size, size)
    ghost.icon:SetTexture(sample.dragIcon)
    ghost:SetAlpha(GHOST_ALPHA)
    FollowCursor(ghost)
    ghost:Show()
    sample:SetAlpha(SOURCE_ALPHA)
    view.frame:SetScript("OnUpdate", function() Track(view) end)
    return true
end

-- Lets go: the spell moves to the lit slot (or stays), and the preview is
-- drawn again either way.
function M:StopSampleDrag(view)
    local drag = view.drag
    -- Where the cursor is as it lets go counts.
    if drag then Track(view) end
    view.drag = nil
    view.frame:SetScript("OnUpdate", nil)
    if view.ghost then view.ghost:Hide() end
    for _, sample in ipairs(Samples(view)) do if sample.highlight then sample.highlight:Hide() end end
    view.dragList = nil
    if not drag then return false end
    local moved = drag.to ~= drag.from and drag.id == self:PreviewViewer() and self:MoveSpell(drag.id, drag.key, drag.to)
    view.Refresh()
    return moved == true
end

-- A sample's drag handlers. A press clears the last drag, so only a press
-- that turned into a drag skips the click.
function M:EnableSampleDrag(view, sample)
    sample:RegisterForDrag("LeftButton")
    sample:SetScript("OnMouseDown", function() view.dragged = nil end)
    sample:SetScript("OnDragStart", function() M:StartSampleDrag(view, sample) end)
    sample:SetScript("OnDragStop", function() M:StopSampleDrag(view) end)
end

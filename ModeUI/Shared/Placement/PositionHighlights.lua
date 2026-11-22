local _, addon = ...
local PM = addon.PositionManager
local Combat = addon.InCombat
-- Name chips, inside tags and nudge buttons: Graphite panel; a white lift
-- under the mouse.
local function PaintPanel(texture, alpha)
    local c = addon.Style.Tone.graphite.panel
    texture:SetColorTexture(c[1], c[2], c[3], alpha or 0.94)
end
local function PaintHover(texture)
    local c = addon.Style.Tone.mono.white
    texture:SetColorTexture(c[1], c[2], c[3], 0.12)
end
local function Name(element) return element.label or element.module.title end

-- Decoration is attached to actual owned bounds, including module icon/layout bounds.
-- Only the element itself and its chip take the mouse; no invisible overlay.
-- Each element has an outline, a name chip (the selected element's: its name
-- and size, or X and Y while it moves; the hovered element's; with Names on
-- Fit, every name that found a spot, EditLabels.lua) and an inside tag (Names
-- on Inside: its top-left corner, cut short to fit). Under the focus dim
-- (EditFocus.lua) the selected and hovered elements' decoration lifts above it.
local function Chip(self, frame, element)
    local chip = CreateFrame("Button", nil, frame)
    chip:SetHeight(addon.EditLabels.HEIGHT); chip:Hide()
    chip:RegisterForClicks("LeftButtonUp"); chip:RegisterForDrag("LeftButton")
    local background = chip:CreateTexture(nil, "BACKGROUND"); background:SetAllPoints(); PaintPanel(background)
    local label = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", 8, 0); addon.Media:BindInterfaceFont(label, GameFontHighlight, 11)
    local sub = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sub:SetPoint("LEFT", label, "RIGHT", 8, 0); addon.Media:BindInterfaceFont(sub, GameFontHighlight, 11)
    sub:SetTextColor(unpack(addon.Style.Tone.edit.grid))
    chip:SetScript("OnMouseDown", function() if self:CanDrag(element) then self:SelectElement(element.id) end end)
    chip:SetScript("OnDragStart", function() self:StartDragging(element.id) end)
    chip:SetScript("OnDragStop", function() self:StopDragging(element.id) end)
    chip.label, chip.sub = label, sub
    return chip
end
local function Tag(frame)
    local tag = CreateFrame("Frame", nil, frame)
    tag:SetPoint("TOPLEFT", 2, -2); tag:SetHeight(14); tag:EnableMouse(false); tag:Hide()
    local background = tag:CreateTexture(nil, "BACKGROUND"); background:SetAllPoints(); PaintPanel(background, 0.78)
    local text = tag:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", 4, 0); text:SetJustifyH("LEFT"); text:SetWordWrap(false)
    addon.Media:BindInterfaceFont(text, GameFontHighlight, 10)
    tag.text = text
    return tag
end

function PM:UpdateEditDecoration(element, selected, show)
    local active = show and element.draggable and not Combat()
    if not element.decoration and active then
        local frame = CreateFrame("Frame", nil, element.frame)
        frame:SetAllPoints(element.frame); frame:EnableMouse(false)
        frame:SetFrameLevel(element.frame:GetFrameLevel()+15)
        local edges = {}
        for i,points in ipairs({{"TOPLEFT","TOPRIGHT"},{"BOTTOMLEFT","BOTTOMRIGHT"},{"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}}) do
            local texture=frame:CreateTexture(nil,"OVERLAY")
            texture:SetPoint(points[1]);texture:SetPoint(points[2])
            if i<=2 then texture:SetHeight(1) else texture:SetWidth(1) end
            edges[i]=texture
        end
        local chip, tag = Chip(self, frame, element), Tag(frame)
        chip.label:SetText(Name(element)); tag.text:SetText(Name(element))
        element.decoration = { frame = frame, edges = edges, chip = chip, handle = chip, label = chip.label, sub = chip.sub, tag = tag }
    end
    local d=element.decoration
    if not d then return end
    local edit = addon.Style.Tone.edit
    local hovered = self.hovered == element.id
    local focus = addon.EditFocus:On()
    local lifted = active and (selected or (hovered and focus ~= nil)) or false
    local color = selected and edit.select or hovered and edit.hover or edit.idle
    for _,edge in ipairs(d.edges) do edge:SetColorTexture(color[1],color[2],color[3],(selected or hovered) and 0.9 or 0.5) end
    local volt = edit.name
    d.label:SetTextColor(volt[1], volt[2], volt[3]); d.tag.text:SetTextColor(volt[1], volt[2], volt[3])
    if lifted then
        d.frame:SetFrameStrata("DIALOG"); d.frame:SetFrameLevel(addon.EditFocus.LIFT)
    else
        d.frame:SetFrameStrata(element.frame:GetFrameStrata()); d.frame:SetFrameLevel(element.frame:GetFrameLevel() + 15)
    end
    d.active, d.selected, d.hovered = active and true or false, selected and true or false, hovered
    -- Strong focus: the other outlines stay hidden until the mouse is over one.
    d.frame:SetShown(d.active and not (focus == "strong" and not lifted))
    self:UpdateEditName(element)
end

-- An element's decoration, from the current selection and switches.
function PM:Decorate(element)
    local show = addon.editMode and element.editMode and element.module.enabled and addon.EditMode.highlights
    self:UpdateEditDecoration(element, element.id == self.selected, show)
end

-- A chip's width in UIParent units, for its name and an optional second part.
function PM:ChipWidth(element, sub)
    local d = element.decoration
    if not d then return 0 end
    local width = d.label:GetStringWidth() + 16
    if sub and sub ~= "" then d.sub:SetText(sub); width = width + d.sub:GetStringWidth() + 8 end
    return math.ceil(width)
end

-- The element's name: its chip where EditLabels.lua placed it, and its inside tag.
function PM:UpdateEditName(element)
    local d = element.decoration
    if not d then return end
    local L, mode = addon.EditLabels, addon.EditMode:Names()
    local spot, sub, interactive
    if d.active and d.selected then spot, sub, interactive = L.selectedSpot, L:SubText(element), true
    elseif d.active and d.hovered and mode ~= "none" then spot = L:HoverSpot(element)
    elseif d.active and mode == "fit" then spot, interactive = L.spots and L.spots[element.id], true end
    local rect = spot and L.FrameRect(element.frame)
    local chip = d.chip
    d.sub:SetText(sub or "")
    if rect then
        -- In UIParent units whatever the element's scale.
        local scale = d.frame:GetEffectiveScale()
        chip:SetScale(scale > 0 and UIParent:GetEffectiveScale() / scale or 1)
        chip:SetWidth(self:ChipWidth(element, sub))
        chip:ClearAllPoints(); chip:SetPoint("BOTTOMLEFT", d.frame, "BOTTOMLEFT", spot.x - rect.x, spot.y - rect.y)
    end
    chip:SetShown(rect ~= nil)
    -- Anchor To: a shown chip still takes the click (it picks), but never drags.
    chip:EnableMouse(rect ~= nil and interactive and (self:CanDrag(element) or self:Pickable(element)) or false)
    local tag, room = d.tag, (element.frame:GetWidth() or 0) - 4
    local inside = d.active and mode == "inside" and not d.selected and room >= 40 and (element.frame:GetHeight() or 0) >= 16
    if inside then
        d.tag.text:SetWidth(0)
        local width = math.min(d.tag.text:GetStringWidth() + 8, room)
        tag:SetWidth(width); tag.text:SetWidth(width - 8)
    end
    tag:SetShown(inside and true or false)
end

-- Renames an element's Edit Mode name (a custom bar renamed, say).
function PM:SetLabel(id, label)
    local element = self.elements[id]
    if not element or type(label) ~= "string" or label == "" then return false end
    element.label = label
    if element.decoration then
        element.decoration.label:SetText(label); element.decoration.tag.text:SetText(label)
        addon.EditLabels.dirty = true
    end
    return true
end

-- The selected element's place on the screen: its center's X and Y from the
-- screen's center (where the center lines cross), in whole UI units.
function PM:ScreenOffset(element)
    local x,y=addon.Positioning:Geometry(element.frame)
    local sx,sy=UIParent:GetCenter()
    if not x or not sx then return end
    return math.floor(x-sx+0.5),math.floor(y-sy+0.5)
end

-- Four arrow buttons (Place, in the Edit Mode panel): each click moves the
-- selected element one physical pixel. The arrows are the dropdown chevron,
-- turned. `selected` returns the element's id.
local NUDGES={{-1,0,-math.pi/2},{0,1,math.pi},{0,-1,0},{1,0,math.pi/2}}
function PM:NudgeButtons(parent, selected)
    local buttons={}
    for i,nudge in ipairs(NUDGES) do
        local button=CreateFrame("Button",nil,parent)
        button:SetSize(22,22)
        button:RegisterForClicks("LeftButtonUp")
        local background=button:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();PaintPanel(background)
        local arrow=button:CreateTexture(nil,"ARTWORK");arrow:SetPoint("CENTER");arrow:SetSize(16,16)
        addon.Media:ApplyTexture(arrow,"ModeChevron");arrow:SetVertexColor(unpack(addon.Style.Tone.edit.grid))
        if arrow.SetRotation then arrow:SetRotation(nudge[3]) end
        local hover=button:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();PaintHover(hover)
        button:SetScript("OnClick",function() local id=selected(); if id then self:Nudge(id,nudge[1],nudge[2]) end end)
        button.nudge=nudge
        buttons[i]=button
    end
    return buttons
end

function PM:ReleaseEditDecoration(element)
    local d=element.decoration
    if not d then return end
    d.frame:Hide();d.frame:ClearAllPoints();d.chip:EnableMouse(false)
    for _,name in ipairs({"OnMouseDown","OnDragStart","OnDragStop"}) do d.chip:SetScript(name,nil) end
    addon.Media:UnbindInterfaceFont(d.label);addon.Media:UnbindInterfaceFont(d.sub);addon.Media:UnbindInterfaceFont(d.tag.text)
    if self.hovered == element.id then self.hovered = nil end
    element.decoration=nil
end

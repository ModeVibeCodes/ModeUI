local _, addon = ...
local P = addon.Positioning
-- Edit Mode's focus (docs/DESIGN_LANGUAGE.md, "Edit Mode"): with an element
-- selected, the screen around it darkens (Tone.edit.scrim). Four plain
-- textures surround the element, so it needs no mask, and the layer takes no
-- clicks: every other element can still be picked. It sits in the DIALOG
-- strata at LEVEL, above every element's outline and name (they sink under
-- it), below the guides, the top bar and the panel; the selected element's
-- outline and chip, and the one under the mouse, lift above it
-- (PositionHighlights.lua). Dim and Strong are its strengths; Strong also
-- hides the other outlines until the mouse is over one. It halves while you
-- drag, so what you snap to stays in sight, and steps away while Anchor To or
-- Match waits for a click.
local F = { STRENGTH = { dim = 0.40, strong = 0.65 }, PAD = 2, LEVEL = 20, LIFT = 40, FADE = 0.12 }
addon.EditFocus = F

-- The focus in effect now ("dim" or "strong"), or nil.
function F:On()
    local E = addon.EditMode
    if not addon.editMode or not E then return nil end
    local mode = E:Focus()
    if mode == "off" or not E:Selected() then return nil end
    if addon.EditAnchor and addon.EditAnchor:Active() then return nil end
    return mode
end

function F:Build()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetAllPoints(UIParent); frame:SetFrameStrata("DIALOG"); frame:SetFrameLevel(self.LEVEL)
    frame:EnableMouse(false); frame:Hide()
    self.pieces = {}
    for i = 1, 4 do self.pieces[i] = frame:CreateTexture(nil, "BACKGROUND") end
    if frame.CreateAnimationGroup then
        local fade = frame:CreateAnimationGroup()
        local alpha = fade:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0); alpha:SetToAlpha(1); alpha:SetDuration(self.FADE)
        self.fade = fade
    end
    frame:SetScript("OnUpdate", function() F:Track() end)
    self.frame = frame
end

function F:Update()
    local mode = self:On()
    if not mode then
        if self.frame then self.frame:Hide() end
        return
    end
    if not self.frame then self:Build() end
    self.mode, self.key = mode, nil
    local shown = self.frame:IsShown()
    self.frame:Show()
    self:Track()
    if not shown and self.fade then self.fade:Play() end
end

-- Places the four pieces around the selected element and sets their alpha;
-- runs every frame while shown, so the opening follows a drag or a nudge.
function F:Track()
    local element = addon.EditMode:Selected()
    local x, y, w, h
    if element then x, y, w, h = P:Geometry(element.frame) end
    if not x then return end
    local alpha = self.STRENGTH[self.mode] * (element.dragging and 0.5 or 1)
    if self.key and self.key[1] == x and self.key[2] == y and self.key[3] == w and self.key[4] == h and self.key[5] == alpha then return end
    self.key, self.alpha = { x, y, w, h, alpha }, alpha
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local left, right = math.max(0, x - w / 2 - self.PAD), math.min(width, x + w / 2 + self.PAD)
    local bottom, top = math.max(0, y - h / 2 - self.PAD), math.min(height, y + h / 2 + self.PAD)
    -- Above, below, left and right of the opening: { left, top, right, bottom }.
    local rects = { { 0, height, width, top }, { 0, bottom, width, 0 }, { 0, top, left, bottom }, { right, top, width, bottom } }
    local c = addon.Style.Tone.edit.scrim
    for i, piece in ipairs(self.pieces) do
        local r = rects[i]
        piece:ClearAllPoints()
        piece:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", r[1], r[2])
        piece:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r[3], r[4])
        piece:SetColorTexture(c[1], c[2], c[3], alpha)
        piece:SetShown(r[3] > r[1] and r[2] > r[4])
        piece.rect = r
    end
end

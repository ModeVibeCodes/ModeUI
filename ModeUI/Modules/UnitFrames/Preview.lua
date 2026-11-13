local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- The settings preview: one sample of the frame chosen with Editing, built and
-- laid out by the same code as the frames in the world (BuildFace,
-- ApplyLayout, PaintSample), so it always matches the settings: portrait,
-- bars, texts, cast bar, auras and, on the Target, combo points. Static shows
-- the cast part-way through; Animated loops it. Clicking a part opens its
-- settings. Shown through the shared settings preview (W.Preview).
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local CAST_SECONDS, HINT_HEIGHT, MARGIN = 2.5, 18, 12

addon.PreviewStates:Register(M.id, {
    states = { { id = "static", label = "Static" }, { id = "animated", label = "Animated" } },
    animated = { animated = true }, previewAnimated = "animated",
    sample = function(_, phase) return phase end,
})

-- The frame the page is editing, else the Player.
function M:PreviewUnit()
    local page = self.page
    return page and page.unitFrameEditing and page.unitFrameEditing() or "player"
end

-- A sample part that opens its settings when clicked and lights up under the
-- mouse; regions that aren't frames get a frame laid over them.
local function Clickable(region, target, group, host)
    local hit = region
    if host then
        hit = CreateFrame("Frame", nil, host)
        hit:SetAllPoints(region)
        hit:SetFrameLevel(host:GetFrameLevel() + 2)
    end
    hit:EnableMouse(true)
    hit.jumpHighlight = W.Fill(hit, T.primary, "OVERLAY", 0, 0.16)
    hit.jumpHighlight:Hide()
    hit:SetScript("OnEnter", function() hit.jumpHighlight:Show() end)
    hit:SetScript("OnLeave", function() hit.jumpHighlight:Hide() end)
    hit:SetScript("OnMouseUp", function(_, button)
        if button == nil or button == "LeftButton" then M:JumpTo(target, group) end
    end)
    hit.jump = { target = target, group = group }
    return hit
end

-- Room around the frame for what sits outside it: the name and top aura rows
-- above, a cast bar and bottom aura rows below, the combo arc beside it.
local function Room(self, unit)
    local fdb = self:FrameDB(unit)
    local cast = self.db[unit].castBar
    local top, bottom, side = (fdb.showName and fdb.namePosition == "above") and fdb.nameFontSize + 8 or 6, 6, MARGIN
    if cast.enabled then
        local size = cast.height + 8 + cast.gap
        if cast.position == "above" then top = top + size else bottom = bottom + size end
    end
    for _, group in ipairs(self.auraGroups) do
        local adb = self.db[unit][group]
        if adb.enabled then
            local rows = math.ceil(math.min(adb.max, self.AURA_SAMPLE) / adb.perRow)
            local size = rows * (adb.size + adb.spacing) + 2
            if adb.anchor:find("^TOP") then top = top + size + math.max(0, adb.y) else bottom = bottom + size + math.max(0, -adb.y) end
        end
    end
    if unit == "target" and self.db.comboPoints.enabled then side = side + self.db.comboPoints.size + self.db.comboPoints.distance + 4 end
    return top, bottom, side
end

function M:GetPreviewSize(view)
    local unit = self:PreviewUnit()
    local face = view and view.faces[unit]
    local scale = self:FrameDB(unit).scale / 100
    local top, bottom, side = Room(self, unit)
    local g = face and face.geometry
    local width, height = g and g.width or 240, g and g.height or 70
    return math.max(320, width * scale + 2 * side * scale), (top + height + bottom) * scale + 6 + HINT_HEIGHT
end

-- Marks every part of a face as a way into its settings, once.
local function MakeClickable(face)
    if face.jumpReady then return end
    face.jumpReady = true
    Clickable(face.health, "health"); Clickable(face.power, "power"); Clickable(face.portrait, "portrait")
    Clickable(face.castBox, "cast")
    Clickable(face.nameText, "name", nil, face.textLayer)
    if face.combo then Clickable(face.combo, "combo") end
end

function M:RenderPreview(view)
    local unit = self:PreviewUnit()
    local phase = addon.PreviewStates:Sample(self.id)
    for name, face in pairs(view.faces) do if name ~= unit then face:Hide() end end
    local face = view.faces[unit]
    if not face then
        face = CreateFrame("Frame", nil, view.frame)
        face.unit, face.ghost, face.sample = unit, true, true
        self:BuildFace(face)
        view.faces[unit] = face
    end
    self:ApplyLayout(face, unit)
    self:PaintSample(face, unit)
    MakeClickable(face)
    for _, group in ipairs(self.auraGroups) do
        for _, icon in ipairs(face.auraIcons[group]) do if not icon.jump then Clickable(icon, "auras", group) end end
    end
    if phase and face.castBox:IsShown() then face.castBox.bar:SetValue((phase % CAST_SECONDS) / CAST_SECONDS) end
    -- Centred on whole pixels, below the room its name and top rows need.
    local top = Room(self, unit)
    local px = face.geometry.px
    local x = math.floor(-face.geometry.width / 2 / px + 0.5) * px
    face:ClearAllPoints()
    face:SetPoint("TOPLEFT", view.frame, "TOP", x, -math.floor(top / px + 0.5) * px)
    face:SetShown(self.db[unit].enabled)
    view.caption:SetText(self.db[unit].enabled and L[self.titles[unit]] or L["This frame is turned off"])
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, faces = {} }
    view.caption = W.Label(frame, "", nil, 0, 0, 200, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a part to open its settings"], nil, 0, 0, 200, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

-- Opens the settings for a part of the sample: its tab, and the aura group.
function M:JumpTo(target, group)
    local page = self.page
    if not page or not page.jumpTargets or not page.jumpTargets[target] then return false end
    if group and page.SetAuraGroup then page.SetAuraGroup(group) end
    page:Reveal(page.jumpTargets[target])
    return true
end

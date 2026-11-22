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
local CAST_SECONDS, HINT_HEIGHT = 2.5, 18
-- One fixed size, so moving or resizing a part never resizes the preview or
-- moves the sample (owner, November 13, 2026). The sample draws at 80% of the
-- frame's own scale (owner: the preview took too much of the page), with room
-- for the largest frame at 100% with a name and buffs above and a cast bar below.
M.PREVIEW_WIDTH, M.PREVIEW_HEIGHT, M.PREVIEW_SCALE = 440, 150, 0.8

addon.PreviewStates:Register(M.id, {
    states = { { id = "static", label = "Static" }, { id = "animated", label = "Animated" } },
    animated = { animated = true }, previewAnimated = "animated",
    sample = function(_, phase) return phase end,
})

-- The frame the page is editing, else the Player. (The class resource's
-- cards show while Editing is the Target, so the sample is the Target then.)
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

function M:GetPreviewSize() return self.PREVIEW_WIDTH, self.PREVIEW_HEIGHT end

-- Marks every part of a face as a way into its settings, once.
local function MakeClickable(face)
    if face.jumpReady then return end
    face.jumpReady = true
    Clickable(face.health, "health"); Clickable(face.power, "power"); Clickable(face.portrait, "portrait")
    Clickable(face.castBox, "cast")
    -- Each text opens the Text tab at its own spot.
    for slot, text in pairs(face.texts) do Clickable(text, "text:" .. slot, nil, face.textLayer) end
    if face.combo then Clickable(face.combo, "combo") end
end

function M:RenderPreview(view)
    local unit = self:PreviewUnit()
    local phase = addon.PreviewStates:Sample(self.id)
    for name, face in pairs(view.faces) do if name ~= unit then face:Hide() end end
    local face = view.faces[unit]
    if not face then
        face = CreateFrame("Frame", nil, view.frame)
        face.unit, face.ghost, face.sample, face.previewScale = unit, true, true, M.PREVIEW_SCALE
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
    -- A fixed spot: the frame's centre on the preview's centre (above the
    -- hint line), on whole pixels. Offsets are in the sample's own scale.
    local g, scale = face.geometry, face:GetScale()
    local px = g.px
    local function Snap(v) return math.floor(v / px + 0.5) * px end
    local width, height = view.frame:GetWidth(), view.frame:GetHeight()
    face:ClearAllPoints()
    face:SetPoint("TOPLEFT", view.frame, "TOPLEFT", Snap(width / 2 / scale - g.width / 2),
        -Snap((height - HINT_HEIGHT) / 2 / scale - g.height / 2))
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
    if group and target == "auras" and page.SetAuraGroup then page.SetAuraGroup(group) end
    page:Reveal(page.jumpTargets[target])
    return true
end

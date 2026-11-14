local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The settings preview: the sample party, built and laid out by the same
-- code as the members in the world, scaled to fit. Clicking a part opens its
-- settings (bars, texts, icons, an aura group). Shown through the shared
-- settings preview (W.Preview).
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local HINT_HEIGHT = 18
M.PREVIEW_WIDTH, M.PREVIEW_HEIGHT = 440, 200

addon.PreviewStates:Register(M.id, { states = { { id = "static", label = "Static" } }, sample = function() end })

function M:GetPreviewSize() return self.PREVIEW_WIDTH, self.PREVIEW_HEIGHT end

local function Clickable(region, target, host)
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
        if button == nil or button == "LeftButton" then M:JumpTo(target) end
    end)
    hit.jump = target
    return hit
end

local function MakeClickable(face)
    if face.jumpReady then return end
    face.jumpReady = true
    Clickable(face.health, "health"); Clickable(face.power, "power")
    for element, text in pairs(face.texts) do Clickable(text, "element:" .. element, face.textLayer) end
    for element, icon in pairs(face.icons) do Clickable(icon, "element:" .. element, face.textLayer) end
end

function M:RenderPreview(view)
    local frame, faces = view.frame, view.faces
    -- Laid out at full size first, then scaled to fit the preview.
    for _, face in ipairs(faces) do face.previewScale = 1 end
    local width, height = self:LayoutSamples(view.group, faces, self.MAX_MEMBERS)
    local room = 40 * (self.db.scale / 100)
    local fit = math.min(1, (frame:GetWidth() - 24) / (width + room), (frame:GetHeight() - HINT_HEIGHT - 12) / (height + room))
    fit = math.max(0.3, fit)
    for _, face in ipairs(faces) do face.previewScale = fit end
    width, height = self:LayoutSamples(view.group, faces, self.MAX_MEMBERS)
    local scale = self.db.scale / 100 * fit
    view.group:SetSize(width * scale, height * scale)
    view.group:ClearAllPoints()
    view.group:SetPoint("CENTER", frame, "CENTER", 0, HINT_HEIGHT / 2)
    view.group:SetScale(1)
    for i, face in ipairs(faces) do
        self:PaintSample(face, i)
        MakeClickable(face)
        for _, group in ipairs(self.auraGroups) do
            for _, icon in ipairs(face.auraIcons[group]) do if not icon.jump then Clickable(icon, "auras:" .. group) end end
        end
    end
    view.caption:SetText(self.enabled and L["Party Frames"] or L["Party Frames are turned off"])
    return scale
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, faces = {} }
    view.group = CreateFrame("Frame", nil, frame)
    for i = 1, self.MAX_MEMBERS do
        local face = CreateFrame("Frame", nil, view.group)
        face.ghost, face.sample = true, true
        self:BuildFace(face)
        view.faces[i] = face
    end
    view.caption = W.Label(frame, "", nil, 0, 0, 200, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a part to open its settings"], nil, 0, 0, 200, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

-- Opens the settings for a part of the sample: its tab, element or aura group.
function M:JumpTo(target)
    local page = self.page
    if not page or not page.jumpTargets then return false end
    local element = target:match("^element:(.+)$")
    local group = target:match("^auras:(.+)$")
    if element and page.SetElement then page.SetElement(element); target = "element" end
    if group and page.SetAuraGroup then page.SetAuraGroup(group); target = "auras" end
    local entry = page.jumpTargets[target]
    if not entry then return false end
    page:Reveal(entry)
    return true
end

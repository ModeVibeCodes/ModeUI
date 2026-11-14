local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The settings preview: sample members built and laid out by the same code
-- as the members in the world. One member by default; the header's sample
-- buttons show a party or raid sizes (groups of five side by side) to see how
-- the layout scales. Each sample size has a fixed scale and the samples hang
-- from a fixed top-left spot, so changing a size grows the sample in place
-- instead of rescaling or moving it. On the Auras tab the preview shows one
-- larger member with only the group being edited. Clicking a part opens its
-- settings. Shown through the shared settings preview (W.Preview).
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local HINT_HEIGHT, MARGIN = 18, 36
M.PREVIEW_WIDTH, M.PREVIEW_HEIGHT = 440, 190
M.AURA_PREVIEW_SCALE = 1.5
M.previewSample = "one"

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

function M:PreviewSample()
    for _, item in ipairs(self.previewSamples) do if item.id == self.previewSample then return item end end
    return self.previewSamples[1]
end
function M:SetPreviewSample(id)
    for _, item in ipairs(self.previewSamples) do
        if item.id == id then
            self.previewSample = id
            if self.page then self.page:Refresh() end
            return true
        end
    end
    return false
end

-- The aura group the Auras tab is editing while it is open, else nil.
function M:PreviewAuraGroup()
    local page = self.page
    local section = page and page.selectedSection
    if section and section.title == L["Auras"] and page.partyAuraGroup then return page.partyAuraGroup() end
end

function M:RenderPreview(view)
    local frame, faces = view.frame, view.faces
    local auraGroup = self:PreviewAuraGroup()
    local sample = self:PreviewSample()
    local count, fixed = sample.count, sample.scale
    if auraGroup then count, fixed = 1, self.AURA_PREVIEW_SCALE end
    for i = #faces + 1, count do
        local face = CreateFrame("Frame", nil, view.group)
        face.ghost, face.sample = true, true
        self:BuildFace(face)
        faces[i] = face
    end
    for _, face in ipairs(faces) do face.previewScale = fixed end
    local width, height = self:LayoutSamples(view.group, faces, count)
    local scale = faces[1]:GetScale()
    view.group:SetSize(width * scale, height * scale)
    view.group:ClearAllPoints()
    -- One member sits in the middle; groups hang from the top left.
    if count == 1 then
        local px = faces[1].geometry.px * scale
        local function Snap(v) return math.floor(v / px + 0.5) * px end
        view.group:SetPoint("TOPLEFT", frame, "TOPLEFT", Snap((frame:GetWidth() - width * scale) / 2),
            -Snap(math.max(MARGIN / 2, (frame:GetHeight() - HINT_HEIGHT - height * scale) / 2)))
    else view.group:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -MARGIN / 2) end
    for i = 1, count do
        local face = faces[i]
        self:PaintSample(face, i, auraGroup)
        MakeClickable(face)
        for _, group in ipairs(self.auraGroups) do
            for _, icon in ipairs(face.auraIcons[group]) do if not icon.jump then Clickable(icon, "auras:" .. group) end end
        end
    end
    local caption = auraGroup and L["Editing"] .. ": " .. L[self.auraGroupLabels[auraGroup]] or L[sample.label]
    view.caption:SetText(self.enabled and caption or L["Party Frames are turned off"])
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    if frame.SetClipsChildren then frame:SetClipsChildren(true) end
    local view = { frame = frame, faces = {} }
    view.group = CreateFrame("Frame", nil, frame)
    view.caption = W.Label(frame, "", nil, 0, 0, 200, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a part to open its settings"], nil, 0, 0, 200, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

-- Sample buttons for the preview header: One, Party and the raid sizes.
function M:PreviewSampleButtons(page)
    local buttons = {}
    for _, item in ipairs(self.previewSamples) do
        local button = W.Button(page.previewArea or page, L[item.label], 64, 24, "choice")
        button:SetScript("OnClick", function() M:SetPreviewSample(item.id) end)
        button.sampleId = item.id
        buttons[#buttons + 1] = button
    end
    page.refreshers[#page.refreshers + 1] = function()
        local aura = M:PreviewAuraGroup() ~= nil
        for _, button in ipairs(buttons) do
            button:SetSelected(button.sampleId == M.previewSample)
            button:SetEnabled(not aura)
        end
    end
    return buttons
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

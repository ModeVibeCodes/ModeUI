local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The settings preview: sample members (Samples.lua) built and laid out by
-- the same code as the members in the world. One member by default; the
-- header's sample buttons show a party or raid sizes (groups of five side by
-- side). Each sample size keeps its scale, and the preview grows taller to
-- hold the samples; only a layout too big for it is scaled down to fit, so
-- nothing clips. The open tab's element shows on the first sample
-- (M:PreviewFocus), and Show in the header adds states to every sample. On
-- the Auras tab the preview shows one larger member with only the group
-- being edited, beside a quick list of the groups (PreviewTools.lua).
-- Clicking a part opens its settings. Shown through W.Preview.
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local HINT_HEIGHT, MARGIN, MIN_HEIGHT, MAX_HEIGHT = 18, 24, 150, 380
M.PREVIEW_WIDTH, M.QUICK_WIDTH = 440, 132
M.AURA_PREVIEW_SCALE = 1.5
M.previewSample = "one"

addon.PreviewStates:Register(M.id, { states = { { id = "static", label = "Static" } }, sample = function() end })

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
        if button == nil or button == "LeftButton" then M:JumpTo(hit.jump) end
    end)
    hit.jump = target
    return hit
end
M.PreviewClickable = Clickable

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

-- The open tab's title, if the page is built.
function M:PreviewSection()
    local section = self.page and self.page.selectedSection
    return section and section.title
end
-- The aura group the Auras tab is editing while it is open, else nil.
function M:PreviewAuraGroup()
    if self:PreviewSection() == "Auras" and self.page.partyAuraGroup then return self.page.partyAuraGroup() end
end

-- What the open tab edits, shown on the first sample: the power bar on
-- General (a healer with mana); the heal, a shield (the Overshield state shows
-- the overshield) and the power bar on Fill; the element and the power bar on
-- Text; the dispel overlay (by type) and your target on Border.
local ELEMENT_STATES = { readyCheck = "readyCheck", incoming = "summon", status = "dead", raidIcon = "raidIcon", leader = "leader" }
function M:PreviewFocus()
    local page, section = self.page, self:PreviewSection()
    if not page or not section then return {} end
    if section == "General" then return { power = true } end
    if section == "Fill" then return { heals = true, shields = true, power = true } end
    if section == "Text" and page.partyElement then
        local focus = { power = true }
        local state = ELEMENT_STATES[page.partyElement()]
        if state then focus[state] = true end
        return focus
    end
    if section == "Border" and page.partyDispelType then return { dispel = page.partyDispelType(), target = page.partyShowTarget } end
    return {}
end

-- How many samples, at what scale (on top of the frames' own Scale), and how
-- tall the preview is for an `available` width.
function M:PreviewMetrics(available)
    local db = self.db
    local aura = self:PreviewAuraGroup() ~= nil
    local sample = self:PreviewSample()
    local count, scale = sample.count, sample.scale
    if aura then count, scale = 1, self.AURA_PREVIEW_SCALE end
    local g = self:Geometry(1)
    local spacing = math.floor(db.spacing + 0.5)
    local w, h = self:SampleSize(count, g, spacing, spacing + self.RAID_GROUP_GAP)
    local frames = db.scale / 100
    local room = available - 2 * MARGIN - (aura and self.QUICK_WIDTH or 0)
    if w * frames * scale > room then scale = room / (w * frames) end
    local tallest = MAX_HEIGHT - MARGIN - HINT_HEIGHT
    if h * frames * scale > tallest then scale = tallest / (h * frames) end
    local height = h * frames * scale + MARGIN + HINT_HEIGHT
    if aura then height = math.max(height, self:QuickListHeight() + HINT_HEIGHT + 8) end
    return count, scale, math.max(MIN_HEIGHT, math.floor(height + 0.5))
end

function M:PreviewWidth()
    local area = self.page and self.page.previewArea
    local width = area and area:GetWidth()
    if addon.IsNumber(width, 200) then return math.floor(width - 24) end
    return self.PREVIEW_WIDTH
end
function M:GetPreviewSize()
    local width = self:PreviewWidth()
    local _, _, height = self:PreviewMetrics(width)
    return width, height
end

function M:RenderPreview(view)
    local frame, faces = view.frame, view.faces
    local auraGroup = self:PreviewAuraGroup()
    local available = frame:GetWidth()
    if not addon.IsNumber(available, 100) then available = self:PreviewWidth() end
    local count, scale = self:PreviewMetrics(available)
    for i = #faces + 1, count do
        local face = CreateFrame("Frame", nil, view.group)
        face.ghost, face.sample = true, true
        self:BuildFace(face)
        faces[i] = face
    end
    for _, face in ipairs(faces) do face.previewScale = scale end
    local width, height = self:LayoutSamples(view.group, faces, count)
    local s = faces[1]:GetScale()
    view.group:SetSize(width * s, height * s)
    view.group:ClearAllPoints()
    local quick = auraGroup and self.QUICK_WIDTH or 0
    -- One member sits in the middle of the room left of the quick list;
    -- groups hang from the top left.
    local px = faces[1].geometry.px * s
    local function Snap(v) return math.floor(v / px + 0.5) * px end
    if count == 1 then
        view.group:SetPoint("TOPLEFT", frame, "TOPLEFT", Snap(math.max(MARGIN, (available - quick - width * s) / 2)),
            -Snap(math.max(MARGIN / 2, (frame:GetHeight() - HINT_HEIGHT - height * s) / 2)))
    else view.group:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -MARGIN / 2) end
    local focus = self:PreviewFocus()
    for i = 1, count do
        local states = {}
        for key, on in pairs(self.previewStates) do states[key] = on end
        if i == 1 then for key, on in pairs(focus) do states[key] = on end end
        local face = faces[i]
        self:PaintSample(face, i, auraGroup, states)
        MakeClickable(face)
        for _, group in ipairs(self.auraGroups) do
            for _, icon in ipairs(face.auraIcons[group]) do
                if not icon.jump then Clickable(icon, "auras:" .. group) end
            end
        end
    end
    self:LayoutQuickList(view, auraGroup)
    local sample = self:PreviewSample()
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

-- Opens the settings for a part of the sample: its tab, element or aura group.
function M:JumpTo(target)
    local page = self.page
    if not page or not page.jumpTargets or type(target) ~= "string" then return false end
    local element = target:match("^element:(.+)$")
    local group = target:match("^auras:(.+)$")
    if element and page.SetElement then page.SetElement(element); target = "element" end
    if group and page.SetAuraGroup then page.SetAuraGroup(group); target = "auras" end
    local entry = page.jumpTargets[target]
    if not entry then return false end
    page:Reveal(entry)
    return true
end

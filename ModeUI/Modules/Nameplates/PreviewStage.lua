local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The settings preview (owner, November 23, 2026: the magnified previewer):
--   * state chips: the cast (No Cast, Casting, Can't Interrupt, Interrupted),
--     Target or Not Target, and auras (None, Some, Full: every group at Most
--     Shown, its full reach);
--   * a stage with the kind being edited, magnified (2x, less when its full
--     reach can't fit) and pixel snapped. The health bar stays in the middle
--     across: changing an anchor never slides the plate sideways; up and down,
--     the plate's full reach is centered, from the layout, so states never
--     move it;
--   * a strip of three more plates in other states, smaller and each named
--     (friendly: a player and an NPC, names only by default).
-- Clicking a part of the stage plate jumps to its settings. Shown through the
-- shared settings preview (W.Preview); samples are painted in Preview.lua.
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local CHIPS_HEIGHT, STRIP_HEIGHT, CAPTION_HEIGHT, PREVIEW_HEIGHT = 26, 60, 18, 320
M.PREVIEW_ZOOM = 2

M.previewState = { cast = "cast", targeted = true, auras = "some" }
M.previewChips = {
    { key = "cast", choices = { { "none", "No Cast" }, { "cast", "Casting" }, { "locked", "Can't Interrupt" }, { "interrupted", "Interrupted" } } },
    { key = "targeted", choices = { { true, "Target" }, { false, "Not Target" } } },
    { key = "auras", choices = { { "none", "No Auras" }, { "some", "Some" }, { "full", "Full" } } },
}
-- The strip's plates: { sample key or nil for the kind's own, state, label }.
-- Smaller than the stage (owner, November 23, 2026), each named under it.
local STRIP = {
    enemy = { { nil, { cast = "none", targeted = false, focus = true, auras = "some", soft = false }, "Your Focus" },
        { nil, { cast = "locked", targeted = false, auras = "some", soft = false }, "Can't Interrupt" },
        { nil, { cast = "none", targeted = false, auras = "none", soft = false }, "No Cast, No Auras" } },
    friendly = { { nil, { cast = "none", targeted = false, auras = "some", soft = false }, "Friendly Player" },
        { "friendlyNPC", { cast = "none", targeted = false, auras = "none", soft = false }, "Friendly NPC" } },
}
local STRIP_SCALE, LABEL_HEIGHT = 0.75, 12

-- A text's click area covers the written text, not the whole line.
local function FitText(hit, text)
    local width = math.max(8, math.min(text:GetWidth(), text:GetStringWidth() + 4))
    local justify = text:GetJustifyH()
    local point = justify == "LEFT" and "LEFT" or justify == "RIGHT" and "RIGHT" or "CENTER"
    hit:ClearAllPoints()
    hit:SetPoint(point, text, point, 0, 0)
    hit:SetSize(width, math.max(8, text:GetStringHeight() + 2))
end

function M:GetPreviewSize() return 2000, PREVIEW_HEIGHT end

-- Builds one plate on the stage or the strip; `clickable` plates jump.
local function SamplePlate(self, parent, kind, clickable)
    local plate = self:BuildPlate(parent, true)
    plate.kind, plate.sample, plate.clickable = kind, true, clickable
    return plate
end

-- Places the stage plate: zoomed, the bar centered across, its full reach
-- centered up and down, on whole pixels.
local function Stage(self, view, plate, style, progress)
    local stage = view.stage
    -- While the page shows the focus highlight (the Glow tab) the sample is
    -- your focus instead of your target.
    local page, state = self.page, {}
    for key, value in pairs(self.previewState) do state[key] = value end
    state.focus = page and page.nameplateFocusSample and page.nameplateFocusSample() or false
    plate:SetScale(1)
    self:LayoutPlate(plate)
    local sample = self.previewSamples[plate.kind]
    self:PaintSample(plate, style, sample, progress, state)
    local left, right, up, down = self:PreviewReach(plate)
    local halfWidth = plate:GetWidth() / 2 + math.max(left, right)
    local height = up + plate:GetHeight() + down
    local width, room = stage:GetWidth(), stage:GetHeight()
    local zoom = M.PREVIEW_ZOOM
    if addon.IsNumber(width, 1) and addon.IsNumber(room, 1) then
        zoom = math.min(zoom, (width - 16) / (2 * halfWidth), (room - 8) / height)
        -- Quarter steps: the plate is laid out again at its zoom, so every
        -- step stays on whole physical pixels.
        zoom = math.max(1, math.floor(zoom * 4) / 4)
    end
    plate:SetScale(zoom)
    -- The scale changes the plate's pixel size: lay it out again at the zoom.
    self:LayoutPlate(plate)
    self:PaintSample(plate, style, sample, progress, state)
    local px = plate.px or 1
    local y = math.floor(((down - up) / 2) / px + 0.5) * px
    plate:ClearAllPoints(); plate:SetPoint("CENTER", stage, "CENTER", 0, y)
    plate:Show()
    view.zoom = zoom
end

-- The strip: each plate at 3/4 size (less if its full reach can't fit), in
-- its own slot, its reach centered above a label naming what it shows.
local function Strip(self, view, kind, style, progress)
    local list = STRIP[kind] or {}
    local count = math.max(1, #list)
    local width = view.stripFrame:GetWidth()
    local slot = (addon.IsNumber(width, 1) and width or 600) / count
    for i, plate in ipairs(view.strip[kind]) do
        local entry, label = list[i], view.stripLabels[kind][i]
        if not entry or not style.show then plate:Hide(); label:Hide()
        else
            plate:SetScale(1)
            self:LayoutPlate(plate)
            local sample = self.previewSamples[entry[1] or kind]
            self:PaintSample(plate, style, sample, progress, entry[2])
            local left, right, up, down = self:PreviewReach(plate)
            local scale = math.min(STRIP_SCALE, (STRIP_HEIGHT - LABEL_HEIGHT - 6) / (up + plate:GetHeight() + down),
                (slot - 8) / (plate:GetWidth() + 2 * math.max(left, right)))
            plate:SetScale(math.max(0.4, scale))
            self:LayoutPlate(plate)
            self:PaintSample(plate, style, sample, progress, entry[2])
            local px = plate.px or 1
            local x = (i - 0.5) * slot - (addon.IsNumber(width, 1) and width or 600) / 2
            -- Offsets are in the plate's own (scaled) units.
            local y = LABEL_HEIGHT / 2 / plate:GetScale() + (down - up) / 2
            plate:ClearAllPoints()
            plate:SetPoint("CENTER", view.stripFrame, "CENTER", math.floor(x / plate:GetScale() / px + 0.5) * px, math.floor(y / px + 0.5) * px)
            plate:Show()
            label:SetText(L[entry[3]])
            label:ClearAllPoints(); label:SetPoint("BOTTOM", view.stripFrame, "BOTTOM", math.floor(x + 0.5), 1)
            label:Show()
        end
    end
end

function M:RenderPreview(view)
    local phase = addon.PreviewStates:Sample(self.id)
    local progress = phase and (phase % M.PREVIEW_CAST_SECONDS) / M.PREVIEW_CAST_SECONDS or M.PREVIEW_STATIC_PROGRESS
    local shownKind = self:PreviewKind()
    for _, chip in ipairs(view.chips) do chip:SetSelected(self.previewState[chip.stateKey] == chip.stateValue) end
    for _, kind in ipairs(self.kinds) do
        local style, plate = self.db[kind], view.plates[kind]
        local on = kind == shownKind and style.show
        if not on then
            plate:Hide()
            for _, other in ipairs(view.strip[kind]) do other:Hide() end
            for _, label in ipairs(view.stripLabels[kind]) do label:Hide() end
        else
            Stage(self, view, plate, style, progress)
            Strip(self, view, kind, style, progress)
            FitText(view.targets[kind].name, plate.name)
            FitText(view.targets[kind].healthText, plate.healthText)
        end
    end
    local style = self.db[shownKind]
    view.caption:SetText(style.show and L[self.previewSamples[shownKind].caption] .. string.format(" · %gx", view.zoom or 1)
        or L[self.kindLabels[shownKind] .. " plates use Blizzard's look"])
end

-- A state chip: picks one value of the preview state.
local function Chip(self, view, parent, key, value, label)
    local button = W.Button(parent, L[label], 60, 20, "choice")
    button:SetWidth(math.max(56, math.ceil(button.label:GetStringWidth()) + 14))
    button.stateKey, button.stateValue = key, value
    button:SetScript("OnClick", function() self.previewState[key] = value; self:RenderPreview(view) end)
    view.chips[#view.chips + 1] = button
    return button
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, plates = {}, strip = {}, stripLabels = {}, targets = {}, chips = {} }
    -- Chips along the top.
    local chips = CreateFrame("Frame", nil, frame)
    chips:SetPoint("TOPLEFT"); chips:SetPoint("TOPRIGHT"); chips:SetHeight(CHIPS_HEIGHT)
    local x = 0
    for g, chip in ipairs(M.previewChips) do
        for _, choice in ipairs(chip.choices) do
            local button = Chip(self, view, chips, chip.key, choice[1], choice[2])
            button:SetPoint("LEFT", chips, "LEFT", x, 0)
            x = x + button:GetWidth() + 2
        end
        if g < #M.previewChips then x = x + 10 end
    end
    -- The stage, the strip and the captions.
    view.stage = CreateFrame("Frame", nil, frame)
    view.stage:SetPoint("TOPLEFT", chips, "BOTTOMLEFT", 0, -4); view.stage:SetPoint("RIGHT", frame, "RIGHT")
    view.stage:SetPoint("BOTTOM", frame, "BOTTOM", 0, STRIP_HEIGHT + CAPTION_HEIGHT)
    view.stage:SetClipsChildren(true)
    view.stripFrame = CreateFrame("Frame", nil, frame)
    view.stripFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, CAPTION_HEIGHT); view.stripFrame:SetPoint("RIGHT", frame, "RIGHT")
    view.stripFrame:SetHeight(STRIP_HEIGHT)
    view.stripFrame:SetClipsChildren(true)
    view.stripLine = W.Fill(view.stripFrame, T.line or T.muted, "BACKGROUND", 0, 0.5)
    view.stripLine:ClearAllPoints(); view.stripLine:SetPoint("TOPLEFT"); view.stripLine:SetPoint("TOPRIGHT"); view.stripLine:SetHeight(1)
    for _, kind in ipairs(self.kinds) do
        local plate = SamplePlate(self, view.stage, kind, true)
        view.plates[kind] = plate
        view.targets[kind] = {
            health = M.Clickable(plate.healthBox, kind, "health"),
            cast = M.Clickable(plate.castBox, kind, "cast"),
            name = M.Clickable(plate.name, kind, "name", nil, plate.textLayer),
            healthText = M.Clickable(plate.healthText, kind, "healthText", nil, plate.textLayer),
            markers = M.Clickable(plate.raidIcon, kind, "markers", nil, plate.textLayer),
            softTarget = M.Clickable(plate.softTarget, kind, "softTarget", nil, plate.textLayer),
            combo = M.Clickable(plate.combo, kind, "combo"),
            quest = M.Clickable(plate.indicatorParts.quest, kind, "indicator", "quest", plate.textLayer),
            classification = M.Clickable(plate.indicatorParts.classification, kind, "indicator", "classification", plate.textLayer),
            level = M.Clickable(plate.indicatorParts.level, kind, "indicator", "level", plate.textLayer),
        }
        view.strip[kind], view.stripLabels[kind] = {}, {}
        for i = 1, 3 do
            view.strip[kind][i] = SamplePlate(self, view.stripFrame, kind, false)
            local label = W.Label(view.stripFrame, "", nil, 0, 0, 160, T.muted)
            label:SetJustifyH("CENTER"); label:Hide()
            view.stripLabels[kind][i] = label
        end
    end
    view.caption = W.Label(frame, "", nil, 0, 0, 260, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a part to open its settings"], nil, 0, 0, 200, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

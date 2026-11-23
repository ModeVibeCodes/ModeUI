local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The settings preview (owner, November 23, 2026: the magnified previewer,
-- one plate):
--   * state chips: the cast (No Cast, Casting, Can't Interrupt, Interrupted),
--     the highlight (Target, Focus, Neither), auras (None, Some, Full: every
--     group at Most Shown, its full reach) and, for friendly plates, the
--     sample (Player, NPC);
--   * a stage with the kind being edited, magnified (2x at most, less when its
--     full reach can't fit, in quarter steps) and pixel snapped. The health
--     bar stays in the middle across: changing an anchor never slides the
--     plate sideways; up and down, the plate's full reach is centered, from
--     the layout, so states never move it.
-- Clicking a part of the plate jumps to its settings. Shown through the shared
-- settings preview (W.Preview); samples are painted in Preview.lua.
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local CHIPS_HEIGHT, CAPTION_HEIGHT, PREVIEW_HEIGHT = 26, 18, 230
M.PREVIEW_ZOOM = 2

M.previewState = { cast = "cast", highlight = "target", auras = "some", sample = "player" }
M.previewChips = {
    { key = "cast", choices = { { "none", "No Cast" }, { "cast", "Casting" }, { "locked", "Can't Interrupt" }, { "interrupted", "Interrupted" } } },
    { key = "highlight", choices = { { "target", "Target" }, { "focus", "Focus" }, { "none", "Neither" } } },
    { key = "auras", choices = { { "none", "No Auras" }, { "some", "Some" }, { "full", "Full" } } },
    { key = "sample", kind = "friendly", choices = { { "player", "Player" }, { "npc", "NPC" } } },
}

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

-- The sample and state the chips pick. While the page shows the focus
-- highlight (the Glow tab) the sample is your focus.
function M:PreviewSample(kind)
    local chosen, page = self.previewState, self.page
    local state = { cast = chosen.cast, auras = chosen.auras, targeted = chosen.highlight == "target",
        focus = chosen.highlight == "focus" or (page and page.nameplateFocusSample and page.nameplateFocusSample()) or false }
    if state.focus then state.targeted = false end
    local sample = (kind == "friendly" and chosen.sample == "npc") and self.previewSamples.friendlyNPC or self.previewSamples[kind]
    return sample, state
end

-- Places the plate: zoomed, the bar centered across, its full reach centered
-- up and down, on whole pixels.
local function Stage(self, view, plate, style, progress)
    local stage = view.stage
    local sample, state = self:PreviewSample(plate.kind)
    plate:SetScale(1)
    self:LayoutPlate(plate)
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
    view.zoom, view.sample = zoom, sample
end

-- Lines up the chips for the kind being edited (the sample chips are friendly only).
local function LayoutChips(view, kind)
    local x, group = 0, nil
    for _, chip in ipairs(view.chips) do
        local shown = chip.chipKind == nil or chip.chipKind == kind
        chip:SetShown(shown)
        if shown then
            if group and chip.stateKey ~= group then x = x + 10 end
            group = chip.stateKey
            chip:ClearAllPoints(); chip:SetPoint("LEFT", view.chipRow, "LEFT", x, 0)
            x = x + chip:GetWidth() + 2
        end
    end
end

function M:RenderPreview(view)
    local phase = addon.PreviewStates:Sample(self.id)
    local progress = phase and (phase % M.PREVIEW_CAST_SECONDS) / M.PREVIEW_CAST_SECONDS or M.PREVIEW_STATIC_PROGRESS
    local shownKind = self:PreviewKind()
    LayoutChips(view, shownKind)
    for _, chip in ipairs(view.chips) do chip:SetSelected(self.previewState[chip.stateKey] == chip.stateValue) end
    for _, kind in ipairs(self.kinds) do
        local style, plate = self.db[kind], view.plates[kind]
        if kind == shownKind and style.show then
            Stage(self, view, plate, style, progress)
            FitText(view.targets[kind].name, plate.name)
            FitText(view.targets[kind].healthText, plate.healthText)
        else
            plate:Hide()
        end
    end
    local style = self.db[shownKind]
    view.caption:SetText(style.show and L[(view.sample or self.previewSamples[shownKind]).caption] .. string.format(" · %gx", view.zoom or 1)
        or L[self.kindLabels[shownKind] .. " plates use Blizzard's look"])
end

-- A state chip: picks one value of the preview state.
local function Chip(self, view, parent, group, value, label)
    local button = W.Button(parent, L[label], 60, 20, "choice")
    button:SetWidth(math.max(56, math.ceil(button.label:GetStringWidth()) + 14))
    button.stateKey, button.stateValue, button.chipKind = group.key, value, group.kind
    button:SetScript("OnClick", function() self.previewState[group.key] = value; self:RenderPreview(view) end)
    view.chips[#view.chips + 1] = button
    return button
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, plates = {}, targets = {}, chips = {} }
    view.chipRow = CreateFrame("Frame", nil, frame)
    view.chipRow:SetPoint("TOPLEFT"); view.chipRow:SetPoint("TOPRIGHT"); view.chipRow:SetHeight(CHIPS_HEIGHT)
    for _, group in ipairs(M.previewChips) do
        for _, choice in ipairs(group.choices) do Chip(self, view, view.chipRow, group, choice[1], choice[2]) end
    end
    LayoutChips(view, "enemy")
    view.stage = CreateFrame("Frame", nil, frame)
    view.stage:SetPoint("TOPLEFT", view.chipRow, "BOTTOMLEFT", 0, -4); view.stage:SetPoint("RIGHT", frame, "RIGHT")
    view.stage:SetPoint("BOTTOM", frame, "BOTTOM", 0, CAPTION_HEIGHT)
    view.stage:SetClipsChildren(true)
    for _, kind in ipairs(self.kinds) do
        local plate = self:BuildPlate(view.stage, true)
        plate.kind, plate.sample, plate.clickable = kind, true, true
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
    end
    view.caption = W.Label(frame, "", nil, 0, 0, 260, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a part to open its settings"], nil, 0, 0, 200, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The settings preview: a sample enemy and friendly plate side by side, built
-- and laid out by the same code as the plates in the world, so they always
-- match the current settings. Static shows a cast part-way through; Animated
-- loops the cast. Shown through the shared settings preview (W.Preview).
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local RaidIcon = addon.Domain.RaidIcon
local CAST_SECONDS, STATIC_PROGRESS = 2.5, 0.6

M.previewSamples = {
    enemy = { name = "Enemy Nameplate", caption = "Enemy (your target)", health = 72, reaction = "hostile", raid = 8, targeted = true,
        cast = { text = "Shadow Bolt", icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt" } },
    friendly = { name = "Friendly Nameplate", caption = "Friendly", health = 90, reaction = "friendly",
        cast = { text = "Flash Heal", icon = "Interface\\Icons\\Spell_Holy_FlashHeal" } },
}

addon.PreviewStates:Register(M.id, {
    states = { { id = "static", label = "Static" }, { id = "animated", label = "Animated" } },
    animated = { animated = true }, previewAnimated = "animated",
    sample = function(_, phase) return phase end,
})

local function Thousands(number)
    local text, count = tostring(number), 0
    repeat text, count = text:gsub("^(%d+)(%d%d%d)", "%1,%2") until count == 0
    return text
end
local function HealthText(mode, percent)
    local current = Thousands(percent * 120)
    if mode == "current" then return current end
    if mode == "both" then return current .. " · " .. percent .. "%" end
    return percent .. "%"
end

function M:PaintSample(plate, style, sample, progress)
    plate.health:SetMinMaxValues(0, 100); plate.health:SetValue(sample.health)
    local color = self:ColorFor(style, nil, sample.reaction, nil)
    plate.health:SetStatusBarColor(color[1], color[2], color[3])
    Kit.Write(plate.name, L[sample.name])
    Kit.Write(plate.healthText, HealthText(style.healthText, sample.health))
    if style.showRaidIcon and sample.raid then RaidIcon.ApplyIndex(plate.raidIcon, sample.raid) else plate.raidIcon:Hide() end
    self:PaintTarget(plate, style.targetHighlight and sample.targeted == true)
    if not style.showCastBar then self:StopCast(plate); return end
    plate.cast:SetMinMaxValues(0, 1); plate.cast:SetValue(progress)
    self:PaintCast(plate, style, false, false, L[sample.cast.text], sample.cast.icon)
end

-- Space above a plate for its name.
local function NameSpace(style) return style.showName and style.nameFontSize + 6 or 4 end

function M:GetPreviewSize()
    local column, height = 0, 0
    for _, kind in ipairs(self.kinds) do
        local style = self.db[kind]
        column = math.max(column, style.width + 48)
        height = math.max(height, NameSpace(style) + style.healthHeight + style.castHeight + 10 + 26)
    end
    return math.max(320, 2 * column + 24), height + 8
end

function M:RenderPreview(view)
    local phase = addon.PreviewStates:Sample(self.id)
    local progress = phase and (phase % CAST_SECONDS) / CAST_SECONDS or STATIC_PROGRESS
    local quarter = view.frame:GetWidth() / 4
    for index, kind in ipairs(self.kinds) do
        local style, plate, caption = self.db[kind], view.plates[kind], view.captions[kind]
        local x = (index == 1 and -1 or 1) * quarter
        caption:ClearAllPoints()
        if style.show then
            self:LayoutPlate(plate)
            plate:ClearAllPoints(); plate:SetPoint("TOP", view.frame, "TOP", x, -NameSpace(style))
            plate:Show()
            self:PaintSample(plate, style, self.previewSamples[kind], progress)
            caption:SetPoint("TOP", plate, "BOTTOM", 0, -8)
            caption:SetText(L[self.previewSamples[kind].caption])
        else
            plate:Hide()
            caption:SetPoint("TOP", view.frame, "TOP", x, -NameSpace(style))
            caption:SetText(L[self.kindLabels[kind] .. " plates use Blizzard's look"])
        end
    end
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, plates = {}, captions = {} }
    for _, kind in ipairs(self.kinds) do
        local plate = self:BuildPlate(frame)
        plate.kind, plate.sample = kind, true
        view.plates[kind] = plate
        local caption = W.Label(frame, "", nil, 0, 0, 220, T.muted)
        caption:SetJustifyH("CENTER")
        view.captions[kind] = caption
    end
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

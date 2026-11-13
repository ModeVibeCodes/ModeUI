local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The settings preview: a sample enemy and friendly plate side by side, built
-- and laid out by the same code as the plates in the world, so they always
-- match the current settings, auras included. Static shows a cast part-way
-- through; Animated loops the cast. Shown through the shared settings preview
-- (W.Preview).
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local RaidIcon = addon.Domain.RaidIcon
local CAST_SECONDS, STATIC_PROGRESS = 2.5, 0.6
local ICONS = "Interface\\Icons\\"

-- Each sample aura belongs to a group (cc, debuff, buff); its tags say which
-- Debuffs or Buffs choices it matches, as the game's filters would.
M.previewSamples = {
    enemy = { name = "Enemy Nameplate", caption = "Enemy (your target)", health = 72, reaction = "hostile", raid = 8, targeted = true,
        cast = { text = "Shadow Bolt", icon = ICONS .. "Spell_Shadow_ShadowBolt" },
        auras = {
            { icon = ICONS .. "Spell_Nature_Polymorph", group = "cc", duration = 8, elapsed = 3 },
            { icon = ICONS .. "Spell_Shadow_ShadowWordPain", group = "debuff", tags = { mine = true }, duration = 18, elapsed = 6 },
            { icon = ICONS .. "Spell_Shadow_CurseOfTounges", group = "debuff", tags = { dispellable = true }, count = 3, duration = 30, elapsed = 10 },
            { icon = ICONS .. "Spell_Holy_PowerWordShield", group = "buff", tags = { dispellable = true, important = true }, duration = 15, elapsed = 5 },
        } },
    friendly = { name = "Friendly Nameplate", caption = "Friendly", health = 90, reaction = "friendly",
        cast = { text = "Flash Heal", icon = ICONS .. "Spell_Holy_FlashHeal" },
        auras = {
            { icon = ICONS .. "Spell_Frost_ChainsOfIce", group = "cc", duration = 6, elapsed = 2 },
            { icon = ICONS .. "Spell_Shadow_AbominationExplosion", group = "debuff", tags = { dispellable = true }, duration = 12, elapsed = 4 },
            { icon = ICONS .. "Spell_Nature_Rejuvenation", group = "buff", tags = { mine = true }, count = 2, duration = 12, elapsed = 4 },
        } },
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

-- The sample auras a style would show: the same groups and order as in the
-- world (crowd control, debuffs, buffs), up to the style's maximum.
function M:SampleAuras(style, sample)
    local shown = {}
    if not style.showAuras then return shown end
    local function Take(group, mode)
        for _, aura in ipairs(sample.auras) do
            local match = aura.group == group and (group == "cc" or mode == "all" or (aura.tags and aura.tags[mode]))
            if match and #shown < style.auraMax then shown[#shown + 1] = aura end
        end
    end
    if style.auraCrowdControl then Take("cc") end
    if style.auraDebuffs ~= "none" then Take("debuff", style.auraDebuffs) end
    if style.auraBuffs ~= "none" then Take("buff", style.auraBuffs) end
    return shown
end

function M:PaintSampleAuras(plate, style, sample)
    local auras = self:SampleAuras(style, sample)
    for index, aura in ipairs(auras) do
        local icon = self:AuraIcon(plate, index)
        icon.icon:SetTexture(aura.icon)
        Kit.Write(icon.count, (style.auraCount and aura.count) and tostring(aura.count) or "")
        if style.auraTimer then
            icon.cooldown:SetCooldown(GetTime() - aura.elapsed, aura.duration); icon.cooldown:Show()
        else icon.cooldown:Hide() end
        icon:Show()
    end
    self:HideAuras(plate, #auras + 1)
    self:LayoutAuras(plate, #auras)
end

function M:PaintSample(plate, style, sample, progress)
    plate.health:SetMinMaxValues(0, 100); plate.health:SetValue(sample.health)
    local color = self:ColorFor(style, nil, sample.reaction, nil)
    plate.health:SetStatusBarColor(color[1], color[2], color[3])
    Kit.Write(plate.name, L[sample.name])
    Kit.Write(plate.healthText, HealthText(style.healthText, sample.health))
    if style.showRaidIcon and sample.raid then RaidIcon.ApplyIndex(plate.raidIcon, sample.raid) else plate.raidIcon:Hide() end
    self:PaintTarget(plate, style.targetHighlight and sample.targeted == true)
    self:PaintSampleAuras(plate, style, sample)
    if not style.showCastBar then self:StopCast(plate); return end
    plate.cast:SetMinMaxValues(0, 1); plate.cast:SetValue(progress)
    self:PaintCast(plate, style, false, false, L[sample.cast.text], sample.cast.icon)
end

-- Space above a plate for its name and for auras shown above it; below it for
-- auras shown below; beside it for auras shown left or right.
local function Above(style)
    local space = style.showName and style.nameFontSize + 6 or 4
    if style.showAuras and style.auraPosition == "above" then space = space + style.auraSize + 4 end
    return space
end
local function Below(style) return (style.showAuras and style.auraPosition == "below") and style.auraSize + 4 or 0 end
local function Beside(style)
    if not style.showAuras or (style.auraPosition ~= "left" and style.auraPosition ~= "right") then return 0 end
    return math.min(style.auraMax, 4) * (style.auraSize + style.auraSpacing)
end

function M:GetPreviewSize()
    local column, height = 0, 0
    for _, kind in ipairs(self.kinds) do
        local style = self.db[kind]
        column = math.max(column, style.width + 48 + Beside(style))
        height = math.max(height, Above(style) + style.healthHeight + style.castHeight + 10 + Below(style) + 26)
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
            plate:ClearAllPoints(); plate:SetPoint("TOP", view.frame, "TOP", x, -Above(style))
            plate:Show()
            self:PaintSample(plate, style, self.previewSamples[kind], progress)
            caption:SetPoint("TOP", plate, "BOTTOM", 0, -8 - Below(style))
            caption:SetText(L[self.previewSamples[kind].caption])
        else
            plate:Hide()
            caption:SetPoint("TOP", view.frame, "TOP", x, -Above(style))
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

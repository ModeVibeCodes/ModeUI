local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The settings preview: a sample enemy and friendly plate side by side, built
-- and laid out by the same code as the plates in the world, so they always
-- match the current settings, auras included. Static shows a cast part-way
-- through; Animated loops the cast. Clicking a part of a sample (health, name,
-- health text, cast bar, an aura, the raid marker) jumps to its settings.
-- Shown through the shared settings preview (W.Preview).
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local RaidIcon = addon.Domain.RaidIcon
local CAST_SECONDS, STATIC_PROGRESS, HINT_HEIGHT = 2.5, 0.6, 18
local ICONS = "Interface\\Icons\\"

-- Each sample aura belongs to a group; its tags say which Which choices it
-- matches, as the game's filters would.
M.previewSamples = {
    enemy = { name = "Enemy Nameplate", caption = "Enemy (your target)", health = 72, reaction = "hostile", raid = 8, targeted = true,
        cast = { text = "Shadow Bolt", icon = ICONS .. "Spell_Shadow_ShadowBolt" },
        auras = {
            { icon = ICONS .. "Spell_Nature_Polymorph", group = "crowdControl", duration = 8, elapsed = 3 },
            { icon = ICONS .. "Spell_Shadow_ShadowWordPain", group = "debuffs", tags = { mine = true }, duration = 18, elapsed = 6 },
            { icon = ICONS .. "Spell_Shadow_CurseOfTounges", group = "debuffs", tags = { dispellable = true }, count = 3, duration = 30, elapsed = 10 },
            { icon = ICONS .. "Spell_Holy_PowerWordShield", group = "buffs", tags = { dispellable = true, important = true }, duration = 15, elapsed = 5 },
        } },
    friendly = { name = "Friendly Nameplate", caption = "Friendly", health = 90, reaction = "friendly",
        cast = { text = "Flash Heal", icon = ICONS .. "Spell_Holy_FlashHeal" },
        auras = {
            { icon = ICONS .. "Spell_Frost_ChainsOfIce", group = "crowdControl", duration = 6, elapsed = 2 },
            { icon = ICONS .. "Spell_Shadow_AbominationExplosion", group = "debuffs", tags = { dispellable = true }, duration = 12, elapsed = 4 },
            { icon = ICONS .. "Spell_Nature_Rejuvenation", group = "buffs", tags = { mine = true }, count = 2, duration = 12, elapsed = 4 },
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

-- A sample part that jumps to its settings when clicked and lights up under
-- the mouse. Frames take the click themselves; text and textures get a frame
-- laid over them.
local function Clickable(region, kind, target, group, host)
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
        if button == nil or button == "LeftButton" then M:JumpTo(kind, target, group) end
    end)
    hit.jump = { kind = kind, target = target, group = group }
    return hit
end

-- The sample auras one group would show, as the game's filters would pick them.
function M:SampleAuras(style, sample, group)
    local shown, settings = {}, style[group]
    if not style.showAuras or not settings.show then return shown end
    for _, aura in ipairs(sample.auras) do
        local match = aura.group == group and (group == "crowdControl" or settings.filter == "all" or (aura.tags and aura.tags[settings.filter]))
        if match and #shown < settings.max then shown[#shown + 1] = aura end
    end
    return shown
end

function M:PaintSampleAuras(plate, style, sample)
    for _, group in ipairs(self.auraGroups) do
        local auras = self:SampleAuras(style, sample, group)
        for index, aura in ipairs(auras) do
            local icon = self:AuraIcon(plate, group, index)
            if not icon.jump then Clickable(icon, plate.kind, "auras", group) end
            icon.icon:SetTexture(aura.icon)
            Kit.Write(icon.count, (style.auraCount and aura.count) and tostring(aura.count) or "")
            if style.auraTimer then
                icon.cooldown:SetCooldown(GetTime() - aura.elapsed, aura.duration); icon.cooldown:Show()
            else icon.cooldown:Hide() end
            icon:Show()
        end
        self:HideAuras(plate, group, #auras + 1)
    end
    self:LayoutAuras(plate)
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

-- Room a style's auras need around the plate: above, below and beside it.
local function AuraRoom(style)
    local room = { top = 0, bottom = 0, side = 0 }
    if not style.showAuras then return room end
    for _, group in ipairs(M.auraGroups) do
        local settings = style[group]
        if settings.show then
            local anchor, size = settings.anchor, settings.size + style.auraSpacing
            if anchor:find("^TOP") then room.top = room.top + size + math.max(0, settings.y)
            elseif anchor:find("^BOTTOM") then room.bottom = room.bottom + size + math.max(0, -settings.y)
            else room.side = room.side + math.min(settings.max, 3) * size + math.abs(settings.x) end
        end
    end
    return room
end
local function Above(style) return (style.showName and style.nameFontSize + 6 or 4) + AuraRoom(style).top end

function M:GetPreviewSize()
    local column, height = 0, 0
    for _, kind in ipairs(self.kinds) do
        local style = self.db[kind]
        local room = AuraRoom(style)
        column = math.max(column, style.width + 48 + room.side)
        height = math.max(height, Above(style) + style.healthHeight + style.castHeight + 10 + room.bottom + 26)
    end
    return math.max(320, 2 * column + 24), height + 8 + HINT_HEIGHT
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
            caption:SetPoint("TOP", plate, "BOTTOM", 0, -8 - AuraRoom(style).bottom)
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
    local view = { frame = frame, plates = {}, captions = {}, targets = {} }
    for _, kind in ipairs(self.kinds) do
        local plate = self:BuildPlate(frame)
        plate.kind, plate.sample = kind, true
        view.plates[kind] = plate
        view.targets[kind] = {
            health = Clickable(plate.healthBox, kind, "health"),
            cast = Clickable(plate.castBox, kind, "cast"),
            name = Clickable(plate.name, kind, "name", nil, plate.textLayer),
            healthText = Clickable(plate.healthText, kind, "healthText", nil, plate.textLayer),
            markers = Clickable(plate.raidIcon, kind, "markers", nil, plate.textLayer),
        }
        local caption = W.Label(frame, "", nil, 0, 0, 220, T.muted)
        caption:SetJustifyH("CENTER")
        view.captions[kind] = caption
    end
    view.hint = W.Label(frame, L["Click any part of a sample to jump to its settings."], nil, 0, 0, 360, T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2); view.hint:SetJustifyH("CENTER")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

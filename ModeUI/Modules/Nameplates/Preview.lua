local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The settings preview: one sample plate, the kind chosen with Editing,
-- centered and built by the same code as the plates in the world, so it always
-- matches the current settings (layout, auras, target style, Name Only).
-- Static shows a cast part-way through; Animated loops it. Clicking a part of
-- the sample (health, name, health text, cast bar, an aura, the raid marker)
-- jumps to its settings. Shown through the shared settings preview (W.Preview).
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local RaidIcon, UnitColor, Level = addon.Domain.RaidIcon, addon.Domain.UnitColor, addon.Domain.Level
local CAST_SECONDS, STATIC_PROGRESS, HINT_HEIGHT = 2.5, 0.6, 18
local ICONS = "Interface\\Icons\\"

-- Each sample aura belongs to a group; its tags say which Which choices it
-- matches, and dispel names a dispel type, as the game would report them.
M.previewSamples = {
    enemy = { name = "Enemy Nameplate", caption = "Enemy, shown as your target", health = 72, reaction = "hostile", raid = 8, targeted = true,
        level = 62, classification = "elite", quest = true,
        cast = { text = "Shadow Bolt", icon = ICONS .. "Spell_Shadow_ShadowBolt", target = "Mode", targetClass = "PALADIN" },
        auras = {
            { icon = ICONS .. "Spell_Nature_Polymorph", group = "crowdControl", dispel = "Magic", duration = 8, elapsed = 3 },
            { icon = ICONS .. "Spell_Shadow_ShadowWordPain", group = "debuffs", tags = { mine = true }, dispel = "Magic", duration = 18, elapsed = 6 },
            { icon = ICONS .. "Spell_Shadow_CurseOfTounges", group = "debuffs", tags = { dispellable = true }, dispel = "Curse", count = 3, duration = 30, elapsed = 10 },
            { icon = ICONS .. "Spell_Holy_PowerWordShield", group = "buffs", tags = { dispellable = true, important = true }, dispel = "Magic", duration = 15, elapsed = 5 },
        } },
    friendly = { name = "Friendly Nameplate", caption = "Friendly player (Mage)", health = 90, reaction = "friendly", class = "MAGE", level = 60,
        cast = { text = "Flash Heal", icon = ICONS .. "Spell_Holy_FlashHeal", target = "Tank", targetClass = "WARRIOR" },
        auras = {
            { icon = ICONS .. "Spell_Frost_ChainsOfIce", group = "crowdControl", dispel = "Magic", duration = 6, elapsed = 2 },
            { icon = ICONS .. "Spell_Shadow_AbominationExplosion", group = "debuffs", tags = { dispellable = true }, dispel = "Disease", duration = 12, elapsed = 4 },
            { icon = ICONS .. "Spell_Nature_Rejuvenation", group = "buffs", tags = { mine = true }, count = 2, duration = 12, elapsed = 4 },
        } },
}

addon.PreviewStates:Register(M.id, {
    states = { { id = "static", label = "Static" }, { id = "animated", label = "Animated" } },
    animated = { animated = true }, previewAnimated = "animated",
    sample = function(_, phase) return phase end,
})

-- The kind the page is editing, else Enemy.
function M:PreviewKind()
    local page = self.page
    return page and page.nameplateEditing and page.nameplateEditing() or "enemy"
end

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
        if button == nil or button == "LeftButton" then M:JumpTo(hit.jumpKind or kind, target, group) end
    end)
    hit.jump = { kind = kind, target = target, group = group }
    return hit
end

-- Text click areas cover the written text, not the whole line: text inside
-- the bar is laid out as wide as the bar, and a click on the bar beside the
-- text should reach the bar.
local function FitText(hit, text)
    local width = math.max(8, math.min(text:GetWidth(), text:GetStringWidth() + 4))
    local justify = text:GetJustifyH()
    local point = justify == "LEFT" and "LEFT" or justify == "RIGHT" and "RIGHT" or "CENTER"
    hit:ClearAllPoints()
    hit:SetPoint(point, text, point, 0, 0)
    hit:SetSize(width, math.max(8, text:GetStringHeight() + 2))
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
            icon.jumpKind = plate.kind
            icon.icon:SetTexture(aura.icon)
            Kit.Write(icon.count, (style.auraCount and aura.count) and tostring(aura.count) or "")
            Kit.TintAuraRim(icon, self:AuraRimColor(style, aura.dispel))
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
    local class = sample.class and UnitColor.Class(sample.class)
    self:PaintHealthColor(plate, self:ColorFor(style, class, sample.reaction, nil))
    plate.sampleNameColor = class and { class.r, class.g, class.b } or self.reactionColors[sample.reaction]
    Kit.Write(plate.name, L[sample.name])
    Kit.Write(plate.healthText, HealthText(style.healthText, sample.health))
    if style.showRaidIcon and sample.raid then RaidIcon.ApplyIndex(plate.raidIcon, sample.raid) else plate.raidIcon:Hide() end
    self:PaintIndicator(plate, sample.quest, sample.classification, tostring(sample.level), Level.DifficultyColor(sample.level))
    self:PaintTarget(plate, style.targetStyle ~= "none" and sample.targeted == true)
    self:PaintSampleAuras(plate, style, sample)
    if not style.showCastBar or plate.nameOnly then self:StopCast(plate); return end
    plate.cast:SetMinMaxValues(0, 1); plate.cast:SetValue(progress)
    self:PaintCast(plate, style, false, false, L[sample.cast.text], sample.cast.icon)
    local targetClass = UnitColor.Class(sample.cast.targetClass)
    self:PaintCastTarget(plate, sample.cast.target, targetClass and { targetClass.r, targetClass.g, targetClass.b })
    Kit.Formatted(plate.castTimer, "%.1f", CAST_SECONDS * (1 - progress))
end

-- Room the sample needs above and below its health bar, and beside it.
local function Room(style)
    local top, bottom, side = (style.showName and style.nameFontSize + 6 or 4), style.castHeight + 8, 40
    if style.raidAnchor:find("^TOP") then top = top + style.raidSize + 2 end
    if style.showIndicator then
        if style.indicatorAnchor:find("^TOP") then top = top + style.indicatorSize + 2
        elseif style.indicatorAnchor == "LEFT" or style.indicatorAnchor == "RIGHT" then side = side + 3 * style.indicatorSize end
    end
    if style.showAuras then
        for _, group in ipairs(M.auraGroups) do
            local settings = style[group]
            if settings.show then
                local size = settings.size + style.auraSpacing
                if settings.anchor:find("^TOP") then top = top + size + math.max(0, settings.y)
                elseif settings.anchor:find("^BOTTOM") then bottom = bottom + size + math.max(0, -settings.y)
                else side = side + math.min(settings.max, 3) * size + math.abs(settings.x) end
            end
        end
    end
    if style.targetStyle == "arrows" or style.targetStyle == "borderArrows" then side = side + style.targetArrowSize + style.targetArrowGap end
    return top, bottom, side
end

function M:GetPreviewSize()
    local style = self.db[self:PreviewKind()]
    local top, bottom, side = Room(style)
    return math.max(320, style.width + 2 * side), top + style.healthHeight + 4 + bottom + 24 + HINT_HEIGHT
end

function M:RenderPreview(view)
    local phase = addon.PreviewStates:Sample(self.id)
    local progress = phase and (phase % CAST_SECONDS) / CAST_SECONDS or STATIC_PROGRESS
    local shownKind = self:PreviewKind()
    for _, kind in ipairs(self.kinds) do
        local style, plate, caption = self.db[kind], view.plates[kind], view.captions[kind]
        caption:ClearAllPoints()
        if kind ~= shownKind then
            plate:Hide(); caption:Hide()
        else
            local top = Room(style)
            caption:Show()
            if style.show then
                self:LayoutPlate(plate)
                local px = plate.px or 1
                local x = math.floor(-plate:GetWidth() / 2 / px + 0.5) * px
                plate:ClearAllPoints(); plate:SetPoint("TOPLEFT", view.frame, "TOP", x, -math.floor(top / px + 0.5) * px)
                plate:Show()
                self:PaintSample(plate, style, self.previewSamples[kind], progress)
                FitText(view.targets[kind].name, plate.name)
                FitText(view.targets[kind].healthText, plate.healthText)
                caption:SetPoint("BOTTOM", view.frame, "BOTTOM", 0, HINT_HEIGHT + 2)
                caption:SetText(L[self.previewSamples[kind].caption])
            else
                plate:Hide()
                caption:SetPoint("CENTER", view.frame, "CENTER", 0, 0)
                caption:SetText(L[self.kindLabels[kind] .. " plates use Blizzard's look"])
            end
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
            indicator = Clickable(plate.indicator, kind, "indicator"),
        }
        local caption = W.Label(frame, "", nil, 0, 0, 260, T.muted)
        caption:SetJustifyH("CENTER")
        view.captions[kind] = caption
    end
    view.hint = W.Label(frame, L["Click any part of the sample to jump to its settings."], nil, 0, 0, 360, T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2); view.hint:SetJustifyH("CENTER")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

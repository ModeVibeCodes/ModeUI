local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The settings preview: one sample plate, the kind chosen with Editing,
-- centered and built by the same code as the plates in the world, so it always
-- matches the current settings (layout, auras, target style, Name Only).
-- Static shows a cast part-way through; Animated loops it. Clicking a part of
-- the sample (health, name, health text, cast bar, an aura, the raid marker,
-- the combo points)
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
            Kit.TintAuraRim(icon, self:AuraRimColor(style, aura.dispel, group))
            Kit.GlowAura(icon, self:AuraGlowColor(style, aura.dispel, group), style.auraGlowStyle)
            Kit.Write(icon.timer, style.auraTimerText and tostring(math.max(0, aura.duration - aura.elapsed)) or "")
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
    -- On the Focus tab the sample is your focus instead of your target.
    local page = self.page
    local focus = page and page.selectedSection and page.selectedSection.title == L["Focus"] or false
    self:PaintTarget(plate, style.targetStyle ~= "none" and sample.targeted == true and not focus)
    self:PaintFocus(plate, focus, focus)
    self:PaintSampleCombo(plate, style)
    self:PaintSampleAuras(plate, style, sample)
    if not style.showCastBar or plate.nameOnly then self:StopCast(plate); return end
    plate.cast:SetMinMaxValues(0, 1); plate.cast:SetValue(progress)
    self:PaintCast(plate, style, false, false, L[sample.cast.text], sample.cast.icon)
    local targetClass = UnitColor.Class(sample.cast.targetClass)
    self:PaintCastTarget(plate, sample.cast.target, targetClass and { targetClass.r, targetClass.g, targetClass.b })
    Kit.Formatted(plate.castTimer, "%.1f", CAST_SECONDS * (1 - progress))
end

-- How far the sample reaches past its health bar on each side, measured from
-- the laid-out plate: rows above and below share one band (the tallest item
-- counts), and each side counts only what sits on it, so the whole sample can
-- be centered and the preview kept as short as it can be.
function M:PreviewBounds(plate, style, sample)
    local px, gap = plate.px or 1, 2 * plate.px
    local up, down = 0, 0
    local side = { LEFT = self:SideRoom(plate, "LEFT"), RIGHT = self:SideRoom(plate, "RIGHT") }
    local function Band(anchor, height)
        if anchor:find("^TOP") then up = math.max(up, height) elseif anchor:find("^BOTTOM") then down = math.max(down, height) end
    end
    if style.showRaidIcon then Band(style.raidAnchor, plate.markSize or style.raidSize) end
    if style.showIndicator then
        for _, part in ipairs(M.indicatorParts) do
            if style[M.indicatorShowKeys[part]] then Band(style[part .. "Anchor"], part == "level" and style.levelSize + 2 or style[part .. "Size"]) end
        end
    end
    if style.showAuras and not plate.nameOnly then
        for _, group in ipairs(M.auraGroups) do
            local settings, count = style[group], #self:SampleAuras(style, sample, group)
            if count > 0 then
                local width, height = self:AuraSize(plate, group)
                local anchor = settings.anchor
                if side[anchor] then
                    side[anchor] = side[anchor] + count * (width + style.auraSpacing * px) + math.abs(settings.x)
                elseif not settings.attach then
                    Band(anchor, height + math.abs(settings.y))
                end
            end
        end
    end
    -- Combo points: past everything else on a side, else in a band.
    local combo = self:SampleComboCount(style)
    if combo > 0 then
        local size = Kit.ResourcePointSize(style.comboSize, px)
        local width = combo * size + (combo - 1) * math.floor(style.comboSpacing / px + 0.5) * px
        if side[style.comboAnchor] then side[style.comboAnchor] = side[style.comboAnchor] + 3 * px + width + math.abs(style.comboX)
        else Band(style.comboAnchor, size + math.abs(style.comboY)) end
    end
    if style.targetStyle == "arrows" or style.targetStyle == "borderArrows" then
        for key in pairs(side) do side[key] = side[key] + style.targetArrowGap * px + style.targetArrowSize end
    end
    local top = plate.above + (up > 0 and up + gap or 0)
    local bottom = plate.below + (down > 0 and down + gap or 0)
    return top, bottom, side.LEFT, side.RIGHT
end

function M:GetPreviewSize(view)
    local kind = self:PreviewKind()
    local style, plate = self.db[kind], view and view.plates and view.plates[kind]
    if not plate or not style.show then return 320, 60 end
    -- Measures the sample as it was last drawn; laying it out again here would
    -- undo its painted colors.
    if not plate.px then self:LayoutPlate(plate) end
    local top, bottom, left, right = self:PreviewBounds(plate, style, self.previewSamples[kind])
    return math.max(320, plate:GetWidth() + left + right + 16), 4 + top + plate:GetHeight() + bottom + 6 + HINT_HEIGHT
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
            caption:Show()
            if style.show then
                self:LayoutPlate(plate)
                local px = plate.px or 1
                -- Center everything the sample shows, not just its health bar.
                local top, _, left, right = self:PreviewBounds(plate, style, self.previewSamples[kind])
                local x = math.floor((-plate:GetWidth() / 2 + (left - right) / 2) / px + 0.5) * px
                plate:ClearAllPoints(); plate:SetPoint("TOPLEFT", view.frame, "TOP", x, -math.floor((top + 4) / px + 0.5) * px)
                plate:Show()
                self:PaintSample(plate, style, self.previewSamples[kind], progress)
                FitText(view.targets[kind].name, plate.name)
                FitText(view.targets[kind].healthText, plate.healthText)
                -- What the sample shows, bottom left; the click hint sits bottom right.
                caption:SetPoint("BOTTOMLEFT", view.frame, "BOTTOMLEFT", 0, 2)
                caption:SetJustifyH("LEFT")
                caption:SetText(L[self.previewSamples[kind].caption])
            else
                plate:Hide()
                caption:SetPoint("CENTER", view.frame, "CENTER", 0, 0)
                caption:SetJustifyH("CENTER")
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
            combo = Clickable(plate.combo, kind, "combo"),
            quest = Clickable(plate.indicatorParts.quest, kind, "indicator", "quest", plate.textLayer),
            classification = Clickable(plate.indicatorParts.classification, kind, "indicator", "classification", plate.textLayer),
            level = Clickable(plate.indicatorParts.level, kind, "indicator", "level", plate.textLayer),
        }
        local caption = W.Label(frame, "", nil, 0, 0, 260, T.muted)
        caption:SetJustifyH("CENTER")
        view.captions[kind] = caption
    end
    view.hint = W.Label(frame, L["Click a part to open its settings"], nil, 0, 0, 200, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

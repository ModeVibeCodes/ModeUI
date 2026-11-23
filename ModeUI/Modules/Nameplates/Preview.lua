local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The settings preview's samples (the stage itself is PreviewStage.lua): sample
-- units, their auras, casts and states, painted on plates built by the same
-- code as the plates in the world, so a sample always matches the settings.
local Kit, L = addon.Kit, addon.L
local RaidIcon, UnitColor, Level = addon.Domain.RaidIcon, addon.Domain.UnitColor, addon.Domain.Level
M.PREVIEW_CAST_SECONDS, M.PREVIEW_STATIC_PROGRESS = 2.5, 0.6
local ICONS = "Interface\\Icons\\"
-- The game's cursor art (the glue screens load Interface\Cursor\Attack and Interact).
local CURSORS = "Interface\\Cursor\\"

-- Each sample aura belongs to a group; its tags say which Which choices it
-- matches, and dispel names a dispel type, as the game would report them.
M.previewSamples = {
    enemy = { name = "Scarlet Crusader", caption = "Enemy", health = 72, reaction = "hostile", raid = 8, targeted = true,
        level = 62, classification = "elite", quest = true, softTarget = CURSORS .. "Interact",
        cast = { text = "Holy Smite", icon = ICONS .. "Spell_Holy_HolySmite", target = "Mode", targetClass = "PALADIN" },
        auras = {
            { icon = ICONS .. "Spell_Nature_Polymorph", group = "crowdControl", dispel = "Magic", duration = 8, elapsed = 3 },
            { icon = ICONS .. "Spell_Shadow_ShadowWordPain", group = "debuffs", tags = { mine = true }, dispel = "Magic", duration = 18, elapsed = 6 },
            { icon = ICONS .. "Spell_Shadow_CurseOfTounges", group = "debuffs", tags = { mine = true, dispellable = true }, dispel = "Curse", count = 3, duration = 30, elapsed = 10 },
            { icon = ICONS .. "Spell_Holy_PowerWordShield", group = "buffs", tags = { dispellable = true, important = true }, dispel = "Magic", duration = 15, elapsed = 5 },
        } },
    friendly = { name = "Wildleaf", caption = "Friendly player (Mage)", health = 90, reaction = "friendly", class = "MAGE", level = 60, softTarget = CURSORS .. "Interact",
        cast = { text = "Flash Heal", icon = ICONS .. "Spell_Holy_FlashHeal", target = "Tank", targetClass = "WARRIOR" },
        auras = {
            { icon = ICONS .. "Spell_Frost_ChainsOfIce", group = "crowdControl", dispel = "Magic", duration = 6, elapsed = 2 },
            { icon = ICONS .. "Spell_Shadow_AbominationExplosion", group = "debuffs", tags = { dispellable = true }, dispel = "Disease", duration = 12, elapsed = 4 },
            { icon = ICONS .. "Spell_Nature_Rejuvenation", group = "buffs", tags = { mine = true }, count = 2, duration = 12, elapsed = 4 },
        } },
    -- A friendly NPC, for the friendly strip (players and NPCs both show names).
    friendlyNPC = { name = "Innkeeper Farley", caption = "Friendly NPC", health = 100, reaction = "friendly", level = 30, auras = {},
        cast = { text = "Hearthstone", icon = ICONS .. "INV_Misc_Rune_01" } },
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

-- The sample auras one group shows: "some" as the game's filters would pick
-- them from the sample; "full" fills the group to Most Shown (so its full
-- reach shows); "none" none.
function M:SampleAuras(style, sample, group, mode)
    local shown, settings = {}, style[group]
    if mode == "none" or not style.showAuras or not settings.show then return shown end
    local pool = {}
    for _, aura in ipairs(sample.auras) do
        local match = aura.group == group and (group == "crowdControl" or settings.filter == "all" or (aura.tags and aura.tags[settings.filter]))
        if match then pool[#pool + 1] = aura end
    end
    if mode == "full" then
        for _, aura in ipairs(sample.auras) do if aura.group == group then pool[#pool + 1] = aura end end
        for i = 1, (#pool > 0 and settings.max or 0) do shown[i] = pool[(i - 1) % #pool + 1] end
        return shown
    end
    for _, aura in ipairs(pool) do if #shown < settings.max then shown[#shown + 1] = aura end end
    return shown
end

function M:PaintSampleAuras(plate, style, sample, mode)
    for _, group in ipairs(self.auraGroups) do
        local auras = self:GroupShown(plate, group) and self:SampleAuras(style, sample, group, mode) or {}
        for index, aura in ipairs(auras) do
            local icon = self:AuraIcon(plate, group, index)
            if plate.clickable and not icon.jump then self.Clickable(icon, plate.kind, "auras", group) end
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

-- An interrupted cast as the hold shows it (CastBar.lua HoldCast), without
-- the timer that ends it.
local function PaintInterrupted(self, plate, style)
    local bar = plate.cast
    if bar.SetReverseFill then bar:SetReverseFill(false) end
    bar:SetMinMaxValues(0, 1); bar:SetValue(1)
    Kit.Tint(bar:GetStatusBarTexture(), style.castInterruptedColor, 1)
    plate.comet:SetShown(false)
    Kit.Write(plate.castText, style.castShowText and (INTERRUPTED or "Interrupted") or "")
    Kit.Write(plate.castTimer, ""); Kit.Write(plate.castTarget, "")
    self:SetCastShown(plate, true)
end

-- Paints a sample in a state: { cast = "none" | "cast" | "locked" |
-- "interrupted", targeted, focus, auras = "none" | "some" | "full" }.
function M:PaintSample(plate, style, sample, progress, state)
    state = state or {}
    plate.health:SetMinMaxValues(0, 100); plate.health:SetValue(sample.health)
    local class = sample.class and UnitColor.Class(sample.class)
    self:PaintHealthColor(plate, self:ColorFor(style, class, sample.reaction, nil))
    plate.sampleNameColor = class and { class.r, class.g, class.b } or self.reactionColors[sample.reaction]
    plate.nameValue = L[sample.name]
    Kit.Write(plate.healthText, HealthText(style.healthText, sample.health))
    self:PaintHealthText(plate, sample.health / 100)
    if style.showRaidIcon and sample.raid then RaidIcon.ApplyIndex(plate.raidIcon, sample.raid) else plate.raidIcon:Hide() end
    if style.showSoftTarget and sample.softTarget and state.soft ~= false then plate.softTarget:SetTexture(sample.softTarget); plate.softTarget:Show()
    else plate.softTarget:Hide() end
    self:PaintIndicator(plate, sample.quest, sample.classification, tostring(sample.level), Level.DifficultyColor(sample.level), true)
    -- The Target chip applies to samples that can be your target (the enemy's).
    local targeted = state.targeted
    if targeted == nil or sample.targeted == nil then targeted = sample.targeted == true end
    self:PaintTarget(plate, style.targetStyle ~= "none" and targeted and not state.focus)
    self:PaintFocus(plate, state.focus == true, state.focus == true)
    self:PaintSampleCombo(plate, style, targeted)
    local cast = state.cast or "cast"
    if not style.showCastBar or plate.nameOnly or cast == "none" or not sample.cast then self:StopCast(plate)
    elseif cast == "interrupted" then PaintInterrupted(self, plate, style)
    else
        plate.cast:SetMinMaxValues(0, 1); plate.cast:SetValue(progress)
        self:PaintCast(plate, style, false, cast == "locked", L[sample.cast.text], sample.cast.icon)
        local targetClass = sample.cast.targetClass and UnitColor.Class(sample.cast.targetClass)
        self:PaintCastTarget(plate, sample.cast.target, targetClass and { targetClass.r, targetClass.g, targetClass.b })
        Kit.Formatted(plate.castTimer, "%.1f", M.PREVIEW_CAST_SECONDS * (1 - progress))
    end
    self:PlaceStacks(plate)
    self:PaintSampleAuras(plate, style, sample, state.auras or "some")
end

-- How far the sample can reach past its health box on each side, from the
-- layout and every aura row at Most Shown, so the stage keeps its place while
-- states change: left, right, up, down.
function M:PreviewReach(plate)
    local style, px = self:Style(plate), plate.px or 1
    local gap = 2 * px
    local reach = { LEFT = 0, RIGHT = 0 }
    for side in pairs(reach) do
        local size = plate.rowSize and plate.rowSize[side]
        if size then reach[side] = reach[side] + size[1] + 3 * px end
        for _, group in ipairs(self.auraGroups) do
            if self:GroupShown(plate, group) and self:GroupKey(style, group) == side then
                local width = self:AuraSize(plate, group)
                reach[side] = reach[side] + gap + style[group].max * (width + style.auraSpacing * px)
            end
        end
        if style.targetStyle == "arrows" or style.targetStyle == "borderArrows" then
            reach[side] = reach[side] + style.targetArrowGap * px + style.targetArrowSize
        end
    end
    local up = (plate.above or 0) + self:TopStackRoom(plate)
    if style.showSoftTarget then up = math.max(up, plate.softTargetTop or 0) end
    local down = (plate.below or 0)
    for _, key in ipairs({ "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
        local size, extra = plate.rowSize and plate.rowSize[key], 0
        if size then extra = size[2] + gap end
        for _, group in ipairs(self.auraGroups) do
            if self:GroupShown(plate, group) and self:GroupKey(style, group) == key then
                local _, height = self:AuraSize(plate, group)
                extra = extra + height + gap
            end
        end
        down = math.max(down, (plate.below or 0) + extra)
    end
    return reach.LEFT, reach.RIGHT, up + gap, down + gap
end

-- A sample part that jumps to its settings when clicked and lights up under
-- the mouse. Frames take the click themselves; text and textures get a frame
-- laid over them.
function M.Clickable(region, kind, target, group, host)
    local W, T = addon.ConfigWidgets, addon.InterfaceTheme
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

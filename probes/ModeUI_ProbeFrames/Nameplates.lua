local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- Nameplates probe (Phase 5): plates in the Mode design language: the
-- `frameThin` edge, Mode BG fill in the reaction color (class Gradient for
-- players), a 12px cast bar in Mode Cast with the Comet spark and its icon,
-- Ivory outer line for the target and Rosewood for focus, debuffs in
-- `frameThin` and enemy buffs with a dispel `line` rim, names in Gradient
-- SemiBold and Bold health text. Samples animate their casts; the last plate
-- follows your target live (secret values only reach widgets that accept them).
local S, T, D = Kit.S, Kit.T, Kit.D
local Q = D.Query

local ICONS = {
    fireball = [[Interface\Icons\Spell_Fire_FlameBolt]], heal = [[Interface\Icons\Spell_Holy_Heal]],
    drain = [[Interface\Icons\Spell_Shadow_LifeDrain02]], fear = [[Interface\Icons\Spell_Shadow_Possession]],
    corruption = [[Interface\Icons\Spell_Shadow_AbominationExplosion]], pain = [[Interface\Icons\Spell_Shadow_ShadowWordPain]],
    shield = [[Interface\Icons\Spell_Holy_PowerWordShield]], enrage = [[Interface\Icons\Ability_Druid_ChallangingRoar]],
}
local SAMPLES = {
    { name = "Defias Pillager", reaction = "hostile", hp = 76, level = "18", marker = 8, target = true,
        cast = { text = "Fireball", icon = "fireball", kind = "casting", time = 2.5 }, debuffs = { "corruption", "pain" },
        note = "Target: Ivory outer line, skull, your debuffs" },
    { name = "Murloc Oracle", reaction = "hostile", hp = 48, level = "16", focus = true,
        cast = { text = "Drain Life", icon = "drain", kind = "channeling", time = 4 }, buffs = { { "shield", "Magic" } },
        note = "Focus: Rosewood line; channel drains; Magic buff rim" },
    { name = "Riverpaw Mystic", reaction = "neutral", hp = 92, level = "15",
        cast = { text = "Healing Wave", icon = "heal", kind = "shielded", time = 3 },
        note = "Neutral; cast that can't be interrupted (grey)" },
    { name = "Gnoll Brute", reaction = "hostile", hp = 21, level = "17",
        cast = { text = "Interrupted", icon = "fear", kind = "interrupted" }, note = "Interrupted: red, held" },
    { name = "Tapped Wolf", reaction = "tapped", hp = 64, level = "12", note = "Tapped by someone else" },
    { name = "Aerin", class = "PALADIN", friendly = true, hp = 100, level = "60", note = "Friendly player: 120 x 8, class Gradient" },
}

local function NewPlate(parent)
    local p = CreateFrame("Frame", nil, parent)
    p.health = S.Bar(p, { role = "nameplate" })
    p.health:SetPoint("TOPLEFT"); p.health:SetPoint("TOPRIGHT")
    p.edge = S.Edge(p.health, "frameThin")
    p.over = CreateFrame("Frame", nil, p)
    p.over:SetAllPoints(); p.over:SetFrameLevel(p.health:GetFrameLevel() + 6)
    p.name = Kit.Text(p.over, 10, "semibold")
    p.name:SetPoint("BOTTOM", p.health, "TOP", 0, 4)
    p.level = Kit.Text(p.over, 9, "medium", T.graphite.muted)
    p.level:SetPoint("LEFT", p.name, "RIGHT", 3, 0)
    p.value = Kit.Text(p.over, 9, "bold")
    p.value:SetPoint("RIGHT", p.health, "RIGHT", -3, 0)
    p.marker = p.over:CreateTexture(nil, "OVERLAY")
    p.marker:SetSize(16, 16)
    p.marker:SetPoint("RIGHT", p.health, "LEFT", -6, 0)
    -- Cast bar, 2px under the health bar, its icon on the left.
    p.castHolder = CreateFrame("Frame", nil, p)
    p.cast = S.Bar(p.castHolder, { texture = "Cast", spark = true })
    p.cast:SetAllPoints()
    p.castEdge = S.Edge(p.castHolder, "frameThin")
    p.castIcon = Kit.Icon(p, 16, "frameThin")
    p.castText = Kit.Text(p.over, 9, "bold", T.textBright)
    p.castText:SetPoint("LEFT", p.castHolder, "LEFT", 3, 0)
    p.castTime = Kit.Text(p.over, 9, "bold", T.textBright)
    p.castTime:SetPoint("RIGHT", p.castHolder, "RIGHT", -3, 0)
    p.auras = {}
    for i = 1, 4 do p.auras[i] = Kit.Icon(p, 20, "frameThin") end
    p.note = Kit.Text(parent, 10, "medium", T.graphite.muted)
    p.note:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -10)
    return p
end

local function Size(p, friendly)
    local w, h = friendly and 120 or 140, friendly and 8 or 12
    p:SetSize(w, h + 2 + 12)
    p.health:SetHeight(h)
    p.castHolder:ClearAllPoints()
    p.castHolder:SetPoint("TOPLEFT", p.health, "BOTTOMLEFT", 18, -4)
    p.castHolder:SetPoint("TOPRIGHT", p.health, "BOTTOMRIGHT", 0, -4)
    p.castHolder:SetHeight(12)
    p.castIcon:ClearAllPoints()
    p.castIcon:SetPoint("RIGHT", p.castHolder, "LEFT", -2, 0)
end

-- Auras above the name: debuffs (`frameThin`), then buffs with a dispel rim.
local function Auras(p, debuffs, buffs)
    local n = 0
    for _, key in ipairs(debuffs or {}) do
        n = n + 1
        local icon = p.auras[n]
        icon.icon:SetTexture(ICONS[key]); icon.edge:SetTint(nil); icon:Show()
    end
    for _, buff in ipairs(buffs or {}) do
        n = n + 1
        local icon = p.auras[n]
        icon.icon:SetTexture(ICONS[buff[1]]); icon.edge:SetTint(T.dispel[buff[2]]); icon:Show()
    end
    for i = n + 1, #p.auras do p.auras[i]:Hide() end
    local width = n * 20 + math.max(0, n - 1) * 4
    for i = 1, n do
        local icon = p.auras[i]
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT", p.health, "TOP", -width / 2 + (i - 1) * 24, 20)
    end
end

local CAST_COLORS = { casting = T.cast.casting, channeling = T.cast.channeling, shielded = T.cast.shielded, interrupted = T.cast.interrupted }

local function ApplySample(p, s)
    Size(p, s.friendly)
    local color = s.class and Kit.ClassColor(s.class) or T.reaction[s.reaction]
    p.health:SetTextureKey(s.friendly and "Gradient" or "BG")
    p.health:SetFill(color)
    p.health:SetMinMaxValues(0, 100); p.health:SetValue(s.hp)
    S.SetName(p.name, s.name, color, "gradient")
    p.level:SetText(s.level or "")
    local c = Kit.HealthTextColor(s.hp / 100)
    p.value:SetText(s.friendly and "" or (s.hp .. "%")); p.value:SetTextColor(c[1], c[2], c[3])
    p.edge:SetHighlight(s.target and "accent" or s.focus and "specialty" or nil)
    if s.marker then D.RaidIcon.ApplyIndex(p.marker, s.marker) else p.marker:Hide() end
    Auras(p, s.debuffs, s.buffs)
    local cast = s.cast
    p.castHolder:SetShown(cast ~= nil); p.castIcon:SetShown(cast ~= nil)
    p.castText:SetShown(cast ~= nil); p.castTime:SetShown(cast ~= nil)
    if cast then
        p.cast:SetFill(CAST_COLORS[cast.kind])
        p.castIcon.icon:SetTexture(ICONS[cast.icon])
        p.castText:SetText(cast.text)
        p.cast:SetSpark(cast.kind ~= "interrupted")
        p.cast:SetMinMaxValues(0, 1); p.cast:SetValue(cast.kind == "interrupted" and 1 or 0)
    end
    p.sample = s
end

-- Moves a sample cast on: casts fill, channels drain, and each loops.
local function Animate(p, now)
    local cast = p.sample and p.sample.cast
    if not cast or not cast.time then return end
    local t = (now % (cast.time + 0.6)) / cast.time
    if t > 1 then t = 1 end
    local value = cast.kind == "channeling" and (1 - t) or t
    p.cast:SetValue(value)
    p.castTime:SetFormattedText("%.1f", math.max(0, cast.time * (1 - t)))
end

-- The live plate for your target, through Domain (possibly secret values).
local function ApplyLive(p, unit)
    local friendlyPlayer = Q.Truthy(UnitIsPlayer, unit) and not Q.Truthy(UnitCanAttack, "player", unit)
    Size(p, friendlyPlayer)
    local c = D.UnitColor.PlayerClass(unit)
    local reaction = D.UnitColor.Reaction(unit)
    local color = (friendlyPlayer and c) and { c.r, c.g, c.b } or T.reaction[reaction or "neutral"]
    local key = friendlyPlayer and "Gradient" or "BG"
    if p.health.textureKey ~= key then p.health:SetTextureKey(key) end
    p.health:SetFill(color)
    local okMax, max, okValue, value = D.Health.Read(unit)
    p.health:SetMinMaxValues(0, okMax and max or 1); p.health:SetValue(okValue and value or 0)
    S.SetName(p.name, D.Name.Get(unit), color, "gradient")
    p.level:SetText(D.Level.Text(unit))
    local curve = CurveConstants and CurveConstants.ScaleTo100
    local ok, percent = false, nil
    if curve then ok, percent = D.Health.Percent(unit, curve) end
    if not (ok and pcall(p.value.SetFormattedText, p.value, "%.0f%%", percent)) then p.value:SetText("") end
    if not S.PaintHealthText(p.value, unit) then p.value:SetTextColor(T.text[1], T.text[2], T.text[3]) end
    p.edge:SetHighlight("accent")
    D.RaidIcon.Apply(p.marker, unit)
    for _, icon in ipairs(p.auras) do icon:Hide() end
    local auras = D.Auras.Collect(unit, { "HARMFUL|PLAYER" }, #p.auras)
    for i, aura in ipairs(auras) do
        local icon = p.auras[i]
        D.Auras.Apply(icon, unit, aura, true, true)
        icon.edge:SetTint(nil); icon:Show()
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT", p.health, "TOP", -(#auras * 24 - 4) / 2 + (i - 1) * 24, 20)
    end
    local info = D.Cast.Read(unit)
    p.castHolder:SetShown(info ~= nil); p.castIcon:SetShown(info ~= nil)
    p.castText:SetShown(info ~= nil); p.castTime:SetShown(info ~= nil)
    if info then
        -- A channel drains: Slate fills from the right over the channel color.
        local base = info.channel and T.cast.channeling or T.cast.casting
        p.cast.reverse = info.channel == true
        p.cast:SetReverseFill(p.cast.reverse)
        if info.channel then p.cast:SetFill(T.slate); S.Paint(p.cast.bg, base)
        else
            S.Paint(p.cast.bg, T.slate)
            p.cast:SetFillFromBoolean(info.notInterruptible, T.cast.shielded, base)
        end
        p.cast:LayoutStyle()
        pcall(p.cast.SetMinMaxValues, p.cast, info.startMs, info.endMs)
        p.cast:SetValue(D.Cast.Now())
        if not pcall(p.castIcon.icon.SetTexture, p.castIcon.icon, info.texture) then p.castIcon.icon:SetTexture(nil) end
        if not pcall(p.castText.SetText, p.castText, info.text) then p.castText:SetText("") end
        local okLeft, left = D.Cast.Remaining(unit, info.channel)
        if not (okLeft and pcall(p.castTime.SetFormattedText, p.castTime, "%.1f", left)) then p.castTime:SetText("") end
    end
end

function ns.BuildNameplates(body)
    local backdrop = CreateFrame("Frame", nil, body)
    backdrop:SetPoint("TOPLEFT", 0, 0); backdrop:SetPoint("BOTTOMRIGHT", 0, 0)
    Kit.Fill(backdrop, "Matte", T.mono.track, "BACKGROUND", -6)
    local plates = {}
    for i, s in ipairs(SAMPLES) do
        local p = NewPlate(backdrop)
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        p:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60 + col * 250, -70 - row * 150)
        ApplySample(p, s)
        p.note:SetText(s.note)
        plates[i] = p
    end
    local live = NewPlate(backdrop)
    live:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -380)
    local liveTitle = Kit.Heading(backdrop, "Your target (live)", 16, -330)
    live.note:SetText("Target something: name, health, debuffs you cast, marker and cast bar follow it.")
    local empty = Kit.Text(backdrop, 11, "medium", T.graphite.muted)
    empty:SetPoint("TOPLEFT", liveTitle, "BOTTOMLEFT", 0, -26)
    empty:SetText("No target.")
    local clock = 0
    Kit.Every(backdrop, 0.03, function(elapsed)
        clock = clock + elapsed
        for _, p in ipairs(plates) do Animate(p, clock) end
    end)
    Kit.Every(backdrop, 0.1, function()
        local has = Q.Truthy(UnitExists, "target")
        live:SetShown(has); live.note:SetShown(has); empty:SetShown(not has)
        if has then ApplyLive(live, "target") end
    end)
end

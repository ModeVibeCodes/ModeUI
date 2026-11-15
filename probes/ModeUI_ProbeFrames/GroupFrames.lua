local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- Group Frames probe (Phase 5): party and raid frames in the Mode design
-- language (docs/DESIGN_LANGUAGE.md, "Sizes", "Borders", "Bars"): the `group`
-- edge with frames exactly 1px apart, Combined shields, 3px power, Gradient
-- names in SemiBold, Bold health text colored by health, the dispel Gradient
-- from the top edge, the rim swapped to a flat color for target and aggro, and
-- auras flush in the corner. Samples show every state; Live reads your group
-- through ModeUI's guarded readers (values the game keeps secret only reach
-- widgets that accept them).
local S, T, D = Kit.S, Kit.T, Kit.D
local Q = D.Query

local LAYOUTS = {
    { id = "party", label = "Party", w = 150, h = 34, count = 5, perLine = 5, down = true, aura = 18, value = "right" },
    { id = "healer", label = "Healer", w = 104, h = 54, count = 5, perLine = 5, aura = 18, value = "under" },
    { id = "raid", label = "Raid", w = 74, h = 34, count = 20, perLine = 5, down = true, aura = 14 },
    { id = "raidhealer", label = "Raid Healer", w = 92, h = 48, count = 20, perLine = 5, down = true, aura = 14, value = "under" },
    { id = "vertical", label = "Vertical", w = 62, h = 66, count = 5, perLine = 5, aura = 14, value = "under", vertical = true },
}
local ICONS = {
    Magic = [[Interface\Icons\Spell_Frost_FrostNova]], Curse = [[Interface\Icons\Spell_Shadow_CurseOfTounges]],
    Poison = [[Interface\Icons\Spell_Nature_CorrosiveBreath]], Disease = [[Interface\Icons\Spell_Shadow_CallofBone]],
    Renew = [[Interface\Icons\Spell_Holy_Renew]],
}
-- Five party samples, one state each (slot 1 is you, live).
local PARTY = {
    { live = "player", note = "You (live): your health, power, shield and role" },
    { name = "Brannoc", class = "WARRIOR", role = "TANK", hp = 88, power = "RAGE", pw = 40, aggro = true, leader = true,
        note = "Aggro: the rim turns hostile red; leader crown" },
    { name = "Isolde", class = "PRIEST", role = "HEALER", hp = 64, power = "MANA", pw = 72, shield = 22, dispel = "Magic",
        auras = { "Magic", "Renew" }, note = "Magic: dispel Gradient from the top; shield on health" },
    { name = "Kestrel", class = "HUNTER", role = "DAMAGER", hp = 27, power = "MANA", pw = 55, target = true,
        note = "Your target: Ivory rim; low health text in Rosewood" },
    { name = "Vayle", class = "MAGE", role = "DAMAGER", hp = 100, power = "MANA", pw = 90, shield = 18, far = true,
        note = "Out of range: 55% alpha; overshield at full health" },
}
-- Twenty raid samples cycling classes, with a few states mixed in.
local RAID, NAMES = {}, { "Aldric", "Brisa", "Corvin", "Delmy", "Elowen", "Faren", "Gisla", "Harrow", "Iona", "Jorin",
    "Kaela", "Lune", "Maddoc", "Nerys", "Orin", "Pell", "Quill", "Rhea", "Soren", "Tamsin" }
for i = 1, 20 do
    local class = D.UnitColor.classes[(i - 1) % #D.UnitColor.classes + 1]
    RAID[i] = { name = NAMES[i], class = class, role = i <= 2 and "TANK" or (i % 5 == 0) and "HEALER" or "DAMAGER",
        hp = 100 - ((i * 37) % 70), power = (class == "WARRIOR") and "RAGE" or (class == "ROGUE") and "ENERGY" or "MANA", pw = 60 }
end
RAID[1].aggro = true; RAID[4].shield = 30; RAID[7].dead = true; RAID[9].dispel = "Curse"; RAID[9].auras = { "Curse" }
RAID[11].target = true; RAID[13].far = true; RAID[16].dispel = "Poison"; RAID[16].auras = { "Poison" }
RAID[18].dispel = "Disease"; RAID[18].auras = { "Disease" }

local function NewMember(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.back = Kit.Fill(f, "Solid", T.mono.void, "BACKGROUND", -8)
    f.edge = S.Edge(f, "group")
    f.health = S.Bar(f, { role = "health" })
    f.power = S.Bar(f, { role = "power" })
    f.shield = S.Shield(f.health)
    f.over = CreateFrame("Frame", nil, f)
    f.over:SetAllPoints()
    f.over:SetFrameLevel(f.health:GetFrameLevel() + 4)
    f.dispel = f.over:CreateTexture(nil, "ARTWORK")
    S.ApplyAsset(f.dispel, "Solid")
    f.name = Kit.Text(f.over, 12, "semibold")
    f.name:SetWordWrap(false)
    f.value = Kit.Text(f.over, 11, "bold")
    f.role = f.over:CreateTexture(nil, "OVERLAY")
    f.leader = f.over:CreateTexture(nil, "OVERLAY")
    f.auras = {}
    for i = 1, 2 do f.auras[i] = Kit.Icon(f.over, 18) end
    f.note = Kit.Text(parent, 10, "medium", T.graphite.muted)
    return f
end

-- Sizes and places one member's parts for a layout.
local function LayoutMember(f, L, px)
    f:SetSize(L.w, L.h + 4)
    f.health:ClearAllPoints()
    f.health:SetPoint("TOPLEFT"); f.health:SetPoint("TOPRIGHT")
    f.health:SetHeight(L.h)
    f.health:SetOrientation(L.vertical and "VERTICAL" or "HORIZONTAL")
    f.shield:SetShown(not L.vertical)
    f.power:ClearAllPoints()
    f.power:SetPoint("BOTTOMLEFT"); f.power:SetPoint("BOTTOMRIGHT")
    f.power:SetHeight(3)
    f.health:LayoutStyle()
    f.dispel:ClearAllPoints()
    f.dispel:SetPoint("TOPLEFT", f.health, "TOPLEFT"); f.dispel:SetPoint("TOPRIGHT", f.health, "TOPRIGHT")
    f.dispel:SetHeight(L.h * 0.72)
    local small = L.w < 90
    S.Font(f.name, small and 11 or 12, "semibold")
    f.role:SetSize(12, 12)
    f.role:ClearAllPoints(); f.name:ClearAllPoints(); f.value:ClearAllPoints()
    if L.value == "under" then
        f.name:SetPoint("TOP", f.health, "TOP", 0, -6)
        f.name:SetWidth(L.w - 8)
        f.role:SetPoint("TOPLEFT", f.health, "TOPLEFT", 3, -3)
        f.value:SetPoint("TOP", f.name, "BOTTOM", 0, -3)
    else
        f.role:SetPoint("LEFT", f.health, "LEFT", 4, 0)
        f.name:SetPoint("LEFT", f.role, "RIGHT", 3, 0)
        f.name:SetWidth(L.w - (L.value == "right" and 62 or 22))
        f.name:SetJustifyH("LEFT")
        f.value:SetPoint("RIGHT", f.health, "RIGHT", -6, 0)
    end
    f.value:SetShown(L.value ~= nil)
    f.leader:SetSize(12, 12)
    f.leader:ClearAllPoints(); f.leader:SetPoint("CENTER", f.health, "TOPLEFT", 10, 0)
    -- Flush in the bottom right corner of the health part, 1px black on the inner sides.
    for i, icon in ipairs(f.auras) do
        local w = L.aura
        icon:SetSize(w, S.IconHeight(w))
        S.CropIcon(icon.icon, w, S.IconHeight(w))
        icon.back:ClearAllPoints()
        icon.back:SetPoint("TOPLEFT", -px, px); icon.back:SetPoint("BOTTOMRIGHT")
        icon:ClearAllPoints()
        if i == 1 then icon:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT")
        else icon:SetPoint("RIGHT", f.auras[i - 1], "LEFT", -px, 0) end
    end
end

local function Rim(f, color) f.edge:SetTint(color) end
local function Dispel(f, kind)
    local c = kind and T.dispel[kind]
    f.dispel:SetShown(c ~= nil)
    if c and f.dispel.SetGradient and CreateColor then
        f.dispel:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], 0.56))
    end
end
local function Fill(f, color, classFill)
    local key = classFill and "Gradient" or "Matte"
    if f.health.textureKey ~= key then f.health:SetTextureKey(key) end
    f.health:SetFill(classFill and color or T.darkFill)
end

-- A sample: plain numbers, so everything can be shown at once.
local function ApplySample(f, s, classFill)
    local color = Kit.ClassColor(s.class)
    Fill(f, color, classFill)
    local hp = s.dead and 0 or s.hp
    f.health:SetMinMaxValues(0, 100); f.health:SetValue(hp)
    local shield = s.shield or 0
    f.shield:Update(nil, { max = 100, shield = math.min(shield, 100 - hp), total = shield })
    f.shield.full:SetAlpha(hp >= 100 and shield > 0 and 1 or 0)
    f.power:SetFill(D.Power.Color(s.power)); f.power:SetMinMaxValues(0, 100); f.power:SetValue(s.dead and 0 or s.pw)
    S.SetName(f.name, s.name, color, "gradient")
    if s.dead then
        local c = T.graphite.muted
        f.value:SetText("Dead"); f.value:SetTextColor(c[1], c[2], c[3])
    else
        local c = Kit.HealthTextColor(hp / 100)
        f.value:SetText(hp .. "%"); f.value:SetTextColor(c[1], c[2], c[3])
    end
    f.role:SetAtlas(D.Group.ROLE_ATLAS[s.role]); f.role:Show()
    f.leader:SetShown(s.leader == true)
    if s.leader then f.leader:SetAtlas(D.Group.LEADER_ATLAS) end
    Rim(f, s.target and T.ivory or s.aggro and T.reaction.hostile or nil)
    Dispel(f, s.dispel)
    for i, icon in ipairs(f.auras) do
        local key = s.auras and s.auras[i]
        icon:SetShown(key ~= nil)
        if key then icon.icon:SetTexture(ICONS[key]); icon.count:SetText("") end
    end
    f:SetAlpha(s.far and 0.55 or 1)
end

-- A live unit: every value through Domain, possibly secret.
local calculator
local function ApplyLive(f, unit, classFill)
    local c = D.UnitColor.PlayerClass(unit)
    local color = c and { c.r, c.g, c.b } or T.reaction.friendly
    Fill(f, color, classFill)
    local okMax, max, okValue, value = D.Health.Read(unit)
    f.health:SetMinMaxValues(0, okMax and max or 1); f.health:SetValue(okValue and value or 0)
    calculator = calculator or D.Group.NewCalculator()
    f.shield:Update(unit, D.Group.Prediction(unit, calculator))
    local _, token, okPowerMax, powerMax, okPower, power = D.Power.Read(unit)
    f.power:SetFill(D.Power.Color(token))
    f.power:SetMinMaxValues(0, okPowerMax and powerMax or 1); f.power:SetValue(okPower and power or 0)
    S.SetName(f.name, D.Name.Get(unit), color, "gradient")
    local state = D.Health.State(unit)
    if state then
        local m = T.graphite.muted
        f.value:SetText(state); f.value:SetTextColor(m[1], m[2], m[3])
    else
        local curve = CurveConstants and CurveConstants.ScaleTo100
        local ok, percent = false, nil
        if curve then ok, percent = D.Health.Percent(unit, curve) end
        if not (ok and pcall(f.value.SetFormattedText, f.value, "%.0f%%", percent)) then f.value:SetText("") end
        if not S.PaintHealthText(f.value, unit) then f.value:SetTextColor(T.text[1], T.text[2], T.text[3]) end
    end
    local role = D.Group.Role(unit)
    f.role:SetShown(role ~= nil)
    if role then f.role:SetAtlas(D.Group.ROLE_ATLAS[role]) end
    local leader = D.Group.LeaderAtlas(unit)
    f.leader:SetShown(leader ~= nil)
    if leader then f.leader:SetAtlas(leader) end
    local threat = D.Threat.Status(unit)
    Rim(f, Q.Truthy(UnitIsUnit, unit, "target") and T.ivory or (threat and threat >= 2) and T.reaction.hostile or nil)
    local auras, kind = D.Auras.Collect(unit, { "HARMFUL|RAID" }, #f.auras), nil
    for i, icon in ipairs(f.auras) do
        local aura = auras[i]
        icon:SetShown(aura ~= nil)
        if aura then D.Auras.Apply(icon, unit, aura, false, true); kind = kind or icon.dispelType end
    end
    Dispel(f, kind)
    local okRange, inRange = false, nil
    if unit ~= "player" then okRange, inRange = D.Group.InRange(unit) end
    if okRange and f.SetAlphaFromBoolean then f:SetAlphaFromBoolean(inRange, 1, 0.55) else f:SetAlpha(1) end
end

-- The unit for a slot in Live mode, or nil when there is nobody there.
local function LiveUnit(index, raid)
    local unit
    if raid and Q.Truthy(IsInRaid) then unit = "raid" .. index
    elseif index == 1 then unit = "player"
    elseif index <= 5 then unit = "party" .. (index - 1) end
    if unit and Q.Truthy(UnitExists, unit) then return unit end
end

function ns.BuildGroupFrames(body)
    local state = { layout = "party", fill = "dark", source = "samples" }
    local members = {}
    local stage = CreateFrame("Frame", nil, body)
    stage:SetPoint("TOPLEFT", 0, -64); stage:SetPoint("BOTTOMRIGHT")
    local legend = Kit.Text(body, 10, "medium", T.graphite.muted)
    legend:SetPoint("BOTTOMLEFT", 0, 0)
    legend:SetJustifyH("LEFT")
    local function Current() for _, L in ipairs(LAYOUTS) do if L.id == state.layout then return L end end end
    local function Refresh()
        local L, px = Current(), S.Pixel(stage)
        local step = 3 * px -- 1px between the rims: each frame's 1px rim plus one pixel
        for i = 1, 20 do
            local f = members[i]
            if i > L.count then
                if f then f:Hide(); f.note:Hide() end
            else
                f = f or NewMember(stage)
                members[i] = f
                LayoutMember(f, L, px)
                local line, place = math.floor((i - 1) / L.perLine), (i - 1) % L.perLine
                local x, y
                if L.down then x, y = line * (L.w + step), -place * (L.h + 4 + step)
                else x, y = place * (L.w + step), -line * (L.h + 4 + step) end
                f:ClearAllPoints(); f:SetPoint("TOPLEFT", stage, "TOPLEFT", x + 4, y - 4)
                local sample = (L.count > 5 and RAID or PARTY)[i]
                f.sample = sample
                f.unit = state.source == "live" and LiveUnit(i, L.count > 5) or (state.source ~= "live" and sample.live) or nil
                f:SetShown(f.unit ~= nil or state.source ~= "live")
                if f.unit then ApplyLive(f, f.unit, state.fill == "class")
                elseif state.source ~= "live" then ApplySample(f, sample, state.fill == "class") end
                local showNote = L.id == "party" and state.source ~= "live"
                f.note:SetShown(showNote)
                if showNote then
                    f.note:ClearAllPoints(); f.note:SetPoint("LEFT", f, "RIGHT", 14, 0); f.note:SetText(sample.note)
                end
            end
        end
        legend:SetText(state.source == "live" and "Live: you and your party (raid1-20 in a raid). Frames are previews; clicks do nothing."
            or L.id == "party" and "Party 150 x 34 + 3 power, 1px apart." or
            (L.label .. " " .. L.w .. " x " .. L.h .. " + 3 power. Samples: aggro, shield, dead, Curse, target, out of range, Poison, Disease."))
    end
    local layouts = {}
    for _, L in ipairs(LAYOUTS) do layouts[#layouts + 1] = { id = L.id, label = L.label } end
    local a = Kit.Choice(body, layouts, function() return state.layout end, function(v) state.layout = v; Refresh() end)
    a.first:SetPoint("TOPLEFT", 0, -4)
    local b = Kit.Choice(body, { { id = "dark", label = "Dark" }, { id = "class", label = "Class" } },
        function() return state.fill end, function(v) state.fill = v; Refresh() end, 64)
    b.first:SetPoint("TOPLEFT", 0, -34)
    local c = Kit.Choice(body, { { id = "samples", label = "Samples" }, { id = "live", label = "Live" } },
        function() return state.source end, function(v) state.source = v; Refresh() end, 72)
    c.first:SetPoint("LEFT", b.buttons[2], "RIGHT", 24, 0)
    Refresh()
    -- Live slots update five times a second; the group itself is re-read each second.
    local tick = 0
    Kit.Every(body, 0.2, function()
        tick = tick + 1
        if tick % 5 == 0 and state.source == "live" then Refresh(); return end
        for i = 1, Current().count do
            local f = members[i]
            if f and f.unit and f:IsShown() then ApplyLive(f, f.unit, state.fill == "class") end
        end
    end)
end

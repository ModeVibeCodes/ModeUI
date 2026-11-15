local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- Cooldown Manager probe (Phase 6): the game's cooldown viewer rows in the
-- Mode design language: Essential icons 40 x 34 and Utility 32 x 28 in the
-- `frameThin` edge, tracked buffs as icons, and tracked bars as Mode Gradient
-- timer bars with the Comet spark. Your class's cooldowns come from the game
-- (C_CooldownViewer through ModeUI's reader); unlearned ones are grey. When
-- the game has none to give, samples fill the rows.
local S, T, D = Kit.S, Kit.T, Kit.D
local CD = D.Cooldowns

local SAMPLE_ICONS = {
    Essential = { [[Interface\Icons\Ability_Rogue_Eviscerate]], [[Interface\Icons\Ability_Vanish]], [[Interface\Icons\Ability_Rogue_Sprint]],
        [[Interface\Icons\Spell_Shadow_ShadowWard]], [[Interface\Icons\Ability_Rogue_KidneyShot]], [[Interface\Icons\Ability_Kick]] },
    Utility = { [[Interface\Icons\Ability_Stealth]], [[Interface\Icons\Ability_Rogue_Distract]], [[Interface\Icons\Ability_Sap]],
        [[Interface\Icons\Spell_Shadow_MindSteal]], [[Interface\Icons\Ability_Rogue_FeignDeath]] },
    TrackedBuff = { [[Interface\Icons\Ability_Rogue_SliceDice]], [[Interface\Icons\Ability_Warrior_Riposte]],
        [[Interface\Icons\Spell_Nature_Invisibilty]] },
}
local SAMPLE_BARS = {
    { name = "Slice and Dice", icon = [[Interface\Icons\Ability_Rogue_SliceDice]], time = 21 },
    { name = "Adrenaline Rush", icon = [[Interface\Icons\Spell_Shadow_ShadowWordDominate]], time = 15 },
    { name = "Evasion", icon = [[Interface\Icons\Spell_Shadow_ShadowWard]], time = 12 },
}

-- A row of icons for a viewer category, live when the game lists any.
local function Row(body, category, width, y, title)
    Kit.Heading(body, title, 0, y)
    local list = CD.ClassCooldowns({ category })
    local live = #list > 0
    local count = live and math.min(#list, 12) or #SAMPLE_ICONS[category]
    local icons = {}
    local px = S.Pixel(body)
    for i = 1, count do
        local icon = Kit.Icon(body, width, "frameThin", { numbers = true })
        local step = width + 2 * icon.edge:Outset() + 2 * px
        icon:SetPoint("TOPLEFT", body, "TOPLEFT", 4 + (i - 1) * step, y - 24)
        local entry = list[i]
        if live then
            icon.spellID = entry.spellID
            icon.icon:SetTexture(CD.SpellIcon(entry.spellID))
            icon.icon:SetDesaturated(not entry.known)
            if not entry.known then S.Paint(icon.icon, T.graphite.muted) end
        else
            icon.icon:SetTexture(SAMPLE_ICONS[category][i])
            if i == 2 then icon.cooldown:SetCooldown(GetTime() - 30, 90); icon.cooldown:Show() end
        end
        if icon.cooldown.GetCountdownFontString then
            local ok, text = pcall(icon.cooldown.GetCountdownFontString, icon.cooldown)
            if ok and text then S.Font(text, math.floor(width / 3), "bold"); text:SetTextColor(T.cooldown[1], T.cooldown[2], T.cooldown[3]) end
        end
        icons[i] = icon
    end
    local caption = Kit.Caption(body, (live and "Your class (live): " or "Samples: ") .. title .. ", " .. width .. " x " .. S.IconHeight(width),
        icons[1] or body, 0, -8)
    return icons, live, caption
end

-- Live cooldowns: the spell's duration object drives the swipe and numbers.
local function UpdateCooldowns(icons)
    for _, icon in ipairs(icons) do
        local duration = icon.spellID and CD.CooldownDuration(icon.spellID)
        if duration and icon.cooldown.SetCooldownFromDurationObject
            and pcall(icon.cooldown.SetCooldownFromDurationObject, icon.cooldown, duration) then
            icon.cooldown:Show()
        elseif icon.spellID then
            icon.cooldown:Hide()
        end
    end
end

-- A tracked bar: icon, then a Mode Gradient timer bar with the Comet spark.
local function NewTimer(body, s, y)
    local holder = CreateFrame("Frame", nil, body)
    holder:SetSize(220, 16)
    holder:SetPoint("TOPLEFT", body, "TOPLEFT", 26, y)
    local bar = S.Bar(holder, { role = "timer", spark = true })
    bar:SetAllPoints()
    -- Your class color, like the game's own tracked bars.
    local c = D.UnitColor.PlayerClass("player")
    bar:SetFill(c and { c.r, c.g, c.b } or T.ivory)
    bar:SetMinMaxValues(0, s.time)
    S.Edge(holder, "frameThin")
    local icon = Kit.Icon(body, 20, "frameThin")
    icon:SetPoint("RIGHT", holder, "LEFT", -4, 0)
    icon:SetHeight(16)
    S.CropIcon(icon.icon, 20, 16)
    icon.icon:SetTexture(s.icon)
    local texts = CreateFrame("Frame", nil, holder)
    texts:SetAllPoints(); texts:SetFrameLevel(bar:GetFrameLevel() + 4)
    local name = Kit.Text(texts, 10, "bold", T.textBright)
    name:SetPoint("LEFT", 4, 0); name:SetText(s.name)
    local left = Kit.Text(texts, 10, "bold", T.textBright)
    left:SetPoint("RIGHT", -4, 0)
    return { bar = bar, left = left, time = s.time, name = name }
end

function ns.BuildCooldownManager(body)
    local essential = Row(body, "Essential", 40, -4, "Essential")
    local utility = Row(body, "Utility", 32, -100, "Utility")
    local buffs = Row(body, "TrackedBuff", 32, -186, "Tracked buffs")
    Kit.Heading(body, "Tracked bars (samples)", 0, -272)
    local timers = {}
    for i, s in ipairs(SAMPLE_BARS) do timers[i] = NewTimer(body, s, -298 - (i - 1) * 24) end
    Kit.Caption(body, "Mode Gradient in the bar's color, Comet spark, frameThin edge; text in Geist Bold.", timers[#timers].bar, -26, -10)
    local clock = 0
    Kit.Every(body, 0.05, function(elapsed)
        clock = clock + elapsed
        for _, timer in ipairs(timers) do
            local left = timer.time - (clock % (timer.time + 1))
            if left < 0 then left = 0 end
            timer.bar:SetValue(left)
            timer.left:SetFormattedText("%.1f", left)
        end
    end)
    Kit.Every(body, 0.25, function()
        UpdateCooldowns(essential); UpdateCooldowns(utility); UpdateCooldowns(buffs)
    end)
end

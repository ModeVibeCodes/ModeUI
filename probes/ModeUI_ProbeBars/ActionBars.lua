local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- Action Bars probe (Phase 6): buttons in the Mode design language: 40 x 34
-- (wider than tall), the `frame` edge (2px Gunmetal, edge-lit, shadow and
-- drop), Geist Bold keybinds and counts, cooldown numbers in the cooldown
-- color, and the `empty` rim in Celadon for a proc. The top row mirrors your
-- action slots 1-12 (pictures only: these buttons can't cast); the second row
-- shows each state; the Extra Action button is a sample.
local S, T, D = Kit.S, Kit.T, Kit.D
local Q = D.Query

-- An action API: C_ActionBar's when the client has it, else the global.
local function API(name) return (C_ActionBar and C_ActionBar[name]) or _G[name] end

local SIZE = 40
local SAMPLE = {
    { label = "Ready", icon = [[Interface\Icons\Ability_Rogue_SinisterStrike]], key = "1" },
    { label = "Hover", icon = [[Interface\Icons\Ability_Rogue_Eviscerate]], key = "2", hover = true },
    { label = "Cooldown", icon = [[Interface\Icons\Ability_Vanish]], key = "3", cooldown = 42 },
    { label = "Proc", icon = [[Interface\Icons\Ability_Rogue_Ambush]], key = "4", proc = true },
    { label = "Out of range", icon = [[Interface\Icons\Ability_Throw]], key = "5", range = true },
    { label = "No energy", icon = [[Interface\Icons\Ability_Rogue_KidneyShot]], key = "6", mana = true },
    { label = "Unusable", icon = [[Interface\Icons\Ability_Stealth]], key = "7", unusable = true },
    { label = "Charges", icon = [[Interface\Icons\INV_Misc_Bomb_08]], key = "S-8", count = "2" },
}

-- A button face: the icon in the `frame` edge (or a Celadon `empty` rim for a
-- proc), its keybind top right, count bottom right, cooldown numbers centered.
local function NewButton(parent, width, proc)
    local button = CreateFrame("Button", nil, parent)
    local height = S.IconHeight(width)
    button:SetSize(width, height)
    button.face = Kit.Fill(button, "Button", T.mono.panel, "BACKGROUND", -2)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    S.CropIcon(button.icon, width, height)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    if button.cooldown.SetDrawEdge then button.cooldown:SetDrawEdge(false) end
    button.cooldown:Hide()
    button.edge = proc and S.Edge(button, "empty", { color = T.celadon, rim = 2 }) or S.Edge(button, "frame")
    button.texts = CreateFrame("Frame", nil, button)
    button.texts:SetAllPoints()
    button.texts:SetFrameLevel(button.cooldown:GetFrameLevel() + 3)
    button.key = Kit.Text(button.texts, 10, "bold", T.graphite.secondary)
    button.key:SetPoint("TOPRIGHT", -2, -2)
    button.count = Kit.Text(button.texts, 11, "bold", T.textBright)
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button.timer = Kit.Text(button.texts, 13, "bold", T.cooldown)
    button.timer:SetPoint("CENTER")
    -- The cooldown's own countdown numbers, in Geist Bold and the cooldown color.
    if button.cooldown.GetCountdownFontString then
        local ok, text = pcall(button.cooldown.GetCountdownFontString, button.cooldown)
        if ok and text then S.Font(text, 13, "bold"); text:SetTextColor(T.cooldown[1], T.cooldown[2], T.cooldown[3]) end
    end
    return button
end

-- Icon tint for a state: out of range Rosewood, out of power the power blue,
-- unusable desaturated and muted.
local function Tint(button, state)
    local icon = button.icon
    icon:SetDesaturated(state == "unusable")
    if state == "range" then S.Paint(icon, T.rosewood)
    elseif state == "mana" then S.Paint(icon, S.Mix(T.power, T.mono.white, 0.7))
    elseif state == "unusable" then S.Paint(icon, T.graphite.muted)
    else S.Paint(icon, T.mono.white) end
end

-- "SHIFT-1" -> "S-1", the way short keybinds read on a 40px button.
local function ShortKey(key)
    if type(key) ~= "string" then return "" end
    return (key:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("BUTTON", "M"):gsub("MOUSEWHEELUP", "WU")
        :gsub("MOUSEWHEELDOWN", "WD"):gsub("NUMPAD", "N"))
end

-- One live slot: picture, count, keybind, usability, range and cooldown.
local function ApplySlot(button, slot, index)
    local okTexture, texture = Q.Call(API("GetActionTexture"), slot)
    local has = okTexture and texture ~= nil
    button.icon:SetShown(has)
    if has and not pcall(button.icon.SetTexture, button.icon, texture) then button.icon:Hide() end
    local okCount, count = Q.Call(API("GetActionCount"), slot)
    if not (okCount and has and pcall(button.count.SetText, button.count, (Kit.IsNumber(count) and count > 1) and count or "")) then
        button.count:SetText("")
    end
    button.key:SetText(ShortKey(Q.Plain(GetBindingKey, "ACTIONBUTTON" .. index)))
    local usable, noMana = Q.Plain(API("IsUsableAction"), slot)
    local inRange = Q.Plain(API("IsActionInRange"), slot)
    Tint(button, not has and "ready" or inRange == false and "range" or noMana and "mana" or usable == false and "unusable" or "ready")
    local kind, id = Q.Plain(API("GetActionInfo"), slot)
    local duration = kind == "spell" and Kit.IsNumber(id) and D.Cooldowns.CooldownDuration(id)
    if duration and button.cooldown.SetCooldownFromDurationObject
        and pcall(button.cooldown.SetCooldownFromDurationObject, button.cooldown, duration) then
        button.cooldown:Show()
    else
        button.cooldown:Hide()
    end
end

local function ApplySample(button, s)
    button.icon:SetTexture(s.icon)
    button.key:SetText(s.key)
    button.count:SetText(s.count or "")
    button.timer:SetText(s.cooldown and tostring(s.cooldown) or "")
    if s.cooldown then button.cooldown:SetCooldown(GetTime() - 18, 60); button.cooldown:Show() end
    Tint(button, s.range and "range" or s.mana and "mana" or s.unusable and "unusable" or "ready")
    if s.hover then button.edge:SetHighlight("accent") end
end

function ns.BuildActionBars(body)
    local px = S.Pixel(body)
    -- Buttons 4px apart outside their shadows.
    local probe = NewButton(body, SIZE)
    local step = SIZE + 2 * probe.edge:Outset() + 4 * px
    probe:Hide()
    Kit.Heading(body, "Your action bar 1 (live)", 0, -4)
    local live = {}
    for i = 1, 12 do
        local button = NewButton(body, SIZE)
        button:SetPoint("TOPLEFT", body, "TOPLEFT", 6 + (i - 1) * step, -30)
        button.slot = i
        button:SetScript("OnEnter", function(self)
            if GameTooltip and GameTooltip.SetAction then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetAction(self.slot); GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        live[i] = button
    end
    local note = Kit.Caption(body, "Pictures of slots 1-12: pressing them does nothing. Keybinds, counts, range, power and cooldowns follow the game.", live[1], 0, -12)
    Kit.Heading(body, "States", 0, -120)
    for i, s in ipairs(SAMPLE) do
        local button = NewButton(body, SIZE, s.proc)
        button:SetPoint("TOPLEFT", body, "TOPLEFT", 6 + (i - 1) * (step + 26), -146)
        ApplySample(button, s)
        Kit.Caption(body, s.label, button, 0, -10)
    end
    Kit.Heading(body, "Extra Action", 0, -236)
    local extra = NewButton(body, 56)
    extra:SetPoint("TOPLEFT", body, "TOPLEFT", 6, -262)
    ApplySample(extra, { icon = [[Interface\Icons\INV_Misc_EngGizmos_27]], key = "" })
    Kit.Caption(body, "56 x 50, the frame edge; a sample (no encounter needed).", extra, 0, -10)
    Kit.Heading(body, "Sizes", 300, -236)
    local x = 300
    for _, width in ipairs({ 30, 36, 44 }) do
        local button = NewButton(body, width)
        button:SetPoint("TOPLEFT", body, "TOPLEFT", x, -262)
        ApplySample(button, { icon = [[Interface\Icons\Ability_Rogue_SinisterStrike]], key = "1" })
        Kit.Caption(body, width .. " x " .. S.IconHeight(width), button, 0, -10)
        x = x + width + 40
    end
    note:SetWidth(step * 12)
    Kit.Every(body, 0.25, function() for i, button in ipairs(live) do ApplySlot(button, i, i) end end)
end

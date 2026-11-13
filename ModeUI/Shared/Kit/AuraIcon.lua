local _, addon = ...
local Kit = addon.Kit

-- An aura icon in the Mode look: a 1px slate rim, the icon cropped inside it,
-- a cooldown swipe and the stack count in the corner. Fill it with
-- Domain.Auras.Apply.
function Kit.AuraIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    icon.rim = icon:CreateTexture(nil, "BACKGROUND")
    icon.rim:SetTexture(Kit.FLAT); icon.rim:SetAllPoints()
    icon.icon = icon:CreateTexture(nil, "ARTWORK")
    icon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.cooldown = CreateFrame("Cooldown", nil, icon)
    icon.cooldown:SetAllPoints(icon.icon)
    if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(false) end
    if icon.cooldown.SetReverse then icon.cooldown:SetReverse(true) end
    if icon.cooldown.SetHideCountdownNumbers then icon.cooldown:SetHideCountdownNumbers(true) end
    icon.textLayer = CreateFrame("Frame", nil, icon)
    icon.textLayer:SetAllPoints()
    icon.count = Kit.Text(icon.textLayer)
    icon.count.lift = Kit.Text(icon.textLayer, "ARTWORK")
    icon:Hide()
    return icon
end

-- Size, rim and text for one icon; px is one physical pixel.
function Kit.LayoutAuraIcon(icon, size, px, style, fontPath)
    icon:SetSize(size, size)
    Kit.Tint(icon.rim, Kit.onyx.border, 1)
    Kit.Inset(icon.icon, icon, px)
    icon.textLayer:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
    local countSize = math.max(7, math.floor(size * 0.45 + 0.5))
    Kit.Font(icon.count, style, countSize, fontPath, px)
    icon.count:ClearAllPoints()
    icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -px, px)
    icon.count:SetJustifyH("RIGHT")
    Kit.LayoutLift(icon.count, style, countSize, fontPath, px, true, "RIGHT")
end

local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- One member's face, the same for a secure header button and its Edit Mode
-- or preview stand-in: health and power bars inside the ModeUI border
-- (Kit.ModeBorder), incoming heals and absorbs riding on the health fill,
-- texts and icons above, highlights for your target, the mouse and a debuff
-- you can dispel, and a layer for aura icons. Nothing here is protected:
-- these are children of the button, so they may change in combat.
local Kit = addon.Kit

-- A bar that rides on the health fill: its left edge follows the end of the
-- health fill texture, its range is the health range, so a (possibly secret)
-- amount draws at the right length without arithmetic. As oUF's HealthPrediction.
local function Rider(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(Kit.FLAT)
    bar:SetMinMaxValues(0, 1); bar:SetValue(0)
    return bar
end

function M:BuildFace(f)
    local panel = CreateFrame("Frame", nil, f)
    panel:SetAllPoints(f)
    f.panel = panel
    panel.border = Kit.ModeBorder(panel)
    panel.hairline = panel:CreateTexture(nil, "BACKGROUND", nil, 0)
    panel.hairline:SetTexture(Kit.FLAT)
    f.health, f.power = Kit.Bar(panel), Kit.Bar(panel)
    f.healPrediction, f.absorb = Rider(f.health), Rider(f.health)
    -- Highlights sit over the bars and under the text.
    local glow = CreateFrame("Frame", nil, f)
    glow:SetAllPoints(panel)
    f.glowLayer = glow
    -- Border highlights: the ModeUI border shape again, in the highlight color.
    f.targetRing, f.dispelRing = Kit.CapRing(glow, 1), Kit.CapRing(glow, 2)
    f.targetFill = glow:CreateTexture(nil, "ARTWORK", nil, 0)
    f.dispelFill = glow:CreateTexture(nil, "ARTWORK", nil, 0)
    f.hover = glow:CreateTexture(nil, "ARTWORK", nil, -1)
    for _, region in ipairs({ f.targetFill, f.dispelFill, f.hover }) do region:SetTexture(Kit.FLAT); region:Hide() end
    f.textLayer = CreateFrame("Frame", nil, f)
    f.textLayer:SetAllPoints(panel)
    f.texts = {}
    for element in pairs(self.textElements) do
        local text = Kit.Text(f.textLayer)
        text.lift = Kit.Text(f.textLayer, "ARTWORK")
        Kit.Write(text, "")
        f.texts[element] = text
    end
    f.icons = {}
    for _, element in ipairs(self.elements) do
        if not self.textElements[element] then
            local icon = f.textLayer:CreateTexture(nil, "OVERLAY", nil, 1)
            icon:Hide()
            f.icons[element] = icon
        end
    end
    f.auraLayer = CreateFrame("Frame", nil, f)
    f.auraLayer:SetAllPoints(panel)
    f.auraIcons, f.auraShown = {}, {}
    for _, group in ipairs(self.auraGroups) do f.auraIcons[group], f.auraShown[group] = {}, 0 end
    f.auraContainers = {}
end

-- The mouse highlight on secure buttons and stand-ins alike.
function M:HookHover(f)
    f:HookScript("OnEnter", function() if self.db.hoverHighlight then f.hover:Show() end end)
    f:HookScript("OnLeave", function() f.hover:Hide() end)
end

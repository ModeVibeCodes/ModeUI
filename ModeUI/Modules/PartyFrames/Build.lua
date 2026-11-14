local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- One member's face, the same for a secure header button and its Edit Mode
-- or preview stand-in: health and power bars inside the ModeUI border in its
-- box form (Kit.ModeBoxBorder: corners as round as the chat windows'), heals
-- and shields riding on the health fill, an overshield filling back from full
-- health, texts and icons above, highlights for your target and the mouse,
-- debuff effects by type, and a layer for aura icons. Nothing here is
-- protected: these are children of the button, so they may change in combat.
local Kit = addon.Kit

function M:BuildFace(f)
    local panel = CreateFrame("Frame", nil, f)
    panel:SetAllPoints(f)
    f.panel = panel
    panel.border = Kit.ModeBoxBorder(panel)
    panel.hairline = panel:CreateTexture(nil, "BACKGROUND", nil, 0)
    panel.hairline:SetTexture(Kit.FLAT)
    f.health, f.power = Kit.Bar(panel), Kit.Bar(panel)
    -- Inset power bars wear a border of their own.
    f.powerBorder = Kit.ModeBoxBorder(f.power)
    -- Riders: bars on the health bar that take its range, so a (possibly
    -- secret) amount draws at the right length without arithmetic.
    f.healPrediction, f.absorb, f.overshield = Kit.Bar(f.health), Kit.Bar(f.health), Kit.Bar(f.health)
    for _, bar in ipairs({ f.healPrediction, f.absorb, f.overshield }) do
        bar.bg:Hide(); bar:SetMinMaxValues(0, 1); bar:SetValue(0)
    end
    -- Highlights sit over the bars and under the text.
    local glow = CreateFrame("Frame", nil, f)
    glow:SetAllPoints(panel)
    f.glowLayer = glow
    f.targetRing = Kit.ModeBoxBorder(glow)
    f.targetFill = glow:CreateTexture(nil, "ARTWORK", nil, 0)
    f.hover = glow:CreateTexture(nil, "ARTWORK", nil, -1)
    -- Debuff effects for samples and clients without aura containers
    -- (Dispel.lua; in the world the game shows them through aura slots).
    f.dispel = { ring = Kit.ModeBoxBorder(glow), health = glow:CreateTexture(nil, "ARTWORK", nil, 1),
        gradient = glow:CreateTexture(nil, "ARTWORK", nil, 2) }
    for _, region in ipairs({ f.targetFill, f.hover, f.dispel.health, f.dispel.gradient }) do region:SetTexture(Kit.FLAT); region:Hide() end
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

-- Shows or hides every piece of a box border (its rim frame).
function M.ShowBorder(border, shown) border.edge:SetShown(shown and true or false) end

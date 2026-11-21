local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- One member's face, the same for a secure header button and its Edit Mode
-- or preview stand-in (docs/DESIGN_LANGUAGE.md): health and power bars inside
-- the `group` edge (1px Gunmetal; the rim art covers the bars' corners, so
-- nothing is masked), incoming heals riding on the health fill, Combined
-- shields (Style.Shield), texts and icons above, highlights for your target,
-- aggro and the mouse (the rim swapped to a flat color, so the size never
-- changes), debuff effects by type, and a layer for aura icons. Nothing here
-- is protected: these are children of the button, so they may change in combat.
local Kit, Style = addon.Kit, addon.Style

function M:BuildFace(f)
    local panel = CreateFrame("Frame", nil, f)
    panel:SetAllPoints(f)
    f.panel = panel
    -- The bars' area, one rim inside the member; the edge's rim fills that band.
    panel.inner = CreateFrame("Frame", nil, panel)
    panel.back = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
    Style.ApplyAsset(panel.back, "Solid")
    panel.hairline = panel:CreateTexture(nil, "BACKGROUND", nil, 0)
    Style.ApplyAsset(panel.hairline, "Solid")
    f.health, f.power = Kit.Bar(panel), Kit.Bar(panel)
    -- Edges in pieces: a member is shorter than the ring art, whose sliced
    -- corners shrink and read square (owner, November 18, 2026;
    -- docs/DESIGN_LANGUAGE.md, "Pieces").
    panel.edge = Style.Edge(panel.inner, "group", { pieces = true })
    -- Inset power bars wear an edge of their own.
    f.powerEdge = Style.Edge(f.power, "group", { pieces = true })
    -- Incoming heals: a bar on the health bar that takes its range, so a
    -- (possibly secret) amount draws at the right length without arithmetic.
    f.healPrediction = Kit.Bar(f.health)
    f.healPrediction.bg:Hide(); f.healPrediction:SetMinMaxValues(0, 1); f.healPrediction:SetValue(0)
    -- The spark end line where the heals stop (Style.EndSpark).
    f.healPrediction.spark = Style.EndSpark(f.healPrediction)
    f.health.shield = Style.Shield(f.health)
    -- The Prism glow round the member (mouseover and focus: Update.lua).
    f.prism = Style.Glow(panel)
    -- Highlights sit over the bars and under the text.
    local glow = CreateFrame("Frame", nil, f)
    glow:SetAllPoints(panel)
    f.glowLayer = glow
    f.targetFill = glow:CreateTexture(nil, "ARTWORK", nil, 0)
    f.hover = glow:CreateTexture(nil, "ARTWORK", nil, -1)
    -- Debuff effects for samples and clients without aura containers
    -- (Dispel.lua; in the world the game shows them through aura slots).
    f.dispel = { health = glow:CreateTexture(nil, "ARTWORK", nil, 1), gradient = glow:CreateTexture(nil, "ARTWORK", nil, 2) }
    for _, region in ipairs({ f.targetFill, f.hover, f.dispel.health, f.dispel.gradient }) do Style.ApplyAsset(region, "Solid"); region:Hide() end
    f.textLayer = CreateFrame("Frame", nil, f)
    f.textLayer:SetAllPoints(panel)
    -- The power text sits on the power bar, above its border.
    f.powerTextLayer = CreateFrame("Frame", nil, f.power)
    f.powerTextLayer:SetAllPoints(f.power)
    f.powerText = Kit.Text(f.powerTextLayer)
    f.powerText.lift = Kit.Text(f.powerTextLayer, "ARTWORK")
    Kit.Write(f.powerText, "")
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
    f:HookScript("OnEnter", function()
        if self.db.hoverHighlight then f.hover:Show() end
        f.hovered = true; self:PaintGlow(f)
    end)
    f:HookScript("OnLeave", function() f.hover:Hide(); f.hovered = false; self:PaintGlow(f) end)
end

-- The member's rim: a dispel type's color (samples), your target, aggro, or
-- the Gunmetal metal (docs/DESIGN_LANGUAGE.md, "Borders": group frames swap
-- their rim instead of adding a ring, so their size never changes).
function M:PaintRim(f)
    local db = self.db
    local color = f.dispelRim or (f.isTarget and db.targetHighlight == "border" and db.targetColor)
        or (f.hasAggro and db.aggroHighlight and Style.Tone.reaction.hostile) or nil
    f.panel.edge:SetTint(color)
end

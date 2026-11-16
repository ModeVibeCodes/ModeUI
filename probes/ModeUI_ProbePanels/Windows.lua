local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- The Panel and Field helpers the Phase 7 tabs share (the Windows, Chat and
-- Damage Meters tabs retired once ModeUI's modules were built and
-- confirmed): panels in the Mode design
-- language (docs/DESIGN_LANGUAGE.md, "Windows and panels"): Graphite panel
-- with Mode Panel, Mode Title bar, the `window` edge (1px Steel Sheen, black
-- gap, shadow and drop), cards in the `card` edge, controls in `control`.
local S, T, D = Kit.S, Kit.T, Kit.D

-- A small Mode window inside the probe: panel, title bar and edge.
function ns.Panel(parent, title, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(width, height)
    Kit.Tiled(panel, "Panel", T.graphite.panel, "BACKGROUND", -7)
    panel.edge = S.Edge(panel, "window")
    if title then
        local bar = CreateFrame("Frame", nil, panel)
        bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(22)
        Kit.Tiled(bar, "Title", T.graphite.raised, "BACKGROUND", -6)
        local line = bar:CreateTexture(nil, "BORDER")
        S.ApplyAsset(line, "Solid"); S.Paint(line, T.graphite.line)
        line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
        panel.title = Kit.Text(bar, 11, "semibold", T.graphite.text)
        panel.title:SetPoint("LEFT", 8, 0)
        panel.title:SetText(title)
        panel.bar = bar
    end
    return panel
end

-- A text field: the `control` edge on a Graphite base, a muted placeholder.
function ns.Field(parent, width, placeholder)
    local field = CreateFrame("Frame", nil, parent)
    field:SetSize(width, 22)
    Kit.Fill(field, "Solid", T.graphite.base)
    S.Edge(field, "control")
    local text = Kit.Text(field, 11, "regular", T.graphite.muted)
    text:SetPoint("LEFT", 7, 0)
    text:SetText(placeholder)
    field.text = text
    return field
end

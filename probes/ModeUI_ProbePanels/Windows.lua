local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- Damage Meters probe (Phase 7; the Windows and Chat tabs retired once
-- ModeUI's modules were built and confirmed) and the Panel and Field helpers
-- the other tabs share: panels in the Mode design
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

-- Damage Meters: Mode Panel bars in class colors, 1px apart.
local METER = { { "WARRIOR", "Brannoc", 182400 }, { "MAGE", "Vayle", 164900 }, { "HUNTER", "Kestrel", 151200 },
    { "PRIEST", "Isolde", 40300 } }
function ns.BuildMeters(body)
    local meter = ns.Panel(body, "Damage Done  ·  Current", 280, 22 + 6 * 19 + 8)
    meter:SetPoint("TOPLEFT", 6, -6)
    local _, class = D.Query.Plain(UnitClass, "player")
    local rows = { { class or "ROGUE", D.Name.Get("player"), 171800 } }
    for _, row in ipairs(METER) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b) return a[3] > b[3] end)
    local total = 0
    for _, row in ipairs(rows) do total = total + row[3] end
    for i, row in ipairs(rows) do
        local holder = CreateFrame("Frame", nil, meter)
        holder:SetPoint("TOPLEFT", 4, -26 - (i - 1) * 19); holder:SetPoint("TOPRIGHT", -4, -26 - (i - 1) * 19)
        holder:SetHeight(18)
        local bar = S.Bar(holder, { role = "meter" })
        bar:SetAllPoints()
        bar:SetFill(Kit.ClassColor(row[1]))
        bar:SetMinMaxValues(0, rows[1][3]); bar:SetValue(row[3])
        local texts = CreateFrame("Frame", nil, holder)
        texts:SetAllPoints(); texts:SetFrameLevel(bar:GetFrameLevel() + 3)
        local name = Kit.Text(texts, 11, "semibold", T.textBright)
        name:SetPoint("LEFT", 5, 0)
        name:SetText(i .. ". " .. (Kit.IsPublic(row[2]) and row[2] or "You"))
        local value = Kit.Text(texts, 11, "bold", T.textBright)
        value:SetPoint("RIGHT", -5, 0)
        value:SetFormattedText("%.1fK  (%d%%)", row[3] / 1000, math.floor(row[3] / total * 100 + 0.5))
    end
    Kit.Caption(body, "Mode Panel bars in class colors on Mode BG, 1px apart; names SemiBold, numbers Bold. Sample fight (your name in it).", meter, 0, -12):SetWidth(600)
end

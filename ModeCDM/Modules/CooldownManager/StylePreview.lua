local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Bar Style page's preview (owner, November 24, 2026: a preview shows
-- what its page edits, not every bar): the Bar Style itself, drawn by the
-- same skin, text and glow code as the bars. A line of Large icons (your
-- Essential spells), one of Small icons (your Tracked Buffs) and a Tracked
-- Bar, each a sample style made from the Bar Style (BarStyle.lua), so the
-- page's changes show before any bar follows them. Sample values: a cooldown
-- on two icons, a count and the Starting Glow Look on the first.
local Copy = function(value) return addon.ProfileCodec.Copy(value) end
local ROWS = { { base = "essential", count = 6, label = "Large" }, { base = "buffIcon", count = 6, label = "Small" },
    { base = "buffBar", count = 1, label = "Bar" } }
local ROW_GAP, LABEL_WIDTH, MAX_WIDTH, CAPTION_HEIGHT, SAMPLE_ICON = 10, 44, 560, 18, 134400
local COOLING = { [2] = 3, [4] = 6 } -- seconds left of an 8 second sample cooldown

-- A sample style: bar `base`'s settings with every Bar Style group written
-- into them, one line of `count`, shown, with no spells of its own.
function M:BarStyleSample(base, count)
    local style = Copy(self.db[base])
    style.follow = {}
    for _, group in ipairs(self.styleGroups) do style.follow[group] = true end
    local db = { barStyle = self.db.barStyle, customBars = {}, [base] = style }
    self.ApplyBarStyle(db, base)
    style.perLine, style.grow, style.show, style.opacity, style.spells = count, "centerH", true, 100, {}
    return style
end

local function Rows(self)
    local rows, width = {}, 0
    for index, spec in ipairs(ROWS) do
        local style = self:BarStyleSample(spec.base, spec.count)
        local g = self.Geometry(style, spec.count, 1)
        rows[index] = { spec = spec, style = style, width = g.extent.width, height = g.extent.height }
        width = math.max(width, g.extent.width)
    end
    return rows, width
end
local function Scale(width) return math.min(1, MAX_WIDTH / (width + LABEL_WIDTH)) end

function M:GetStylePreviewSize()
    local rows, width = Rows(self)
    local scale, height = Scale(width), 0
    for _, row in ipairs(rows) do height = height + row.height end
    height = height + ROW_GAP * (#rows - 1)
    return math.max(600, (width + LABEL_WIDTH) * scale), height * scale + 12 + CAPTION_HEIGHT
end

local function Line(view, index)
    local line = view.lines[index]
    if line then return line end
    line = { area = CreateFrame("Frame", nil, view.frame), samples = {} }
    line.holder = CreateFrame("Frame", nil, line.area)
    line.label = W.Label(view.frame, "", nil, 0, 0, LABEL_WIDTH - 6, T.muted)
    view.lines[index] = line
    return line
end

local function Fill(self, sample, style, g, entry, index, bar)
    local icon = bar and sample.Icon.Icon or sample.Icon
    icon:SetTexture(entry.icon or SAMPLE_ICON)
    if bar then
        sample.Bar:SetValue(0.65)
        sample.Bar.Name:SetText(entry.name or "")
        sample.Bar.Duration:SetText("7")
        sample.Icon.Applications:SetText("2")
        return
    end
    sample.ChargeCount.Current:SetText(index == 1 and "2" or "")
    local left = COOLING[index]
    if left then
        sample.Cooldown:SetCooldown(GetTime() - (8 - left), 8); sample.Cooldown:Show()
        sample.cooldownText:SetText(string.format("%d", left))
    else
        sample.Cooldown:Hide(); sample.cooldownText:SetText("")
    end
    if sample.Icon.SetDesaturated then sample.Icon:SetDesaturated(left ~= nil and style.desaturate == true) end
end

function M:RenderStylePreview(view)
    local rows, width = Rows(self)
    local scale = Scale(width)
    local y = 4
    for index, row in ipairs(rows) do
        local line, spec, style = Line(view, index), row.spec, row.style
        local bar = self:IsBar(spec.base)
        line.area:SetScale(scale)
        local g = self.Geometry(style, spec.count, self.PixelSize(line.area))
        line.area:SetSize(g.extent.width, g.extent.height)
        line.area:ClearAllPoints()
        line.area:SetPoint("TOP", view.frame, "TOP", LABEL_WIDTH / 2 / scale, -y / scale)
        line.holder:SetSize(g.width, g.height)
        line.holder:ClearAllPoints(); line.holder:SetPoint("TOPLEFT", line.area, "TOPLEFT", g.extent.x, -g.extent.y)
        line.label:SetText(L[spec.label])
        line.label:ClearAllPoints(); line.label:SetPoint("RIGHT", line.area, "LEFT", -8, 0); line.label:SetJustifyH("RIGHT")
        local entries = self:PreviewEntries(spec.base)
        for i = 1, spec.count do
            local sample = line.samples[i]
            if not sample then sample = self:BuildSample(line.holder, bar); line.samples[i] = sample end
            local state = self:Dress(sample)
            state.viewer, state.g, state.style = spec.base, g, style
            local placed = self.Place(sample, line.holder, g, i)
            if bar then self:SkinBar(sample, style, placed, state) else self:SkinIcon(sample, style, placed, state) end
            self:StyleTexts(spec.base, sample, style, placed, false)
            Fill(self, sample, style, placed, entries[i] or {}, i, bar)
            local look
            if i == 1 and not bar then
                local kind = self:IsBuff(spec.base) and "buff" or "proc"
                look = { style = style[kind .. "Glow"], color = style[kind .. "Color"], pulse = style[kind .. "Pulse"],
                    lines = style.glowLines, thickness = style.glowThickness }
            end
            self:WantGlow(sample, "proc", look)
            self:ResolveGlows(sample)
            sample:Show()
        end
        y = y + row.height * scale + ROW_GAP * scale
    end
    local bs = self.db.barStyle
    view.caption:SetText(string.format(L["Bar Style · Large %d x %d · Small %d x %d · sample values"],
        bs.largeWidth, bs.largeHeight, bs.smallWidth, bs.smallHeight))
end

function M:CreateStylePreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, lines = {} }
    view.caption = W.Label(frame, "", nil, 0, 0, 520, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    function view.Refresh() M:RenderStylePreview(view) end
    view.RenderSimulation = view.Refresh
    self.stylePreview = view
    return view
end

-- What the shared preview widget (W.Preview) calls.
function M:StylePreviewOwner()
    return setmetatable({
        CreateConfigPreview = function(_, parent) return M:CreateStylePreview(parent) end,
        GetPreviewSize = function() return M:GetStylePreviewSize() end,
    }, { __index = M })
end

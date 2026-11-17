local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- The settings preview: the bar being edited, filled with sample auras in its
-- look (the same layout code as Edit Mode), drawn at most at 100% and scaled
-- down to fit the pane. A caption names the bar and what it shows.
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local CAPTION, MAX_WIDTH, MAX_HEIGHT = 18, 420, 150

local function Shown(bar)
    local parts = {}
    for _, category in ipairs(M.categories[bar.kind]) do
        if bar.cats[category.id] then parts[#parts + 1] = L[category.label] end
    end
    return #parts > 0 and table.concat(parts, ", ") or L["nothing picked"]
end

function M:GetPreviewSize()
    local bar = self.db.bars[self:EditingBar()]
    local width, height = self:BarSize(bar, 1)
    local scale = math.min(1, MAX_WIDTH / width, MAX_HEIGHT / height)
    return math.max(300, width * scale), height * scale + 12 + CAPTION
end

function M:RenderPreview(view)
    local id = self:EditingBar()
    local bar = self.db.bars[id]
    local width, height = self:BarSize(bar, 1)
    local scale = math.min(1, MAX_WIDTH / width, MAX_HEIGHT / height)
    local host = view.host
    host:SetScale(scale)
    host:SetSize(width, height)
    host:ClearAllPoints(); host:SetPoint("TOP", view.frame, "TOP", 0, -4 / scale)
    host:SetAlpha(bar.show and 1 or 0.4)
    self:PaintSamples(host, view.pool, bar, 1)
    local caption = self:BarLabel(id) .. " · " .. Shown(bar)
    if not bar.show then caption = self:BarLabel(id) .. " · " .. L["hidden"] end
    view.caption:SetText(caption)
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, pool = {} }
    view.host = CreateFrame("Frame", nil, frame)
    view.caption = W.Label(frame, "", nil, 0, 0, 400, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.caption:SetWordWrap(false)
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    self.previewViews = self.previewViews or {}
    self.previewViews[#self.previewViews + 1] = view
    return view
end

function M:RefreshPreview()
    for _, view in ipairs(self.previewViews or {}) do view.Refresh() end
    local page = self.page
    if page and page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
end

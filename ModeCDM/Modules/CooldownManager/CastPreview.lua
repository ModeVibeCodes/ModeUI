local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- The Cast Bar page's preview: the bar drawn by the same layout code as the
-- real one (CastBar.lua) with a sample cast; Animated runs the fill. A bar
-- wider than the page is scaled down to fit.
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local MAX_WIDTH, CAPTION_HEIGHT, CAST_SECONDS = 560, 18, 2

local function Scale(width) return math.min(1, MAX_WIDTH / width) end
-- How far a text sits off the bar, up or down.
local function Lift(style) return math.max(math.abs(style.nameY), math.abs(style.timerY)) end

function M:GetCastPreviewSize()
    local style = self.db.castBar
    local width = self:CastWidth(1)
    local scale = Scale(width)
    local tall = math.max(self.ResourceBarHeight(style, 1) + 2 * self.ResourceReach(style, 1), style.textSize + 2 * Lift(style))
    return math.max(320, width * scale), tall * scale + 12 + CAPTION_HEIGHT
end

function M:RenderCastPreview(view)
    local style, frame = self.db.castBar, view.bar
    local scale = Scale(self:CastWidth(1))
    view.area:SetScale(scale)
    local px = Kit.PixelSize(view.area)
    local width = self:CastWidth(px)
    view.area:SetSize(width, self:LayoutCastFrame(frame, width, px))
    view.area:ClearAllPoints()
    view.area:SetPoint("TOP", view.frame, "TOP", 0, -(6 + Lift(style)) / scale)
    local phase = addon.PreviewStates:Sample(self.id)
    self:PaintCastSample(frame, phase and (phase % CAST_SECONDS) / CAST_SECONDS or nil)
    frame:Show()
    view.area:SetAlpha(style.show and style.opacity / 100 or 0.4)
    local label = L[self.CAST_LABEL]
    view.caption:SetText((style.show and label or string.format(L["%s is off"], label)) .. " · " .. L["sample values"])
end

function M:CreateCastPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame }
    self.castPreview = view
    view.area = CreateFrame("Frame", nil, frame)
    view.bar = self:NewCastFrame(view.area)
    view.bar:SetAllPoints(view.area)
    view.caption = W.Label(frame, "", nil, 0, 0, 420, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    function view.Refresh() M:RenderCastPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

-- What the shared preview widget (W.Preview) calls.
function M:CastPreviewOwner()
    return setmetatable({
        CreateConfigPreview = function(_, parent) return M:CreateCastPreview(parent) end,
        GetPreviewSize = function() return M:GetCastPreviewSize() end,
    }, { __index = M })
end

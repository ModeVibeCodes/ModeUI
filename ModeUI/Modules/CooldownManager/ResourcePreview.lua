local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The resource bar page's preview: the bar being edited, drawn by the same
-- layout code as the real one (Resources.lua) with sample values, so every
-- class sees every bar (Combo Points show five points, three lit, for a
-- class without them). Animated runs the fill up and down. Bars wider than
-- the page are scaled down to fit.
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local Power = addon.Domain.Power
local MAX_WIDTH, CAPTION_HEIGHT, SAMPLE_MAX = 560, 18, 20300

-- The resource bar chosen in the window's list.
function M:ResourceEditing() return self:IsResource(self.selectedResource) and self.selectedResource or "power" end

local function Scale(width) return math.min(1, MAX_WIDTH / width) end

function M:GetResourcePreviewSize()
    local id = self:ResourceEditing()
    local style = self.db.resources[id]
    local width = self:ResourceWidth(id, 1)
    local scale = Scale(width)
    local tall = math.max(style.height + 2 * self.ResourceReach(style, 1), style.textSize + 2 * math.abs(style.textY))
    return math.max(320, width * scale), tall * scale + 12 + CAPTION_HEIGHT
end

-- Sample texts for a fill (0-1), in the real bar's formats.
local function Short(value) return value >= 1000 and string.format("%.1fK", value / 1000) or tostring(value) end
local function SampleText(mode, fraction)
    local current = math.floor(fraction * SAMPLE_MAX + 0.5)
    if mode == "current" then return Short(current) end
    if mode == "percent" then return string.format("%.0f%%", fraction * 100) end
    if mode == "both" then return string.format("%s · %.0f%%", Short(current), fraction * 100) end
    if mode == "currentMax" then return string.format("%s / %s", Short(current), Short(SAMPLE_MAX)) end
    return ""
end

function M:RenderResourcePreview(view)
    local id = self:ResourceEditing()
    local style, frame = self.db.resources[id], view.bar
    local scale = Scale(self:ResourceWidth(id, 1))
    view.area:SetScale(scale)
    local px = Kit.PixelSize(view.area)
    local width = self:ResourceWidth(id, px)
    local height = self:LayoutResourceFrame(frame, id, width, px, true)
    view.area:SetSize(width, height)
    view.area:ClearAllPoints()
    view.area:SetPoint("TOP", view.frame, "TOP", 0, -(6 + math.abs(style.textY)) / scale)
    local phase = addon.PreviewStates:Sample(self.id)
    local opacity = style.barOpacity / 100
    if self.resourceSpecs[id].segmented then
        local count = frame.count
        local lit = phase and (math.floor(phase * 2) % (count + 1)) or math.min(count, 3)
        for i = 1, count do frame.boxes[i].bar:SetValue(lit) end
        self.PaintResource(frame, self:ResourceColor(id), opacity)
        Kit.Write(frame.text, style.text == "current" and tostring(lit) or "")
    else
        local fraction = phase and (0.55 + 0.4 * math.sin(phase * 1.5)) or 0.65
        local bar = frame.boxes[1].bar
        bar:SetMinMaxValues(0, 100); bar:SetValue(fraction * 100)
        local token = id == "mana" and "MANA" or nil
        if id == "power" then token = select(2, Power.Read("player")) end
        self.PaintResource(frame, self:ResourceColor(id, token), opacity)
        Kit.Write(frame.text, SampleText(style.text, fraction))
    end
    frame:Show()
    view.area:SetAlpha(style.show and style.opacity / 100 or 0.4)
    local label = self:ResourceLabel(id)
    view.caption:SetText((style.show and label or string.format(L["%s is off"], label)) .. " · " .. L["sample values"])
end

function M:CreateResourcePreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame }
    self.resourcePreview = view
    view.area = CreateFrame("Frame", nil, frame)
    view.bar = self:NewResourceFrame(view.area)
    view.bar:SetAllPoints(view.area)
    view.caption = W.Label(frame, "", nil, 0, 0, 420, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    function view.Refresh() M:RenderResourcePreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

-- What the shared preview widget (W.Preview) calls: the module, with the
-- resource bar preview in place of the cooldown one.
function M:ResourcePreviewOwner()
    return setmetatable({
        CreateConfigPreview = function(_, parent) return M:CreateResourcePreview(parent) end,
        GetPreviewSize = function() return M:GetResourcePreviewSize() end,
    }, { __index = M })
end

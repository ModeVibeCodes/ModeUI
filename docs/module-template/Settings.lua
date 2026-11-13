local _, addon = ...
local M, W, L = addon.Example, addon.ConfigWidgets, addon.L
if not M then return end

-- Only defines the page. ModeUI builds it the first time it's opened (or a
-- settings search needs it), never at login.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    page:Section(L["Display"], nil, false)
    page.toggles = page:ToggleGrid({
        { label = L["Show Target Name"], get = function() return M.db.showTarget end,
            set = function(value) M:SetOption("showTarget", value) end },
    }, { maxColumns = 2, minimumCellWidth = 210 })
    local row = page:Row(L["Scale"], 48)
    page.refreshers[#page.refreshers + 1] = W.Slider(row, M.ranges.scale[1], M.ranges.scale[2], 1,
        function() return M.db.scale end, function(value) M:SetOption("scale", math.floor(value + 0.5)) end, "%", true)
    page.scaleSlider = row.slider
    page:Finish(); return page
end

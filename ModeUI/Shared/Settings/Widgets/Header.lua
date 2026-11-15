local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets

W.PAGE_HEADER_HEIGHT = 36

-- Page header (docs/DESIGN_LANGUAGE.md, "Settings window"): the page title on
-- the left and the module's slide toggle on the right. No description text:
-- the description stays on the header for search and tests, hidden.
function W.ModuleHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(W.PAGE_HEADER_HEIGHT)
    header:EnableMouse(false)
    local title = W.Heading(header, "", T.fontSize.page, 0, -2, 520, T.heading)
    title:SetWordWrap(false)
    local description = W.Label(header, "", nil, 0, -30, 520, T.muted)
    description:SetWordWrap(false); description:Hide()
    local toggle = W.Button(header, "", 68, 22, "toggle")
    toggle:SetPoint("TOPRIGHT", 0, 0)
    local state = W.Label(header, "", nil, 0, 0, 80, T.muted)
    state:ClearAllPoints(); state:SetPoint("RIGHT", toggle, "LEFT", -6, 0); state:SetJustifyH("RIGHT")
    title:SetPoint("TOPRIGHT", -84, -2)
    local divider = W.Fill(header, T.line, "BORDER")
    divider:ClearAllPoints(); divider:SetPoint("BOTTOMLEFT", 0, 0); divider:SetPoint("BOTTOMRIGHT", 0, 0)
    divider:SetHeight(1); divider:Hide()
    toggle:SetScript("OnClick", function()
        if header.module then addon:SetModuleEnabled(header.module.id, not header.module.enabled) end
    end)
    function header:Refresh()
        local gameplay = self.module ~= nil and not self.module.developer and not self.module.planned and not self.module.alwaysOn
        toggle:SetShown(gameplay)
        state:SetShown(false)
        if self.module then
            toggle:SetSelected(self.module.enabled)
            state:SetText(self.module.enabled and "Enabled" or "Disabled")
            state:SetTextColor(unpack(W.StateColor(self.module.enabled)))
        end
    end
    function header:SetModule(module)
        self.module = module
        title:SetText(module and module.title or "General")
        description:SetText(module and (module.configDescription or module.description or "")
            or "Turn modules on or off, or open one to change its settings.")
        self:Refresh()
    end
    header.title, header.description, header.toggle, header.state, header.divider = title, description, toggle, state, divider
    return header
end

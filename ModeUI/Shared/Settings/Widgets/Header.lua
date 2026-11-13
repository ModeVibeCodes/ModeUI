local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets

W.PAGE_HEADER_HEIGHT = 64

-- Page header: title and one-line description on the left, the module's
-- enable switch on the right, closed by a hairline.
function W.ModuleHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(W.PAGE_HEADER_HEIGHT)
    header:EnableMouse(false)
    local title = W.Heading(header, "", T.fontSize.page, 0, -2, 520, T.text)
    title:SetWordWrap(false)
    local description = W.Label(header, "", nil, 0, -30, 520, T.muted)
    description:SetWordWrap(false)
    local toggle = W.Button(header, "", 44, 24, "toggle")
    toggle:SetPoint("TOPRIGHT", 0, -2)
    local state = W.Label(header, "", nil, 0, 0, 80, T.muted)
    state:ClearAllPoints(); state:SetPoint("RIGHT", toggle, "LEFT", -6, 0); state:SetJustifyH("RIGHT")
    title:SetPoint("TOPRIGHT", -140, -2)
    description:SetPoint("TOPRIGHT", -140, -30)
    local divider = W.Fill(header, T.line, "BORDER")
    divider:ClearAllPoints(); divider:SetPoint("BOTTOMLEFT", 0, 12); divider:SetPoint("BOTTOMRIGHT", 0, 12)
    divider:SetHeight(1)
    toggle:SetScript("OnClick", function()
        if header.module then addon:SetModuleEnabled(header.module.id, not header.module.enabled) end
    end)
    function header:Refresh()
        local gameplay = self.module ~= nil and not self.module.developer and not self.module.planned and not self.module.alwaysOn
        toggle:SetShown(gameplay)
        state:SetShown(gameplay)
        if self.module then
            toggle:SetSelected(self.module.enabled)
            state:SetText(self.module.enabled and "Enabled" or "Disabled")
            state:SetTextColor(unpack(W.StateColor(self.module.enabled)))
        end
    end
    function header:SetModule(module)
        self.module = module
        title:SetText(module and module.title or "Dashboard")
        local icon=module and module.classIcon
        -- Class identity already appears in the sidebar and category tab.
        title:SetShown(icon==nil)
        description:ClearAllPoints();description:SetPoint("TOPLEFT",0,icon and -2 or -30)
        description:SetPoint("TOPRIGHT",-140,icon and -2 or -30)
        description:SetWordWrap(icon~=nil)
        description:SetText(module and (module.configDescription or module.description or "")
            or "Turn modules on or off, or open one to change its settings.")
        self:Refresh()
    end
    header.title, header.description, header.toggle, header.state, header.divider = title, description, toggle, state, divider
    return header
end

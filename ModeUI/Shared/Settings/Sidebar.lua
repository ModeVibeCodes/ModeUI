local _, addon = ...
-- The settings sidebar and the icon rail (docs/DESIGN_LANGUAGE.md, "Settings
-- window"). The sidebar: General, then each category's caption and its modules,
-- each with its icon and a Celadon (on) or Rosewood (off) dot; the chosen row
-- has a 2px Ivory bar on its left. The rail is the same list as 48px icons for
-- split view, with the home icon on top. Built once by addon:CreateConfig.
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
local Style = addon.Style
local ROW, CAPTION, RAIL_ITEM = 26, 26, 34

-- Each page's icon (a Style.ICONS name); a module may set module.icon instead.
local ICONS = { home = "Home", profiles = "Profiles", optimizations = "Optimizations", classColors = "ClassColors",
    windows = "Windows", chat = "Chat", damageMeters = "DamageMeters", actionBars = "ActionBars", tooltip = "Tooltip",
    bags = "Bags", minimap = "Minimap", unitFrames = "UnitFrames", nameplates = "Nameplates", partyFrames = "GroupFrames",
    cooldownManager = "Cooldowns" }
function addon:ConfigIcon(id)
    local module = self.modules[id]
    return (module and module.icon) or ICONS[id] or "Home"
end

local function Icon(parent, id, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    Style.ApplyAsset(icon, "Icon" .. addon:ConfigIcon(id))
    icon:SetSize(size, size)
    return icon
end
local function Dot(parent)
    local dot = parent:CreateTexture(nil, "OVERLAY")
    Style.ApplyAsset(dot, "Circle")
    dot:SetSize(6, 6)
    return dot
end
local function Tint(region, color) region:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end

-- The pages the sidebar lists, in order: { caption = category } or { id = page }.
local function Entries(self)
    local list = { { id = "home", title = "General" } }
    for _, categoryID in ipairs(self.categoryOrder) do
        local category = self.categories[categoryID]
        local modules = {}
        for _, id in ipairs(category.modules) do
            if not self.modules[id].standalone then modules[#modules + 1] = id end
        end
        if #modules > 0 then
            list[#list + 1] = { caption = category }
            for _, id in ipairs(modules) do list[#list + 1] = { id = id, title = self.modules[id].tabTitle or self.modules[id].title } end
        end
    end
    for _, id in ipairs(self.moduleOrder) do
        local module = self.modules[id]
        if not module.category and not module.standalone and not module.developer then list[#list + 1] = { id = id, title = module.title } end
    end
    return list
end

function addon:BuildConfigSidebar(window)
    local sidebar, rail = window.sidebar, window.rail
    local rows, items, captions = {}, {}, {}
    window.navigationButtons, window.sidebarModuleButtons, window.railButtons = captions, rows, items
    local y, ry = -6, -6
    for _, entry in ipairs(Entries(self)) do
        if entry.caption then
            local label = W.Label(sidebar, entry.caption.title:upper(), nil, 10, y - 10, 160, T.faint)
            addon.Media:BindInterfaceFont(label, GameFontHighlight, T.fontSize.group, nil, "heading")
            captions[entry.caption.id] = { label = label }
            y = y - CAPTION
            local line = W.Fill(rail, T.line, "BORDER")
            line:ClearAllPoints(); line:SetPoint("TOPLEFT", 8, ry - 4); line:SetPoint("TOPRIGHT", -8, ry - 4); line:SetHeight(1)
            ry = ry - 9
        else
            local id = entry.id
            local row = W.Button(sidebar, entry.title, W.SETTINGS_SIZES.sidebar - 1, ROW, "tab")
            row:SetPoint("TOPLEFT", 0, y)
            row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 31, 0); row.label:SetPoint("RIGHT", -24, 0)
            row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false)
            row.icon = Icon(row, id, 13); row.icon:SetPoint("LEFT", 12, 0)
            if self.modules[id] and not self.modules[id].alwaysOn then row.dot = Dot(row); row.dot:SetPoint("RIGHT", -12, 0) end
            row:SetScript("OnClick", function() self:SelectConfigPage(id) end)
            rows[id] = row
            y = y - ROW
            local item = W.Button(rail, "", W.SETTINGS_SIZES.rail - 1, RAIL_ITEM, "tab")
            item:SetPoint("TOPLEFT", 0, ry)
            item.icon = Icon(item, id, 15); item.icon:SetPoint("CENTER")
            if row.dot then item.dot = Dot(item); item.dot:SetPoint("BOTTOMRIGHT", -9, 7) end
            item:SetScript("OnClick", function() self:SelectConfigPage(id) end)
            item:HookScript("OnEnter", function(owner)
                GameTooltip:SetOwner(owner, "ANCHOR_RIGHT"); GameTooltip:SetText(entry.title); GameTooltip:Show()
            end)
            item:HookScript("OnLeave", function() GameTooltip:Hide() end)
            items[id] = item
            ry = ry - RAIL_ITEM
            if id == "home" then ry = ry - 2 end
        end
    end
    function window:RefreshNavigation()
        local selected = self.selectedPage
        for id, row in pairs(rows) do
            local chosen = id == selected
            row:SetSelected(chosen); items[id]:SetSelected(chosen)
            local color = chosen and T.heading or T.muted
            Tint(row.icon, color); Tint(items[id].icon, color)
            local module = addon.modules[id]
            if row.dot then
                local dot = module.enabled and T.enabled or T.off
                Tint(row.dot, dot); Tint(items[id].dot, dot)
            end
        end
    end
end

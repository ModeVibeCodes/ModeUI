local _, addon = ...
-- The General page, the settings window's main panel (docs/DESIGN_LANGUAGE.md,
-- "Settings window"): global cards four across. It holds only settings that
-- already work; each redesign phase adds the cards its modules obey (the
-- artifact's Accent, Text, Textures, Borders, Shields, Names, Scale, Combat).
local W, T = addon.ConfigWidgets, addon.InterfaceTheme

-- A row with its label on the left and a slide toggle on the right.
local function SwitchRow(page, title, get, set)
    local controls = page:Row(title, 30, nil, true)
    local row = controls.row
    controls:ClearAllPoints(); controls:SetAllPoints(row)
    local toggle = W.Button(controls, "", 68, 24, "toggle")
    toggle:SetPoint("RIGHT", 0, 0)
    toggle:SetScript("OnClick", function() set(not get()); page:Refresh() end)
    row.settingsLabel:SetTextColor(unpack(T.text))
    function row:layoutChildren(width) self.settingsLabel:SetWidth(math.max(40, width - 76)) end
    page.refreshers[#page.refreshers + 1] = function() toggle:SetSelected(get() and true or false) end
    return toggle
end

-- A full-width button row.
local function ButtonRow(page, label, onClick, keywords)
    local controls = page:Row(label, 30, keywords, true)
    local row = controls.row
    row.settingsLabel:Hide()
    controls:ClearAllPoints(); controls:SetAllPoints(row)
    local button = W.Button(controls, label, 120, 24)
    button:SetPoint("LEFT", 0, 0); button:SetPoint("RIGHT", 0, 0)
    button:SetScript("OnClick", onClick)
    return button
end

-- A label on the left and a button on the right (a quick action).
local function ActionRow(page, label, keywords)
    local controls = page:Row(label, 30, keywords, true)
    local row = controls.row
    controls:ClearAllPoints(); controls:SetAllPoints(row)
    local button = W.Button(controls, "", 96, 24)
    button:SetPoint("RIGHT", 0, 0)
    row.settingsLabel:SetTextColor(unpack(T.text))
    function row:layoutChildren(width) self.settingsLabel:SetWidth(math.max(40, width - 104)) end
    return button, row
end
local ROWS = { Switch = SwitchRow, Button = ButtonRow, Action = ActionRow }

-- Cards modules add to the General page (module:BuildHomeCard(page, rows)),
-- in module order; Shared names no module.
local function ModuleHomeCards(page)
    for _, id in ipairs(addon.moduleOrder) do
        local module = addon.modules[id]
        if module.BuildHomeCard then module:BuildHomeCard(page, ROWS) end
    end
end

-- A module's card: on/off and a button that opens its page.
local function ModuleCard(page, id)
    local module = addon.modules[id]
    if not module then return end
    page:Group(module.title)
    if not module.alwaysOn then
        page["home" .. id .. "Toggle"] = SwitchRow(page, "Enabled", function() return module.enabled end,
            function(value) addon:SetModuleEnabled(id, value) end)
    end
    page["home" .. id .. "Open"] = ButtonRow(page, "Open " .. module.title, function() addon:SelectConfigPage(id) end)
end

function addon:CreateConfigHome(parent)
    local page = W.Page(parent)
    page.cardColumns = 4
    page:Group("Profile")
    local host = page:Row("Active profile")
    page.homeProfile = W.Select(host, 160, function()
        local list = {}
        for _, name in ipairs(addon.Profiles:List()) do list[#list + 1] = { id = name, label = name } end
        return list
    end, function()
        local name = addon.Profiles:Pending() or addon.Profiles:Active()
        return name, tostring(name)
    end, function(name)
        local _, message = addon.Profiles:Select(name)
        if message then addon:PrintAction(message, "profile") end
    end)
    page.refreshers[#page.refreshers + 1] = function() page.homeProfile:Refresh() end
    page.homeProfiles = ButtonRow(page, "Manage profiles", function() addon:SelectConfigPage("profiles") end)
    ModuleHomeCards(page)
    ModuleCard(page, "optimizations")
    ModuleCard(page, "classColors")
    page:Group("Window")
    page.homeResetWindow = ButtonRow(page, "Reset position", function() addon:ResetConfigWindowPosition() end,
        { "window", "position", "center" })
    page:Finish()
    return page
end

local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, L = addon.CooldownManager, addon.ConfigWidgets, addon.L
if not M then return end

-- The resource bars' settings page, shown in the /mcdm window when a bar
-- under Resource Bars is chosen in its list; built the first time. A preview
-- of the bar (ResourcePreview.lua) above the tabs: Bar (here), Look, Text and
-- Visibility (ResourceSettingsLook.lua). Every bar keeps its own settings;
-- Group Resources is one choice shared by Power, Combo Points and Alternate
-- Mana.
function M:CreateResourcePage(parent)
    local page = W.Page(parent, 480); self.resourcePage = page
    local function Id() return M:ResourceEditing() end
    local function db() return M.db.resources[Id()] end
    page.resourceEditing = Id
    function page.SetEditing(id)
        if not M:IsResource(id) then return end
        M.selectedResource = id
        page:Refresh(); page:Layout()
        if page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
    end
    -- The shared row helpers (SettingsHelpers.lua) on the bar being edited.
    local ui = self:PageHelpers(page, { db = db, set = function(key, value) M:SetResourceOption(Id(), key, value) end,
        ranges = M.resourceRanges, owner = self:ResourceAppearanceOwner(Id) })
    local Refresh = ui.Refresh
    ui.Id = Id
    function ui.Segmented() return M.resourceSpecs[Id()].segmented == true end
    function ui.InBlock() return M:ResourceInBlock(Id()) end

    W.Preview(page, self:ResourcePreviewOwner(), { contentHeight = 90 })
    -- Editing: which bar this page shows, at the top right of the preview.
    self:AddEditingCorner(page)

    ui.Tab("Bar", function()
        page.resourceShowToggles = ui.Toggles({ { "Show Bar", "show" } })
        page.resourceStatus = ui.Status(function() return M:ResourceStatus(Id()) end)
        -- Group Resources: one border for Power, Combo Points and Alternate Mana.
        ui.When(function() return M.resourceSpecs[Id()].group == true end, function()
            page:Group(L["Resources"])
            page.resourceLayoutPills = ui.Pills("Layout", M.resourceChoices.resourceLayout, nil, 170,
                function() return M.db.resourceLayout end, function(value) M:SetResourceLayout(value) end)
        end)
        page:Group(L["Size"])
        ui.When(function() return not ui.InBlock() end, function()
            local size = ui.Columns({ "Width" })
            page.resourceWidthSlider = ui.Slider(size[1], "width", "px")
        end)
        local tall = ui.Columns({ "Height" })
        page.resourceHeightSlider = ui.Slider(tall[1], "height", "px")
        ui.When(ui.InBlock, function() W.Tip(ui.Note("Grouped: the block takes Power's width, border and place.")) end)
        -- Combo Points: Grouped (one border, a line between points) or Separated.
        ui.When(ui.Segmented, function()
            page:Group(L["Combo Points"])
            page.resourceComboLayoutPills = ui.Pills("Layout", M.resourceChoices.layout, "layout", 120)
            ui.When(function() return db().layout == "separated" and not ui.InBlock() end, function()
                local points = ui.Columns({ "Spacing" })
                page.resourceSpacingSlider = ui.Slider(points[1], "spacing", "px")
            end)
            ui.When(function() return db().layout == "grouped" or ui.InBlock() end, function()
                local lines = ui.Columns({ "Divider Width", "Divider Color" })
                page.resourceDividerSlider = ui.Slider(lines[1], "dividerWidth", "px")
                ui.Color(lines[2], "dividerColor")
            end)
        end)
        -- Tick Marks: this bar's own lines at power values, each for one
        -- power type; one to start, more with Add Tick Mark.
        ui.When(function() return M.resourceSpecs[Id()].marks == true end, function()
            page:Group(L["Tick Marks"])
            page.resourceMarkToggles = ui.Toggles({ { "Show Tick Marks", "marksShow" } })
            ui.When(function() return db().marksShow == true end, function()
                page.resourceMarkInputs, page.resourceMarkRemove = {}, {}
                local function Mark(i) local marks = db().marks; return marks and marks[i] end
                for i = 1, M.MARK_MAX do
                    ui.When(function() return Mark(i) ~= nil end, function()
                        local cells = ui.Columns({ string.format(L["Tick %d"], i), "Shows On" })
                        local input = W.NumericInput(cells[1], function() local mark = Mark(i); return mark and mark.value or 0 end,
                            function(value) M:SetResourceMark(Id(), i, "value", math.floor(value + 0.5)) end, M.MARK_RANGE[1], M.MARK_RANGE[2], 80)
                        input:SetPoint("LEFT")
                        Refresh(function() input:Refresh() end)
                        page.resourceMarkInputs[i] = input
                        if i > 1 then
                            local remove = W.Button(cells[1], L["Remove"], 80, 24, "secondary")
                            remove:SetPoint("LEFT", input, "RIGHT", 8, 0)
                            remove:SetScript("OnClick", function() M:RemoveResourceMark(Id(), i) end)
                            page.resourceMarkRemove[i] = remove
                        end
                        ui.Select(cells[2], 160, function() return M.resourceChoices.markPower end, nil,
                            function() local mark = Mark(i); return mark and mark.power or "any" end, function(value) M:SetResourceMark(Id(), i, "power", value) end)
                    end)
                end
                ui.When(function() local marks = db().marks; return marks ~= nil and #marks < M.MARK_MAX end, function()
                    page.resourceAddMarkButton = ui.Button("+ Add Tick Mark", 160, function() M:AddResourceMark(Id()) end)
                end)
                local look = ui.Columns({ "Tick Width", "Tick Color" })
                ui.Slider(look[1], "markWidth", "px")
                ui.Color(look[2], "markColor")
                W.Tip(ui.Note("These ticks are this bar's own. Type a power value (0 hides the tick); a tick shows only while its power type is shown."))
            end)
        end)
        page:Group(L["Placement"])
        page.resourceEditModeButton = ui.EditModeButton()
        page:Group(L["Reset"])
        page.resourceResetButton = ui.Button("Reset to Defaults", 150, function() M:ResetResource(Id()) end)
    end)

    self:BuildResourceLookTabs(page, ui)
    W.SectionTabs(page)
    page:Finish(); return page
end

-- One Tick Mark's value or power type.
function M:SetResourceMark(id, index, key, value)
    local marks = addon.ProfileCodec.Copy(self.db.resources[id].marks)
    if type(marks) ~= "table" or type(marks[index]) ~= "table" then return false end
    marks[index][key] = value
    return self:SetResourceOption(id, "marks", marks)
end

-- Add Tick Mark: one more (up to MARK_MAX), on the last one's power type.
function M:AddResourceMark(id)
    local marks = addon.ProfileCodec.Copy(self.db.resources[id].marks)
    if type(marks) ~= "table" or #marks >= self.MARK_MAX then return false end
    local last = marks[#marks]
    marks[#marks + 1] = { value = 0, power = type(last) == "table" and last.power or "any" }
    return self:SetResourceOption(id, "marks", marks)
end

-- Remove: a tick goes (the first one always stays).
function M:RemoveResourceMark(id, index)
    local marks = addon.ProfileCodec.Copy(self.db.resources[id].marks)
    if type(marks) ~= "table" or #marks <= 1 or type(marks[index]) ~= "table" then return false end
    table.remove(marks, index)
    return self:SetResourceOption(id, "marks", marks)
end

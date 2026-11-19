local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, L = addon.CooldownManager, addon.ConfigWidgets, addon.L
if not M then return end

-- The resource bar page's Look, Text and Visibility tabs (the page and its
-- Bar tab are ResourceSettings.lua; `ui` holds its shared helpers).
function M:BuildResourceLookTabs(page, ui)
    local db, Id, When, Columns = ui.db, ui.Id, ui.When, ui.Columns
    local function Dark() return db().barMode == "dark" end

    ui.Tab("Look", function()
        page:Group(L["Border"])
        -- In a Grouped block the border is the block's (Power's).
        When(function() return not ui.InBlock() end, function()
            page.resourceBorderPills = ui.Pills("Border", M.resourceChoices.border, "border", 96)
            -- Border Style and Rim Color (docs/DESIGN_LANGUAGE.md, "Choosing a border").
            When(function() return db().border ~= "none" end, function()
                local cells = Columns({ "Border Style", "Rim Color" })
                page.resourceBorderStylePicker = ui.Select(cells[1], 180, function() return M.resourceChoices.edgeStyle end, "edgeStyle")
                page.resourceRimPicker = ui.Select(cells[2], 180, M.ResourceRimChoices, nil,
                    function() return M:ResourceRim(Id()) end, function(value) M:SetResourceRim(Id(), value) end)
                local size = Columns({ "Border Size" })
                page.resourceBorderSizeSelect = ui.Select(size[1], 180, function() return M.choices.edgeSize end, "edgeSize")
                When(function() return db().rimColor == "custom" end, function()
                    local custom = Columns({ "Custom Rim Color" })
                    ui.Color(custom[1], "rimCustom")
                end)
            end)
        end)
        When(ui.InBlock, function() W.Tip(ui.Note("Grouped: the block's border is set on Power.")) end)
        page:Group(L["Bar"])
        -- Bar Mode: Color, or Dark (the fill in the dark fill, the text in color).
        page.resourceBarModePills = ui.Pills("Bar Mode", M.resourceChoices.barMode, "barMode", 96)
        local texture = Columns({ "Bar Texture", "Bar Color" })
        page.resourceTextureSelect = ui.Select(texture[1], 200, function() return addon.Kit.BarTextureChoices(true) end, "barTexture")
        page.resourceColorSelect = ui.Select(texture[2], 200, function() return M:ResourceColorChoices(Id()) end, "colorMode")
        When(function() return db().colorMode == "custom" end, function()
            local custom = Columns({ "Custom Color" })
            ui.Color(custom[1], "barColor")
        end)
        When(Dark, function()
            local text = Columns({ "Dark Text Color" })
            page.resourceDarkTextSelect = ui.Select(text[1], 200, function() return M:ResourceDarkTextChoices(Id()) end, "darkText")
            When(function() return db().darkText == "custom" end, function()
                local custom = Columns({ "Custom Text Color" })
                ui.Color(custom[1], "darkTextColor")
            end)
        end)
        local fill = Columns({ "Bar Opacity" })
        page.resourceBarOpacitySlider = ui.Slider(fill[1], "barOpacity", "%")
        local back = Columns({ "Bar Background", "Background Opacity" })
        page.resourceBackgroundSelect = ui.Select(back[1], 200, function() return addon.Kit.BarTextureChoices(false) end, "barBackground")
        page.resourceBackgroundSlider = ui.Slider(back[2], "barBackgroundOpacity", "%")
        -- Combo Points: every point takes Full Combo Points Color once all are lit.
        When(ui.Segmented, function()
            page.resourceFullToggles = ui.Toggles({ { "Full Combo Points Color", "fullShow" } })
            When(function() return db().fullShow end, function()
                local full = Columns({ "Full Combo Points Color" })
                ui.Color(full[1], "fullColor")
            end)
        end)
        page:Group(L["Fill"])
        page.resourceDirectionPills = ui.Pills("Fill Direction", M.resourceChoices.reverse, "reverse", 120)
        When(function() return not ui.Segmented() end, function()
            page.resourceFillToggles = ui.Toggles({ { "Smooth", "smooth" }, { "Fill End Line", "fillEdge" } })
        end)
    end)

    ui.Tab("Text", function()
        page:Group(L["Text"])
        -- The text sits in the middle of the bar; Show Text turns it on or off.
        page.resourceTextToggles = ui.Toggles({ { "Show Text", "textShow" } })
        When(function() return db().textShow == true end, function()
            -- Combo Points have one format, the count.
            When(function() return #M:ResourceTextChoices(Id()) > 1 end, function()
                local which = Columns({ "Text" })
                page.resourceTextSelect = ui.Select(which[1], 220, function() return M:ResourceTextChoices(Id()) end, "text")
            end)
            local place = Columns({ "Size", "Offset X", "Offset Y" })
            page.resourceTextSizeSlider = ui.Slider(place[1], "textSize")
            ui.Slider(place[2], "textX", "px"); ui.Slider(place[3], "textY", "px")
            -- In Dark mode the text takes Dark Text Color (Look tab).
            When(function() return not Dark() end, function()
                local color = Columns({ "Text Color" })
                ui.Color(color[1], "textColor")
            end)
        end)
        page:Group(L["Font"])
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), ui.owner); ui.Refresh(fontRefresh)
        page.resourceFontToggles = ui.Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" }, { "Slug Text", "slug" } })
    end)

    ui.Tab("Visibility", function()
        page:Group(L["Visibility"])
        local show = Columns({ "Show" })
        page.resourceVisibilitySelect = ui.Select(show[1], 240, function() return M.resourceChoices.visibility end, "visibility")
        local opacity = Columns({ "Opacity", "Faded Opacity" })
        page.resourceOpacitySlider = ui.Slider(opacity[1], "opacity", "%")
        ui.Slider(opacity[2], "fadeOpacity", "%")
    end)
end

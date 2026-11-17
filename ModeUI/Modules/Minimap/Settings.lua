local _, addon = ...
local M, W, L = addon.Minimap, addon.ConfigWidgets, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. The
-- layout is the owner's approved design (November 14, 2026): four tabs
-- pinned above the cards, two controls per line, no description text.
--   Shape     Minimap (Size, Wider Than Tall By); Border (Map Border,
--             Button Border: Thin or Mode; Border Color: the edges' rim;
--             Border Style and Border Metal)
--   Text      Zone and Clock (Text Layout, Zone Color, Clock, Coordinates,
--             Clock Format, Text Size)
--   Buttons   Blizzard Buttons (a switch and a corner each); Addon Buttons
--             (Show, Match Minimap Width, Button Size, Spacing)
--   Behavior  Zoom (Mouse Wheel Zoom, Zoom Out After); Visibility (Combat
--             Opacity, Opacity)
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local UI = self.SettingsUI
    local function Columns(titles)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized)
    end
    local function Slider(host, key, suffix)
        local r = M.ranges[key]
        page.refreshers[#page.refreshers + 1] = W.Slider(host, r[1], r[2], r[3], function() return M.db[key] end,
            function(value) M:SetOption(key, math.floor(value / r[3] + 0.5) * r[3]) end, suffix, true)
        return host.slider
    end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = function() return M.db[entry[2]] end,
                set = function(value) M:SetOption(entry[2], value) end }
        end
        return page:ToggleGrid(items, { maxColumns = 2, minimumCellWidth = 180 })
    end

    page:Section(L["Shape"], nil, false)
    page:Group(L["Minimap"])
    local shape = Columns({ "Size", "Wider Than Tall By" })
    page.sizeSlider = Slider(shape[1], "size", "px")
    page.differenceButtons = UI.Segments(page, shape[2], "difference", 60)
    page:Group(L["Border"])
    local border = Columns({ "Map Border", "Button Border" })
    page.borderButtons = UI.Segments(page, border[1], "border", 80)
    page.buttonBorderButtons = UI.Segments(page, border[2], "buttonBorder", 80)
    page.swatches = UI.Swatches(page, Columns({ "Border Color" })[1])
    -- Every edge's style and metal (docs/DESIGN_LANGUAGE.md, "Choosing a border").
    page.borderStyle, page.borderMetal = W.BorderPickers(page,
        { get = function() return M.db.edgeStyle end, set = function(value) M:SetOption("edgeStyle", value) end },
        { get = function() return M.db.edgeMetal end, set = function(value) M:SetOption("edgeMetal", value) end })

    page:Section(L["Text"], nil, false)
    page:Group(L["Zone and Clock"])
    local layout = Columns({ "Text Layout", "Zone Color" })
    page.textLayoutButtons = UI.Segments(page, layout[1], "textLayout", 64)
    page.zoneColorButtons = UI.Segments(page, layout[2], "zoneColor", 90)
    page.textToggles = Toggles({ { "Clock", "clock" }, { "Coordinates", "coords" } })
    local clock = Columns({ "Clock Format", "Text Size" })
    page.clockFormatButtons = UI.Segments(page, clock[1], "clockFormat", 80)
    page.textSizeSlider = Slider(clock[2], "textSize")

    page:Section(L["Buttons"], nil, false)
    page:Group(L["Blizzard Buttons"])
    page.buttonRows = {}
    for _, name in ipairs(self.BUTTONS) do page.buttonRows[name] = UI.ButtonRow(page, name) end
    page:Group(L["Addon Buttons"])
    local show = Columns({ "Show", "Match Minimap Width" })
    page.addonButtonsButtons = UI.Segments(page, show[1], "addonButtons", 64)
    page.matchWidthToggle = UI.Switch(page, show[2], "matchWidth")
    local cells = Columns({ "Button Size", "Spacing" })
    page.buttonSizeSlider = Slider(cells[1], "buttonSize", "px")
    page.buttonSpacingSlider = Slider(cells[2], "buttonSpacing", "px")

    page:Section(L["Behavior"], nil, false)
    page:Group(L["Zoom"])
    local zoom = Columns({ "Mouse Wheel Zoom", "Zoom Out After" })
    page.wheelZoomToggle = UI.Switch(page, zoom[1], "wheelZoom")
    page.zoomResetButtons = UI.Segments(page, zoom[2], "zoomReset", 56)
    page:Group(L["Visibility"])
    local visibility = Columns({ "Combat Opacity", "Opacity" })
    page.combatOpacitySlider = Slider(visibility[1], "combatOpacity", "%")
    page.opacitySlider = Slider(visibility[2], "opacity", "%")

    W.PinnedSectionTabs(page)
    page:Finish(); return page
end

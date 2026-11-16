local _, addon = ...
local M, W, L = addon.Windows, addon.ConfigWidgets, addon.L
if not M then return end

-- The Windows page's Character tab: the window's style, its stats display
-- (which stats, where, how big), rarity borders and enchant text. `H` holds
-- the page helpers from Settings.lua.
local ANCHOR_LABELS = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", CENTER = "Center",
    RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }
local NUDGES = { { "Left", -1, 0 }, { "Up", 0, 1 }, { "Down", 0, -1 }, { "Right", 1, 0 } }

function M:CreateCharacterSettings(page, H)
    page:Group(L["Character Window"])
    page.characterStylePills = H.Pills("Style", { { id = true, label = "ModeUI" }, { id = false, label = "Blizzard" } },
        function() return M.db.windows.character end, function(value) M:SetWindow("character", value) end, 120)

    page:Group(L["Stats Display"])
    page.statsToggles = H.Toggles({ { "Show Stats", "charStats" }, { "Stats Background", "charStatsBackground" } }, 2)
    H.When(function() return M.db.charStats end, function()
        local items = {}
        for _, stat in ipairs(M.STATS) do
            local id = stat.id
            items[#items + 1] = { L[stat.label], id, get = function() return M.db.charStatList[id] == true end,
                set = function(value) M:SetStat(id, value) end }
        end
        page.statToggles = H.Toggles(items, 3)
        local labels = setmetatable({}, { __index = function(_, key) return L[ANCHOR_LABELS[key] or key] end })
        local buttons, refresh = W.AnchorPicker(page:Row(L["Stats Anchor"], W.ANCHOR_PICKER_HEIGHT + 16),
            function() return M.db.charStatsAnchor end, function(value) M:SetOption("charStatsAnchor", value); page:Refresh() end,
            labels, { center = true })
        H.Refresh(refresh); page.statsAnchorButtons = buttons
        local offset = H.Columns({ "Offset X", "Offset Y" })
        page.statsXSlider = H.Slider(offset[1], "charStatsX", "px")
        page.statsYSlider = H.Slider(offset[2], "charStatsY", "px")
        -- Nudge: one pixel at a time.
        local nudge = page:Row(L["Nudge"], 48)
        page.nudgeButtons = {}
        local x = 0
        for _, step in ipairs(NUDGES) do
            local button = W.Button(nudge, L[step[1]], 64, 28, "secondary")
            button:SetPoint("LEFT", x, 0)
            button:SetScript("OnClick", function()
                local r = M.ranges.charStatsX
                M:SetOption("charStatsX", math.max(r[1], math.min(r[2], M.db.charStatsX + step[2])))
                M:SetOption("charStatsY", math.max(r[1], math.min(r[2], M.db.charStatsY + step[3])))
                page:Refresh()
            end)
            page.nudgeButtons[step[1]] = button
            x = x + 68
        end
        local size = H.Columns({ "Stats Text Size" })
        page.statsSizeSlider = H.Slider(size[1], "charStatsSize")
        -- Stat Colors: a row for each stat shown (Main Stat uses its attribute's).
        page:Group(L["Stat Colors"])
        local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return M.db.charStatColors[key] end }) } }
        function owner.CanConfigure() return true end
        function owner.SetAppearance(_, key, value) return M:SetStatColor(key, value) end
        local attributes = { strength = true, agility = true, intellect = true }
        page.statColorRows = {}
        for _, stat in ipairs(M.STATS) do
            local id = stat.id
            if M.STAT_COLORS[id] then
                H.When(function() return M.db.charStatList[id] == true or (attributes[id] and M.db.charStatList.mainStat == true) end, function()
                    local host = H.Columns({ stat.label })
                    page.statColorRows[id] = W.ColorRow(page, owner, L[stat.label], id, nil, host[1])
                end)
            end
        end
    end)

    page:Group(L["Rarity Borders"])
    page.borderToggles = H.Toggles({ { "Rarity Borders", "charBorders" } }, 2)
    H.When(function() return M.db.charBorders end, function()
        local size = H.Columns({ "Border Size" })
        page.charBorderSlider = H.Slider(size[1], "charBorderSize", "px")
    end)

    page:Group(L["Enchant Text"])
    page.enchantToggles = H.Toggles({ { "Enchant Text", "charEnchants" } }, 2)
    H.When(function() return M.db.charEnchants end, function()
        local size = H.Columns({ "Enchant Text Size" })
        page.enchantSizeSlider = H.Slider(size[1], "charEnchantSize")
    end)
end

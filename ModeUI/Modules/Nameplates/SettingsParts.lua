local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The settings page's General cards for the parts that join a stack
-- (Stacks.lua): combo points, the indicators, the raid marker and the
-- soft-target icon. Called from CreateConfigPage (Settings.lua) with its
-- helpers in `ui`, so they share its rows, refreshers and jump targets.
function M:BuildPartCards(page, ui)
    local Card, Note, Refresh, When, Anchor, Columns = ui.Card, ui.Note, ui.Refresh, ui.When, ui.Anchor, ui.Columns
    local Slider, SliderIn, Pills, Toggles, Mark, Set, db = ui.Slider, ui.SliderIn, ui.Pills, ui.Toggles, ui.Mark, ui.Set, ui.db
    -- Combo points live on your target, so they show on its plate.
    Card("General", "Combo Points", nil, function()
        page.comboNote = Note("", 32)
        Refresh(function()
            local spec, class = addon.Domain.ClassResource.Spec(), addon.Domain.ClassResource.ClassName()
            if spec then page.comboNote:SetText(class .. ": " .. spec.name .. (spec.when and (", " .. spec.when) or "") .. ", on your target's plate.")
            else page.comboNote:SetText((class ~= "" and class or "Your class") .. " has no combo points on WoW Forever, so nothing shows. Rogues, and Druids in Cat Form, have them.") end
        end)
        When(function() return db().showCombo end, function()
            page.comboAnchorButtons = Anchor("Anchor", function() return db().comboAnchor end, Set("comboAnchor"), true); Mark("combo")
            page.comboToggles = Toggles({ { "Move Up While Not Casting", "comboFollowCast" } })
            local place = Columns({ "Point Size", "Spacing" })
            page.comboSizeSlider = Slider(place[1], "comboSize", "px"); Slider(place[2], "comboSpacing", "px")
            local offset = Columns({ "Offset X", "Offset Y" })
            Slider(offset[1], "comboX", "px"); Slider(offset[2], "comboY", "px")
        end)
    end)
    Card("General", "Indicators", nil, function()
        local parts = {}
        for _, part in ipairs(M.indicatorParts) do parts[#parts + 1] = { id = part, label = M.indicatorPartLabels[part] } end
        page.indicatorPartButtons = Pills("Indicator", parts, ui.IndicatorPart, page.SetIndicatorPart, 112)
        Mark("indicator")
        local function Key(suffix) return ui.IndicatorPart() .. suffix end
        local function SetPart(suffix) return function(value) M:SetOption(ui.Kind(), Key(suffix), value) end end
        page.indicatorPartToggles = Toggles({ { "Show This Indicator", "part",
            get = function() return db()[M.indicatorShowKeys[ui.IndicatorPart()]] end,
            set = function(value) M:SetOption(ui.Kind(), M.indicatorShowKeys[ui.IndicatorPart()], value) end },
            { "Inside the Bar", "inside", get = function() return db()[Key("Inside")] end, set = SetPart("Inside") } })
        page.indicatorAnchorButtons = Anchor("Anchor", function() return db()[Key("Anchor")] end, SetPart("Anchor"), true)
        -- Icons and the level text have different size ranges.
        When(function() return ui.IndicatorPart() ~= "level" end, function()
            local place = Columns({ "Icon Size", "Offset X", "Offset Y" })
            SliderIn(place[1], M.ranges.questSize, function() return db()[Key("Size")] end, SetPart("Size"), "px")
            SliderIn(place[2], M.ranges.questX, function() return db()[Key("X")] end, SetPart("X"), "px")
            SliderIn(place[3], M.ranges.questY, function() return db()[Key("Y")] end, SetPart("Y"), "px")
        end)
        When(function() return ui.IndicatorPart() == "level" end, function()
            local place = Columns({ "Size", "Offset X", "Offset Y" })
            SliderIn(place[1], M.ranges.levelSize, function() return db().levelSize end, Set("levelSize"))
            SliderIn(place[2], M.ranges.levelX, function() return db().levelX end, Set("levelX"), "px")
            SliderIn(place[3], M.ranges.levelY, function() return db().levelY end, Set("levelY"), "px")
        end)
        Note("Parts on one anchor line up in a row and close up when one is missing. Inside the Bar puts a Left or Right indicator inside the bar; inside on the left the level comes first. Quest shows on creatures that are part of one of your quests; level uses the game's difficulty color.", 64)
    end)
    Card("General", "Raid Marker", nil, function()
        page.raidAnchorButtons = Anchor("Anchor", function() return db().raidAnchor end, Set("raidAnchor"), true); Mark("markers")
        page.raidToggles = Toggles({ { "Inside the Bar", "raidInside" } })
        local raid = Columns({ "Size", "Offset X", "Offset Y" })
        Slider(raid[1], "raidSize", "px"); Slider(raid[2], "raidX", "px"); Slider(raid[3], "raidY", "px")
    end)
    Card("General", "Soft Target Icon", nil, function()
        local soft = Columns({ "Size", "Offset X", "Offset Y" }); Mark("softTarget")
        Slider(soft[1], "softTargetSize", "px"); Slider(soft[2], "softTargetX", "px"); Slider(soft[3], "softTargetY", "px")
        page.softTargetToggles = Toggles({ { "Show Combat Icons", "softTargetCombat" }, { "Hide Blizzard's Combat Icon", "hideBlizzard",
            get = function() return M.db.hideBlizzardCombatIcon end, set = function(value) M:SetHideBlizzardCombatIcon(value) end } })
        Note("The cursor the game shows over your soft target, above the plate: a bag or gear on what you can loot or use. Show Combat Icons adds the sword on your soft enemy. Hide Blizzard's Combat Icon turns the game's enemy and friend icons off (its Accessibility setting) and puts them back when turned off.", 64)
    end)
end

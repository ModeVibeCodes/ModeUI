local _, addon = ...
local M, W, L = addon.PartyFrames, addon.ConfigWidgets, addon.L
if not M then return end

-- The Power Bars and Resources tab: who shows a power bar (everyone, healers,
-- mana users, healers with mana, or no one), where it sits and how big it is
-- (below the health, or inset on it with its own width, alignment and
-- offset), how it looks (color, textures, opacities, fill) and its text. The
-- preview shows a healer with mana while this tab is open, so the bar is
-- there to see whichever choice is picked.

function M:BuildPowerTab(page, c)
    local function Set(key) return c.Set(key) end
    local function Shown() return M.db.powerShown ~= "none" end
    page:Section(L["Power Bars and Resources"], nil, false)

    page:Group(L["Show Power"])
    page.powerSelect = c.Select(page:Row(L["Power Bar For"], 48), 200, M.choices.powerShown, "powerShown"); c.Mark("power")
    c.Note("Everyone shows every member's power. Healers shows only healers'. Mana Users shows it only where the power is mana. Healer Mana shows it only on healers with mana and hides every other resource. No One hides power bars.", 48)

    c.When(Shown, function()
        page:Group(L["Size and Place"])
        page.powerStylePills = c.Pills("Style", M.choices.powerStyle, function() return M.db.powerStyle end, Set("powerStyle"), 120)
        local size = c.Columns({ "Power Height" })
        page.powerHeightSlider = c.Slider(size[1], "powerHeight", "px")
        c.When(function() return M.db.powerStyle == "inset" end, function()
            local inset = c.Columns({ "Power Width" })
            page.powerWidthSlider = c.Slider(inset[1], "powerWidth", "%")
            page.powerAlignPills = c.Pills("Alignment", M.choices.powerAlign, function() return M.db.powerAlign end, Set("powerAlign"), 80)
            local offset = c.Columns({ "Offset X", "Offset Y" })
            c.Slider(offset[1], "powerX", "px"); c.Slider(offset[2], "powerY", "px")
            page.powerNudge = c.Nudge(function() return M.db.powerX end, function() return M.db.powerY end,
                Set("powerX"), Set("powerY"), M.ranges.powerX)
        end)
        c.Note("Below Health takes a row under the health bar, Power Height tall. Inset sits on the health bar in a border of its own, Power Width of the frame wide.", 32)

        page:Group(L["Look"])
        local color = c.Columns({ "Power Color", "Custom Color" })
        page.powerColorSelect = c.Select(color[1], 200, M.choices.powerColorMode, "powerColorMode")
        c.Color(color[2], "powerColor", function() return M.db.powerColorMode == "custom" end)
        local textures = c.Columns({ "Foreground", "Background" })
        c.Texture(textures[1], "powerForegroundTexture", function() return M.TextureChoices(true) end)
        c.Texture(textures[2], "powerBackgroundTexture", function() return M.TextureChoices(false) end)
        local fade = c.Columns({ "Bar Opacity", "Background Opacity" })
        page.powerOpacitySlider = c.Slider(fade[1], "powerOpacity", "%")
        page.powerBackgroundSlider = c.Slider(fade[2], "powerBackgroundOpacity", "%")
        page.powerFillPills = c.Pills("Fill", M.choices.fillDirection, function() return M.db.powerFillDirection end,
            Set("powerFillDirection"), 120)

        page:Group(L["Power Text"])
        page.powerTextToggles = c.Toggles({ { "Show Power Text", "powerTextShow" } })
        c.When(function() return M.db.powerTextShow end, function()
            page.powerTextPills = c.Pills("Shows", M.choices.powerText, function() return M.db.powerText end, Set("powerText"), 120)
            page.powerTextAlignPills = c.Pills("Alignment", M.choices.powerAlign, function() return M.db.powerTextAlign end,
                Set("powerTextAlign"), 80)
            local text = c.Columns({ "Text Size", "Offset X", "Offset Y" })
            c.Slider(text[1], "powerTextSize"); c.Slider(text[2], "powerTextX", "px"); c.Slider(text[3], "powerTextY", "px")
            page.powerTextNudge = c.Nudge(function() return M.db.powerTextX end, function() return M.db.powerTextY end,
                Set("powerTextX"), Set("powerTextY"), M.ranges.powerTextX)
            c.Note("The text uses the font and text color on the Text and Icons tab.", 32)
        end)
    end)
end

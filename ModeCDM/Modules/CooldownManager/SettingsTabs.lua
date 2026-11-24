local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The bar page's Spells & Glows and Show sections (Settings.lua builds the
-- page and its helpers in `ui`).

-- Spells & Glows: the spells on this bar as a list (SpellList.lua), then
-- the look a glow starts with when a spell's menu switches it on (the
-- Starting Glow Look, from the Bar Style unless the bar has its own).
function M:BuildSpellsSection(ui)
    local page, db = ui.page, ui.db
    local STYLE_WIDTHS = { mode = 92, border = 72, pixel = 64, blizzard = 76, gcd = 56 }
    local function GlowGroup(kind, note, extra)
        page:Group(L[M.glowLabels[kind]])
        local choices = {}
        for _, item in ipairs(M.glowStyles) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = STYLE_WIDTHS[item.id] } end
        local buttons, refresh = W.Exclusive(page:Row(L["Style"], 48), choices, function() return db()[kind .. "Glow"] end, ui.Set(kind .. "Glow"))
        ui.Refresh(refresh); page[kind .. "Pills"] = buttons
        if kind == "proc" or kind == "buff" then ui.Mark(kind == "proc" and "glows" or "buffGlows") end
        local color = ui.Columns({ "Glow Color" })
        ui.Color(color[1], kind .. "Color")
        ui.When(function() local style = db()[kind .. "Glow"]; return style == "mode" or style == "border" end, function()
            page[kind .. "Toggles"] = ui.Toggles({ { "Pulse", kind .. "Pulse" } })
        end)
        if extra then extra() end
        W.Note(ui.Note(note, 40))
    end
    ui.Tab("Spells & Glows", function()
        page:Group(L["Spells"])
        local status = W.Label(page:Row(L["This Bar"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        ui.Mark("spells")
        ui.Refresh(function()
            local hidden = M:HiddenCount(ui.Viewer())
            status:SetText(hidden > 0 and string.format(L["%d spells hidden here."], hidden) or L["Every tracked spell shows."])
        end)
        page.spellsStatus = status
        M:BuildSpellList(ui)
        W.Tip(ui.Note("Click a spell in the list or the preview for its menu: glows, its own text, order, or to take it off the bar. Drag in the preview to move one.", 48))
        ui.More("spells", function()
            page.resetSpellsButton = ui.Button("Reset All Spells", 160, function() M:ResetSpells(ui.Viewer()) end)
            ui.Refresh(function() page.resetSpellsButton:SetEnabled(next(M.db[ui.Viewer()].spells) ~= nil) end)
        end)
        ui.When(ui.Bars, function() W.Tip(ui.Note("Tracked Bars have no glows; Tracked Buffs and your own bars do.", 32)) end)
        ui.When(ui.Icons, function()
            page:Group(L["Starting Glow Look"]); ui.Chip("glows")
            ui.Summary("glows", function()
                local style = db()
                local kind = ui.Cooldowns() and "proc" or "buff"
                local label = ""
                for _, item in ipairs(M.glowStyles) do if item.id == style[kind .. "Glow"] then label = L[item.label] end end
                return string.format(L["Bar Style: %s %s. A glow switched on in a spell's menu starts with this look."], L[M.glowLabels[kind]], label)
            end)
        end)
        ui.When(ui.Icons, function()
            ui.Styled("glows", function()
                ui.When(ui.Cooldowns, function()
                    GlowGroup("proc", "A proc is the game lighting up a spell you should use now (Blizzard's own animation hides while ModeUI is on).")
                    GlowGroup("active", "While the spell's effect is up.")
                    GlowGroup("ready", "Lights an icon when a cooldown longer than the global cooldown ends.", function()
                        ui.More("ready", function()
                            page.readyModePills = ui.Pills("When", M.choices.readyMode, function() return db().readyMode end, ui.Set("readyMode"), 110)
                            ui.When(function() return db().readyMode == "flash" end, function()
                                local time = ui.Columns({ "Glow Time" })
                                page.readySlider = ui.Slider(time[1], "readyDuration", "s")
                            end)
                        end)
                    end)
                end)
                ui.When(function() return not ui.Cooldowns() end, function()
                    GlowGroup("buff", "Lights a tracked buff's icon while the buff is up.")
                end)
                page:Group(L["Pixel Glow"])
                local pixel = ui.Columns({ "Lines", "Thickness" })
                page.glowLinesSlider = ui.Slider(pixel[1], "glowLines")
                page.glowThicknessSlider = ui.Slider(pixel[2], "glowThickness", "px")
            end)
        end)
    end)
end

-- Show: when the bar shows and how strongly; Reset to Defaults.
function M:BuildShowSection(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Show", function()
        page:Group(L["When to Show"])
        local show = ui.Columns({ "Show When" })
        page.visibilitySelect = ui.SelectIn(show[1], 260, function() return M.choices.visibility end,
            function() return db().visibility end, ui.Set("visibility")); ui.Mark("visibility")
        M:BuildShowRules(ui)
        local opacity = ui.Columns({ "Opacity" })
        page.opacitySlider = ui.Slider(opacity[1], "opacity", "%")
        ui.When(function() return db().visibility == "mouseover" or db().dim end, function()
            local faded = ui.Columns({ "Faded Opacity" })
            page.fadeSlider = ui.Slider(faded[1], "fadeOpacity", "%")
        end)
        ui.More("show", function()
            page.resetButton = ui.Button("Reset to Defaults", 150, function() M:ResetViewer(ui.Viewer()) end)
        end)
    end)
end

-- The show rules under Show When (Visibility.lua).
function M:BuildShowRules(ui)
    ui.page.showRuleToggles = ui.Toggles({ { "Hide While Mounted", "hideMounted" }, { "Hide in a Vehicle", "hideVehicle" },
        { "Only in a Group", "onlyInGroup" }, { "Only in an Instance", "onlyInInstance" }, { "Dim Instead of Hide", "dim" } })
end

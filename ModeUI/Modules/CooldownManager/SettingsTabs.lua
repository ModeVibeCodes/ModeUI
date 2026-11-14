local _, addon = ...
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Text, Glows, Spells, Visibility and Copy & Apply tabs, built by
-- CreateConfigPage (Settings.lua) with its helpers in `ui`.

-- Text: pick a text, then its place, size and color; the font is shared.
function M:BuildTextTab(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Text", function()
        ui.Note("The bar's text look. Click a spell in the preview, then a text's > in its menu, to give that spell its own font, size, color, outline, shadow and place.", 40)
        page:Group(L["Text"])
        local function Parts(list)
            local choices = {}
            for _, part in ipairs(list) do choices[#choices + 1] = { id = part, label = M.textPartLabels[part] } end
            return choices
        end
        ui.When(ui.Icons, function() page.iconPartButtons = ui.Pills("Text", Parts(M.iconParts), ui.Part, page.SetTextPart, 104); ui.Mark("text") end)
        ui.When(ui.Bars, function() page.barPartButtons = ui.Pills("Text", Parts(M.barParts), ui.Part, page.SetTextPart, 96) end)
        page.textToggles = ui.Toggles({ { "Show This Text", "part", get = function() return db()[ui.PartKey("Show")] end, set = ui.SetPart("Show") } })
        local labels = setmetatable({}, { __index = function(_, key) return L[M.anchorLabels[key] or key] end })
        local anchorButtons, anchorRefresh = W.AnchorPicker(page:Row(L["Anchor"], W.ANCHOR_PICKER_HEIGHT + 16),
            function() return db()[ui.PartKey("Anchor")] end, ui.SetPart("Anchor"), labels, { center = true })
        ui.Refresh(anchorRefresh); page.textAnchorButtons = anchorButtons
        local place = ui.Columns({ "Size", "Offset X", "Offset Y" })
        local function PartSlider(host, suffix, unit)
            return ui.SliderIn(host, M.ranges["cooldown" .. suffix], function() return db()[ui.PartKey(suffix)] end, ui.SetPart(suffix), unit)
        end
        page.textSizeSlider = PartSlider(place[1], "Size")
        PartSlider(place[2], "X", "px"); PartSlider(place[3], "Y", "px")
        local color = ui.Columns({ "Color" })
        ui.Color(color[1], "partColor")
        ui.When(function() return ui.Part() == "cooldown" end, function()
            ui.Note("Cooldown numbers show while Blizzard's Show Timer option for the viewer is on.", 32)
        end)
        ui.When(function() return ui.Part() == "duration" end, function()
            ui.Note("The time left shows while Blizzard's Show Timer option for the viewer is on; the name follows its Bar Content.", 32)
        end)
        page:Group(L["Font"])
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), ui.owner); ui.Refresh(fontRefresh)
        page.fontToggles = ui.Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" }, { "Slug Text", "slug" } })
    end)
end

-- Glow Defaults: every glow starts off on every spell; a spell's menu in
-- the preview switches one on and its popout sets its own look. These are
-- the looks a glow starts with when it's switched on.
function M:BuildGlowTab(ui)
    local page, db = ui.page, ui.db
    local STYLE_WIDTHS = { mode = 92, border = 72, pixel = 64, blizzard = 76, gcd = 56 }
    local styles = {}
    for _, item in ipairs(M.glowStyles) do styles[#styles + 1] = { id = item.id, label = item.label } end
    local function GlowGroup(kind, note, extra)
        page:Group(L[M.glowLabels[kind]])
        local choices = {}
        for _, item in ipairs(styles) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = STYLE_WIDTHS[item.id] } end
        local buttons, refresh = W.Exclusive(page:Row(L["Style"], 48), choices, function() return db()[kind .. "Glow"] end, ui.Set(kind .. "Glow"))
        ui.Refresh(refresh); page[kind .. "Pills"] = buttons
        if kind == "proc" or kind == "buff" then ui.Mark(kind == "proc" and "glows" or "buffGlows") end
        local color = ui.Columns({ "Glow Color" })
        ui.Color(color[1], kind .. "Color")
        ui.When(function() local style = db()[kind .. "Glow"]; return style == "mode" or style == "border" end, function()
            page[kind .. "Toggles"] = ui.Toggles({ { "Pulse", kind .. "Pulse" } })
        end)
        if extra then extra() end
        ui.Note(note, 40)
    end
    ui.Tab("Glows", function()
        ui.When(ui.Bars, function() ui.Note("Tracked Bars have no glows; Tracked Buffs and your own bars do.", 32) end)
        ui.When(ui.Icons, function()
            ui.Note("Glows start off on every spell. Click a spell in the preview to switch its glows on; each one's > sets its own look there. A glow switched on starts with the look below.", 48)
        end)
        ui.When(function() return ui.Icons() and ui.Cooldowns() end, function()
            GlowGroup("proc", "A proc is the game lighting up a spell you should use now (Blizzard's own animation hides while ModeUI is on).")
            GlowGroup("active", "While the spell's effect is up.")
            GlowGroup("ready", "Flash lights an icon for Glow Time when a cooldown longer than the global cooldown ends; While Ready keeps it lit for as long as the spell is ready.", function()
                page.readyModePills = ui.Pills("When", M.choices.readyMode, function() return db().readyMode end, ui.Set("readyMode"), 110)
                ui.When(function() return db().readyMode == "flash" end, function()
                    local time = ui.Columns({ "Glow Time" })
                    page.readySlider = ui.Slider(time[1], "readyDuration", "s")
                end)
            end)
            ui.Note("One glow shows at a time: proc, then active, then off cooldown.", 32)
        end)
        ui.When(function() return ui.Icons() and not ui.Cooldowns() end, function()
            GlowGroup("buff", "Lights a tracked buff's icon while the buff is up.")
        end)
        ui.When(ui.Icons, function()
            page:Group(L["Pixel Glow"])
            local pixel = ui.Columns({ "Lines", "Thickness" })
            page.glowLinesSlider = ui.Slider(pixel[1], "glowLines")
            page.glowThicknessSlider = ui.Slider(pixel[2], "glowThickness", "px")
            ui.Note("Pixel draws lines that march around the icon; GCD and Blizzard are the game's own animated art, in the glow's color.", 40)
        end)
    end)
end

-- Spells: each spell's own switches are set from the preview.
function M:BuildSpellsTab(ui)
    local page = ui.page
    ui.Tab("Spells", function()
        page:Group(L["Spells"])
        local status = W.Label(page:Row(L["This Bar"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        ui.Mark("spells")
        ui.Refresh(function()
            local hidden = M:HiddenCount(ui.Viewer())
            status:SetText(hidden > 0 and string.format(L["%d spells hidden here."], hidden) or L["Every tracked spell shows."])
        end)
        page.spellsStatus = status
        ui.Note("Click a spell in the preview to hide it from this bar (the others close up) or switch its glows off. Hidden spells show faded in the preview. Copy, Paste and Apply to Bar move one spell's switches to others. On a custom bar, Essential and Utility, the + slot adds spells and a spell's menu orders it or takes it off the bar (a viewer's own spell hides there).", 64)
        local reset = page:Row("", 40)
        reset.rowLabel:Hide(); reset:ClearAllPoints(); reset:SetAllPoints(reset.row)
        page.resetSpellsButton = W.Button(reset, L["Reset All Spells"], 160, 30, "secondary")
        page.resetSpellsButton:SetPoint("LEFT")
        page.resetSpellsButton:SetScript("OnClick", function() M:ResetSpells(ui.Viewer()) end)
        ui.Refresh(function() page.resetSpellsButton:SetEnabled(next(M.db[ui.Viewer()].spells) ~= nil) end)
        ui.Note("Puts every spell on this bar back to showing, with its glows following the bar.", 32)
    end)
end

function M:BuildVisibilityTab(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Visibility", function()
        page:Group(L["When to Show"])
        local show = ui.Columns({ "Show" })
        page.visibilitySelect = ui.SelectIn(show[1], 260, function() return M.choices.visibility end,
            function() return db().visibility end, ui.Set("visibility")); ui.Mark("visibility")
        page:Group(L["Opacity"])
        local opacity = ui.Columns({ "Opacity" })
        page.opacitySlider = ui.Slider(opacity[1], "opacity", "%")
        ui.When(function() return db().visibility == "mouseover" end, function()
            local faded = ui.Columns({ "Faded Opacity" })
            page.fadeSlider = ui.Slider(faded[1], "fadeOpacity", "%")
        end)
        ui.Note("Mouseover keeps the bar at Faded Opacity until the mouse is over it. Every bar that's on shows in Edit Mode. Blizzard's own Visibility and Opacity for a viewer apply first (custom bars follow the viewer their spells come from): set its Visibility to Always to let these decide.", 48)
    end)
end

-- Copy & Apply: the bar being edited is the source; tick bars, then apply.
function M:BuildCopyTab(ui)
    local page = ui.page
    ui.Tab("Copy & Apply", function()
        page:Group(L["Copy From"])
        local from = ui.Columns({ "Bar" })
        page.applySource = ui.SelectIn(from[1], 240, ui.ViewerChoices, ui.Viewer, page.SetEditing)
        ui.Note("Its borders, background, cooldown look, text, glows, opacity and bar look are copied; each bar keeps its own size, lines, spells and show settings.", 32)
        page:Group(L["Apply To"])
        local targets = {}
        page.applyTargets = targets
        local function Chosen()
            local count = 0
            for viewer in pairs(targets) do if viewer ~= ui.Viewer() then count = count + 1 end end
            return count
        end
        local function TargetChoices()
            local list = {}
            for _, viewer in ipairs(M:BarIds()) do
                local source = viewer == ui.Viewer()
                list[#list + 1] = { id = viewer, label = source and (M:Label(viewer) .. "  |cff8c8c8c" .. L["Source"] .. "|r")
                    or ui.ViewerLabel(viewer), selected = not source and targets[viewer] == true, disabled = source }
            end
            return list
        end
        local function TargetLabel()
            local count = Chosen()
            if count == 0 then return nil, L["Choose bars"] end
            return nil, string.format(L["%d bars selected"], count)
        end
        local to = ui.Columns({ "Bars" })
        page.applyTargetSelect = ui.SelectIn(to[1], 240, TargetChoices, TargetLabel, function(viewer)
            if viewer ~= ui.Viewer() then targets[viewer] = not targets[viewer] or nil end
        end, { multi = true })
        local apply = page:Row("", 40)
        apply.rowLabel:Hide(); apply:ClearAllPoints(); apply:SetAllPoints(apply.row)
        page.applyButton = W.Button(apply, L["Apply to Selected"], 150, 30, "secondary")
        page.applyButton:SetPoint("LEFT")
        page.applyAllButton = W.Button(apply, L["Apply to All Bars"], 160, 30, "secondary")
        page.applyAllButton:SetPoint("LEFT", page.applyButton, "RIGHT", 8, 0)
        local result = W.Label(apply, "", nil, 0, 0, 160, T.muted)
        result:ClearAllPoints(); result:SetPoint("LEFT", page.applyAllButton, "RIGHT", 10, 0)
        page.applyResult = result
        local function Report(ok, count)
            result:SetText(ok and string.format(L["Applied to %d bars."], count or 0) or L["Choose bars first."])
        end
        page.applyButton:SetScript("OnClick", function()
            if Chosen() == 0 then Report(false); return end
            Report(M:CopyStyleTo(ui.Viewer(), targets))
        end)
        page.applyAllButton:SetScript("OnClick", function() Report(M:CopyStyleToAll(ui.Viewer())) end)
        page:Group(L["Reset"])
        local reset = page:Row("", 40)
        reset.rowLabel:Hide(); reset:ClearAllPoints(); reset:SetAllPoints(reset.row)
        page.resetButton = W.Button(reset, L["Reset to Defaults"], 150, 30, "secondary")
        page.resetButton:SetPoint("LEFT"); page.resetButton:SetScript("OnClick", function() M:ResetViewer(ui.Viewer()) end)
        ui.Note("Puts this bar back to ModeUI's defaults; its size, lines, spells and show settings stay.", 32)
    end)
end

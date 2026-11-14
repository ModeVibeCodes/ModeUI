local _, addon = ...
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Text, Glows, Spells, Visibility and Copy & Apply tabs, built by
-- CreateConfigPage (Settings.lua) with its helpers in `ui`.

-- Text: pick a text, then its place, size and color; the font is shared.
function M:BuildTextTab(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Text", function()
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

-- Glows: how Essential and Utility icons react to procs and cooldowns.
function M:BuildGlowTab(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Glows", function()
        ui.When(function() return not ui.Cooldowns() end, function()
            ui.Note("Glows are for Essential and Utility cooldowns; buffs have none.", 32)
        end)
        ui.When(ui.Cooldowns, function()
            page:Group(L["Proc Glow"])
            page.procPills = ui.Pills("Style", M.choices.procGlow, function() return db().procGlow end, ui.Set("procGlow"), 96); ui.Mark("glows")
            ui.When(function() return db().procGlow == "mode" or db().procGlow == "border" end, function()
                local proc = ui.Columns({ "Proc Color" })
                ui.Color(proc[1], "procColor")
                page.procToggles = ui.Toggles({ { "Pulse", "procPulse" } })
            end)
            ui.Note("A proc is the game lighting up a spell you should use now. Blizzard keeps the game's own animation; None shows nothing.", 32)
            page:Group(L["Cooldown Ready"])
            page.readyToggles = ui.Toggles({ { "Glow When Ready", "readyGlow" } })
            ui.When(function() return db().readyGlow end, function()
                page.readyPills = ui.Pills("Style", M.choices.readyStyle, function() return db().readyStyle end, ui.Set("readyStyle"))
                local ready = ui.Columns({ "Glow Color", "Glow Time" })
                ui.Color(ready[1], "readyColor")
                page.readySlider = ui.Slider(ready[2], "readyDuration", "s")
            end)
            ui.Note("Glow When Ready lights an icon for Glow Time when a cooldown longer than the global cooldown ends. Click a spell in the preview to switch its glows on or off.", 40)
        end)
    end)
end

-- Spells: each spell's own switches are set from the preview.
function M:BuildSpellsTab(ui)
    local page = ui.page
    ui.Tab("Spells", function()
        page:Group(L["Spells"])
        local status = W.Label(page:Row(L["This Viewer"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        ui.Mark("spells")
        ui.Refresh(function()
            local hidden = M:HiddenCount(ui.Viewer())
            status:SetText(hidden > 0 and string.format(L["%d spells hidden here."], hidden) or L["Every tracked spell shows."])
        end)
        page.spellsStatus = status
        ui.Note("Click a spell in the preview to hide it from this viewer (the others close up) or, on Essential and Utility, switch its proc glow or ready glow off. Hidden spells show faded in the preview. Copy, Paste and Apply to Viewer move one spell's switches to others.", 64)
        local reset = page:Row("", 40)
        reset.rowLabel:Hide(); reset:ClearAllPoints(); reset:SetAllPoints(reset.row)
        page.resetSpellsButton = W.Button(reset, L["Reset All Spells"], 160, 30, "secondary")
        page.resetSpellsButton:SetPoint("LEFT")
        page.resetSpellsButton:SetScript("OnClick", function() M:ResetSpells(ui.Viewer()) end)
        ui.Refresh(function() page.resetSpellsButton:SetEnabled(next(M.db[ui.Viewer()].spells) ~= nil) end)
        ui.Note("Puts every spell in this viewer back to showing, with its glows following the viewer.", 32)
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
        ui.Note("Mouseover keeps the viewer at Faded Opacity until the mouse is over it. Every viewer that's on shows in Edit Mode. Blizzard's own Visibility and Opacity for the viewer apply first: set its Visibility to Always to let these decide.", 48)
    end)
end

-- Copy & Apply: the viewer in Editing is the source; tick viewers, then apply.
function M:BuildCopyTab(ui)
    local page = ui.page
    ui.Tab("Copy & Apply", function()
        page:Group(L["Copy From"])
        local from = ui.Columns({ "Viewer" })
        page.applySource = ui.SelectIn(from[1], 240, ui.ViewerChoices, ui.Viewer, page.SetEditing)
        ui.Note("Its borders, background, cooldown look, text, glows, opacity and bar look are copied; each viewer keeps its own size, lines, spells and show settings.", 32)
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
            for _, viewer in ipairs(M.viewers) do
                local source = viewer == ui.Viewer()
                list[#list + 1] = { id = viewer, label = source and (L[M.viewerSpecs[viewer].label] .. "  |cff8c8c8c" .. L["Source"] .. "|r")
                    or ui.ViewerLabel(viewer), selected = not source and targets[viewer] == true, disabled = source }
            end
            return list
        end
        local function TargetLabel()
            local count = Chosen()
            if count == 0 then return nil, L["Choose viewers"] end
            return nil, string.format(L["%d viewers selected"], count)
        end
        local to = ui.Columns({ "Viewers" })
        page.applyTargetSelect = ui.SelectIn(to[1], 240, TargetChoices, TargetLabel, function(viewer)
            if viewer ~= ui.Viewer() then targets[viewer] = not targets[viewer] or nil end
        end, { multi = true })
        local apply = page:Row("", 40)
        apply.rowLabel:Hide(); apply:ClearAllPoints(); apply:SetAllPoints(apply.row)
        page.applyButton = W.Button(apply, L["Apply to Selected"], 150, 30, "secondary")
        page.applyButton:SetPoint("LEFT")
        page.applyAllButton = W.Button(apply, L["Apply to All Viewers"], 160, 30, "secondary")
        page.applyAllButton:SetPoint("LEFT", page.applyButton, "RIGHT", 8, 0)
        local result = W.Label(apply, "", nil, 0, 0, 160, T.muted)
        result:ClearAllPoints(); result:SetPoint("LEFT", page.applyAllButton, "RIGHT", 10, 0)
        page.applyResult = result
        local function Report(ok, count)
            result:SetText(ok and string.format(L["Applied to %d viewers."], count or 0) or L["Choose viewers first."])
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
        ui.Note("Puts the viewer in Editing back to ModeUI's defaults; its size, lines, spells and show settings stay.", 32)
    end)
end

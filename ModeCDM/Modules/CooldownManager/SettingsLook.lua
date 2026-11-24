local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The bar page's Look and Text sections (Settings.lua builds the page and
-- its helpers in `ui`). Each group follows the Bar Style or is the bar's
-- own (its chip); the controls the Bar Style sets show while it's Custom.
local function Label(list, id)
    for _, choice in ipairs(list) do if choice.id == id then return L[choice.label] end end
    return tostring(id)
end

-- Look: border, background, the cooldown on icons or the fill on Tracked
-- Bars, then Copy Look To.
function M:BuildLookSection(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Look", function()
        page:Group(L["Border"]); ui.Chip("border")
        ui.Summary("border", function()
            local style = db()
            if style.border == "none" then return L["Bar Style: no border."] end
            return string.format(L["Bar Style: %s, %s, %dpx."], Label(M.choices.edgeStyle, style.edgeStyle),
                style.edgeMetal == "default" and L["its own metal"] or Label(M.choices.edgeMetal, style.edgeMetal), style.edgeSize)
        end)
        ui.Styled("border", function()
            page.borderPills = ui.Pills("Border", M.choices.border, function() return db().border end, ui.Set("border")); ui.Mark("look")
            ui.When(function() return db().border ~= "none" end, function()
                page.borderStylePicker, page.borderMetalPicker = W.BorderPickers(page,
                    { get = function() return db().edgeStyle end, set = ui.Set("edgeStyle") },
                    { get = function() return db().edgeMetal end, set = ui.Set("edgeMetal") }, { labels = { "Border Style", "Border Color" } })
                local size = ui.Columns({ "Border Size" })
                page.borderSizeSelect = ui.SelectIn(size[1], 180, function() return M.choices.edgeSize end,
                    function() return db().edgeSize end, ui.Set("edgeSize"))
                -- Mode-Empty's flat band takes a color of its own.
                ui.When(function() return addon.Style.IsFlatStyle(db().edgeStyle) end, function()
                    local color = ui.Columns({ "Band Color" })
                    ui.Color(color[1], "edgeColor")
                end)
            end)
        end)
        page:Group(L["Background"]); ui.Chip("background")
        ui.Styled("background", function()
            local background = ui.Columns({ "Background Color", "Background Opacity" })
            ui.Color(background[1], "backgroundColor")
            page.backgroundSlider = ui.Slider(background[2], "backgroundOpacity", "%")
        end)
        ui.When(ui.Icons, function()
            page:Group(L["Cooldown"]); ui.Chip("cooldown")
            ui.When(ui.Cooldowns, function()
                page.desaturateToggles = ui.Toggles({ { "Gray on Cooldown", "desaturate" }, { "Out of Range Tint", "rangeTint" } })
            end)
            ui.When(function() return not ui.Cooldowns() end, function()
                page.debuffToggles = ui.Toggles({ { "Debuff Border", "debuffBorder" } })
            end)
            ui.Styled("cooldown", function()
                local swipe = ui.Columns({ "Swipe Color", "Swipe Opacity" })
                ui.Color(swipe[1], "swipeColor")
                page.swipeSlider = ui.Slider(swipe[2], "swipeOpacity", "%")
            end)
            ui.More("cooldown", function()
                ui.When(ui.Cooldowns, function() page.auraToggles = ui.Toggles({ { "Show Effect Time", "auraSwipe" } }) end)
                page.cooldownToggles = ui.Toggles({ { "Swipe Edge", "showEdge" }, { "Finish Sparkle", "showBling" }, { "Ready Flash", "showFlash" } })
            end)
        end)
        ui.When(ui.Bars, function()
            page:Group(L["Bar Fill"]); ui.Chip("fill")
            local color = ui.Columns({ "Bar Color" })
            page.barColorSelect = ui.SelectIn(color[1], 200, function() return M.choices.barColorMode end,
                function() return db().barColorMode end, ui.Set("barColorMode"))
            ui.When(function() return db().barColorMode == "custom" end, function()
                local custom = ui.Columns({ "Custom Color" })
                ui.Color(custom[1], "barColor")
            end)
            page.iconSidePills = ui.Pills("Icon Side", M.choices.iconSide, function() return db().iconSide end, ui.Set("iconSide"))
            page.debuffBarToggles = ui.Toggles({ { "Debuff Border", "debuffBorder" } })
            ui.Styled("fill", function()
                local textures = ui.Columns({ "Bar Texture", "Bar Background" })
                page.barTextureSelect = ui.SelectIn(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end,
                    function() return db().barTexture end, ui.Set("barTexture"))
                page.barBackgroundSelect = ui.SelectIn(textures[2], 200, function() return addon.Kit.BarTextureChoices(false) end,
                    function() return db().barBackground end, ui.Set("barBackground"))
                local opacity = ui.Columns({ "Background Opacity" })
                page.barBackgroundSlider = ui.Slider(opacity[1], "barBackgroundOpacity", "%")
                page.barToggles = ui.Toggles({ { "Spark", "showSpark" } })
            end)
        end)
        page:Group(L["Copy Look To"])
        ui.More("copy", function() M:BuildCopyRows(ui) end)
    end)
end

-- Text: pick a text, then whether it shows and its size; its place under
-- More options; its color and the font from the Bar Style.
function M:BuildTextSection(ui)
    local page, db = ui.page, ui.db
    ui.Tab("Text", function()
        page:Group(L["Text"]); ui.Chip("text")
        ui.Summary("text", function()
            local style = db()
            return string.format(L["Bar Style: %s%s; sizes follow the icon."], style.fontMedia,
                style.outline and (", " .. L["outlined"]) or "")
        end)
        local function Parts(list)
            local choices = {}
            for _, part in ipairs(list) do choices[#choices + 1] = { id = part, label = M.textPartLabels[part] } end
            return choices
        end
        ui.When(ui.Icons, function() page.iconPartButtons = ui.Pills("Text", Parts(M.iconParts), ui.Part, page.SetTextPart, 104); ui.Mark("text") end)
        ui.When(ui.Bars, function() page.barPartButtons = ui.Pills("Text", Parts(M.barParts), ui.Part, page.SetTextPart, 96) end)
        page.textToggles = ui.Toggles({ { "Show", "part", get = function() return db()[ui.PartKey("Show")] end, set = ui.SetPart("Show") } })
        local function PartSlider(host, suffix, unit)
            return ui.SliderIn(host, M.ranges["cooldown" .. suffix], function() return db()[ui.PartKey(suffix)] end, ui.SetPart(suffix), unit)
        end
        local size = ui.Columns({ "Size" })
        page.textSizeSlider = PartSlider(size[1], "Size")
        ui.Styled("text", function()
            local color = ui.Columns({ "Text Color" })
            ui.Color(color[1], "partColor")
            local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), ui.owner); ui.Refresh(fontRefresh)
            page.fontToggles = ui.Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" }, { "Sharp Text", "slug" } })
        end)
        ui.More("text", function()
            local labels = setmetatable({}, { __index = function(_, key) return L[M.anchorLabels[key] or key] end })
            local anchorButtons, anchorRefresh = W.AnchorPicker(page:Row(L["Anchor"], W.ANCHOR_PICKER_HEIGHT + 16),
                function() return db()[ui.PartKey("Anchor")] end, ui.SetPart("Anchor"), labels, { center = true })
            ui.Refresh(anchorRefresh); page.textAnchorButtons = anchorButtons
            local place = ui.Columns({ "Offset X", "Offset Y" })
            PartSlider(place[1], "X", "px"); PartSlider(place[2], "Y", "px")
        end)
        W.Tip(ui.Note("Click a spell in the preview, then a text's > in its menu, to give that spell its own font, size, color, outline, shadow and place.", 40))
    end)
end

-- Copy Look To: this bar's look (border, background, cooldown, text, glows,
-- bars) to the bars you tick; each keeps its size, lines, spells and show
-- settings. Under Look's More options.
function M:BuildCopyRows(ui)
    local page = ui.page
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
            list[#list + 1] = { id = viewer, label = source and (M:Label(viewer) .. "  " .. addon.Style.ColorText(L["This bar"], addon.Style.Tone.graphite.muted))
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
    local apply = page:Row("", 62)
    apply.rowLabel:Hide(); apply:ClearAllPoints(); apply:SetAllPoints(apply.row)
    page.applyButton = W.Button(apply, L["Copy to Selected"], 150, 30, "secondary")
    page.applyButton:SetPoint("TOPLEFT", 0, -2)
    page.applyAllButton = W.Button(apply, L["Copy to All Bars"], 160, 30, "secondary")
    page.applyAllButton:SetPoint("LEFT", page.applyButton, "RIGHT", 8, 0)
    local result = W.Label(apply, "", nil, 0, 0, 160, T.muted)
    result:ClearAllPoints(); result:SetPoint("TOPLEFT", page.applyButton, "BOTTOMLEFT", 0, -6)
    page.applyResult = result
    local function Report(ok, count)
        result:SetText(ok and string.format(L["Copied to %d bars."], count or 0) or L["Choose bars first."])
    end
    page.applyButton:SetScript("OnClick", function()
        if Chosen() == 0 then Report(false); return end
        Report(M:CopyStyleTo(ui.Viewer(), targets))
    end)
    page.applyAllButton:SetScript("OnClick", function() Report(M:CopyStyleToAll(ui.Viewer())) end)
end

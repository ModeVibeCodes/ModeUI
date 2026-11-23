local _, addon = ...
local M, W, T, L = addon.Nameplates, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Only defines the page; ModeUI builds it the first time it's opened. A live
-- preview of the kind being edited sits above the standard tabs (General,
-- Fill, Border, Glow, Text, Auras, Behavior; docs/DESIGN_LANGUAGE.md,
-- "Standard tabs"); clicking a part of it jumps to that part's settings. The
-- Editing switch (Enemy or Friendly) sits above every tab; each part has a
-- card, named for it, in each tab that holds some of its settings.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local editing, auraGroup, indicatorPart, castText = "enemy", "debuffs", "level", "castText"
    local function Kind() return editing end
    local function db() return M.db[editing] end
    local function Group() return db()[auraGroup] end
    page.nameplateEditing = Kind
    page.nameplateAuraGroup = function() return auraGroup end
    function page.SetEditing(kind) if M.styleDefaults[kind] then editing = kind; page:Refresh(); page:Layout() end end
    function page.SetAuraGroup(group) if M.auraGroupLabels[group] then auraGroup = group; page:Refresh(); page:Layout() end end
    function page.SetIndicatorPart(part) if M.indicatorPartLabels[part] then indicatorPart = part; page:Refresh(); page:Layout() end end
    page.nameplateIndicatorPart = function() return indicatorPart end
    function page.SetCastText(key) castText = key; page:Refresh(); page:Layout() end
    local owner = M:AppearanceOwner(Kind)
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) M:SetOption(editing, key, value) end end
    local function SetGroup(key) return function(value) M:SetOption(editing, key, value, auraGroup) end end
    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    local function Shown() return db().show end
    local function Plate() return db().display == "plate" end
    local function Auras() return db().showAuras end
    -- The settings a preview click jumps to.
    page.jumpTargets = {}
    local function Mark(target) local row = page.rows[#page.rows]; page.jumpTargets[target] = { section = row.section, row = row } end

    -- Controls. Each takes the host it fills: a row, or one cell of Columns.
    local function SliderIn(host, range, get, set, suffix)
        Refresh(W.Slider(host, range[1], range[2], range[3], get, function(value) set(math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    local function Slider(host, key, suffix) return SliderIn(host, M.ranges[key], function() return db()[key] end, Set(key), suffix) end
    local function GroupSlider(host, key, suffix)
        return SliderIn(host, M.groupRanges[key], function() return Group()[key] end, SetGroup(key), suffix)
    end
    local function SelectIn(host, width, choices, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get()
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, tostring(value)
        end, set)
        Refresh(function() button:Refresh() end)
        return button
    end
    local function Select(host, width, list, key) return SelectIn(host, width, function() return list end, function() return db()[key] end, Set(key)) end
    local function Pills(title, list, get, set, width)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 96 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get, set)
        Refresh(refresh)
        return buttons
    end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = entry.get or function() return db()[entry[2]] end, set = entry.set or Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    local function Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    local function Note(text, height)
        local host = page:Row("", height or 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return W.Note(label)
    end
    local function Anchor(title, get, set, center)
        local labels = setmetatable({}, { __index = function(_, key) return L[M.anchorLabels[key] or key] end })
        local buttons, refresh = W.AnchorPicker(page:Row(L[title], W.ANCHOR_PICKER_HEIGHT + 16), get, set, labels, { center = center })
        Refresh(refresh)
        return buttons
    end
    local function Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    -- A card in a standard tab, shown while ModeUI styles this kind (and predicate holds).
    local function Card(tab, title, predicate, build)
        page:Tab(tab)
        When(function() return Shown() and (not predicate or predicate()) end, function() page:Group(L[title]); build() end)
    end

    page.configPreview = W.Preview(page, M, { contentHeight = 150 })

    -- Above every tab: the Editing switch, and a tip while that kind is left to Blizzard.
    page.nameplateEditButtons = { Pills("Editing",
        { { id = "enemy", label = "Enemy" }, { id = "friendly", label = "Friendly" } }, Kind, page.SetEditing, 110) }
    When(function() return not Shown() end, function()
        W.Tip(Note("This kind uses Blizzard's own nameplates. Turn on Use ModeUI Plates on the General tab to style it."))
    end)

    -- General: each part's switch, the size, and where each part sits.
    page:Tab("General"); page:Group(L["Show"])
    page.showToggles = Toggles({ { "Use ModeUI Plates", "show" } })
    When(Shown, function()
        page.displayPills = Pills("Style", M.choices.display, function() return db().display end, Set("display"), 110)
        When(Plate, function() page.castToggles = Toggles({ { "Show Cast Bar", "showCastBar" } }) end)
        page.partToggles = Toggles({ { "Show Auras", "showAuras" }, { "Show Combo Points", "showCombo" }, { "Show Indicators", "showIndicator" },
            { "Show Raid Marker", "showRaidIcon" }, { "Show Soft Target Icon", "showSoftTarget" } })
    end)
    Card("General", "Size", Plate, function()
        local size = Columns({ "Width", "Health Height" })
        page.widthSlider = Slider(size[1], "width", "px")
        page.healthHeightSlider = Slider(size[2], "healthHeight", "px")
    end)
    Card("General", "Cast Bar", Plate, function()
        page.castPositionPills = Pills("Position", M.choices.castAnchor, function() return db().castAnchor end, Set("castAnchor")); Mark("cast")
        local size = Columns({ "Height", "Offset X", "Offset Y" })
        page.castHeightSlider = Slider(size[1], "castHeight", "px"); Slider(size[2], "castX", "px"); Slider(size[3], "castY", "px")
        page.castIconPills = Pills("Spell Icon", M.choices.castIcon, function() return db().castIcon end, Set("castIcon"))
        local icon = Columns({ "Icon Offset X", "Icon Offset Y" })
        Slider(icon[1], "castIconX", "px"); Slider(icon[2], "castIconY", "px")
    end)
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
            local place = Columns({ "Point Size", "Spacing" })
            page.comboSizeSlider = Slider(place[1], "comboSize", "px"); Slider(place[2], "comboSpacing", "px")
            local offset = Columns({ "Offset X", "Offset Y" })
            Slider(offset[1], "comboX", "px"); Slider(offset[2], "comboY", "px")
        end)
    end)
    Card("General", "Indicators", nil, function()
        local parts = {}
        for _, part in ipairs(M.indicatorParts) do parts[#parts + 1] = { id = part, label = M.indicatorPartLabels[part] } end
        page.indicatorPartButtons = Pills("Indicator", parts, function() return indicatorPart end, page.SetIndicatorPart, 112)
        Mark("indicator")
        local function Key(suffix) return indicatorPart .. suffix end
        local function SetPart(suffix) return function(value) M:SetOption(editing, Key(suffix), value) end end
        page.indicatorPartToggles = Toggles({ { "Show This Indicator", "part",
            get = function() return db()[M.indicatorShowKeys[indicatorPart]] end,
            set = function(value) M:SetOption(editing, M.indicatorShowKeys[indicatorPart], value) end } })
        page.indicatorAnchorButtons = Anchor("Anchor", function() return db()[Key("Anchor")] end, SetPart("Anchor"), true)
        -- Icons and the level text have different size ranges.
        When(function() return indicatorPart ~= "level" end, function()
            local place = Columns({ "Icon Size", "Offset X", "Offset Y" })
            SliderIn(place[1], M.ranges.questSize, function() return db()[Key("Size")] end, SetPart("Size"), "px")
            SliderIn(place[2], M.ranges.questX, function() return db()[Key("X")] end, SetPart("X"), "px")
            SliderIn(place[3], M.ranges.questY, function() return db()[Key("Y")] end, SetPart("Y"), "px")
        end)
        When(function() return indicatorPart == "level" end, function()
            local place = Columns({ "Size", "Offset X", "Offset Y" })
            SliderIn(place[1], M.ranges.levelSize, function() return db().levelSize end, Set("levelSize"))
            SliderIn(place[2], M.ranges.levelX, function() return db().levelX end, Set("levelX"), "px")
            SliderIn(place[3], M.ranges.levelY, function() return db().levelY end, Set("levelY"), "px")
        end)
        Note("Indicators on the same anchor line up in one row: quest, elite and rare, level. Quest shows on creatures that are part of one of your quests; level uses the game's difficulty color.", 48)
    end)
    Card("General", "Raid Marker", nil, function()
        page.raidAnchorButtons = Anchor("Anchor", function() return db().raidAnchor end, Set("raidAnchor"), true); Mark("markers")
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

    -- Fill: each bar's textures and colors.
    Card("Fill", "Health Bar", Plate, function()
        local textures = Columns({ "Foreground", "Background" })
        page.foregroundSelect = SelectIn(textures[1], 200, function() return M.TextureChoices(true) end,
            function() return db().foregroundTexture end, Set("foregroundTexture"))
        page.backgroundSelect = SelectIn(textures[2], 200, function() return M.TextureChoices(false) end,
            function() return db().backgroundTexture end, Set("backgroundTexture"))
        local choose = Columns({ "Health Color" })
        page.colorSelect = Select(choose[1], 200, M.choices.healthColorMode, "healthColorMode"); Mark("health")
        local custom = Columns({ "Custom Color" })
        Color(custom[1], "healthColor", function() return db().healthColorMode == "custom" end)
        local fade = Columns({ "Health Opacity", "Background Opacity" })
        page.healthOpacitySlider = Slider(fade[1], "healthOpacity", "%")
        page.backgroundOpacitySlider = Slider(fade[2], "backgroundOpacity", "%")
        When(function() return editing == "enemy" end, function()
            page.healthToggles = Toggles({ { "Threat Colors", "threatColors" } })
            local threat = Columns({ "Has Aggro", "Losing Aggro", "Close to Pulling" })
            local function On() return db().threatColors end
            Color(threat[1], "threatAggroColor", On)
            Color(threat[2], "threatLosingColor", On)
            Color(threat[3], "threatPullingColor", On)
            Note("Has Aggro: the enemy is attacking you. Losing Aggro: it's attacking you, but someone else is about to take it. Close to Pulling: it's attacking someone else and you're about to take it.", 48)
        end)
    end)
    Card("Fill", "Cast Bar", Plate, function()
        local texture = Columns({ "Texture" })
        page.castTextureSelect = SelectIn(texture[1], 200, function() return M.TextureChoices(true) end,
            function() return db().castTexture end, Set("castTexture"))
        local colors = Columns({ "Interruptible", "Not Interruptible", "Interrupted" })
        Color(colors[1], "castColor"); Color(colors[2], "castLockedColor"); Color(colors[3], "castInterruptedColor")
        local channel = Columns({ "Channel" })
        Color(channel[1], "castChannelColor")
    end)
    Card("Fill", "Combo Points", function() return db().showCombo end, function()
        local colors = Columns({ "Lit Point Color", "Empty Point Color" })
        Color(colors[1], "comboActiveColor"); Color(colors[2], "comboEmptyColor")
    end)
    Card("Fill", "Focus", Plate, function()
        local texture = Columns({ "Focus Texture" })
        page.focusTextureSelect = SelectIn(texture[1], 200, function()
            local list = { { id = "default", label = "Same as Foreground" } }
            for _, choice in ipairs(M.TextureChoices(true)) do list[#list + 1] = choice end
            return list
        end, function() return db().focusTexture end, Set("focusTexture"))
    end)

    -- Border: the health and cast bar border (docs/DESIGN_LANGUAGE.md,
    -- "Choosing a border"), the aura rims, and rims colored by meaning.
    Card("Border", "Border", Plate, function()
        page.borderStyleSelect, page.borderMetalSelect = W.BorderPickers(page,
            { get = function() return db().edgeStyle end, set = Set("edgeStyle") },
            { get = function() return db().edgeMetal end, set = Set("edgeMetal") })
    end)
    Card("Border", "Aura Borders", Auras, function()
        page.auraBorderPills = Pills("Rim Color", M.choices.auraBorder, function() return db().auraBorder end, Set("auraBorder"))
        local size = Columns({ "Border Size" })
        page.auraBorderSlider = Slider(size[1], "auraBorderSize", "px")
    end)
    Card("Border", "Target", nil, function()
        local style = Columns({ "Style", "Color" })
        page.targetStyleSelect = Select(style[1], 200, M.choices.targetStyle, "targetStyle")
        Color(style[2], "targetColor")
        local sizes = Columns({ "Border Size", "Arrow Size", "Arrow Gap" })
        Slider(sizes[1], "targetThickness", "px"); Slider(sizes[2], "targetArrowSize", "px"); Slider(sizes[3], "targetArrowGap", "px")
        Note("Arrows always sit outside the raid marker, the indicator, any aura row and the combo points beside the bar.", 32)
    end)
    Card("Border", "Aura Border Colors", function() return Auras() and db().auraBorder == "type" end, function()
        local first = Columns({ "Magic", "Curse", "Disease" })
        Color(first[1], "auraMagicColor"); Color(first[2], "auraCurseColor"); Color(first[3], "auraDiseaseColor")
        local second = Columns({ "Poison", "Enrage", "Bleed" })
        Color(second[1], "auraPoisonColor"); Color(second[2], "auraEnrageColor"); Color(second[3], "auraBleedColor")
        local none = Columns({ "No Type", "No Type: Crowd Control" })
        Color(none[1], "auraNoTypeColor"); Color(none[2], "auraCCNoTypeColor")
        Note("Auras without a dispel type, and any aura while the game hides its details, keep the Mode rim.", 32)
    end)

    -- Glow: the focus highlight, the crowd control glow and the health text glow.
    Card("Glow", "Focus", Plate, function()
        page.focusStylePills = Pills("Highlight", M.choices.focusStyle, function() return db().focusStyle end, Set("focusStyle"), 90)
        Mark("focus")
        local look = Columns({ "Color", "Stripe Opacity" })
        Color(look[1], "focusColor")
        page.focusStripeSlider = Slider(look[2], "focusStripeOpacity", "%")
    end)
    Card("Glow", "Crowd Control", Auras, function()
        page.auraGlowToggles = Toggles({ { "Crowd Control Glow", "auraCCGlow" } })
        When(function() return db().auraCCGlow end, function()
            page.auraGlowPills = Pills("Glow Style", M.choices.auraGlowStyle, function() return db().auraGlowStyle end, Set("auraGlowStyle"), 110)
        end)
    end)
    Card("Glow", "Health Text", Plate, function()
        page.healthGlowToggles = Toggles({ { "Health Text Glow", "healthTextGlow" } })
    end)

    -- Text: the text style, then one card per text.
    Card("Text", "Text Style", nil, function()
        local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), owner); Refresh(fontRefresh)
        page.textToggles = Toggles({ { "Outline", "outline" }, { "Slug Text", "slug" } })
        page.shadowPills = Pills("Shadow", addon.Kit.SHADOW_CHOICES, function() return addon.Kit.ShadowMode(db()) end, function(mode)
            local shadow, lifted = addon.Kit.ShadowKeys(mode)
            M:SetOption(editing, "shadow", shadow); M:SetOption(editing, "liftedShadow", lifted)
        end)
        Note("Slug Text draws letters from their outlines, so they stay sharp at any size.", 32)
        local color = Columns({ "Text Color" })
        Color(color[1], "textColor")
    end)
    Card("Text", "Name Text", nil, function()
        page.nameToggles = Toggles({ { "Show Name", "showName" } }); Mark("name")
        page.nameColorPills = Pills("Color", M.choices.nameColorMode, function() return db().nameColorMode end, Set("nameColorMode"), 150)
        When(Plate, function()
            page.nameAnchorButtons = Anchor("Anchor", function() return db().nameAnchor end, Set("nameAnchor"), true)
        end)
        local name = Columns({ "Offset X", "Offset Y", "Size" })
        Slider(name[1], "nameX", "px"); Slider(name[2], "nameY", "px"); page.nameSizeSlider = Slider(name[3], "nameFontSize")
    end)
    Card("Text", "Health Text", Plate, function()
        local choose = Columns({ "Value", "Color" })
        page.healthTextSelect = Select(choose[1], 200, M.choices.healthText, "healthText")
        page.healthTextColorSelect = Select(choose[2], 200, M.choices.healthTextColor, "healthTextColor")
        page.healthTextAnchorButtons = Anchor("Anchor", function() return db().healthTextAnchor end, Set("healthTextAnchor"), true)
        Mark("healthText")
        local health = Columns({ "Offset X", "Offset Y", "Size" })
        Slider(health[1], "healthTextX", "px"); Slider(health[2], "healthTextY", "px"); page.healthSizeSlider = Slider(health[3], "healthFontSize")
    end)
    -- The cast bar's three texts share one size; Position Of picks the one to place.
    Card("Text", "Cast Bar Text", Plate, function()
        page.castContentToggles = Toggles({ { "Spell Name", "castShowText" }, { "Cast Target", "castShowTarget" }, { "Timer", "castShowTimer" } })
        local size = Columns({ "Size" })
        page.castSizeSlider = Slider(size[1], "castFontSize")
        local texts = { { id = "castText", label = "Spell Name" }, { id = "castTimer", label = "Timer" }, { id = "castTarget", label = "Cast Target" } }
        page.castTextButtons = Pills("Position Of", texts, function() return castText end, page.SetCastText, 112)
        page.castTextAnchorButtons = Anchor("Anchor", function() return db()[castText .. "Anchor"] end,
            function(value) M:SetOption(editing, castText .. "Anchor", value) end, true)
        local offset = Columns({ "Offset X", "Offset Y" })
        SliderIn(offset[1], M.ranges.castTextX, function() return db()[castText .. "X"] end, function(value) M:SetOption(editing, castText .. "X", value) end, "px")
        SliderIn(offset[2], M.ranges.castTextY, function() return db()[castText .. "Y"] end, function(value) M:SetOption(editing, castText .. "Y", value) end, "px")
        Note("Left, Center and Right sit inside the cast bar; Top and Bottom anchors sit outside it. Cast Target is who the caster is targeting. The timer stays empty while the game hides cast times and gives no duration.", 48)
    end)

    -- Auras: each group's contents and place, then how every icon looks.
    page:Tab("Auras")
    When(function() return Shown() and not Auras() end, function()
        W.Tip(Note("Turn on Show Auras on the General tab to set up this kind's auras."))
    end)
    Card("Auras", "Groups", Auras, function()
        page.auraGroupButtons = Pills("Group", { { id = "crowdControl", label = "Crowd Control" }, { id = "debuffs", label = "Debuffs" },
            { id = "buffs", label = "Buffs" } }, function() return auraGroup end, page.SetAuraGroup, 112)
        Mark("auras")
        page.auraGroupToggles = Toggles({ { "Show This Group", "show", get = function() return Group().show end, set = SetGroup("show") },
            { "Sit on Health Bar", "attach", get = function() return Group().attach end, set = SetGroup("attach") } })
        When(function() return Group().show end, function()
            When(function() return M.groupFilters[auraGroup] ~= nil end, function()
                local which = Columns({ "Which" })
                page.auraFilterSelect = SelectIn(which[1], 220, function() return M.groupFilters[auraGroup] or {} end,
                    function() return Group().filter end, SetGroup("filter"))
            end)
            page.auraAnchorButtons = Anchor("Anchor", function() return Group().anchor end, SetGroup("anchor"))
            page.auraGrowPills = Pills("Grow", M.growChoices, function() return Group().grow end, SetGroup("grow"), 70)
            Note("Sit on Health Bar: a Top or Bottom group sits right against the bar, and the name and cast bar on that side move past it.", 32)
            local offset = Columns({ "Offset X", "Offset Y" })
            page.auraXSlider = GroupSlider(offset[1], "x", "px"); page.auraYSlider = GroupSlider(offset[2], "y", "px")
            local size = Columns({ "Icon Size", "Most Shown" })
            page.auraSizeSlider = GroupSlider(size[1], "size", "px"); page.auraMaxSlider = GroupSlider(size[2], "max")
        end)
    end)
    Card("Auras", "Icons", Auras, function()
        page.auraShapePills = Pills("Icon Shape", M.choices.auraShape, function() return db().auraShape end, Set("auraShape"))
        local spacing = Columns({ "Spacing" })
        page.auraSpacingSlider = Slider(spacing[1], "auraSpacing", "px")
    end)
    Card("Auras", "Timer", Auras, function()
        page.auraToggles = Toggles({ { "Timer Swipe", "auraTimer" }, { "Timer Text", "auraTimerText" } })
        When(function() return db().auraTimerText end, function()
            local timer = Columns({ "Timer Text Color" })
            Color(timer[1], "auraTimerColor")
        end)
    end)
    Card("Auras", "Stacks", Auras, function()
        page.auraCountToggles = Toggles({ { "Stack Count", "auraCount" } })
    end)

    -- Behavior: fading the other plates while you have a focus.
    Card("Behavior", "Focus", Plate, function()
        local fade = Columns({ "Other Plates Opacity" })
        page.focusFadeSlider = Slider(fade[1], "focusFadeOthers", "%")
        Note("Your focus's plate shows the highlight and its own texture. Other Plates Opacity fades every other plate while you have a focus; 100% leaves them alone. A plate that is your target and focus shows the target's border.", 48)
    end)

    W.StandardTabs(page)
    -- The sample shows itself as your focus while the Glow tab (the focus highlight) is open.
    function page.nameplateFocusSample() return page.selectedSection ~= nil and page.selectedSection.title == "Glow" end
    local select = page.SelectSectionTab
    function page:SelectSectionTab(...)
        select(self, ...)
        if self.configPreview and self.configPreview.Refresh then self.configPreview:Refresh() end
    end
    page:Finish(); return page
end

local _, addon = ...
local M, W, T = addon.UnitFrames, addon.ConfigWidgets, addon.InterfaceTheme
if not M then return end

-- Tabs: Frame (show it, matching, scale, placement, tools), then one per part
-- of the frame (Health Bar, Power Bar, Portrait, Cast Bar, Auras, Class
-- Resource) with that part's own size, colors, textures and text spots, and
-- Text (name colors, font). The Onyx rim is locked, so there is no Border tab.
-- Every tab edits the frame picked with Editing above the preview, shared by
-- every tab for this session.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    -- Tiles four across under the preview strip (docs/DESIGN_LANGUAGE.md, "Settings window").
    page.cardColumns = 4
    local editing = "player"
    local function Unit() return editing end
    local function db() return M.db[editing] end
    local owner = M:AppearanceOwner(Unit)
    page.unitFrameEditing = Unit

    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    -- Controls take the host they fill: a labeled row, or one cell of Columns.
    local function SelectIn(host, width, choices, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get()
            for _, choice in ipairs(choices()) do if choice.id == value then return value, choice.label end end
            return value, addon.Media:MediaLabel(tostring(value):gsub("^media:", ""))
        end, set)
        page.refreshers[#page.refreshers + 1] = function() button:Refresh() end
        return button
    end
    local function Select(label, choices, get, set) return SelectIn(page:Row(label, 48), 260, choices, get, set) end
    local function Set(key) return function(v) M:SetFrameOption(editing, key, v) end end
    local function SliderIn(host, key, suffix)
        local r = M.frameRanges[key]
        page.refreshers[#page.refreshers + 1] = W.Slider(host, r[1], r[2], r[3],
            function() return db()[key] end, function(v) M:SetFrameOption(editing, key, math.floor(v + 0.5)) end, suffix, true)
        return host.slider
    end
    local function Slider(text, key, suffix) return SliderIn(page:Row(text, 48), key, suffix) end
    local function Choice(text, key)
        local list = M.choices[M.choiceKeys[key]]
        Select(text, function() return list end, function() return db()[key] end, Set(key))
    end
    local function Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            local key = entry[2]
            items[#items + 1] = { label = entry[1], get = entry.get or function() return db()[key] end, set = entry.set or Set(key) }
        end
        page:ToggleGrid(items, { maxColumns = 2, minimumCellWidth = 210 })
    end
    local function Color(text, key, enabled) W.ColorRow(page, owner, text, key, enabled) end
    local function Matched() return editing == "target" and db().matchPlayer end
    local function Note(title, text, height)
        local label = W.Label(page:Row(title, height or 40), text, nil, 0, -4, 420, T.muted); label:SetWordWrap(true)
        return W.Note(label)
    end
    -- Style settings a Target matching the Player takes from the Player: hidden
    -- while it matches (tabs of the frame's own settings use this per row).
    local function Style(build) When(function() return not Matched() end, build) end

    -- The live sample of the frame being edited (Preview.lua); clicking a part
    -- of it reveals the row marked here for that part.
    page.configPreview = W.Preview(page, M, { contentHeight = 150 })
    -- A tab about one frame's part (Class Resource) switches the sample to that frame.
    function page:OnSectionTabChanged() if self.configPreview then self.configPreview:Refresh() end end
    page.jumpTargets = {}
    local function Mark(target) local row = page.rows[#page.rows]; page.jumpTargets[target] = { section = row.section, row = row } end

    -- Editing (the frame every tab changes) sits at the preview's top right,
    -- as on Action Bars. Each frame in its list says On or Off beside its
    -- name, and Turn On shows when the frame being edited is off.
    local function Hex(c) return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
    function M.FrameStateLabel(unit)
        local on = M.db[unit].enabled
        return M.labels[unit] .. "  " .. (on and Hex(T.enabled) .. "On" or Hex(T.muted) .. "Off") .. "|r"
    end
    local function FrameChoices()
        local list = {}
        for _, unit in ipairs(M.units) do list[#list + 1] = { id = unit, label = M.FrameStateLabel(unit) } end
        return list
    end
    function page.SetEditing(unit) if M.labels[unit] then editing = unit; page:Refresh(); page:Layout() end end
    if page.previewArea then
        local corner = CreateFrame("Frame", nil, page.previewArea)
        corner:SetPoint("TOPRIGHT", page.previewArea, "TOPRIGHT", 0, -4); corner:SetSize(370, 28)
        local select = SelectIn(corner, 220, FrameChoices, Unit, page.SetEditing)
        select:ClearAllPoints(); select:SetPoint("RIGHT", 0, 0)
        local label = W.Label(corner, "Editing", nil, 0, 0, 52, T.muted)
        label:ClearAllPoints(); label:SetPoint("RIGHT", select, "LEFT", -8, 0); label:SetJustifyH("RIGHT")
        local turnOn = W.Button(corner, "Turn On", 80, 24, "choice")
        turnOn:SetPoint("RIGHT", label, "LEFT", -8, 0)
        turnOn:SetScript("OnClick", function() M:SetFrameOption(editing, "enabled", true) end)
        page.refreshers[#page.refreshers + 1] = function() turnOn:SetShown(not M.db[editing].enabled) end
        page.unitFrameEditSelect, page.unitFrameTurnOn = select, turnOn
        page.previewReserveRight = 380
        page:UpdatePreviewLayout()
    end

    -- A tab of style settings for the frame being edited. `own`: settings every
    -- frame keeps for itself (cast bar, auras), so a matched Target edits them
    -- too. `always`: the frame's own settings shown first, even on a matched Target.
    local function Tab(title, build, own, always)
        page:Section(title, nil, false)
        if always then When(function() return db().enabled end, always) end
        if not own then
            When(function() return db().enabled and Matched() end, function()
                W.Tip(Note("Target Matches Player", "The Target uses the Player frame's look. Turn off Match Player Frame on the Frame tab to customize it here."))
            end)
        end
        When(function() return not db().enabled end, function()
            W.Tip(Note("Frame Off", "This frame is turned off. Use Turn On above the preview, or Show Frame on the Frame tab."))
        end)
        When(function() return db().enabled and (own or not Matched()) end, build)
    end
    -- Helpers the other tab files (SettingsExtra.lua, SettingsText.lua) build with.
    local ui = { page = page, When = When, SelectIn = SelectIn, Select = Select, Toggles = Toggles, Note = Note, Tab = Tab,
        Editing = Unit, db = db, Mark = Mark, Choice = Choice, Slider = Slider, SliderIn = SliderIn, Color = Color, owner = owner,
        Matched = Matched, Style = Style, Set = Set }

    -- Frame: show it, Blizzard's own, matching (Target), size, placement, tools.
    page:Section("Frame", nil, false)
    Toggles({ { "Show Frame", "enabled" }, { "Hide Blizzard's Frame", "hideBlizzard" } }); Mark("frame")
    When(function() return editing == "target" end, function()
        page:Group("Match the Player")
        Toggles({ { "Match Player Frame", "matchPlayer" } })
        When(Matched, function()
            Toggles({ { "Mirror Player Text", "mirrorText" } })
            W.Tip(Note("Target Matches Player", "The Target uses the Player frame's look and text, mirrored to its other side with Mirror Player Text. Its width, fill direction, cast bar, auras, status and placement stay its own.", 52))
        end)
    end)
    When(function() return db().enabled end, function()
        Style(function() page:Group("Size"); Slider("Scale", "scale", "%") end)
        -- The frame's and its cast bar's border (docs/DESIGN_LANGUAGE.md, "Choosing a border").
        Style(function()
            page:Group("Border")
            page.unitFrameBorder, page.unitFrameBorderMetal = W.BorderPickers(page,
                { get = function() return db().edgeStyle end, set = Set("edgeStyle") },
                { get = function() return db().edgeMetal end, set = Set("edgeMetal") })
            -- The heavy border's soft drop (Player and Target only).
            When(function() return editing == "player" or editing == "target" end, function()
                Toggles({ { "Drop Shadow", "dropShadow" } })
            end)
            -- The Prism glow round the block (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme").
            Choice("Prism Glow", "prismGlow")
        end)
        -- Target of Target and Target of Focus can attach to their parent frame
        -- (offsets in screen pixels); detached, they move in Edit Mode.
        When(function() return M.attachParents[editing] ~= nil end, function()
            page:Group("Placement")
            for unit, parent in pairs(M.attachParents) do
                When(function() return editing == unit end, function() Toggles({ { "Attach to " .. M.titles[parent], "attach" } }) end)
            end
            When(function() return db().attach end, function()
                Choice("Attach Point", "attachPoint")
                local offsets = page:Columns({ "Attach Offset X", "Attach Offset Y" })
                page.unitFrameAttachX = SliderIn(offsets[1], "attachOffsetX", "px")
                page.unitFrameAttachY = SliderIn(offsets[2], "attachOffsetY", "px")
            end)
        end)
        -- The Player and Target copy their style to each other; the smaller
        -- frames copy the Player's.
        page:Group("Style Tools")
        local function CopyPair()
            if editing == "player" then return "player", "target", "Copy Style to Target" end
            if editing == "target" then return "target", "player", "Copy Style to Player" end
            return "player", editing, "Copy Player Style"
        end
        -- One button per line, the tile's width.
        local tools = page:Row("Frame Tools")
        local reset = W.Button(tools, "Reset Frame", 190, 24); reset:SetPoint("LEFT"); reset:SetPoint("RIGHT")
        reset:SetScript("OnClick", function() M:ResetFrame(editing) end)
        local copyRow = page:Row("", 30, nil, true)
        copyRow.rowLabel:Hide(); copyRow:ClearAllPoints(); copyRow:SetAllPoints(copyRow.row)
        table.remove(page.searchEntries)
        local copy = W.Button(copyRow, "", 190, 24); copy:SetPoint("LEFT"); copy:SetPoint("RIGHT")
        copy:SetScript("OnClick", function() local from, to = CopyPair(); M:CopyStyle(from, to) end)
        page.refreshers[#page.refreshers + 1] = function() local _, _, text = CopyPair(); copy.label:SetText(text) end
        page.unitFrameReset, page.unitFrameCopy = reset, copy
    end)
    local status = W.Label(page:Row("Status", 56), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    page.unitFrameStatus = status
    page.refreshers[#page.refreshers + 1] = function() status:SetText(M:Status()) end

    -- Bar textures and opacity: a part's own keys.
    local function Textures(fill, back, fillOpacity, backOpacity)
        page:Group("Textures")
        local textures = page:Columns({ "Foreground", "Background" })
        local fg = SelectIn(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end, function() return db()[fill] end, Set(fill))
        local bg = SelectIn(textures[2], 200, function() return addon.Kit.BarTextureChoices(false) end, function() return db()[back] end, Set(back))
        local fade = page:Columns({ "Foreground Opacity", "Background Opacity" })
        return fg, bg, SliderIn(fade[1], fillOpacity, "%"), SliderIn(fade[2], backOpacity, "%")
    end

    -- Health Bar: its width and height (the portrait follows the bar block's
    -- height), fill, colors, textures and the text spots on it. Width and fill
    -- direction are each frame's own, so a matched Target keeps them.
    Tab("Health Bar", function()
        When(function() return Matched() end, function()
            W.Tip(Note("Target Matches Player", "The Target uses the Player frame's look; its width, fill direction and health color stay its own. Turn off Match Player Frame on the Frame tab to customize the rest.", 52))
        end)
        -- The Player can be a mana frame: its bar shows mana, not health (owner,
        -- November 19, 2026: two pills, Show: Health or Mana).
        When(function() return editing == "player" end, function()
            page:Group("Bar")
            local choices = {}
            for _, item in ipairs(M.choices.barShows) do choices[#choices + 1] = { label = item.label, value = item.id, width = 96 } end
            local buttons, refresh = W.Exclusive(page:Row("Show", 48), choices, function() return db().barShows end, Set("barShows"))
            page.refreshers[#page.refreshers + 1] = refresh
            page.unitFrameShow = buttons
        end)
        page:Group("Size")
        Slider("Frame Width", "barWidth", "px")
        -- Frame Height (owner, November 19, 2026; was Health Bar Height): the
        -- health bar's height, the bar block's inside its 2px rim.
        Style(function() Slider("Frame Height", "healthHeight", "px"); Mark("health") end)
        Choice("Fill Direction", "fillDirection")
        Style(function() Toggles({ { "Fill End Line", "fillEdge" }, { "Shields", "showShields" } }) end)
        -- Health Color is each frame's own, a matched Target's too: Default is
        -- the dark fill; the Target takes Class Color by default.
        page:Group("Color")
        Choice("Health Color", "healthColorMode")
        When(function() return db().healthColorMode == "custom" end, function() Color("Custom Health Color", "healthColor") end)
        Style(function()
            page.unitFrameForeground, page.unitFrameBackground, page.unitFrameForegroundOpacity, page.unitFrameBackgroundOpacity =
                Textures("foregroundTexture", "backgroundTexture", "barForegroundOpacity", "barBackgroundOpacity")
        end)
    end, true)

    Tab("Power Bar", function()
        Toggles({ { "Show Power Bar", "showPower" } }); Mark("power")
        When(function() return db().showPower end, function()
            page:Group("Size")
            Slider("Power Bar Height", "powerHeight", "px")
            page:Group("Color")
            Choice("Power Color", "powerColorMode")
            When(function() return db().powerColorMode == "custom" end, function() Color("Custom Power Color", "powerColor") end)
            page.unitFramePowerForeground, page.unitFramePowerBackground, page.unitFramePowerForegroundOpacity,
                page.unitFramePowerBackgroundOpacity = Textures("powerForegroundTexture", "powerBackgroundTexture",
                "powerForegroundOpacity", "powerBackgroundOpacity")
        end)
    end)

    -- Show Portrait comes first, then the status badges on the portrait,
    -- then its look. A matched Target takes Show Portrait from the Player.
    Tab("Portrait", function()
        When(function() return db().showPortrait end, function()
            page:Group("Portrait")
            Choice("Portrait Style", "portraitStyle"); Choice("Portrait Side", "portraitSide")
            -- A share of the bar block's height, so it grows and shrinks with the bars.
            Slider("Portrait Size", "portraitScale", "%")
            -- Ring Style (any Mode border style), then its finish: a metal
            -- (Portrait Ring "border" + Ring Metal), Class Color or Custom.
            page.unitFrameRingStyle, page.unitFrameRingFinish = W.BorderPickers(page,
                { get = function() return db().portraitRingStyle end, set = Set("portraitRingStyle") },
                { get = function() return M.RingFinish(db()) end, set = function(id) M:SetRingFinish(editing, id) end },
                { labels = { "Ring Style", "Ring Finish" }, finishes = M.ringFinishes })
            When(function() return db().portraitRing == "custom" end, function() Color("Portrait Ring Color", "portraitRingColor") end)
        end)
    end, false, function()
        Style(function() Toggles({ { "Show Portrait", "showPortrait" } }); Mark("portrait") end)
        M:BuildStatusControls(ui)
    end)

    M:BuildCastTab(ui)
    M:BuildAurasTab(ui)
    M:BuildComboTab(ui)
    M:BuildTextTab(ui)

    W.PinnedSectionTabs(page)
    page:Finish(); return page
end

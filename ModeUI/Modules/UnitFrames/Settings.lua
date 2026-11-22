local _, addon = ...
local M, W, T = addon.UnitFrames, addon.ConfigWidgets, addon.InterfaceTheme
if not M then return end

-- The standard tabs (docs/DESIGN_LANGUAGE.md, "Standard tabs"), a card per
-- part of the frame in each: General (show, match, size, placement), Fill
-- (bars, colors, textures), Border (frame border, portrait ring, aura
-- borders), Glow (Prism glow, combat ring, text glows), Text (font, then a
-- card per text) and Auras. Every tab edits the frame picked with Editing
-- above the preview, shared by every tab for this session.
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
    -- while it matches (cards of the frame's own settings use this per row).
    local function Style(build) When(function() return not Matched() end, build) end

    -- The live sample of the frame being edited (Preview.lua); clicking a part
    -- of it reveals the row marked here for that part.
    page.configPreview = W.Preview(page, M, { contentHeight = 150 })
    -- Each mark opens the tab its row sits on.
    page.jumpTargets = {}
    local function Mark(target) local row = page.rows[#page.rows]; page.jumpTargets[target] = { section = row.section, row = row } end

    -- Editing (the frame every tab changes) sits at the preview's top right,
    -- as on Action Bars. Each frame in its list says On or Off beside its
    -- name, and Show Frame shows when the frame being edited is off.
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
        corner:SetPoint("TOPRIGHT", page.previewArea, "TOPRIGHT", 0, -4); corner:SetSize(390, 28)
        local select = SelectIn(corner, 220, FrameChoices, Unit, page.SetEditing)
        select:ClearAllPoints(); select:SetPoint("RIGHT", 0, 0)
        local label = W.Label(corner, "Editing", nil, 0, 0, 52, T.muted)
        label:ClearAllPoints(); label:SetPoint("RIGHT", select, "LEFT", -8, 0); label:SetJustifyH("RIGHT")
        local turnOn = W.Button(corner, "Show Frame", 100, 24, "choice")
        turnOn:SetPoint("RIGHT", label, "LEFT", -8, 0)
        turnOn:SetScript("OnClick", function() M:SetFrameOption(editing, "enabled", true) end)
        page.refreshers[#page.refreshers + 1] = function() turnOn:SetShown(not M.db[editing].enabled) end
        page.unitFrameEditSelect, page.unitFrameTurnOn = select, turnOn
        page.previewReserveRight = 400
        page:UpdatePreviewLayout()
    end

    -- A card of the frame being edited, in the standard tab `tab`
    -- (docs/DESIGN_LANGUAGE.md, "Standard tabs"), shown while the frame is on.
    -- `own`: settings every frame keeps for itself (cast bar, auras, status),
    -- so a matched Target edits them too; other cards hide while it matches.
    local function Card(tab, title, build, own)
        page:Tab(tab)
        When(function() return db().enabled and (own or not Matched()) end, function()
            if title then page:Group(title) end
            build()
        end)
    end
    -- Helpers the other settings files (SettingsExtra.lua, SettingsText.lua) build with.
    local ui = { page = page, When = When, SelectIn = SelectIn, Select = Select, Toggles = Toggles, Note = Note, Card = Card,
        Editing = Unit, db = db, Mark = Mark, Choice = Choice, Slider = Slider, SliderIn = SliderIn, Color = Color, owner = owner,
        Matched = Matched, Style = Style, Set = Set }

    -- Above every tab: why the frame's settings are missing.
    When(function() return not db().enabled end, function()
        W.Tip(Note("Frame Off", "This frame is turned off. Use Show Frame above the preview, or on the General tab."))
    end)
    When(function() return db().enabled and Matched() end, function()
        W.Tip(Note("Target Matches Player", "The Target uses the Player frame's look and text, mirrored to its other side with Mirror Player Text. Its width, fill direction, health color, cast bar, auras, status and placement stay its own. Turn off Match Player Frame on the General tab to customize the rest.", 52))
    end)

    -- General > Frame: show it (reachable while it is off), Blizzard's own, its
    -- scale and size. Width is each frame's own, so a matched Target keeps it.
    -- Frame Height (owner, November 19, 2026; was Health Bar Height): the
    -- health bar's height, the bar block's inside its 2px rim (the portrait
    -- follows the bar block's height).
    page:Tab("General"); page:Group("Frame")
    Toggles({ { "Show Frame", "enabled" }, { "Hide Blizzard's Frame", "hideBlizzard" } }); Mark("frame")
    When(function() return db().enabled end, function()
        Style(function() Slider("Scale", "scale", "%") end)
        Slider("Frame Width", "barWidth", "px")
        Style(function() Slider("Frame Height", "healthHeight", "px") end)
    end)
    -- General > Match the Player (the Target only).
    When(function() return editing == "target" end, function()
        page:Group("Match the Player")
        Toggles({ { "Match Player Frame", "matchPlayer" } })
        When(Matched, function() Toggles({ { "Mirror Player Text", "mirrorText" } }) end)
    end)
    -- Border > Frame: the frame's and its cast bar's border (docs/DESIGN_LANGUAGE.md, "Choosing a border").
    Card("Border", "Frame", function()
        page.unitFrameBorder, page.unitFrameBorderMetal = W.BorderPickers(page,
            { get = function() return db().edgeStyle end, set = Set("edgeStyle") },
            { get = function() return db().edgeMetal end, set = Set("edgeMetal") })
        -- The heavy border's soft drop (Player and Target only).
        When(function() return editing == "player" or editing == "target" end, function()
            Toggles({ { "Shadow", "dropShadow" } })
        end)
    end)
    -- Glow > Frame: the Prism glow round the block (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme").
    Card("Glow", "Frame", function() Choice("Prism Glow", "prismGlow") end)

    -- Bar textures and opacity: a part's own keys, in the part's Fill card.
    local function Textures(fill, back, fillOpacity, backOpacity)
        local textures = page:Columns({ "Foreground", "Background" })
        local fg = SelectIn(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end, function() return db()[fill] end, Set(fill))
        local bg = SelectIn(textures[2], 200, function() return addon.Kit.BarTextureChoices(false) end, function() return db()[back] end, Set(back))
        local fade = page:Columns({ "Foreground Opacity", "Background Opacity" })
        return fg, bg, SliderIn(fade[1], fillOpacity, "%"), SliderIn(fade[2], backOpacity, "%")
    end

    -- Fill > Health Bar: what it shows, its fill, color and textures. Fill
    -- direction and Health Color are each frame's own, a matched Target's too.
    Card("Fill", "Health Bar", function()
        -- The Player can be a mana frame: its bar shows mana, not health (owner,
        -- November 19, 2026: two pills, Show: Health or Mana).
        When(function() return editing == "player" end, function()
            local choices = {}
            for _, item in ipairs(M.choices.barShows) do choices[#choices + 1] = { label = item.label, value = item.id, width = 96 } end
            local buttons, refresh = W.Exclusive(page:Row("Show", 48), choices, function() return db().barShows end, Set("barShows"))
            page.refreshers[#page.refreshers + 1] = refresh
            page.unitFrameShow = buttons
        end)
        Choice("Fill Direction", "fillDirection"); Mark("health")
        Style(function() Toggles({ { "Fill End Line", "fillEdge" }, { "Shields", "showShields" } }) end)
        -- Default is the dark fill; the Target takes Class Color by default.
        Choice("Health Color", "healthColorMode")
        When(function() return db().healthColorMode == "custom" end, function() Color("Custom Health Color", "healthColor") end)
        Style(function()
            page.unitFrameForeground, page.unitFrameBackground, page.unitFrameForegroundOpacity, page.unitFrameBackgroundOpacity =
                Textures("foregroundTexture", "backgroundTexture", "barForegroundOpacity", "barBackgroundOpacity")
        end)
    end, true)

    -- Power Bar: shown and sized in General, colored in Fill.
    Card("General", "Power Bar", function()
        Toggles({ { "Show Power Bar", "showPower" } }); Mark("power")
        When(function() return db().showPower end, function() Slider("Power Bar Height", "powerHeight", "px") end)
    end)
    Card("Fill", "Power Bar", function()
        When(function() return db().showPower end, function()
            Choice("Power Color", "powerColorMode")
            When(function() return db().powerColorMode == "custom" end, function() Color("Custom Power Color", "powerColor") end)
            page.unitFramePowerForeground, page.unitFramePowerBackground, page.unitFramePowerForegroundOpacity,
                page.unitFramePowerBackgroundOpacity = Textures("powerForegroundTexture", "powerBackgroundTexture",
                "powerForegroundOpacity", "powerBackgroundOpacity")
        end)
    end)

    -- Portrait: Show Portrait first, then its look in General and its ring in
    -- Border; the status badges and combat ring are the frame's own. A
    -- matched Target takes the rest from the Player.
    Card("General", "Portrait", function()
        Toggles({ { "Show Portrait", "showPortrait" } }); Mark("portrait")
        When(function() return db().showPortrait end, function()
            Choice("Portrait Style", "portraitStyle"); Choice("Portrait Side", "portraitSide")
            -- A share of the bar block's height, so it grows and shrinks with the bars.
            Slider("Portrait Size", "portraitScale", "%")
        end)
    end)
    Card("Border", "Portrait", function()
        When(function() return db().showPortrait end, function()
            -- Ring Style (any Mode border style), then its finish: a metal
            -- (Portrait Ring "border" + Ring Metal), Class Color or Custom.
            page.unitFrameRingStyle, page.unitFrameRingFinish = W.BorderPickers(page,
                { get = function() return db().portraitRingStyle end, set = Set("portraitRingStyle") },
                { get = function() return M.RingFinish(db()) end, set = function(id) M:SetRingFinish(editing, id) end },
                { labels = { "Ring Style", "Ring Finish" }, finishes = M.ringFinishes })
            When(function() return db().portraitRing == "custom" end, function() Color("Portrait Ring Color", "portraitRingColor") end)
        end)
    end)
    M:BuildStatusControls(ui)

    M:BuildTextTab(ui)
    M:BuildCastTab(ui)
    M:BuildAurasTab(ui)
    M:BuildComboTab(ui)

    -- General > Placement: Target of Target and Target of Focus can attach to
    -- their parent frame (offsets in screen pixels); detached, they move in Edit Mode.
    page:Tab("General")
    When(function() return db().enabled and M.attachParents[editing] ~= nil end, function()
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
    page:Tab("General")
    local status = W.Label(page:Row("Status", 56), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
    page.unitFrameStatus = status
    page.refreshers[#page.refreshers + 1] = function() status:SetText(M:Status()) end

    W.StandardTabs(page, true)
    page:Finish(); return page
end

-- The frame Editing names on the settings page (the Player before it is built).
local function EditingUnit()
    local page = M.page
    return page and page.unitFrameEditing and page.unitFrameEditing() or "player"
end

-- Reset… (the settings footer): the frame being edited, or every frame.
function M:ResetScopes()
    local unit = EditingUnit()
    return {
        { label = M.titles[unit], run = function() M:ResetFrame(unit) end,
            prompt = "Put every " .. M.titles[unit] .. " setting back to its default?" },
        { label = "All of " .. M.title, run = function() M:ResetToDefaults() end,
            prompt = "Put every " .. M.title .. " setting back to its default?" },
    }
end

-- Copy To… (the settings footer): the Player and Target copy their style to
-- each other; the smaller frames take the Player's.
function M:CopyActions()
    local unit = EditingUnit()
    local from, to = "player", unit
    if unit == "player" then to = "target" elseif unit == "target" then from, to = "target", "player" end
    return { { label = M.labels[from] .. " Style to " .. M.labels[to], run = function() M:CopyStyle(from, to) end } }
end

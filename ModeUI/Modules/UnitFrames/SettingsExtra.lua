local _, addon = ...
local M, W = addon.UnitFrames, addon.ConfigWidgets
if not M then return end

-- Settings tabs for the parts kept in nested tables: the class resource (the
-- Target's, in M.db.comboPoints), and each frame's cast bar and auras. Built
-- by CreateConfigPage (Settings.lua) with its helpers in `ui`.

-- Controls bound to one nested table: `get()` returns the table and
-- `set(key, value)` changes it through M:SetNestedOption.
local function Nested(ui, get, set)
    local page, n = ui.page, {}
    function n.Toggle(label, key) return { label = label, get = function() return get()[key] end, set = function(v) set(key, v) end } end
    function n.Toggles(entries) return page:ToggleGrid(entries, { maxColumns = 2, minimumCellWidth = 210 }) end
    function n.Select(label, list, key)
        return ui.Select(label, function() return list end, function() return get()[key] end, function(v) set(key, v) end)
    end
    function n.SelectIn(host, list, key)
        return ui.SelectIn(host, 200, function() return list end, function() return get()[key] end, function(v) set(key, v) end)
    end
    -- One slider in a Columns cell; `range` is { low, high, step }.
    function n.Slider(host, range, key, suffix)
        page.refreshers[#page.refreshers + 1] = W.Slider(host, range[1], range[2], range[3], function() return get()[key] end,
            function(v) set(key, math.floor(v + 0.5)) end, suffix, true)
        return host.slider
    end
    -- The shared color row reads and writes through an appearance owner.
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return get()[key] end }) } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.SetAppearance(_, key, value) return set(key, value) end
    function n.Color(label, key, enabled) W.ColorRow(page, owner, label, key, enabled) end
    return n
end
M.NestedControls = Nested

-- Class Resource (owner, November 13, 2026: not just a Rogue's): your class's
-- points around the Target's portrait (Domain.ClassResource). A class without
-- one is told so, and nothing shows or can be set for it.
function M:BuildComboTab(ui)
    local page, When = ui.page, ui.When
    local Resource = addon.Domain.ClassResource
    page:Section("Class Resource", nil, false)
    local function C() return M.db.comboPoints end
    local function Has() return Resource.Spec() ~= nil end
    local n = Nested(ui, C, function(key, value) M:SetComboOption(key, value) end)
    local about = W.Tip(ui.Note("Your Class", "", 40))
    page.unitFrameResourceNote = about
    page.refreshers[#page.refreshers + 1] = function()
        local spec, class = Resource.Spec(), Resource.ClassName()
        if spec then
            about:SetText(class .. ": " .. spec.name .. (spec.when and (", " .. spec.when) or "") .. ", around the Target frame's portrait.")
        else
            about:SetText((class ~= "" and class or "Your class") .. " has no class resource on WoW Forever, so nothing shows here. Rogues, and Druids in Cat Form, have Combo Points.")
        end
    end
    ui.Mark("combo")
    When(Has, function()
        page.unitFrameComboToggles = n.Toggles({ n.Toggle("Show Class Resource", "enabled"), n.Toggle("Hide Blizzard Class Resource", "hideBlizzard") })
    end)
    When(function() return Has() and C().enabled end, function()
        page:Group("Placement")
        page.unitFrameComboArc = n.Select("Arc Position", M.choices.comboArc, "arc")
        local sizes = page:Columns({ "Point Size", "Spacing", "Distance" })
        page.unitFrameComboSize = n.Slider(sizes[1], M.comboRanges.size, "size", "px")
        n.Slider(sizes[2], M.comboRanges.spacing, "spacing", "px")
        n.Slider(sizes[3], M.comboRanges.distance, "distance", "px")
        page:Group("Colors")
        n.Color("Lit Point Color", "activeColor"); n.Color("Empty Point Color", "emptyColor")
    end)
end

-- A tab of the frame's own (a matched Target edits its own cast bar).
function M:BuildCastTab(ui)
    local page, When = ui.page, ui.When
    local function C() return ui.db().castBar end
    local n = Nested(ui, C, function(key, value) M:SetCastOption(ui.Editing(), key, value) end)
    ui.Tab("Cast Bar", function()
        page.unitFrameCastToggles = n.Toggles({ n.Toggle("Show Cast Bar", "enabled") }); ui.Mark("cast")
        -- Only the Player, Target and Focus have a Blizzard cast bar to hide.
        When(function() return C().enabled and M.nativeCast[ui.Editing()] ~= nil end, function()
            n.Toggles({ n.Toggle("Hide Blizzard Cast Bar", "hideBlizzard") })
        end)
        When(function() return C().enabled end, function()
            page:Group("Placement")
            page.unitFrameCastPosition = n.Select("Position", M.choices.castPosition, "position")
            local size = page:Columns({ "Bar Height", "Gap" })
            page.unitFrameCastHeight = n.Slider(size[1], M.castRanges.height, "height", "px")
            n.Slider(size[2], M.castRanges.gap, "gap", "px")
            -- Full Width spans the bar block (short of the portrait); off, Bar
            -- Width sets it, centred under that span.
            page.unitFrameCastFullWidth = n.Toggles({ n.Toggle("Full Width", "fullWidth") })
            When(function() return not C().fullWidth end, function()
                local width = page:Columns({ "Bar Width" })
                page.unitFrameCastWidth = n.Slider(width[1], M.castRanges.width, "width", "px")
            end)
            page:Group("Textures")
            local textures = page:Columns({ "Foreground", "Background" })
            page.unitFrameCastForeground = ui.SelectIn(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end,
                function() return C().foregroundTexture end, function(v) M:SetCastOption(ui.Editing(), "foregroundTexture", v) end)
            page.unitFrameCastBackground = ui.SelectIn(textures[2], 200, function() return addon.Kit.BarTextureChoices(false) end,
                function() return C().backgroundTexture end, function(v) M:SetCastOption(ui.Editing(), "backgroundTexture", v) end)
            page:Group("Icon and Text")
            page.unitFrameCastIcon = n.Select("Spell Icon", M.choices.castIcon, "icon")
            n.Toggles({ n.Toggle("Spell Name", "showText"), n.Toggle("Timer", "showTimer") })
            local font = page:Columns({ "Font Size" })
            n.Slider(font[1], M.castRanges.fontSize, "fontSize")
            page:Group("Colors")
            n.Color("Cast Color", "color"); n.Color("Uninterruptible Color", "lockedColor")
        end)
    end, true)
end

-- Buffs and Debuffs share one set of controls; the group switch at the top
-- picks which one they edit. A tab of the frame's own.
function M:BuildAurasTab(ui)
    local page, When = ui.page, ui.When
    local group = "buffs"
    local function A() return ui.db()[group] end
    function page.SetAuraGroup(name) if M.auraGroupLabels[name] then group = name; page:Refresh(); page:Layout() end end
    page.unitFrameAuraGroup = function() return group end
    local n = Nested(ui, A, function(key, value) M:SetAuraOption(ui.Editing(), group, key, value) end)
    ui.Tab("Auras", function()
        local buttons, refresh = W.Exclusive(page:Row("Group", 48), { { label = "Buffs", value = "buffs", width = 110 },
            { label = "Debuffs", value = "debuffs", width = 110 } }, function() return group end, page.SetAuraGroup)
        page.refreshers[#page.refreshers + 1] = refresh
        page.unitFrameAuraButtons = buttons; ui.Mark("auras")
        page.unitFrameAuraToggles = n.Toggles({ { label = "Show", get = function() return A().enabled end,
            set = function(v) M:SetAuraOption(ui.Editing(), group, "enabled", v) end } })
        When(function() return A().enabled end, function()
            page:Group("Which Auras")
            for _, name in ipairs(M.auraGroups) do
                When(function() return group == name end, function() n.Select("Filter", M.choices[name .. "Filter"], "filter") end)
            end
            local count = page:Columns({ "Max Shown", "Per Row" })
            n.Slider(count[1], M.auraRanges.max, "max"); n.Slider(count[2], M.auraRanges.perRow, "perRow")
            page:Group("Placement")
            local place = page:Columns({ "Corner", "Grow" })
            page.unitFrameAuraAnchor = n.SelectIn(place[1], M.choices.auraAnchor, "anchor")
            n.SelectIn(place[2], M.choices.auraGrow, "grow")
            local offsets = page:Columns({ "Offset X", "Offset Y" })
            n.Slider(offsets[1], M.auraRanges.x, "x", "px"); n.Slider(offsets[2], M.auraRanges.y, "y", "px")
            page:Group("Icons")
            local look = page:Columns({ "Icon Size", "Spacing" })
            page.unitFrameAuraSize = n.Slider(look[1], M.auraRanges.size, "size", "px")
            n.Slider(look[2], M.auraRanges.spacing, "spacing", "px")
            local skin = page:Columns({ "Shape", "Border" })
            n.SelectIn(skin[1], M.choices.auraShape, "shape"); n.SelectIn(skin[2], M.choices.auraBorder, "border")
            n.Toggles({ n.Toggle("Timer Swipe", "timer"), n.Toggle("Stack Count", "count") })
        end)
    end, true)
end

-- Status on the portrait (Portrait tab): each frame's own, so a matched Target
-- edits its own. Shown while the frame shows a portrait.
function M:BuildStatusControls(ui)
    local page, When = ui.page, ui.When
    local function St() return ui.db().status end
    local n = Nested(ui, St, function(key, value) M:SetStatusOption(ui.Editing(), key, value) end)
    local function Portrait() return M:FrameDB(ui.Editing()).showPortrait end
    local function Player() return ui.Editing() == "player" end
    When(Portrait, function()
        page:Group("Status")
        When(Player, function()
            page.unitFrameRestToggle = n.Toggles({ n.Toggle("Rested Icon", "restIcon"), n.Toggle("Combat Icon", "combatIcon") })
        end)
        When(function() return not Player() end, function() n.Toggles({ n.Toggle("Combat Icon", "combatIcon") }) end)
        local corners = page:Columns({ "Rested Corner", "Combat Corner" })
        page.unitFrameRestCorner = n.SelectIn(corners[1], M.choices.statusCorner, "restCorner")
        page.unitFrameCombatCorner = n.SelectIn(corners[2], M.choices.statusCorner, "combatCorner")
        local size = page:Columns({ "Badge Size" })
        n.Slider(size[1], M.statusRanges.badgeSize, "badgeSize", "px")
        n.Toggles({ n.Toggle("Keep Relative Text Positions", "mirror"), n.Toggle("Combat Ring", "combatRing") })
        When(function() return St().combatRing or St().pulse end, function() n.Color("Combat Ring Color", "ringColor") end)
        -- Something pulled you that you haven't targeted: the ring pulses until you do.
        When(Player, function()
            page.unitFramePulseToggle = n.Toggles({ n.Toggle("Pulse When Pulled", "pulse") })
        end)
    end)
end

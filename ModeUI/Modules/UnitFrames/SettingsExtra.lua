local _, addon = ...
local M, W = addon.UnitFrames, addon.ConfigWidgets
if not M then return end

-- Settings cards for the parts kept in nested tables: the class resource (the
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
-- points around the Target's portrait (Domain.ClassResource), so its cards
-- (General, Fill) show while Editing is the Target, the frame they sit on. A
-- class without one is told so, and nothing shows or can be set for it.
function M:BuildComboTab(ui)
    local page, When = ui.page, ui.When
    local Resource = addon.Domain.ClassResource
    local function C() return M.db.comboPoints end
    local function Has() return Resource.Spec() ~= nil end
    local function Target() return ui.Editing() == "target" end
    local n = Nested(ui, C, function(key, value) M:SetComboOption(key, value) end)
    page:Tab("General")
    When(Target, function()
        page:Group("Class Resource")
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
            page.unitFrameComboArc = n.Select("Arc Position", M.choices.comboArc, "arc")
            local sizes = page:Columns({ "Point Size", "Spacing", "Distance" })
            page.unitFrameComboSize = n.Slider(sizes[1], M.comboRanges.size, "size", "px")
            n.Slider(sizes[2], M.comboRanges.spacing, "spacing", "px")
            n.Slider(sizes[3], M.comboRanges.distance, "distance", "px")
        end)
    end)
    page:Tab("Fill")
    When(function() return Target() and Has() and C().enabled end, function()
        page:Group("Class Resource")
        n.Color("Lit Point Color", "activeColor"); n.Color("Empty Point Color", "emptyColor")
    end)
end

-- The frame's own cast bar (a matched Target edits its own): shown, sized and
-- placed in General, its fill in Fill, its text in Text.
function M:BuildCastTab(ui)
    local page, When = ui.page, ui.When
    local function C() return ui.db().castBar end
    local function On() return C().enabled end
    local n = Nested(ui, C, function(key, value) M:SetCastOption(ui.Editing(), key, value) end)
    ui.Card("General", "Cast Bar", function()
        page.unitFrameCastToggles = n.Toggles({ n.Toggle("Show Cast Bar", "enabled") }); ui.Mark("cast")
        -- ModeCDM's Cast Bar draws the player's casts while it's on.
        When(function() return M:CastClaimed(ui.Editing()) end, function()
            page.unitFrameCastClaimed = W.Tip(ui.Note("Cast Bar in the Cooldown Manager",
                "The Cooldown Manager's Cast Bar shows your casts while it's on, so this one steps aside. Turn it off in /mcdm (Cast Bar, Show Bar) to use this one.", 52))
        end)
        -- Only the Player, Target and Focus have a Blizzard cast bar to hide.
        When(function() return On() and M.nativeCast[ui.Editing()] ~= nil end, function()
            n.Toggles({ n.Toggle("Hide Blizzard Cast Bar", "hideBlizzard") })
        end)
        When(On, function()
            page.unitFrameCastPosition = n.Select("Position", M.choices.castPosition, "position")
            local size = page:Columns({ "Bar Height", "Spacing" })
            page.unitFrameCastHeight = n.Slider(size[1], M.castRanges.height, "height", "px")
            n.Slider(size[2], M.castRanges.gap, "gap", "px")
            -- Full Width spans the bar block (short of the portrait); off, Bar
            -- Width sets it, centred under that span.
            page.unitFrameCastFullWidth = n.Toggles({ n.Toggle("Full Width", "fullWidth") })
            When(function() return not C().fullWidth end, function()
                local width = page:Columns({ "Bar Width" })
                page.unitFrameCastWidth = n.Slider(width[1], M.castRanges.width, "width", "px")
            end)
            page.unitFrameCastIcon = n.Select("Spell Icon", M.choices.castIcon, "icon")
        end)
    end, true)
    ui.Card("Fill", "Cast Bar", function()
        When(On, function()
            local textures = page:Columns({ "Foreground", "Background" })
            page.unitFrameCastForeground = ui.SelectIn(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end,
                function() return C().foregroundTexture end, function(v) M:SetCastOption(ui.Editing(), "foregroundTexture", v) end)
            page.unitFrameCastBackground = ui.SelectIn(textures[2], 200, function() return addon.Kit.BarTextureChoices(false) end,
                function() return C().backgroundTexture end, function(v) M:SetCastOption(ui.Editing(), "backgroundTexture", v) end)
            n.Color("Cast Color", "color"); n.Color("Uninterruptible Color", "lockedColor"); n.Color("Channel Color", "channelColor")
        end)
    end, true)
    ui.Card("Text", "Cast Bar Text", function()
        When(On, function()
            n.Toggles({ n.Toggle("Spell Name", "showText"), n.Toggle("Timer", "showTimer"), n.Toggle("Outline", "outline") })
            local font = page:Columns({ "Size" })
            n.Slider(font[1], M.castRanges.fontSize, "fontSize")
        end)
    end, true)
end

-- Buffs and Debuffs share one set of controls; the group switch at the top
-- of the Auras tab picks which one they edit. Each group's border is in the
-- Border tab. The frame's own.
function M:BuildAurasTab(ui)
    local page, When = ui.page, ui.When
    local group = "buffs"
    local function A() return ui.db()[group] end
    function page.SetAuraGroup(name) if M.auraGroupLabels[name] then group = name; page:Refresh(); page:Layout() end end
    page.unitFrameAuraGroup = function() return group end
    local n = Nested(ui, A, function(key, value) M:SetAuraOption(ui.Editing(), group, key, value) end)
    local function Player() return ui.Editing() == "player" end
    ui.Card("Auras", nil, function()
        -- The Player frame's auras are bars in Buffs & Debuffs (owner,
        -- November 17, 2026); its saved settings here stay untouched.
        When(Player, function()
            local row = page:Row("Player Auras", 72)
            local label = W.Label(row, addon.L["The Player frame's buffs and debuffs moved to Buffs & Debuffs (Interface): bars you filter, size, style and place anywhere."],
                nil, 0, -4, 420, addon.InterfaceTheme.muted)
            label:SetWordWrap(true)
            page.unitFramePlayerAurasButton = W.Button(row, addon.L["Open Buffs & Debuffs"], 190, 28, "secondary")
            page.unitFramePlayerAurasButton:SetPoint("TOPLEFT", 0, -40)
            page.unitFramePlayerAurasButton:SetScript("OnClick", function() addon:SelectConfigPage("buffsDebuffs") end)
        end)
        When(function() return not Player() end, function()
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
                page:Group("Icons")
                local look = page:Columns({ "Icon Size", "Spacing" })
                page.unitFrameAuraSize = n.Slider(look[1], M.auraRanges.size, "size", "px")
                n.Slider(look[2], M.auraRanges.spacing, "spacing", "px")
                local skin = page:Columns({ "Shape" })
                n.SelectIn(skin[1], M.choices.auraShape, "shape")
                local place = page:Columns({ "Corner", "Grow" })
                page.unitFrameAuraAnchor = n.SelectIn(place[1], M.choices.auraAnchor, "anchor")
                n.SelectIn(place[2], M.choices.auraGrow, "grow")
                local offsets = page:Columns({ "Offset X", "Offset Y" })
                n.Slider(offsets[1], M.auraRanges.x, "x", "px"); n.Slider(offsets[2], M.auraRanges.y, "y", "px")
                page:Group("Timer and Stacks")
                n.Toggles({ n.Toggle("Timer Swipe", "timer"), n.Toggle("Stack Count", "count") })
            end)
        end)
    end, true)
    -- Border > Auras: each group's icon border, while that group shows.
    ui.Card("Border", "Auras", function()
        page.unitFrameAuraBorders = {}
        for _, name in ipairs(M.auraGroups) do
            local function G() return ui.db()[name] end
            local own = Nested(ui, G, function(key, value) M:SetAuraOption(ui.Editing(), name, key, value) end)
            When(function() return not Player() and G().enabled end, function()
                local cell = page:Columns({ (name == "buffs" and "Buff" or "Debuff") .. " Border" })
                page.unitFrameAuraBorders[name] = own.SelectIn(cell[1], M.choices.auraBorder, "border")
            end)
        end
    end, true)
end

-- Status on the portrait: each frame's own, so a matched Target edits its
-- own. Shown while the frame shows a portrait: the badges in General, the
-- combat ring in Glow.
function M:BuildStatusControls(ui)
    local page, When = ui.page, ui.When
    local function St() return ui.db().status end
    local n = Nested(ui, St, function(key, value) M:SetStatusOption(ui.Editing(), key, value) end)
    local function Portrait() return M:FrameDB(ui.Editing()).showPortrait end
    local function Player() return ui.Editing() == "player" end
    ui.Card("General", "Status Icons", function()
        When(Portrait, function()
            When(Player, function()
                page.unitFrameRestToggle = n.Toggles({ n.Toggle("Rested Icon", "restIcon"), n.Toggle("Combat Icon", "combatIcon") })
            end)
            When(function() return not Player() end, function() n.Toggles({ n.Toggle("Combat Icon", "combatIcon") }) end)
            -- Only the Player rests.
            When(Player, function()
                local rested = page:Columns({ "Rested Corner" })
                page.unitFrameRestCorner = n.SelectIn(rested[1], M.choices.statusCorner, "restCorner")
            end)
            local combat = page:Columns({ "Combat Corner" })
            page.unitFrameCombatCorner = n.SelectIn(combat[1], M.choices.statusCorner, "combatCorner")
            local size = page:Columns({ "Badge Size" })
            n.Slider(size[1], M.statusRanges.badgeSize, "badgeSize", "px")
            n.Toggles({ n.Toggle("Keep Relative Text Positions", "mirror") })
        end)
    end, true)
    ui.Card("Glow", "Combat Ring", function()
        When(Portrait, function()
            n.Toggles({ n.Toggle("Combat Ring", "combatRing") })
            When(function() return St().combatRing or St().pulse end, function() n.Color("Combat Ring Color", "ringColor") end)
            -- Something pulled you that you haven't targeted: the ring pulses until you do.
            When(Player, function()
                page.unitFramePulseToggle = n.Toggles({ n.Toggle("Pulse When Pulled", "pulse") })
            end)
        end)
    end, true)
end

local _, addon = ...
local M, W, L = addon.PartyFrames, addon.ConfigWidgets, addon.L
if not M then return end

-- The aura manager: pick a group (Healing Buffs, Group Buffs, Defensives,
-- each debuff type, Other Debuffs, Crowd Control) above the tabs, then edit
-- it on Auras (what it shows, where it sits with 1px nudges, its icons, with
-- its own preview: one larger member showing only that group), Border › Aura
-- Borders and Glow › Aura Glows. Type Colors (Border tab) are shared by every
-- group and the debuff effects.

-- Owner for the color rows of the group being edited.
local function GroupOwner(Group)
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return M.db.auras[Group()][key] end }) } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetAuraOption(Group(), key, value) end
    return owner
end

-- Controls for the group being edited.
local function GroupControls(page, c, Group)
    local g = {}
    function g.db() return M.db.auras[Group()] end
    function g.Set(key) return function(value) M:SetAuraOption(Group(), key, value) end end
    function g.Slider(host, key, suffix) return c.SliderIn(host, M.auraRanges[key], function() return g.db()[key] end, g.Set(key), suffix) end
    function g.Pills(title, list, key, width) return c.Pills(title, list, function() return g.db()[key] end, g.Set(key), width) end
    function g.Toggle(label, key) return { label, key, get = function() return g.db()[key] end, set = g.Set(key) } end
    local owner = GroupOwner(Group)
    function g.Color(host, key, enabled) W.ColorRow(page, owner, host.rowLabel:GetText(), key, enabled, host) end
    return g
end

local TRACKED_NOTE = "Buffs you pick: click + (here or in the preview's list) and click a buff on you or your party, or add one by its spell ID. They show here with this group's settings, and the other buff groups leave them out."
local TYPE_NOTE = " debuffs that Dispellable by You doesn't show. Groups on the same anchor and place continue in one row."
M.auraNotes = { heals = "Heals over time and other buffs Blizzard's raid frames show in combat.",
    buffs = "Long buffs such as Fortitude and Mark of the Wild: the ones raid frames leave out in combat.",
    defensives = "Big and External shows up to Most Shown of each kind.",
    tracked1 = TRACKED_NOTE, tracked2 = TRACKED_NOTE, tracked3 = TRACKED_NOTE,
    dispellable = "Debuffs you can dispel, of any type, first in the debuff row. By Type borders color them by type.",
    magic = "Magic" .. TYPE_NOTE, curse = "Curse" .. TYPE_NOTE, disease = "Disease" .. TYPE_NOTE,
    poison = "Poison" .. TYPE_NOTE, bleed = "Bleed" .. TYPE_NOTE,
    otherDebuffs = "Debuffs without a Magic, Curse, Disease, Poison or Bleed type.",
    crowdControl = "Stuns, fears, polymorphs and other loss of control on your party." }

-- Which group the Border, Glow and Auras tabs edit: above the tabs (rows
-- without a tab), shown only on those three.
local GROUP_TABS = { Border = true, Glow = true, Auras = true }
function M:BuildAuraPicker(page, c, Group)
    local function OnGroupTab() local section = page.selectedSection; return section ~= nil and GROUP_TABS[section.title] == true end
    c.When(OnGroupTab, function()
        -- Buffs and debuffs are separate lists; the preview's quick list matches.
        page.auraKindPills = c.Pills("Aura Kind", { { id = "buffs", label = "Buffs" }, { id = "debuffs", label = "Debuffs" } },
            page.partyAuraKind, page.SetAuraKind, 110)
        page.auraGroupSelect = c.SelectIn(page:Row(L["Aura Group"], 48), 220, function()
            local list = {}
            for _, id in ipairs(M:AuraKindGroups(page.partyAuraKind())) do list[#list + 1] = { id = id, label = M.auraGroupLabels[id] } end
            return list
        end, Group, page.SetAuraGroup)
    end)
end

function M:BuildAuraBorders(page, c, Group)
    local g = GroupControls(page, c, Group)
    page:Tab("Border")
    c.When(function() return g.db().show end, function()
        page:Group(L["Aura Borders"])
        page.auraBorderPills = g.Pills("Border", M.choices.auraBorder, "border", 90)
        c.When(function() return g.db().border ~= "none" end, function()
            local border = c.Columns({ "Border Size", "Border Color" })
            page.auraBorderSlider = g.Slider(border[1], "borderSize", "px")
            g.Color(border[2], "borderColor", function() return g.db().border == "custom" end)
        end)
        c.Note("By Type colors the border with the aura's dispel type (Type Colors); auras without one take No Type. Border Size 1 matches the Thin border.", 32)
    end)
end

-- One color per dispel type, shared by aura borders, aura glows and the
-- dispel overlay.
function M:BuildTypeColors(page, c)
    page:Tab("Border")
    page:Group(L["Type Colors"])
    local first = c.Columns({ "Magic", "Curse", "Disease" })
    c.Color(first[1], "auraMagicColor"); c.Color(first[2], "auraCurseColor"); c.Color(first[3], "auraDiseaseColor")
    local second = c.Columns({ "Poison", "Bleed", "No Type" })
    c.Color(second[1], "auraPoisonColor"); c.Color(second[2], "auraBleedColor"); c.Color(second[3], "auraNoTypeColor")
    c.Note("Used by By Type borders and glows and by the dispel overlay. In combat the game colors them even while it hides the aura's details.", 32)
end

function M:BuildAuraGlows(page, c, Group)
    local g = GroupControls(page, c, Group)
    page:Tab("Glow")
    c.When(function() return g.db().show end, function()
        page:Group(L["Aura Glows"])
        page.auraGlowPills = g.Pills("Glow", M.choices.auraGlow, "glow", 100)
        c.When(function() return g.db().glow ~= "none" end, function()
            page.auraGlowColorPills = g.Pills("Glow Color", M.choices.auraGlowColor, "glowColor", 100)
            local glow = c.Columns({ "Custom Glow Color" })
            g.Color(glow[1], "glowCustomColor", function() return g.db().glowColor == "custom" end)
        end)
    end)
end

function M:BuildAuraTab(page, c, Group)
    local g = GroupControls(page, c, Group)
    local db, Set, Slider, Pills, Toggle = g.db, g.Set, g.Slider, g.Pills, g.Toggle
    page:Tab("Auras")
    page:Group(L["Which Auras"])
    page.auraShowToggles = c.Toggles({ Toggle("Show This Group", "show") })
    c.Mark("auras")
    -- Tracked Buffs: the + picker and how many buffs the group holds.
    c.When(function() return M.TRACKED[Group()] == true end, function()
        local row = page:Row(L["Tracked Buffs"], 48)
        page.trackedAddButton = W.Button(row, L["+ Add or Remove Buffs"], 190, 30, "secondary")
        page.trackedAddButton:SetPoint("LEFT")
        page.trackedAddButton:SetScript("OnClick", function() M:OpenPicker(Group(), page.trackedAddButton) end)
        page.trackedCount = W.Label(row, "", nil, 200, -8, 200, addon.InterfaceTheme.muted)
        c.Refresh(function()
            local n = #(db().spells or {})
            page.trackedCount:SetText(n == 0 and L["No buffs yet"] or string.format(L["%d buffs"], n))
        end)
    end)
    page.auraFilterNote = c.Note("", 32)
    c.Refresh(function() page.auraFilterNote:SetText(L[M.auraNotes[Group()]]) end)
    c.When(function() return db().show end, function()
        local which = c.Columns({ "Which Auras" })
        page.auraFilterSelect = c.SelectIn(which[1], 240, function() return M.auraFilters[Group()] end,
            function() return db().filter end, Set("filter"))

        page:Group(L["Placement"])
        page.auraAnchor = c.Anchor("Anchor", function() return db().anchor end, Set("anchor"))
        page.auraPlacePills = Pills("Place", M.choices.place, "place", 96)
        page.auraGrowPills = Pills("Grow", M.growChoices, "grow", 70)
        local offset = c.Columns({ "Offset X", "Offset Y" })
        page.auraXSlider = Slider(offset[1], "x", "px"); page.auraYSlider = Slider(offset[2], "y", "px")
        page.auraNudge = c.Nudge(function() return db().x end, function() return db().y end, Set("x"), Set("y"), M.auraRanges.x)
        local count = c.Columns({ "Most Shown", "Per Row", "Spacing" })
        page.auraMaxSlider = Slider(count[1], "max"); page.auraPerRowSlider = Slider(count[2], "perRow")
        page.auraSpacingSlider = Slider(count[3], "spacing", "px")

        page:Group(L["Icons"])
        local size = c.Columns({ "Icon Width", "Icon Height" })
        page.auraWidthSlider = Slider(size[1], "width", "px"); page.auraHeightSlider = Slider(size[2], "height", "px")
        page.auraLookToggles = c.Toggles({ Toggle("Timer Swipe", "timer"), Toggle("Timer Text", "timerText"),
            Toggle("Stack Count", "count"), Toggle("Tooltips", "tooltip") })
        -- Every group's timer text, in one color.
        local timer = c.Columns({ "Timer Text Color" })
        c.Color(timer[1], "auraTimerColor")
    end)
end

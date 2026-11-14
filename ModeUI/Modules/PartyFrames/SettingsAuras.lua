local _, addon = ...
local M, W, L = addon.PartyFrames, addon.ConfigWidgets, addon.L
if not M then return end

-- The Auras tab: the aura manager, with its own preview (one larger member
-- showing only the group being edited). Pick a group (Healing Buffs, Group
-- Buffs, Defensives, each debuff type, Other Debuffs, Crowd Control), then
-- what it shows, where it sits (with 1px nudges), and how its icons look:
-- width and height, border, glow, timers and stacks. Type colors are shared by
-- every group and the debuff effects.

-- Owner for the color rows of the group being edited.
local function GroupOwner(Group)
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return M.db.auras[Group()][key] end }) } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetAuraOption(Group(), key, value) end
    return owner
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

function M:BuildAuraTab(page, c, Group)
    local function db() return M.db.auras[Group()] end
    local function Set(key) return function(value) M:SetAuraOption(Group(), key, value) end end
    local function Slider(host, key, suffix) return c.SliderIn(host, M.auraRanges[key], function() return db()[key] end, Set(key), suffix) end
    local function Pills(title, list, key, width) return c.Pills(title, list, function() return db()[key] end, Set(key), width) end
    local function Toggle(label, key) return { label, key, get = function() return db()[key] end, set = Set(key) } end
    local owner = GroupOwner(Group)
    local function GroupColor(host, key, enabled) W.ColorRow(page, owner, host.rowLabel:GetText(), key, enabled, host) end
    page:Section(L["Auras"], nil, false)
    page:Group(L["Aura Groups"])
    -- Buffs and debuffs are separate lists; the preview's quick list matches.
    page.auraKindPills = c.Pills("Kind", { { id = "buffs", label = "Buffs" }, { id = "debuffs", label = "Debuffs" } },
        page.partyAuraKind, page.SetAuraKind, 110)
    local groups = {}
    for _, id in ipairs(M.auraGroups) do groups[#groups + 1] = { id = id, label = M.auraGroupLabels[id] } end
    page.auraGroupSelect = c.SelectIn(page:Row(L["Group"], 48), 220, function()
        local list = {}
        for _, id in ipairs(M:AuraKindGroups(page.partyAuraKind())) do list[#list + 1] = { id = id, label = M.auraGroupLabels[id] } end
        return list
    end, Group, page.SetAuraGroup)
    c.Mark("auras")
    page.auraShowToggles = c.Toggles({ Toggle("Show This Group", "show") })
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
        page.auraBorderPills = Pills("Border", M.choices.auraBorder, "border", 90)
        c.When(function() return db().border ~= "none" end, function()
            local border = c.Columns({ "Border Size", "Border Color" })
            page.auraBorderSlider = Slider(border[1], "borderSize", "px")
            GroupColor(border[2], "borderColor", function() return db().border == "custom" end)
        end)
        page.auraGlowPills = Pills("Glow", M.choices.auraGlow, "glow", 100)
        c.When(function() return db().glow ~= "none" end, function()
            page.auraGlowColorPills = Pills("Glow Color", M.choices.auraGlowColor, "glowColor", 100)
            local glow = c.Columns({ "Custom Glow Color" })
            GroupColor(glow[1], "glowCustomColor", function() return db().glowColor == "custom" end)
        end)
        c.Note("By Type colors the border and glow with the aura's dispel type (Type Colors below); auras without one take No Type. Border Size 1 matches the Thin border.", 32)

        page:Group(L["This Group"])
        local tools = page:Row(L["Group"], 48)
        page.auraResetButton = W.Button(tools, L["Reset Group"], 120, 30, "secondary")
        page.auraResetButton:SetPoint("LEFT"); page.auraResetButton:SetScript("OnClick", function() M:ResetSettings(Group()) end)
        local copy = c.Columns({ "Copy Look To" })
        page.auraCopySelect = c.SelectIn(copy[1], 220, function()
            local list = {}
            for _, item in ipairs(groups) do if item.id ~= Group() then list[#list + 1] = item end end
            return list
        end, function() return nil end, function(to) M:CopyAuraGroup(Group(), to) end)
        c.Note("Copy Look To gives another group this group's place and icon look; which auras it shows stays its own.", 32)
    end)

    page:Group(L["Type Colors"])
    local first = c.Columns({ "Magic", "Curse", "Disease" })
    c.Color(first[1], "auraMagicColor"); c.Color(first[2], "auraCurseColor"); c.Color(first[3], "auraDiseaseColor")
    local second = c.Columns({ "Poison", "Bleed", "No Type" })
    c.Color(second[1], "auraPoisonColor"); c.Color(second[2], "auraBleedColor"); c.Color(second[3], "auraNoTypeColor")
    local timer = c.Columns({ "Timer Text Color" })
    c.Color(timer[1], "auraTimerColor")
    c.Note("Used by By Type borders and glows and by the debuff effects. In combat the game colors them even while it hides the aura's details.", 32)
end

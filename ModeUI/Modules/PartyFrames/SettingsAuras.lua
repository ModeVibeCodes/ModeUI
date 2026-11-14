local _, addon = ...
local M, W, L = addon.PartyFrames, addon.ConfigWidgets, addon.L
if not M then return end

-- The Auras tab: the aura manager. Pick a group (Buffs, Debuffs,
-- Dispellable, Defensives, Crowd Control), then what it shows, where it sits
-- and how its icons look. Rim colors by dispel type are shared by every group.
function M:BuildAuraTab(page, c, Group)
    local function db() return M.db.auras[Group()] end
    local function Set(key) return function(value) M:SetAuraOption(Group(), key, value) end end
    local function Slider(host, key, suffix) return c.SliderIn(host, M.auraRanges[key], function() return db()[key] end, Set(key), suffix) end
    page:Section(L["Auras"], nil, false)
    page:Group(L["Aura Groups"])
    local groups = {}
    for _, id in ipairs(M.auraGroups) do groups[#groups + 1] = { id = id, label = M.auraGroupLabels[id] } end
    page.auraGroupSelect = c.SelectIn(page:Row(L["Group"], 48), 220, function() return groups end, Group, page.SetAuraGroup)
    c.Mark("auras")
    page.auraShowToggles = c.Toggles({ { "Show This Group", "show", get = function() return db().show end, set = Set("show") } })
    c.When(function() return db().show end, function()
        local which = c.Columns({ "Which Auras" })
        page.auraFilterSelect = c.SelectIn(which[1], 240, function() return M.auraFilters[Group()] end,
            function() return db().filter end, Set("filter"))
        page.auraFilterNote = c.Note("", 32)
        c.Refresh(function()
            local notes = { buffs = "Raid Frame Buffs are the ones Blizzard's raid frames show in combat; Your Heals Over Time are yours among them.",
                debuffs = "Raid Frame Debuffs are the ones Blizzard's raid frames show in combat.",
                dispellable = "Debuffs a Magic, Curse, Disease or Poison dispel removes.",
                defensives = "Big and External shows up to Most Shown of each kind.",
                crowdControl = "Stuns, fears, polymorphs and other loss of control on your party." }
            page.auraFilterNote:SetText(L[notes[Group()]])
        end)

        page:Group(L["Placement"])
        page.auraAnchor = c.Anchor("Anchor", function() return db().anchor end, Set("anchor"))
        page.auraPlacePills = c.Pills("Place", M.choices.place, function() return db().place end, Set("place"), 96)
        page.auraGrowPills = c.Pills("Grow", M.growChoices, function() return db().grow end, Set("grow"), 70)
        local offset = c.Columns({ "Offset X", "Offset Y" })
        page.auraXSlider = Slider(offset[1], "x", "px"); page.auraYSlider = Slider(offset[2], "y", "px")
        local count = c.Columns({ "Most Shown", "Per Row", "Spacing" })
        page.auraMaxSlider = Slider(count[1], "max"); page.auraPerRowSlider = Slider(count[2], "perRow")
        page.auraSpacingSlider = Slider(count[3], "spacing", "px")

        page:Group(L["Icons"])
        local look = c.Columns({ "Icon Size" })
        page.auraSizeSlider = Slider(look[1], "size", "px")
        page.auraShapePills = c.Pills("Icon Shape", M.choices.auraShape, function() return db().shape end, Set("shape"))
        page.auraBorderPills = c.Pills("Borders", M.choices.auraBorder, function() return db().border end, Set("border"))
        page.auraLookToggles = c.Toggles({
            { "Timer Swipe", "timer", get = function() return db().timer end, set = Set("timer") },
            { "Timer Text", "timerText", get = function() return db().timerText end, set = Set("timerText") },
            { "Stack Count", "count", get = function() return db().count end, set = Set("count") },
            { "Tooltips", "tooltip", get = function() return db().tooltip end, set = Set("tooltip") } })

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

    page:Group(L["Border Colors"])
    local first = c.Columns({ "Magic", "Curse", "Disease" })
    c.Color(first[1], "auraMagicColor"); c.Color(first[2], "auraCurseColor"); c.Color(first[3], "auraDiseaseColor")
    local second = c.Columns({ "Poison", "Bleed", "No Type" })
    c.Color(second[1], "auraPoisonColor"); c.Color(second[2], "auraBleedColor"); c.Color(second[3], "auraNoTypeColor")
    local timer = c.Columns({ "Timer Text Color" })
    c.Color(timer[1], "auraTimerColor")
    c.Note("Groups with By Type borders, and the dispel highlight, use these colors. In combat the game colors them even while it hides the aura's details.", 48)
end

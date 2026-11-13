-- Damage Meters: windows fed by a stubbed C_DamageMeter (the game's meter),
-- pixel geometry, rows, numbers, secret values in combat, Always Show Me,
-- scrolling, the header menu, earlier fights, the spell breakdown, show
-- settings, Edit Mode, Test on Screen, the settings page and its preview,
-- validation and persistence. Simulated client; not WoW rendering or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. [==[
    local methods = getmetatable(UIParent).__index
    -- Secret text makes a FontString's measurements secret too (as in the client).
    local setText = methods.SetText
    function methods:SetText(text)
        if self.kind == 'FontString' and issecretvalue(text) then self.secretContent = true end
        return setText(self, text)
    end
    for _, name in ipairs({ 'GetStringWidth', 'GetStringHeight' }) do
        local get = methods[name]
        methods[name] = function(self, ...) if self.secretContent then return Secret('measure') end return get(self, ...) end
    end
    Enum = { DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6,
        DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 },
        DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 } }
    meterOn, meterAvailable, resets, inGroup = true, true, 0, false
    C_CVar = { GetCVarBool = function(name) assert(name == 'damageMeterEnabled'); return meterOn end }
    function IsInGroup() return inGroup end
    deathRecaps = {}
    function OpenDeathRecapUI(id) deathRecaps[#deathRecaps + 1] = id end
    -- In combat every amount, name and GUID is secret; classes and "you" never are.
    local function S(value, label) if testCombat then return Secret(label or 'amount') end return value end
    -- One fight, ranked by the game: a mage, you (a rogue) and a creature.
    fight = { { name = 'Valeria', class = 'MAGE', amount = 5000, guid = 'Player-1' },
        { name = 'Fixture', class = 'ROGUE', amount = 3000, guid = 'Player-2', me = true },
        { name = 'Wolf', class = '', amount = 500, creature = 1234 } }
    calls = {}
    local function Session()
        local sources, total = {}, 0
        for i, f in ipairs(fight) do
            sources[i] = { name = S(f.name, 'name'), classFilename = f.class, totalAmount = S(f.amount),
                amountPerSecond = S(math.floor(f.amount / 10)), isLocalPlayer = f.me == true,
                sourceGUID = f.guid and S(f.guid, 'guid') or nil, sourceCreatureID = f.creature,
                deathRecapID = f.recap or 0, deathTimeSeconds = S(f.died or 0) }
            total = total + f.amount
        end
        return { combatSources = sources, maxAmount = S(fight[1] and fight[1].amount or 0), totalAmount = S(total), durationSeconds = S(75) }
    end
    local function Public(...)
        for i = 1, select('#', ...) do assert(not issecretvalue((select(i, ...))), 'no secret arguments from addon code') end
    end
    C_DamageMeter = {
        IsDamageMeterAvailable = function() return meterAvailable, meterAvailable and '' or 'Not available in this zone.' end,
        GetCombatSessionFromType = function(sessionType, meterType)
            Public(sessionType, meterType); calls[#calls + 1] = { 'type', sessionType, meterType }; return Session()
        end,
        GetCombatSessionFromID = function(id, meterType)
            Public(id, meterType); calls[#calls + 1] = { 'id', id, meterType }; return Session()
        end,
        GetCombatSessionSourceFromType = function(sessionType, meterType, guid, creature)
            Public(sessionType, meterType, guid, creature); calls[#calls + 1] = { 'source', guid, creature }
            return { combatSpells = {
                { spellID = S(133, 'spell'), totalAmount = S(4000), amountPerSecond = S(400), creatureName = '' },
                { spellID = S(11366, 'spell'), totalAmount = S(1000), amountPerSecond = S(100), creatureName = S('Imp', 'pet') } },
                maxAmount = S(4000), totalAmount = S(5000) }
        end,
        GetAvailableCombatSessions = function() return { { sessionID = 7, name = 'Hogger', durationSeconds = 65 } } end,
        GetSessionDurationSeconds = function(sessionType) Public(sessionType); return 75 end,
        ResetAllCombatSessions = function() resets = resets + 1 end,
    }
    C_Spell = {
        GetSpellName = function(id) if issecretvalue(id) then return Secret('spell name') end return 'Spell' .. id end,
        GetSpellTexture = function(id) if issecretvalue(id) then return Secret('icon') end return 'Interface/Icons/Spell' .. id end,
    }
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, PM, Kit, DM = addon.DamageMeters, addon.PositionManager, addon.Kit, addon.Domain.DamageMeter
    assert(M and not M.enabled and not M.built, 'Damage Meters start off and build nothing')
    assert(M.db.window1.show and not M.db.window2.show and not M.db.window3.show, 'one window on by default')
    assert(M.db.window1.meterType == 'damageDone' and M.db.window2.meterType == 'healingDone' and M.db.window3.meterType == 'damageTaken')
    assert(M.db.window1.barTexture == 'mode' and M.db.window1.fontMedia == 'Expressway', 'Mode Gradient and Expressway')
    assert(DM.Clock(65) == '1:05' and DM.Clock(Secret('t')) == '' and DM.Clock(nil) == '', 'clock text')
    assert(#DM.types == 10 and DM.typeById.dps.perSecond and DM.typeById.interrupts.count, 'the meters Blizzard offers')

    addon:SetModuleEnabled('damageMeters', true)
    local w1, w2 = ModeUIDamageMeter1, ModeUIDamageMeter2
    assert(M.built and w1 and w2 and ModeUIDamageMeter3, 'three windows')
    assert(w1:IsShown() and not w2:IsShown(), 'only switched-on windows show')
    assert(not w1.secure and not (w1.IsProtected and w1:IsProtected()), 'plain frames: they update in combat')

    -- Geometry: 1px rim, 20px header, 1px divider, 1px padding, 8 rows of 18 one pixel apart.
    assert(w1.width == 240 and w1.height == 1 + 20 + 1 + 1 + 8 * 18 + 7 + 1 + 1, 'exact height for the rows')
    assert(w1.height % 2 == 0 and w1.width % 2 == 0, 'even size stays on the pixel grid')
    assert(ModeUIDamageMeter1Mover.width == w1.width and Point(w1)[2] == ModeUIDamageMeter1Mover, 'hangs from its stand-in')
    local row1, row2, row3 = w1.rows[1], w1.rows[2], w1.rows[3]
    local p = Point(row1)
    assert(p[1] == 'TOPLEFT' and p[4] == 2 and p[5] == -23 and row1.width == 236 and row1.height == 18, 'first row inside rim, header, divider and padding')
    assert(Point(row2)[5] == -42, 'next row one row and one pixel down')
    assert(row1.icon.width == 18 and Point(row1.bar)[4] == 19, 'square icon, a pixel gap, then the bar')
    local rim = w1.rim
    assert(rim[1]:IsShown() and Point(rim[1], 1)[4] == 1 and Point(rim[1], 2)[5] == -1, 'rounded rim leaves its corner pixel out')
    assert(rim[1].vertexColor[1] == M.BORDER_COLOR[1] and w1.fill.vertexColor[4] == 0.75, 'rim color and 75% background')
    assert(w1.divider:IsShown() and Point(w1.divider)[5] == -21, 'divider under the header')

    -- Out of combat: names, ranks, numbers and bars from the game.
    assert(w1.header.title.text == 'DAMAGE DONE' and w1.header.info.text == 'Current · 1:15', 'header: meter, fight and time')
    assert(row1.name.text == '1. Valeria' and row1.value.text == '5000 (500)', 'rank, name, amount and per second')
    assert(row1.bar.high == 5000 and row1.bar.value == 5000 and row2.bar.value == 3000, 'bars scale to the top amount')
    local mage = addon.Domain.UnitColor.Class('MAGE')
    assert(row1.bar.statusBarColor[1] == mage.r and row1.bar.statusBarColor[4] == 1, 'class colored')
    assert(row1.icon.atlas == 'classicon-mage' and row1.icon:IsShown(), 'class icon')
    assert(row3.name.text == '3. Wolf' and row3.bar.statusBarColor[1] == M.OTHER_COLOR[1] and not row3.icon:IsShown(), 'no class: Other Color, no icon')
    assert(not w1.rows[4]:IsShown() and not w1.empty:IsShown(), 'unused rows hide')
    assert(M:SetOption('window1', 'showPercent', true) and row1.value.text == '5000 (500) · 59%', 'percent of the total')
    assert(M:SetOption('window1', 'numbers', 'primary') and row1.value.text == '5000 · 59%')
    assert(M:SetOption('window1', 'meterType', 'dps') and row1.value.text == '500 · 59%' and w1.header.title.text == 'DPS', 'DPS leads with per second')
    assert(M:SetOption('window1', 'numbers', 'both') and row1.value.text == '500 (5000) · 59%')
    assert(M:SetOption('window1', 'meterType', 'interrupts') and row1.value.text == '5000 · 59%', 'counts have no per second')
    assert(M:SetOption('window1', 'showRank', false) and row1.name.text == 'Valeria')
    assert(M:SetOption('window1', 'nameColorMode', 'class') and row1.name.color[1] == mage.r, 'class-colored names')
    assert(M:SetOption('window1', 'barColorMode', 'custom') and row1.bar.statusBarColor[3] == M.db.window1.barColor[3], 'one custom color')
    assert(M:ResetWindow('window1') and M.db.window1.meterType == 'interrupts' and M.db.window1.showRank, 'reset keeps the meter')
    assert(M:SetOption('window1', 'meterType', 'damageDone'))

    -- Combat: amounts, names and GUIDs turn secret. They only reach the bar, AbbreviateNumbers and SetFormattedText.
    testCombat = true; FireEvent('PLAYER_REGEN_DISABLED')
    FireEvent('DAMAGE_METER_COMBAT_SESSION_UPDATED', 0, 1); Advance(0.3)
    assert(issecretvalue(row1.bar.high) and issecretvalue(row1.bar.value), 'secret amounts drive the bars')
    assert(row1.name.text.formatted == '%d. %s' and issecretvalue(row1.name.text.secret), 'secret name, ranked by the game')
    assert(row1.value.text.formatted == '%s (%s)' and issecretvalue(row1.value.text.secret), 'secret numbers; no percent in combat')
    assert(row1.bar.statusBarColor[1] == mage.r and row1.icon.atlas == 'classicon-mage', 'class is never secret')
    assert(w1.header.info.text == 'Current · 1:15', 'the fight timer stays public')
    assert(row2.name.text.formatted == '%d. %s', 'still in the game order')
    -- Clicking a row in combat: the GUID is secret, so no call; the panel says when it fills in.
    local before = #calls
    row1.scripts.OnClick(row1, 'LeftButton')
    local panel = ModeUIDamageMeterBreakdown
    assert(panel:IsShown() and panel.empty:IsShown() and panel.empty.text == 'Spell details show after combat.', 'breakdown waits for combat to end')
    for i = before + 1, #calls do assert(calls[i][1] ~= 'source', 'no breakdown call with a secret GUID') end
    testCombat = false; FireEvent('PLAYER_REGEN_ENABLED'); Advance(0.3)
    assert(row1.value.text == '5000 (500)' and row1.name.text == '1. Valeria', 'public again after combat')
    local asked = false
    for i = before + 1, #calls do if calls[i][1] == 'source' and calls[i][2] == 'Player-1' then asked = true end end
    assert(panel.guid == 'Player-1' and asked, 'found by rank once public, then asked by GUID')
    local spell1, spell2 = panel.rows[1], panel.rows[2]
    assert(spell1:IsShown() and spell1.name.text == 'Spell133' and spell1.icon.texture == 'Interface/Icons/Spell133', 'spells with icons')
    assert(spell2.name.text == 'Spell11366 (Imp)' and spell1.bar.high == 4000 and spell2.bar.value == 1000, 'pet spells named, bars scaled')
    assert(spell1.bar.statusBarColor[1] == mage.r and panel.header.title.text == 'Valeria', "the source's color and name")
    assert(Point(panel)[1] == 'TOPRIGHT' and Point(panel)[2] == w1, 'beside the window, facing the middle')
    -- In combat the spells come back secret too; they go to C_Spell and the widgets as they are.
    testCombat = true; FireEvent('PLAYER_REGEN_DISABLED'); M:RenderAll()
    assert(issecretvalue(spell1.name.text) and issecretvalue(spell1.icon.texture) and issecretvalue(spell2.name.text), 'secret spells (and a secret pet name) shown as they are')
    testCombat = false; FireEvent('PLAYER_REGEN_ENABLED')
    row1.scripts.OnClick(row1, 'LeftButton'); assert(not panel:IsShown(), 'same row again closes it')

    -- Always Show Me and the mouse wheel.
    assert(M:SetOption('window1', 'rows', 1) and w1.height == 1 + 20 + 1 + 1 + 18 + 1 + 1 + 1, 'one row (an extra pixel keeps it even)')
    assert(row1.name.text == '2. Fixture', 'you take the last row when ranked below it')
    assert(M:SetOption('window1', 'alwaysShowMe', false) and row1.name.text == '1. Valeria')
    assert(M:SetOption('window1', 'rows', 2))
    w1.scripts.OnMouseWheel(w1, -1)
    assert(w1.offset == 1 and row1.name.text == '2. Fixture' and row2.name.text == '3. Wolf', 'the wheel scrolls the ranking')
    w1.scripts.OnMouseWheel(w1, -5); assert(w1.offset == 1, 'no further than the last source')
    row1.scripts.OnMouseWheel(row1, 1); assert(w1.offset == 0 and row1.name.text == '1. Valeria', 'the wheel over a row scrolls too')
    assert(M:SetOption('window1', 'rows', 8) and M:SetOption('window1', 'alwaysShowMe', true) and w1.offset == 0)

    -- Header menu: meters, fights and reset.
    w1.header.scripts.OnClick(w1.header, 'LeftButton')
    local menu = M.menu
    assert(menu.catcher:IsShown() and menu.entries[1].text.text == 'DAMAGE', 'menu opens under the header')
    local function Entry(label)
        for _, entry in ipairs(menu.entries) do if entry:IsShown() and entry.text.text == label then return entry end end
    end
    assert(Entry('Damage Done').mark:IsShown() and not Entry('DPS').mark:IsShown(), 'the current meter is marked')
    Entry('Healing Done').scripts.OnClick(Entry('Healing Done'))
    assert(not menu.catcher:IsShown() and M.db.window1.meterType == 'healingDone' and calls[#calls][3] == 2, 'picks the meter')
    w1.header.scripts.OnClick(w1.header, 'LeftButton')
    local hogger = Entry('Hogger  1:05')
    assert(hogger, 'earlier fights listed with their length')
    hogger.scripts.OnClick(hogger)
    assert(M.sessionIds.window1 == 7 and calls[#calls][1] == 'id' and w1.header.info.text == 'Hogger · 1:05', 'an earlier fight')
    assert(M.db.window1.session == 'current', 'earlier fights are not saved')
    row1.scripts.OnClick(row1, 'RightButton'); assert(menu.catcher:IsShown(), 'right-clicking a row opens the menu too')
    menu.catcher.scripts.OnClick(menu.catcher); assert(not menu.catcher:IsShown(), 'clicking elsewhere closes it')
    w1.header.scripts.OnClick(w1.header, 'LeftButton')
    Entry('Reset All Data').scripts.OnClick(Entry('Reset All Data'))
    assert(resets == 1 and M.sessionIds.window1 == nil and w1.header.info.text == 'Current · 1:15', 'reset clears the fights')
    assert(M:SetOption('window1', 'meterType', 'damageDone'))

    -- Deaths open the game's Death Recap.
    fight[2].recap, fight[2].died = 9, 125
    assert(M:SetOption('window1', 'meterType', 'deaths'))
    assert(row2.value.text == '2:05' and row2.bar.high == 1 and row2.bar.value == 1, 'when each death happened')
    row2.scripts.OnClick(row2, 'LeftButton')
    assert(deathRecaps[1] == 9 and not (M.breakdown and M.breakdown:IsShown()), 'death recap instead of spells')
    assert(M:SetOption('window1', 'meterType', 'damageDone'))

    -- Settings are checked before they're kept.
    assert(not M:SetOption('window1', 'width', 50) and M.db.window1.width == 240, 'width range')
    assert(not M:SetOption('window1', 'meterType', 'bogus') and not M:SetOption('window1', 'barTexture', 'nope'), 'known choices only')
    assert(not M:SetOption('window1', 'borderColor', { 2, 0, 0 }), 'colors are 0-1')
    assert(M:SetOption('window1', 'barTexture', 'flat') and row1.bar.statusBarTexture == Kit.FLAT and not row1.bar.sheen:IsShown(), 'Flat texture')
    assert(M:SetOption('window1', 'barTexture', 'mode') and row1.bar.sheen:IsShown(), 'Mode Gradient')
    assert(M:SetOption('window1', 'border', 'none') and not rim[1]:IsShown() and not w1.divider:IsShown() and Point(row1)[4] == 1, 'no rim, no divider')
    assert(M:SetOption('window1', 'border', 'square') and Point(rim[1], 1)[4] == 0, 'square corners')
    assert(M:SetOption('window1', 'header', false) and not w1.header:IsShown() and Point(row1)[5] == -2, 'no header: rows start under the rim')
    assert(M:SetOption('window1', 'header', true) and M:SetOption('window1', 'icon', 'none') and not row1.icon:IsShown() and Point(row1.bar)[4] == 0, 'no icon: the bar fills the row')
    assert(M:SetOption('window1', 'clickThrough', true) and not row1.mouse, 'Click Through')
    assert(M:SetOption('window1', 'clickThrough', false) and row1.mouse)
    -- Copy Style keeps each window's meter, fight and show settings.
    assert(M:SetOption('window1', 'width', 300) and M:CopyStyleToAll('window1'))
    assert(M.db.window2.width == 300 and M.db.window2.meterType == 'healingDone' and not M.db.window2.show, 'look copied, identity kept')

    -- Show: Always, In Combat, In a Group, Hidden.
    assert(M:SetOption('window2', 'show', true) and w2:IsShown() and w2.header.title.text == 'HEALING DONE', 'a second window with its own meter')
    assert(M:SetOption('window2', 'visibility', 'combat') and not w2:IsShown(), 'combat only')
    testCombat = true; FireEvent('PLAYER_REGEN_DISABLED'); assert(w2:IsShown(), 'shows in combat')
    testCombat = false; FireEvent('PLAYER_REGEN_ENABLED'); assert(not w2:IsShown())
    assert(M:SetOption('window2', 'visibility', 'group') and not w2:IsShown())
    inGroup = true; FireEvent('GROUP_ROSTER_UPDATE'); assert(w2:IsShown(), 'shows in a group')
    inGroup = false; FireEvent('GROUP_ROSTER_UPDATE')
    assert(M:SetOption('window2', 'visibility', 'hidden') and not w2:IsShown())
    assert(M:SetOption('window1', 'opacity', 50) and w1:GetAlpha() == 0.5, 'opacity')
    assert(M:SetOption('window1', 'opacity', 100))

    -- Edit Mode: every window that's on shows the sample fight, with its stand-in.
    assert(PM.elements.damageMetersWindow1 and PM.elements.damageMetersWindow1.label == 'Window 1')
    assert(PM:GetPosition('damageMetersWindow2').target == 'damageMetersWindow1', 'window 2 stacks on window 1')
    assert(addon:SetEditMode(true))
    local mover2 = ModeUIDamageMeter2Mover
    assert(ModeUIDamageMeter1Mover:IsShown() and mover2:IsShown() and w2:IsShown(), 'hidden windows show while editing')
    assert(mover2.label.text == 'Window 2' and mover2.fill.vertexColor[3] == Kit.palette.accent[3], 'named and highlighted')
    assert(row1.name.text == '1. Valeria' and w1.rows[4].name.text == '4. Mode', 'sample fight while editing')
    assert(addon:SetEditMode(false) and not mover2:IsShown() and not w2:IsShown() and not w1.rows[4]:IsShown())

    -- The game's meter off or unavailable: the window says why.
    fight = {}; meterOn = false; M:RenderAll()
    assert(w1.empty:IsShown() and w1.empty.text:find("Damage Meter option", 1, true) and not row1:IsShown(), 'turn the game meter on')
    assert(M:Status():find('option is off', 1, true))
    meterOn, meterAvailable = true, false; M:RenderAll()
    assert(w1.empty.text == 'Not available in this zone.', "the game's reason")
    meterAvailable = true; M:RenderAll(); assert(w1.empty.text == 'No data yet.')

    -- Settings page and preview.
    SlashCmdList.MODEUI(); addon:SelectConfigPage('damageMeters')
    local page = addon.configWindow.pages.damageMeters
    local sections = {}
    for _, section in ipairs(page.sections) do sections[#sections + 1] = section.title end
    assert(table.concat(sections, ',') == 'Window,Bars,Text,Header,Frame', 'five tabs')
    local view = page.configPreview
    local shell = view.window
    assert(shell.width == 300 and shell.rows[1].name.text == '1. Valeria' and shell.rows[1].value.text == '1284000 (13660)', 'preview: the sample fight in the edited window')
    assert(shell.header.title.text == 'DAMAGE DONE' and view.caption.text == 'Window 1 · sample fight')
    page.SetEditing('window2')
    assert(page.windowEditing() == 'window2' and shell.header.title.text == 'HEALING DONE' and shell.rows[1].name.text == '1. Ysolde', 'follows the window being edited')
    page.SetEditing('window1')
    shell.header.scripts.OnMouseUp(shell.header, 'LeftButton')
    assert(page.selectedSection.title == 'Header', 'header click opens Header')
    shell.rows[2].scripts.OnMouseUp(shell.rows[2], 'LeftButton')
    assert(page.selectedSection.title == 'Bars', 'bar click opens Bars')
    shell.rows[2].textHit.scripts.OnMouseUp(shell.rows[2].textHit, 'LeftButton')
    assert(page.selectedSection.title == 'Text', 'name click opens Text')
    view.background.scripts.OnMouseUp(view.background, 'LeftButton')
    assert(page.selectedSection.title == 'Frame', 'frame click opens Frame')
    assert(M:SetOption('window1', 'rowHeight', 22) and shell.rows[1].height == 22 and w1.rows[1].height == 22, 'preview and window follow the settings')
    assert(page.statusLabel.text:find('Edit Mode', 1, true), 'status line')
    assert(addon:SetEditMode(true))
    addon.EditMode:Select('damageMetersWindow2')
    addon.editWindow.settingsButton.scripts.OnClick(addon.editWindow.settingsButton)
    assert(not addon.editMode and page:IsShown() and page.windowEditing() == 'window2', 'Open Module Settings opens the selected window')

    -- Test on Screen: the sample fight on the real windows.
    assert(M:SetTestDisplay(true) and w1.rows[4].name.text == '4. Mode' and M:IsSimulationVisible())
    assert(M:SetTestDisplay(false) and not w1.rows[4]:IsShown())

    -- Off: windows hide.
    addon:SetModuleEnabled('damageMeters', false)
    assert(not w1:IsShown() and not w2:IsShown(), 'off hides every window')
    addon:SetModuleEnabled('damageMeters', true)
    assert(w1:IsShown())
    assert(M:SetOption('window1', 'width', 260))
]==], "damage meters")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.DamageMeters
    assert(M.enabled and M.db.window1.width == 260 and M.db.window1.rowHeight == 22 and M.db.window2.visibility == 'hidden', 'settings persist')
    assert(ModeUIDamageMeter1:IsShown() and ModeUIDamageMeter1.width == 260)
]==], "restore")

-- No meter API on the client: the windows say so instead of failing.
H.Load({ before = STUBS .. "\nC_DamageMeter = nil", saved = world.saved() }).run([==[
    local w1 = ModeUIDamageMeter1
    assert(w1:IsShown() and w1.empty:IsShown() and w1.empty.text:find("isn't available on this client", 1, true))
    assert(not w1.rows[1]:IsShown())
]==], "no meter")

-- Bad saved data stops startup rather than being reset.
local saved = restored.saved()
saved.profiles.Default.modules.damageMeters.window1.rows = "many"
local ok = pcall(H.Load, { before = STUBS, saved = saved })
assert(not ok, "invalid damage meter settings are refused")

print("damage meters: all checks passed")

-- The Cast Bar in the Cooldown Manager (/mcdm): defaults, its stand-in above
-- Essential with Buff Icons above it, the resource bars' look (pieces, whole
-- pixels, Mode-Border in its own metal, Dark with the Comet head alone), casts,
-- channels and secret values, Show Interrupted, the claim on the player's
-- cast bar (Unit Frames' Player cast bar steps aside, Blizzard's stays faded
-- while either module holds it), the icon box, Edit Mode, the page and
-- preview, settings checks, persistence, the version 8 move of Buff Icons
-- and bad saved data. Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua") .. [[
    MakeViewers()
]]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, PM, Kit, Tone, UF = addon.CooldownManager, addon.PositionManager, addon.Kit, addon.Style.Tone, addon.UnitFrames
    local db = M.db.castBar
    assert(M.db.version == M.VERSION and M.VERSION == 11, 'settings version 11')
    -- Every Mode cast bar (owner, November 23, 2026): light blue, orange-red when it can't be interrupted.
    assert(addon.Style.SameColor(db.barColor, Tone.cast.casting) and addon.Style.SameColor(db.lockedColor, Tone.cast.shielded), 'the new cast colors')
    assert(db.show and db.edgeStyle == 'obsidian' and db.edgeMetal == 'default' and db.rimColor == 'metal' and db.barMode == 'color' and db.barColorMode == 'class', 'Mode-Border in its own metal, filled in your class color')
    assert(db.icon == 'none' and db.showInterrupted and db.darkText == 'class' and db.matchWidth and db.height == 18, 'icon hidden, Show Interrupted, class-colored text')
    assert(M.defaultPositions.buffIcon.target == M.CAST_ELEMENT and M.castPosition.target == 'cooldownManagerEssential' and M.castPosition.placement == 'above')

    -- Unit Frames' Player cast bar shows the cast while the Cooldown Manager is off.
    if not UF.enabled then addon:SetModuleEnabled('unitFrames', true) end
    local ufCast = UF.frames.player.castBox
    units.player.cast = { name = 'Frostbolt', text = 'Frostbolt', icon = 135846, start = 99000, stop = 102000 }
    FireEvent('UNIT_SPELLCAST_START', 'player')
    assert(ufCast:IsShown() and Kit.PlayerCast.ClaimedBy() == nil, 'Unit Frames draws the cast')
    units.player.cast = nil; FireEvent('UNIT_SPELLCAST_STOP', 'player')

    addon:SetModuleEnabled('cooldownManager', true)
    local frame, mover = M.castFrame, ModeUICastBar
    local box, bar = frame.box, frame.box.bar
    local place = PM:GetPosition(M.CAST_ELEMENT)
    assert(mover and place.target == 'cooldownManagerEssential' and place.placement == 'above', 'above Essential')
    assert(PM:GetPosition('cooldownManagerBuffIcon').target == M.CAST_ELEMENT, 'Buff Icons hang above it')
    assert(Kit.PlayerCast.ClaimedBy() == 'cooldownManager' and Kit.NativeFade:IsHeld(PlayerCastingBarFrame, 'cooldownManager'), 'the claim')
    assert(PlayerCastingBarFrame:GetAlpha() == 0 and not frame:IsShown(), "Blizzard's faded; nothing while not casting")
    -- The resource bars' look: the edge in pieces outside the box, on whole pixels.
    assert(box.edge.pieces and #box.edge.parts[1] == 8 and box.edge.styleId == 'obsidian' and box.edge:Metal() == Tone.metal.obsidian, 'Mode-Border in its own metal, in pieces')
    assert(box.height == 18 and mover.height == 22 and Point(box)[4] == 2 and Point(box)[5] == -2, 'the box inside the edge reach')
    assert(frame.snapMover == mover and box.width == mover.width - 4, 'hung on whole pixels, the bar across the width')
    assert(PM:GetSizeMatch(M.CAST_ELEMENT, 'width'), 'Match Width')

    -- A cast: Unit Frames steps aside; by default the fill in your class color with the full Comet.
    units.player.cast = { name = 'Frostbolt', text = 'Frostbolt', icon = 135846, start = 99000, stop = 102000 }
    FireEvent('UNIT_SPELLCAST_START', 'player')
    local fill = bar:GetStatusBarTexture()
    local class = addon.Domain.UnitColor.PlayerClass('player')
    assert(fill.vertexColor[1] == class.r and fill.vertexColor[3] == class.b and box.comet.trail:IsShown(), 'the fill in your class color')
    -- Dark: the dark fill, the Comet head alone, the class color.
    assert(M:SetCastOption('barMode', 'dark'))
    assert(frame:IsShown() and bar.low == 99000 and bar.high == 102000 and bar.value == testClock * 1000, 'the cast, at the time now')
    assert(frame.name.text == 'Frostbolt' and frame.timer.text and frame.icon.texture.texture == 135846, 'name, timer, icon')
    assert(not ufCast:IsShown(), "Unit Frames' Player cast bar steps aside")
    assert(fill.vertexColor[1] == Tone.darkFill[1] and box.comet.head:IsShown() and not box.comet.trail:IsShown(), 'Dark: the dark fill, the Comet head alone')
    assert(frame.name.color[1] == class.r and frame.timer.color[3] == class.b, 'Dark: the text in your class color')
    Advance(0.2); assert(bar.value == testClock * 1000, 'the bar follows the time')
    assert(Point(frame.name)[1] == 'LEFT' and Point(frame.name)[4] == 4 and Point(frame.timer)[1] == 'RIGHT', 'Spell Name left, Timer right')
    -- Color mode: Bar Color (any color), the full Comet; Not Interruptible in its own color.
    assert(M:SetCastOption('barMode', 'color') and M:SetCastOption('barColorMode', 'custom') and not M:SetCastOption('barColorMode', 'rainbow'))
    assert(fill.vertexColor[1] == db.barColor[1] and box.comet.trail:IsShown(), 'Color, Bar Color Custom: Bar Color and the trail')
    assert(M:SetCastOption('barColor', { 0, 1, 0 }) and fill.vertexColor[2] == 1 and fill.vertexColor[1] == 0, 'any foreground color')
    assert(frame.name.color[1] == db.textColor[1], 'Color mode: Text Color')
    units.player.cast.locked = true; FireEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', 'player')
    assert(fill.vertexColor[1] == db.lockedColor[1] and fill.vertexColor[3] == db.lockedColor[3], 'Not Interruptible')
    units.player.cast.locked = false
    assert(M:SetCastOption('rimColor', 'bar') and box.edge.tint[2] == 1, 'Rim Color: Bar Color')
    assert(M:SetCastRim('steel') and box.edge.tint == nil and box.edge:Metal() == Tone.metal.steel and M:CastRim() == 'steel', 'Rim Color: a metal')
    -- Secret cast values go only to the bar, the text and the texture.
    units.player.cast = { name = Secret('n'), text = Secret('t'), icon = Secret('i'), start = Secret('s'), stop = Secret('e'), locked = Secret('l') }
    FireEvent('UNIT_SPELLCAST_START', 'player')
    assert(frame:IsShown() and issecretvalue(bar.low) and issecretvalue(bar.high) and issecretvalue(frame.name.text), 'secret casts reach the widgets')
    units.player.cast = nil; FireEvent('UNIT_SPELLCAST_STOP', 'player')
    assert(not frame:IsShown(), 'hidden when the cast stops')
    -- A channel drains: the fill from the right in the background color over the cast color.
    units.player.channel = { name = 'Arcane Missiles', text = 'Arcane Missiles', icon = 136096, start = 99000, stop = 103000 }
    FireEvent('UNIT_SPELLCAST_CHANNEL_START', 'player')
    assert(frame:IsShown() and bar.reverseFill == true and bar.bg.vertexColor[2] == 1 and frame.name.text == 'Arcane Missiles', 'a channel drains')
    units.player.channel = nil; FireEvent('UNIT_SPELLCAST_CHANNEL_STOP', 'player')
    assert(M:SetCastOption('barMode', 'dark'))

    -- Show Interrupted: 1s full in the Interrupted color with its name, then a 0.3s fade.
    units.player.cast = { name = 'Frostbolt', text = 'Frostbolt', icon = 135846, start = testClock * 1000, stop = testClock * 1000 + 2000 }
    FireEvent('UNIT_SPELLCAST_START', 'player')
    units.player.cast = nil
    FireEvent('UNIT_SPELLCAST_INTERRUPTED', 'player', 'guid', 116)
    assert(frame.heldUntil and bar.value == 1 and bar.high == 1 and fill.vertexColor[1] == db.interruptedColor[1], 'held full in the Interrupted color')
    assert(frame.name.text == (INTERRUPTED or 'Interrupted') and frame.timer.text == '' and not box.comet.clip:IsShown(), '"Interrupted", no spark')
    FireEvent('UNIT_SPELLCAST_STOP', 'player')
    assert(frame:IsShown() and frame.alpha == 1, 'the stop that follows leaves it held')
    Advance(1.15); assert(frame:IsShown() and frame.alpha > 0.4 and frame.alpha < 0.6, 'fading')
    Advance(0.2); assert(not frame:IsShown() and frame.heldUntil == nil, 'then gone')
    assert(M:SetCastOption('showInterrupted', false))
    units.player.cast = { name = 'Frostbolt', text = 'Frostbolt', icon = 135846, start = testClock * 1000, stop = testClock * 1000 + 2000 }
    FireEvent('UNIT_SPELLCAST_START', 'player'); units.player.cast = nil
    FireEvent('UNIT_SPELLCAST_INTERRUPTED', 'player', 'guid', 116)
    assert(not frame:IsShown(), 'Show Interrupted off: gone at once')
    assert(M:SetCastOption('showInterrupted', true))

    -- The icon: its own box in its own edge, at either end; the bar takes the rest.
    assert(M:SetCastOption('icon', 'left') and frame.icon:IsShown() and frame.icon.edge.pieces and frame.icon.edge.holder:IsShown())
    assert(frame.icon.width == 18 and Point(frame.icon)[4] == 2 and Point(box)[4] == 26 and box.width == mover.width - 26 - 2, 'Left: icon, Icon Gap, bar')
    assert(M:SetCastOption('icon', 'right') and Point(frame.icon)[4] == mover.width - 20 and Point(box)[4] == 2, 'Right')
    assert(M:SetCastOption('border', 'none') and not box.edge.holder:IsShown() and not frame.icon.edge.holder:IsShown() and box.height == 18, 'Border None')
    assert(M:SetCastOption('border', 'mode') and M:SetCastOption('icon', 'none') and not frame.icon:IsShown())
    -- Texts: each with its anchor and offsets.
    assert(M:SetCastOption('nameAnchor', 'CENTER') and M:SetCastOption('nameY', 3) and Point(frame.name)[1] == 'CENTER' and Point(frame.name)[4] == 0 and Point(frame.name)[5] == 3)
    assert(M:SetCastOption('timerShow', false) and not frame.timer:IsShown() and M:SetCastOption('timerShow', true))
    assert(M:SetCastOption('textSize', 14) and frame.name.font[2] == 14)

    -- Edit Mode: the stand-in, and a sample cast on the bar.
    assert(addon:SetEditMode(true) and mover:IsShown() and frame:IsShown() and frame.name.text == 'Frostbolt' and bar.value == 0.6, 'a sample in Edit Mode')
    assert(PM:Element(M.CAST_ELEMENT).label == 'Cast Bar')
    assert(addon:SetEditMode(false) and not mover:IsShown() and not frame:IsShown())

    -- Off: the claim goes, Unit Frames draws the cast again; Blizzard's stays
    -- faded while Unit Frames still holds it (its own Hide Blizzard Cast Bar).
    assert(M:SetCastOption('show', false) and Kit.PlayerCast.ClaimedBy() == nil and not Kit.NativeFade:IsHeld(PlayerCastingBarFrame, 'cooldownManager'))
    assert(Kit.NativeFade:IsHeld(PlayerCastingBarFrame, 'unitFrames') and PlayerCastingBarFrame:GetAlpha() == 0, 'Unit Frames still hides it')
    units.player.cast = { name = 'Frostbolt', text = 'Frostbolt', icon = 135846, start = 99000, stop = 102000 }
    FireEvent('UNIT_SPELLCAST_START', 'player')
    assert(ufCast:IsShown() and not frame:IsShown(), 'Unit Frames shows it again')
    assert(M:SetCastOption('show', true) and not ufCast:IsShown() and frame:IsShown(), 'and steps aside again')
    -- Unit Frames off: the Cast Bar alone keeps Blizzard's faded; both off: it comes back.
    addon:SetModuleEnabled('unitFrames', false)
    assert(PlayerCastingBarFrame:GetAlpha() == 0 and Kit.NativeFade:IsHeld(PlayerCastingBarFrame, 'cooldownManager'), 'still faded')
    addon:SetModuleEnabled('cooldownManager', false)
    assert(PlayerCastingBarFrame:GetAlpha() == 1 and Kit.PlayerCast.ClaimedBy() == nil and not frame:IsShown(), "Blizzard's back")
    addon:SetModuleEnabled('cooldownManager', true)
    addon:SetModuleEnabled('unitFrames', true)
    assert(Kit.PlayerCast.ClaimedBy() == 'cooldownManager' and PlayerCastingBarFrame:GetAlpha() == 0)
    units.player.cast = nil; FireEvent('UNIT_SPELLCAST_STOP', 'player')

    -- Checked settings, outside combat only; Reset keeps Show Bar and the size.
    assert(not M:SetCastOption('height', 100) and not M:SetCastOption('icon', 'top') and not M:SetCastOption('barColor', { 2, 0, 0 }), 'bad values refused')
    assert(not M:SetCastOption('unknown', 1) and not M:SetCastOption('darkText', 'power'))
    testCombat, testLockdown = true, true
    assert(not M:SetCastOption('height', 20), 'settings change only outside combat')
    testCombat, testLockdown = false, false
    assert(M:SetCastOption('height', 20) and M:SetCastOption('barMode', 'dark') and M:ResetCast())
    assert(db.height == 20 and M.db.castBar.barMode == 'color' and M.db.castBar.barColorMode == 'class' and M.db.castBar.nameAnchor == 'LEFT', 'Reset: the look back, the size kept')
    db = M.db.castBar

    -- The window: Cast Bar under Resource Bars, its page and preview.
    SlashCmdList.MODEUICDM()
    local window = ModeUICooldownManagerWindow
    -- After the viewers, the custom bars (the five default bars) and the resource bars.
    local base = #M.viewers + #M.db.customBars
    local row = window.rows[base + 5]
    assert(row and row.label.text == 'Cast Bar' and row.resource == 'cast', 'Cast Bar in the list')
    assert(M.castPage == nil, 'built on first use')
    row.scripts.OnClick(row)
    local page, view = M.castPage, M.castPreview
    assert(page and page:IsShown() and not M.page:IsShown() and row.selected and M.selectedCast, 'the Cast Bar page')
    assert(view.bar:IsShown() and view.bar.name.text == 'Frostbolt' and view.bar.box.bar.value == 0.6, 'preview: a sample cast')
    assert(page.castStatus.text:find('Shows your casts') ~= nil and M:EditingValue() == 'cast')
    assert(M:SetCastOption('icon', 'left') and view.bar.icon:IsShown(), 'the preview follows the settings')
    assert(page.castRimPicker and page.castBorderStylePicker and page.castIconPills and page.castTextSizeSlider, 'its controls')
    window.rows[base + 1].scripts.OnClick(window.rows[base + 1])
    assert(M.resourcePage:IsShown() and not page:IsShown() and not M.selectedCast, 'a resource bar instead')
    M:SelectEditing('cast'); assert(page:IsShown() and not M.resourcePage:IsShown(), 'Editing picks it too')
    window.rows[1].scripts.OnClick(window.rows[1])
    assert(M.page:IsShown() and not page:IsShown(), 'back to the cooldown page')
    M:OpenSettings(M.CAST_ELEMENT)
    assert(page:IsShown(), "Edit Mode's Open Module Settings opens it")
    window:Hide()
]==], "cast bar")

-- Saved: the settings come back; bad data stops startup rather than being reset.
local saved = world.saved()
local restored = H.Load({ before = STUBS, saved = saved })
restored.run([==[
    local db = addon.CooldownManager.db.castBar
    assert(db.height == 20 and db.icon == 'left' and db.nameAnchor == 'LEFT', 'kept')
]==], "restore")
local function Refused(change, label)
    local data = restored.saved()
    change(data.profiles.Default.modules.cooldownManager.castBar)
    assert(not pcall(H.Load, { before = STUBS, saved = data }), "invalid cast bar settings are refused: " .. label)
end
Refused(function(db) db.icon = "top" end, "icon")
Refused(function(db) db.height = 400 end, "height")
Refused(function(db) db.barColor = { 2, 0, 0 } end, "a color")
Refused(function(db) db.darkText = "power" end, "a Dark Text Color")
Refused(function(db) db.showInterrupted = "yes" end, "Show Interrupted")

-- Version 7 -> 8: a Buff Icons place still at its old default (above
-- Essential) moves above the cast bar, once; a moved one stays; a profile
-- from before the cast bar takes its defaults.
local seven = restored.saved()
local profile = seven.profiles.Default
local cdm = profile.modules.cooldownManager
cdm.version, cdm.castBar, cdm.moveBuffIcons = 7, nil, nil
profile.positions.cooldownManagerBuffIcon = { target = 'cooldownManagerEssential', placement = 'above', x = 0, y = 0 }
H.Load({ before = STUBS, saved = seven }).run([==[
    local M = addon.CooldownManager
    assert(M.db.version == 11 and M.db.moveBuffIcons == nil and M.db.castBar.show and M.db.castBar.icon == 'none', 'version 8 (then 9, 10); the cast bar from its defaults')
    assert(addon.db.positions.cooldownManagerBuffIcon.target == M.CAST_ELEMENT, 'Buff Icons above the cast bar')
]==], "version 8")

-- Version 9 -> 10 (owner, November 20, 2026): a Cast Bar still at Dark, the
-- old default, takes Color in your class color; Color with a picked Bar Color stays.
local nine = restored.saved()
nine.profiles.Default.modules.cooldownManager.version = 9
nine.profiles.Default.modules.cooldownManager.castBar.barMode = 'dark'
nine.profiles.Default.modules.cooldownManager.castBar.barColorMode = nil
H.Load({ before = STUBS, saved = nine }).run([==[
    local db = addon.CooldownManager.db
    assert(db.version == 11 and db.castBar.barMode == 'color' and db.castBar.barColorMode == 'class', 'Dark becomes your class color')
]==], "version 10")

-- Version 10 -> 11 (owner, November 23, 2026): cast colors still at the old
-- amber and gray take light blue and orange-red; a picked color stays.
local ten = restored.saved()
ten.profiles.Default.modules.cooldownManager.version = 10
ten.profiles.Default.modules.cooldownManager.castBar.barColor = { 0xF2 / 255, 0xB1 / 255, 0x3C / 255 }
ten.profiles.Default.modules.cooldownManager.castBar.lockedColor = { 0.2, 0.3, 0.4 }
H.Load({ before = STUBS, saved = ten }).run([==[
    local db, Tone, Same = addon.CooldownManager.db, addon.Style.Tone, addon.Style.SameColor
    assert(db.version == 11 and Same(db.castBar.barColor, Tone.cast.casting), 'old amber takes the light blue')
    assert(Same(db.castBar.lockedColor, { 0.2, 0.3, 0.4 }), 'a picked color stays')
]==], "version 11")
local moved = restored.saved()
moved.profiles.Default.modules.cooldownManager.version = 7
moved.profiles.Default.positions.cooldownManagerBuffIcon = { target = 'cooldownManagerEssential', placement = 'above', x = 12, y = 0 }
H.Load({ before = STUBS, saved = moved }).run([==[
    assert(addon.db.positions.cooldownManagerBuffIcon.target == 'cooldownManagerEssential' and addon.db.positions.cooldownManagerBuffIcon.x == 12, 'a place you chose stays')
]==], "version 8, moved")

print("cast bar: all checks passed")

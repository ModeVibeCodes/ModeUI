-- The Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme";
-- docs/OBSIDIAN.md): the first start's Mode-Obsidian profile, borders,
-- tokens, the typeface, the fill-end line, the Prism glow and the theme
-- parts. Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

-- An account that has a profile: the first start copies it to Mode-Obsidian,
-- makes the copy active and leaves the original as it was.
local saved = { schemaVersion = 2, activeProfile = "Main",
    profiles = { Main = { modules = { tooltip = { enabled = false } }, positions = {} } } }
local world = H.Load({ before = STUBS, saved = saved, obsidian = true })
world.run([==[
    local root, Style, Tone = ModeUIDB, addon.Style, addon.Style.Tone
    assert(root.activeProfile == 'Mode-Obsidian', 'the copy is active: ' .. tostring(root.activeProfile))
    assert(root.previousProfile == 'Main' and root.builtThemes.obsidian == true)
    assert(root.profiles.Main.theme == nil, 'the original profile is left as it was')
    local profile = root.profiles['Mode-Obsidian']
    assert(profile.theme == 'obsidian' and type(profile.themeParts) == 'table')
    assert(profile.modules.tooltip.enabled == false, 'the copy keeps the settings')
    local said = false
    for _, line in ipairs(messages) do if tostring(line):find('Mode%-Obsidian') and tostring(line):find('Main') then said = true end end
    assert(said, 'the first start says how to go back')

    -- Style follows the theme.
    assert(Style.Theme() == 'obsidian' and Style.IsObsidian())
    assert(Style.ThemeStyle('blizz') == 'obsidian' and Style.ThemeStyle('thin') == 'obsidian'
        and Style.ThemeStyle('round') == 'obsidian' and Style.ThemeStyle('blizzEmpty') == 'obsidianEmpty')
    local host = CreateFrame('Frame', nil, UIParent); host:SetSize(100, 30)
    local edge = Style.Edge(host, 'frame', { style = 'blizz' })
    assert(edge.styleId == 'obsidian', 'a saved Mode-Blizz border draws as Mode-Obsidian')
    edge:SetStyle('thin', 'default')
    assert(edge.styleId == 'obsidian')
    assert(edge.rings[1].key:find('^softHeavy'), 'soft round rings: ' .. edge.rings[1].key)
    local reach = Style.EdgeReach('frame')
    assert(reach == 3 and edge:Layout() == 2, 'the reach never changes')
    local aura = Style.Edge(host, 'frameThin', { style = 'thin', pieces = true })
    assert(aura.styleId == 'obsidian' and Style.EdgeMinHeight('frameThin', 'thin') == Style.EdgeMinHeight('frameThin', 'obsidian'))
    local choices = Style.EdgeStyleChoices(true, true)
    assert(choices[1].id == 'obsidian' and choices[2].id == 'obsidianEmpty' and choices[3].id == 'none', 'the theme lists its own styles')
    local empty = Style.Edge(host, 'empty', {})
    assert(empty.styleId == 'obsidianEmpty')
    -- The lit top row and the champagne bottom row, painted in the Obsidian metal.
    local tones = {}
    for _, ring in ipairs(edge.rings) do if ring.kind == 'band' then tones[#tones + 1] = ring.tone .. (ring.profile or '') end end
    assert(table.concat(tones, ',') == 'deep,hio1h,lighto1l', 'Obsidian lighting: ' .. table.concat(tones, ','))
    assert(edge:Metal() == Tone.metal.obsidian)

    -- The portrait ring: the Obsidian ring lighting.
    local ring = Style.Ring(host, 40, nil, 'blizz')
    assert(ring.styleId == 'obsidian' and #ring.layers == 3 and ring.layers[2].profile == 'orh' and ring.layers[3].profile == 'ord')
    Style.PaintRing(ring, { 1, 0.49, 0.04 })

    -- Tokens, typeface, fill end.
    local function Hex(c) return string.format('%02X%02X%02X', math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
    assert(Hex(Tone.graphite.panel) == '0B0B0C' and Hex(Tone.darkFill) == '161618' and Hex(Tone.slate) == '46464B')
    assert(Tone.emptyAlpha == 0.85 and Tone.shadowAlpha == 0.9)
    assert(Hex(Style.BlizzTone('graphite', 'panel')) == '121213', 'the Mode-Blizz values are kept')
    assert(Hex(Style.ObsidianTone('graphite', 'panel')) == '0B0B0C')
    assert(Style.FontPath('semibold'):find('Urbanist%-SemiBold%.ttf$') and Style.Typeface() == 'Urbanist')
    assert(Style.Weighted(Style.FontPath('regular'), 'bold'):find('Urbanist%-Bold%.ttf$'))
    local color, alpha, inset = Style.FillEnd(0.22)
    assert(color == Tone.fillEnd and alpha == 0.85 and inset == 1)
    local bar = Style.Bar(host, { role = 'health' })
    assert(bar.endLine.points[1][5] == -bar.endLine.points[1][5] * -1 and bar.endLine.points[1][5] < 0, 'the end line sits 1px in')

    -- The Prism glow.
    local glow = Style.Glow(host)
    assert(not glow:IsShown() and glow.texture.blendMode == 'ADD')
    glow:SetColor({ 0.25, 0.78, 0.92 }); glow:SetShown(true)
    assert(glow:IsShown())
    glow:SetShown(false)

    -- Switching back puts every Mode-Blizz value back.
    Style.ApplyTheme('blizz')
    assert(Hex(Tone.graphite.panel) == '121213' and Hex(Tone.darkFill) == '1C1D1C' and Tone.emptyAlpha == 0.6)
    Style.ApplyTheme('obsidian')
]==])

-- The theme parts ran once for the Mode-Obsidian profile.
world.run([==[
    local profile = ModeUIDB.profiles['Mode-Obsidian']
    local m = profile.modules
    for _, id in ipairs({ 'unitFrames', 'partyFrames', 'nameplates', 'actionBars', 'bags', 'chat', 'damageMeters', 'tooltip', 'windows', 'cooldownManager' }) do
        assert(profile.themeParts[id] == 'obsidian', 'theme part ran: ' .. id)
    end
    local player, focus = m.unitFrames.player, m.unitFrames.focus
    assert(player.healthColorMode == 'default' and player.foregroundTexture == 'media:Mode-Obsidian'
        and player.backgroundTexture == 'media:Mode-Obsidian Track' and player.barBackgroundOpacity == 85)
    assert(player.nameColorMode == 'class' and player.prismGlow == 'hover' and focus.prismGlow == 'always')
    local party = m.partyFrames
    assert(party.healthColorMode == 'default' and party.dispelFrom == 'bottom' and party.hoverGlow and party.focusGlow and not party.hoverHighlight)
    assert(m.nameplates.enemy.focusStyle == 'glow' and m.nameplates.enemy.healthColorMode == 'reaction', 'nameplates keep reaction health')
    local function Hex(c) return string.format('%02X%02X%02X', math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
    assert(Hex(m.tooltip.backgroundColor) == '0B0B0C' and Hex(m.bags.headerColor) == '131314' and Hex(m.actionBars.bar1.backgroundColor) == '09090A')
    assert(m.cooldownManager.resources.power.barBackground == 'media:Mode-Obsidian Track' and m.cooldownManager.castBar.barBackgroundOpacity == 85)
    -- Once: a later change stays through another check.
    player.prismGlow = 'none'
    local checked = addon.Database:ValidateProfile(profile)
    assert(checked.modules.unitFrames.player.prismGlow == 'none', 'a part never runs twice')
    -- The live frames: the Prism glow on the player frame, the end line in ice.
    local uf = addon.UnitFrames
    if uf.frames and uf.frames.player then
        local f = uf.frames.player
        assert(f.prism, 'the player frame has its glow')
        f:GetScript('OnEnter')(f)
        f:GetScript('OnLeave')(f)
    end
    -- A new profile made now carries the theme.
    local made = addon.Database:NewProfile()
    assert(made.theme == 'obsidian' and made.modules.unitFrames.player.prismGlow == 'hover', 'a new profile takes the theme in use')
    assert(addon.Profiles:CreateThemed('Main Obsidian', 'Main', 'obsidian'), 'a themed copy')
    local copy = ModeUIDB.profiles['Main Obsidian']
    assert(copy.theme == 'obsidian' and copy.themeParts.unitFrames == 'obsidian' and copy.modules.unitFrames.focus.prismGlow == 'always')
    assert(ModeUIDB.profiles.Main.theme == nil, 'the source stays')
    local layout = addon.Layouts:Build('mode-default', '1440')
    assert(layout.theme == 'obsidian' and layout.modules.partyFrames.dispelFrom == 'bottom', 'a layout profile takes the theme in use')
]==])

-- A second start: nothing new is made.
local again = H.Load({ before = STUBS, saved = world.saved(), obsidian = true })
again.run([==[
    assert(ModeUIDB.profiles['Mode-Obsidian (2)'] == nil and ModeUIDB.activeProfile == 'Mode-Obsidian', 'the first start runs once')
    assert(addon.Style.Theme() == 'obsidian')
]==])

-- A fresh account: its only profile starts in Mode-Obsidian.
local fresh = H.Load({ before = STUBS, obsidian = true })
fresh.run([==[
    local count = 0
    for _ in pairs(ModeUIDB.profiles) do count = count + 1 end
    assert(ModeUIDB.activeProfile == 'Default' and ModeUIDB.profiles.Default.theme == 'obsidian', 'a fresh account starts in Mode-Obsidian')
    assert(addon.Style.Theme() == 'obsidian')
]==])

-- Every other test runs on Mode-Blizz (the harness marks the first start done).
local blizz = H.Load({ before = STUBS })
blizz.run([==[
    local Style = addon.Style
    assert(Style.Theme() == 'blizz' and Style.ThemeStyle('blizz') == 'blizz')
    assert(Style.FontPath('regular'):find('Geist%-Regular%.ttf$'))
    assert(#Style.EdgeStyleChoices(nil, true) == 4 and #Style.EdgeStyleChoices() == 6, 'a picker lists the theme; checks accept every style')
    local color, alpha, inset = Style.FillEnd(0.22)
    assert(color == Style.Tone.mono.white and alpha == 0.22 and inset == 0)
]==])

-- A part added later still runs on a profile already in the theme.
world.run([[
    local profile = ModeUIDB.profiles['Mode-Obsidian']
    assert(profile.themeParts.classColors == nil, 'a module without a part is not marked')
    local ran = false
    addon.Themes:Contribute('obsidian', 'classColors', function() ran = true end)
    addon.Database:ValidateProfile(profile)
    assert(ran, 'a part added later runs')
]])

-- A first-start copy that fails its check leaves the account as it was.
local broken = H.Load({ before = STUBS .. [[
    addon.Themes:Contribute('obsidian', 'classColors', function() error('broken part') end)
]], saved = { schemaVersion = 2, activeProfile = 'Main', profiles = { Main = { modules = {}, positions = {} } } }, obsidian = true })
broken.run([[
    assert(ModeUIDB.activeProfile == 'Main' and ModeUIDB.profiles['Mode-Obsidian'] == nil, 'the failed copy is dropped')
    assert(not ModeUIDB.builtThemes.obsidian, 'tried again at the next start')
    assert(addon.Style.Theme() == 'blizz')
]])

-- A fresh account that imports Play The Game Tools keeps the import in its
-- own profile and gets a Mode-Obsidian copy.
local ptg = H.Load({ before = STUBS, obsidian = true,
    ptg = { defaultProfile = 'P', profiles = { P = { modules = { unitFrames = { enabled = true } }, positions = {} } } } })
ptg.run([[
    assert(tostring(ModeUIDB.importedFrom):find('PlayTheGameTools'), 'imported')
    assert(ModeUIDB.activeProfile == 'Mode-Obsidian' and ModeUIDB.profiles.Default.theme == nil, 'the import stays as it was')
    assert(ModeUIDB.profiles.Default.modules.unitFrames.enabled == true)
]])

print("obsidian: all checks passed")

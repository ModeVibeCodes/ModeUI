-- Mode-Obsidian, the only look (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian
-- theme"; docs/OBSIDIAN.md): every profile turns Mode-Obsidian when it is
-- checked (each module's part once, the look and typeface steps), borders,
-- tokens, the typeface, the fill-end line and the Prism glow. Simulated
-- client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

-- An account from before November 20, 2026 with a Mode-Blizz profile: no
-- copy is made; the profile itself turns Mode-Obsidian.
local saved = { schemaVersion = 2, activeProfile = "Main",
    profiles = { Main = { typeface = 3, modules = { tooltip = { enabled = false }, unitFrames = { player = { edgeStyle = "thin",
        edgeMetal = "steel", foregroundTexture = "media:Mode Matte", fontMedia = "Mode Geist SemiBold" } } }, positions = {} } } }
local world = H.Load({ before = STUBS, saved = saved })
world.run([==[
    local root, Style, Tone = ModeUIDB, addon.Style, addon.Style.Tone
    assert(root.activeProfile == 'Main' and root.profiles['Mode-Obsidian'] == nil and root.previousProfile == nil, 'no copy: ' .. tostring(root.activeProfile))
    local profile = root.profiles.Main
    assert(profile == addon.db and profile.theme == 'obsidian' and profile.look == 1 and profile.typeface == 4, 'the profile itself is Mode-Obsidian')
    assert(profile.modules.tooltip.enabled == false, 'its settings stay')
    local player = profile.modules.unitFrames.player
    assert(player.edgeStyle == 'obsidian' and player.edgeMetal == 'default', 'a Mode-Thin Steel border: Mode-Border in its own metal')
    assert(player.foregroundTexture == 'media:Mode-FG' and player.fontMedia == 'Mode-Urbanist SemiBold', 'textures and fonts moved')

    -- Style: one look.
    assert(Style.Theme() == 'obsidian' and Style.IsObsidian())
    assert(Style.ThemeStyle('blizz') == 'obsidian' and Style.ThemeStyle('thin') == 'obsidian'
        and Style.ThemeStyle('round') == 'obsidian' and Style.ThemeStyle('blizzEmpty') == 'obsidianEmpty' and Style.ThemeStyle('bogus') == nil)
    local host = CreateFrame('Frame', nil, UIParent); host:SetSize(100, 30)
    local edge = Style.Edge(host, 'frame', { style = 'blizz' })
    assert(edge.styleId == 'obsidian', 'an old Mode-Blizz id draws as Mode-Border')
    edge:SetStyle('thin', 'default')
    assert(edge.styleId == 'obsidian')
    assert(edge.rings[1].key:find('^softHeavy'), 'soft round rings: ' .. edge.rings[1].key)
    local reach = Style.EdgeReach('frame')
    assert(reach == 3 and edge:Layout() == 2, 'the reach never changes')
    local aura = Style.Edge(host, 'frameThin', { style = 'thin', pieces = true })
    assert(aura.styleId == 'obsidian' and Style.EdgeMinHeight('frameThin', 'thin') == Style.EdgeMinHeight('frameThin', 'obsidian'))
    local choices = Style.EdgeStyleChoices(true, true)
    assert(choices[1].id == 'obsidian' and choices[1].label == 'Mode-Border' and choices[2].id == 'obsidianEmpty'
        and choices[2].label == 'Mode-Empty' and choices[3].id == 'none', 'a picker lists Mode-Border and Mode-Empty')
    assert(#Style.EdgeStyleChoices() == 6, 'a settings check also accepts the four old ids')
    local empty = Style.Edge(host, 'empty', {})
    assert(empty.styleId == 'obsidianEmpty')
    -- The lit top row and the champagne bottom row, painted in the Obsidian metal.
    local tones = {}
    for _, ring in ipairs(edge.rings) do if ring.kind == 'band' then tones[#tones + 1] = ring.tone .. (ring.profile or '') end end
    assert(table.concat(tones, ',') == 'deep,hio1h,lighto1l', 'Obsidian lighting: ' .. table.concat(tones, ','))
    assert(edge:Metal() == Tone.metal.obsidian)
    -- The softer edge (owner, November 20, 2026): long fades, a lighter dark
    -- glass, a lighter shadow ring.
    local P = Style.EDGE_DATA.PROFILES
    assert(P.o1h[3][1] == 0.42 and P.o1l[2][1] == 0.62, 'long fades')

    -- The portrait ring: the Obsidian ring lighting.
    local ring = Style.Ring(host, 40, nil, 'blizz')
    assert(ring.styleId == 'obsidian' and #ring.layers == 3 and ring.layers[2].profile == 'orh' and ring.layers[3].profile == 'ord')
    Style.PaintRing(ring, { 1, 0.49, 0.04 })

    -- Tokens, typeface, fill end.
    local function Hex(c) return string.format('%02X%02X%02X', math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
    assert(Hex(Tone.graphite.panel) == '0B0B0C' and Hex(Tone.darkFill) == '161618' and Hex(Tone.slate) == '46464B')
    assert(Tone.emptyAlpha == 0.85 and Tone.shadowAlpha == 0.65 and Hex(Tone.metal.obsidian.deep) == '19191C', 'the softer edge')
    assert(Hex(Style.BlizzTone('graphite', 'panel')) == '121213', 'the Mode-Blizz values are kept for migrations')
    assert(Hex(Style.ObsidianTone('graphite', 'panel')) == '0B0B0C')
    Style.ApplyTheme('blizz')
    assert(Hex(Tone.graphite.panel) == '0B0B0C' and Style.Theme() == 'obsidian', 'there is no other look to apply')
    assert(Style.FontPath('semibold'):find('Urbanist%-SemiBold%.ttf$') and Style.Typeface() == 'Urbanist')
    assert(Style.Weighted(Style.FontPath('regular'), 'bold'):find('Urbanist%-Bold%.ttf$'))
    local color, alpha, inset = Style.FillEnd(0.22)
    assert(color == Tone.fillEnd and alpha == 0.85 and inset == 1)
    local bar = Style.Bar(host, { role = 'health' })
    assert(bar.endLine.points[1][5] < 0, 'the end line sits 1px in')

    -- The Prism glow.
    local glow = Style.Glow(host)
    assert(not glow:IsShown() and glow.texture.blendMode == 'ADD')
    glow:SetColor({ 0.25, 0.78, 0.92 }); glow:SetShown(true)
    assert(glow:IsShown())
    glow:SetShown(false)
]==])

-- Every theme part ran once for the profile.
world.run([==[
    local profile = ModeUIDB.profiles.Main
    local m = profile.modules
    for _, id in ipairs({ 'unitFrames', 'partyFrames', 'nameplates', 'actionBars', 'bags', 'chat', 'damageMeters', 'tooltip', 'windows', 'cooldownManager' }) do
        assert(profile.themeParts[id] == 'obsidian', 'theme part ran: ' .. id)
    end
    local player, focus = m.unitFrames.player, m.unitFrames.focus
    assert(player.healthColorMode == 'default' and player.foregroundTexture == 'media:Mode-FG'
        and player.backgroundTexture == 'media:Mode-BG' and player.barBackgroundOpacity == 85)
    assert(player.nameColorMode == 'class' and player.prismGlow == 'hover' and focus.prismGlow == 'always')
    local party = m.partyFrames
    assert(party.healthColorMode == 'default' and party.dispelFrom == 'bottom' and party.hoverGlow and party.focusGlow and not party.hoverHighlight)
    assert(m.nameplates.enemy.focusStyle == 'glow' and m.nameplates.enemy.healthColorMode == 'reaction', 'nameplates keep reaction health')
    local function Hex(c) return string.format('%02X%02X%02X', math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
    assert(Hex(m.tooltip.backgroundColor) == '0B0B0C' and Hex(m.bags.headerColor) == '131314' and Hex(m.actionBars.bar1.backgroundColor) == '09090A')
    assert(m.cooldownManager.resources.power.barBackground == 'media:Mode-BG' and m.cooldownManager.castBar.barBackgroundOpacity == 85)
    -- Once: a later change stays through another check.
    player.prismGlow = 'none'
    local checked = addon.Database:ValidateProfile(profile)
    assert(checked.modules.unitFrames.player.prismGlow == 'none', 'a part never runs twice')
    -- The live frames: the Prism glow on the player frame.
    local uf = addon.UnitFrames
    if uf.frames and uf.frames.player then
        local f = uf.frames.player
        assert(f.prism, 'the player frame has its glow')
        f:GetScript('OnEnter')(f)
        f:GetScript('OnLeave')(f)
    end
    -- A new profile and a layout's are Mode-Obsidian.
    local made = addon.Database:NewProfile()
    assert(made.theme == 'obsidian' and made.look == 1 and made.modules.unitFrames.player.prismGlow == 'hover', 'a new profile')
    assert(made.modules.cooldownManager.essential.edgeStyle == 'obsidianEmpty', "the Cooldown Manager's icons in Mode-Empty")
    local layout = addon.Layouts:Build('mode-default', '1440')
    assert(layout.theme == 'obsidian' and layout.modules.partyFrames.dispelFrom == 'bottom', 'a layout profile')
    assert(addon.Profiles.CreateThemed == nil, 'no themed copies: there is one look')
]==])

-- A second start: nothing new is made.
local again = H.Load({ before = STUBS, saved = world.saved() })
again.run([==[
    local count = 0
    for name in pairs(ModeUIDB.profiles) do count = count + 1; assert(not name:find('Obsidian'), name) end
    assert(ModeUIDB.activeProfile == 'Main' and addon.Style.Theme() == 'obsidian')
]==])

-- A fresh account: its only profile is Mode-Obsidian.
local fresh = H.Load({ before = STUBS })
fresh.run([==[
    assert(ModeUIDB.activeProfile == 'Default' and ModeUIDB.profiles.Default.theme == 'obsidian', 'a fresh account is Mode-Obsidian')
    assert(addon.Style.Theme() == 'obsidian')
]==])

-- A part added later still runs on a profile already checked.
world.run([[
    local profile = ModeUIDB.profiles.Main
    assert(profile.themeParts.classColors == nil, 'a module without a part is not marked')
    local ran = false
    addon.Themes:Contribute('obsidian', 'classColors', function() ran = true end)
    addon.Database:ValidateProfile(profile)
    assert(ran, 'a part added later runs')
]])

-- An account that imports Play The Game Tools keeps the import in its own
-- profile, which is Mode-Obsidian like every other.
local ptg = H.Load({ before = STUBS,
    ptg = { defaultProfile = 'P', profiles = { P = { modules = { unitFrames = { enabled = true } }, positions = {} } } } })
ptg.run([[
    assert(tostring(ModeUIDB.importedFrom):find('PlayTheGameTools'), 'imported')
    assert(ModeUIDB.activeProfile == 'Default' and ModeUIDB.profiles.Default.theme == 'obsidian')
    assert(ModeUIDB.profiles.Default.modules.unitFrames.enabled == true and ModeUIDB.profiles['Mode-Obsidian'] == nil)
]])

print("obsidian: all checks passed")
